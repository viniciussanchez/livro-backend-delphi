unit TicketApi.Entity.Reservation;

interface

uses
  System.Generics.Collections;

type
  TReservationStatus = (rsActive, rsCancelled);
  TTicketStatus = (tsValid, tsUsed, tsCancelled);

  TReservationStatusHelper = record helper for TReservationStatus
    function ToString: string;
    class function Parse(const AValue: string): TReservationStatus; static;
  end;

  TTicketStatusHelper = record helper for TTicketStatus
    function ToString: string;
    class function Parse(const AValue: string): TTicketStatus; static;
  end;

  // Um ingresso: uma pessoa, uma entrada. É ele que é apresentado na portaria.
  TTicket = class
  private
    FId: Integer;
    FReservationId: Integer;
    FEventId: Integer;
    FCode: string;
    FStatus: TTicketStatus;
    FCheckedInAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property ReservationId: Integer read FReservationId write FReservationId;
    property EventId: Integer read FEventId write FEventId;
    property Code: string read FCode write FCode;
    property Status: TTicketStatus read FStatus write FStatus;
    // Zero enquanto o ingresso não foi usado.
    property CheckedInAt: TDateTime read FCheckedInAt write FCheckedInAt;
  end;

  // Uma compra: um participante, um lote, uma quantidade de ingressos.
  TReservation = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FBatchId: Integer;
    FEventId: Integer;
    FQuantity: Integer;
    FUnitPrice: Currency;
    FStatus: TReservationStatus;
    FCreatedAt: TDateTime;
    FCancelledAt: TDateTime;
    FTickets: TObjectList<TTicket>;
  public
    constructor Create;
    destructor Destroy; override;
    function Total: Currency;
    property Id: Integer read FId write FId;
    property CustomerId: Integer read FCustomerId write FCustomerId;
    property BatchId: Integer read FBatchId write FBatchId;
    property EventId: Integer read FEventId write FEventId;
    property Quantity: Integer read FQuantity write FQuantity;
    // Preço no momento da compra: se o lote mudar de preço depois, a reserva não muda.
    property UnitPrice: Currency read FUnitPrice write FUnitPrice;
    property Status: TReservationStatus read FStatus write FStatus;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property CancelledAt: TDateTime read FCancelledAt write FCancelledAt;
    property Tickets: TObjectList<TTicket> read FTickets;
  end;

implementation

uses
  System.SysUtils;

const
  RESERVATION_STATUS: array[TReservationStatus] of string = ('ACTIVE', 'CANCELLED');
  TICKET_STATUS: array[TTicketStatus] of string = ('VALID', 'USED', 'CANCELLED');

function TReservationStatusHelper.ToString: string;
begin
  Result := RESERVATION_STATUS[Self];
end;

class function TReservationStatusHelper.Parse(const AValue: string): TReservationStatus;
var
  LStatus: TReservationStatus;
begin
  for LStatus := Low(TReservationStatus) to High(TReservationStatus) do
    if SameText(RESERVATION_STATUS[LStatus], AValue) then
      Exit(LStatus);
  raise EArgumentException.CreateFmt('Status de reserva desconhecido: %s', [AValue]);
end;

function TTicketStatusHelper.ToString: string;
begin
  Result := TICKET_STATUS[Self];
end;

class function TTicketStatusHelper.Parse(const AValue: string): TTicketStatus;
var
  LStatus: TTicketStatus;
begin
  for LStatus := Low(TTicketStatus) to High(TTicketStatus) do
    if SameText(TICKET_STATUS[LStatus], AValue) then
      Exit(LStatus);
  raise EArgumentException.CreateFmt('Status de ingresso desconhecido: %s', [AValue]);
end;

constructor TReservation.Create;
begin
  inherited Create;
  FTickets := TObjectList<TTicket>.Create(True);
end;

destructor TReservation.Destroy;
begin
  FTickets.Free;
  inherited;
end;

function TReservation.Total: Currency;
begin
  Result := FUnitPrice * FQuantity;
end;

end.
