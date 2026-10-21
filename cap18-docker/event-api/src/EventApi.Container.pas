unit EventApi.Container;

{ Composition root: o único lugar que sabe quais implementações
  concretas estão em uso. }

interface

uses
  EventApi.Service.Category,
  EventApi.Service.Venue,
  EventApi.Service.Event;

const
  EVENT_DB = 'event_db';

function CategoryService: ICategoryService;
function VenueService: IVenueService;
function EventService: IEventService;

implementation

uses
  Platform.Database,
  EventApi.Repository.Category.FireDAC,
  EventApi.Repository.Venue.FireDAC,
  EventApi.Repository.Event.FireDAC,
  EventApi.Repository.Batch.FireDAC;

function CategoryService: ICategoryService;
begin
  Result := TCategoryService.Create(
    TCategoryRepositoryFireDAC.Create(TDatabase.NewSession(EVENT_DB)));
end;

function VenueService: IVenueService;
begin
  Result := TVenueService.Create(
    TVenueRepositoryFireDAC.Create(TDatabase.NewSession(EVENT_DB)));
end;

function EventService: IEventService;
var
  LSession: IDbSession;
begin
  // Os quatro repositórios compartilham a mesma sessão:
  // uma única conexão do pool atende a requisição inteira.
  LSession := TDatabase.NewSession(EVENT_DB);
  Result := TEventService.Create(
    TEventRepositoryFireDAC.Create(LSession),
    TBatchRepositoryFireDAC.Create(LSession),
    TVenueRepositoryFireDAC.Create(LSession),
    TCategoryRepositoryFireDAC.Create(LSession));
end;

end.
