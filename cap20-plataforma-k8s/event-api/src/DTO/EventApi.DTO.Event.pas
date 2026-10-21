unit EventApi.DTO.Event;

interface

uses
  System.JSON,
  System.Generics.Collections,
  EventApi.Entity.Event,
  EventApi.Entity.Batch;

type
  TEventRequest = record
    Name: string;
    Description: string;
    CategoryId: Integer;
    VenueId: Integer;
    StartAt: string;
    class function FromJSON(const AJSON: TJSONObject): TEventRequest; static;
  end;

  TBatchRequest = record
    Name: string;
    Price: Double;
    Quantity: Integer;
    SalesStart: string;
    SalesEnd: string;
    class function FromJSON(const AJSON: TJSONObject): TBatchRequest; static;
  end;

  TEventMapper = class
  public
    class function ToJSON(const AEvent: TEvent): TJSONObject; static;
    class function ToJSONArray(const AEvents: TObjectList<TEvent>): TJSONArray; static;
    // Evento com os seus lotes, usado na consulta de um evento.
    class function ToDetailJSON(const AEvent: TEvent; const ABatches: TObjectList<TBatch>): TJSONObject; static;
  end;

  TBatchMapper = class
  public
    class function ToJSON(const ABatch: TBatch): TJSONObject; static;
    class function ToJSONArray(const ABatches: TObjectList<TBatch>): TJSONArray; static;
    // Lote com um resumo do evento: o que os outros serviços precisam saber.
    class function ToCatalogJSON(const ABatch: TBatch; const AEvent: TEvent): TJSONObject; static;
  end;

implementation

uses
  System.SysUtils,
  Platform.Dates;

{ TEventRequest }

class function TEventRequest.FromJSON(const AJSON: TJSONObject): TEventRequest;
begin
  Result.Name := AJSON.GetValue<string>('name', '').Trim;
  Result.Description := AJSON.GetValue<string>('description', '').Trim;
  Result.CategoryId := AJSON.GetValue<Integer>('categoryId', 0);
  Result.VenueId := AJSON.GetValue<Integer>('venueId', 0);
  Result.StartAt := AJSON.GetValue<string>('startAt', '').Trim;
end;

{ TBatchRequest }

class function TBatchRequest.FromJSON(const AJSON: TJSONObject): TBatchRequest;
begin
  Result.Name := AJSON.GetValue<string>('name', '').Trim;
  Result.Price := AJSON.GetValue<Double>('price', -1);
  Result.Quantity := AJSON.GetValue<Integer>('quantity', 0);
  Result.SalesStart := AJSON.GetValue<string>('salesStart', '').Trim;
  Result.SalesEnd := AJSON.GetValue<string>('salesEnd', '').Trim;
end;

{ TEventMapper }

class function TEventMapper.ToJSON(const AEvent: TEvent): TJSONObject;
var
  LCategory, LVenue: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(AEvent.Id));
  Result.AddPair('name', AEvent.Name);
  Result.AddPair('description', AEvent.Description);
  Result.AddPair('startAt', FormatISODateTime(AEvent.StartAt));
  Result.AddPair('status', AEvent.Status.ToString);

  LCategory := TJSONObject.Create;
  LCategory.AddPair('id', TJSONNumber.Create(AEvent.CategoryId));
  LCategory.AddPair('name', AEvent.CategoryName);
  Result.AddPair('category', LCategory);

  LVenue := TJSONObject.Create;
  LVenue.AddPair('id', TJSONNumber.Create(AEvent.VenueId));
  LVenue.AddPair('name', AEvent.VenueName);
  LVenue.AddPair('city', AEvent.City);
  Result.AddPair('venue', LVenue);
end;

class function TEventMapper.ToJSONArray(const AEvents: TObjectList<TEvent>): TJSONArray;
var
  LEvent: TEvent;
begin
  Result := TJSONArray.Create;
  for LEvent in AEvents do
    Result.AddElement(ToJSON(LEvent));
end;

class function TEventMapper.ToDetailJSON(const AEvent: TEvent; const ABatches: TObjectList<TBatch>): TJSONObject;
begin
  Result := ToJSON(AEvent);
  Result.AddPair('batches', TBatchMapper.ToJSONArray(ABatches));
end;

{ TBatchMapper }

class function TBatchMapper.ToJSON(const ABatch: TBatch): TJSONObject;
var
  LPrice: Double;
begin
  LPrice := ABatch.Price;
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(ABatch.Id));
  Result.AddPair('eventId', TJSONNumber.Create(ABatch.EventId));
  Result.AddPair('name', ABatch.Name);
  Result.AddPair('price', TJSONNumber.Create(LPrice));
  Result.AddPair('quantity', TJSONNumber.Create(ABatch.Quantity));
  Result.AddPair('salesStart', FormatISODateTime(ABatch.SalesStart));
  Result.AddPair('salesEnd', FormatISODateTime(ABatch.SalesEnd));
end;

class function TBatchMapper.ToJSONArray(const ABatches: TObjectList<TBatch>): TJSONArray;
var
  LBatch: TBatch;
begin
  Result := TJSONArray.Create;
  for LBatch in ABatches do
    Result.AddElement(ToJSON(LBatch));
end;

class function TBatchMapper.ToCatalogJSON(const ABatch: TBatch; const AEvent: TEvent): TJSONObject;
var
  LEvent: TJSONObject;
begin
  Result := ToJSON(ABatch);
  LEvent := TJSONObject.Create;
  LEvent.AddPair('id', TJSONNumber.Create(AEvent.Id));
  LEvent.AddPair('name', AEvent.Name);
  LEvent.AddPair('status', AEvent.Status.ToString);
  LEvent.AddPair('startAt', FormatISODateTime(AEvent.StartAt));
  Result.AddPair('event', LEvent);
end;

end.
