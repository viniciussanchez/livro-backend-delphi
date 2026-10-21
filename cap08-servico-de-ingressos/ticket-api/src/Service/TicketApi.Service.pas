unit TicketApi.Service;

{ Regras de negócio da venda de ingressos. }

interface

uses
  Platform.Transactions,
  TicketApi.Entity.Batch,
  TicketApi.Entity.Reservation,
  TicketApi.DTO,
  TicketApi.Repository;

const
  MAX_TICKETS_PER_RESERVATION = 6;

type
  IBatchService = interface
    ['{F1C86A3D-2B57-4E90-8D14-A6E3C0B7925F}']
    function FindById(const AId: Integer): TBatchInventory;
    function Save(const AId: Integer; const ARequest: TBatchRequest): TBatchInventory;
  end;

  IReservationService = interface
    ['{8A2E5F16-C3D0-4B79-9E41-7D6B0A3C8E52}']
    function Reserve(const ARequest: TReservationRequest): TReservation;
    function FindById(const AId: Integer): TReservation;
    function Cancel(const AId: Integer): TReservation;
    function FindTicket(const ACode: string): TTicket;
    function CheckIn(const ACode: string): TTicket;
  end;

  TBatchService = class(TInterfacedObject, IBatchService)
  private
    FBatches: IBatchRepository;
  public
    constructor Create(const ABatches: IBatchRepository);
    function FindById(const AId: Integer): TBatchInventory;
    function Save(const AId: Integer; const ARequest: TBatchRequest): TBatchInventory;
  end;

  TReservationService = class(TInterfacedObject, IReservationService)
  private
    FTransaction: ITransactionScope;
    FBatches: IBatchRepository;
    FReservations: IReservationRepository;
    procedure RaiseStockError(const ABatchId, AQuantity: Integer; const ANow: TDateTime);
  public
    constructor Create(const ATransaction: ITransactionScope;
      const ABatches: IBatchRepository; const AReservations: IReservationRepository);
    function Reserve(const ARequest: TReservationRequest): TReservation;
    function FindById(const AId: Integer): TReservation;
    function Cancel(const AId: Integer): TReservation;
    function FindTicket(const ACode: string): TTicket;
    function CheckIn(const ACode: string): TTicket;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Platform.Exceptions,
  Platform.Dates,
  TicketApi.TicketCode;

{ TBatchService }

constructor TBatchService.Create(const ABatches: IBatchRepository);
begin
  inherited Create;
  FBatches := ABatches;
end;

function TBatchService.FindById(const AId: Integer): TBatchInventory;
begin
  Result := FBatches.FindById(AId);
  if not Assigned(Result) then
    raise ENotFoundException.Create('Lote não encontrado.');
end;

function TBatchService.Save(const AId: Integer; const ARequest: TBatchRequest): TBatchInventory;
var
  LSalesStart, LSalesEnd: TDateTime;
begin
  if ARequest.EventId <= 0 then
    raise EValidationException.Create('Informe o evento do lote.');
  if ARequest.Price < 0 then
    raise EValidationException.Create('Informe o preço do lote (zero para ingressos gratuitos).');
  if ARequest.Quantity <= 0 then
    raise EValidationException.Create('A quantidade de ingressos do lote deve ser maior que zero.');
  if not TryParseISODateTime(ARequest.SalesStart, LSalesStart) then
    raise EValidationException.Create('Informe o início das vendas no formato aaaa-mm-ddThh:mm:ss.');
  if not TryParseISODateTime(ARequest.SalesEnd, LSalesEnd) then
    raise EValidationException.Create('Informe o fim das vendas no formato aaaa-mm-ddThh:mm:ss.');
  if LSalesStart >= LSalesEnd then
    raise EBusinessRuleException.Create('O fim das vendas deve ser depois do início.');

  Result := TBatchInventory.Create;
  try
    Result.Id := AId;
    Result.EventId := ARequest.EventId;
    Result.Price := SimpleRoundTo(ARequest.Price, -2);
    Result.Quantity := ARequest.Quantity;
    Result.SalesStart := LSalesStart;
    Result.SalesEnd := LSalesEnd;
    if not FBatches.Save(Result, Now) then
      raise EConflictException.Create('A quantidade não pode ser menor do que os ingressos já vendidos.');
  except
    Result.Free;
    raise;
  end;
end;

{ TReservationService }

constructor TReservationService.Create(const ATransaction: ITransactionScope;
  const ABatches: IBatchRepository; const AReservations: IReservationRepository);
begin
  inherited Create;
  FTransaction := ATransaction;
  FBatches := ABatches;
  FReservations := AReservations;
end;

procedure TReservationService.RaiseStockError(const ABatchId, AQuantity: Integer; const ANow: TDateTime);
var
  LBatch: TBatchInventory;
