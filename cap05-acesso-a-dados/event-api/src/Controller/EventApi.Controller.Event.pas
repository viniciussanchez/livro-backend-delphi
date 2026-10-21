unit EventApi.Controller.Event;

{ Camada HTTP: lê a requisição, chama o Service e monta a resposta.
  Não contém regra de negócio. }

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Horse,
  Platform.Http,
  EventApi.Entity.Event,
  EventApi.DTO.Event,
  EventApi.Container;

// GET /events?city=...
procedure GetEvents(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LEvents: TObjectList<TEvent>;
    begin
      LEvents := EventService.FindAll(Req.Query['city']);
      try
        Res.Send<TJSONArray>(TEventMapper.ToJSONArray(LEvents));
      finally
        LEvents.Free;
      end;
    end);
end;

// GET /events/:id
procedure GetEventById(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LEvent: TEvent;
    begin
      LEvent := EventService.FindById(ParseId(Req.Params['id']));
      try
        Res.Send<TJSONObject>(TEventMapper.ToJSON(LEvent));
      finally
        LEvent.Free;
      end;
    end);
end;

// POST /events
procedure PostEvent(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LEvent: TEvent;
    begin
      LEvent := EventService.Add(TEventRequest.FromJSON(RequestBody(Req)));
      try
        Res.AddHeader('Location', '/events/' + LEvent.Id.ToString);
        Res.Status(THTTPStatus.Created).Send<TJSONObject>(TEventMapper.ToJSON(LEvent));
      finally
        LEvent.Free;
      end;
    end);
end;

// DELETE /events/:id
procedure DeleteEvent(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    begin
      EventService.Delete(ParseId(Req.Params['id']));
      Res.Status(THTTPStatus.NoContent);
    end);
end;

procedure Registry;
begin
  THorse
    .Get('/events', GetEvents)
    .Get('/events/:id', GetEventById)
    .Post('/events', PostEvent)
    .Delete('/events/:id', DeleteEvent);
end;

end.
