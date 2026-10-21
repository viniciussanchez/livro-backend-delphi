unit EventApi.Repository.Category.FireDAC;

interface

uses
  System.Generics.Collections,
  Platform.Repository,
  EventApi.Entity.Category,
  EventApi.Repository.Category;

type
  TCategoryRepositoryFireDAC = class(TFireDACRepository, ICategoryRepository)
  public
    function FindAll: TObjectList<TCategory>;
    function FindById(const AId: Integer): TCategory;
    function ExistsByName(const AName: string): Boolean;
    procedure Insert(const ACategory: TCategory);
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.Comp.Client,
  Platform.Exceptions;

function ToEntity(const AQuery: TFDQuery): TCategory;
begin
  Result := TCategory.Create;
  Result.Id := AQuery.FieldByName('id').AsInteger;
  Result.Name := AQuery.FieldByName('name').AsString;
end;

function TCategoryRepositoryFireDAC.FindAll: TObjectList<TCategory>;
var
  LQuery: TFDQuery;
begin
  Result := TObjectList<TCategory>.Create(True);
  try
    LQuery := NewQuery('select id, name from category order by name');
    try
      LQuery.Open;
      while not LQuery.Eof do
      begin
        Result.Add(ToEntity(LQuery));
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TCategoryRepositoryFireDAC.FindById(const AId: Integer): TCategory;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := NewQuery('select id, name from category where id = :id');
  try
    LQuery.ParamByName('id').AsInteger := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := ToEntity(LQuery);
  finally
    LQuery.Free;
  end;
end;

function TCategoryRepositoryFireDAC.ExistsByName(const AName: string): Boolean;
begin
  Result := Connection.ExecSQLScalar(
    'select count(*) from category where lower(name) = lower(:name)', [AName]) > 0;
end;

procedure TCategoryRepositoryFireDAC.Insert(const ACategory: TCategory);
var
  LQuery: TFDQuery;
begin
  LQuery := NewQuery('insert into category (name) values (:name) returning id');
  try
    LQuery.ParamByName('name').AsString := ACategory.Name;
    try
      LQuery.Open;
    except
      // O índice único é a última linha de defesa: se duas requisições
      // cadastrarem o mesmo nome ao mesmo tempo, uma delas cai aqui.
      on E: EFDDBEngineException do
        if E.Kind = ekUKViolated then
          raise EConflictException.Create('Já existe uma categoria com este nome.')
        else
          raise;
    end;
    ACategory.Id := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

end.
