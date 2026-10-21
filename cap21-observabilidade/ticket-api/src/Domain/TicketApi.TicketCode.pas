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
  System.SysUtils,
  Platform.SecureRandom;

const
  ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  CODE_LENGTH = 10;
  // 248 é o maior múltiplo de 31 (o tamanho do alfabeto) que cabe em um byte.
  // Bytes de 248 a 255 são descartados: se usássemos "mod 31" neles, as
  // primeiras letras do alfabeto sairiam um pouco mais do que as outras.
  ACCEPT_BELOW = 256 - (256 mod Length(ALPHABET));

class function TTicketCode.New: string;
var
  LBytes: TBytes;
  LByte: Byte;
  LCount: Integer;
begin
  // Capítulo 17: os bytes vêm do gerador criptográfico do sistema operacional.
  // Até o capítulo 16 usávamos os bytes de um TGUID.NewGuid, que no Windows
  // são aleatórios, mas no Linux são derivados do relógio.
  SetLength(Result, CODE_LENGTH);
  LCount := 0;
  while LCount < CODE_LENGTH do
  begin
    LBytes := SecureRandomBytes(CODE_LENGTH * 2);
    for LByte in LBytes do
      if (LByte < ACCEPT_BELOW) and (LCount < CODE_LENGTH) then
      begin
        Inc(LCount);
        Result[LCount] := ALPHABET[(LByte mod Length(ALPHABET)) + 1];
      end;
  end;
end;

end.
