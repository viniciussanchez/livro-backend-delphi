unit TicketApi.Repository.Report.FireDAC;

interface

uses
  Platform.Repository,
  TicketApi.Entity.Report,
  TicketApi.Repository.Report;

type
  TReportRepositoryFireDAC = class(TFireDACRepository, IReportRepository)
  public
    function EventSales(const AEventId: Integer): TEventSales;
    function EventAttendance(const AEventId: Integer): TEventAttendance;
    function Revenue(const AFilter: TRevenueFilter): TArray<TRevenuePeriod>;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

function TReportRepositoryFireDAC.EventSales(const AEventId: Integer): TEventSales;
var
  LQuery: TFDQuery;
  LRows: TList<TBatchSales>;
  LRow: TBatchSales;
begin
  // Uma única consulta traz todos os lotes do evento já com as somas.
  // O "filter" do PostgreSQL permite contar ativas e canceladas na mesma passada.
  LQuery := NewQuery(
    'select b.id, b.price, b.quantity, b.sold,' +
    '       count(r.id) filter (where r.status = ''ACTIVE'') as active_reservations,' +
    '       count(r.id) filter (where r.status = ''CANCELLED'') as cancelled_reservations,' +
    '       coalesce(sum(r.total) filter (where r.status = ''ACTIVE''), 0) as revenue' +
    '  from batch_inventory b' +
    '  left join reservation r on r.batch_id = b.id' +
    ' where b.event_id = :event_id' +
    ' group by b.id' +
    ' order by b.id');
  LRows := TList<TBatchSales>.Create;
  try
    LQuery.ParamByName('event_id').AsInteger := AEventId;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LRow.BatchId := LQuery.FieldByName('id').AsInteger;
      LRow.Price := LQuery.FieldByName('price').AsCurrency;
      LRow.Quantity := LQuery.FieldByName('quantity').AsInteger;
      LRow.Sold := LQuery.FieldByName('sold').AsInteger;
      LRow.ActiveReservations := LQuery.FieldByName('active_reservations').AsInteger;
      LRow.CancelledReservations := LQuery.FieldByName('cancelled_reservations').AsInteger;
      LRow.Revenue := LQuery.FieldByName('revenue').AsCurrency;
      LRows.Add(LRow);
      LQuery.Next;
    end;
    Result.EventId := AEventId;
    Result.Batches := LRows.ToArray;
  finally
    LRows.Free;
    LQuery.Free;
  end;
end;

function TReportRepositoryFireDAC.EventAttendance(const AEventId: Integer): TEventAttendance;
var
  LQuery: TFDQuery;
begin
  Result := Default(TEventAttendance);
  Result.EventId := AEventId;

  Result.Capacity := Connection.ExecSQLScalar(
    'select coalesce(sum(quantity), 0) from batch_inventory where event_id = :event_id', [AEventId]);

  LQuery := NewQuery(
    'select count(*) filter (where t.status in (''VALID'', ''USED'')) as issued,' +
    '       count(*) filter (where t.status = ''USED'') as checked_in,' +
    '       count(*) filter (where t.status = ''CANCELLED'') as cancelled' +
    '  from ticket t' +
    '  join reservation r on r.id = t.reservation_id' +
    ' where r.event_id = :event_id');
  try
    LQuery.ParamByName('event_id').AsInteger := AEventId;
    LQuery.Open;
    Result.TicketsIssued := LQuery.FieldByName('issued').AsInteger;
    Result.CheckedIn := LQuery.FieldByName('checked_in').AsInteger;
    Result.TicketsCancelled := LQuery.FieldByName('cancelled').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TReportRepositoryFireDAC.Revenue(const AFilter: TRevenueFilter): TArray<TRevenuePeriod>;
const
  UNITS: array[TRevenueGroupBy] of string = ('day', 'month');
var
  LSQL: string;
  LQuery: TFDQuery;
  LRows: TList<TRevenuePeriod>;
  LRow: TRevenuePeriod;
begin
  // date_trunc "arredonda" a data para o início do dia ou do mês,
  // e o group by soma tudo o que caiu no mesmo período.
  LSQL :=
    'select date_trunc(:unit, created_at)::date as period_start,' +
    '       count(*) as reservations,' +
    '       sum(quantity) as tickets,' +
    '       sum(total) as revenue' +
    '  from reservation' +
    ' where status = ''ACTIVE''' +
    '   and created_at >= :date_from' +
    '   and created_at < :date_to';
  // O filtro opcional entra no texto antes de criarmos a query;
  // só depois preenchemos os parâmetros.
  if AFilter.EventId > 0 then
    LSQL := LSQL + ' and event_id = :event_id';
  LSQL := LSQL + ' group by 1 order by 1';

  LQuery := NewQuery(LSQL);
  LRows := TList<TRevenuePeriod>.Create;
  try
    if AFilter.EventId > 0 then
      LQuery.ParamByName('event_id').AsInteger := AFilter.EventId;
    LQuery.ParamByName('unit').AsString := UNITS[AFilter.GroupBy];
    LQuery.ParamByName('date_from').AsDateTime := AFilter.DateFrom;
    // "Até" inclusivo: o fim do período é o início do dia seguinte.
    LQuery.ParamByName('date_to').AsDateTime := IncDay(AFilter.DateTo);
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LRow.PeriodStart := LQuery.FieldByName('period_start').AsDateTime;
      LRow.Reservations := LQuery.FieldByName('reservations').AsInteger;
      LRow.Tickets := LQuery.FieldByName('tickets').AsInteger;
      LRow.Revenue := LQuery.FieldByName('revenue').AsCurrency;
      LRows.Add(LRow);
      LQuery.Next;
    end;
    Result := LRows.ToArray;
  finally
    LRows.Free;
    LQuery.Free;
  end;
end;

end.
