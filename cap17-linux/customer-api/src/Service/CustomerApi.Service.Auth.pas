unit CustomerApi.Service.Auth;

{ Login e contas da equipe. A customer-api é quem emite os tokens da
  plataforma: ela conhece as pessoas e as senhas. }

interface

uses
  CustomerApi.Repository.User;

const
  MIN_PASSWORD_LENGTH = 8;

type
  TTokenResult = record
    AccessToken: string;
    ExpiresIn: Integer;
    Role: string;
  end;

  IAuthService = interface
    ['{C4E2A9B7-3F15-4D80-A6E9-21B7F5C3D084}']
    function Login(const AEmail, APassword: string): TTokenResult;
    procedure CreateStaff(const AEmail, APassword, ARole: string);
    // Cria o primeiro administrador, se ainda não houver nenhum.
    function EnsureAdmin(const AEmail, APassword: string): Boolean;
  end;

  TAuthService = class(TInterfacedObject, IAuthService)
  private
    FUsers: IUserRepository;
  public
    constructor Create(const AUsers: IUserRepository);
    function Login(const AEmail, APassword: string): TTokenResult;
    procedure CreateStaff(const AEmail, APassword, ARole: string);
    function EnsureAdmin(const AEmail, APassword: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  Platform.Exceptions,
  Platform.Validation,
  Platform.Auth;

constructor TAuthService.Create(const AUsers: IUserRepository);
begin
  inherited Create;
  FUsers := AUsers;
end;

function TAuthService.Login(const AEmail, APassword: string): TTokenResult;
var
  LAccount: TUserAccount;
begin
  // Mesma mensagem para e-mail inexistente e senha errada: quem tenta
  // adivinhar não descobre quais e-mails estão cadastrados.
  if AEmail.IsEmpty or APassword.IsEmpty or
     not FUsers.FindByCredentials(AEmail.Trim, APassword, LAccount) then
    raise EUnauthorizedException.Create('E-mail ou senha inválidos.');

  Result.AccessToken := IssueToken(LAccount.Id.ToString, LAccount.Role,
    LAccount.CustomerId, USER_TOKEN_SECONDS);
  Result.ExpiresIn := USER_TOKEN_SECONDS;
  Result.Role := LAccount.Role;
end;

procedure TAuthService.CreateStaff(const AEmail, APassword, ARole: string);
var
  LValidation: TValidation;
begin
  LValidation.Check(TRegEx.IsMatch(AEmail, '^[^@\s]+@[^@\s]+\.[^@\s]+$'), 'email', 'Informe um e-mail válido.');
  LValidation.Check(APassword.Length >= MIN_PASSWORD_LENGTH, 'password',
    Format('A senha deve ter pelo menos %d caracteres.', [MIN_PASSWORD_LENGTH]));
  LValidation.Check(SameText(ARole, ROLE_ADMIN) or SameText(ARole, ROLE_STAFF), 'role',
    'O papel deve ser admin ou staff.');
  LValidation.RaiseIfInvalid;

  if FUsers.EmailInUse(AEmail) then
    raise EConflictException.Create('Este e-mail já está em uso.');
  FUsers.Insert(AEmail.ToLower, APassword, ARole.ToLower, 0, Now);
end;

function TAuthService.EnsureAdmin(const AEmail, APassword: string): Boolean;
begin
  Result := not FUsers.AdminExists;
  if Result then
    FUsers.Insert(AEmail.ToLower, APassword, ROLE_ADMIN, 0, Now);
end;

end.
