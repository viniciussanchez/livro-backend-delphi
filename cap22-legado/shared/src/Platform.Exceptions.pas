unit Platform.Exceptions;

{ Exceções de domínio compartilhadas pelos serviços da plataforma.
  Nenhuma delas sabe o que é HTTP: a tradução para status e para o
  formato Problem Details fica em Platform.Middleware.Errors. }

interface

uses
  System.SysUtils;

type
  // Um problema em um campo específico da requisição.
  TFieldError = record
    Field: string;
    Message: string;
    class function New(const AField, AMessage: string): TFieldError; static;
  end;

  EDomainException = class(Exception)
  protected
    // Código estável, em inglês, que o cliente da API pode usar no "if".
    // A mensagem pode mudar de texto; o código não muda.
    class function DefaultCode: string; virtual;
  public
    function Code: string;
  end;

  // Dados de entrada inválidos (campo vazio, formato errado...).
  EValidationException = class(EDomainException)
  private
    FErrors: TArray<TFieldError>;
  protected
    class function DefaultCode: string; override;
  public
    // Vários campos inválidos de uma só vez.
    constructor CreateWithErrors(const AErrors: TArray<TFieldError>);
    // Um único campo inválido.
    constructor CreateForField(const AField, AMessage: string);
    property Errors: TArray<TFieldError> read FErrors;
  end;

  // O registro procurado não existe.
  ENotFoundException = class(EDomainException)
  protected
    class function DefaultCode: string; override;
  end;

  // A operação conflita com o estado atual (duplicidade, estado incompatível...).
  EConflictException = class(EDomainException)
  protected
    class function DefaultCode: string; override;
  end;

  // Os dados são válidos, mas violam uma regra de negócio.
  EBusinessRuleException = class(EDomainException)
  protected
    class function DefaultCode: string; override;
  end;

  // Falta o token, ou ele é inválido ou expirou (capítulo 13).
  EUnauthorizedException = class(EDomainException)
  protected
    class function DefaultCode: string; override;
  end;

  // O token é válido, mas não dá permissão para a operação (capítulo 13).
  EForbiddenException = class(EDomainException)
  protected
    class function DefaultCode: string; override;
  end;

  // Um serviço do qual dependemos não respondeu a tempo (capítulo 12).
  // Não é culpa de quem chamou: vale tentar de novo mais tarde.
  EServiceUnavailableException = class(EDomainException)
  protected
    class function DefaultCode: string; override;
  end;

  // O gateway recebeu uma resposta inválida, ou nenhuma, do serviço
  // para o qual encaminhou a requisição (capítulo 16).
  EBadGatewayException = class(EDomainException)
  protected
    class function DefaultCode: string; override;
  end;

  // O serviço de destino demorou mais do que o gateway aceita esperar (capítulo 16).
  EGatewayTimeoutException = class(EDomainException)
  protected
    class function DefaultCode: string; override;
  end;

  // O cliente fez requisições demais em pouco tempo (capítulo 16).
  ETooManyRequestsException = class(EDomainException)
  private
    FRetryAfter: Integer;
  protected
    class function DefaultCode: string; override;
  public
    constructor Create(const AMessage: string; const ARetryAfter: Integer);
    // Em quantos segundos o cliente pode tentar de novo.
    property RetryAfter: Integer read FRetryAfter;
  end;

implementation

{ TFieldError }

class function TFieldError.New(const AField, AMessage: string): TFieldError;
begin
  Result.Field := AField;
  Result.Message := AMessage;
end;

{ EDomainException }

class function EDomainException.DefaultCode: string;
begin
  Result := 'domain-error';
end;

function EDomainException.Code: string;
begin
  Result := DefaultCode;
end;

{ EValidationException }

class function EValidationException.DefaultCode: string;
begin
  Result := 'validation-error';
end;

constructor EValidationException.CreateWithErrors(const AErrors: TArray<TFieldError>);
begin
  if Length(AErrors) = 1 then
    inherited Create(AErrors[0].Message)
  else
    inherited CreateFmt('Os dados enviados têm %d problemas.', [Length(AErrors)]);
  FErrors := AErrors;
end;

constructor EValidationException.CreateForField(const AField, AMessage: string);
begin
  CreateWithErrors([TFieldError.New(AField, AMessage)]);
end;

{ ENotFoundException }

class function ENotFoundException.DefaultCode: string;
begin
  Result := 'not-found';
end;

{ EConflictException }

class function EConflictException.DefaultCode: string;
begin
  Result := 'conflict';
end;

{ EBusinessRuleException }

class function EBusinessRuleException.DefaultCode: string;
begin
  Result := 'business-rule';
end;

{ EUnauthorizedException }

class function EUnauthorizedException.DefaultCode: string;
begin
  Result := 'unauthorized';
end;

{ EForbiddenException }

class function EForbiddenException.DefaultCode: string;
begin
  Result := 'forbidden';
end;

{ EServiceUnavailableException }

class function EServiceUnavailableException.DefaultCode: string;
begin
  Result := 'service-unavailable';
end;

{ EBadGatewayException }

class function EBadGatewayException.DefaultCode: string;
begin
  Result := 'bad-gateway';
end;

{ EGatewayTimeoutException }

class function EGatewayTimeoutException.DefaultCode: string;
begin
  Result := 'gateway-timeout';
end;

{ ETooManyRequestsException }

class function ETooManyRequestsException.DefaultCode: string;
begin
  Result := 'too-many-requests';
end;

constructor ETooManyRequestsException.Create(const AMessage: string; const ARetryAfter: Integer);
begin
  inherited Create(AMessage);
  FRetryAfter := ARetryAfter;
end;

end.
