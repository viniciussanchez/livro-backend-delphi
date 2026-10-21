unit LegacySync.Controller;

{ Rotas de operação da sincronização (capítulo 22). Só a administração.
  Elas não passam pelo gateway: são para quem cuida da migração. }

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  Horse,
  Platform.Auth,
  Platform.Database,
  Platform.Log,
  LegacySync.Queue,
  LegacySync.Worker;

// GET /sync/status: como está a fila agora.
procedure GetStatus(Req: THorseRequest; Res: THorseResponse);
var
  LSession: IDbSession;
  LQueue: TLegacyQueue;
begin
  LSession := TDatabase.NewSession(LEGACY_DB);
  LQueue := TLegacyQueue.Create(LSession.Connection);
  try
    Res.Send<TJSONObject>(LQueue.Status);
  finally
    LQueue.Free;
  end;
end;

// GET /sync/rejected?limit=50: os clientes que precisam de correção no
// sistema antigo, com o motivo.
procedure GetRejected(Req: THorseRequest; Res: THorseResponse);
var
  LSession: IDbSession;
  LQueue: TLegacyQueue;
begin
  LSession := TDatabase.NewSession(LEGACY_DB);
  LQueue := TLegacyQueue.Create(LSession.Connection);
  try
    Res.Send<TJSONArray>(LQueue.Rejected(StrToIntDef(Req.Query['limit'], 50)));
  finally
    LQueue.Free;
  end;
end;

// POST /sync/full-load: coloca todos os clientes na fila (carga inicial).
// Pode ser chamado de novo a qualquer momento: como cada envio é um PUT
// pelo código do sistema antigo, repetir não duplica ninguém.
procedure PostFullLoad(Req: THorseRequest; Res: THorseResponse);
var
  LSession: IDbSession;
  LQueue: TLegacyQueue;
  LCount: Integer;
  LResult: TJSONObject;
begin
  LSession := TDatabase.NewSession(LEGACY_DB);
  LQueue := TLegacyQueue.Create(LSession.Connection);
  try
    LCount := LQueue.EnqueueAllCustomers;
  finally
    LQueue.Free;
  end;
  TLog.Info('carga completa enfileirada', [F('customers', LCount)]);
  LResult := TJSONObject.Create;
  LResult.AddPair('queued', TJSONNumber.Create(LCount));
  Res.Status(THTTPStatus.Accepted).Send<TJSONObject>(LResult);
end;

procedure Registry;
begin
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Get('/sync/status', GetStatus);
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Get('/sync/rejected', GetRejected);
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Post('/sync/full-load', PostFullLoad);
end;

end.
