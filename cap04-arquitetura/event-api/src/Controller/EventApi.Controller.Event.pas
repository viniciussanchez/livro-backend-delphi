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
  EventApi.Entity.Event,
  EventApi.DTO.Event,
  EventApi.Exceptions,
  EventApi.Container;

procedure SendError(const ARes: THorseResponse; const AStatus: THTTPStatus; const AMessage: string);
var
  LError: TJSONObject;
begin
  LError := TJSONObject.Create;
  LError.AddPair('message', AMessage);
  ARes.Status(AStatus).Send<TJSONObject>(LError);
end;

// Traduz as exceções de domínio em status HTTP.
// No capítulo 10 isto vira um middleware compartilhado por todas as rotas.
procedure HandleErrors(const ARes: THorseResponse; const AAction: TProc);
begin
  try
    AAction();
  except
    on E: EValidationException do
      SendError(ARes, THTTPStatus.BadRequest, E.Message);
    on E: ENotFoundException do
      SendError(ARes, THTTPStatus.NotFound, E.Message);
  end;
end;

function ParseId(const AValue: string): Integer;
begin
  if not TryStrToInt(AValue, Result) then
    raise EValidationException.Create('O id do evento deve ser um número inteiro.');
end;

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
      if not (Req.Body<TJSONValue> is TJSONObject) then
        raise EValidationException.Create('Envie os dados do evento como um objeto JSON.');

      LEvent := EventService.Add(TEventRequest.FromJSON(Req.Body<TJSONObject>));
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
