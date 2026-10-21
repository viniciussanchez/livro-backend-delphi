unit TicketApi.DTO.Report;

interface

uses
  System.JSON,
  TicketApi.Entity.Report;

type
  TReportMapper = class
  public
    class function ToJSON(const ASales: TEventSales): TJSONObject; overload; static;
    class function ToJSON(const AAttendance: TEventAttendance): TJSONObject; overload; static;
    class function ToJSON(const APeriods: TArray<TRevenuePeriod>; const AFilter: TRevenueFilter): TJSONObject; overload; static;
  end;

implementation

uses
  System.SysUtils,
  Platform.Dates;

function Money(const AValue: Currency): TJSONNumber;
var
  LValue: Double;
begin
  LValue := AValue;
  Result := TJSONNumber.Create(LValue);
end;

class function TReportMapper.ToJSON(const ASales: TEventSales): TJSONObject;
var
  LBatches: TJSONArray;
  LBatch: TBatchSales;
  LItem, LTotals: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('eventId', TJSONNumber.Create(ASales.EventId));

  LBatches := TJSONArray.Create;
  for LBatch in ASales.Batches do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('batchId', TJSONNumber.Create(LBatch.BatchId));
    LItem.AddPair('price', Money(LBatch.Price));
    LItem.AddPair('quantity', TJSONNumber.Create(LBatch.Quantity));
    LItem.AddPair('sold', TJSONNumber.Create(LBatch.Sold));
    LItem.AddPair('available', TJSONNumber.Create(LBatch.Available));
    LItem.AddPair('activeReservations', TJSONNumber.Create(LBatch.ActiveReservations));
    LItem.AddPair('cancelledReservations', TJSONNumber.Create(LBatch.CancelledReservations));
    LItem.AddPair('revenue', Money(LBatch.Revenue));
    LBatches.AddElement(LItem);
  end;
  Result.AddPair('batches', LBatches);

  LTotals := TJSONObject.Create;
  LTotals.AddPair('quantity', TJSONNumber.Create(ASales.TotalQuantity));
  LTotals.AddPair('sold', TJSONNumber.Create(ASales.TotalSold));
  LTotals.AddPair('revenue', Money(ASales.TotalRevenue));
  Result.AddPair('totals', LTotals);
end;

class function TReportMapper.ToJSON(const AAttendance: TEventAttendance): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('eventId', TJSONNumber.Create(AAttendance.EventId));
  Result.AddPair('capacity', TJSONNumber.Create(AAttendance.Capacity));
  Result.AddPair('ticketsIssued', TJSONNumber.Create(AAttendance.TicketsIssued));
  Result.AddPair('checkedIn', TJSONNumber.Create(AAttendance.CheckedIn));
  Result.AddPair('ticketsCancelled', TJSONNumber.Create(AAttendance.TicketsCancelled));
  Result.AddPair('occupancyRate', TJSONNumber.Create(AAttendance.OccupancyRate));
  Result.AddPair('attendanceRate', TJSONNumber.Create(AAttendance.AttendanceRate));
end;

class function TReportMapper.ToJSON(const APeriods: TArray<TRevenuePeriod>; const AFilter: TRevenueFilter): TJSONObject;
const
  GROUP_NAMES: array[TRevenueGroupBy] of string = ('day', 'month');
var
  LItems: TJSONArray;
  LPeriod: TRevenuePeriod;
  LItem: TJSONObject;
  LTotal: Currency;
  LTickets: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('from', FormatISODate(AFilter.DateFrom));
  Result.AddPair('to', FormatISODate(AFilter.DateTo));
  Result.AddPair('groupBy', GROUP_NAMES[AFilter.GroupBy]);

  LTotal := 0;
  LTickets := 0;
  LItems := TJSONArray.Create;
  for LPeriod in APeriods do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('period', FormatISODate(LPeriod.PeriodStart));
    LItem.AddPair('reservations', TJSONNumber.Create(LPeriod.Reservations));
    LItem.AddPair('tickets', TJSONNumber.Create(LPeriod.Tickets));
    LItem.AddPair('revenue', Money(LPeriod.Revenue));
    LItems.AddElement(LItem);
    LTotal := LTotal + LPeriod.Revenue;
    Inc(LTickets, LPeriod.Tickets);
  end;
  Result.AddPair('periods', LItems);
  Result.AddPair('totalTickets', TJSONNumber.Create(LTickets));
  Result.AddPair('totalRevenue', Money(LTotal));
end;

end.
