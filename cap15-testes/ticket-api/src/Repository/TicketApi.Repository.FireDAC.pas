unit TicketApi.Repository.FireDAC;

interface

uses
  Platform.Repository,
  TicketApi.Entity.Batch,
  TicketApi.Entity.Reservation,
  TicketApi.Repository;

type
  TBatchRepositoryFireDAC = class(TFireDACRepository, IBatchRepository)
  public
    function FindById(const AId: Integer): TBatchInventory;
    function Save(const ABatch: TBatchInventory; const ANow: TDateTime): Boolean;
    function TryTakeStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime;
      out AUnitPrice: Currency; out AEventId: Integer): Boolean;
    procedure ReleaseStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime);
  end;

  TReservationRepositoryFireDAC = class(TFireDACRepository, IReservationRepository)
  private
    procedure LoadTickets(const AReservation: TReservation; const ALock: Boolean = False);
  public
    function FindById(const AId: Integer; const ALock: Boolean = False): TReservation;
    procedure Insert(const AReservation: TReservation);
    procedure MarkCancelled(const AId: Integer; const ANow: TDateTime);
    function FindTicket(const ACode: string): TTicket;
    function TryCheckIn(const ACode: string; const ANow: TDateTime): Boolean;
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

function NullableDateTime(const AField: TField): TDateTime;
begin
  if AField.IsNull then
    Result := 0
  else
    Result := AField.AsDateTime;
end;

{ TBatchRepositoryFireDAC }

function TBatchRepositoryFireDAC.FindById(const AId: Integer): TBatchInventory;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := NewQuery(
    'select id, event_id, price, quantity, sold, sales_start, sales_end' +
    '  from batch_inventory where id = :id');
  try
    LQuery.ParamByName('id').AsInteger := AId;
    LQuery.Open;
    if LQuery.IsEmpty then
      Exit;
    Result := TBatchInventory.Create;
    Result.Id := LQuery.FieldByName('id').AsInteger;
    Result.EventId := LQuery.FieldByName('event_id').AsInteger;
    Result.Price := LQuery.FieldByName('price').AsCurrency;
    Result.Quantity := LQuery.FieldByName('quantity').AsInteger;
    Result.Sold := LQuery.FieldByName('sold').AsInteger;
    Result.SalesStart := LQuery.FieldByName('sales_start').AsDateTime;
    Result.SalesEnd := LQuery.FieldByName('sales_end').AsDateTime;
  finally
    LQuery.Free;
  end;
end;

function TBatchRepositoryFireDAC.Save(const ABatch: TBatchInventory; const ANow: TDateTime): Boolean;
var
  LQuery: TFDQuery;
begin
  // "Upsert": insere o lote ou, se ele já existir, atualiza. O "where" do
  // "do update" impede reduzir a quantidade para menos do que já foi vendido.
  LQuery := NewQuery(
    'insert into batch_inventory (id, event_id, price, quantity, sold, sales_start, sales_end, updated_at)' +
    ' values (:id, :event_id, :price, :quantity, 0, :sales_start, :sales_end, :now)' +
    ' on conflict (id) do update set' +
    '   event_id = excluded.event_id, price = excluded.price, quantity = excluded.quantity,' +
    '   sales_start = excluded.sales_start, sales_end = excluded.sales_end, updated_at = excluded.updated_at' +
    ' where batch_inventory.sold <= excluded.quantity' +
    ' returning sold');
  try
    LQuery.ParamByName('id').AsInteger := ABatch.Id;
    LQuery.ParamByName('event_id').AsInteger := ABatch.EventId;
    LQuery.ParamByName('price').AsBCD := ABatch.Price;
    LQuery.ParamByName('quantity').AsInteger := ABatch.Quantity;
    LQuery.ParamByName('sales_start').AsDateTime := ABatch.SalesStart;
    LQuery.ParamByName('sales_end').AsDateTime := ABatch.SalesEnd;
    LQuery.ParamByName('now').AsDateTime := ANow;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
    if Result then
      ABatch.Sold := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TBatchRepositoryFireDAC.TryTakeStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime;
  out AUnitPrice: Currency; out AEventId: Integer): Boolean;
