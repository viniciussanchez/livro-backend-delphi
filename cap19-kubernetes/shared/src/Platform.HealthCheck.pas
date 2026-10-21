unit Platform.HealthCheck;

(* "EventApi --healthcheck": o próprio executável pergunta ao serviço,
  que já está rodando no mesmo contêiner, se ele está saudável.

  O Docker precisa de um comando para saber se o contêiner está bem
  (capítulo 18). O comum é usar o curl, mas aí precisaríamos instalar o
  curl em toda imagem só para isso. Como o executável já está lá, ele
  mesmo faz a pergunta e devolve o código de saída: 0 saudável, 1 doente. *)

interface

// Se o programa foi chamado com --healthcheck, faz a verificação, ajusta
// o ExitCode e devolve True: quem chamou deve encerrar logo em seguida.
// AAcceptedStatus: os status HTTP que contam como "saudável".
function RunHealthCheckIfRequested(const ADefaultPort: string;
  const AAcceptedStatus: array of Integer): Boolean;

implementation

uses
  System.SysUtils,
  System.Net.HttpClient;

function RunHealthCheckIfRequested(const ADefaultPort: string;
  const AAcceptedStatus: array of Integer): Boolean;
var
  LClient: THTTPClient;
  LPort: string;
  LStatus, LAccepted, I: Integer;
begin
  // FindCmdLineSwitch não serve aqui: ele entende "-healthcheck" ou
  // "/healthcheck", mas não as duas barras do padrão do Linux.
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '--healthcheck') then
      Result := True;
  if not Result then
    Exit;

  ExitCode := 1;
  LPort := GetEnvironmentVariable('PORT');
  if LPort.IsEmpty then
    LPort := ADefaultPort;
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 2000;
    LClient.ResponseTimeout := 5000;
    try
      LStatus := LClient.Get('http://127.0.0.1:' + LPort + '/health').StatusCode;
      for LAccepted in AAcceptedStatus do
        if LStatus = LAccepted then
          ExitCode := 0;
    except
      // Sem resposta: continua doente (ExitCode 1).
    end;
  finally
    LClient.Free;
  end;
end;

end.
