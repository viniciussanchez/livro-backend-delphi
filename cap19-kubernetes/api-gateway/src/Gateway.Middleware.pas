unit Gateway.Middleware;

{ Middlewares que valem para toda requisição que passa pelo gateway. }

interface

uses
  System.SysUtils,
  Horse;

// Garante que toda requisição tenha um X-Request-Id e o devolve na resposta.
procedure RequestId(Req: THorseRequest; Res: THorseResponse; Next: TProc);

// Uma linha no console por requisição: id, método, caminho, status e tempo.
procedure AccessLog(Req: THorseRequest; Res: THorseResponse; Next: TProc);

// CORS: permite que páginas dos endereços em AllowedOrigins chamem a API.
procedure ConfigureCors(const AAllowedOrigins: string);
procedure Cors(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

uses
  System.Diagnostics,
  System.SyncObjs,
  Horse.Commons;

var
  GLogLock: TCriticalSection;
  GAllowedOrigins: TArray<string>;

function NewRequestId: string;
begin
  // Um GUID sem chaves e sem hífens: 32 caracteres, fácil de procurar no log.
  Result := TGUID.NewGuid.ToString.Substring(1, 36).Replace('-', '').ToLower;
end;

procedure RequestId(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LId: string;
begin
  LId := Req.Headers['X-Request-Id'];
  // Aceitamos o id de quem chamou só se ele for razoável. Um valor enorme
  // ou com caracteres estranhos iria parar nos logs de todos os serviços.
  if LId.IsEmpty or (LId.Length > 64) or (LId.IndexOfAny([' ', #13, #10, #9]) >= 0) then
    LId := NewRequestId;
  // Gravamos no próprio Req.Headers: daqui para a frente, todo mundo
  // (o proxy, o log, o tratamento de erros) lê o mesmo valor.
  Req.Headers.Dictionary.AddOrSetValue('X-Request-Id', LId);
  Res.AddHeader('X-Request-Id', LId);
  Next;
end;

procedure WriteLog(const ALine: string);
begin
  // Várias threads escrevendo no console ao mesmo tempo embaralham as linhas.
  GLogLock.Enter;
  try
    Writeln(ALine);
    Flush(Output);
  finally
    GLogLock.Leave;
  end;
end;

procedure AccessLog(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LWatch: TStopwatch;
begin
  LWatch := TStopwatch.StartNew;
  try
    Next;
  finally
    // No finally para registrar também as requisições que terminaram em erro.
    WriteLog(Format('%s %s %-6s %-40s %d %d ms', [
      FormatDateTime('hh:nn:ss.zzz', Now), Req.Headers['X-Request-Id'],
      Req.RawWebRequest.Method, Req.PathInfo, Res.Status, LWatch.ElapsedMilliseconds]));
  end;
end;

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

initialization
  GLogLock := TCriticalSection.Create;

finalization
  GLogLock.Free;

end.
