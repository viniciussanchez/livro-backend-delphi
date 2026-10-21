unit TicketApi.Integration.CustomerApi;

{ Cliente HTTP da customer-api. }

interface

uses
  Platform.Integration,
  TicketApi.Partners;

type
  TCustomerApiClient = class(TServiceClient, ICustomerDirectory)
  public
    constructor Create(const ABaseURL: string; const ATimeout: Integer);
    function Exists(const ACustomerId: Integer): Boolean;
  end;

implementation

uses
  System.SysUtils,
  RESTRequest4D;

constructor TCustomerApiClient.Create(const ABaseURL: string; const ATimeout: Integer);
begin
  inherited Create('customer-api', ABaseURL, ATimeout);
end;

function TCustomerApiClient.Exists(const ACustomerId: Integer): Boolean;
var
  LResponse: IResponse;
begin
  LResponse := Get('customers/' + ACustomerId.ToString);
  case LResponse.StatusCode of
    200: Result := True;
    404: Result := False;
  else
    RaiseUnavailable(Format('HTTP %d ao buscar o participante %d', [LResponse.StatusCode, ACustomerId]));
    Result := False; // nunca chega aqui; evita o aviso do compilador
  end;
end;

end.
