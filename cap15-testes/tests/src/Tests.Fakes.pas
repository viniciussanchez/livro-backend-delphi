unit Tests.Fakes;

{ Dublês de teste: implementações em memória das interfaces que o
  TReservationService recebe no construtor. Graças à injeção de dependência
  do capítulo 4, o serviço não percebe a diferença. }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Platform.Transactions,
  TicketApi.Entity.Batch,
  TicketApi.Entity.Reservation,
  TicketApi.Repository,
  TicketApi.Partners;

type
  // Executa o bloco direto, sem banco.
  TFakeTransaction = class(TInterfacedObject, ITransactionScope)
  public
    Count: Integer;
    procedure InTransaction(const AProc: TProc);
  end;

  TFakeBatchRepository = class(TInterfacedObject, IBatchRepository)
  private
    FBatches: TObjectDictionary<Integer, TBatchInventory>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AId, AQuantity, ASold: Integer; const APrice: Currency);
    function Sold(const AId: Integer): Integer;
    function Exists(const AId: Integer): Boolean;
    function FindById(const AId: Integer): TBatchInventory;
    function Save(const ABatch: TBatchInventory; const ANow: TDateTime): Boolean;
    function TryTakeStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime;
      out AUnitPrice: Currency; out AEventId: Integer): Boolean;
    procedure ReleaseStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime);
  end;

  TFakeReservationRepository = class(TInterfacedObject, IReservationRepository)
  public
    Inserted: Integer;
    function FindById(const AId: Integer; const ALock: Boolean = False): TReservation;
    procedure Insert(const AReservation: TReservation);
    procedure MarkCancelled(const AId: Integer; const ANow: TDateTime);
    function FindTicket(const ACode: string): TTicket;
    function TryCheckIn(const ACode: string; const ANow: TDateTime): Boolean;
  end;

  TFakeEventCatalog = class(TInterfacedObject, IEventCatalog)
  private
    FBatches: TDictionary<Integer, TCatalogBatch>;
  public
    Online: Boolean;
    Calls: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Add(const ABatchId, AQuantity: Integer; const APrice: Currency; const APublished: Boolean);
    function FindBatch(const ABatchId: Integer; out ABatch: TCatalogBatch): Boolean;
    function FindEventName(const AEventId: Integer; out AName: string): Boolean;
  end;

  TFakeCustomerDirectory = class(TInterfacedObject, ICustomerDirectory)
  private
    FIds: TList<Integer>;
  public
    Online: Boolean;
    Calls: Integer;
    constructor Create(const AIds: array of Integer);
    destructor Destroy; override;
    function Exists(const ACustomerId: Integer): Boolean;
  end;

implementation

uses
  Platform.Exceptions;

{ TFakeTransaction }

procedure TFakeTransaction.InTransaction(const AProc: TProc);
begin
  Inc(Count);
  AProc();
end;

{ TFakeBatchRepository }

constructor TFakeBatchRepository.Create;
begin
  inherited Create;
  FBatches := TObjectDictionary<Integer, TBatchInventory>.Create([doOwnsValues]);
end;

destructor TFakeBatchRepository.Destroy;
begin
  FBatches.Free;
  inherited;
end;

procedure TFakeBatchRepository.Add(const AId, AQuantity, ASold: Integer; const APrice: Currency);
var
  LBatch: TBatchInventory;
begin
  LBatch := TBatchInventory.Create;
  LBatch.Id := AId;
  LBatch.EventId := 1;
  LBatch.Price := APrice;
  LBatch.Quantity := AQuantity;
  LBatch.Sold := ASold;
  LBatch.SalesStart := Now - 1;
  LBatch.SalesEnd := Now + 1;
  FBatches.AddOrSetValue(AId, LBatch);
end;

function TFakeBatchRepository.Sold(const AId: Integer): Integer;
begin
  Result := FBatches[AId].Sold;
end;

function TFakeBatchRepository.Exists(const AId: Integer): Boolean;
begin
  Result := FBatches.ContainsKey(AId);
end;

function TFakeBatchRepository.FindById(const AId: Integer): TBatchInventory;
var
  LBatch: TBatchInventory;
begin
  Result := nil;
  if not FBatches.TryGetValue(AId, LBatch) then
    Exit;
  // Devolve uma cópia: quem chama libera, como no repositório de verdade.
  Result := TBatchInventory.Create;
  Result.Id := LBatch.Id;
  Result.EventId := LBatch.EventId;
  Result.Price := LBatch.Price;
  Result.Quantity := LBatch.Quantity;
  Result.Sold := LBatch.Sold;
  Result.SalesStart := LBatch.SalesStart;
  Result.SalesEnd := LBatch.SalesEnd;
