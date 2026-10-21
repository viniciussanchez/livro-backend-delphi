unit TicketApi.Repository.Report;

{ Consultas dos relatórios. Todo o cálculo pesado (somas, contagens,
  agrupamentos) acontece no banco; o Delphi recebe só o resultado. }

interface

uses
  TicketApi.Entity.Report;

type
  IReportRepository = interface
    ['{B3E0D6A4-58C2-4F17-9A3E-C7D21F06B8E5}']
    function EventSales(const AEventId: Integer): TEventSales;
    function EventAttendance(const AEventId: Integer): TEventAttendance;
    function Revenue(const AFilter: TRevenueFilter): TArray<TRevenuePeriod>;
  end;

implementation

end.