var
  LQuery: TFDQuery;
begin
  // O coração do capítulo: verificar e baixar o estoque em um único comando.
  // O PostgreSQL trava a linha do lote durante o update; duas requisições
  // simultâneas nunca leem o mesmo "sold" e vendem o mesmo ingresso.
  LQuery := NewQuery(
    'update batch_inventory' +
    '   set sold = sold + :quantity, updated_at = :now' +
    ' where id = :id' +
    '   and sold + :quantity <= quantity' +
    '   and :now >= sales_start and :now < sales_end' +
    ' returning price, event_id');
  try
    LQuery.ParamByName('id').AsInteger := ABatchId;
    LQuery.ParamByName('quantity').AsInteger := AQuantity;
    LQuery.ParamByName('now').AsDateTime := ANow;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
    if Result then
    begin
      AUnitPrice := LQuery.FieldByName('price').AsCurrency;
      AEventId := LQuery.FieldByName('event_id').AsInteger;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TBatchRepositoryFireDAC.ReleaseStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime);
begin
  Connection.ExecSQL(
    'update batch_inventory set sold = sold - :quantity, updated_at = :now where id = :id',
    [AQuantity, ANow, ABatchId]);
end;

{ TReservationRepositoryFireDAC }

procedure TReservationRepositoryFireDAC.LoadTickets(const AReservation: TReservation; const ALock: Boolean);
var
  LQuery: TFDQuery;
  LTicket: TTicket;
begin
  LQuery := NewQuery(
    'select id, code, status, checked_in_at from ticket where reservation_id = :id order by id');
  try
    // No cancelamento, os ingressos também ficam travados: um check-in
    // simultâneo espera o cancelamento terminar e então é recusado.
    if ALock then
      LQuery.SQL.Add('for update');
    LQuery.ParamByName('id').AsInteger := AReservation.Id;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LTicket := TTicket.Create;
      AReservation.Tickets.Add(LTicket);
      LTicket.Id := LQuery.FieldByName('id').AsInteger;
      LTicket.ReservationId := AReservation.Id;
      LTicket.EventId := AReservation.EventId;
      LTicket.Code := LQuery.FieldByName('code').AsString;
      LTicket.Status := TTicketStatus.Parse(LQuery.FieldByName('status').AsString);
      LTicket.CheckedInAt := NullableDateTime(LQuery.FieldByName('checked_in_at'));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TReservationRepositoryFireDAC.FindById(const AId: Integer; const ALock: Boolean): TReservation;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := NewQuery(
    'select id, customer_id, batch_id, event_id, quantity, unit_price, status, created_at, cancelled_at' +
    '  from reservation where id = :id');
  try
    // "for update" trava a linha: outra transação que tente cancelar
    // a mesma reserva espera esta terminar.
    if ALock then
      LQuery.SQL.Add('for update');
    LQuery.ParamByName('id').AsInteger := AId;
    LQuery.Open;
    if LQuery.IsEmpty then
      Exit;
    Result := TReservation.Create;
    try
      Result.Id := LQuery.FieldByName('id').AsInteger;
      Result.CustomerId := LQuery.FieldByName('customer_id').AsInteger;
      Result.BatchId := LQuery.FieldByName('batch_id').AsInteger;
      Result.EventId := LQuery.FieldByName('event_id').AsInteger;
      Result.Quantity := LQuery.FieldByName('quantity').AsInteger;
      Result.UnitPrice := LQuery.FieldByName('unit_price').AsCurrency;
      Result.Status := TReservationStatus.Parse(LQuery.FieldByName('status').AsString);
      Result.CreatedAt := LQuery.FieldByName('created_at').AsDateTime;
      Result.CancelledAt := NullableDateTime(LQuery.FieldByName('cancelled_at'));
      LoadTickets(Result, ALock);
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TReservationRepositoryFireDAC.Insert(const AReservation: TReservation);
var
  LQuery: TFDQuery;
  LTicket: TTicket;
