unit Platform.Health;

(* GET /health: o serviço responde se está de pé e se alcança o próprio banco.

  Quem pergunta é uma máquina: o gateway (capítulo 16), o Docker
  (capítulo 18) ou um monitor. Por isso a rota é pública, rápida e não
  devolve detalhes internos, só "ok" ou "fora do ar".

    200 {"service": "event-api", "status": "up", "database": "up"}
    503 {"service": "event-api", "status": "down", "database": "down"}

  Capítulo 19: GET /health/live responde só se o processo está vivo,
  sem olhar o banco. O Kubernetes usa as duas perguntas para coisas
  diferentes: /health/live para decidir se reinicia o contêiner,
  /health para decidir se manda tráfego para ele. *)

interface

// Registra a rota. AConnectionDefName é a conexão do pool do serviço.
procedure RegisterHealthCheck(const AServiceName, AConnectionDefName: string);

implementation

uses
  System.SysUtils,
  System.JSON,
  FireDAC.Comp.Client,
  Horse,
  Platform.Database;

var
  GServiceName: string;
  GConnectionDefName: string;

function DatabaseIsUp: Boolean;
var
  LConnection: TFDConnection;
begin
  try
    LConnection := TDatabase.NewConnection(GConnectionDefName);
    try
      LConnection.ExecSQLScalar('select 1');
      Result := True;
    finally
      LConnection.Free;
    end;
  except
    // Aqui a falha é a resposta: não há o que propagar.
    Result := False;
  end;
end;

procedure GetHealth(Req: THorseRequest; Res: THorseResponse);
var
  LUp: Boolean;
  LBody: TJSONObject;
begin
  LUp := DatabaseIsUp;
  LBody := TJSONObject.Create;
  LBody.AddPair('service', GServiceName);
  if LUp then
  begin
    LBody.AddPair('status', 'up');
    LBody.AddPair('database', 'up');
    Res.Send<TJSONObject>(LBody).Status(THTTPStatus.OK);
  end
  else
  begin
    LBody.AddPair('status', 'down');
    LBody.AddPair('database', 'down');
    Res.Send<TJSONObject>(LBody).Status(THTTPStatus.ServiceUnavailable);
  end;
end;

// Se este código está rodando, o processo está vivo. Não consultamos o banco
// de propósito: um banco fora do ar não se resolve reiniciando o serviço.
procedure GetLiveness(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
begin
  LBody := TJSONObject.Create;
  LBody.AddPair('service', GServiceName);
  LBody.AddPair('status', 'up');
  Res.Send<TJSONObject>(LBody).Status(THTTPStatus.OK);
end;

procedure RegisterHealthCheck(const AServiceName, AConnectionDefName: string);
begin
  GServiceName := AServiceName;
  GConnectionDefName := AConnectionDefName;
  THorse.Get('/health', GetHealth);
  THorse.Get('/health/live', GetLiveness);
end;

end.
