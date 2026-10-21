unit Gateway.Middleware;

{ Middlewares que valem para toda requisição que passa pelo gateway.
  Capítulo 21: o X-Request-Id e o log de acesso saíram daqui e foram para
  Platform.Middleware.Observability, comum a todos os serviços. }

interface

uses
  System.SysUtils,
  Horse;

// CORS: permite que páginas dos endereços em AllowedOrigins chamem a API.
procedure ConfigureCors(const AAllowedOrigins: string);
procedure Cors(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

uses
  Horse.Commons;

var
  GAllowedOrigins: TArray<string>;

procedure ConfigureCors(const AAllowedOrigins: string);
var
  LOrigin: string;
begin
  GAllowedOrigins := [];
  for LOrigin in AAllowedOrigins.Split([',']) do
    if not LOrigin.Trim.IsEmpty then
      GAllowedOrigins := GAllowedOrigins + [LOrigin.Trim.TrimRight(['/'])];
end;

function IsAllowedOrigin(const AOrigin: string): Boolean;
var
  LAllowed: string;
begin
  for LAllowed in GAllowedOrigins do
    if SameText(LAllowed, AOrigin) then
      Exit(True);
  Result := False;
end;

procedure Cors(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LOrigin: string;
begin
  LOrigin := Req.Headers['Origin'];
  // A resposta muda conforme a origem: caches no caminho precisam saber disso.
  Res.AddHeader('Vary', 'Origin');
  if not LOrigin.IsEmpty and IsAllowedOrigin(LOrigin) then
  begin
    Res.AddHeader('Access-Control-Allow-Origin', LOrigin);
    // Sem isto, o JavaScript da página não consegue ler esses cabeçalhos.
    Res.AddHeader('Access-Control-Expose-Headers', 'Location, Retry-After, X-Request-Id');
  end;

  // Pré-verificação (preflight): o navegador pergunta antes de enviar
  // um POST com JSON ou um cabeçalho Authorization. Respondemos aqui
  // mesmo, sem incomodar os serviços.
  // O Horse não tem um TMethodType para OPTIONS: comparamos o texto do método.
  if SameText(Req.RawWebRequest.Method, 'OPTIONS') then
  begin
    if not LOrigin.IsEmpty and IsAllowedOrigin(LOrigin) then
    begin
      Res.AddHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      Res.AddHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Request-Id');
      Res.AddHeader('Access-Control-Max-Age', '600');
    end;
    // Origem não permitida: respondemos sem os cabeçalhos e o navegador bloqueia.
    // Sem chamar Next: a resposta termina aqui.
    Res.Status(THTTPStatus.NoContent).Send('');
    Exit;
  end;

  Next;
end;

end.
