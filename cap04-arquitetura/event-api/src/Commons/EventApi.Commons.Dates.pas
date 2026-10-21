unit EventApi.Commons.Dates;

interface

function TryParseISODate(const AValue: string; out ADate: TDate): Boolean;
function FormatISODate(const ADate: TDate): string;

implementation

uses
  System.SysUtils;

function TryParseISODate(const AValue: string; out ADate: TDate): Boolean;
var
  LFormat: TFormatSettings;
  LDateTime: TDateTime;
begin
  LFormat := TFormatSettings.Create;
  LFormat.DateSeparator := '-';
  LFormat.ShortDateFormat := 'yyyy-mm-dd';
  Result := TryStrToDate(AValue, LDateTime, LFormat);
  if Result then
    ADate := LDateTime;
end;

function FormatISODate(const ADate: TDate): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADate);
end;

end.
