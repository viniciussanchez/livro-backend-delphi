unit TicketApi.Service.Report;

interface

uses
  TicketApi.Entity.Report,
  TicketApi.Repository.Report;

const
  // Um relatório diário de vários anos teria milhares de linhas.
  MAX_REVENUE_DAYS = 366;

type
  IReportService = interface
    ['{4C92A1E7-0F6B-4D38-B5E2-91A7D3C60F18}']
    function EventSales(const AEventId: Integer): TEventSales;
    function EventAttendance(const AEventId: Integer): TEventAttendance;
    function Revenue(const AFilter: TRevenueFilter): TArray<TRevenuePeriod>;
  end;

  TReportService = class(TInterfacedObject, IReportService)
  private
    FRepository: IReportRepository;
  public
    constructor Create(const ARepository: IReportRepository);
    function EventSales(const AEventId: Integer): TEventSales;
    function EventAttendance(const AEventId: Integer): TEventAttendance;
    function Revenue(const AFilter: TRevenueFilter): TArray<TRevenuePeriod>;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  Platform.Exceptions,
  Platform.Validation;

constructor TReportService.Create(const ARepository: IReportRepository);
begin
  inherited Create;
  FRepository := ARepository;
end;

function TReportService.EventSales(const AEventId: Integer): TEventSales;
begin
  Result := FRepository.EventSales(AEventId);
  if Length(Result.Batches) = 0 then
    raise ENotFoundException.Create('Nenhum lote à venda para este evento.');
end;

function TReportService.EventAttendance(const AEventId: Integer): TEventAttendance;
begin
  Result := FRepository.EventAttendance(AEventId);
  if Result.Capacity = 0 then
    raise ENotFoundException.Create('Nenhum lote à venda para este evento.');
end;

function TReportService.Revenue(const AFilter: TRevenueFilter): TArray<TRevenuePeriod>;
var
  LValidation: TValidation;
begin
  LValidation.Check(AFilter.DateFrom > 0, 'from', 'Informe a data inicial no formato aaaa-mm-dd.');
  LValidation.Check(AFilter.DateTo > 0, 'to', 'Informe a data final no formato aaaa-mm-dd.');
  LValidation.RaiseIfInvalid;

  if AFilter.DateFrom > AFilter.DateTo then
    raise EValidationException.CreateForField('from', 'A data inicial deve ser anterior à final.');
  if (AFilter.GroupBy = rgDay) and (DaysBetween(AFilter.DateFrom, AFilter.DateTo) > MAX_REVENUE_DAYS) then
    raise EValidationException.CreateForField('groupBy', Format(
      'Para agrupar por dia, o período pode ter no máximo %d dias. Use groupBy=month.', [MAX_REVENUE_DAYS]));

  Result := FRepository.Revenue(AFilter);
end;

end.
