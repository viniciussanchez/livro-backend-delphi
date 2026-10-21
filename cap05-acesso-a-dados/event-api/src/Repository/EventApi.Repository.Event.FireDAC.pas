unit EventApi.Repository.Event.FireDAC;

{ Implementação do IEventRepository com FireDAC e PostgreSQL. }

interface

uses
  System.Generics.Collections,
  Platform.Repository,
  EventApi.Entity.Event,
  EventApi.Repository.Event;

type
  TEventRepositoryFireDAC = class(TFireDACRepository, IEventRepository)
  public
    function FindAll(const ACity: string): TObjectList<TEvent>;
    function FindById(const AId: Integer): TEvent;
    procedure Insert(const AEvent: TEvent);
    function Delete(const AId: Integer): Boolean;
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

const
  SELECT_EVENT =
    'select id, name, city, event_date, capacity from event';

function ToEntity(const AQuery: TFDQuery): TEvent;
begin
  Result := TEvent.Create;
  Result.Id := AQuery.FieldByName('id').AsInteger;
  Result.Name := AQuery.FieldByName('name').AsString;
  Result.City := AQuery.FieldByName('city').AsString;
  Result.EventDate := AQuery.FieldByName('event_date').AsDateTime;
  Result.Capacity := AQuery.FieldByName('capacity').AsInteger;
end;

function TEventRepositoryFireDAC.FindAll(const ACity: string): TObjectList<TEvent>;
var
  LQuery: TFDQuery;
begin
  Result := TObjectList<TEvent>.Create(True);
  try
    LQuery := NewQuery(SELECT_EVENT);
    try
      if not ACity.IsEmpty then
      begin
        LQuery.SQL.Add('where lower(city) = lower(:city)');
        LQuery.ParamByName('city').AsString := ACity;
      end;
      LQuery.SQL.Add('order by event_date, id');
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
  LQuery := NewQuery(SELECT_EVENT + ' where id = :id');
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
  // O "returning id" devolve o identificador gerado pelo banco
  // na mesma ida ao servidor do insert.
  LQuery := NewQuery(
    'insert into event (name, city, event_date, capacity) ' +
    'values (:name, :city, :event_date, :capacity) ' +
    'returning id');
  try
    LQuery.ParamByName('name').AsString := AEvent.Name;
    LQuery.ParamByName('city').AsString := AEvent.City;
    LQuery.ParamByName('event_date').AsDate := AEvent.EventDate;
    LQuery.ParamByName('capacity').AsInteger := AEvent.Capacity;
    LQuery.Open;
    AEvent.Id := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TEventRepositoryFireDAC.Delete(const AId: Integer): Boolean;
begin
  Result := Connection.ExecSQL('delete from event where id = :id', [AId]) > 0;
end;

end.
