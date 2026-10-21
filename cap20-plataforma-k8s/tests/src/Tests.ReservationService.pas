unit Tests.ReservationService;

{ Testes do TReservationService com dublês: sem banco, sem rede, em
  milissegundos. Cada teste monta exatamente o cenário de que precisa. }

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Platform.Transactions,
  TicketApi.Repository,
  TicketApi.Partners,
  TicketApi.Service,
  TicketApi.DTO,
  Tests.Fakes;

type
  [TestFixture]
  TReservationServiceTests = class
  private
    // Guardamos a interface (que mantém o objeto vivo) e o objeto (para inspecionar).
    FTransactionRef: ITransactionScope;
    FBatchesRef: IBatchRepository;
    FReservationsRef: IReservationRepository;
    FCatalogRef: IEventCatalog;
    FCustomersRef: ICustomerDirectory;
    FTransaction: TFakeTransaction;
    FBatches: TFakeBatchRepository;
    FReservations: TFakeReservationRepository;
    FCatalog: TFakeEventCatalog;
    FCustomers: TFakeCustomerDirectory;
    function Service: IReservationService;
    function Request(const ACustomerId, ABatchId, AQuantity: Integer): TReservationRequest;
    // Confere que a reserva falha com a exceção esperada (e a mensagem, se informada).
    procedure ExpectFailure(const ARequest: TReservationRequest; const AClass: ExceptClass;
      const AMessage: string = '');
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ReservesAndIssuesOneTicketPerSeat;
    [Test]
    procedure UsesThePriceFromTheEventApi;
    [Test]
    procedure InvalidQuantityDoesNotCallOtherServices;
    [Test]
    procedure UnknownCustomerIsAFieldError;
    [Test]
    procedure UnpublishedEventIsNotOnSale;
    [Test]
    procedure SoldOutBatch;
    [Test]
    procedure NotEnoughTickets;
    [Test]
    procedure EventApiDownWithoutLocalCopyIsUnavailable;
    [Test]
    procedure EventApiDownWithLocalCopyKeepsSelling;
    [Test]
    procedure CustomerApiDownIsUnavailable;
  end;

implementation

uses
  System.Generics.Collections,
  Platform.Exceptions,
  TicketApi.Entity.Reservation,
  TicketApi.Exceptions;

procedure TReservationServiceTests.Setup;
begin
  FTransaction := TFakeTransaction.Create;
  FTransactionRef := FTransaction;
  FBatches := TFakeBatchRepository.Create;
  FBatchesRef := FBatches;
  FReservations := TFakeReservationRepository.Create;
  FReservationsRef := FReservations;
  FCatalog := TFakeEventCatalog.Create;
  FCatalogRef := FCatalog;
  FCustomers := TFakeCustomerDirectory.Create([1, 2]);
  FCustomersRef := FCustomers;
end;

procedure TReservationServiceTests.TearDown;
begin
  // Soltar as interfaces libera os dublês.
  FTransactionRef := nil;
  FBatchesRef := nil;
  FReservationsRef := nil;
  FCatalogRef := nil;
  FCustomersRef := nil;
end;

function TReservationServiceTests.Service: IReservationService;
begin
  Result := TReservationService.Create(FTransactionRef, FBatchesRef, FReservationsRef,
    FCatalogRef, FCustomersRef);
end;

function TReservationServiceTests.Request(const ACustomerId, ABatchId, AQuantity: Integer): TReservationRequest;
begin
  Result.CustomerId := ACustomerId;
  Result.BatchId := ABatchId;
  Result.Quantity := AQuantity;
end;

procedure TReservationServiceTests.ExpectFailure(const ARequest: TReservationRequest;
  const AClass: ExceptClass; const AMessage: string);
var
  LClassName, LMessage: string;
begin
  LClassName := '';
  try
    Service.Reserve(ARequest).Free;
  except
    on E: Exception do
    begin
      LClassName := E.ClassName;
      LMessage := E.Message;
    end;
  end;
  Assert.AreEqual(AClass.ClassName, LClassName, 'Exceção diferente da esperada');
  if AMessage <> '' then
    Assert.AreEqual(AMessage, LMessage);
end;

procedure TReservationServiceTests.ReservesAndIssuesOneTicketPerSeat;
var
  LReservation: TReservation;
  LCodes: THashSet<string>;
  LTicket: TTicket;
