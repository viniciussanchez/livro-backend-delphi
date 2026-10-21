unit Platform.Http;

{ Peças da camada HTTP que todos os controllers usam.
  O tratamento de erros saiu daqui no capítulo 10: agora é o
  middleware de Platform.Middleware.Errors. }

interface

uses
  System.JSON,
  Horse;

// Converte um parâmetro de rota em inteiro ou lança EValidationException.
function ParseId(const AValue: string; const AField: string = 'id'): Integer;

// Devolve o corpo da requisição como objeto JSON ou lança EValidationException.
function RequestBody(const AReq: THorseRequest): TJSONObject;

implementation

uses
  System.SysUtils,
  Platform.Exceptions;

function ParseId(const AValue: string; const AField: string): Integer;
begin
  if not TryStrToInt(AValue, Result) or (Result <= 0) then
    raise EValidationException.CreateForField(AField,
      Format('O campo %s deve ser um número inteiro positivo.', [AField]));
end;

function RequestBody(const AReq: THorseRequest): TJSONObject;
begin
  // O Jhonson só converte o body quando o Content-Type é application/json.
  if not (AReq.Body<TJSONValue> is TJSONObject) then
    raise EValidationException.Create('Envie os dados como um objeto JSON, com o cabeçalho Content-Type: application/json.');
  Result := AReq.Body<TJSONObject>;
end;

end.