end;

function TFakeBatchRepository.Save(const ABatch: TBatchInventory; const ANow: TDateTime): Boolean;
var
  LSold: Integer;
begin
  LSold := 0;
  if FBatches.ContainsKey(ABatch.Id) then
    LSold := FBatches[ABatch.Id].Sold;
  Result := ABatch.Quantity >= LSold;
  if Result then
  begin
    Add(ABatch.Id, ABatch.Quantity, LSold, ABatch.Price);
    FBatches[ABatch.Id].EventId := ABatch.EventId;
    FBatches[ABatch.Id].SalesStart := ABatch.SalesStart;
    FBatches[ABatch.Id].SalesEnd := ABatch.SalesEnd;
  end;
end;

function TFakeBatchRepository.TryTakeStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime;
  out AUnitPrice: Currency; out AEventId: Integer): Boolean;
var
  LBatch: TBatchInventory;
begin
  AUnitPrice := 0;
  AEventId := 0;
  // A mesma regra do update condicional do capítulo 8.
  Result := FBatches.TryGetValue(ABatchId, LBatch) and LBatch.IsOnSale(ANow) and
    (LBatch.Available >= AQuantity);
  if Result then
  begin
    LBatch.Sold := LBatch.Sold + AQuantity;
    AUnitPrice := LBatch.Price;
    AEventId := LBatch.EventId;
  end;
end;

procedure TFakeBatchRepository.ReleaseStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime);
begin
  FBatches[ABatchId].Sold := FBatches[ABatchId].Sold - AQuantity;
end;

{ TFakeReservationRepository }

function TFakeReservationRepository.FindById(const AId: Integer; const ALock: Boolean): TReservation;
begin
  Result := nil;
end;

procedure TFakeReservationRepository.Insert(const AReservation: TReservation);
begin
  Inc(Inserted);
  AReservation.Id := Inserted;
end;

procedure TFakeReservationRepository.MarkCancelled(const AId: Integer; const ANow: TDateTime);
begin
end;

function TFakeReservationRepository.FindTicket(const ACode: string): TTicket;
begin
  Result := nil;
end;

function TFakeReservationRepository.TryCheckIn(const ACode: string; const ANow: TDateTime): Boolean;
begin
  Result := False;
end;

{ TFakeEventCatalog }

constructor TFakeEventCatalog.Create;
begin
  inherited Create;
  FBatches := TDictionary<Integer, TCatalogBatch>.Create;
  Online := True;
end;

destructor TFakeEventCatalog.Destroy;
begin
  FBatches.Free;
  inherited;
end;

procedure TFakeEventCatalog.Add(const ABatchId, AQuantity: Integer; const APrice: Currency;
  const APublished: Boolean);
var
  LBatch: TCatalogBatch;
begin
  LBatch := Default(TCatalogBatch);
  LBatch.Id := ABatchId;
  LBatch.EventId := 1;
  LBatch.EventName := 'Evento de teste';
  LBatch.EventPublished := APublished;
  LBatch.Price := APrice;
  LBatch.Quantity := AQuantity;
  LBatch.SalesStart := Now - 1;
  LBatch.SalesEnd := Now + 1;
  FBatches.AddOrSetValue(ABatchId, LBatch);
end;

function TFakeEventCatalog.FindBatch(const ABatchId: Integer; out ABatch: TCatalogBatch): Boolean;
begin
  Inc(Calls);
  if not Online then
    raise EServiceUnavailableException.Create('event-api fora do ar (dublê)');
  Result := FBatches.TryGetValue(ABatchId, ABatch);
end;

function TFakeEventCatalog.FindEventName(const AEventId: Integer; out AName: string): Boolean;
begin
  Inc(Calls);
  if not Online then
    raise EServiceUnavailableException.Create('event-api fora do ar (dublê)');
  AName := 'Evento de teste';
  Result := True;
end;

{ TFakeCustomerDirectory }

constructor TFakeCustomerDirectory.Create(const AIds: array of Integer);
var
  LId: Integer;
begin
  inherited Create;
  FIds := TList<Integer>.Create;
  for LId in AIds do
    FIds.Add(LId);
  Online := True;
end;

destructor TFakeCustomerDirectory.Destroy;
begin
  FIds.Free;
  inherited;
end;

function TFakeCustomerDirectory.Exists(const ACustomerId: Integer): Boolean;
begin
  Inc(Calls);
  if not Online then
    raise EServiceUnavailableException.Create('customer-api fora do ar (dublê)');
  Result := FIds.Contains(ACustomerId);
end;

end.
