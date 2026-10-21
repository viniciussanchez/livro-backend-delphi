unit TicketApi.Entity.Batch;

{ O estoque de um lote, do ponto de vista de quem vende.

  O lote nasce na event-api. A ticket-api guarda só o que precisa para vender:
  preço, quantidade, período de vendas e quantos já foram vendidos.
  No capítulo 12, esses dados passam a vir da event-api automaticamente. }

interface

type
  TBatchInventory = class
  private
    FId: Integer;
    FEventId: Integer;
    FPrice: Currency;
    FQuantity: Integer;
    FSold: Integer;
    FSalesStart: TDateTime;
    FSalesEnd: TDateTime;
  public
    function Available: Integer;
    function IsOnSale(const ANow: TDateTime): Boolean;
    // Mesmo id do lote na event-api.
    property Id: Integer read FId write FId;
    property EventId: Integer read FEventId write FEventId;
    property Price: Currency read FPrice write FPrice;
    property Quantity: Integer read FQuantity write FQuantity;
    property Sold: Integer read FSold write FSold;
    property SalesStart: TDateTime read FSalesStart write FSalesStart;
    property SalesEnd: TDateTime read FSalesEnd write FSalesEnd;
  end;

implementation

function TBatchInventory.Available: Integer;
begin
  Result := FQuantity - FSold;
end;

function TBatchInventory.IsOnSale(const ANow: TDateTime): Boolean;
begin
  Result := (ANow >= FSalesStart) and (ANow < FSalesEnd);
end;

end.
