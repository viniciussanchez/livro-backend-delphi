unit Gateway.RateLimit;

{ Limite de tentativas por endereço, em janela fixa.

  Cada endereço tem direito a MaxRequests requisições a cada WindowSeconds.
  A janela começa na primeira requisição; quando ela termina, o contador
  zera. É o algoritmo mais simples que resolve o problema que temos:
  impedir que alguém fique testando senhas no POST /auth/token. }

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  Horse,
  Horse.Commons;

type
  TFixedWindowLimiter = class
  private
    type
      TWindow = record
        StartedAt: TDateTime;
        Count: Integer;
      end;
  private
    FMaxRequests: Integer;
    FWindowSeconds: Integer;
    FWindows: TDictionary<string, TWindow>;
    FLock: TCriticalSection;
    procedure RemoveExpired(const ANow: TDateTime);
  public
    constructor Create(const AMaxRequests, AWindowSeconds: Integer);
    destructor Destroy; override;
    // Conta mais uma requisição de AKey. Devolve False se passou do limite;
    // nesse caso, ARetryAfter diz em quantos segundos a janela reabre.
    function TryAcquire(const AKey: string; out ARetryAfter: Integer): Boolean;
  end;

// Middleware: aplica o limite só ao login. Configure antes com ConfigureLoginLimit.
procedure ConfigureLoginLimit(const AMaxRequests, AWindowSeconds: Integer);
procedure LoginRateLimit(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

uses
  System.DateUtils,
  System.Math,
  Platform.Exceptions;

var
  GLoginLimiter: TFixedWindowLimiter;

{ TFixedWindowLimiter }

constructor TFixedWindowLimiter.Create(const AMaxRequests, AWindowSeconds: Integer);
begin
  inherited Create;
  FMaxRequests := AMaxRequests;
  FWindowSeconds := AWindowSeconds;
  FWindows := TDictionary<string, TWindow>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TFixedWindowLimiter.Destroy;
begin
  FLock.Free;
  FWindows.Free;
  inherited;
end;

procedure TFixedWindowLimiter.RemoveExpired(const ANow: TDateTime);
var
  LExpired: TList<string>;
  LPair: TPair<string, TWindow>;
  LKey: string;
begin
  // Sem esta faxina, o dicionário cresceria com cada endereço que já
  // passou por aqui, para sempre.
  LExpired := TList<string>.Create;
  try
    for LPair in FWindows do
      if SecondsBetween(ANow, LPair.Value.StartedAt) >= FWindowSeconds then
        LExpired.Add(LPair.Key);
    for LKey in LExpired do
      FWindows.Remove(LKey);
  finally
    LExpired.Free;
  end;
end;

function TFixedWindowLimiter.TryAcquire(const AKey: string; out ARetryAfter: Integer): Boolean;
var
  LNow: TDateTime;
  LWindow: TWindow;
begin
  ARetryAfter := 0;
  LNow := Now;
  // Várias requisições chegam ao mesmo tempo, em threads diferentes.
  FLock.Enter;
  try
    RemoveExpired(LNow);
    if not FWindows.TryGetValue(AKey, LWindow) then
    begin
      LWindow.StartedAt := LNow;
      LWindow.Count := 0;
    end;
    Inc(LWindow.Count);
    FWindows.AddOrSetValue(AKey, LWindow);
    Result := LWindow.Count <= FMaxRequests;
    if not Result then
      ARetryAfter := Max(1, FWindowSeconds - SecondsBetween(LNow, LWindow.StartedAt));
  finally
    FLock.Leave;
  end;
end;

{ Middleware }

procedure ConfigureLoginLimit(const AMaxRequests, AWindowSeconds: Integer);
begin
  FreeAndNil(GLoginLimiter);
  GLoginLimiter := TFixedWindowLimiter.Create(AMaxRequests, AWindowSeconds);
end;

procedure LoginRateLimit(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LRetryAfter: Integer;
begin
  if (Req.MethodType = mtPost) and SameText(Req.PathInfo, '/auth/token') and
     not GLoginLimiter.TryAcquire(Req.RawWebRequest.RemoteAddr, LRetryAfter) then
    raise ETooManyRequestsException.Create(Format(
      'Muitas tentativas de login. Tente de novo em %d segundos.', [LRetryAfter]), LRetryAfter);
  Next;
end;

initialization
  GLoginLimiter := nil;

finalization
  GLoginLimiter.Free;

end.
