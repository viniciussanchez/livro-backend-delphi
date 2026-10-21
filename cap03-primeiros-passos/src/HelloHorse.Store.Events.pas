unit HelloHorse.Store.Events;

{ Armazenamento em memória dos eventos.
  Serve apenas para o capítulo 3: no capítulo 5 os dados passam
  a ser gravados no PostgreSQL. }

interface

uses
  System.SysUtils,
  System.JSON,
  System.SyncObjs,
  System.Generics.Collections;

type
  TEvent = record
    Id: Integer;
    Name: string;
    City: string;
    EventDate: TDate;
    Capacity: Integer;
    function ToJSON: TJSONObject;
  end;

  TEventStore = class
  private
    FEvents: TList<TEvent>;
    FLock: TCriticalSection;
    FNextId: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AName, ACity: string; const AEventDate: TDate; const ACapacity: Integer): TEvent;
    function FindAll(const ACity: string): TArray<TEvent>;
    function TryFindById(const AId: Integer; out AEvent: TEvent): Boolean;
    function Remove(const AId: Integer): Boolean;
  end;

function EventStore: TEventStore;
function TryParseISODate(const AValue: string; out ADate: TDate): Boolean;
function FormatISODate(const ADate: TDate): string;

implementation

var
  GEventStore: TEventStore;

function EventStore: TEventStore;
begin
  Result := GEventStore;
end;

function ISOFormatSettings: TFormatSettings;
begin
  Result := TFormatSettings.Create;
  Result.DateSeparator := '-';
  Result.ShortDateFormat := 'yyyy-mm-dd';
end;

function TryParseISODate(const AValue: string; out ADate: TDate): Boolean;
var
  LDateTime: TDateTime;
begin
  Result := TryStrToDate(AValue, LDateTime, ISOFormatSettings);
  if Result then
    ADate := LDateTime;
end;

function FormatISODate(const ADate: TDate): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADate);
end;

{ TEvent }

function TEvent.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(Id));
  Result.AddPair('name', Name);
  Result.AddPair('city', City);
  Result.AddPair('eventDate', FormatISODate(EventDate));
  Result.AddPair('capacity', TJSONNumber.Create(Capacity));
end;

{ TEventStore }

constructor TEventStore.Create;
begin
  inherited Create;
  FEvents := TList<TEvent>.Create;
  FLock := TCriticalSection.Create;
  FNextId := 1;
end;

destructor TEventStore.Destroy;
begin
  FLock.Free;
  FEvents.Free;
  inherited;
end;

function TEventStore.Add(const AName, ACity: string; const AEventDate: TDate; const ACapacity: Integer): TEvent;
begin
  FLock.Enter;
  try
    Result.Id := FNextId;
    Result.Name := AName;
    Result.City := ACity;
    Result.EventDate := AEventDate;
    Result.Capacity := ACapacity;
    FEvents.Add(Result);
    Inc(FNextId);
  finally
    FLock.Leave;
  end;
end;

function TEventStore.FindAll(const ACity: string): TArray<TEvent>;
var
  LEvent: TEvent;
  LResult: TList<TEvent>;
begin
  LResult := TList<TEvent>.Create;
  try
    FLock.Enter;
    try
      for LEvent in FEvents do
        if ACity.IsEmpty or SameText(LEvent.City, ACity) then
          LResult.Add(LEvent);
    finally
      FLock.Leave;
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

function TEventStore.TryFindById(const AId: Integer; out AEvent: TEvent): Boolean;
var
  LEvent: TEvent;
begin
  Result := False;
  FLock.Enter;
  try
    for LEvent in FEvents do
      if LEvent.Id = AId then
      begin
        AEvent := LEvent;
        Exit(True);
      end;
  finally
    FLock.Leave;
  end;
end;

function TEventStore.Remove(const AId: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  FLock.Enter;
  try
    for I := 0 to Pred(FEvents.Count) do
      if FEvents[I].Id = AId then
      begin
        FEvents.Delete(I);
        Exit(True);
      end;
  finally
    FLock.Leave;
  end;
end;

initialization
  GEventStore := TEventStore.Create;

finalization
  GEventStore.Free;

end.
