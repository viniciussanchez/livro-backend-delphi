unit TicketApi.TicketCode;

{ Geração do código de validação impresso no ingresso. }

interface

type
  TTicketCode = class
  public
    // 10 caracteres, sem letras e números que se confundem (0/O, 1/I/L).
    class function New: string; static;
  end;

implementation

uses
  System.SysUtils;

const
  ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  CODE_LENGTH = 10;
  RANDOM_BYTES: array[0..CODE_LENGTH - 1] of Integer = (0, 1, 2, 3, 4, 5, 10, 11, 12, 13);

class function TTicketCode.New: string;
var
  LBytes: TBytes;
  I: Integer;
begin
  // Um GUID novo traz bytes aleatórios gerados pelo sistema operacional.
  // Ao contrário do Random, não depende de semente e pode ser chamado
  // de várias threads ao mesmo tempo. Pulamos os bytes 6 a 9, que contêm
  // os bits fixos de versão e variante do GUID.
  LBytes := TGUID.NewGuid.ToByteArray;
  SetLength(Result, CODE_LENGTH);
  for I := 0 to CODE_LENGTH - 1 do
    Result[I + 1] := ALPHABET[(LBytes[RANDOM_BYTES[I]] mod Length(ALPHABET)) + 1];
end;

end.
