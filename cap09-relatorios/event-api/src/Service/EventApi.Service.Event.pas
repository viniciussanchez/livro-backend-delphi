unit EventApi.Service.Event;

{ Regras de negócio dos eventos e dos seus lotes de ingressos. }

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Event,
  EventApi.Entity.Batch,
  EventApi.DTO.Event,
  EventApi.Repository.Event,
  EventApi.Repository.Batch,
  EventApi.Repository.Venue,
  EventApi.Repository.Category;

type
  IEventService = interface
    ['{C24E7A19-5D83-4B0F-A6E2-9F31D8B07C54}']
    function FindAll(const AFilter: TEventFilter): TObjectList<TEvent>;
    function FindById(const AId: Integer): TEvent;
    function FindBatches(const AEventId: Integer): TObjectList<TBatch>;
    function Add(const ARequest: TEventRequest): TEvent;
    procedure Publish(const AId: Integer);
    function AddBatch(const AEventId: Integer; const ARequest: TBatchRequest): TBatch;
  end;

  TEventService = class(TInterfacedObject, IEventService)
  private
    FEvents: IEventRepository;
    FBatches: IBatchRepository;
    FVenues: IVenueRepository;
    FCategories: ICategoryRepository;
    procedure ValidateEvent(const ARequest: TEventRequest; out AStartAt: TDateTime);
    procedure ValidateBatch(const AEvent: TEvent; const ARequest: TBatchRequest;
      out ASalesStart, ASalesEnd: TDateTime);
  public
    constructor Create(const AEvents: IEventRepository; const ABatches: IBatchRepository;
      const AVenues: IVenueRepository; const ACategories: ICategoryRepository);
    function FindAll(const AFilter: TEventFilter): TObjectList<TEvent>;
    function FindById(const AId: Integer): TEvent;
    function FindBatches(const AEventId: Integer): TObjectList<TBatch>;
    function Add(const ARequest: TEventRequest): TEvent;
    procedure Publish(const AId: Integer);
    function AddBatch(const AEventId: Integer; const ARequest: TBatchRequest): TBatch;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Platform.Exceptions,
  Platform.Dates,
  EventApi.Entity.Venue,
  EventApi.Entity.Category;

constructor TEventService.Create(const AEvents: IEventRepository; const ABatches: IBatchRepository;
  const AVenues: IVenueRepository; const ACategories: ICategoryRepository);
begin
  inherited Create;
  FEvents := AEvents;
  FBatches := ABatches;
  FVenues := AVenues;
  FCategories := ACategories;
end;

procedure TEventService.ValidateEvent(const ARequest: TEventRequest; out AStartAt: TDateTime);
var
  LCategory: TCategory;
  LVenue: TVenue;
begin
  if ARequest.Name.IsEmpty then
    raise EValidationException.Create('Informe o nome do evento.');
  if ARequest.Name.Length > 150 then
    raise EValidationException.Create('O nome do evento deve ter no máximo 150 caracteres.');
  if not TryParseISODateTime(ARequest.StartAt, AStartAt) then
    raise EValidationException.Create('Informe o início do evento no formato aaaa-mm-ddThh:mm:ss.');

  LCategory := FCategories.FindById(ARequest.CategoryId);
  if not Assigned(LCategory) then
    raise EValidationException.Create('A categoria informada não existe.');
  LCategory.Free;

  LVenue := FVenues.FindById(ARequest.VenueId);
  if not Assigned(LVenue) then
    raise EValidationException.Create('O local informado não existe.');
  LVenue.Free;

  if AStartAt <= Now then
    raise EBusinessRuleException.Create('O evento precisa começar em uma data futura.');
end;

procedure TEventService.ValidateBatch(const AEvent: TEvent; const ARequest: TBatchRequest;
  out ASalesStart, ASalesEnd: TDateTime);
var
  LVenue: TVenue;
  LTotal: Integer;
