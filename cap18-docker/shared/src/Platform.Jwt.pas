unit Platform.Jwt;

{ JSON Web Token (RFC 7519) assinado com HMAC-SHA256 (HS256).

  Um JWT são três partes em Base64URL, separadas por ponto:
    cabeçalho.conteúdo.assinatura
  A assinatura é o HMAC-SHA256 de "cabeçalho.conteúdo" com a chave secreta.
  Quem não conhece a chave não consegue gerar uma assinatura válida, e
  qualquer alteração no conteúdo invalida a assinatura.

  Esta unit implementa apenas o formato HS256, usando o HMAC do próprio
  Delphi (System.Hash). Para outros algoritmos (RS256, ES256...), use uma
  biblioteca completa, como a delphi-jose-jwt. }

interface

uses
  System.SysUtils,
  System.JSON;

type
  EJwtException = class(Exception);

  TJwt = class
  public
    // Gera o token. As claims não são liberadas aqui: quem criou libera.
    class function Sign(const AClaims: TJSONObject; const ASecret: string): string; static;
    // Confere formato, algoritmo, assinatura e validade (exp/nbf).
    // Devolve as claims; quem chama é dono do objeto. Lança EJwtException.
    class function Verify(const AToken, ASecret: string): TJSONObject; static;
    // Agora, em segundos desde 01/01/1970 UTC: o relógio dos JWT.
    class function NowUnix: Int64; static;
  end;

implementation

uses
  System.Hash,
  System.NetEncoding,
  System.DateUtils;

const
  HEADER_HS256 = '{"alg":"HS256","typ":"JWT"}';
  // Tolerância para pequenas diferenças de relógio entre servidores.
  CLOCK_SKEW_SECONDS = 30;

function Base64UrlEncode(const ABytes: TBytes): string;
var
  LEncoding: TBase64Encoding;
begin
  // Base64 comum, sem quebras de linha, trocando os caracteres que
  // atrapalham em URLs e sem o preenchimento "=".
  LEncoding := TBase64Encoding.Create(0);
  try
    Result := LEncoding.EncodeBytesToString(ABytes)
      .Replace('+', '-', [rfReplaceAll])
      .Replace('/', '_', [rfReplaceAll])
      .Replace('=', '', [rfReplaceAll]);
  finally
    LEncoding.Free;
  end;
end;

function Base64UrlDecode(const AText: string): TBytes;
var
  LText: string;
  LEncoding: TBase64Encoding;
begin
  LText := AText.Replace('-', '+', [rfReplaceAll]).Replace('_', '/', [rfReplaceAll]);
  while Length(LText) mod 4 <> 0 do
    LText := LText + '=';
  LEncoding := TBase64Encoding.Create(0);
  try
    Result := LEncoding.DecodeStringToBytes(LText);
  finally
    LEncoding.Free;
  end;
end;

function Signature(const ASigningInput, ASecret: string): TBytes;
begin
  Result := THashSHA2.GetHMACAsBytes(TEncoding.UTF8.GetBytes(ASigningInput),
    TEncoding.UTF8.GetBytes(ASecret), THashSHA2.TSHA2Version.SHA256);
end;

// Compara em tempo constante: o tempo gasto não revela em que posição
// as assinaturas começam a diferir.
function SameBytes(const A, B: TBytes): Boolean;
var
  I: Integer;
  LDiff: Byte;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  LDiff := 0;
  for I := 0 to High(A) do
    LDiff := LDiff or (A[I] xor B[I]);
  Result := LDiff = 0;
end;

class function TJwt.NowUnix: Int64;
begin
  Result := DateTimeToUnix(Now, False);
end;

class function TJwt.Sign(const AClaims: TJSONObject; const ASecret: string): string;
var
  LInput: string;
begin
  LInput := Base64UrlEncode(TEncoding.UTF8.GetBytes(HEADER_HS256)) + '.' +
    Base64UrlEncode(TEncoding.UTF8.GetBytes(AClaims.ToJSON));
  Result := LInput + '.' + Base64UrlEncode(Signature(LInput, ASecret));
end;

class function TJwt.Verify(const AToken, ASecret: string): TJSONObject;
var
  LParts: TArray<string>;
  LHeader: TJSONValue;
  LAlg: string;
  LValue: TJSONValue;
  LExp, LNbf: Int64;
begin
  LParts := AToken.Split(['.']);
  if Length(LParts) <> 3 then
    raise EJwtException.Create('Token mal formado.');

  // 1. Algoritmo: aceitamos SOMENTE HS256. Um token que diz "alg: none"
  //    (sem assinatura) é um ataque conhecido e precisa ser recusado.
  try
    LHeader := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(Base64UrlDecode(LParts[0])));
  except
    LHeader := nil;
  end;
  try
    if not (LHeader is TJSONObject) or
       not TJSONObject(LHeader).TryGetValue<string>('alg', LAlg) or (LAlg <> 'HS256') then
      raise EJwtException.Create('Algoritmo do token não aceito.');
  finally
    LHeader.Free;
  end;

  // 2. Assinatura.
  if not SameBytes(Base64UrlDecode(LParts[2]), Signature(LParts[0] + '.' + LParts[1], ASecret)) then
    raise EJwtException.Create('Assinatura do token inválida.');

  // 3. Conteúdo e validade.
  try
    LValue := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(Base64UrlDecode(LParts[1])));
  except
    LValue := nil;
  end;
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EJwtException.Create('Conteúdo do token inválido.');
  end;
  Result := TJSONObject(LValue);
  try
    if not Result.TryGetValue<Int64>('exp', LExp) then
      raise EJwtException.Create('Token sem data de expiração.');
    if NowUnix > LExp + CLOCK_SKEW_SECONDS then
      raise EJwtException.Create('Token expirado.');
    if Result.TryGetValue<Int64>('nbf', LNbf) and (NowUnix + CLOCK_SKEW_SECONDS < LNbf) then
      raise EJwtException.Create('Token ainda não é válido.');
  except
    Result.Free;
    raise;
  end;
end;

end.
