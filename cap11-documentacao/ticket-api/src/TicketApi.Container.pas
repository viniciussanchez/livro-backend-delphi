unit TicketApi.Container;

{ Composition root da ticket-api. }

interface

uses
  TicketApi.Service,
  TicketApi.Service.Report;

const
  TICKET_DB = 'ticket_db';

function BatchService: IBatchService;
function ReservationService: IReservationService;
function ReportService: IReportService;

implementation

uses
  Platform.Database,
  TicketApi.Repository.FireDAC,
  TicketApi.Repository.Report.FireDAC;

function BatchService: IBatchService;
begin
  Result := TBatchService.Create(TBatchRepositoryFireDAC.Create(TDatabase.NewSession(TICKET_DB)));
end;

function ReservationService: IReservationService;
var
  LSession: IDbSession;
begin
  // A sessão entra três vezes: como escopo de transação e como conexão dos
  // dois repositórios. Por isso a transação aberta pelo Service vale para ambos.
  LSession := TDatabase.NewSession(TICKET_DB);
  Result := TReservationService.Create(LSession,
    TBatchRepositoryFireDAC.Create(LSession),
    TReservationRepositoryFireDAC.Create(LSession));
end;

function ReportService: IReportService;
begin
  Result := TReportService.Create(TReportRepositoryFireDAC.Create(TDatabase.NewSession(TICKET_DB)));
end;

end.
