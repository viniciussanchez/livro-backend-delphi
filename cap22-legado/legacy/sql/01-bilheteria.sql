set client_encoding = 'UTF8';
-- O banco do sistema antigo da bilheteria (capítulo 22).
--
-- Representa um sistema cliente-servidor típico: um executável Delphi na
-- máquina de cada caixa, todos gravando direto neste banco. O esquema está
-- como "sempre esteve": nomes em maiúsculas e em português, datas guardadas
-- como texto, CPF com ou sem máscara, conforme quem digitou.
--
-- Não vamos mudar nada aqui, a não ser o que está em 03-sincronizacao.sql.

create sequence GEN_CLIENTE;

create table CLIENTE (
  COD_CLI      integer primary key default nextval('GEN_CLIENTE'),
  NOME         varchar(60) not null,
  CPF          varchar(14),
  FONE         varchar(20),
  EMAIL        varchar(80),
  DT_NASC      varchar(10),               -- 'dd/mm/aaaa', em texto
  SITUACAO     char(1) not null default 'A', -- A = ativo, I = inativo
  DT_CADASTRO  timestamp not null default now()
);

create table VENDA (
  COD_VENDA    integer generated always as identity primary key,
  COD_CLI      integer not null references CLIENTE (COD_CLI),
  DESCRICAO    varchar(100) not null,
  VALOR        numeric(10,2) not null,
  DT_VENDA     timestamp not null default now()
);
