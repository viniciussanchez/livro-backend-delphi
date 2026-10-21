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
  Platform.Config,
  TicketApi.Partners,
  TicketApi.Integration.EventApi,
  TicketApi.Integration.CustomerApi,
  TicketApi.Repository.FireDAC,
  TicketApi.Repository.Report.FireDAC;

function EventCatalog: IEventCatalog;
begin
  Result := TEventApiClient.Create(TConfig.Value('EVENT_API_URL'), TConfig.IntValue('SERVICE_TIMEOUT_MS'));
end;

function CustomerDirectory: ICustomerDirectory;
begin
  Result := TCustomerApiClient.Create(TConfig.Value('CUSTOMER_API_URL'), TConfig.IntValue('SERVICE_TIMEOUT_MS'));
end;

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
    TReservationRepositoryFireDAC.Create(LSession),
    EventCatalog,
    CustomerDirectory);
end;

function ReportService: IReportService;
begin
  Result := TReportService.Create(TReportRepositoryFireDAC.Create(TDatabase.NewSession(TICKET_DB)),
    EventCatalog);
end;

end.
