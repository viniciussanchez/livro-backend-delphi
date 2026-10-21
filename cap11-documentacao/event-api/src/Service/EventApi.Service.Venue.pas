unit EventApi.Service.Venue;

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Venue,
  EventApi.DTO.Venue,
  EventApi.Repository.Venue;

type
  IVenueService = interface
    ['{7F2B6E04-C1D9-4A35-8B70-D46E92A1C5F8}']
    function FindAll(const ACity: string): TObjectList<TVenue>;
    function FindById(const AId: Integer): TVenue;
    function Add(const ARequest: TVenueRequest): TVenue;
  end;

  TVenueService = class(TInterfacedObject, IVenueService)
  private
    FRepository: IVenueRepository;
    procedure Validate(const ARequest: TVenueRequest);
  public
    constructor Create(const ARepository: IVenueRepository);
    function FindAll(const ACity: string): TObjectList<TVenue>;
    function FindById(const AId: Integer): TVenue;
    function Add(const ARequest: TVenueRequest): TVenue;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  Platform.Exceptions,
  Platform.Validation;

constructor TVenueService.Create(const ARepository: IVenueRepository);
begin
  inherited Create;
  FRepository := ARepository;
end;

procedure TVenueService.Validate(const ARequest: TVenueRequest);
var
  LValidation: TValidation;
begin
  LValidation.Check(not ARequest.Name.IsEmpty, 'name', 'Informe o nome do local.');
  LValidation.Check(not ARequest.Address.IsEmpty, 'address', 'Informe o endereço do local.');
  LValidation.Check(not ARequest.City.IsEmpty, 'city', 'Informe a cidade do local.');
  LValidation.Check(TRegEx.IsMatch(ARequest.State, '^[A-Z]{2}$'), 'state',
    'Informe a UF do local com duas letras, por exemplo MG.');
  LValidation.Check(ARequest.Capacity > 0, 'capacity', 'A capacidade do local deve ser maior que zero.');
  LValidation.RaiseIfInvalid;
end;

function TVenueService.FindAll(const ACity: string): TObjectList<TVenue>;
begin
  Result := FRepository.FindAll(ACity.Trim);
end;

function TVenueService.FindById(const AId: Integer): TVenue;
begin
  Result := FRepository.FindById(AId);
  if not Assigned(Result) then
    raise ENotFoundException.Create('Local não encontrado.');
end;

function TVenueService.Add(const ARequest: TVenueRequest): TVenue;
begin
  Validate(ARequest);

  Result := TVenue.Create;
  try
    Result.Name := ARequest.Name;
    Result.Address := ARequest.Address;
    Result.City := ARequest.City;
    Result.State := ARequest.State;
    Result.Capacity := ARequest.Capacity;
    FRepository.Insert(Result);
  except
    Result.Free;
    raise;
  end;
end;

end.
