unit HelloHorse.Middleware.RequestLog;

interface

uses
  System.SysUtils,
  Horse;

procedure RequestLog(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

uses
  System.Diagnostics;

var
  GConsoleLock: TObject;

procedure RequestLog(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LStopwatch: TStopwatch;
begin
  LStopwatch := TStopwatch.StartNew;
  try
    Next();
  finally
    LStopwatch.Stop;
    // O Horse atende cada requisição em uma thread.
    // O lock evita que duas linhas de log se misturem no console.
    TMonitor.Enter(GConsoleLock);
    try
      Writeln(Format('%s %s %s -> %d (%d ms)',
        [FormatDateTime('hh:nn:ss', Now), Req.Method, Req.PathInfo,
         Res.Status, LStopwatch.ElapsedMilliseconds]));
    finally
      TMonitor.Exit(GConsoleLock);
    end;
  end;
end;

initialization
  GConsoleLock := TObject.Create;

finalization
  GConsoleLock.Free;

end.
