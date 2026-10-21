unit EventApi.Repository.Event;

{ Contrato da camada de dados. O Service conhece apenas esta interface;
  quem a implementa (memória agora, PostgreSQL no capítulo 5) é um detalhe. }

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Event;

type
  IEventRepository = interface
    ['{8F1D2C47-3B6A-4E59-9C0D-71A2B5E4F368}']
    // Quem chama é dono da lista e dos objetos retornados.
    function FindAll(const ACity: string): TObjectList<TEvent>;
    // Retorna nil quando não encontra. Quem chama é dono do objeto.
    function FindById(const AId: Integer): TEvent;
    // Grava o evento e preenche o Id gerado.
    procedure Insert(const AEvent: TEvent);
    // Retorna False quando o evento não existe.
    function Delete(const AId: Integer): Boolean;
  end;

implementation

end.
