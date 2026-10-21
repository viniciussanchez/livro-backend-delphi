unit Tests.Domain;

{ Testes de unidade das regras que não dependem de banco nem de rede. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCpfTests = class
  public
    [Test]
    [TestCase('com pontuação', '529.982.247-25,52998224725')]
    [TestCase('com espaços', ' 111 444 777 35 ,11144477735')]
    procedure OnlyDigitsRemovesEverythingElse(const AInput, AExpected: string);

    [Test]
    [TestCase('válido 1', '52998224725,True')]
    [TestCase('válido 2', '11144477735,True')]
    [TestCase('dígito errado', '52998224724,False')]
    [TestCase('todos iguais', '11111111111,False')]
    [TestCase('curto', '1234567890,False')]
    procedure IsValidChecksDigits(const ACpf: string; const AExpected: Boolean);

    [Test]
    procedure MaskHidesTheEnds;
  end;

  [TestFixture]
  TTicketCodeTests = class
  public
    [Test]
    procedure HasTenUnambiguousCharacters;
    [Test]
    procedure TenThousandCodesAreAllDifferent;
  end;

  [TestFixture]
  TBatchInventoryTests = class
  public
    [Test]
    procedure AvailableIsQuantityMinusSold;
    [Test]
    procedure SalesWindowIncludesStartAndExcludesEnd;
  end;

  [TestFixture]
  TReportTests = class
  public
    [Test]
    procedure RatesUseOneDecimalPlace;
    [Test]
    procedure RatesAreZeroWithoutBase;
    [Test]
    procedure SalesTotalsSumAllBatches;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  CustomerApi.Cpf,
  TicketApi.TicketCode,
  TicketApi.Entity.Batch,
  TicketApi.Entity.Report;

{ TCpfTests }

procedure TCpfTests.OnlyDigitsRemovesEverythingElse(const AInput, AExpected: string);
begin
  Assert.AreEqual(AExpected, TCpf.OnlyDigits(AInput));
end;

procedure TCpfTests.IsValidChecksDigits(const ACpf: string; const AExpected: Boolean);
begin
  Assert.AreEqual(AExpected, TCpf.IsValid(ACpf));
end;

procedure TCpfTests.MaskHidesTheEnds;
begin
  Assert.AreEqual('***.982.247-**', TCpf.Mask('52998224725'));
end;

{ TTicketCodeTests }

procedure TTicketCodeTests.HasTenUnambiguousCharacters;
var
  LCode: string;
  LChar: Char;
begin
  LCode := TTicketCode.New;
  Assert.AreEqual(10, LCode.Length);
  for LChar in LCode do
    Assert.IsFalse(CharInSet(LChar, ['0', 'O', '1', 'I', 'L']),
      Format('O código %s tem o caractere ambíguo %s', [LCode, LChar]));
end;

procedure TTicketCodeTests.TenThousandCodesAreAllDifferent;
var
  LCodes: THashSet<string>;
  I: Integer;
begin
  LCodes := THashSet<string>.Create;
  try
    for I := 1 to 10000 do
      Assert.IsTrue(LCodes.Add(TTicketCode.New), 'Código repetido na tentativa ' + I.ToString);
  finally
    LCodes.Free;
  end;
end;

{ TBatchInventoryTests }

procedure TBatchInventoryTests.AvailableIsQuantityMinusSold;
var
  LBatch: TBatchInventory;
begin
  LBatch := TBatchInventory.Create;
  try
    LBatch.Quantity := 100;
    LBatch.Sold := 37;
    Assert.AreEqual(63, LBatch.Available);
  finally
    LBatch.Free;
  end;
end;

procedure TBatchInventoryTests.SalesWindowIncludesStartAndExcludesEnd;
var
  LBatch: TBatchInventory;
begin
  LBatch := TBatchInventory.Create;
  try
    LBatch.SalesStart := EncodeDateTime(2026, 11, 1, 0, 0, 0, 0);
    LBatch.SalesEnd := EncodeDateTime(2026, 11, 30, 0, 0, 0, 0);
    Assert.IsFalse(LBatch.IsOnSale(IncSecond(LBatch.SalesStart, -1)), 'um segundo antes do início');
    Assert.IsTrue(LBatch.IsOnSale(LBatch.SalesStart), 'no exato início');
    Assert.IsTrue(LBatch.IsOnSale(IncSecond(LBatch.SalesEnd, -1)), 'um segundo antes do fim');
    Assert.IsFalse(LBatch.IsOnSale(LBatch.SalesEnd), 'no exato fim');
  finally
    LBatch.Free;
  end;
end;

{ TReportTests }

procedure TReportTests.RatesUseOneDecimalPlace;
var
  LAttendance: TEventAttendance;
begin
  LAttendance := Default(TEventAttendance);
  LAttendance.Capacity := 150;
  LAttendance.TicketsIssued := 7;
  LAttendance.CheckedIn := 3;
  Assert.AreEqual(4.7, LAttendance.OccupancyRate, 0.0001);
  Assert.AreEqual(42.9, LAttendance.AttendanceRate, 0.0001);
end;

procedure TReportTests.RatesAreZeroWithoutBase;
var
  LAttendance: TEventAttendance;
begin
  // Evento sem lotes e sem vendas: nada de divisão por zero.
  LAttendance := Default(TEventAttendance);
  Assert.AreEqual(0.0, LAttendance.OccupancyRate, 0.0001);
  Assert.AreEqual(0.0, LAttendance.AttendanceRate, 0.0001);
end;

procedure TReportTests.SalesTotalsSumAllBatches;
var
  LSales: TEventSales;
begin
  LSales := Default(TEventSales);
  SetLength(LSales.Batches, 2);
  LSales.Batches[0].Quantity := 100;
  LSales.Batches[0].Sold := 2;
  LSales.Batches[0].Revenue := 300;
  LSales.Batches[1].Quantity := 50;
  LSales.Batches[1].Sold := 5;
  LSales.Batches[1].Revenue := 1100;
  Assert.AreEqual(150, LSales.TotalQuantity);
  Assert.AreEqual(7, LSales.TotalSold);
  Assert.AreEqual<Currency>(1400, LSales.TotalRevenue);
end;

initialization
  TDUnitX.RegisterTestFixture(TCpfTests);
  TDUnitX.RegisterTestFixture(TTicketCodeTests);
  TDUnitX.RegisterTestFixture(TBatchInventoryTests);
  TDUnitX.RegisterTestFixture(TReportTests);

end.
