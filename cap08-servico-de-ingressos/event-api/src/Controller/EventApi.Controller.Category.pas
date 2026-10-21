unit EventApi.Controller.Category;

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Horse,
  Platform.Http,
  EventApi.Entity.Category,
  EventApi.DTO.Category,
  EventApi.Container;

// GET /categories
procedure GetCategories(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LCategories: TObjectList<TCategory>;
    begin
      LCategories := CategoryService.FindAll;
      try
        Res.Send<TJSONArray>(TCategoryMapper.ToJSONArray(LCategories));
      finally
        LCategories.Free;
      end;
    end);
end;

// POST /categories
procedure PostCategory(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LCategory: TCategory;
    begin
      LCategory := CategoryService.Add(TCategoryRequest.FromJSON(RequestBody(Req)));
      try
        Res.Status(THTTPStatus.Created).Send<TJSONObject>(TCategoryMapper.ToJSON(LCategory));
      finally
        LCategory.Free;
      end;
    end);
end;

procedure Registry;
begin
  THorse
    .Get('/categories', GetCategories)
    .Post('/categories', PostCategory);
end;

end.
