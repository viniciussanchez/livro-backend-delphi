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
    ]),

    // Ainda em desenvolvimento, sem dados a preservar: a tabela de eventos
    // é recriada no novo formato. Em produção, faríamos a migração dos dados.
    TMigration.New(2, 'Categorias, locais, lotes e o novo formato de eventos', [
      'drop table event',

      'create table category (' +
      '  id integer generated always as identity primary key,' +
      '  name varchar(60) not null' +
      ')',
      'create unique index ux_category_name on category (lower(name))',

      'create table venue (' +
      '  id integer generated always as identity primary key,' +
      '  name varchar(150) not null,' +
      '  address varchar(200) not null,' +
      '  city varchar(100) not null,' +
      '  state char(2) not null,' +
      '  capacity integer not null check (capacity > 0)' +
      ')',
      'create index ix_venue_city on venue (lower(city))',

      'create table event (' +
      '  id integer generated always as identity primary key,' +
      '  name varchar(150) not null,' +
      '  description text not null default '''',' +
      '  category_id integer not null references category (id),' +
      '  venue_id integer not null references venue (id),' +
      '  start_at timestamp not null,' +
      '  status varchar(10) not null check (status in (''DRAFT'', ''PUBLISHED'', ''CANCELLED'')),' +
      '  created_at timestamp not null default now()' +
      ')',
      'create index ix_event_start_at on event (start_at)',

      'create table ticket_batch (' +
      '  id integer generated always as identity primary key,' +
      '  event_id integer not null references event (id),' +
      '  name varchar(60) not null,' +
      '  price numeric(10,2) not null check (price >= 0),' +
      '  quantity integer not null check (quantity > 0),' +
      '  sales_start timestamp not null,' +
      '  sales_end timestamp not null,' +
      '  check (sales_start < sales_end)' +
      ')',
      'create index ix_ticket_batch_event on ticket_batch (event_id)'
    ]),

    TMigration.New(3, 'Categorias iniciais', [
      'insert into category (name) values ' +
      '(''Show''), (''Palestra''), (''Teatro''), (''Esporte''), (''Workshop'')'
    ])
  ];
end;

end.
