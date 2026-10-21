unit EventApi.Repository.Venue;

interface

uses
  System.Generics.Collections,
  EventApi.Entity.Venue;

type
  IVenueRepository = interface
    ['{9C4A1E72-3F5B-4D80-A6B9-17E2C8D05F63}']
    function FindAll(const ACity: string): TObjectList<TVenue>;
    // Retorna nil quando não encontra. Quem chama é dono do objeto.
    function FindById(const AId: Integer): TVenue;
    procedure Insert(const AVenue: TVenue);
  end;

implementation

end.
