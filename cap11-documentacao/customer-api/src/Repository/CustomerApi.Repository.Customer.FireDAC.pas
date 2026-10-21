unit CustomerApi.Repository.Customer.FireDAC;

interface

uses
  Platform.Repository,
  CustomerApi.Entity.Customer,
  CustomerApi.Repository.Customer;

type
  TCustomerRepositoryFireDAC = class(TFireDACRepository, ICustomerRepository)
  private
    function FindOne(const AWhere: string; const AValue: Variant): TCustomer;
  public
    function FindById(const AId: Integer): TCustomer;
    function FindByCpf(const ACpf: string): TCustomer;
    function FindByEmail(const AEmail: string): TCustomer;
    function EmailInUse(const AEmail: string; const AExceptId: Integer = 0): Boolean;
    function CpfInUse(const ACpf: string): Boolean;
    procedure Insert(const ACustomer: TCustomer);
    procedure Update(const ACustomer: TCustomer);
    function Anonymize(const AId: Integer; const AWhen: TDateTime): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.Comp.Client,
  Platform.Exceptions;

const
  SELECT_CUSTOMER =
    'select id, name, cpf, email, phone, birth_date, created_at, updated_at' +
    '  from customer' +
    ' where anonymized_at is null';

function ToEntity(const AQuery: TFDQuery): TCustomer;
begin
  Result := TCustomer.Create;
  Result.Id := AQuery.FieldByName('id').AsInteger;
  Result.Name := AQuery.FieldByName('name').AsString;
  Result.Cpf := AQuery.FieldByName('cpf').AsString.Trim;
  Result.Email := AQuery.FieldByName('email').AsString;
  Result.Phone := AQuery.FieldByName('phone').AsString;
  if not AQuery.FieldByName('birth_date').IsNull then
    Result.BirthDate := AQuery.FieldByName('birth_date').AsDateTime;
  Result.CreatedAt := AQuery.FieldByName('created_at').AsDateTime;
  Result.UpdatedAt := AQuery.FieldByName('updated_at').AsDateTime;
end;

// Campo opcional: string vazia vira null no banco.
procedure SetNullableString(const AParam: TFDParam; const AValue: string);
begin
  AParam.DataType := ftWideString;
  if AValue.IsEmpty then
    AParam.Clear
  else
    AParam.AsWideString := AValue;
end;

procedure SetNullableDate(const AParam: TFDParam; const AValue: TDate);
begin
  AParam.DataType := ftDate;
  if AValue = 0 then
    AParam.Clear
  else
    AParam.AsDate := AValue;
end;

// Traduz a violação dos índices únicos (CPF ou e-mail) em uma exceção de domínio.
procedure RaiseIfUniqueViolation(const E: EFDDBEngineException);
begin
  if E.Kind = ekUKViolated then
    raise EConflictException.Create('Já existe um participante com este CPF ou e-mail.');
end;

function TCustomerRepositoryFireDAC.FindOne(const AWhere: string; const AValue: Variant): TCustomer;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := NewQuery(SELECT_CUSTOMER + ' and ' + AWhere);
  try
    LQuery.Params[0].Value := AValue;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := ToEntity(LQuery);
  finally
    LQuery.Free;
  end;
end;

function TCustomerRepositoryFireDAC.FindById(const AId: Integer): TCustomer;
begin
  Result := FindOne('id = :id', AId);
end;

function TCustomerRepositoryFireDAC.FindByCpf(const ACpf: string): TCustomer;
begin
  Result := FindOne('cpf = :cpf', ACpf);
end;

function TCustomerRepositoryFireDAC.FindByEmail(const AEmail: string): TCustomer;
begin
  Result := FindOne('lower(email) = lower(:email)', AEmail);
end;

function TCustomerRepositoryFireDAC.EmailInUse(const AEmail: string; const AExceptId: Integer): Boolean;
begin
  Result := Connection.ExecSQLScalar(
    'select count(*) from customer ' +
    ' where anonymized_at is null and lower(email) = lower(:email) and id <> :id',
    [AEmail, AExceptId]) > 0;
end;

function TCustomerRepositoryFireDAC.CpfInUse(const ACpf: string): Boolean;
begin
  Result := Connection.ExecSQLScalar(
    'select count(*) from customer where anonymized_at is null and cpf = :cpf', [ACpf]) > 0;
end;

procedure TCustomerRepositoryFireDAC.Insert(const ACustomer: TCustomer);
var
  LQuery: TFDQuery;
begin
  LQuery := NewQuery(
    'insert into customer (name, cpf, email, phone, birth_date, created_at, updated_at) ' +
    'values (:name, :cpf, :email, :phone, :birth_date, :created_at, :updated_at) returning id');
  try
    LQuery.ParamByName('name').AsString := ACustomer.Name;
    LQuery.ParamByName('cpf').AsString := ACustomer.Cpf;
    LQuery.ParamByName('email').AsString := ACustomer.Email;
    SetNullableString(LQuery.ParamByName('phone'), ACustomer.Phone);
    SetNullableDate(LQuery.ParamByName('birth_date'), ACustomer.BirthDate);
    LQuery.ParamByName('created_at').AsDateTime := ACustomer.CreatedAt;
    LQuery.ParamByName('updated_at').AsDateTime := ACustomer.UpdatedAt;
    try
      LQuery.Open;
    except
      on E: EFDDBEngineException do
      begin
        RaiseIfUniqueViolation(E);
        raise;
      end;
    end;
    ACustomer.Id := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

procedure TCustomerRepositoryFireDAC.Update(const ACustomer: TCustomer);
var
  LQuery: TFDQuery;
begin
  LQuery := NewQuery(
    'update customer set name = :name, email = :email, phone = :phone,' +
    '       birth_date = :birth_date, updated_at = :updated_at' +
    ' where id = :id and anonymized_at is null');
  try
    LQuery.ParamByName('name').AsString := ACustomer.Name;
    LQuery.ParamByName('email').AsString := ACustomer.Email;
    SetNullableString(LQuery.ParamByName('phone'), ACustomer.Phone);
    SetNullableDate(LQuery.ParamByName('birth_date'), ACustomer.BirthDate);
    LQuery.ParamByName('updated_at').AsDateTime := ACustomer.UpdatedAt;
    LQuery.ParamByName('id').AsInteger := ACustomer.Id;
    try
      LQuery.ExecSQL;
    except
      on E: EFDDBEngineException do
      begin
        RaiseIfUniqueViolation(E);
        raise;
      end;
    end;
  finally
    LQuery.Free;
  end;
end;

function TCustomerRepositoryFireDAC.Anonymize(const AId: Integer; const AWhen: TDateTime): Boolean;
begin
  // Os dados pessoais são apagados de fato; fica só o id, para que registros
  // de outros serviços (como os ingressos) continuem apontando para algo.
  Result := Connection.ExecSQL(
    'update customer' +
    '   set name = ''Participante removido'', cpf = null, email = null, phone = null,' +
    '       birth_date = null, anonymized_at = :anonymized_at, updated_at = :updated_at' +
    ' where id = :id and anonymized_at is null',
    [AWhen, AWhen, AId]) > 0;
end;

end.
