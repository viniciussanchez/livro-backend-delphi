unit EventApi.Controller.Venue;

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Horse,
  Platform.Http,
  Platform.Auth,
  EventApi.Entity.Venue,
  EventApi.DTO.Venue,
  EventApi.Container;

// GET /venues?city=...
procedure GetVenues(Req: THorseRequest; Res: THorseResponse);
var
  LVenues: TObjectList<TVenue>;
begin
  LVenues := VenueService.FindAll(Req.Query['city']);
  try
    Res.Send<TJSONArray>(TVenueMapper.ToJSONArray(LVenues));
  finally
    LVenues.Free;
  end;
end;

// GET /venues/:id
procedure GetVenueById(Req: THorseRequest; Res: THorseResponse);
var
  LVenue: TVenue;
begin
  LVenue := VenueService.FindById(ParseId(Req.Params['id']));
  try
    Res.Send<TJSONObject>(TVenueMapper.ToJSON(LVenue));
  finally
    LVenue.Free;
  end;
end;

// POST /venues
procedure PostVenue(Req: THorseRequest; Res: THorseResponse);
var
  LVenue: TVenue;
begin
  LVenue := VenueService.Add(TVenueRequest.FromJSON(RequestBody(Req)));
  try
    Res.AddHeader('Location', '/venues/' + LVenue.Id.ToString);
    Res.Status(THTTPStatus.Created).Send<TJSONObject>(TVenueMapper.ToJSON(LVenue));
  finally
    LVenue.Free;
  end;
end;

procedure Registry;
begin
  THorse.Get('/venues', GetVenues);
  THorse.Get('/venues/:id', GetVenueById);
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Post('/venues', PostVenue);
end;

end.
