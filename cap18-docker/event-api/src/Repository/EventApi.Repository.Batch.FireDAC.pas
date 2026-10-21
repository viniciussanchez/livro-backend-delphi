unit EventApi.Repository.Batch.FireDAC;

interface

uses
  System.Generics.Collections,
  Platform.Repository,
  EventApi.Entity.Batch,
  EventApi.Repository.Batch;

type
  TBatchRepositoryFireDAC = class(TFireDACRepository, IBatchRepository)
  public
    function FindByEvent(const AEventId: Integer): TObjectList<TBatch>;
    function FindById(const AId: Integer): TBatch;
    function TotalQuantity(const AEventId: Integer): Integer;
    procedure Insert(const ABatch: TBatch);
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

function ToEntity(const AQuery: TFDQuery): TBatch;
begin
  Result := TBatch.Create;
  Result.Id := AQuery.FieldByName('id').AsInteger;
  Result.EventId := AQuery.FieldByName('event_id').AsInteger;
  Result.Name := AQuery.FieldByName('name').AsString;
  Result.Price := AQuery.FieldByName('price').AsCurrency;
  Result.Quantity := AQuery.FieldByName('quantity').AsInteger;
  Result.SalesStart := AQuery.FieldByName('sales_start').AsDateTime;
  Result.SalesEnd := AQuery.FieldByName('sales_end').AsDateTime;
end;

function TBatchRepositoryFireDAC.FindByEvent(const AEventId: Integer): TObjectList<TBatch>;
var
  LQuery: TFDQuery;
begin
  Result := TObjectList<TBatch>.Create(True);
  try
    LQuery := NewQuery(
      'select id, event_id, name, price, quantity, sales_start, sales_end ' +
      '  from ticket_batch where event_id = :event_id order by sales_start, id');
    try
      LQuery.ParamByName('event_id').AsInteger := AEventId;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        Result.Add(ToEntity(LQuery));
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TBatchRepositoryFireDAC.FindById(const AId: Integer): TBatch;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := NewQuery(
    'select id, event_id, name, price, quantity, sales_start, sales_end ' +
    '  from ticket_batch where id = :id');
  try
    LQuery.ParamByName('id').AsInteger := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := ToEntity(LQuery);
  finally
    LQuery.Free;
  end;
end;

function TBatchRepositoryFireDAC.TotalQuantity(const AEventId: Integer): Integer;
begin
  Result := Connection.ExecSQLScalar(
    'select coalesce(sum(quantity), 0) from ticket_batch where event_id = :event_id', [AEventId]);
end;

procedure TBatchRepositoryFireDAC.Insert(const ABatch: TBatch);
var
  LQuery: TFDQuery;
begin
  LQuery := NewQuery(
    'insert into ticket_batch (event_id, name, price, quantity, sales_start, sales_end) ' +
    'values (:event_id, :name, :price, :quantity, :sales_start, :sales_end) returning id');
  try
    LQuery.ParamByName('event_id').AsInteger := ABatch.EventId;
    LQuery.ParamByName('name').AsString := ABatch.Name;
    // Dinheiro nunca em ponto flutuante: Currency no Delphi, numeric no PostgreSQL.
    LQuery.ParamByName('price').AsBCD := ABatch.Price;
    LQuery.ParamByName('quantity').AsInteger := ABatch.Quantity;
    LQuery.ParamByName('sales_start').AsDateTime := ABatch.SalesStart;
    LQuery.ParamByName('sales_end').AsDateTime := ABatch.SalesEnd;
    LQuery.Open;
    ABatch.Id := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

end.
