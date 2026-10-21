unit EventApi.Service.Event;

{ Regras de negócio dos eventos. Não conhece HTTP nem banco de dados:
  recebe DTOs, aplica as regras e conversa com o repositório pela interface. }

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Event,
  EventApi.DTO.Event,
  EventApi.Repository.Event;

type
  IEventService = interface
    ['{C24E7A19-5D83-4B0F-A6E2-9F31D8B07C54}']
    function FindAll(const ACity: string): TObjectList<TEvent>;
    function FindById(const AId: Integer): TEvent;
    function Add(const ARequest: TEventRequest): TEvent;
    procedure Delete(const AId: Integer);
  end;

  TEventService = class(TInterfacedObject, IEventService)
  private
    FRepository: IEventRepository;
    procedure Validate(const ARequest: TEventRequest; out AEventDate: TDate);
  public
    constructor Create(const ARepository: IEventRepository);
    function FindAll(const ACity: string): TObjectList<TEvent>;
    function FindById(const AId: Integer): TEvent;
    function Add(const ARequest: TEventRequest): TEvent;
    procedure Delete(const AId: Integer);
  end;

implementation

uses
  System.SysUtils,
  Platform.Exceptions,
  Platform.Dates;

constructor TEventService.Create(const ARepository: IEventRepository);
begin
  inherited Create;
  FRepository := ARepository;
end;

procedure TEventService.Validate(const ARequest: TEventRequest; out AEventDate: TDate);
begin
  if ARequest.Name.IsEmpty then
    raise EValidationException.Create('Informe o nome do evento.');

  if ARequest.City.IsEmpty then
    raise EValidationException.Create('Informe a cidade do evento.');

  if not TryParseISODate(ARequest.EventDate, AEventDate) then
    raise EValidationException.Create('Informe a data do evento no formato aaaa-mm-dd.');

  if ARequest.Capacity <= 0 then
    raise EValidationException.Create('A capacidade do evento deve ser maior que zero.');
end;

function TEventService.FindAll(const ACity: string): TObjectList<TEvent>;
begin
  Result := FRepository.FindAll(ACity.Trim);
end;

function TEventService.FindById(const AId: Integer): TEvent;
begin
  Result := FRepository.FindById(AId);
  if not Assigned(Result) then
    raise ENotFoundException.Create('Evento não encontrado.');
end;

function TEventService.Add(const ARequest: TEventRequest): TEvent;
var
  LEventDate: TDate;
begin
  Validate(ARequest, LEventDate);

  Result := TEvent.Create;
  try
    Result.Name := ARequest.Name;
    Result.City := ARequest.City;
    Result.EventDate := LEventDate;
    Result.Capacity := ARequest.Capacity;
    FRepository.Insert(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TEventService.Delete(const AId: Integer);
begin
  if not FRepository.Delete(AId) then
    raise ENotFoundException.Create('Evento não encontrado.');
end;

end.
