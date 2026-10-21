unit CustomerApi.Migrations;

{ Histórico da estrutura do banco da customer-api. }

interface

uses
  Platform.Migrations;

function Migrations: TArray<TMigration>;

implementation

function Migrations: TArray<TMigration>;
begin
  Result := [
    TMigration.New(1, 'Cria a tabela de participantes', [
      'create table customer (' +
      '  id integer generated always as identity primary key,' +
      '  name varchar(150) not null,' +
      '  cpf char(11),' +
      '  email varchar(254),' +
      '  phone varchar(11),' +
      '  birth_date date,' +
      '  created_at timestamp not null,' +
      '  updated_at timestamp not null,' +
      '  anonymized_at timestamp' +
      ')',
      // Índices únicos parciais: valem apenas para participantes ativos.
      // Assim, quem foi anonimizado não impede um novo cadastro com o mesmo e-mail.
      'create unique index ux_customer_cpf on customer (cpf) where anonymized_at is null',
      'create unique index ux_customer_email on customer (lower(email)) where anonymized_at is null'
    ])
  ];
end;

end.
