unit EventApi.DTO.Category;

interface

uses
  System.JSON,
  System.Generics.Collections,
  EventApi.Entity.Category;

type
  TCategoryRequest = record
    Name: string;
    class function FromJSON(const AJSON: TJSONObject): TCategoryRequest; static;
  end;

  TCategoryMapper = class
  public
    class function ToJSON(const ACategory: TCategory): TJSONObject; static;
    class function ToJSONArray(const ACategories: TObjectList<TCategory>): TJSONArray; static;
  end;

implementation

uses
  System.SysUtils;

class function TCategoryRequest.FromJSON(const AJSON: TJSONObject): TCategoryRequest;
begin
  Result.Name := AJSON.GetValue<string>('name', '').Trim;
end;

class function TCategoryMapper.ToJSON(const ACategory: TCategory): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(ACategory.Id));
  Result.AddPair('name', ACategory.Name);
end;

class function TCategoryMapper.ToJSONArray(const ACategories: TObjectList<TCategory>): TJSONArray;
var
  LCategory: TCategory;
begin
  Result := TJSONArray.Create;
  for LCategory in ACategories do
    Result.AddElement(ToJSON(LCategory));
end;

end.
