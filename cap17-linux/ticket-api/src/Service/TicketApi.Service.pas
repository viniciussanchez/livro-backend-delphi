unit TicketApi.Service;

{ Regras de negócio da venda de ingressos. }

interface

uses
  Platform.Transactions,
  TicketApi.Partners,
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
    FCatalog: IEventCatalog;
    FCustomers: ICustomerDirectory;
    procedure RaiseStockError(const ABatchId, AQuantity: Integer; const ANow: TDateTime);
    // Atualiza o estoque local com os dados da event-api (capítulo 12).
    procedure SyncBatch(const ABatchId: Integer; const ANow: TDateTime);
  public
    constructor Create(const ATransaction: ITransactionScope;
      const ABatches: IBatchRepository; const AReservations: IReservationRepository;
      const ACatalog: IEventCatalog; const ACustomers: ICustomerDirectory);
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
  Platform.Validation,
  Platform.Dates,
  TicketApi.Exceptions,
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
  LValidation: TValidation;
begin
  LValidation.Check(ARequest.EventId > 0, 'eventId', 'Informe o evento do lote.');
  LValidation.Check(ARequest.Price >= 0, 'price', 'Informe o preço do lote (zero para ingressos gratuitos).');
  LValidation.Check(ARequest.Quantity > 0, 'quantity', 'A quantidade de ingressos do lote deve ser maior que zero.');
  LValidation.Check(TryParseISODateTime(ARequest.SalesStart, LSalesStart),
    'salesStart', 'Informe o início das vendas no formato aaaa-mm-ddThh:mm:ss.');
  LValidation.Check(TryParseISODateTime(ARequest.SalesEnd, LSalesEnd),
    'salesEnd', 'Informe o fim das vendas no formato aaaa-mm-ddThh:mm:ss.');
  LValidation.RaiseIfInvalid;

  // Só comparamos as datas depois de saber que as duas são válidas.
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
  const ABatches: IBatchRepository; const AReservations: IReservationRepository;
  const ACatalog: IEventCatalog; const ACustomers: ICustomerDirectory);
begin
  inherited Create;
  FTransaction := ATransaction;
  FBatches := ABatches;
  FReservations := AReservations;
  FCatalog := ACatalog;
  FCustomers := ACustomers;
end;

procedure TReservationService.SyncBatch(const ABatchId: Integer; const ANow: TDateTime);
var
  LCatalog: TCatalogBatch;
  LLocal, LBatch: TBatchInventory;
begin
  try
    if not FCatalog.FindBatch(ABatchId, LCatalog) then
      raise ENotFoundException.Create('Lote não encontrado.');
  except
    on E: EServiceUnavailableException do
    begin
      // Modo degradado: a event-api está fora, mas já conhecemos o lote.
      // Vendemos com a cópia local; sem ela, não há como vender.
      LLocal := FBatches.FindById(ABatchId);
      if not Assigned(LLocal) then
        raise;
      LLocal.Free;
      Writeln(Format('Lote %d: event-api indisponível, usando a cópia local.', [ABatchId]));
      Exit;
    end;
  end;

  if not LCatalog.EventPublished then
    raise EEventNotOnSaleException.Create('O evento deste lote não está à venda.');

  LBatch := TBatchInventory.Create;
  try
    LBatch.Id := LCatalog.Id;
    LBatch.EventId := LCatalog.EventId;
    LBatch.Price := LCatalog.Price;
    LBatch.Quantity := LCatalog.Quantity;
    LBatch.SalesStart := LCatalog.SalesStart;
    LBatch.SalesEnd := LCatalog.SalesEnd;
    // Se a event-api reduziu o lote para menos do que já vendemos, o Save
    // recusa a nova quantidade e o estoque atual continua valendo.
    FBatches.Save(LBatch, ANow);
  finally
    LBatch.Free;
  end;
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
      raise ESalesClosedException.Create('As vendas deste lote não estão abertas.');
    if LBatch.Available = 0 then
      raise ESoldOutException.Create('Ingressos esgotados para este lote.');
    raise EInsufficientStockException.CreateFmt(
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
  LValidation: TValidation;
begin
  LValidation.Check(ARequest.CustomerId > 0, 'customerId', 'Informe o participante da reserva.');
  LValidation.Check(ARequest.BatchId > 0, 'batchId', 'Informe o lote de ingressos.');
  LValidation.Check((ARequest.Quantity >= 1) and (ARequest.Quantity <= MAX_TICKETS_PER_RESERVATION),
    'quantity', Format('A quantidade de ingressos deve ser de 1 a %d por reserva.', [MAX_TICKETS_PER_RESERVATION]));
  LValidation.RaiseIfInvalid;

  // As consultas aos outros serviços ficam FORA da transação: não faz sentido
  // segurar uma conexão do banco enquanto esperamos a rede.
  if not FCustomers.Exists(ARequest.CustomerId) then
    raise EValidationException.CreateForField('customerId', 'Participante não encontrado.');

  LNow := Now;
  SyncBatch(ARequest.BatchId, LNow);

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
          raise ETicketAlreadyUsedException.Create('Ingresso já utilizado em ' +
            FormatDateTime('dd/mm/yyyy "às" hh:nn', Result.CheckedInAt) + '.');
        tsCancelled:
          raise ETicketCancelledException.Create('Ingresso cancelado.');
      end;
    finally
      Result.Free;
    end;
  end;
  Result := FindTicket(LCode);
end;

end.
