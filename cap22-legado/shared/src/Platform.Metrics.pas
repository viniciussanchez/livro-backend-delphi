unit Platform.Metrics;

(* Métricas no formato do Prometheus (capítulo 21).

  O serviço guarda contadores em memória e os mostra em GET /metrics, em
  texto, num formato que o Prometheus sabe ler:

    # HELP http_requests_total Requisições HTTP atendidas.
    # TYPE http_requests_total counter
    http_requests_total{method="POST",route="/reservations",status="201"} 10

  Quem coleta é o Prometheus, de tempos em tempos (modelo "pull"). O
  serviço só conta; não sabe nem precisa saber quem vai ler.

  Dois tipos bastam para a plataforma:
    - contador: só cresce (requisições, ingressos vendidos);
    - histograma: conta quantas observações caíram em cada faixa de valor
      (por exemplo, quantas requisições levaram até 50 ms, até 100 ms...). *)

interface

uses
  System.SysUtils;

type
  TMetrics = class
  public
    // Soma AValue ao contador AName com os rótulos ALabels ("chave=valor").
    class procedure Inc(const AName, AHelp: string; const ALabels: array of string;
      const AValue: Int64 = 1); static;
    // Registra uma duração, em segundos, no histograma AName.
    class procedure Observe(const AName, AHelp: string; const ALabels: array of string;
      const ASeconds: Double); static;
    // O texto completo de /metrics.
    class function Render: string; static;
  end;

// Rota para o rótulo "route": troca ids por marcadores, para que
// /reservations/17 e /reservations/18 contem como a mesma rota.
function RouteTemplate(const APath: string): string;

// Registra GET /metrics no Horse.
procedure RegisterMetricsEndpoint;

implementation

uses
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.DateUtils,
  Horse;

const
  // Faixas do histograma de duração, em segundos (de 5 ms a 5 s).
  BUCKETS: array[0..9] of Double = (0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5);

type
  THistogram = class
    Counts: array[0..High(BUCKETS)] of Int64;
    Count: Int64;
    Sum: Double;
  end;

  TFamily = class
    Help: string;
    IsHistogram: Boolean;
    Counters: TDictionary<string, Int64>;
    Histograms: TObjectDictionary<string, THistogram>;
    constructor Create(const AHelp: string; const AIsHistogram: Boolean);
    destructor Destroy; override;
  end;

var
  GLock: TCriticalSection;
  GFamilies: TObjectDictionary<string, TFamily>;
  GStartTime: TDateTime;

constructor TFamily.Create(const AHelp: string; const AIsHistogram: Boolean);
begin
  inherited Create;
  Help := AHelp;
  IsHistogram := AIsHistogram;
  Counters := TDictionary<string, Int64>.Create;
  Histograms := TObjectDictionary<string, THistogram>.Create([doOwnsValues]);
end;

destructor TFamily.Destroy;
begin
  Histograms.Free;
  Counters.Free;
  inherited;
end;

