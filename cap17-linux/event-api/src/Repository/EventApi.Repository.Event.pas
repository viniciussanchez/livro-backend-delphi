unit EventApi.Repository.Event;

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Event;

type
  // Filtros da listagem de eventos. Valores vazios (ou zero) não filtram.
  TEventFilter = record
    City: string;
    CategoryId: Integer;
    DateFrom: TDate;
    DateTo: TDate;
    FilterByStatus: Boolean;
    Status: TEventStatus;
  end;

  IEventRepository = interface
    ['{8F1D2C47-3B6A-4E59-9C0D-71A2B5E4F368}']
    function FindAll(const AFilter: TEventFilter): TObjectList<TEvent>;
    // Retorna nil quando não encontra. Quem chama é dono do objeto.
    function FindById(const AId: Integer): TEvent;
    procedure Insert(const AEvent: TEvent);
    procedure UpdateStatus(const AId: Integer; const AStatus: TEventStatus);
  end;

implementation

end.
