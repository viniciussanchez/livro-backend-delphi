unit EventApi.Controller.Event;

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
  Platform.Exceptions,
  Platform.Dates,
  Platform.Validation,
  EventApi.Entity.Event,
  EventApi.Entity.Batch,
  EventApi.DTO.Event,
  EventApi.Repository.Event,
  EventApi.Service.Event,
  EventApi.Container;

// Rascunhos são do organizador: só a administração (e os outros serviços da
// plataforma, como a ticket-api) enxergam eventos que ainda não foram publicados.
function CanSeeDrafts(const AReq: THorseRequest): Boolean;
var
  LUser: TPrincipal;
begin
  Result := TryCurrentUser(AReq, LUser) and LUser.HasRole([ROLE_ADMIN, ROLE_SERVICE]);
end;

// Para quem não pode ver rascunhos, um rascunho simplesmente não existe:
// 404, pelo mesmo motivo do "404 em vez de 403" das reservas.
procedure EnsureVisible(const AReq: THorseRequest; const AEvent: TEvent);
begin
  if (AEvent.Status = esDraft) and not CanSeeDrafts(AReq) then
    raise ENotFoundException.Create('Evento não encontrado.');
end;

// Converte a query string da listagem em um TEventFilter.
// ?city=Belo Horizonte&category=1&from=2026-11-01&to=2026-11-30&status=published
function ParseFilter(const AReq: THorseRequest): TEventFilter;
var
  LValue: string;
  LValidation: TValidation;
begin
  Result := Default(TEventFilter);
  Result.City := AReq.Query['city'].Trim;

  // Todos os filtros são conferidos antes de responder:
  // quem errou dois parâmetros fica sabendo dos dois.
  LValue := AReq.Query['category'];
  LValidation.Check(LValue.IsEmpty or TryStrToInt(LValue, Result.CategoryId),
    'category', 'O filtro category deve ser o id numérico da categoria.');

  LValue := AReq.Query['from'];
  LValidation.Check(LValue.IsEmpty or TryParseISODate(LValue, Result.DateFrom),
    'from', 'O filtro from deve estar no formato aaaa-mm-dd.');

  LValue := AReq.Query['to'];
  LValidation.Check(LValue.IsEmpty or TryParseISODate(LValue, Result.DateTo),
    'to', 'O filtro to deve estar no formato aaaa-mm-dd.');

  // Sem status, a listagem mostra só o que está à venda: eventos publicados.
  LValue := AReq.Query['status'];
  if LValue.IsEmpty then
  begin
    Result.FilterByStatus := True;
    Result.Status := esPublished;
  end
  else if not SameText(LValue, 'all') then
  begin
    Result.FilterByStatus := True;
    LValidation.Check(TEventStatus.TryParse(LValue, Result.Status),
      'status', 'O filtro status deve ser draft, published, cancelled ou all.');
  end;

  LValidation.RaiseIfInvalid;

  // A vitrine é pública; rascunhos (status=draft ou all) são só da administração.
  if ((not Result.FilterByStatus) or (Result.Status = esDraft)) and not CanSeeDrafts(AReq) then
    raise EForbiddenException.Create('Somente a administração lista eventos em rascunho.');
end;

// GET /events
procedure GetEvents(Req: THorseRequest; Res: THorseResponse);
var
  LEvents: TObjectList<TEvent>;
begin
  LEvents := EventService.FindAll(ParseFilter(Req));
  try
    Res.Send<TJSONArray>(TEventMapper.ToJSONArray(LEvents));
  finally
    LEvents.Free;
  end;
end;

// GET /events/:id
procedure GetEventById(Req: THorseRequest; Res: THorseResponse);
var
  LService: IEventService;
  LEvent: TEvent;
  LBatches: TObjectList<TBatch>;
begin
  LService := EventService;
  LEvent := LService.FindById(ParseId(Req.Params['id']));
  try
    EnsureVisible(Req, LEvent);
    LBatches := LService.FindBatches(LEvent.Id);
    try
      Res.Send<TJSONObject>(TEventMapper.ToDetailJSON(LEvent, LBatches));
    finally
      LBatches.Free;
    end;
  finally
    LEvent.Free;
  end;
end;

// POST /events
procedure PostEvent(Req: THorseRequest; Res: THorseResponse);
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
end;

// POST /events/:id/publish
procedure PublishEvent(Req: THorseRequest; Res: THorseResponse);
var
  LService: IEventService;
  LId: Integer;
  LEvent: TEvent;
begin
  LService := EventService;
  LId := ParseId(Req.Params['id']);
  LService.Publish(LId);
  LEvent := LService.FindById(LId);
  try
    Res.Send<TJSONObject>(TEventMapper.ToJSON(LEvent));
  finally
    LEvent.Free;
  end;
end;

// GET /events/:id/batches
procedure GetBatches(Req: THorseRequest; Res: THorseResponse);
var
  LService: IEventService;
  LEvent: TEvent;
  LBatches: TObjectList<TBatch>;
begin
  LService := EventService;
  LEvent := LService.FindById(ParseId(Req.Params['id']));
  try
    EnsureVisible(Req, LEvent);
  finally
    LEvent.Free;
  end;
  LBatches := LService.FindBatches(ParseId(Req.Params['id']));
  try
    Res.Send<TJSONArray>(TBatchMapper.ToJSONArray(LBatches));
  finally
    LBatches.Free;
  end;
end;

// POST /events/:id/batches
procedure PostBatch(Req: THorseRequest; Res: THorseResponse);
var
  LBatch: TBatch;
begin
  LBatch := EventService.AddBatch(ParseId(Req.Params['id']),
    TBatchRequest.FromJSON(RequestBody(Req)));
  try
    Res.Status(THTTPStatus.Created).Send<TJSONObject>(TBatchMapper.ToJSON(LBatch));
  finally
    LBatch.Free;
  end;
end;

// GET /batches/:id
// Usada pela ticket-api para conhecer o lote e a situação do evento.
procedure GetBatchById(Req: THorseRequest; Res: THorseResponse);
var
  LService: IEventService;
  LBatch: TBatch;
  LEvent: TEvent;
begin
  LService := EventService;
  LBatch := LService.FindBatch(ParseId(Req.Params['id']));
  try
    LEvent := LService.FindById(LBatch.EventId);
    try
      EnsureVisible(Req, LEvent);
      Res.Send<TJSONObject>(TBatchMapper.ToCatalogJSON(LBatch, LEvent));
    finally
      LEvent.Free;
    end;
  finally
    LBatch.Free;
  end;
end;

procedure Registry;
begin
  // Consultas são públicas: é a vitrine da plataforma. O token é opcional:
  // com ele, a administração enxerga também os rascunhos.
  THorse.AddCallback(OptionalAuth()).Get('/events', GetEvents);
  THorse.AddCallback(OptionalAuth()).Get('/events/:id', GetEventById);
  THorse.AddCallback(OptionalAuth()).Get('/events/:id/batches', GetBatches);
  THorse.AddCallback(OptionalAuth()).Get('/batches/:id', GetBatchById);
  // Alterações, só administradores.
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Post('/events', PostEvent);
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Post('/events/:id/publish', PublishEvent);
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Post('/events/:id/batches', PostBatch);
end;

end.
