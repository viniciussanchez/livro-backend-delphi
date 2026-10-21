unit EventApi.Entity.Event;

interface

type
  TEvent = class
  private
    FId: Integer;
    FName: string;
    FCity: string;
    FEventDate: TDate;
    FCapacity: Integer;
  public
    function Clone: TEvent;
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property City: string read FCity write FCity;
    property EventDate: TDate read FEventDate write FEventDate;
    property Capacity: Integer read FCapacity write FCapacity;
  end;

implementation

function TEvent.Clone: TEvent;
begin
  Result := TEvent.Create;
  Result.Id := FId;
  Result.Name := FName;
  Result.City := FCity;
  Result.EventDate := FEventDate;
  Result.Capacity := FCapacity;
end;

end.
