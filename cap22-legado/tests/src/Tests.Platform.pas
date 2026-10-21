unit Tests.Platform;

{ Testes das peças compartilhadas: validação e JWT. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TValidationTests = class
  public
    [Test]
    procedure NoErrorsDoesNotRaise;
    [Test]
    procedure CollectsEveryProblemBeforeRaising;
    [Test]
    procedure CheckReturnsTheCondition;
  end;

  [TestFixture]
  TJwtTests = class
  private
    const SECRET = 'uma-chave-de-teste-com-mais-de-32-caracteres';
    function Claims(const AExpiresIn: Integer): string;
  public
    [Test]
    procedure SignedTokenIsAccepted;
    [Test]
    procedure ChangedContentIsRejected;
    [Test]
    procedure OtherKeyIsRejected;
    [Test]
    procedure ExpiredTokenIsRejected;
    [Test]
    procedure AlgNoneIsRejected;
    [Test]
    procedure GarbageIsRejected;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.NetEncoding,
  Platform.Exceptions,
  Platform.Validation,
  Platform.Jwt;

{ TValidationTests }

procedure TValidationTests.NoErrorsDoesNotRaise;
var
  LValidation: TValidation;
begin
  LValidation.Check(True, 'name', 'não deveria aparecer');
  Assert.WillNotRaise(
    procedure
    begin
      LValidation.RaiseIfInvalid;
    end);
end;

procedure TValidationTests.CollectsEveryProblemBeforeRaising;
var
  LValidation: TValidation;
begin
  LValidation.Check(False, 'name', 'Informe o nome.');
  LValidation.Check(True, 'email', 'não deveria aparecer');
  LValidation.Check(False, 'quantity', 'A quantidade deve ser maior que zero.');
  try
    LValidation.RaiseIfInvalid;
    Assert.Fail('Deveria ter lançado EValidationException');
  except
    on E: EValidationException do
    begin
      Assert.AreEqual(2, Integer(Length(E.Errors)));
      Assert.AreEqual('name', E.Errors[0].Field);
      Assert.AreEqual('quantity', E.Errors[1].Field);
      Assert.AreEqual('Os dados enviados têm 2 problemas.', E.Message);
      Assert.AreEqual('validation-error', E.Code);
    end;
  end;
end;

procedure TValidationTests.CheckReturnsTheCondition;
var
  LValidation: TValidation;
begin
  Assert.IsTrue(LValidation.Check(True, 'a', 'x'));
  Assert.IsFalse(LValidation.Check(False, 'b', 'y'));
  Assert.IsTrue(LValidation.HasError('b'));
  Assert.IsFalse(LValidation.HasError('a'));
end;

{ TJwtTests }

function TJwtTests.Claims(const AExpiresIn: Integer): string;
begin
  Result := Format('{"sub":"7","role":"customer","cid":7,"exp":%d}', [TJwt.NowUnix + AExpiresIn]);
end;

function SignClaims(const AJSON, ASecret: string): string;
var
  LClaims: TJSONObject;
begin
  LClaims := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  try
    Result := TJwt.Sign(LClaims, ASecret);
  finally
    LClaims.Free;
  end;
end;

// Confere que o token é recusado e, se informado, com qual mensagem.
procedure ExpectRejected(const AToken, ASecret, AMessage: string);
var
  LMessage: string;
  LRejected: Boolean;
begin
  LRejected := False;
  try
    TJwt.Verify(AToken, ASecret).Free;
  except
    on E: EJwtException do
    begin
      LRejected := True;
      LMessage := E.Message;
    end;
  end;
  Assert.IsTrue(LRejected, 'O token deveria ter sido recusado');
  if AMessage <> '' then
    Assert.AreEqual(AMessage, LMessage);
end;

function B64Url(const AText: string): string;
begin
  Result := TNetEncoding.Base64.Encode(AText)
    .Replace(sLineBreak, '', [rfReplaceAll])
    .Replace('+', '-', [rfReplaceAll]).Replace('/', '_', [rfReplaceAll]).Replace('=', '', [rfReplaceAll]);
end;

procedure TJwtTests.SignedTokenIsAccepted;
var
  LClaims: TJSONObject;
begin
  LClaims := TJwt.Verify(SignClaims(Claims(3600), SECRET), SECRET);
  try
    Assert.AreEqual('customer', LClaims.GetValue<string>('role'));
    Assert.AreEqual(7, LClaims.GetValue<Integer>('cid'));
  finally
    LClaims.Free;
  end;
end;

procedure TJwtTests.ChangedContentIsRejected;
var
  LParts: TArray<string>;
  LForged: string;
begin
  // Pega um token verdadeiro e troca só o papel no conteúdo.
  LParts := SignClaims(Claims(3600), SECRET).Split(['.']);
  LForged := LParts[0] + '.' + B64Url(Claims(3600).Replace('customer', 'admin')) + '.' + LParts[2];
  ExpectRejected(LForged, SECRET, 'Assinatura do token inválida.');
end;

procedure TJwtTests.OtherKeyIsRejected;
var
  LToken: string;
begin
  LToken := SignClaims(Claims(3600), 'outra-chave-que-o-servidor-nao-conhece');
  ExpectRejected(LToken, SECRET, 'Assinatura do token inválida.');
end;

procedure TJwtTests.ExpiredTokenIsRejected;
var
  LToken: string;
begin
  LToken := SignClaims(Claims(-3600), SECRET);
  ExpectRejected(LToken, SECRET, 'Token expirado.');
end;

procedure TJwtTests.AlgNoneIsRejected;
var
  LToken: string;
begin
  LToken := B64Url('{"alg":"none","typ":"JWT"}') + '.' + B64Url(Claims(3600)) + '.';
  ExpectRejected(LToken, SECRET, 'Algoritmo do token não aceito.');
end;

procedure TJwtTests.GarbageIsRejected;
begin
  ExpectRejected('isto-nao-e-um-token', SECRET, '');
end;

initialization
  TDUnitX.RegisterTestFixture(TValidationTests);
  TDUnitX.RegisterTestFixture(TJwtTests);

end.
