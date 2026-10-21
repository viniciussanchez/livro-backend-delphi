unit TicketApi.Entity.Report;

{ Estruturas dos relatórios. São records: dados somente de leitura,
  calculados pelo banco, sem identidade nem regras próprias. }

interface

type
  // Uma linha do relatório de vendas: um lote de um evento.
  TBatchSales = record
    BatchId: Integer;
    Price: Currency;
    Quantity: Integer;
    Sold: Integer;
    ActiveReservations: Integer;
    CancelledReservations: Integer;
    Revenue: Currency;
    function Available: Integer;
  end;

  TEventSales = record
    EventId: Integer;
    // Vem da event-api (capítulo 12); vazio quando ela não responde.
    EventName: string;
    Batches: TArray<TBatchSales>;
    function TotalQuantity: Integer;
    function TotalSold: Integer;
    function TotalRevenue: Currency;
  end;

  TEventAttendance = record
    EventId: Integer;
    Capacity: Integer;
    TicketsIssued: Integer;
    CheckedIn: Integer;
    TicketsCancelled: Integer;
    // Percentual da capacidade vendida.
    function OccupancyRate: Double;
    // Percentual de quem comprou e efetivamente entrou.
    function AttendanceRate: Double;
  end;

  TRevenueGroupBy = (rgDay, rgMonth);

  TRevenuePeriod = record
    PeriodStart: TDate;
    Reservations: Integer;
    Tickets: Integer;
    Revenue: Currency;
  end;

  TRevenueFilter = record
    DateFrom: TDate;
    DateTo: TDate;
    GroupBy: TRevenueGroupBy;
    EventId: Integer;
  end;

implementation

uses
  System.Math;

function Percent(const APart, ATotal: Integer): Double;
begin
  if ATotal = 0 then
    Exit(0);
  Result := SimpleRoundTo(APart * 100 / ATotal, -1);
end;

{ TBatchSales }

function TBatchSales.Available: Integer;
begin
  Result := Quantity - Sold;
end;

{ TEventSales }

function TEventSales.TotalQuantity: Integer;
var
  LBatch: TBatchSales;
begin
  Result := 0;
  for LBatch in Batches do
    Inc(Result, LBatch.Quantity);
end;

function TEventSales.TotalSold: Integer;
var
  LBatch: TBatchSales;
begin
  Result := 0;
  for LBatch in Batches do
    Inc(Result, LBatch.Sold);
end;

function TEventSales.TotalRevenue: Currency;
var
  LBatch: TBatchSales;
begin
  Result := 0;
  for LBatch in Batches do
    Result := Result + LBatch.Revenue;
end;

{ TEventAttendance }

function TEventAttendance.OccupancyRate: Double;
begin
  Result := Percent(TicketsIssued, Capacity);
end;

function TEventAttendance.AttendanceRate: Double;
begin
  Result := Percent(CheckedIn, TicketsIssued);
end;

end.