function Escape(const AValue: string): string;
begin
  Result := AValue.Replace('\', '\\').Replace('"', '\"').Replace(#10, '\n');
end;

// ['method=POST', 'status=201'] -> method="POST",status="201"
function LabelText(const ALabels: array of string): string;
var
  LLabel: string;
  LPos: Integer;
begin
  Result := '';
  for LLabel in ALabels do
  begin
    LPos := LLabel.IndexOf('=');
    if not Result.IsEmpty then
      Result := Result + ',';
    Result := Result + LLabel.Substring(0, LPos) + '="' + Escape(LLabel.Substring(LPos + 1)) + '"';
  end;
end;

function FamilyFor(const AName, AHelp: string; const AIsHistogram: Boolean): TFamily;
begin
  if not GFamilies.TryGetValue(AName, Result) then
  begin
    Result := TFamily.Create(AHelp, AIsHistogram);
    GFamilies.Add(AName, Result);
  end;
end;

class procedure TMetrics.Inc(const AName, AHelp: string; const ALabels: array of string;
  const AValue: Int64);
var
  LFamily: TFamily;
  LKey: string;
  LCurrent: Int64;
begin
  LKey := LabelText(ALabels);
  GLock.Enter;
  try
    LFamily := FamilyFor(AName, AHelp, False);
    if not LFamily.Counters.TryGetValue(LKey, LCurrent) then
      LCurrent := 0;
    LFamily.Counters.AddOrSetValue(LKey, LCurrent + AValue);
  finally
    GLock.Leave;
  end;
end;

class procedure TMetrics.Observe(const AName, AHelp: string; const ALabels: array of string;
  const ASeconds: Double);
var
  LFamily: TFamily;
  LHistogram: THistogram;
  LKey: string;
  I: Integer;
begin
  LKey := LabelText(ALabels);
  GLock.Enter;
  try
    LFamily := FamilyFor(AName, AHelp, True);
    if not LFamily.Histograms.TryGetValue(LKey, LHistogram) then
    begin
      LHistogram := THistogram.Create;
      LFamily.Histograms.Add(LKey, LHistogram);
    end;
    // As faixas são acumulativas: uma requisição de 30 ms conta
    // em "até 50 ms", "até 100 ms" e em todas as maiores.
    for I := 0 to High(BUCKETS) do
      if ASeconds <= BUCKETS[I] then
        System.Inc(LHistogram.Counts[I]);
    System.Inc(LHistogram.Count);
    LHistogram.Sum := LHistogram.Sum + ASeconds;
  finally
    GLock.Leave;
  end;
end;

function Num(const AValue: Double): string;
begin
  // O Prometheus quer ponto decimal, qualquer que seja o idioma do sistema.
  Result := FloatToStr(AValue, TFormatSettings.Invariant);
end;

function WithLabel(const ALabels, AExtra: string): string;
begin
  if ALabels.IsEmpty then
    Result := '{' + AExtra + '}'
  else
    Result := '{' + ALabels + ',' + AExtra + '}';
end;

function Braces(const ALabels: string): string;
begin
  if ALabels.IsEmpty then
    Result := ''
  else
    Result := '{' + ALabels + '}';
end;

{$IFDEF LINUX}
function ResidentMemoryBytes: Int64;
var
  LHandle: THandle;
  LBuffer: TBytes;
  LRead: Integer;
  LParts: TArray<string>;
begin
  // /proc/self/statm: tamanho total e residente, em páginas de 4 KB.
  // Os arquivos de /proc dizem ter tamanho zero, então não dá para usar
  // TStringList.LoadFromFile: lemos direto, até o arquivo acabar.
  Result := 0;
  LHandle := FileOpen('/proc/self/statm', fmOpenRead);
  if LHandle = THandle(-1) then
    Exit;
  try
    SetLength(LBuffer, 256);
    LRead := FileRead(LHandle, LBuffer[0], Length(LBuffer));
    if LRead <= 0 then
      Exit;
    LParts := TEncoding.ASCII.GetString(LBuffer, 0, LRead).Trim.Split([' ']);
    if Length(LParts) > 1 then
      Result := StrToInt64Def(LParts[1], 0) * 4096;
  finally
    FileClose(LHandle);
  end;
end;
{$ENDIF}

class function TMetrics.Render: string;
var
  LBuilder: TStringBuilder;
  LNames: TArray<string>;
  LName, LKey: string;
  LFamily: TFamily;
  LHistogram: THistogram;
  I: Integer;
begin
  LBuilder := TStringBuilder.Create;
  GLock.Enter;
  try
    LNames := GFamilies.Keys.ToArray;
    TArray.Sort<string>(LNames);
    for LName in LNames do
    begin
      LFamily := GFamilies[LName];
      LBuilder.AppendLine('# HELP ' + LName + ' ' + LFamily.Help);
      if LFamily.IsHistogram then
      begin
        LBuilder.AppendLine('# TYPE ' + LName + ' histogram');
        for LKey in LFamily.Histograms.Keys do
        begin
          LHistogram := LFamily.Histograms[LKey];
          for I := 0 to High(BUCKETS) do
            LBuilder.AppendLine(LName + '_bucket' + WithLabel(LKey, 'le="' + Num(BUCKETS[I]) + '"') +
              ' ' + LHistogram.Counts[I].ToString);
          LBuilder.AppendLine(LName + '_bucket' + WithLabel(LKey, 'le="+Inf"') + ' ' + LHistogram.Count.ToString);
          LBuilder.AppendLine(LName + '_sum' + Braces(LKey) + ' ' + Num(LHistogram.Sum));
          LBuilder.AppendLine(LName + '_count' + Braces(LKey) + ' ' + LHistogram.Count.ToString);
        end;
      end
      else
      begin
        LBuilder.AppendLine('# TYPE ' + LName + ' counter');
        for LKey in LFamily.Counters.Keys do
          LBuilder.AppendLine(LName + Braces(LKey) + ' ' + LFamily.Counters[LKey].ToString);
      end;
    end;
  finally
    GLock.Leave;
  end;
  try
    LBuilder.AppendLine('# HELP process_start_time_seconds Início do processo, em segundos desde 1970.');
    LBuilder.AppendLine('# TYPE process_start_time_seconds gauge');
    LBuilder.AppendLine('process_start_time_seconds ' +
      DateTimeToUnix(TTimeZone.Local.ToUniversalTime(GStartTime)).ToString);
{$IFDEF LINUX}
    LBuilder.AppendLine('# HELP process_resident_memory_bytes Memória ocupada pelo processo.');
    LBuilder.AppendLine('# TYPE process_resident_memory_bytes gauge');
    LBuilder.AppendLine('process_resident_memory_bytes ' + ResidentMemoryBytes.ToString);
{$ENDIF}
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function IsNumeric(const AValue: string): Boolean;
var
  LChar: Char;
begin
  Result := not AValue.IsEmpty;
  for LChar in AValue do
    if not CharInSet(LChar, ['0'..'9']) then
      Exit(False);
end;

function RouteTemplate(const APath: string): string;
var
  LParts: TArray<string>;
  I: Integer;
begin
  LParts := APath.Split(['/']);
  for I := 0 to High(LParts) do
    if IsNumeric(LParts[I]) then
      LParts[I] := ':id'
    // O código do ingresso não é número: /tickets/ABC234XYZ9 -> /tickets/:code
    else if (I > 0) and SameText(LParts[I - 1], 'tickets') and not LParts[I].IsEmpty then
      LParts[I] := ':code';
  Result := string.Join('/', LParts);
end;

procedure GetMetrics(Req: THorseRequest; Res: THorseResponse);
begin
  Res.ContentType('text/plain; version=0.0.4; charset=utf-8').Send(TMetrics.Render);
end;

procedure RegisterMetricsEndpoint;
begin
  THorse.Get('/metrics', GetMetrics);
end;

initialization
  GLock := TCriticalSection.Create;
  GFamilies := TObjectDictionary<string, TFamily>.Create([doOwnsValues]);
  GStartTime := Now;

finalization
  GFamilies.Free;
  GLock.Free;

end.
