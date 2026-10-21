unit EventApi.Migrations;

{ Histórico da estrutura do banco da event-api.
  Uma migração aplicada nunca é alterada: mudanças entram como uma nova versão. }

interface

uses
  Platform.Migrations;

function Migrations: TArray<TMigration>;

implementation

function Migrations: TArray<TMigration>;
begin
  Result := [
    TMigration.New(1, 'Cria a tabela de eventos', [
      'create table event (' +
      '  id integer generated always as identity primary key,' +
      '  name varchar(150) not null,' +
      '  city varchar(100) not null,' +
      '  event_date date not null,' +
      '  capacity integer not null check (capacity > 0),' +
      '  created_at timestamp not null default now()' +
      ')',
      'create index ix_event_city on event (lower(city))'
    ])
  ];
end;

end.