begin
  if ARequest.Name.IsEmpty then
    raise EValidationException.Create('Informe o nome do lote.');
  if ARequest.Price < 0 then
    raise EValidationException.Create('Informe o preço do lote (zero para ingressos gratuitos).');
  if ARequest.Quantity <= 0 then
    raise EValidationException.Create('A quantidade de ingressos do lote deve ser maior que zero.');
  if not TryParseISODateTime(ARequest.SalesStart, ASalesStart) then
    raise EValidationException.Create('Informe o início das vendas no formato aaaa-mm-ddThh:mm:ss.');
  if not TryParseISODateTime(ARequest.SalesEnd, ASalesEnd) then
    raise EValidationException.Create('Informe o fim das vendas no formato aaaa-mm-ddThh:mm:ss.');

  if AEvent.Status = esCancelled then
    raise EConflictException.Create('Não é possível criar lotes para um evento cancelado.');
  if ASalesStart >= ASalesEnd then
    raise EBusinessRuleException.Create('O fim das vendas deve ser depois do início.');
  if ASalesEnd > AEvent.StartAt then
    raise EBusinessRuleException.Create('As vendas do lote precisam terminar até o início do evento.');

  // A soma de todos os lotes não pode passar da capacidade do local.
  LVenue := FVenues.FindById(AEvent.VenueId);
  try
    LTotal := FBatches.TotalQuantity(AEvent.Id) + ARequest.Quantity;
    if LTotal > LVenue.Capacity then
      raise EBusinessRuleException.CreateFmt(
        'Os lotes somariam %d ingressos, mas o local comporta %d pessoas.', [LTotal, LVenue.Capacity]);
  finally
    LVenue.Free;
  end;
end;

function TEventService.FindAll(const AFilter: TEventFilter): TObjectList<TEvent>;
begin
  Result := FEvents.FindAll(AFilter);
end;

function TEventService.FindById(const AId: Integer): TEvent;
begin
  Result := FEvents.FindById(AId);
  if not Assigned(Result) then
    raise ENotFoundException.Create('Evento não encontrado.');
end;

function TEventService.FindBatches(const AEventId: Integer): TObjectList<TBatch>;
begin
  // Garante o 404 quando o evento não existe, em vez de uma lista vazia.
  FindById(AEventId).Free;
  Result := FBatches.FindByEvent(AEventId);
end;

function TEventService.Add(const ARequest: TEventRequest): TEvent;
var
  LStartAt: TDateTime;
  LEvent: TEvent;
begin
  ValidateEvent(ARequest, LStartAt);

  LEvent := TEvent.Create;
  try
    LEvent.Name := ARequest.Name;
    LEvent.Description := ARequest.Description;
    LEvent.CategoryId := ARequest.CategoryId;
    LEvent.VenueId := ARequest.VenueId;
    LEvent.StartAt := LStartAt;
    LEvent.Status := esDraft;
    FEvents.Insert(LEvent);
    // Relemos o evento para devolver também os nomes da categoria e do local.
    Result := FindById(LEvent.Id);
  finally
    LEvent.Free;
  end;
end;

procedure TEventService.Publish(const AId: Integer);
var
  LEvent: TEvent;
  LBatches: TObjectList<TBatch>;
begin
  LEvent := FindById(AId);
  try
    if LEvent.Status <> esDraft then
      raise EConflictException.Create('Somente eventos em rascunho podem ser publicados.');
    if LEvent.StartAt <= Now then
      raise EBusinessRuleException.Create('Não é possível publicar um evento que já começou.');

    LBatches := FBatches.FindByEvent(AId);
    try
      if LBatches.Count = 0 then
        raise EBusinessRuleException.Create('Cadastre ao menos um lote de ingressos antes de publicar.');
    finally
      LBatches.Free;
    end;

    FEvents.UpdateStatus(AId, esPublished);
  finally
    LEvent.Free;
  end;
end;

function TEventService.AddBatch(const AEventId: Integer; const ARequest: TBatchRequest): TBatch;
var
  LEvent: TEvent;
  LSalesStart, LSalesEnd: TDateTime;
begin
  LEvent := FindById(AEventId);
  try
    ValidateBatch(LEvent, ARequest, LSalesStart, LSalesEnd);

    Result := TBatch.Create;
    try
      Result.EventId := AEventId;
      Result.Name := ARequest.Name;
      // Arredonda para centavos antes de guardar como Currency.
      Result.Price := SimpleRoundTo(ARequest.Price, -2);
      Result.Quantity := ARequest.Quantity;
      Result.SalesStart := LSalesStart;
      Result.SalesEnd := LSalesEnd;
      FBatches.Insert(Result);
    except
      Result.Free;
      raise;
    end;
  finally
    LEvent.Free;
  end;
end;

end.
