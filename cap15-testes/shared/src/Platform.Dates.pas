unit Platform.Dates;

{ Datas trafegam na API no formato ISO 8601:
  datas como 'aaaa-mm-dd' e data/hora como 'aaaa-mm-ddThh:nn:ss'. }

interface

function TryParseISODate(const AValue: string; out ADate: TDate): Boolean;
function FormatISODate(const ADate: TDate): string;

function TryParseISODateTime(const AValue: string; out ADateTime: TDateTime): Boolean;
function FormatISODateTime(const ADateTime: TDateTime): string;

implementation

uses
  System.SysUtils,
  System.DateUtils;

function TryParseISODate(const AValue: string; out ADate: TDate): Boolean;
var
  LFormat: TFormatSettings;
  LDateTime: TDateTime;
begin
  LFormat := TFormatSettings.Create;
  LFormat.DateSeparator := '-';
  LFormat.ShortDateFormat := 'yyyy-mm-dd';
  Result := (Length(AValue) = 10) and TryStrToDate(AValue, LDateTime, LFormat);
  if Result then
    ADate := LDateTime;
end;

function FormatISODate(const ADate: TDate): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADate);
end;

function TryParseISODateTime(const AValue: string; out ADateTime: TDateTime): Boolean;
begin
  // Sem fuso na entrada, o valor é usado como veio. AReturnUTC = True evita
  // que o Delphi "converta" o horário para o fuso local da máquina.
  Result := (Length(AValue) >= 16) and TryISO8601ToDate(AValue, ADateTime, True);
end;

function FormatISODateTime(const ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', ADateTime);
end;

end.
