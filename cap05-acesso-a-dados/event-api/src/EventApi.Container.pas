unit EventApi.Container;

{ Composition root: o único lugar que sabe quais implementações
  concretas estão em uso. }

interface

uses
  EventApi.Service.Event;

const
  EVENT_DB = 'event_db';

function EventService: IEventService;

implementation

uses
  Platform.Database,
  EventApi.Repository.Event.FireDAC;

function EventService: IEventService;
var
  LSession: IDbSession;
begin
  // Uma sessão por requisição: ela pega uma conexão do pool e a devolve
  // quando o Service (e, com ele, o repositório) deixa de ser usado.
  LSession := TDatabase.NewSession(EVENT_DB);
  Result := TEventService.Create(TEventRepositoryFireDAC.Create(LSession));
end;

end.
