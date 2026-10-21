unit EventApi.Repository.Batch;

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Batch;

type
  IBatchRepository = interface
    ['{4D6F0A38-B92E-4C71-8D53-E0A1F7C2964B}']
    function FindByEvent(const AEventId: Integer): TObjectList<TBatch>;
    // Soma das quantidades de todos os lotes do evento.
    function TotalQuantity(const AEventId: Integer): Integer;
    procedure Insert(const ABatch: TBatch);
  end;

implementation

end.
