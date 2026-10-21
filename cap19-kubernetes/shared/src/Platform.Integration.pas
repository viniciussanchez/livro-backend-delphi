unit Platform.Integration;

{ Base para chamar outros serviços da plataforma por HTTP, com o
  RESTRequest4Delphi. Concentra aqui as decisões que valem para toda
  chamada entre serviços: tempo limite, nova tentativa e o que fazer
  quando o outro lado não responde. }

interface

uses
  RESTRequest4D;

type
  TServiceClient = class(TInterfacedObject)
  private
    FServiceName: string;
    FBaseURL: string;
    // Quanto esperamos por outro serviço, em milissegundos. Uma tela de compra
    // não pode ficar presa: é melhor falhar rápido e avisar.
    FTimeout: Integer;
  protected
    // Requisição já configurada para o serviço: endereço, JSON e tempo limite.
    function NewRequest(const AResource: string): IRequest;
    // GET com uma nova tentativa em falha de rede. Se o serviço não responder,
    // lança EServiceUnavailableException. Respostas HTTP (200, 404...) voltam
    // normalmente para quem chamou decidir.
    function Get(const AResource: string): IResponse;
    procedure RaiseUnavailable(const ADetail: string);
  public
    constructor Create(const AServiceName, ABaseURL: string; const ATimeout: Integer);
    property ServiceName: string read FServiceName;
  end;

implementation

uses
  System.SysUtils,
  Platform.Exceptions,
  Platform.Auth;

constructor TServiceClient.Create(const AServiceName, ABaseURL: string; const ATimeout: Integer);
begin
  inherited Create;
  FServiceName := AServiceName;
  FBaseURL := ABaseURL;
  FTimeout := ATimeout;
end;

function TServiceClient.NewRequest(const AResource: string): IRequest;
begin
  Result := TRequest.New
    .BaseURL(FBaseURL)
    .Resource(AResource)
    .Accept('application/json')
    // Os outros serviços exigem autenticação (capítulo 13): cada chamada
    // leva o token deste serviço, com o papel "service".
    .TokenBearer(ServiceToken)
    .Timeout(FTimeout);
end;

function TServiceClient.Get(const AResource: string): IResponse;
begin
  try
    // GET pode ser repetido sem efeito colateral: uma segunda tentativa
    // cobre a falha passageira de rede, sem risco de duplicar nada.
    Result := NewRequest(AResource).Retry(1).Get;
  except
    on E: Exception do
      RaiseUnavailable(E.Message);
  end;
  // 5xx: o outro serviço respondeu, mas está com problemas.
  if Result.StatusCode >= 500 then
    RaiseUnavailable(Format('HTTP %d', [Result.StatusCode]));
end;

procedure TServiceClient.RaiseUnavailable(const ADetail: string);
begin
  Writeln(Format('[%s] %s indisponível: %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), FServiceName, ADetail]));
  Flush(Output);
  raise EServiceUnavailableException.CreateFmt(
    'O serviço %s não respondeu. Tente novamente em alguns segundos.', [FServiceName]);
end;

end.
