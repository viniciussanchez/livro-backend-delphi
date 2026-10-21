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
  Platform.Dates,
  Platform.Exceptions,
  EventApi.Entity.Event,
  EventApi.Entity.Batch,
  EventApi.DTO.Event,
  EventApi.Repository.Event,
  EventApi.Service.Event,
  EventApi.Container;

// Converte a query string da listagem em um TEventFilter.
// ?city=Belo Horizonte&category=1&from=2026-11-01&to=2026-11-30&status=published
function ParseFilter(const AReq: THorseRequest): TEventFilter;
var
  LValue: string;
begin
  Result := Default(TEventFilter);
  Result.City := AReq.Query['city'].Trim;

  LValue := AReq.Query['category'];
  if not LValue.IsEmpty and not TryStrToInt(LValue, Result.CategoryId) then
    raise EValidationException.Create('O filtro category deve ser o id numérico da categoria.');

  LValue := AReq.Query['from'];
  if not LValue.IsEmpty and not TryParseISODate(LValue, Result.DateFrom) then
    raise EValidationException.Create('O filtro from deve estar no formato aaaa-mm-dd.');

  LValue := AReq.Query['to'];
  if not LValue.IsEmpty and not TryParseISODate(LValue, Result.DateTo) then
    raise EValidationException.Create('O filtro to deve estar no formato aaaa-mm-dd.');

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
    if not TEventStatus.TryParse(LValue, Result.Status) then
      raise EValidationException.Create('O filtro status deve ser draft, published, cancelled ou all.');
  end;
end;

// GET /events
procedure GetEvents(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LEvents: TObjectList<TEvent>;
    begin
      LEvents := EventService.FindAll(ParseFilter(Req));
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
      LService: IEventService;
      LEvent: TEvent;
      LBatches: TObjectList<TBatch>;
    begin
      LService := EventService;
      LEvent := LService.FindById(ParseId(Req.Params['id']));
      try
        LBatches := LService.FindBatches(LEvent.Id);
        try
          Res.Send<TJSONObject>(TEventMapper.ToDetailJSON(LEvent, LBatches));
        finally
          LBatches.Free;
        end;
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

// POST /events/:id/publish
procedure PublishEvent(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
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
    end);
end;

// GET /events/:id/batches
procedure GetBatches(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LBatches: TObjectList<TBatch>;
    begin
      LBatches := EventService.FindBatches(ParseId(Req.Params['id']));
      try
        Res.Send<TJSONArray>(TBatchMapper.ToJSONArray(LBatches));
      finally
        LBatches.Free;
      end;
    end);
end;

// POST /events/:id/batches
procedure PostBatch(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
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
    end);
end;

procedure Registry;
begin
  THorse
    .Get('/events', GetEvents)
    .Get('/events/:id', GetEventById)
    .Post('/events', PostEvent)
    .Post('/events/:id/publish', PublishEvent)
    .Get('/events/:id/batches', GetBatches)
    .Post('/events/:id/batches', PostBatch);
end;

end.
