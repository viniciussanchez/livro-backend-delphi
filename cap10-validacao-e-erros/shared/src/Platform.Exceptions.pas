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

end.
