unit EventApi.Service.Category;

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Category,
  EventApi.DTO.Category,
  EventApi.Repository.Category;

type
  ICategoryService = interface
    ['{E3A9C5D1-48B7-4F02-9E6A-5B1D7C3F8A20}']
    function FindAll: TObjectList<TCategory>;
    function Add(const ARequest: TCategoryRequest): TCategory;
  end;

  TCategoryService = class(TInterfacedObject, ICategoryService)
  private
    FRepository: ICategoryRepository;
  public
    constructor Create(const ARepository: ICategoryRepository);
    function FindAll: TObjectList<TCategory>;
    function Add(const ARequest: TCategoryRequest): TCategory;
  end;

implementation

uses
  System.SysUtils,
  Platform.Exceptions;

constructor TCategoryService.Create(const ARepository: ICategoryRepository);
begin
  inherited Create;
  FRepository := ARepository;
end;

function TCategoryService.FindAll: TObjectList<TCategory>;
begin
  Result := FRepository.FindAll;
end;

function TCategoryService.Add(const ARequest: TCategoryRequest): TCategory;
begin
  if ARequest.Name.IsEmpty then
    raise EValidationException.Create('Informe o nome da categoria.');
  if ARequest.Name.Length > 60 then
    raise EValidationException.Create('O nome da categoria deve ter no máximo 60 caracteres.');
  if FRepository.ExistsByName(ARequest.Name) then
    raise EConflictException.Create('Já existe uma categoria com este nome.');

  Result := TCategory.Create;
  try
    Result.Name := ARequest.Name;
    FRepository.Insert(Result);
  except
    Result.Free;
    raise;
  end;
end;

end.
