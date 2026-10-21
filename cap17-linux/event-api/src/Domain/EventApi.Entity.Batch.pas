unit EventApi.Entity.Batch;

interface

type
  // Lote de ingressos: um preço, uma quantidade e um período de vendas.
  // Ex.: "1º lote", R$ 150,00, 200 ingressos, de 01/11 a 15/11.
  TBatch = class
  private
    FId: Integer;
    FEventId: Integer;
    FName: string;
    FPrice: Currency;
    FQuantity: Integer;
    FSalesStart: TDateTime;
    FSalesEnd: TDateTime;
  public
    property Id: Integer read FId write FId;
    property EventId: Integer read FEventId write FEventId;
    property Name: string read FName write FName;
    property Price: Currency read FPrice write FPrice;
    property Quantity: Integer read FQuantity write FQuantity;
    property SalesStart: TDateTime read FSalesStart write FSalesStart;
    property SalesEnd: TDateTime read FSalesEnd write FSalesEnd;
  end;

implementation

end.
