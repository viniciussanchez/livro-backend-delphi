unit EventApi.Repository.Event.Memory;

{ Implementação em memória do repositório de eventos.
  É a mesma ideia do armazenamento do capítulo 3, agora atrás de uma interface. }

interface

uses
  System.SyncObjs,
  System.Generics.Collections,
  EventApi.Entity.Event,
  EventApi.Repository.Event;

type
  TEventRepositoryMemory = class(TInterfacedObject, IEventRepository)
  private
    FEvents: TObjectList<TEvent>;
    FLock: TCriticalSection;
    FNextId: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function FindAll(const ACity: string): TObjectList<TEvent>;
    function FindById(const AId: Integer): TEvent;
    procedure Insert(const AEvent: TEvent);
    function Delete(const AId: Integer): Boolean;
  end;

implementation

uses
  System.SysUtils;

constructor TEventRepositoryMemory.Create;
begin
  inherited Create;
  FEvents := TObjectList<TEvent>.Create(True);
  FLock := TCriticalSection.Create;
  FNextId := 1;
end;

destructor TEventRepositoryMemory.Destroy;
begin
  FLock.Free;
  FEvents.Free;
  inherited;
end;

function TEventRepositoryMemory.FindAll(const ACity: string): TObjectList<TEvent>;
var
  LEvent: TEvent;
begin
  Result := TObjectList<TEvent>.Create(True);
  try
    FLock.Enter;
    try
      for LEvent in FEvents do
        if ACity.IsEmpty or SameText(LEvent.City, ACity) then
          Result.Add(LEvent.Clone);
    finally
      FLock.Leave;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TEventRepositoryMemory.FindById(const AId: Integer): TEvent;
var
  LEvent: TEvent;
begin
  Result := nil;
  FLock.Enter;
  try
    for LEvent in FEvents do
      if LEvent.Id = AId then
        Exit(LEvent.Clone);
  finally
    FLock.Leave;
  end;
end;

procedure TEventRepositoryMemory.Insert(const AEvent: TEvent);
begin
  FLock.Enter;
  try
    AEvent.Id := FNextId;
    Inc(FNextId);
    // A lista guarda uma cópia: o objeto recebido continua sendo de quem chamou.
    FEvents.Add(AEvent.Clone);
  finally
    FLock.Leave;
  end;
end;

function TEventRepositoryMemory.Delete(const AId: Integer): Boolean;
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

end.
