program CustomerApi;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  Horse.GBSwagger,
  Platform.Exceptions in '..\shared\src\Platform.Exceptions.pas',
  Platform.Config in '..\shared\src\Platform.Config.pas',
  Platform.Dates in '..\shared\src\Platform.Dates.pas',
  Platform.Validation in '..\shared\src\Platform.Validation.pas',
  Platform.Http in '..\shared\src\Platform.Http.pas',
  Platform.Middleware.Errors in '..\shared\src\Platform.Middleware.Errors.pas',
  Platform.Docs in '..\shared\src\Platform.Docs.pas',
  Platform.Jwt in '..\shared\src\Platform.Jwt.pas',
  Platform.Auth in '..\shared\src\Platform.Auth.pas',
  Platform.Transactions in '..\shared\src\Platform.Transactions.pas',
  Platform.Database in '..\shared\src\Platform.Database.pas',
  Platform.Migrations in '..\shared\src\Platform.Migrations.pas',
  Platform.Repository in '..\shared\src\Platform.Repository.pas',
  Platform.Health in '..\shared\src\Platform.Health.pas',
  CustomerApi.Entity.Customer in 'src\Domain\CustomerApi.Entity.Customer.pas',
  CustomerApi.Cpf in 'src\Domain\CustomerApi.Cpf.pas',
  CustomerApi.DTO.Customer in 'src\DTO\CustomerApi.DTO.Customer.pas',
  CustomerApi.Repository.Customer in 'src\Repository\CustomerApi.Repository.Customer.pas',
  CustomerApi.Repository.Customer.FireDAC in 'src\Repository\CustomerApi.Repository.Customer.FireDAC.pas',
  CustomerApi.Repository.User in 'src\Repository\CustomerApi.Repository.User.pas',
  CustomerApi.Repository.User.FireDAC in 'src\Repository\CustomerApi.Repository.User.FireDAC.pas',
  CustomerApi.Service.Auth in 'src\Service\CustomerApi.Service.Auth.pas',
  CustomerApi.Service.Customer in 'src\Service\CustomerApi.Service.Customer.pas',
  CustomerApi.Controller.Customer in 'src\Controller\CustomerApi.Controller.Customer.pas',
  CustomerApi.Controller.Auth in 'src\Controller\CustomerApi.Controller.Auth.pas',
  CustomerApi.Docs in 'src\Docs\CustomerApi.Docs.pas',
  CustomerApi.Migrations in 'src\CustomerApi.Migrations.pas',
  CustomerApi.Container in 'src\CustomerApi.Container.pas';


begin
  try
    // Capítulo 14: toda a configuração passa por aqui, antes de qualquer coisa.
    TConfig.Load(CommonSettings + [
      TSetting.New('PORT', '9002'),
      TSetting.New('ADMIN_EMAIL', 'admin@eventos.local', False, True),
      TSetting.New('ADMIN_PASSWORD', 'admin12345', True, True, 12)
    ]);
    TConfig.PrintSummary('customer-api');
    ConfigureAuth(TConfig.Value('JWT_SECRET'), 'customer-api');
    TDatabase.Configure(CUSTOMER_DB, 'customer_db', 'customer-api');
    TMigrator.Run(CUSTOMER_DB, CustomerApi.Migrations.Migrations);
    // Primeiro acesso: sem nenhum administrador, criamos um com os dados
    // de ADMIN_EMAIL e ADMIN_PASSWORD.
    if AuthService.EnsureAdmin(TConfig.Value('ADMIN_EMAIL'), TConfig.Value('ADMIN_PASSWORD')) then
      Writeln('Administrador inicial criado.');
  except
    on E: EConfigException do
    begin
      Writeln(E.Message);
      ExitCode := 2;
      Exit;
    end;
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
  CustomerApi.Controller.Auth.Registry;
  // Capítulo 16: o gateway e, mais adiante, o Docker perguntam por aqui.
  RegisterHealthCheck('customer-api', CUSTOMER_DB);

  THorse.Listen(TConfig.IntValue('PORT'),
    procedure
    begin
      Writeln(Format('customer-api rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
