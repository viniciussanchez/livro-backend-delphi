set client_encoding = 'UTF8';
-- A única mudança no banco do sistema antigo (capítulo 22).
--
-- Uma tabela de fila e um gatilho: toda vez que um cliente é incluído ou
-- alterado, por qualquer tela ou rotina do sistema antigo, uma linha entra
-- na fila. O serviço legacy-sync lê a fila e leva o cliente para a
-- customer-api. Nenhuma linha de código Delphi do sistema antigo muda.

create table SYNC_FILA (
  ID                 bigint generated always as identity primary key,
  TABELA             varchar(30) not null,
  CHAVE              integer not null,
  CRIADO_EM          timestamp not null default now(),
  -- P = pendente, O = ok, R = rejeitado (precisa de correção no sistema antigo)
  STATUS             char(1) not null default 'P',
  TENTATIVAS         integer not null default 0,
  PROXIMA_TENTATIVA  timestamp not null default now(),
  PROCESSADO_EM      timestamp,
  ERRO               varchar(1000)
);

-- A fila só é lida pelas linhas pendentes; o índice parcial fica pequeno
-- mesmo com milhões de linhas já processadas.
create index IX_SYNC_FILA_PENDENTE on SYNC_FILA (PROXIMA_TENTATIVA, ID) where STATUS = 'P';
create index IX_SYNC_FILA_CHAVE on SYNC_FILA (TABELA, CHAVE);

create function FN_SYNC_CLIENTE() returns trigger as $$
begin
  -- Só anotamos QUEM mudou. O QUE mudou, o serviço lê do próprio CLIENTE
  -- na hora de enviar, e assim sempre envia o estado mais recente.
  insert into SYNC_FILA (TABELA, CHAVE) values ('CLIENTE', new.COD_CLI);
  return new;
end $$ language plpgsql;

create trigger TG_SYNC_CLIENTE
  after insert or update on CLIENTE
  for each row execute function FN_SYNC_CLIENTE();
