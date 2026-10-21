unit LegacySync.CustomerClient;

{ Cliente HTTP da customer-api, do ponto de vista da sincronização. }

interface

uses
  System.JSON,
  Platform.Integration;

type
  TPushOutcome = (poCreated, poUpdated, poRejected);

  TCustomerApiClient = class(TServiceClient)
  public
    constructor Create(const ABaseURL: string; const ATimeout: Integer);
    // Envia o cliente traduzido. Se a customer-api recusar os dados (400,
    // 409, 422), devolve poRejected e o motivo em AProblem. Se ela não
    // responder ou falhar (5xx), lança EServiceUnavailableException: o item
    // volta para a fila e é tentado de novo mais tarde.
    function PushLegacyCustomer(const ALegacyCode: Integer; const ABody: TJSONObject;
      out AProblem: string): TPushOutcome;
  end;

implementation

uses
  System.SysUtils,
  RESTRequest4D;

constructor TCustomerApiClient.Create(const ABaseURL: string; const ATimeout: Integer);
begin
  inherited Create('customer-api', ABaseURL, ATimeout);
end;

// Monta uma frase a partir da resposta Problem Details (capítulo 10):
// "Os dados enviados têm 1 problemas. cpf: O CPF informado não é válido."
function ProblemText(const AContent: string): string;
var
  LJSON: TJSONValue;
  LErrors: TJSONArray;
  LError: TJSONValue;
begin
  Result := AContent;
  LJSON := TJSONObject.ParseJSONValue(AContent);
  if not (LJSON is TJSONObject) then
  begin
    LJSON.Free;
    Exit;
  end;
  try
    Result := TJSONObject(LJSON).GetValue<string>('detail', '');
    if TJSONObject(LJSON).TryGetValue<TJSONArray>('errors', LErrors) then
      for LError in LErrors do
        Result := Result + ' ' + LError.GetValue<string>('field', '') + ': ' +
          LError.GetValue<string>('message', '');
  finally
    LJSON.Free;
  end;
end;

function TCustomerApiClient.PushLegacyCustomer(const ALegacyCode: Integer; const ABody: TJSONObject;
  out AProblem: string): TPushOutcome;
var
  LResponse: IResponse;
begin
  AProblem := '';
  try
    // PUT pode ser repetido sem risco: a customer-api encontra o cliente
    // pelo código do sistema antigo e só atualiza. Por isso, a nova
    // tentativa em falha de rede é segura aqui, ao contrário de um POST.
    LResponse := NewRequest('customers/legacy/' + ALegacyCode.ToString)
      .AddBody(ABody.ToJSON)
      .Retry(1)
      .Put;
  except
    on E: Exception do
    begin
      RaiseUnavailable(E.Message);
      raise; // nunca chega aqui; RaiseUnavailable sempre lança
    end;
  end;
  case LResponse.StatusCode of
    200: Result := poUpdated;
    201: Result := poCreated;
    400, 409, 422:
      begin
        AProblem := ProblemText(LResponse.Content);
        Result := poRejected;
      end;
  else
    RaiseUnavailable(Format('HTTP %d ao enviar o cliente %d', [LResponse.StatusCode, ALegacyCode]));
    Result := poRejected; // nunca chega aqui; evita o aviso do compilador
  end;
end;

end.
