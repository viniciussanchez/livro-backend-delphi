program TicketApi;

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
  TicketApi.Entity.Batch in 'src\Domain\TicketApi.Entity.Batch.pas',
  TicketApi.Entity.Reservation in 'src\Domain\TicketApi.Entity.Reservation.pas',
  TicketApi.TicketCode in 'src\Domain\TicketApi.TicketCode.pas',
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
  TicketApi.Migrations in 'src\TicketApi.Migrations.pas',
  TicketApi.Container in 'src\TicketApi.Container.pas';

begin
  try
    TDatabase.Configure(TICKET_DB, 'ticket_db', 'ticket-api');
    TMigrator.Run(TICKET_DB, TicketApi.Migrations.Migrations);
  except
    on E: Exception do
    begin
      Writeln('Falha ao preparar o banco de dados: ' + E.Message);
      ExitCode := 1;
      Exit;
    end;
  end;

  THorse.Use(Jhonson);

  TicketApi.Controller.Registry;
  TicketApi.Controller.Report.Registry;

  THorse.Listen(9003,
    procedure
    begin
      Writeln(Format('ticket-api rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
