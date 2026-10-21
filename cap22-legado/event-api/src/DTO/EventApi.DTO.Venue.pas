unit EventApi.DTO.Venue;

interface

uses
  System.JSON,
  System.Generics.Collections,
  EventApi.Entity.Venue;

type
  TVenueRequest = record
    Name: string;
    Address: string;
    City: string;
    State: string;
    Capacity: Integer;
    class function FromJSON(const AJSON: TJSONObject): TVenueRequest; static;
  end;

  TVenueMapper = class
  public
    class function ToJSON(const AVenue: TVenue): TJSONObject; static;
    class function ToJSONArray(const AVenues: TObjectList<TVenue>): TJSONArray; static;
  end;

implementation

uses
  System.SysUtils;

class function TVenueRequest.FromJSON(const AJSON: TJSONObject): TVenueRequest;
begin
  Result.Name := AJSON.GetValue<string>('name', '').Trim;
  Result.Address := AJSON.GetValue<string>('address', '').Trim;
  Result.City := AJSON.GetValue<string>('city', '').Trim;
  Result.State := AJSON.GetValue<string>('state', '').Trim.ToUpper;
  Result.Capacity := AJSON.GetValue<Integer>('capacity', 0);
end;

class function TVenueMapper.ToJSON(const AVenue: TVenue): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(AVenue.Id));
  Result.AddPair('name', AVenue.Name);
  Result.AddPair('address', AVenue.Address);
  Result.AddPair('city', AVenue.City);
  Result.AddPair('state', AVenue.State);
  Result.AddPair('capacity', TJSONNumber.Create(AVenue.Capacity));
end;

class function TVenueMapper.ToJSONArray(const AVenues: TObjectList<TVenue>): TJSONArray;
var
  LVenue: TVenue;
begin
  Result := TJSONArray.Create;
  for LVenue in AVenues do
    Result.AddElement(ToJSON(LVenue));
end;

end.
