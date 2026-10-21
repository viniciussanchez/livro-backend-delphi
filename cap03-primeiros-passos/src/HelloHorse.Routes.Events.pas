unit HelloHorse.Routes.Events;

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  Horse,
  HelloHorse.Store.Events;

procedure SendError(const ARes: THorseResponse; const AStatus: THTTPStatus; const AMessage: string);
var
  LError: TJSONObject;
begin
  LError := TJSONObject.Create;
  LError.AddPair('message', AMessage);
  ARes.Status(AStatus).Send<TJSONObject>(LError);
end;

// GET /events?city=Belo Horizonte
procedure GetEvents(Req: THorseRequest; Res: THorseResponse);
var
  LEvent: TEvent;
  LEvents: TJSONArray;
begin
  LEvents := TJSONArray.Create;
  for LEvent in EventStore.FindAll(Req.Query['city']) do
    LEvents.AddElement(LEvent.ToJSON);
  Res.Send<TJSONArray>(LEvents);
end;

// GET /events/:id
procedure GetEventById(Req: THorseRequest; Res: THorseResponse);
var
  LId: Integer;
  LEvent: TEvent;
begin
  if not TryStrToInt(Req.Params['id'], LId) then
  begin
    SendError(Res, THTTPStatus.BadRequest, 'O id do evento deve ser um número inteiro.');
    Exit;
  end;

  if not EventStore.TryFindById(LId, LEvent) then
  begin
    SendError(Res, THTTPStatus.NotFound, 'Evento não encontrado.');
    Exit;
  end;

  Res.Send<TJSONObject>(LEvent.ToJSON);
end;

// POST /events
procedure PostEvent(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LName, LCity, LDateText: string;
  LCapacity: Integer;
  LDate: TDate;
  LEvent: TEvent;
begin
  // O Jhonson só converte o body quando o Content-Type é application/json.
  // O conteúdo pode ser um objeto, um array ou nada; aqui só aceitamos objeto.
  if not (Req.Body<TJSONValue> is TJSONObject) then
  begin
    SendError(Res, THTTPStatus.BadRequest, 'Envie os dados do evento como um objeto JSON.');
    Exit;
  end;
  LBody := Req.Body<TJSONObject>;

  LName := LBody.GetValue<string>('name', '').Trim;
  LCity := LBody.GetValue<string>('city', '').Trim;
  LDateText := LBody.GetValue<string>('eventDate', '');
  LCapacity := LBody.GetValue<Integer>('capacity', 0);

  if LName.IsEmpty then
  begin
    SendError(Res, THTTPStatus.BadRequest, 'Informe o nome do evento.');
    Exit;
  end;

  if LCity.IsEmpty then
  begin
    SendError(Res, THTTPStatus.BadRequest, 'Informe a cidade do evento.');
    Exit;
  end;

  if not TryParseISODate(LDateText, LDate) then
  begin
    SendError(Res, THTTPStatus.BadRequest, 'Informe a data do evento no formato aaaa-mm-dd.');
    Exit;
  end;

  if LCapacity <= 0 then
  begin
    SendError(Res, THTTPStatus.BadRequest, 'A capacidade do evento deve ser maior que zero.');
    Exit;
  end;

  LEvent := EventStore.Add(LName, LCity, LDate, LCapacity);

  Res.AddHeader('Location', '/events/' + LEvent.Id.ToString);
  Res.Status(THTTPStatus.Created).Send<TJSONObject>(LEvent.ToJSON);
end;

// DELETE /events/:id
procedure DeleteEvent(Req: THorseRequest; Res: THorseResponse);
var
  LId: Integer;
begin
  if not TryStrToInt(Req.Params['id'], LId) then
  begin
    SendError(Res, THTTPStatus.BadRequest, 'O id do evento deve ser um número inteiro.');
    Exit;
  end;

  if not EventStore.Remove(LId) then
  begin
    SendError(Res, THTTPStatus.NotFound, 'Evento não encontrado.');
    Exit;
  end;

  Res.Status(THTTPStatus.NoContent);
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
