unit Platform.Validation;

{ Acumula os problemas de validação de uma requisição para devolver
  todos de uma vez, em vez de parar no primeiro.

  Uso:
    var LValidation: TValidation;
    LValidation.Check(not AName.IsEmpty, 'name', 'Informe o nome.');
    LValidation.Check(AQuantity > 0, 'quantity', 'A quantidade deve ser maior que zero.');
    LValidation.RaiseIfInvalid; }

interface

uses
  Platform.Exceptions;

type
  TValidation = record
  private
    FErrors: TArray<TFieldError>;
  public
    procedure Add(const AField, AMessage: string);
    // Registra o erro quando a condição é falsa. Devolve a própria condição,
    // para encadear verificações que dependem desta.
    function Check(const ACondition: Boolean; const AField, AMessage: string): Boolean;
    function HasErrors: Boolean;
    function HasError(const AField: string): Boolean;
    procedure RaiseIfInvalid;
  end;

implementation

uses
  System.SysUtils;

procedure TValidation.Add(const AField, AMessage: string);
begin
  FErrors := FErrors + [TFieldError.New(AField, AMessage)];
end;

function TValidation.Check(const ACondition: Boolean; const AField, AMessage: string): Boolean;
begin
  Result := ACondition;
  if not Result then
    Add(AField, AMessage);
end;

function TValidation.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

function TValidation.HasError(const AField: string): Boolean;
var
  LError: TFieldError;
begin
  for LError in FErrors do
    if SameText(LError.Field, AField) then
      Exit(True);
  Result := False;
end;

procedure TValidation.RaiseIfInvalid;
begin
  if HasErrors then
    raise EValidationException.CreateWithErrors(FErrors);
end;

end.
