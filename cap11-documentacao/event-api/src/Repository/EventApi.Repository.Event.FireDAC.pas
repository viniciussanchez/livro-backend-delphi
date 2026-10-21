unit EventApi.Repository.Event.FireDAC;

interface

uses
  System.Generics.Collections,
  Platform.Repository,
  EventApi.Entity.Event,
  EventApi.Repository.Event;

type
  TEventRepositoryFireDAC = class(TFireDACRepository, IEventRepository)
  public
    function FindAll(const AFilter: TEventFilter): TObjectList<TEvent>;
    function FindById(const AId: Integer): TEvent;
    procedure Insert(const AEvent: TEvent);
    procedure UpdateStatus(const AId: Integer; const AStatus: TEventStatus);
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

const
  // A listagem já traz o nome da categoria e o local: uma consulta só,
  // em vez de uma consulta extra por evento.
  SELECT_EVENT =
    'select e.id, e.name, e.description, e.start_at, e.status,' +
    '       c.id as category_id, c.name as category_name,' +
    '       v.id as venue_id, v.name as venue_name, v.city' +
    '  from event e' +
    '  join category c on c.id = e.category_id' +
    '  join venue v on v.id = e.venue_id';

function ToEntity(const AQuery: TFDQuery): TEvent;
var
  LStatus: TEventStatus;
begin
  Result := TEvent.Create;
  Result.Id := AQuery.FieldByName('id').AsInteger;
  Result.Name := AQuery.FieldByName('name').AsString;
  Result.Description := AQuery.FieldByName('description').AsString;
  Result.StartAt := AQuery.FieldByName('start_at').AsDateTime;
  if TEventStatus.TryParse(AQuery.FieldByName('status').AsString, LStatus) then
    Result.Status := LStatus;
  Result.CategoryId := AQuery.FieldByName('category_id').AsInteger;
  Result.CategoryName := AQuery.FieldByName('category_name').AsString;
  Result.VenueId := AQuery.FieldByName('venue_id').AsInteger;
  Result.VenueName := AQuery.FieldByName('venue_name').AsString;
  Result.City := AQuery.FieldByName('city').AsString;
end;

function TEventRepositoryFireDAC.FindAll(const AFilter: TEventFilter): TObjectList<TEvent>;
var
  LQuery: TFDQuery;
  LWhere: string;

  procedure AddCondition(const ACondition: string);
  begin
    if LWhere.IsEmpty then
      LWhere := ' where ' + ACondition
    else
      LWhere := LWhere + ' and ' + ACondition;
  end;

begin
  // Montamos o where só com os filtros informados. Os valores
  // sempre entram como parâmetros, nunca concatenados no SQL.
  LWhere := '';
  if not AFilter.City.IsEmpty then
    AddCondition('lower(v.city) = lower(:city)');
  if AFilter.CategoryId > 0 then
    AddCondition('e.category_id = :category_id');
  if AFilter.DateFrom > 0 then
    AddCondition('e.start_at >= :date_from');
  if AFilter.DateTo > 0 then
    AddCondition('e.start_at < :date_to');
  if AFilter.FilterByStatus then
    AddCondition('e.status = :status');

  Result := TObjectList<TEvent>.Create(True);
  try
    LQuery := NewQuery(SELECT_EVENT + LWhere + ' order by e.start_at, e.id');
    try
      if not AFilter.City.IsEmpty then
        LQuery.ParamByName('city').AsString := AFilter.City;
      if AFilter.CategoryId > 0 then
        LQuery.ParamByName('category_id').AsInteger := AFilter.CategoryId;
      if AFilter.DateFrom > 0 then
        LQuery.ParamByName('date_from').AsDateTime := AFilter.DateFrom;
      if AFilter.DateTo > 0 then
        // "Até 30/11" inclui o dia 30 inteiro: comparamos com o início do dia seguinte.
        LQuery.ParamByName('date_to').AsDateTime := IncDay(AFilter.DateTo);
      if AFilter.FilterByStatus then
        LQuery.ParamByName('status').AsString := AFilter.Status.ToString;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        Result.Add(ToEntity(LQuery));
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TEventRepositoryFireDAC.FindById(const AId: Integer): TEvent;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := NewQuery(SELECT_EVENT + ' where e.id = :id');
  try
    LQuery.ParamByName('id').AsInteger := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := ToEntity(LQuery);
  finally
    LQuery.Free;
  end;
end;

procedure TEventRepositoryFireDAC.Insert(const AEvent: TEvent);
var
  LQuery: TFDQuery;
begin
  LQuery := NewQuery(
    'insert into event (name, description, category_id, venue_id, start_at, status) ' +
    'values (:name, :description, :category_id, :venue_id, :start_at, :status) returning id');
  try
    LQuery.ParamByName('name').AsString := AEvent.Name;
    LQuery.ParamByName('description').AsString := AEvent.Description;
    LQuery.ParamByName('category_id').AsInteger := AEvent.CategoryId;
    LQuery.ParamByName('venue_id').AsInteger := AEvent.VenueId;
    LQuery.ParamByName('start_at').AsDateTime := AEvent.StartAt;
    LQuery.ParamByName('status').AsString := AEvent.Status.ToString;
    LQuery.Open;
    AEvent.Id := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

procedure TEventRepositoryFireDAC.UpdateStatus(const AId: Integer; const AStatus: TEventStatus);
begin
  Connection.ExecSQL('update event set status = :status where id = :id', [AStatus.ToString, AId]);
end;

end.
