unit LegacySync.Worker;

(* As threads que esvaziam a fila (capítulo 22).

  Cada thread repete, enquanto houver trabalho:
    1. pega o próximo item pendente da SYNC_FILA, travado (SKIP LOCKED);
    2. trava o cliente (duas alterações seguidas do mesmo cliente nunca são
       enviadas ao mesmo tempo);
    3. lê o estado ATUAL do cliente no sistema antigo e o traduz;
    4. envia para a customer-api;
    5. marca o resultado: feito, rejeitado ou "tentar de novo mais tarde".
  Tudo isso numa transação só. Se o processo cair no meio, nada foi
  marcado, e o item é tratado de novo: como o envio é um PUT, repetir é
  seguro.

  Quando a fila esvazia, a thread dorme SYNC_IDLE_MS e olha de novo. *)

interface

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections;

type
  TSyncWorkers = class
  public
    class procedure Start(const ACount, AIdleMs: Integer; const ACustomerApiUrl: string;
      const ATimeout: Integer); static;
    class procedure Stop; static;
  end;

const
  LEGACY_DB = 'legacy_db';

implementation

uses
  System.SysUtils,
  System.Math,
  System.JSON,
  FireDAC.Comp.Client,
  Platform.Database,
  Platform.Exceptions,
  Platform.Log,
  Platform.Metrics,
  LegacySync.Translator,
  LegacySync.Queue,
  LegacySync.CustomerClient;

type
  TSyncWorker = class(TThread)
  private
    FIdleMs: Integer;
    FClient: TCustomerApiClient;
    // TServiceClient é contado por referência (TInterfacedObject). Esta
    // referência mantém o objeto vivo enquanto a thread existir e o libera
    // sozinha no fim.
    FClientRef: IInterface;
    function ProcessNext: Boolean;
    procedure Handle(const AQueue: TLegacyQueue; const AItem: TSyncItem);
    procedure HandleCustomer(const AQueue: TLegacyQueue; const AItem: TSyncItem);
  protected
    procedure Execute; override;
  public
    constructor Create(const AIdleMs: Integer; const ACustomerApiUrl: string; const ATimeout: Integer);
  end;

var
  GWorkers: TObjectList<TSyncWorker>;
  // Sinalizado no encerramento, para acordar quem está dormindo.
  GStopEvent: TEvent;

procedure CountItem(const AResult: string);
begin
  TMetrics.Inc('legacy_sync_items_total', 'Itens da fila processados, por resultado.', ['result=' + AResult]);
end;

// 1 s, 2 s, 4 s, 8 s... até no máximo 1 minuto entre as tentativas.
function RetryDelaySeconds(const AAttempts: Integer): Integer;
begin
  Result := Min(60, 1 shl Min(AAttempts, 6));
end;

{ TSyncWorker }

constructor TSyncWorker.Create(const AIdleMs: Integer; const ACustomerApiUrl: string; const ATimeout: Integer);
begin
  inherited Create(True);
  FIdleMs := AIdleMs;
  FClient := TCustomerApiClient.Create(ACustomerApiUrl, ATimeout);
  FClientRef := FClient;
end;

procedure TSyncWorker.Execute;
begin
  while not Terminated do
    try
      if not ProcessNext then
        GStopEvent.WaitFor(FIdleMs);
    except
      on E: Exception do
      begin
        // Banco do sistema antigo fora do ar, por exemplo. Registra e
        // espera um pouco, em vez de repetir o erro mil vezes por segundo.
        TLog.Error('falha na sincronização', [F('exception', E.ClassName), F('detail', E.Message)]);
        GStopEvent.WaitFor(5000);
      end;
    end;
end;

function TSyncWorker.ProcessNext: Boolean;
var
  LConnection: TFDConnection;
  LQueue: TLegacyQueue;
  LItem: TSyncItem;
