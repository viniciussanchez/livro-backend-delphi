program EventApi;

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
  EventApi.Entity.Category in 'src\Domain\EventApi.Entity.Category.pas',
  EventApi.Entity.Venue in 'src\Domain\EventApi.Entity.Venue.pas',
  EventApi.Entity.Event in 'src\Domain\EventApi.Entity.Event.pas',
  EventApi.Entity.Batch in 'src\Domain\EventApi.Entity.Batch.pas',
  EventApi.DTO.Category in 'src\DTO\EventApi.DTO.Category.pas',
  EventApi.DTO.Venue in 'src\DTO\EventApi.DTO.Venue.pas',
  EventApi.DTO.Event in 'src\DTO\EventApi.DTO.Event.pas',
  EventApi.Repository.Category in 'src\Repository\EventApi.Repository.Category.pas',
  EventApi.Repository.Venue in 'src\Repository\EventApi.Repository.Venue.pas',
  EventApi.Repository.Event in 'src\Repository\EventApi.Repository.Event.pas',
  EventApi.Repository.Batch in 'src\Repository\EventApi.Repository.Batch.pas',
  EventApi.Repository.Category.FireDAC in 'src\Repository\EventApi.Repository.Category.FireDAC.pas',
  EventApi.Repository.Venue.FireDAC in 'src\Repository\EventApi.Repository.Venue.FireDAC.pas',
  EventApi.Repository.Event.FireDAC in 'src\Repository\EventApi.Repository.Event.FireDAC.pas',
  EventApi.Repository.Batch.FireDAC in 'src\Repository\EventApi.Repository.Batch.FireDAC.pas',
  EventApi.Service.Category in 'src\Service\EventApi.Service.Category.pas',
  EventApi.Service.Venue in 'src\Service\EventApi.Service.Venue.pas',
  EventApi.Service.Event in 'src\Service\EventApi.Service.Event.pas',
  EventApi.Controller.Category in 'src\Controller\EventApi.Controller.Category.pas',
  EventApi.Controller.Venue in 'src\Controller\EventApi.Controller.Venue.pas',
  EventApi.Controller.Event in 'src\Controller\EventApi.Controller.Event.pas',
  EventApi.Docs in 'src\Docs\EventApi.Docs.pas',
  EventApi.Migrations in 'src\EventApi.Migrations.pas',
  EventApi.Container in 'src\EventApi.Container.pas';

begin
  try
    // Capítulo 14: toda a configuração passa por aqui, antes de qualquer coisa.
    TConfig.Load(CommonSettings + [
      TSetting.New('PORT', '9001')
    ]);
    TConfig.PrintSummary('event-api');
    ConfigureAuth(TConfig.Value('JWT_SECRET'), 'event-api');
    TDatabase.Configure(EVENT_DB, 'event_db', 'event-api');
    TMigrator.Run(EVENT_DB, EventApi.Migrations.Migrations);
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

  // Documentação: http://localhost:9001/swagger/doc/html
  EventApi.Docs.Configure;
  THorse.Use(HorseSwagger);

  EventApi.Controller.Category.Registry;
  EventApi.Controller.Venue.Registry;
  EventApi.Controller.Event.Registry;
  // Capítulo 16: o gateway e, mais adiante, o Docker perguntam por aqui.
  RegisterHealthCheck('event-api', EVENT_DB);

  THorse.Listen(TConfig.IntValue('PORT'),
    procedure
    begin
      Writeln(Format('event-api rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
