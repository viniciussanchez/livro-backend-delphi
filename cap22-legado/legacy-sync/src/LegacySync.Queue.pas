unit LegacySync.Queue;

(* Acesso ao banco do sistema antigo (capítulo 22): a fila SYNC_FILA,
  preenchida pelo gatilho, e a leitura da tabela CLIENTE.

  Cada operação roda na conexão que recebe. Quem chama abre a transação:
  pegar o item da fila, enviar o cliente e marcar o resultado acontecem
  dentro de uma transação só. *)

interface

uses
  System.SysUtils,
  System.JSON,
  FireDAC.Comp.Client,
  LegacySync.Translator;

type
  TSyncItem = record
    Id: Int64;
    Table: string;
    Key: Integer;
    Attempts: Integer;
  end;

  TLegacyQueue = class
  private
    FConnection: TFDConnection;
  public
    constructor Create(const AConnection: TFDConnection);
    // Pega o próximo item pendente e o trava até o fim da transação.
    // Outras cópias do serviço pulam os itens travados (SKIP LOCKED).
    function TryTakeNext(out AItem: TSyncItem): Boolean;
    // Garante que um mesmo cliente é tratado por uma cópia de cada vez.
    procedure LockKey(const AItem: TSyncItem);
    function ReadCustomer(const ACode: Integer; out ACustomer: TLegacyCustomer): Boolean;
    // Marca o item como feito, junto com os itens mais antigos do mesmo
    // cliente que ainda estavam na fila. Devolve há quantos segundos o
    // item tinha entrado na fila.
    function MarkDone(const AItem: TSyncItem; const ANote: string = ''): Double;
    procedure MarkRejected(const AItem: TSyncItem; const AError: string);
    procedure ScheduleRetry(const AItem: TSyncItem; const AError: string; const ADelaySeconds: Integer);
    // Operação: coloca todos os clientes na fila (carga inicial).
    function EnqueueAllCustomers: Integer;
    function Status: TJSONObject;
    function Rejected(const ALimit: Integer): TJSONArray;
    function QueueExists: Boolean;
  end;

implementation

uses
  Data.DB,
  FireDAC.Stan.Param,
  Platform.Dates;

