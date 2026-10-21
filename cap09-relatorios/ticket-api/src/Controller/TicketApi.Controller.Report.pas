unit TicketApi.Controller.Report;

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  Horse,
  Platform.Http,
  Platform.Dates,
  Platform.Exceptions,
  TicketApi.Entity.Report,
  TicketApi.DTO.Report,
  TicketApi.Container;

// GET /reports/events/:eventId/sales
procedure GetEventSales(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    begin
      Res.Send<TJSONObject>(TReportMapper.ToJSON(
        ReportService.EventSales(ParseId(Req.Params['eventId']))));
    end);
end;

// GET /reports/events/:eventId/attendance
procedure GetEventAttendance(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    begin
      Res.Send<TJSONObject>(TReportMapper.ToJSON(
        ReportService.EventAttendance(ParseId(Req.Params['eventId']))));
    end);
end;

// GET /reports/revenue?from=2026-10-01&to=2026-10-31&groupBy=day&eventId=1
procedure GetRevenue(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LFilter: TRevenueFilter;
      LValue: string;
    begin
      LFilter := Default(TRevenueFilter);
      if not TryParseISODate(Req.Query['from'], LFilter.DateFrom) then
        LFilter.DateFrom := 0;
      if not TryParseISODate(Req.Query['to'], LFilter.DateTo) then
        LFilter.DateTo := 0;

      LValue := Req.Query['groupBy'];
      if LValue.IsEmpty or SameText(LValue, 'day') then
        LFilter.GroupBy := rgDay
      else if SameText(LValue, 'month') then
        LFilter.GroupBy := rgMonth
      else
        raise EValidationException.Create('O parâmetro groupBy deve ser day ou month.');

      LValue := Req.Query['eventId'];
      if not LValue.IsEmpty then
        LFilter.EventId := ParseId(LValue);

      Res.Send<TJSONObject>(TReportMapper.ToJSON(ReportService.Revenue(LFilter), LFilter));
    end);
end;

procedure Registry;
begin
  THorse
    .Get('/reports/events/:eventId/sales', GetEventSales)
    .Get('/reports/events/:eventId/attendance', GetEventAttendance)
    .Get('/reports/revenue', GetRevenue);
end;

end.
