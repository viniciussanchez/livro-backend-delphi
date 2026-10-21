unit TicketApi.Migrations;

{ Histórico da estrutura do banco da ticket-api. }

interface

uses
  Platform.Migrations;

function Migrations: TArray<TMigration>;

implementation

function Migrations: TArray<TMigration>;
begin
  Result := [
    TMigration.New(1, 'Estoque de lotes, reservas e ingressos', [
      'create table batch_inventory (' +
      '  id integer primary key,' +
      '  event_id integer not null,' +
      '  price numeric(10,2) not null check (price >= 0),' +
      '  quantity integer not null check (quantity > 0),' +
      '  sold integer not null default 0,' +
      '  sales_start timestamp not null,' +
      '  sales_end timestamp not null,' +
      '  updated_at timestamp not null,' +
      // Última linha de defesa: mesmo com um bug no código,
      // o banco recusa vender mais do que existe.
      '  constraint ck_batch_inventory_sold check (sold >= 0 and sold <= quantity)' +
      ')',

      'create table reservation (' +
      '  id integer generated always as identity primary key,' +
      '  customer_id integer not null,' +
      '  batch_id integer not null references batch_inventory (id),' +
      '  event_id integer not null,' +
      '  quantity integer not null check (quantity > 0),' +
      '  unit_price numeric(10,2) not null,' +
      '  total numeric(10,2) not null,' +
      '  status varchar(10) not null check (status in (''ACTIVE'', ''CANCELLED'')),' +
      '  created_at timestamp not null,' +
      '  cancelled_at timestamp' +
      ')',
      'create index ix_reservation_customer on reservation (customer_id)',

      'create table ticket (' +
      '  id integer generated always as identity primary key,' +
      '  reservation_id integer not null references reservation (id),' +
      '  code varchar(10) not null,' +
      '  status varchar(10) not null check (status in (''VALID'', ''USED'', ''CANCELLED'')),' +
      '  checked_in_at timestamp' +
      ')',
      'create unique index ux_ticket_code on ticket (code)',
      'create index ix_ticket_reservation on ticket (reservation_id)'
    ])
  ];
end;

end.