begin
  FCatalog.Add(10, 100, 150, True);
  LReservation := Service.Reserve(Request(1, 10, 3));
  LCodes := THashSet<string>.Create;
  try
    Assert.AreEqual(3, Integer(LReservation.Tickets.Count));
    for LTicket in LReservation.Tickets do
      Assert.IsTrue(LCodes.Add(LTicket.Code), 'Dois ingressos com o mesmo código');
    Assert.AreEqual(3, FBatches.Sold(10));
    Assert.AreEqual(1, FReservations.Inserted);
    Assert.AreEqual(1, FTransaction.Count, 'A gravação deve acontecer em uma transação');
  finally
    LCodes.Free;
    LReservation.Free;
  end;
end;

procedure TReservationServiceTests.UsesThePriceFromTheEventApi;
var
  LReservation: TReservation;
begin
  // A cópia local tem um preço antigo; a event-api tem o atual.
  FBatches.Add(10, 100, 0, 150);
  FCatalog.Add(10, 100, 180, True);
  LReservation := Service.Reserve(Request(1, 10, 2));
  try
    Assert.AreEqual<Currency>(180, LReservation.UnitPrice);
    Assert.AreEqual<Currency>(360, LReservation.Total);
  finally
    LReservation.Free;
  end;
end;

procedure TReservationServiceTests.InvalidQuantityDoesNotCallOtherServices;
begin
  ExpectFailure(Request(1, 10, 7), EValidationException);
  // Dado inválido é recusado antes de qualquer chamada pela rede.
  Assert.AreEqual(0, FCustomers.Calls);
  Assert.AreEqual(0, FCatalog.Calls);
end;

procedure TReservationServiceTests.UnknownCustomerIsAFieldError;
begin
  FCatalog.Add(10, 100, 150, True);
  try
    Service.Reserve(Request(99, 10, 1)).Free;
    Assert.Fail('Deveria ter recusado o participante');
  except
    on E: EValidationException do
    begin
      Assert.AreEqual(1, Integer(Length(E.Errors)));
      Assert.AreEqual('customerId', E.Errors[0].Field);
    end;
  end;
  Assert.AreEqual(0, FReservations.Inserted);
end;

procedure TReservationServiceTests.UnpublishedEventIsNotOnSale;
begin
  FCatalog.Add(10, 100, 150, False);
  ExpectFailure(Request(1, 10, 1), EEventNotOnSaleException);
end;

procedure TReservationServiceTests.SoldOutBatch;
begin
  FBatches.Add(10, 2, 2, 150);
  FCatalog.Add(10, 2, 150, True);
  ExpectFailure(Request(1, 10, 1), ESoldOutException);
end;

procedure TReservationServiceTests.NotEnoughTickets;
begin
  FBatches.Add(10, 5, 3, 150);
  FCatalog.Add(10, 5, 150, True);
  ExpectFailure(Request(1, 10, 3), EInsufficientStockException, 'Não há ingressos suficientes: restam 2 neste lote.');
end;

procedure TReservationServiceTests.EventApiDownWithoutLocalCopyIsUnavailable;
begin
  FCatalog.Online := False;
  ExpectFailure(Request(1, 10, 1), EServiceUnavailableException);
end;

procedure TReservationServiceTests.EventApiDownWithLocalCopyKeepsSelling;
var
  LReservation: TReservation;
begin
  FBatches.Add(10, 100, 0, 150);
  FCatalog.Online := False;
  LReservation := Service.Reserve(Request(1, 10, 2));
  try
    // Modo degradado: vendeu com o preço da cópia local.
    Assert.AreEqual<Currency>(150, LReservation.UnitPrice);
    Assert.AreEqual(2, FBatches.Sold(10));
  finally
    LReservation.Free;
  end;
end;

procedure TReservationServiceTests.CustomerApiDownIsUnavailable;
begin
  FCatalog.Add(10, 100, 150, True);
  FCustomers.Online := False;
  ExpectFailure(Request(1, 10, 1), EServiceUnavailableException);
  Assert.AreEqual(0, FReservations.Inserted);
end;

initialization
  TDUnitX.RegisterTestFixture(TReservationServiceTests);

end.