begin
  LConnection := TDatabase.NewConnection(LEGACY_DB);
  try
    LQueue := TLegacyQueue.Create(LConnection);
    try
      LConnection.StartTransaction;
      try
        Result := LQueue.TryTakeNext(LItem);
        if Result then
        begin
          // Capítulo 21: o item da fila faz o papel do X-Request-Id. Ele
          // aparece no nosso log e segue para o log da customer-api.
          SetCurrentRequestId('sync-' + LItem.Id.ToString);
          try
            Handle(LQueue, LItem);
          finally
            SetCurrentRequestId('');
          end;
        end;
        LConnection.Commit;
      except
        LConnection.Rollback;
        raise;
      end;
    finally
      LQueue.Free;
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TSyncWorker.Handle(const AQueue: TLegacyQueue; const AItem: TSyncItem);
begin
  if SameText(AItem.Table, 'CLIENTE') then
    HandleCustomer(AQueue, AItem)
  else
  begin
    AQueue.MarkRejected(AItem, 'Tabela não suportada pela sincronização: ' + AItem.Table);
    CountItem('rejected');
  end;
end;

procedure TSyncWorker.HandleCustomer(const AQueue: TLegacyQueue; const AItem: TSyncItem);
var
  LCustomer: TLegacyCustomer;
  LTranslation: TTranslation;
  LWarning, LProblem: string;
  LOutcome: TPushOutcome;
begin
  AQueue.LockKey(AItem);
  if not AQueue.ReadCustomer(AItem.Key, LCustomer) then
  begin
    AQueue.MarkDone(AItem, 'o cliente não existe mais no sistema antigo');
    CountItem('ignored');
    Exit;
  end;

  LTranslation := TLegacyCustomerTranslator.Translate(LCustomer);
  try
    for LWarning in LTranslation.Warnings do
    begin
      TLog.Warn('dado descartado na tradução', [F('legacyCode', AItem.Key), F('detail', LWarning)]);
      TMetrics.Inc('legacy_sync_discarded_fields_total', 'Campos do sistema antigo deixados de fora.', []);
    end;
    if LTranslation.Ignored then
    begin
      AQueue.MarkDone(AItem, LTranslation.IgnoreReason);
      CountItem('ignored');
      Exit;
    end;

    try
      LOutcome := FClient.PushLegacyCustomer(AItem.Key, LTranslation.Body, LProblem);
    except
      on E: EServiceUnavailableException do
      begin
        AQueue.ScheduleRetry(AItem, E.Message, RetryDelaySeconds(AItem.Attempts));
        CountItem('retry');
        Exit;
      end;
    end;

    if LOutcome = poRejected then
    begin
      AQueue.MarkRejected(AItem, LProblem);
      TLog.Warn('cliente rejeitado pela customer-api', [F('legacyCode', AItem.Key), F('detail', LProblem)]);
      CountItem('rejected');
    end
    else
    begin
      // Quanto tempo se passou entre a alteração no balcão e a chegada
      // na plataforma nova.
      TMetrics.Observe('legacy_sync_delay_seconds',
        'Tempo entre a alteração no sistema antigo e a chegada na customer-api.', [],
        AQueue.MarkDone(AItem));
      if LOutcome = poCreated then
        CountItem('created')
      else
        CountItem('updated');
    end;
  finally
    LTranslation.Body.Free;
  end;
end;

{ TSyncWorkers }

class procedure TSyncWorkers.Start(const ACount, AIdleMs: Integer; const ACustomerApiUrl: string;
  const ATimeout: Integer);
var
  I: Integer;
  LWorker: TSyncWorker;
begin
  for I := 1 to ACount do
  begin
    LWorker := TSyncWorker.Create(AIdleMs, ACustomerApiUrl, ATimeout);
    GWorkers.Add(LWorker);
    LWorker.Start;
  end;
  TLog.Info('sincronização iniciada', [F('workers', ACount)]);
end;

class procedure TSyncWorkers.Stop;
var
  LWorker: TSyncWorker;
begin
  for LWorker in GWorkers do
    LWorker.Terminate;
  GStopEvent.SetEvent;
  // A thread termina o item em andamento (no máximo um envio) e sai.
  for LWorker in GWorkers do
    LWorker.WaitFor;
  GWorkers.Clear;
end;

initialization
  GWorkers := TObjectList<TSyncWorker>.Create(True);
  GStopEvent := TEvent.Create(nil, True, False, '');

finalization
  GWorkers.Free;
  GStopEvent.Free;

end.
