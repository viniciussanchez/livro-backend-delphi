unit Tests.LegacySync;

{ Capítulo 22: a tradução do sistema antigo para a plataforma nova.
  Não precisa de banco nem de rede: é só a camada anticorrupção. }

interface

uses
  DUnitX.TestFramework,
  LegacySync.Translator;

type
  [TestFixture]
  TLegacyTranslatorTests = class
  private
    function Customer: TLegacyCustomer;
  public
    [Test]
    [TestCase('maiúsculas', 'ANA SILVA,Ana Silva')]
    [TestCase('preposições', 'MARIA  DA  SILVA DOS SANTOS,Maria da Silva dos Santos')]
    [TestCase('espaços nas pontas', '  joão souza ,João Souza')]
    procedure NormalizesNames(const AInput, AExpected: string);

    [Test]
    // "-" no resultado esperado quer dizer "não é uma data válida".
    [TestCase('válida', '25/12/1980,1980-12-25')]
    [TestCase('dia e mês com um dígito', '5/3/1990,1990-03-05')]
    [TestCase('31 de fevereiro', '31/02/1985,-')]
    [TestCase('formato errado', '1980-12-25,-')]
    procedure ConvertsDates(const AInput, AExpected: string);

    [Test]
    procedure TranslatesTheWholeRecord;
    [Test]
    procedure DiscardsPhoneWithoutAreaCode;
    [Test]
    procedure DiscardsImpossibleBirthDate;
    [Test]
    procedure LeavesEmptyFieldsOut;
    [Test]
    procedure IgnoresInactiveCustomers;
  end;

implementation

uses
  System.JSON;

function TLegacyTranslatorTests.Customer: TLegacyCustomer;
begin
  Result.Code := 42;
  Result.Name := 'MARIA DA SILVA';
  Result.Cpf := '529.982.247-25';
  Result.Phone := '(31) 99999-8888';
  Result.Email := ' Maria@Exemplo.com ';
  Result.BirthDate := '25/12/1980';
  Result.Status := 'A';
end;

procedure TLegacyTranslatorTests.NormalizesNames(const AInput, AExpected: string);
begin
  Assert.AreEqual(AExpected, TLegacyCustomerTranslator.NormalizeName(AInput));
end;

procedure TLegacyTranslatorTests.ConvertsDates(const AInput, AExpected: string);
var
  LIso: string;
begin
  if AExpected = '-' then
    Assert.IsFalse(TLegacyCustomerTranslator.ConvertDate(AInput, LIso))
  else
  begin
    Assert.IsTrue(TLegacyCustomerTranslator.ConvertDate(AInput, LIso));
    Assert.AreEqual(AExpected, LIso);
  end;
end;

procedure TLegacyTranslatorTests.TranslatesTheWholeRecord;
var
  LResult: TTranslation;
begin
  LResult := TLegacyCustomerTranslator.Translate(Customer);
  try
    Assert.IsFalse(LResult.Ignored);
    Assert.AreEqual(0, Integer(Length(LResult.Warnings)));
    Assert.AreEqual('Maria da Silva', LResult.Body.GetValue<string>('name'));
    Assert.AreEqual('52998224725', LResult.Body.GetValue<string>('cpf'));
    Assert.AreEqual('31999998888', LResult.Body.GetValue<string>('phone'));
    Assert.AreEqual('maria@exemplo.com', LResult.Body.GetValue<string>('email'));
    Assert.AreEqual('1980-12-25', LResult.Body.GetValue<string>('birthDate'));
  finally
    LResult.Body.Free;
  end;
end;

procedure TLegacyTranslatorTests.DiscardsPhoneWithoutAreaCode;
var
  LCustomer: TLegacyCustomer;
  LResult: TTranslation;
begin
  LCustomer := Customer;
  LCustomer.Phone := '99999-8888';
  LResult := TLegacyCustomerTranslator.Translate(LCustomer);
  try
    Assert.IsNull(LResult.Body.FindValue('phone'));
    Assert.AreEqual(1, Integer(Length(LResult.Warnings)));
    Assert.Contains(LResult.Warnings[0], 'FONE');
  finally
    LResult.Body.Free;
  end;
end;

procedure TLegacyTranslatorTests.DiscardsImpossibleBirthDate;
var
  LCustomer: TLegacyCustomer;
  LResult: TTranslation;
begin
  LCustomer := Customer;
  LCustomer.BirthDate := '31/02/1985';
  LResult := TLegacyCustomerTranslator.Translate(LCustomer);
  try
    Assert.IsNull(LResult.Body.FindValue('birthDate'));
    Assert.AreEqual(1, Integer(Length(LResult.Warnings)));
    Assert.Contains(LResult.Warnings[0], 'DT_NASC');
  finally
    LResult.Body.Free;
  end;
end;

procedure TLegacyTranslatorTests.LeavesEmptyFieldsOut;
var
  LCustomer: TLegacyCustomer;
  LResult: TTranslation;
begin
  LCustomer := Customer;
  LCustomer.Phone := '';
  LCustomer.Email := '   ';
  LCustomer.BirthDate := '';
  LResult := TLegacyCustomerTranslator.Translate(LCustomer);
  try
    Assert.IsNull(LResult.Body.FindValue('phone'));
    Assert.IsNull(LResult.Body.FindValue('email'));
    Assert.IsNull(LResult.Body.FindValue('birthDate'));
    Assert.AreEqual(0, Integer(Length(LResult.Warnings)));
  finally
    LResult.Body.Free;
  end;
end;

procedure TLegacyTranslatorTests.IgnoresInactiveCustomers;
var
  LCustomer: TLegacyCustomer;
  LResult: TTranslation;
begin
  LCustomer := Customer;
  LCustomer.Status := 'I';
  LResult := TLegacyCustomerTranslator.Translate(LCustomer);
  Assert.IsTrue(LResult.Ignored);
  Assert.IsNull(LResult.Body);
end;

initialization
  TDUnitX.RegisterTestFixture(TLegacyTranslatorTests);

end.
