unit TicketApi.Docs;

{ Documentação Swagger da ticket-api.
  Acesse http://localhost:9003/swagger/doc/html com a API no ar. }

interface

uses
  System.Generics.Collections,
  GBSwagger.Model.Attributes;

type
  [SwagClass('BatchStockRequest')]
  TBatchStockRequestDoc = class
  private
    FEventId: Integer;
    FPrice: Currency;
    FQuantity: Integer;
    FSalesStart: string;
    FSalesEnd: string;
  public
    [SwagProp('Id do evento na event-api', True)]
    property EventId: Integer read FEventId write FEventId;
    [SwagProp('Preço em reais; zero para ingressos gratuitos', True)]
    property Price: Currency read FPrice write FPrice;
    [SwagProp('Quantidade total; não pode ficar abaixo do que já foi vendido', True)]
    property Quantity: Integer read FQuantity write FQuantity;
    [SwagProp('Início das vendas, aaaa-mm-ddThh:mm:ss', True)]
    property SalesStart: string read FSalesStart write FSalesStart;
    [SwagProp('Fim das vendas, aaaa-mm-ddThh:mm:ss', True)]
    property SalesEnd: string read FSalesEnd write FSalesEnd;
  end;

  [SwagClass('BatchStock')]
  TBatchStockDoc = class(TBatchStockRequestDoc)
  private
    FId: Integer;
    FSold: Integer;
    FAvailable: Integer;
  public
    [SwagProp('Mesmo id do lote na event-api', True)]
    property Id: Integer read FId write FId;
    [SwagProp('Ingressos vendidos', False, True)]
    property Sold: Integer read FSold write FSold;
    [SwagProp('Ingressos disponíveis', False, True)]
    property Available: Integer read FAvailable write FAvailable;
  end;

  [SwagClass('ReservationRequest')]
  TReservationRequestDoc = class
  private
    FCustomerId: Integer;
    FBatchId: Integer;
    FQuantity: Integer;
  public
    [SwagProp('Id do participante na customer-api', True)]
    property CustomerId: Integer read FCustomerId write FCustomerId;
    [SwagProp('Id do lote', True)]
    property BatchId: Integer read FBatchId write FBatchId;
    [SwagProp('De 1 a 6 ingressos por reserva', True)]
    property Quantity: Integer read FQuantity write FQuantity;
  end;

  [SwagClass('ReservationTicket')]
  TReservationTicketDoc = class
  private
    FCode: string;
    FStatus: string;
    FCheckedInAt: string;
  public
    [SwagProp('Código apresentado na portaria', True)]
    property Code: string read FCode write FCode;
    [SwagProp('VALID, USED ou CANCELLED', True)]
    property Status: string read FStatus write FStatus;
    [SwagProp('Momento do check-in; null se ainda não entrou', False)]
    property CheckedInAt: string read FCheckedInAt write FCheckedInAt;
  end;

  [SwagClass('Reservation')]
  TReservationDoc = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FEventId: Integer;
    FBatchId: Integer;
    FQuantity: Integer;
    FUnitPrice: Currency;
    FTotal: Currency;
    FStatus: string;
    FCreatedAt: string;
    FCancelledAt: string;
    FTickets: TObjectList<TReservationTicketDoc>;
  public
    property Id: Integer read FId write FId;
    property CustomerId: Integer read FCustomerId write FCustomerId;
    property EventId: Integer read FEventId write FEventId;
    property BatchId: Integer read FBatchId write FBatchId;
    property Quantity: Integer read FQuantity write FQuantity;
    [SwagProp('Preço de cada ingresso no momento da compra', True)]
    property UnitPrice: Currency read FUnitPrice write FUnitPrice;
    property Total: Currency read FTotal write FTotal;
    [SwagProp('ACTIVE ou CANCELLED', True)]
    property Status: string read FStatus write FStatus;
    property CreatedAt: string read FCreatedAt write FCreatedAt;
    [SwagProp('null enquanto a reserva estiver ativa', False)]
    property CancelledAt: string read FCancelledAt write FCancelledAt;
    property Tickets: TObjectList<TReservationTicketDoc> read FTickets write FTickets;
  end;

  [SwagClass('Ticket')]
  TTicketDoc = class(TReservationTicketDoc)
  private
    FReservationId: Integer;
    FEventId: Integer;
  public
    property ReservationId: Integer read FReservationId write FReservationId;
    property EventId: Integer read FEventId write FEventId;
  end;

  [SwagClass('BatchSales')]
  TBatchSalesDoc = class
  private
    FBatchId: Integer;
    FPrice: Currency;
    FQuantity: Integer;
    FSold: Integer;
    FAvailable: Integer;
    FActiveReservations: Integer;
    FCancelledReservations: Integer;
    FRevenue: Currency;
  public
    property BatchId: Integer read FBatchId write FBatchId;
    property Price: Currency read FPrice write FPrice;
    property Quantity: Integer read FQuantity write FQuantity;
    property Sold: Integer read FSold write FSold;
    property Available: Integer read FAvailable write FAvailable;
    property ActiveReservations: Integer read FActiveReservations write FActiveReservations;
    property CancelledReservations: Integer read FCancelledReservations write FCancelledReservations;
    [SwagProp('Soma das reservas ativas', True)]
    property Revenue: Currency read FRevenue write FRevenue;
  end;

  [SwagClass('SalesTotals')]
  TSalesTotalsDoc = class
  private
    FQuantity: Integer;
    FSold: Integer;
    FRevenue: Currency;
  public
    property Quantity: Integer read FQuantity write FQuantity;
    property Sold: Integer read FSold write FSold;
    property Revenue: Currency read FRevenue write FRevenue;
  end;

  [SwagClass('EventSales')]
  TEventSalesDoc = class
  private
    FEventId: Integer;
    FEventName: string;
    FBatches: TObjectList<TBatchSalesDoc>;
    FTotals: TSalesTotalsDoc;
  public
    property EventId: Integer read FEventId write FEventId;
    [SwagProp('Nome do evento, vindo da event-api; null se ela não responder', False)]
    property EventName: string read FEventName write FEventName;
    property Batches: TObjectList<TBatchSalesDoc> read FBatches write FBatches;
    property Totals: TSalesTotalsDoc read FTotals write FTotals;
  end;

  [SwagClass('EventAttendance')]
  TEventAttendanceDoc = class
  private
    FEventId: Integer;
    FCapacity: Integer;
    FTicketsIssued: Integer;
    FCheckedIn: Integer;
    FTicketsCancelled: Integer;
    FOccupancyRate: Double;
    FAttendanceRate: Double;
  public
    property EventId: Integer read FEventId write FEventId;
    [SwagProp('Soma das quantidades dos lotes', True)]
    property Capacity: Integer read FCapacity write FCapacity;
    property TicketsIssued: Integer read FTicketsIssued write FTicketsIssued;
    property CheckedIn: Integer read FCheckedIn write FCheckedIn;
    property TicketsCancelled: Integer read FTicketsCancelled write FTicketsCancelled;
    [SwagProp('Percentual da capacidade vendida, uma casa decimal', True)]
    property OccupancyRate: Double read FOccupancyRate write FOccupancyRate;
    [SwagProp('Percentual dos ingressos emitidos que fizeram check-in', True)]
    property AttendanceRate: Double read FAttendanceRate write FAttendanceRate;
  end;

  [SwagClass('RevenuePeriod')]
  TRevenuePeriodDoc = class
  private
    FPeriod: string;
    FReservations: Integer;
    FTickets: Integer;
    FRevenue: Currency;
  public
    [SwagProp('Primeiro dia do período, aaaa-mm-dd', True)]
    property Period: string read FPeriod write FPeriod;
    property Reservations: Integer read FReservations write FReservations;
    property Tickets: Integer read FTickets write FTickets;
    property Revenue: Currency read FRevenue write FRevenue;
  end;

  [SwagClass('Revenue')]
  TRevenueDoc = class
  private
    FFrom: string;
    FTo: string;
    FGroupBy: string;
    FPeriods: TObjectList<TRevenuePeriodDoc>;
    FTotalTickets: Integer;
    FTotalRevenue: Currency;
  public
    property From: string read FFrom write FFrom;
    property &To: string read FTo write FTo;
    property GroupBy: string read FGroupBy write FGroupBy;
    [SwagProp('Somente os períodos com vendas', True)]
    property Periods: TObjectList<TRevenuePeriodDoc> read FPeriods write FPeriods;
    property TotalTickets: Integer read FTotalTickets write FTotalTickets;
    property TotalRevenue: Currency read FTotalRevenue write FTotalRevenue;
  end;

procedure Configure;

implementation

uses
  Horse.GBSwagger,
  Platform.Docs;

procedure Configure;
begin
  ConfigureSwagger('ticket-api',
    'Estoque de lotes, reservas, ingressos, check-in e relatórios de vendas.');

  Swagger
    .Path('/batches/{id}')
      .Tag('Estoque')
      .PUT('Cria ou atualiza o estoque de um lote',
        'O id é o mesmo do lote na event-api. No capítulo 12 esta sincronização passa a ser automática.')
        .AddParamPath('id', 'Id do lote').Schema(SWAG_INTEGER).Required(True).&End
        .AddParamBody('body', 'Dados do lote').Schema(TBatchStockRequestDoc).&End
        .AddResponse(200, 'Estoque gravado').Schema(TBatchStockDoc).&End
        .AddResponse(400).&End
        .AddResponse(409, 'Quantidade menor do que a já vendida').&End
        .AddResponse(422).&End
      .&End
      .GET('Consulta o estoque de um lote')
        .AddParamPath('id', 'Id do lote').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Estoque do lote').Schema(TBatchStockDoc).&End
        .AddResponse(404).&End
      .&End
    .&End

    .Path('/reservations')
      .Tag('Reservas')
      .POST('Reserva ingressos',
        'Confere o participante na customer-api e o lote na event-api. ' +
        'Erros 409 trazem o code sold-out ou insufficient-stock; 422 traz sales-closed ou event-not-on-sale.')
        .AddParamBody('body', 'Dados da reserva').Schema(TReservationRequestDoc).&End
        .AddResponse(201, 'Reserva criada, com os ingressos emitidos').Schema(TReservationDoc).&End
        .AddResponse(400).&End
        .AddResponse(404).&End
        .AddResponse(409, 'Ingressos esgotados ou insuficientes').&End
        .AddResponse(422, 'Vendas do lote fechadas ou evento não publicado').&End
        .AddResponse(503, 'event-api ou customer-api indisponível').&End
      .&End
    .&End
    .Path('/reservations/{id}')
      .Tag('Reservas')
      .GET('Busca uma reserva')
        .AddParamPath('id', 'Id da reserva').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Reserva encontrada').Schema(TReservationDoc).&End
        .AddResponse(404).&End
      .&End
    .&End
    .Path('/reservations/{id}/cancel')
      .Tag('Reservas')
      .POST('Cancela uma reserva', 'Os ingressos são cancelados e voltam ao estoque do lote.')
        .AddParamPath('id', 'Id da reserva').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Reserva cancelada').Schema(TReservationDoc).&End
        .AddResponse(404).&End
        .AddResponse(409, 'Reserva já cancelada ou com ingresso usado').&End
      .&End
    .&End

    .Path('/tickets/{code}')
      .Tag('Portaria')
      .GET('Consulta um ingresso pelo código')
        .AddParamPath('code', 'Código do ingresso').Schema(SWAG_STRING).Required(True).&End
        .AddResponse(200, 'Ingresso encontrado').Schema(TTicketDoc).&End
        .AddResponse(404).&End
      .&End
    .&End
    .Path('/tickets/{code}/check-in')
      .Tag('Portaria')
      .POST('Registra a entrada do participante',
        'Erros 409 trazem o code ticket-already-used ou ticket-cancelled.')
        .AddParamPath('code', 'Código do ingresso').Schema(SWAG_STRING).Required(True).&End
        .AddResponse(200, 'Entrada registrada').Schema(TTicketDoc).&End
        .AddResponse(404).&End
        .AddResponse(409, 'Ingresso já usado ou cancelado').&End
      .&End
    .&End

    .Path('/reports/events/{eventId}/sales')
      .Tag('Relatórios')
      .GET('Vendas de um evento, lote por lote')
        .AddParamPath('eventId', 'Id do evento').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Vendas do evento').Schema(TEventSalesDoc).&End
        .AddResponse(400).&End
        .AddResponse(404, 'Nenhum lote à venda para o evento').&End
      .&End
    .&End
    .Path('/reports/events/{eventId}/attendance')
      .Tag('Relatórios')
      .GET('Ocupação e comparecimento de um evento')
        .AddParamPath('eventId', 'Id do evento').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Ocupação e comparecimento').Schema(TEventAttendanceDoc).&End
        .AddResponse(400).&End
        .AddResponse(404, 'Nenhum lote à venda para o evento').&End
      .&End
    .&End
    .Path('/reports/revenue')
      .Tag('Relatórios')
      .GET('Faturamento por dia ou por mês',
        'Considera apenas reservas ativas. Por dia, o período pode ter no máximo 366 dias.')
        .AddParamQuery('from', 'Data inicial, aaaa-mm-dd').Schema(SWAG_STRING).Required(True).&End
        .AddParamQuery('to', 'Data final, inclusive, aaaa-mm-dd').Schema(SWAG_STRING).Required(True).&End
        .AddParamQuery('groupBy', 'day (padrão) ou month').Schema(SWAG_STRING).&End
        .AddParamQuery('eventId', 'Somente um evento').Schema(SWAG_INTEGER).&End
        .AddResponse(200, 'Faturamento do período').Schema(TRevenueDoc).&End
        .AddResponse(400).&End
      .&End
    .&End;
end;

end.
