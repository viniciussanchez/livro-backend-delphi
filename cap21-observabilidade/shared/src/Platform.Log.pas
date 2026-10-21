unit Platform.Log;

(* Log estruturado (capítulo 21).

  Em vez de Writeln com texto livre, cada evento vira uma linha com campos
  que uma máquina consegue ler:

    {"time":"2026-10-19T23:03:19.412Z","level":"info","service":"ticket-api",
     "pod":"ticket-api-5c6b48675b-blbh6","requestId":"8c6b...","msg":"requisição",
     "method":"POST","route":"/reservations","status":201,"durationMs":42}

  Em desenvolvimento, o mesmo evento sai em texto, fácil de ler no console:

    23:03:19.412 INFO  requisição method=POST route=/reservations status=201 durationMs=42

  Três regras valem para tudo o que passa por aqui:
    - uma linha por evento, escrita de uma vez só (sem linhas encavaladas);
    - o requestId da requisição atual entra sozinho em toda linha;
    - nada de senhas, tokens ou dados pessoais nos campos. *)

interface

uses
  System.SysUtils;

type
  TLogField = record
    Key: string;
    Value: string;
    IsNumber: Boolean;
  end;

  TLogLevel = (llDebug, llInfo, llWarn, llError);

  TLog = class
  public
    // AFormat: 'json', 'text' ou 'auto' (json em produção, texto fora dela).
    class procedure Configure(const AServiceName, AFormat: string; const AProduction: Boolean); static;
    class function IsJson: Boolean; static;
    class procedure Write(const ALevel: TLogLevel; const AMessage: string;
      const AFields: array of TLogField); static;
    class procedure Info(const AMessage: string; const AFields: array of TLogField); overload; static;
    class procedure Info(const AMessage: string); overload; static;
    class procedure Warn(const AMessage: string; const AFields: array of TLogField); overload; static;
    class procedure Warn(const AMessage: string); overload; static;
    class procedure Error(const AMessage: string; const AFields: array of TLogField); overload; static;
    class procedure Error(const AMessage: string); overload; static;
  end;

// Atalhos para montar campos: F('route', '/reservations'), F('status', 201).
function F(const AKey, AValue: string): TLogField; overload;
function F(const AKey: string; const AValue: Int64): TLogField; overload;

// O identificador da requisição que esta thread está atendendo agora.
// Quem preenche é o middleware de Platform.Middleware.Observability.
function CurrentRequestId: string;
procedure SetCurrentRequestId(const AValue: string);

implementation

uses
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  System.JSON;

var
  GLock: TCriticalSection;
  GServiceName: string = '';
  GPodName: string = '';
  GJson: Boolean = False;

threadvar
  // Cada thread do Horse atende uma requisição por vez. Uma variável
  // "por thread" é o jeito mais simples de levar o requestId até o fundo
  // do código (repositórios, clientes HTTP) sem passá-lo de parâmetro em
  // parâmetro.
  GRequestId: string;

function CurrentRequestId: string;
begin
  Result := GRequestId;
end;

procedure SetCurrentRequestId(const AValue: string);
begin
  GRequestId := AValue;
end;

function F(const AKey, AValue: string): TLogField;
begin
  Result.Key := AKey;
  Result.Value := AValue;
  Result.IsNumber := False;
end;

function F(const AKey: string; const AValue: Int64): TLogField;
begin
  Result.Key := AKey;
  Result.Value := AValue.ToString;
  Result.IsNumber := True;
end;

const
  LEVEL_NAMES: array[TLogLevel] of string = ('debug', 'info', 'warn', 'error');

class procedure TLog.Configure(const AServiceName, AFormat: string; const AProduction: Boolean);
begin
  GServiceName := AServiceName;
  // No Kubernetes, a variável HOSTNAME traz o nome do Pod.
  GPodName := GetEnvironmentVariable('HOSTNAME');
  if SameText(AFormat, 'json') then
    GJson := True
  else if SameText(AFormat, 'text') then
    GJson := False
  else
    GJson := AProduction;
end;

class function TLog.IsJson: Boolean;
begin
  Result := GJson;
end;

function JsonLine(const ALevel: TLogLevel; const AMessage: string;
  const AFields: array of TLogField): string;
var
  LJSON: TJSONObject;
  LField: TLogField;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('time', DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True));
    LJSON.AddPair('level', LEVEL_NAMES[ALevel]);
    if not GServiceName.IsEmpty then
      LJSON.AddPair('service', GServiceName);
    if not GPodName.IsEmpty then
      LJSON.AddPair('pod', GPodName);
    if not CurrentRequestId.IsEmpty then
      LJSON.AddPair('requestId', CurrentRequestId);
    LJSON.AddPair('msg', AMessage);
    for LField in AFields do
      if LField.IsNumber then
        LJSON.AddPair(LField.Key, TJSONNumber.Create(StrToInt64(LField.Value)))
      else
        LJSON.AddPair(LField.Key, LField.Value);
    Result := LJSON.ToJSON([TJSONValue.TJSONOutputOption.EncodeBelow32]);
  finally
    LJSON.Free;
  end;
end;

function TextLine(const ALevel: TLogLevel; const AMessage: string;
  const AFields: array of TLogField): string;
var
  LField: TLogField;
begin
  Result := Format('%s %-5s %s', [FormatDateTime('hh:nn:ss.zzz', Now),
    LEVEL_NAMES[ALevel].ToUpper, AMessage]);
  if not CurrentRequestId.IsEmpty then
    Result := Result + ' requestId=' + CurrentRequestId;
  for LField in AFields do
    Result := Result + ' ' + LField.Key + '=' + LField.Value;
end;

class procedure TLog.Write(const ALevel: TLogLevel; const AMessage: string;
  const AFields: array of TLogField);
var
  LLine: string;
begin
  // Monta a linha inteira antes e escreve de uma vez, dentro da seção
  // crítica: duas threads nunca intercalam pedaços das suas linhas.
  if GJson then
    LLine := JsonLine(ALevel, AMessage, AFields)
  else
    LLine := TextLine(ALevel, AMessage, AFields);
  GLock.Enter;
  try
    Writeln(LLine);
    Flush(Output);
  finally
    GLock.Leave;
  end;
end;

class procedure TLog.Info(const AMessage: string; const AFields: array of TLogField);
begin
  Write(llInfo, AMessage, AFields);
end;

class procedure TLog.Info(const AMessage: string);
begin
  Write(llInfo, AMessage, []);
end;

class procedure TLog.Warn(const AMessage: string; const AFields: array of TLogField);
begin
  Write(llWarn, AMessage, AFields);
end;

class procedure TLog.Warn(const AMessage: string);
begin
  Write(llWarn, AMessage, []);
end;

class procedure TLog.Error(const AMessage: string; const AFields: array of TLogField);
begin
  Write(llError, AMessage, AFields);
end;

class procedure TLog.Error(const AMessage: string);
begin
  Write(llError, AMessage, []);
end;

initialization
  GLock := TCriticalSection.Create;

finalization
  GLock.Free;

end.
