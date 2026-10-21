program CustomerApi;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  Platform.Exceptions in '..\shared\src\Platform.Exceptions.pas',
  Platform.Dates in '..\shared\src\Platform.Dates.pas',
  Platform.Http in '..\shared\src\Platform.Http.pas',
  Platform.Transactions in '..\shared\src\Platform.Transactions.pas',
  Platform.Database in '..\shared\src\Platform.Database.pas',
  Platform.Migrations in '..\shared\src\Platform.Migrations.pas',
  Platform.Repository in '..\shared\src\Platform.Repository.pas',
  CustomerApi.Entity.Customer in 'src\Domain\CustomerApi.Entity.Customer.pas',
  CustomerApi.Cpf in 'src\Domain\CustomerApi.Cpf.pas',
  CustomerApi.DTO.Customer in 'src\DTO\CustomerApi.DTO.Customer.pas',
  CustomerApi.Repository.Customer in 'src\Repository\CustomerApi.Repository.Customer.pas',
  CustomerApi.Repository.Customer.FireDAC in 'src\Repository\CustomerApi.Repository.Customer.FireDAC.pas',
  CustomerApi.Service.Customer in 'src\Service\CustomerApi.Service.Customer.pas',
  CustomerApi.Controller.Customer in 'src\Controller\CustomerApi.Controller.Customer.pas',
  CustomerApi.Migrations in 'src\CustomerApi.Migrations.pas',
  CustomerApi.Container in 'src\CustomerApi.Container.pas';

begin
  try
    TDatabase.Configure(CUSTOMER_DB, 'customer_db', 'customer-api');
    TMigrator.Run(CUSTOMER_DB, CustomerApi.Migrations.Migrations);
  except
    on E: Exception do
    begin
      Writeln('Falha ao preparar o banco de dados: ' + E.Message);
      ExitCode := 1;
      Exit;
    end;
  end;

  THorse.Use(Jhonson);

  CustomerApi.Controller.Customer.Registry;

  THorse.Listen(9002,
    procedure
    begin
      Writeln(Format('customer-api rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
