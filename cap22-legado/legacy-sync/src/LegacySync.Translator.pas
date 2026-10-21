unit LegacySync.Translator;

(* A camada anticorrupção (capítulo 22).

  O sistema antigo e a plataforma nova falam "línguas" diferentes:

    CLIENTE.NOME     'ANA  SILVA'          ->  name       'Ana Silva'
    CLIENTE.CPF      '123.456.789-09'      ->  cpf        '12345678909'
    CLIENTE.FONE     '(31) 99999-8888'     ->  phone      '31999998888'
    CLIENTE.EMAIL    ' Ana@Exemplo.com '   ->  email      'ana@exemplo.com'
    CLIENTE.DT_NASC  '25/12/1980'          ->  birthDate  '1980-12-25'

  Toda essa tradução fica aqui, e só aqui. A customer-api não sabe que o
  sistema antigo existe, e o sistema antigo não sabe que a customer-api
  existe. Se um dia o legado for desligado, esta unit vai junto.

  A unit não acessa banco nem rede: recebe um registro e devolve JSON.
  Por isso, é fácil de testar (veja tests/src/Tests.LegacySync.pas). *)

interface

uses
  System.JSON;

type
  // Uma linha da tabela CLIENTE, do jeito que está no banco antigo.
  TLegacyCustomer = record
    Code: Integer;
    Name: string;
    Cpf: string;
    Phone: string;
    Email: string;
    BirthDate: string;
    Status: string;
  end;

  TTranslation = record
    // O corpo para a customer-api. Quem chama é dono do objeto.
    Body: TJSONObject;
    // Dados que não puderam ser aproveitados e foram deixados de fora.
    Warnings: TArray<string>;
    // True quando o cliente não deve ir para a plataforma nova.
    Ignored: Boolean;
    IgnoreReason: string;
  end;

  TLegacyCustomerTranslator = class
  public
    class function Translate(const ACustomer: TLegacyCustomer): TTranslation; static;
    // 'ANA  DA SILVA' -> 'Ana da Silva'
    class function NormalizeName(const AValue: string): string; static;
    // 'dd/mm/aaaa' -> 'aaaa-mm-dd'. False se não for uma data válida.
    class function ConvertDate(const AValue: string; out AIsoDate: string): Boolean; static;
    class function OnlyDigits(const AValue: string): string; static;
  end;

implementation

uses
  System.SysUtils;

class function TLegacyCustomerTranslator.OnlyDigits(const AValue: string): string;
var
  LChar: Char;
begin
  Result := '';
  for LChar in AValue do
    if CharInSet(LChar, ['0'..'9']) then
      Result := Result + LChar;
end;

class function TLegacyCustomerTranslator.NormalizeName(const AValue: string): string;
const
  // Preposições ficam em minúsculas: "Maria da Silva", "João dos Santos".
  LOWER_WORDS: array[0..4] of string = ('da', 'de', 'do', 'das', 'dos');
var
  LWord: string;
  LLower: string;
  LIsPreposition: Boolean;
  I: Integer;
begin
  Result := '';
  for LWord in AValue.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty) do
  begin
    LLower := LWord.ToLower;
    LIsPreposition := False;
    for I := Low(LOWER_WORDS) to High(LOWER_WORDS) do
      if LLower = LOWER_WORDS[I] then
        LIsPreposition := True;
    if not Result.IsEmpty then
      Result := Result + ' ';
    if LIsPreposition then
      Result := Result + LLower
    else
      Result := Result + LLower.Substring(0, 1).ToUpper + LLower.Substring(1);
  end;
end;

class function TLegacyCustomerTranslator.ConvertDate(const AValue: string; out AIsoDate: string): Boolean;
var
  LParts: TArray<string>;
  LDay, LMonth, LYear: Integer;
  LDate: TDateTime;
begin
  AIsoDate := '';
  LParts := AValue.Trim.Split(['/']);
  Result := (Length(LParts) = 3) and TryStrToInt(LParts[0], LDay) and TryStrToInt(LParts[1], LMonth) and
    TryStrToInt(LParts[2], LYear) and (LYear >= 1900) and TryEncodeDate(LYear, LMonth, LDay, LDate);
  if Result then
    AIsoDate := FormatDateTime('yyyy-mm-dd', LDate);
end;

class function TLegacyCustomerTranslator.Translate(const ACustomer: TLegacyCustomer): TTranslation;
var
  LPhone, LBirthDate: string;
begin
  Result.Body := nil;
  Result.Warnings := [];
  Result.Ignored := False;
  Result.IgnoreReason := '';

  // Decisão do negócio: quem está inativo no sistema antigo não vai para a
  // plataforma nova. Se voltar a comprar no balcão e for reativado, a
  // alteração passa pelo gatilho e ele é enviado nesse momento.
  if SameText(ACustomer.Status.Trim, 'I') then
  begin
    Result.Ignored := True;
    Result.IgnoreReason := 'cliente inativo no sistema antigo';
    Exit;
  end;

  Result.Body := TJSONObject.Create;
  Result.Body.AddPair('name', NormalizeName(ACustomer.Name));
  // O CPF segue só com os dígitos. Se ele é válido ou não, quem decide é a
  // customer-api: a regra mora num lugar só.
  Result.Body.AddPair('cpf', OnlyDigits(ACustomer.Cpf));

  if not ACustomer.Email.Trim.IsEmpty then
    Result.Body.AddPair('email', ACustomer.Email.Trim.ToLower);

  // Telefone e data de nascimento são opcionais na plataforma nova.
  // Decisão do negócio: se o valor antigo não serve, ele é deixado de fora
  // (e registrado no log), em vez de impedir a migração do cliente.
  LPhone := OnlyDigits(ACustomer.Phone);
  if (LPhone.Length = 10) or (LPhone.Length = 11) then
    Result.Body.AddPair('phone', LPhone)
  else if not LPhone.IsEmpty then
    Result.Warnings := Result.Warnings + [Format('FONE "%s" sem DDD ou incompleto: descartado', [ACustomer.Phone.Trim])];

  if not ACustomer.BirthDate.Trim.IsEmpty then
    if ConvertDate(ACustomer.BirthDate, LBirthDate) then
      Result.Body.AddPair('birthDate', LBirthDate)
    else
      Result.Warnings := Result.Warnings + [Format('DT_NASC "%s" não é uma data válida: descartada', [ACustomer.BirthDate.Trim])];
end;

end.
