unit Platform.Middleware.Errors;

(* Tratamento de erros centralizado. Qualquer exceção que escape de um
  controller vira uma resposta no formato Problem Details (RFC 9457):

    HTTP/1.1 404 Not Found
    Content-Type: application/problem+json

    {"type": "/problems/not-found", "title": "Recurso não encontrado",
     "status": 404, "detail": "Evento não encontrado.",
     "instance": "/events/99", "code": "not-found"} *)

interface

uses
  System.SysUtils,
  Horse;

// Middleware: registre com THorse.Use ANTES do Jhonson.
procedure ErrorHandler(Req: THorseRequest; Res: THorseResponse; Next: TProc);

// Callback do Jhonson para corpo que não é um JSON válido.
procedure InvalidJsonHandler(Res: THorseResponse; const AError: string);

implementation

uses
  System.JSON,
  Platform.Exceptions;

const
  PROBLEM_CONTENT_TYPE = 'application/problem+json; charset=UTF-8';

type
  TProblem = record
    Status: THTTPStatus;
    Title: string;
    Code: string;
    Detail: string;
    Instance: string;
    Errors: TArray<TFieldError>;
    ErrorId: string;
    function ToJSON: string;
  end;

function TProblem.ToJSON: string;
var
  LJSON: TJSONObject;
  LErrors: TJSONArray;
  LError: TFieldError;
  LItem: TJSONObject;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('type', '/problems/' + Code);
    LJSON.AddPair('title', Title);
    LJSON.AddPair('status', TJSONNumber.Create(Integer(Status)));
    LJSON.AddPair('detail', Detail);
    if not Instance.IsEmpty then
      LJSON.AddPair('instance', Instance);
    LJSON.AddPair('code', Code);
    if Length(Errors) > 0 then
    begin
      LErrors := TJSONArray.Create;
      for LError in Errors do
      begin
        LItem := TJSONObject.Create;
        LItem.AddPair('field', LError.Field);
        LItem.AddPair('message', LError.Message);
        LErrors.AddElement(LItem);
      end;
      LJSON.AddPair('errors', LErrors);
    end;
    if not ErrorId.IsEmpty then
      LJSON.AddPair('errorId', ErrorId);
    // Mantém os acentos legíveis, como o Jhonson faz com UTF-8.
    Result := LJSON.ToJSON([TJSONValue.TJSONOutputOption.EncodeBelow32]);
  finally
    LJSON.Free;
  end;
end;

procedure SendProblem(const ARes: THorseResponse; const AProblem: TProblem);
begin
  ARes.Status(AProblem.Status)
    .ContentType(PROBLEM_CONTENT_TYPE)
    .Send(AProblem.ToJSON);
end;

// Traduz a família da exceção de domínio em status HTTP e título.
procedure DescribeDomainError(const E: EDomainException; var AProblem: TProblem);
begin
  if E is EValidationException then
  begin
    AProblem.Status := THTTPStatus.BadRequest;
    AProblem.Title := 'Dados inválidos';
    AProblem.Errors := EValidationException(E).Errors;
  end
  else if E is ENotFoundException then
  begin
    AProblem.Status := THTTPStatus.NotFound;
    AProblem.Title := 'Recurso não encontrado';
  end
  else if E is EConflictException then
  begin
    AProblem.Status := THTTPStatus.Conflict;
    AProblem.Title := 'Conflito com o estado atual';
  end
  else if E is EServiceUnavailableException then
  begin
    AProblem.Status := THTTPStatus.ServiceUnavailable;
    AProblem.Title := 'Serviço indisponível';
  end
  else
  begin
    // EBusinessRuleException e qualquer outra exceção de domínio.
    AProblem.Status := THTTPStatus.UnprocessableEntity;
    AProblem.Title := 'Regra de negócio não atendida';
  end;
  AProblem.Code := E.Code;
  AProblem.Detail := E.Message;
end;

function NewErrorId: string;
begin
  // 8 caracteres bastam para achar a ocorrência no log.
  Result := TGUID.NewGuid.ToString.Substring(1, 8).ToLower;
end;

procedure ErrorHandler(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LProblem: TProblem;
begin
  try
    Next;
  except
    // O Jhonson (ou outro middleware) já respondeu e só quer interromper
    // a cadeia. Essa exceção precisa seguir o seu caminho.
    on E: EHorseCallbackInterrupted do
      raise;

    on E: EDomainException do
    begin
      LProblem := Default(TProblem);
      DescribeDomainError(E, LProblem);
      LProblem.Instance := Req.PathInfo;
      // Diz ao cliente quando vale a pena tentar de novo, em segundos.
      if E is EServiceUnavailableException then
        Res.AddHeader('Retry-After', '5');
      SendProblem(Res, LProblem);
    end;

    // Erros que o próprio Horse levanta, como um parâmetro com tipo errado.
    on E: EHorseException do
    begin
      LProblem := Default(TProblem);
      LProblem.Status := E.Status;
      LProblem.Title := 'Requisição inválida';
      LProblem.Code := 'bad-request';
      LProblem.Detail := E.Error;
      if LProblem.Detail.IsEmpty then
        LProblem.Detail := E.Message;
      LProblem.Instance := Req.PathInfo;
      SendProblem(Res, LProblem);
    end;

    // Qualquer outra coisa é um erro nosso: um bug, o banco fora do ar...
    // O cliente recebe uma mensagem genérica; os detalhes vão para o log.
    on E: Exception do
    begin
      LProblem := Default(TProblem);
      LProblem.Status := THTTPStatus.InternalServerError;
      LProblem.Title := 'Erro interno';
      LProblem.Code := 'internal-error';
      LProblem.Detail := 'Ocorreu um erro inesperado. Se persistir, informe o código errorId ao suporte.';
      LProblem.Instance := Req.PathInfo;
      LProblem.ErrorId := NewErrorId;
      Writeln(Format('[%s] %s %s %s -> %s: %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now),
        LProblem.ErrorId, Req.RawWebRequest.Method, Req.PathInfo, E.ClassName, E.Message]));
      Flush(Output);
      SendProblem(Res, LProblem);
    end;
  end;
end;

procedure InvalidJsonHandler(Res: THorseResponse; const AError: string);
var
  LProblem: TProblem;
begin
  LProblem := Default(TProblem);
  LProblem.Status := THTTPStatus.BadRequest;
  LProblem.Title := 'JSON inválido';
  LProblem.Code := 'invalid-json';
  LProblem.Detail := 'O corpo da requisição não é um JSON válido.';
  SendProblem(Res, LProblem);
  // Depois deste callback, o Jhonson interrompe a requisição sozinho.
end;

end.