begin
  LQuery := NewQuery(
    'insert into reservation (customer_id, batch_id, event_id, quantity, unit_price, total, status, created_at)' +
    ' values (:customer_id, :batch_id, :event_id, :quantity, :unit_price, :total, :status, :created_at)' +
    ' returning id');
  try
    LQuery.ParamByName('customer_id').AsInteger := AReservation.CustomerId;
    LQuery.ParamByName('batch_id').AsInteger := AReservation.BatchId;
    LQuery.ParamByName('event_id').AsInteger := AReservation.EventId;
    LQuery.ParamByName('quantity').AsInteger := AReservation.Quantity;
    LQuery.ParamByName('unit_price').AsBCD := AReservation.UnitPrice;
    LQuery.ParamByName('total').AsBCD := AReservation.Total;
    LQuery.ParamByName('status').AsString := AReservation.Status.ToString;
    LQuery.ParamByName('created_at').AsDateTime := AReservation.CreatedAt;
    LQuery.Open;
    AReservation.Id := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;

  LQuery := NewQuery(
    'insert into ticket (reservation_id, code, status) values (:reservation_id, :code, :status) returning id');
  try
    for LTicket in AReservation.Tickets do
    begin
      LTicket.ReservationId := AReservation.Id;
      LQuery.Close;
      LQuery.ParamByName('reservation_id').AsInteger := AReservation.Id;
      LQuery.ParamByName('code').AsString := LTicket.Code;
      LQuery.ParamByName('status').AsString := LTicket.Status.ToString;
      LQuery.Open;
      LTicket.Id := LQuery.Fields[0].AsInteger;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TReservationRepositoryFireDAC.MarkCancelled(const AId: Integer; const ANow: TDateTime);
begin
  Connection.ExecSQL(
    'update reservation set status = ''CANCELLED'', cancelled_at = :now where id = :id',
    [ANow, AId]);
  Connection.ExecSQL(
    'update ticket set status = ''CANCELLED'' where reservation_id = :id and status = ''VALID''',
    [AId]);
end;

function TReservationRepositoryFireDAC.FindTicket(const ACode: string): TTicket;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := NewQuery(
    'select t.id, t.reservation_id, r.event_id, t.code, t.status, t.checked_in_at' +
    '  from ticket t join reservation r on r.id = t.reservation_id' +
    ' where t.code = :code');
  try
    LQuery.ParamByName('code').AsString := ACode;
    LQuery.Open;
    if LQuery.IsEmpty then
      Exit;
    Result := TTicket.Create;
    Result.Id := LQuery.FieldByName('id').AsInteger;
    Result.ReservationId := LQuery.FieldByName('reservation_id').AsInteger;
    Result.EventId := LQuery.FieldByName('event_id').AsInteger;
    Result.Code := LQuery.FieldByName('code').AsString;
    Result.Status := TTicketStatus.Parse(LQuery.FieldByName('status').AsString);
    Result.CheckedInAt := NullableDateTime(LQuery.FieldByName('checked_in_at'));
  finally
    LQuery.Free;
  end;
end;

function TReservationRepositoryFireDAC.TryCheckIn(const ACode: string; const ANow: TDateTime): Boolean;
begin
  // Mesmo princípio da venda: confere e altera em um único comando.
  // Se dois portões lerem o mesmo ingresso no mesmo instante, só um entra.
  Result := Connection.ExecSQL(
    'update ticket set status = ''USED'', checked_in_at = :now' +
    ' where code = :code and status = ''VALID''',
    [ANow, ACode]) > 0;
end;

end.
