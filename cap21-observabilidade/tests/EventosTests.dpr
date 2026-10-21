program EventosTests;

{ Executa os testes automatizados da plataforma.

    EventosTests.exe                        todos os testes
    EventosTests.exe --exclude:integracao   só os que não precisam dos serviços
    EventosTests.exe --include:integracao   só os de integração
    EventosTests.exe --xml:resultado.xml    também grava o resultado em XML (NUnit) }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Platform.Exceptions in '..\shared\src\Platform.Exceptions.pas',
  Platform.Validation in '..\shared\src\Platform.Validation.pas',
  Platform.Transactions in '..\shared\src\Platform.Transactions.pas',
  Platform.Dates in '..\shared\src\Platform.Dates.pas',
  Platform.Log in '..\shared\src\Platform.Log.pas',
  Platform.Jwt in '..\shared\src\Platform.Jwt.pas',
  CustomerApi.Cpf in '..\customer-api\src\Domain\CustomerApi.Cpf.pas',
  TicketApi.Entity.Batch in '..\ticket-api\src\Domain\TicketApi.Entity.Batch.pas',
  TicketApi.Entity.Reservation in '..\ticket-api\src\Domain\TicketApi.Entity.Reservation.pas',
  TicketApi.Entity.Report in '..\ticket-api\src\Domain\TicketApi.Entity.Report.pas',
  Platform.SecureRandom in '..\shared\src\Platform.SecureRandom.pas',
  TicketApi.TicketCode in '..\ticket-api\src\Domain\TicketApi.TicketCode.pas',
  TicketApi.Exceptions in '..\ticket-api\src\Domain\TicketApi.Exceptions.pas',
  TicketApi.Partners in '..\ticket-api\src\Domain\TicketApi.Partners.pas',
  TicketApi.DTO in '..\ticket-api\src\DTO\TicketApi.DTO.pas',
  TicketApi.Repository in '..\ticket-api\src\Repository\TicketApi.Repository.pas',
  TicketApi.Service in '..\ticket-api\src\Service\TicketApi.Service.pas',
  Tests.Fakes in 'src\Tests.Fakes.pas',
  Tests.Domain in 'src\Tests.Domain.pas',
  Tests.Platform in 'src\Tests.Platform.pas',
  Tests.ReservationService in 'src\Tests.ReservationService.pas',
  Tests.Integration in 'src\Tests.Integration.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
begin
  try
    TDUnitX.CheckCommandLine;
    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;
    LRunner.AddLogger(TDUnitXConsoleLogger.Create(False));
    if TDUnitX.Options.XMLOutputFile <> '' then
      LRunner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile));

    LResults := LRunner.Execute;
    // Código de saída diferente de zero quando algo falha: é assim que um
    // servidor de integração contínua sabe que o build está quebrado.
    if not LResults.AllPassed then
      System.ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
