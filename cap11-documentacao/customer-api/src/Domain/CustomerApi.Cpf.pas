unit CustomerApi.Cpf;

{ Regras do CPF: normalização, validação dos dígitos verificadores e máscara. }

interface

type
  TCpf = class
  public
    // Remove tudo que não é dígito: '123.456.789-09' -> '12345678909'.
    class function OnlyDigits(const AValue: string): string; static;
    // Confere tamanho, sequências repetidas e os dois dígitos verificadores.
    class function IsValid(const ADigits: string): Boolean; static;
    // Esconde parte do número para exibição: '***.456.789-**'.
    class function Mask(const ADigits: string): string; static;
  end;

implementation

uses
  System.SysUtils;

class function TCpf.OnlyDigits(const AValue: string): string;
var
  LChar: Char;
begin
  Result := '';
  for LChar in AValue do
    if CharInSet(LChar, ['0'..'9']) then
      Result := Result + LChar;
end;

class function TCpf.IsValid(const ADigits: string): Boolean;

  function CheckDigit(const ALength: Integer): Integer;
  var
    I, LSum: Integer;
  begin
    // Cada dígito é multiplicado por um peso decrescente, começando em ALength + 1.
    LSum := 0;
    for I := 1 to ALength do
      LSum := LSum + StrToInt(ADigits[I]) * (ALength + 2 - I);
    Result := (LSum * 10) mod 11;
    if Result = 10 then
      Result := 0;
  end;

begin
  if (ADigits.Length <> 11) or (ADigits <> OnlyDigits(ADigits)) then
    Exit(False);

  // 000.000.000-00, 111.111.111-11... passam no cálculo, mas não são CPFs válidos.
  if ADigits = StringOfChar(ADigits[1], 11) then
    Exit(False);

  Result := (CheckDigit(9) = StrToInt(ADigits[10])) and
            (CheckDigit(10) = StrToInt(ADigits[11]));
end;

class function TCpf.Mask(const ADigits: string): string;
begin
  if ADigits.Length <> 11 then
    Exit('');
  Result := '***.' + ADigits.Substring(3, 3) + '.' + ADigits.Substring(6, 3) + '-**';
end;

end.
