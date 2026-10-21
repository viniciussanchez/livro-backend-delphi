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
    ]),

    // Capítulo 13: contas de acesso. As senhas são guardadas com bcrypt,
    // pela extensão pgcrypto do PostgreSQL.
    TMigration.New(2, 'Contas de acesso', [
      'create extension if not exists pgcrypto',
      'create table app_user (' +
      '  id integer generated always as identity primary key,' +
      // Só a equipe tem e-mail aqui; o participante entra com o e-mail do cadastro.
      '  email varchar(254),' +
      '  password_hash varchar(100) not null,' +
      '  role varchar(10) not null check (role in (''admin'', ''staff'', ''customer'')),' +
      '  customer_id integer references customer (id),' +
      '  created_at timestamp not null,' +
      // Participante sempre ligado a um cadastro; equipe, nunca.
      '  constraint ck_app_user_owner check ((role = ''customer'') = (customer_id is not null))' +
      ')',
      'create unique index ux_app_user_email on app_user (lower(email)) where email is not null',
      'create unique index ux_app_user_customer on app_user (customer_id) where customer_id is not null'
    ]),

    // Capítulo 22: participantes que vieram do sistema antigo guardam o
    // código que tinham lá. É por ele que a sincronização os encontra.
    TMigration.New(3, 'Código do participante no sistema antigo', [
      'alter table customer add column legacy_code integer',
      'create unique index ux_customer_legacy_code on customer (legacy_code) where legacy_code is not null'
    ])
  ];
end;

end.
