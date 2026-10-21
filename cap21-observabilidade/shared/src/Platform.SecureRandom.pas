unit Platform.SecureRandom;

(* Bytes aleatórios de verdade, vindos do sistema operacional.

  Use para tudo que não pode ser adivinhado: códigos de ingresso, tokens,
  senhas temporárias. O Random do Delphi não serve para isso (é previsível
  a partir da semente), e o TGUID.NewGuid também não: no Windows ele é
  aleatório, mas no Linux o Delphi gera GUIDs baseados no relógio, quase
  iguais entre si (capítulo 17).

    Windows: BCryptGenRandom, o gerador criptográfico do sistema.
    Linux:   /dev/urandom, a fonte equivalente do kernel. *)

interface

uses
  System.SysUtils;

function SecureRandomBytes(const ACount: Integer): TBytes;

implementation

uses
  System.Classes;

{$IFDEF MSWINDOWS}
const
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;

function BCryptGenRandom(hAlgorithm: Pointer; pbBuffer: PByte; cbBuffer: Cardinal;
  dwFlags: Cardinal): Integer; stdcall; external 'bcrypt.dll';

function SecureRandomBytes(const ACount: Integer): TBytes;
begin
  SetLength(Result, ACount);
  if (ACount > 0) and
     (BCryptGenRandom(nil, @Result[0], ACount, BCRYPT_USE_SYSTEM_PREFERRED_RNG) <> 0) then
    raise Exception.Create('Não foi possível obter bytes aleatórios do sistema.');
end;
{$ENDIF}

{$IFDEF POSIX}
function SecureRandomBytes(const ACount: Integer): TBytes;
var
  LStream: TFileStream;
begin
  SetLength(Result, ACount);
  if ACount = 0 then
    Exit;
  LStream := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyNone);
  try
    LStream.ReadBuffer(Result[0], ACount);
  finally
    LStream.Free;
  end;
end;
{$ENDIF}

end.
