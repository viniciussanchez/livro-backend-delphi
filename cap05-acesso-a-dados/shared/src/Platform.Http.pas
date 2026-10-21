unit Platform.Http;

{ Peças da camada HTTP que todos os controllers usam. }

interface

uses
  System.SysUtils,
  System.JSON,
  Horse;

procedure SendError(const ARes: THorseResponse; const AStatus: THTTPStatus; const AMessage: string);

// Executa o handler e traduz as exceções de domínio em status HTTP.
// No capítulo 10 isto vira um middleware.
procedure HandleErrors(const ARes: THorseResponse; const AAction: TProc);

// Converte um parâmetro de rota em inteiro ou lança EValidationException.
function ParseId(const AValue: string): Integer;

// Devolve o corpo da requisição como objeto JSON ou lança EValidationException.
function RequestBody(const AReq: THorseRequest): TJSONObject;

implementation

uses
  Platform.Exceptions;

procedure SendError(const ARes: THorseResponse; const AStatus: THTTPStatus; const AMessage: string);
var
  LError: TJSONObject;
begin
  LError := TJSONObject.Create;
  LError.AddPair('message', AMessage);
  ARes.Status(AStatus).Send<TJSONObject>(LError);
end;

procedure HandleErrors(const ARes: THorseResponse; const AAction: TProc);
begin
  try
    AAction();
  except
    on E: EValidationException do
      SendError(ARes, THTTPStatus.BadRequest, E.Message);
    on E: ENotFoundException do
      SendError(ARes, THTTPStatus.NotFound, E.Message);
    on E: EConflictException do
      SendError(ARes, THTTPStatus.Conflict, E.Message);
    on E: EBusinessRuleException do
      SendError(ARes, THTTPStatus.UnprocessableEntity, E.Message);
  end;
end;

function ParseId(const AValue: string): Integer;
begin
  if not TryStrToInt(AValue, Result) or (Result <= 0) then
    raise EValidationException.Create('O id informado deve ser um número inteiro positivo.');
end;

function RequestBody(const AReq: THorseRequest): TJSONObject;
begin
  // O Jhonson só converte o body quando o Content-Type é application/json.
  if not (AReq.Body<TJSONValue> is TJSONObject) then
    raise EValidationException.Create('Envie os dados como um objeto JSON.');
  Result := AReq.Body<TJSONObject>;
end;

end.
