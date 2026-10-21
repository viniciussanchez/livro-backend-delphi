program CustomerApi;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  Horse.GBSwagger,
  Platform.Exceptions in '..\shared\src\Platform.Exceptions.pas',
  Platform.Dates in '..\shared\src\Platform.Dates.pas',
  Platform.Validation in '..\shared\src\Platform.Validation.pas',
  Platform.Http in '..\shared\src\Platform.Http.pas',
  Platform.Middleware.Errors in '..\shared\src\Platform.Middleware.Errors.pas',
  Platform.Docs in '..\shared\src\Platform.Docs.pas',
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
  CustomerApi.Docs in 'src\Docs\CustomerApi.Docs.pas',
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

  // A ordem importa: o tratamento de erros vem primeiro para "abraçar"
  // todo o resto, inclusive o Jhonson.
  THorse.Use(ErrorHandler);
  THorse.Use(Jhonson('UTF-8', InvalidJsonHandler));

  // Documentação: http://localhost:9002/swagger/doc/html
  CustomerApi.Docs.Configure;
  THorse.Use(HorseSwagger);

  CustomerApi.Controller.Customer.Registry;

  THorse.Listen(9002,
    procedure
    begin
      Writeln(Format('customer-api rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
