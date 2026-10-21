unit TicketApi.DTO;

interface

uses
  System.JSON,
  TicketApi.Entity.Batch,
  TicketApi.Entity.Reservation;

type
  // PUT /batches/:id - estoque de um lote à venda.
  TBatchRequest = record
    EventId: Integer;
    Price: Double;
    Quantity: Integer;
    SalesStart: string;
    SalesEnd: string;
    class function FromJSON(const AJSON: TJSONObject): TBatchRequest; static;
  end;

  // POST /reservations
  TReservationRequest = record
    CustomerId: Integer;
    BatchId: Integer;
    Quantity: Integer;
    class function FromJSON(const AJSON: TJSONObject): TReservationRequest; static;
  end;

  TTicketMapper = class
  public
    class function ToJSON(const ABatch: TBatchInventory): TJSONObject; overload; static;
    class function ToJSON(const AReservation: TReservation): TJSONObject; overload; static;
    class function ToJSON(const ATicket: TTicket): TJSONObject; overload; static;
  end;

implementation

uses
  System.SysUtils,
  Platform.Dates;

function MoneyToJSON(const AValue: Currency): TJSONNumber;
var
  LValue: Double;
begin
  LValue := AValue;
  Result := TJSONNumber.Create(LValue);
end;

function DateTimeOrNull(const AValue: TDateTime): TJSONValue;
begin
  if AValue = 0 then
    Result := TJSONNull.Create
  else
    Result := TJSONString.Create(FormatISODateTime(AValue));
end;

{ TBatchRequest }

class function TBatchRequest.FromJSON(const AJSON: TJSONObject): TBatchRequest;
begin
  Result.EventId := AJSON.GetValue<Integer>('eventId', 0);
  Result.Price := AJSON.GetValue<Double>('price', -1);
  Result.Quantity := AJSON.GetValue<Integer>('quantity', 0);
  Result.SalesStart := AJSON.GetValue<string>('salesStart', '').Trim;
  Result.SalesEnd := AJSON.GetValue<string>('salesEnd', '').Trim;
end;

{ TReservationRequest }

class function TReservationRequest.FromJSON(const AJSON: TJSONObject): TReservationRequest;
begin
  Result.CustomerId := AJSON.GetValue<Integer>('customerId', 0);
  Result.BatchId := AJSON.GetValue<Integer>('batchId', 0);
  Result.Quantity := AJSON.GetValue<Integer>('quantity', 0);
end;

{ TTicketMapper }

class function TTicketMapper.ToJSON(const ABatch: TBatchInventory): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(ABatch.Id));
  Result.AddPair('eventId', TJSONNumber.Create(ABatch.EventId));
  Result.AddPair('price', MoneyToJSON(ABatch.Price));
  Result.AddPair('quantity', TJSONNumber.Create(ABatch.Quantity));
  Result.AddPair('sold', TJSONNumber.Create(ABatch.Sold));
  Result.AddPair('available', TJSONNumber.Create(ABatch.Available));
  Result.AddPair('salesStart', FormatISODateTime(ABatch.SalesStart));
  Result.AddPair('salesEnd', FormatISODateTime(ABatch.SalesEnd));
end;

class function TTicketMapper.ToJSON(const AReservation: TReservation): TJSONObject;
var
  LTickets: TJSONArray;
  LTicket: TTicket;
  LItem: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(AReservation.Id));
  Result.AddPair('customerId', TJSONNumber.Create(AReservation.CustomerId));
  Result.AddPair('eventId', TJSONNumber.Create(AReservation.EventId));
  Result.AddPair('batchId', TJSONNumber.Create(AReservation.BatchId));
  Result.AddPair('quantity', TJSONNumber.Create(AReservation.Quantity));
  Result.AddPair('unitPrice', MoneyToJSON(AReservation.UnitPrice));
  Result.AddPair('total', MoneyToJSON(AReservation.Total));
  Result.AddPair('status', AReservation.Status.ToString);
  Result.AddPair('createdAt', FormatISODateTime(AReservation.CreatedAt));
  Result.AddPair('cancelledAt', DateTimeOrNull(AReservation.CancelledAt));

  LTickets := TJSONArray.Create;
  for LTicket in AReservation.Tickets do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('code', LTicket.Code);
    LItem.AddPair('status', LTicket.Status.ToString);
    LItem.AddPair('checkedInAt', DateTimeOrNull(LTicket.CheckedInAt));
    LTickets.AddElement(LItem);
  end;
  Result.AddPair('tickets', LTickets);
end;

class function TTicketMapper.ToJSON(const ATicket: TTicket): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('code', ATicket.Code);
  Result.AddPair('status', ATicket.Status.ToString);
  Result.AddPair('reservationId', TJSONNumber.Create(ATicket.ReservationId));
  Result.AddPair('eventId', TJSONNumber.Create(ATicket.EventId));
  Result.AddPair('checkedInAt', DateTimeOrNull(ATicket.CheckedInAt));
end;

end.
