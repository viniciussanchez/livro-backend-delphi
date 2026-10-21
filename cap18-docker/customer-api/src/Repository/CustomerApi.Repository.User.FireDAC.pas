unit CustomerApi.Repository.User.FireDAC;

interface

uses
  Platform.Repository,
  CustomerApi.Repository.User;

type
  TUserRepositoryFireDAC = class(TFireDACRepository, IUserRepository)
  public
    function FindByCredentials(const AEmail, APassword: string; out AAccount: TUserAccount): Boolean;
    procedure Insert(const AEmail, APassword, ARole: string; const ACustomerId: Integer;
      const ANow: TDateTime);
    function EmailInUse(const AEmail: string): Boolean;
    function AdminExists: Boolean;
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

function TUserRepositoryFireDAC.FindByCredentials(const AEmail, APassword: string;
  out AAccount: TUserAccount): Boolean;
var
  LQuery: TFDQuery;
begin
  AAccount := Default(TUserAccount);
  // Participantes entram com o e-mail do cadastro (que pode mudar no PUT);
  // a equipe, com o e-mail da própria conta. Anonimizados não entram mais.
  // crypt(senha, hash) refaz o bcrypt com o sal guardado dentro do hash.
  LQuery := NewQuery(
    'select u.id, u.role, coalesce(u.customer_id, 0) as customer_id' +
    '  from app_user u' +
    '  left join customer c on c.id = u.customer_id' +
    ' where lower(coalesce(c.email, u.email)) = lower(:email)' +
    '   and c.anonymized_at is null' +
    '   and u.password_hash = crypt(:password, u.password_hash)');
  try
    LQuery.ParamByName('email').AsString := AEmail;
    LQuery.ParamByName('password').AsString := APassword;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
    if Result then
    begin
      AAccount.Id := LQuery.FieldByName('id').AsInteger;
      AAccount.Role := LQuery.FieldByName('role').AsString;
      AAccount.CustomerId := LQuery.FieldByName('customer_id').AsInteger;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TUserRepositoryFireDAC.Insert(const AEmail, APassword, ARole: string;
  const ACustomerId: Integer; const ANow: TDateTime);
var
  LQuery: TFDQuery;
begin
  // gen_salt('bf', 10): bcrypt com custo 10. Cada senha ganha um sal
  // aleatório, e o custo deixa cada tentativa de adivinhação lenta.
  LQuery := NewQuery(
    'insert into app_user (email, password_hash, role, customer_id, created_at)' +
    ' values (nullif(:email, ''''), crypt(:password, gen_salt(''bf'', 10)), :role,' +
    '         nullif(:customer_id, 0), :now)');
  try
    LQuery.ParamByName('email').AsString := AEmail;
    LQuery.ParamByName('password').AsString := APassword;
    LQuery.ParamByName('role').AsString := ARole;
    LQuery.ParamByName('customer_id').AsInteger := ACustomerId;
    LQuery.ParamByName('now').AsDateTime := ANow;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TUserRepositoryFireDAC.EmailInUse(const AEmail: string): Boolean;
begin
  Result := Connection.ExecSQLScalar(
    'select exists (select 1 from app_user where lower(email) = lower(:e1))' +
    '    or exists (select 1 from customer where lower(email) = lower(:e2) and anonymized_at is null)',
    [AEmail, AEmail]);
end;

function TUserRepositoryFireDAC.AdminExists: Boolean;
begin
  Result := Connection.ExecSQLScalar('select exists (select 1 from app_user where role = ''admin'')');
end;

end.
