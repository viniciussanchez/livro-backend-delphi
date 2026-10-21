unit EventApi.Container;

{ Composition root: o único lugar que sabe quais implementações
  concretas estão em uso. Trocar o repositório em memória pelo
  PostgreSQL, no capítulo 5, vai mexer só aqui. }

interface

uses
  EventApi.Service.Event;

function EventService: IEventService;

implementation

uses
  EventApi.Repository.Event,
  EventApi.Repository.Event.Memory;

var
  // Em memória, o repositório precisa ser único para a aplicação inteira;
  // senão cada requisição enxergaria uma lista diferente.
  GEventRepository: IEventRepository;

function EventService: IEventService;
begin
  Result := TEventService.Create(GEventRepository);
end;

initialization
  GEventRepository := TEventRepositoryMemory.Create;

finalization
  GEventRepository := nil;

end.
