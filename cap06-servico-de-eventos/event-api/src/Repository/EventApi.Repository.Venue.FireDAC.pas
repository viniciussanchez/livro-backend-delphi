unit EventApi.Repository.Venue.FireDAC;

interface

uses
  System.Generics.Collections,
  Platform.Repository,
  EventApi.Entity.Venue,
  EventApi.Repository.Venue;

type
  TVenueRepositoryFireDAC = class(TFireDACRepository, IVenueRepository)
  public
    function FindAll(const ACity: string): TObjectList<TVenue>;
    function FindById(const AId: Integer): TVenue;
    procedure Insert(const AVenue: TVenue);
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

const
  SELECT_VENUE = 'select id, name, address, city, state, capacity from venue';

function ToEntity(const AQuery: TFDQuery): TVenue;
begin
  Result := TVenue.Create;
  Result.Id := AQuery.FieldByName('id').AsInteger;
  Result.Name := AQuery.FieldByName('name').AsString;
  Result.Address := AQuery.FieldByName('address').AsString;
  Result.City := AQuery.FieldByName('city').AsString;
  Result.State := AQuery.FieldByName('state').AsString;
  Result.Capacity := AQuery.FieldByName('capacity').AsInteger;
end;

function TVenueRepositoryFireDAC.FindAll(const ACity: string): TObjectList<TVenue>;
var
  LQuery: TFDQuery;
begin
  Result := TObjectList<TVenue>.Create(True);
  try
    LQuery := NewQuery(SELECT_VENUE);
    try
      if not ACity.IsEmpty then
      begin
        LQuery.SQL.Add('where lower(city) = lower(:city)');
        LQuery.ParamByName('city').AsString := ACity;
      end;
      LQuery.SQL.Add('order by name');
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

function TVenueRepositoryFireDAC.FindById(const AId: Integer): TVenue;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := NewQuery(SELECT_VENUE + ' where id = :id');
  try
    LQuery.ParamByName('id').AsInteger := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := ToEntity(LQuery);
  finally
    LQuery.Free;
  end;
end;

procedure TVenueRepositoryFireDAC.Insert(const AVenue: TVenue);
var
  LQuery: TFDQuery;
begin
  LQuery := NewQuery(
    'insert into venue (name, address, city, state, capacity) ' +
    'values (:name, :address, :city, :state, :capacity) returning id');
  try
    LQuery.ParamByName('name').AsString := AVenue.Name;
    LQuery.ParamByName('address').AsString := AVenue.Address;
    LQuery.ParamByName('city').AsString := AVenue.City;
    LQuery.ParamByName('state').AsString := AVenue.State;
    LQuery.ParamByName('capacity').AsInteger := AVenue.Capacity;
    LQuery.Open;
    AVenue.Id := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

end.
