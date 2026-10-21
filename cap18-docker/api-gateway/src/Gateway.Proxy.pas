unit Gateway.Proxy;

{ O coração do gateway: recebe a requisição do cliente, repassa para o
  serviço certo e devolve a resposta dele, sem abrir o conteúdo.

  Aqui não usamos o RESTRequest4Delphi. Ele brilha quando sabemos o que
  estamos chamando (um GET que devolve um lote, um POST que cria uma
  reserva). O gateway não sabe nem quer saber: ele só transporta bytes.
  Para isso, o THTTPClient da própria RTL é a ferramenta mais direta. }

interface

uses
  Horse,
  Gateway.Routes;

type
  TProxySettings = record
    // Quanto esperamos para abrir a conexão com o serviço.
    ConnectTimeout: Integer;
    // Quanto esperamos pela resposta, depois de conectar.
    ResponseTimeout: Integer;
  end;

  TProxy = class
  private
    class var FSettings: TProxySettings;
  public
    class procedure Configure(const ASettings: TProxySettings); static;
    // Encaminha a requisição e escreve a resposta do serviço em ARes.
    class procedure Forward(const AReq: THorseRequest; const ARes: THorseResponse;
      const AMatch: TRouteMatch); static;
  end;

// O callback registrado no Horse para todas as rotas encaminhadas.
procedure ForwardRequest(Req: THorseRequest; Res: THorseResponse);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Net.URLClient,
  System.Net.HttpClient,
  Platform.Exceptions;

const
  // Cabeçalhos do cliente que o serviço precisa ver. Os demais ficam aqui:
  // cookies, cabeçalhos de conexão e tudo o que não interessa lá dentro.
  FORWARDED_REQUEST_HEADERS: array[0..3] of string =
    ('Authorization', 'Content-Type', 'Accept', 'Accept-Language');

  // Cabeçalhos da resposta do serviço que o cliente precisa ver.
  FORWARDED_RESPONSE_HEADERS: array[0..3] of string =
    ('Location', 'WWW-Authenticate', 'Retry-After', 'Allow');

class procedure TProxy.Configure(const ASettings: TProxySettings);
begin
  FSettings := ASettings;
end;

function BuildHeaders(const AReq: THorseRequest): TNetHeaders;
var
  LName, LValue, LClientAddress: string;
begin
  Result := [];
  for LName in FORWARDED_REQUEST_HEADERS do
  begin
    LValue := AReq.Headers[LName];
    if not LValue.IsEmpty then
      Result := Result + [TNameValuePair.Create(LName, LValue)];
  end;

  // O mesmo identificador em todos os logs (veja Gateway.Middleware).
  Result := Result + [TNameValuePair.Create('X-Request-Id', AReq.Headers['X-Request-Id'])];

  // Quem é o cliente de verdade. Sem isso, para o serviço, todas as
  // requisições viriam do endereço do gateway.
  LClientAddress := AReq.RawWebRequest.RemoteAddr;
  LValue := AReq.Headers['X-Forwarded-For'];
  if not LValue.IsEmpty then
    LClientAddress := LValue + ', ' + LClientAddress;
  Result := Result + [
    TNameValuePair.Create('X-Forwarded-For', LClientAddress),
    TNameValuePair.Create('X-Forwarded-Host', AReq.Headers['Host']),
    TNameValuePair.Create('X-Forwarded-Proto', 'http')];
end;

function BuildURL(const AReq: THorseRequest; const AMatch: TRouteMatch): string;
var
  LQuery: string;
begin
  Result := AMatch.Route.Upstream.BaseURL + AMatch.InternalPath;
  // A query string segue como chegou, sem decodificar e codificar de novo.
  LQuery := AReq.RawWebRequest.Query;
  if not LQuery.IsEmpty then
    Result := Result + '?' + LQuery;
end;

procedure CopyResponse(const AResponse: IHTTPResponse; const ABody: TBytesStream;
  const ARes: THorseResponse);
var
  LName, LValue: string;
begin
  for LName in FORWARDED_RESPONSE_HEADERS do
  begin
    LValue := AResponse.HeaderValue[LName];
    if not LValue.IsEmpty then
      ARes.AddHeader(LName, LValue);
  end;
  ARes.Status(AResponse.StatusCode);
  if ABody.Size > 0 then
  begin
    ARes.ContentType(AResponse.HeaderValue['Content-Type']);
    ARes.Send(Copy(ABody.Bytes, 0, ABody.Size));
  end
  else
    ARes.Send('');
end;

class procedure TProxy.Forward(const AReq: THorseRequest; const ARes: THorseResponse;
  const AMatch: TRouteMatch);
var
  LClient: THTTPClient;
  LRequestBody: TStringStream;
  LResponseBody: TBytesStream;
  LRequest: IHTTPRequest;
  LResponse: IHTTPResponse;
  LWatch: TStopwatch;
  LMethod: string;
begin
  LMethod := AReq.RawWebRequest.Method.ToUpper;
  LClient := THTTPClient.Create;
  LRequestBody := nil;
  LResponseBody := TBytesStream.Create;
  try
    LClient.ConnectionTimeout := FSettings.ConnectTimeout;
    LClient.ResponseTimeout := FSettings.ResponseTimeout;
    // Um redirecionamento do serviço é problema do cliente, não do gateway.
    LClient.HandleRedirects := False;

    if not AReq.Body.IsEmpty then
      LRequestBody := TStringStream.Create(AReq.Body, TEncoding.UTF8);

    LWatch := TStopwatch.StartNew;
    try
      LRequest := LClient.GetRequest(LMethod, BuildURL(AReq, AMatch));
      LRequest.SourceStream := LRequestBody;
      LResponse := LClient.Execute(LRequest, LResponseBody, BuildHeaders(AReq));
    except
      // ENetException é a base de todas as falhas de rede do THTTPClient.
      on E: ENetException do
      begin
        // A mesma classe de exceção serve para "conexão recusada" e para
        // "demorou demais". O relógio separa um caso do outro, do mesmo
        // jeito no Windows e no Linux.
        if LWatch.ElapsedMilliseconds >= FSettings.ResponseTimeout then
          raise EGatewayTimeoutException.CreateFmt(
            'A %s não respondeu em %d ms.', [AMatch.Route.Upstream.Name, FSettings.ResponseTimeout]);
        raise EBadGatewayException.CreateFmt(
          'Não foi possível falar com a %s. Tente de novo em instantes.', [AMatch.Route.Upstream.Name]);
      end;
    end;

    CopyResponse(LResponse, LResponseBody, ARes);
  finally
    LResponseBody.Free;
    LRequestBody.Free;
    LClient.Free;
  end;
end;

procedure ForwardRequest(Req: THorseRequest; Res: THorseResponse);
var
  LMatch: TRouteMatch;
begin
  if not TRouteTable.TryMatch(Req.PathInfo, LMatch) then
    raise ENotFoundException.CreateFmt('Não existe rota pública para %s.', [Req.PathInfo]);
  TProxy.Forward(Req, Res, LMatch);
end;

end.
