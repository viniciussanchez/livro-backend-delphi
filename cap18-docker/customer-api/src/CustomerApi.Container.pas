unit CustomerApi.Container;

{ Composition root da customer-api. }

interface

uses
  CustomerApi.Service.Customer,
  CustomerApi.Service.Auth;

const
  CUSTOMER_DB = 'customer_db';

function CustomerService: ICustomerService;
function AuthService: IAuthService;

implementation

uses
  Platform.Database,
  CustomerApi.Repository.Customer.FireDAC,
  CustomerApi.Repository.User.FireDAC;

function CustomerService: ICustomerService;
var
  LSession: IDbSession;
begin
  // A mesma sessão serve aos dois repositórios e à transação do cadastro.
  LSession := TDatabase.NewSession(CUSTOMER_DB);
  Result := TCustomerService.Create(
    TCustomerRepositoryFireDAC.Create(LSession),
    TUserRepositoryFireDAC.Create(LSession),
    LSession);
end;

function AuthService: IAuthService;
begin
  Result := TAuthService.Create(TUserRepositoryFireDAC.Create(TDatabase.NewSession(CUSTOMER_DB)));
end;

end.
