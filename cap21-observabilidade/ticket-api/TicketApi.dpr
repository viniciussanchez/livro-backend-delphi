program TicketApi;

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
  Platform.Log in '..\shared\src\Platform.Log.pas',
  Platform.Metrics in '..\shared\src\Platform.Metrics.pas',
  Platform.Middleware.Observability in '..\shared\src\Platform.Middleware.Observability.pas',
  Platform.Middleware.Errors in '..\shared\src\Platform.Middleware.Errors.pas',
  Platform.Shutdown in '..\shared\src\Platform.Shutdown.pas',
  Platform.HealthCheck in '..\shared\src\Platform.HealthCheck.pas',
  Platform.Docs in '..\shared\src\Platform.Docs.pas',
  Platform.Jwt in '..\shared\src\Platform.Jwt.pas',
  Platform.Auth in '..\shared\src\Platform.Auth.pas',
  Platform.Integration in '..\shared\src\Platform.Integration.pas',
  Platform.Transactions in '..\shared\src\Platform.Transactions.pas',
  Platform.Database in '..\shared\src\Platform.Database.pas',
  Platform.Migrations in '..\shared\src\Platform.Migrations.pas',
  Platform.Repository in '..\shared\src\Platform.Repository.pas',
  Platform.Health in '..\shared\src\Platform.Health.pas',
  TicketApi.Entity.Batch in 'src\Domain\TicketApi.Entity.Batch.pas',
  TicketApi.Entity.Reservation in 'src\Domain\TicketApi.Entity.Reservation.pas',
  Platform.SecureRandom in '..\shared\src\Platform.SecureRandom.pas',
  TicketApi.TicketCode in 'src\Domain\TicketApi.TicketCode.pas',
  TicketApi.Exceptions in 'src\Domain\TicketApi.Exceptions.pas',
  TicketApi.Partners in 'src\Domain\TicketApi.Partners.pas',
  TicketApi.Integration.EventApi in 'src\Integration\TicketApi.Integration.EventApi.pas',
  TicketApi.Integration.CustomerApi in 'src\Integration\TicketApi.Integration.CustomerApi.pas',
  TicketApi.Entity.Report in 'src\Domain\TicketApi.Entity.Report.pas',
  TicketApi.DTO in 'src\DTO\TicketApi.DTO.pas',
  TicketApi.DTO.Report in 'src\DTO\TicketApi.DTO.Report.pas',
  TicketApi.Repository in 'src\Repository\TicketApi.Repository.pas',
  TicketApi.Repository.FireDAC in 'src\Repository\TicketApi.Repository.FireDAC.pas',
  TicketApi.Repository.Report in 'src\Repository\TicketApi.Repository.Report.pas',
  TicketApi.Repository.Report.FireDAC in 'src\Repository\TicketApi.Repository.Report.FireDAC.pas',
  TicketApi.Service in 'src\Service\TicketApi.Service.pas',
  TicketApi.Service.Report in 'src\Service\TicketApi.Service.Report.pas',
  TicketApi.Controller in 'src\Controller\TicketApi.Controller.pas',
  TicketApi.Controller.Report in 'src\Controller\TicketApi.Controller.Report.pas',
  TicketApi.Docs in 'src\Docs\TicketApi.Docs.pas',
  TicketApi.Migrations in 'src\TicketApi.Migrations.pas',
  TicketApi.Container in 'src\TicketApi.Container.pas';

begin
  // Capítulo 18: "--healthcheck" é o Docker perguntando se estamos bem.
  if RunHealthCheckIfRequested('9003', [200]) then
    Exit;

  // Capítulo 17: Ctrl+C e SIGTERM encerram o serviço com calma.
  // Precisa vir antes de qualquer outra coisa que crie threads.
  EnableGracefulShutdown('ticket-api');
  try
    // Capítulo 14: toda a configuração passa por aqui, antes de qualquer coisa.
    TConfig.Load(CommonSettings + [
      TSetting.New('PORT', '9003'),
      TSetting.New('EVENT_API_URL', 'http://127.0.0.1:9001'),
      TSetting.New('CUSTOMER_API_URL', 'http://127.0.0.1:9002'),
      TSetting.New('SERVICE_TIMEOUT_MS', '2000')
    ]);
    // Capítulo 21: o log precisa saber quem é o serviço e em que formato escrever.
    TLog.Configure('ticket-api', TConfig.Value('LOG_FORMAT'), TConfig.IsProduction);
    TConfig.PrintSummary('ticket-api');
    ConfigureAuth(TConfig.Value('JWT_SECRET'), 'ticket-api');
    TDatabase.Configure(TICKET_DB, 'ticket_db', 'ticket-api');
    TMigrator.Run(TICKET_DB, TicketApi.Migrations.Migrations);
  except
    on E: EConfigException do
    begin
      TLog.Error(E.Message);
      ExitCode := 2;
      Exit;
    end;
    on E: Exception do
    begin
      TLog.Error('falha ao preparar o banco de dados', [F('detail', E.Message)]);
      ExitCode := 1;
      Exit;
    end;
  end;

  // A ordem importa: o tratamento de erros vem primeiro para "abraçar"
  // todo o resto, inclusive o Jhonson.
  // Capítulo 21: o primeiro de todos, para medir e registrar tudo o que vem depois.
  THorse.Use(Observability);
  THorse.Use(ErrorHandler);
  THorse.Use(Jhonson('UTF-8', InvalidJsonHandler));

  // Documentação: http://localhost:9003/swagger/doc/html
  TicketApi.Docs.Configure;
  THorse.Use(HorseSwagger);

  TicketApi.Controller.Registry;
  TicketApi.Controller.Report.Registry;
  // Capítulo 16: o gateway e, mais adiante, o Docker perguntam por aqui.
  RegisterHealthCheck('ticket-api', TICKET_DB);
  // Capítulo 21: as métricas para o Prometheus.
  RegisterMetricsEndpoint;

  // Capítulo 20: sem isto, o WebBroker atende no máximo 32 conexões ao mesmo
  // tempo e recusa as outras com um 500.
  THorse.MaxConnections := TConfig.IntValue('MAX_CONNECTIONS');

  THorse.Listen(TConfig.IntValue('PORT'),
    procedure
    begin
      TLog.Info('ticket-api no ar', [F('port', THorse.Port)]);
    end,
    procedure
    begin
      TLog.Info('ticket-api encerrada');
    end);
end.
