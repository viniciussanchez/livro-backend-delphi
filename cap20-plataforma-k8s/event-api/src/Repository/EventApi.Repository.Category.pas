unit EventApi.Repository.Category;

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Category;

type
  ICategoryRepository = interface
    ['{2B7E4D91-6A0C-4F38-8E15-93C7A2D6B04F}']
    function FindAll: TObjectList<TCategory>;
    // Retorna nil quando não encontra. Quem chama é dono do objeto.
    function FindById(const AId: Integer): TCategory;
    function ExistsByName(const AName: string): Boolean;
    procedure Insert(const ACategory: TCategory);
  end;

implementation

end.
