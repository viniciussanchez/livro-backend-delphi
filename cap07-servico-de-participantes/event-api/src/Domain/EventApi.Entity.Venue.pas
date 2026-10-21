unit EventApi.Entity.Venue;

interface

type
  // Local onde os eventos acontecem: teatro, casa de shows, centro de convenções...
  TVenue = class
  private
    FId: Integer;
    FName: string;
    FAddress: string;
    FCity: string;
    FState: string;
    FCapacity: Integer;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Address: string read FAddress write FAddress;
    property City: string read FCity write FCity;
    property State: string read FState write FState;
    property Capacity: Integer read FCapacity write FCapacity;
  end;

implementation

end.