constructor TLegacyQueue.Create(const AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TLegacyQueue.QueueExists: Boolean;
begin
  Result := FConnection.ExecSQLScalar('select to_regclass(''sync_fila'') is not null');
end;

function TLegacyQueue.TryTakeNext(out AItem: TSyncItem): Boolean;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text :=
      'select ID, TABELA, CHAVE, TENTATIVAS' +
      '  from SYNC_FILA' +
      ' where STATUS = ''P'' and PROXIMA_TENTATIVA <= localtimestamp' +
      ' order by PROXIMA_TENTATIVA, ID' +
      ' limit 1' +
      '   for update skip locked';
    LQuery.Open;
    Result := not LQuery.IsEmpty;
    if Result then
    begin
      AItem.Id := LQuery.FieldByName('ID').AsLargeInt;
      AItem.Table := LQuery.FieldByName('TABELA').AsString;
      AItem.Key := LQuery.FieldByName('CHAVE').AsInteger;
      AItem.Attempts := LQuery.FieldByName('TENTATIVAS').AsInteger;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TLegacyQueue.LockKey(const AItem: TSyncItem);
begin
  // Duas cópias podem pegar dois itens diferentes do MESMO cliente (ele foi
  // alterado duas vezes seguidas). Sem esta trava, a cópia que leu a versão
  // mais antiga poderia enviá-la por último e desfazer a mais nova. A trava
  // vale até o fim da transação.
  FConnection.ExecSQLScalar('select 1 from (select pg_advisory_xact_lock(hashtext(:tabela), :chave)) t',
    [AItem.Table, AItem.Key]);
end;

function TLegacyQueue.ReadCustomer(const ACode: Integer; out ACustomer: TLegacyCustomer): Boolean;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text :=
      'select COD_CLI, NOME, CPF, FONE, EMAIL, DT_NASC, SITUACAO from CLIENTE where COD_CLI = :cod';
    LQuery.ParamByName('cod').AsInteger := ACode;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
    if Result then
    begin
      ACustomer.Code := LQuery.FieldByName('COD_CLI').AsInteger;
      ACustomer.Name := LQuery.FieldByName('NOME').AsString;
      ACustomer.Cpf := LQuery.FieldByName('CPF').AsString;
      ACustomer.Phone := LQuery.FieldByName('FONE').AsString;
      ACustomer.Email := LQuery.FieldByName('EMAIL').AsString;
      ACustomer.BirthDate := LQuery.FieldByName('DT_NASC').AsString;
      ACustomer.Status := LQuery.FieldByName('SITUACAO').AsString;
    end;
  finally
    LQuery.Free;
  end;
end;

function TLegacyQueue.MarkDone(const AItem: TSyncItem; const ANote: string): Double;
begin
  Result := FConnection.ExecSQLScalar(
    'update SYNC_FILA set STATUS = ''O'', PROCESSADO_EM = localtimestamp, ERRO = :nota' +
    ' where ID = :id' +
    ' returning extract(epoch from clock_timestamp()::timestamp - CRIADO_EM)::float8',
    [ANote, AItem.Id]);
  // Os itens anteriores do mesmo cliente, pendentes ou rejeitados, ficam
  // resolvidos: o que acabamos de enviar já é o estado mais recente.
  // O "skip locked" pula os itens que outra thread pegou e ainda segura:
  // esperar por eles aqui, com a trava do cliente na mão, seria um deadlock
  // (a outra thread está esperando justamente essa trava). Ela mesma resolve
  // o item dela quando a trava for liberada.
  FConnection.ExecSQL(
    'update SYNC_FILA set STATUS = ''O'', PROCESSADO_EM = localtimestamp' +
    ' where ID in (select ID from SYNC_FILA' +
    '   where TABELA = :tabela and CHAVE = :chave and ID < :id and STATUS in (''P'', ''R'')' +
    '   for update skip locked)',
    [AItem.Table, AItem.Key, AItem.Id]);
end;

procedure TLegacyQueue.MarkRejected(const AItem: TSyncItem; const AError: string);
begin
  FConnection.ExecSQL(
    'update SYNC_FILA set STATUS = ''R'', PROCESSADO_EM = localtimestamp,' +
    '       TENTATIVAS = TENTATIVAS + 1, ERRO = left(:erro, 1000)' +
    ' where ID = :id', [AError, AItem.Id]);
  // Um item rejeitado não volta para a fila sozinho: alguém precisa
  // corrigir o cadastro no sistema antigo. A correção dispara o gatilho e
  // cria um item novo. Os itens pendentes mais antigos deste cliente
  // teriam o mesmo destino, então saem da fila também.
  FConnection.ExecSQL(
    'update SYNC_FILA set STATUS = ''O'', PROCESSADO_EM = localtimestamp,' +
    '       ERRO = ''substituído pelo item '' || :item_novo' +
    ' where ID in (select ID from SYNC_FILA' +
    '   where TABELA = :tabela and CHAVE = :chave and ID < :limite and STATUS = ''P''' +
    '   for update skip locked)',
    [AItem.Id, AItem.Table, AItem.Key, AItem.Id]);
end;

procedure TLegacyQueue.ScheduleRetry(const AItem: TSyncItem; const AError: string; const ADelaySeconds: Integer);
begin
  FConnection.ExecSQL(
    'update SYNC_FILA set TENTATIVAS = TENTATIVAS + 1, ERRO = left(:erro, 1000),' +
    '       PROXIMA_TENTATIVA = localtimestamp + make_interval(secs => :segundos)' +
    ' where ID = :id', [AError, ADelaySeconds, AItem.Id]);
end;

function TLegacyQueue.EnqueueAllCustomers: Integer;
begin
  Result := FConnection.ExecSQL(
    'insert into SYNC_FILA (TABELA, CHAVE) select ''CLIENTE'', COD_CLI from CLIENTE order by COD_CLI');
end;

function TLegacyQueue.Status: TJSONObject;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text :=
      'select count(*) filter (where STATUS = ''P'') as pending,' +
      '       count(*) filter (where STATUS = ''P'' and TENTATIVAS > 0) as retrying,' +
      '       count(*) filter (where STATUS = ''O'') as done,' +
      '       count(distinct CHAVE) filter (where STATUS = ''R'') as rejected,' +
      '       coalesce(extract(epoch from localtimestamp - min(CRIADO_EM) filter (where STATUS = ''P'')), 0)::float8 as oldest' +
      '  from SYNC_FILA';
    LQuery.Open;
    Result := TJSONObject.Create;
    Result.AddPair('pending', TJSONNumber.Create(LQuery.FieldByName('pending').AsInteger));
    Result.AddPair('retrying', TJSONNumber.Create(LQuery.FieldByName('retrying').AsInteger));
    Result.AddPair('done', TJSONNumber.Create(LQuery.FieldByName('done').AsInteger));
    Result.AddPair('rejectedCustomers', TJSONNumber.Create(LQuery.FieldByName('rejected').AsInteger));
    Result.AddPair('oldestPendingSeconds', TJSONNumber.Create(Round(LQuery.FieldByName('oldest').AsFloat)));
  finally
    LQuery.Free;
  end;
end;

function TLegacyQueue.Rejected(const ALimit: Integer): TJSONArray;
var
  LQuery: TFDQuery;
  LItem: TJSONObject;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    // Um cliente por linha, com o erro mais recente.
    LQuery.SQL.Text :=
      'select distinct on (f.CHAVE) f.CHAVE, c.NOME, f.ERRO, f.PROCESSADO_EM' +
      '  from SYNC_FILA f left join CLIENTE c on c.COD_CLI = f.CHAVE' +
      ' where f.STATUS = ''R'' and f.TABELA = ''CLIENTE''' +
      ' order by f.CHAVE, f.ID desc' +
      ' limit :limite';
    LQuery.ParamByName('limite').AsInteger := ALimit;
    LQuery.Open;
    Result := TJSONArray.Create;
    while not LQuery.Eof do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('legacyCode', TJSONNumber.Create(LQuery.FieldByName('CHAVE').AsInteger));
      LItem.AddPair('name', LQuery.FieldByName('NOME').AsString);
      LItem.AddPair('error', LQuery.FieldByName('ERRO').AsString);
      LItem.AddPair('rejectedAt', FormatISODateTime(LQuery.FieldByName('PROCESSADO_EM').AsDateTime));
      Result.AddElement(LItem);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

end.
