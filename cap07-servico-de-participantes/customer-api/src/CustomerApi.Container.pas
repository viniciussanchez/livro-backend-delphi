unit CustomerApi.Container;

{ Composition root da customer-api. }

interface

uses
  CustomerApi.Service.Customer;

const
  CUSTOMER_DB = 'customer_db';

function CustomerService: ICustomerService;

implementation

uses
  Platform.Database,
  CustomerApi.Repository.Customer.FireDAC;

function CustomerService: ICustomerService;
begin
  Result := TCustomerService.Create(
    TCustomerRepositoryFireDAC.Create(TDatabase.NewSession(CUSTOMER_DB)));
end;

end.
