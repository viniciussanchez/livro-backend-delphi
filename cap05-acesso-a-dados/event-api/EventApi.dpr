program EventApi;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  Platform.Exceptions in '..\shared\src\Platform.Exceptions.pas',
  Platform.Dates in '..\shared\src\Platform.Dates.pas',
  Platform.Http in '..\shared\src\Platform.Http.pas',
  Platform.Database in '..\shared\src\Platform.Database.pas',
  Platform.Migrations in '..\shared\src\Platform.Migrations.pas',
  Platform.Repository in '..\shared\src\Platform.Repository.pas',
  EventApi.Entity.Event in 'src\Domain\EventApi.Entity.Event.pas',
  EventApi.DTO.Event in 'src\DTO\EventApi.DTO.Event.pas',
  EventApi.Repository.Event in 'src\Repository\EventApi.Repository.Event.pas',
  EventApi.Repository.Event.FireDAC in 'src\Repository\EventApi.Repository.Event.FireDAC.pas',
  EventApi.Service.Event in 'src\Service\EventApi.Service.Event.pas',
  EventApi.Controller.Event in 'src\Controller\EventApi.Controller.Event.pas',
  EventApi.Migrations in 'src\EventApi.Migrations.pas',
  EventApi.Container in 'src\EventApi.Container.pas';

begin
  try
    TDatabase.Configure(EVENT_DB, 'event_db', 'event-api');
    TMigrator.Run(EVENT_DB, EventApi.Migrations.Migrations);
  except
    on E: Exception do
    begin
      Writeln('Falha ao preparar o banco de dados: ' + E.Message);
      ExitCode := 1;
      Exit;
    end;
  end;

  THorse.Use(Jhonson);

  EventApi.Controller.Event.Registry;

  THorse.Listen(9001,
    procedure
    begin
      Writeln(Format('event-api rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