begin
  // A baixa de estoque falhou. Descobrimos o motivo para dar uma resposta útil.
  LBatch := FBatches.FindById(ABatchId);
  try
    if not Assigned(LBatch) then
      raise ENotFoundException.Create('Lote não encontrado.');
    if not LBatch.IsOnSale(ANow) then
      raise EBusinessRuleException.Create('As vendas deste lote não estão abertas.');
    if LBatch.Available = 0 then
      raise EConflictException.Create('Ingressos esgotados para este lote.');
    raise EConflictException.CreateFmt(
      'Não há ingressos suficientes: restam %d neste lote.', [LBatch.Available]);
  finally
    LBatch.Free;
  end;
end;

function TReservationService.Reserve(const ARequest: TReservationRequest): TReservation;
var
  LReservation: TReservation;
  LNow: TDateTime;
  LBatchId, LQuantity: Integer;
begin
  if ARequest.CustomerId <= 0 then
    raise EValidationException.Create('Informe o participante da reserva.');
  if ARequest.BatchId <= 0 then
    raise EValidationException.Create('Informe o lote de ingressos.');
  if (ARequest.Quantity < 1) or (ARequest.Quantity > MAX_TICKETS_PER_RESERVATION) then
    raise EValidationException.CreateFmt(
      'A quantidade de ingressos deve ser de 1 a %d por reserva.', [MAX_TICKETS_PER_RESERVATION]);

  LNow := Now;
  LBatchId := ARequest.BatchId;
  LQuantity := ARequest.Quantity;
  LReservation := TReservation.Create;
  try
    LReservation.CustomerId := ARequest.CustomerId;
    LReservation.BatchId := ARequest.BatchId;
    LReservation.Quantity := ARequest.Quantity;
    LReservation.Status := rsActive;
    LReservation.CreatedAt := LNow;

    // Baixa de estoque, reserva e ingressos: tudo ou nada.
    FTransaction.InTransaction(
      procedure
      var
        LUnitPrice: Currency;
        LEventId: Integer;
        LTicket: TTicket;
        I: Integer;
      begin
        if not FBatches.TryTakeStock(LBatchId, LQuantity, LNow, LUnitPrice, LEventId) then
          RaiseStockError(LBatchId, LQuantity, LNow);

        LReservation.UnitPrice := LUnitPrice;
        LReservation.EventId := LEventId;
        for I := 1 to LQuantity do
        begin
          LTicket := TTicket.Create;
          LReservation.Tickets.Add(LTicket);
          LTicket.Code := TTicketCode.New;
          LTicket.Status := tsValid;
          LTicket.EventId := LEventId;
        end;
        FReservations.Insert(LReservation);
      end);

    Result := LReservation;
  except
    LReservation.Free;
    raise;
  end;
end;

function TReservationService.FindById(const AId: Integer): TReservation;
begin
  Result := FReservations.FindById(AId);
  if not Assigned(Result) then
    raise ENotFoundException.Create('Reserva não encontrada.');
end;

function TReservationService.Cancel(const AId: Integer): TReservation;
var
  LNow: TDateTime;
  LId: Integer;
begin
  LNow := Now;
  LId := AId;
  FTransaction.InTransaction(
    procedure
    var
      LReservation: TReservation;
      LTicket: TTicket;
    begin
      // Trava a reserva: dois cancelamentos simultâneos não devolvem o estoque duas vezes.
      LReservation := FReservations.FindById(LId, True);
      if not Assigned(LReservation) then
        raise ENotFoundException.Create('Reserva não encontrada.');
      try
        if LReservation.Status = rsCancelled then
          raise EConflictException.Create('Esta reserva já foi cancelada.');
        for LTicket in LReservation.Tickets do
          if LTicket.Status = tsUsed then
            raise EConflictException.Create(
              'Não é possível cancelar: há ingressos desta reserva que já foram usados.');

        FReservations.MarkCancelled(LId, LNow);
        FBatches.ReleaseStock(LReservation.BatchId, LReservation.Quantity, LNow);
      finally
        LReservation.Free;
      end;
    end);

  Result := FindById(AId);
end;

function TReservationService.FindTicket(const ACode: string): TTicket;
begin
  Result := FReservations.FindTicket(ACode.Trim.ToUpper);
  if not Assigned(Result) then
    raise ENotFoundException.Create('Ingresso não encontrado.');
end;

function TReservationService.CheckIn(const ACode: string): TTicket;
var
  LCode: string;
begin
  LCode := ACode.Trim.ToUpper;
  if not FReservations.TryCheckIn(LCode, Now) then
  begin
    // Não entrou: descobrimos por quê.
    Result := FindTicket(LCode);
    try
      case Result.Status of
        tsUsed:
          raise EConflictException.Create('Ingresso já utilizado em ' +
            FormatDateTime('dd/mm/yyyy "às" hh:nn', Result.CheckedInAt) + '.');
        tsCancelled:
          raise EConflictException.Create('Ingresso cancelado.');
      end;
    finally
      Result.Free;
    end;
  end;
  Result := FindTicket(LCode);
end;

end.
