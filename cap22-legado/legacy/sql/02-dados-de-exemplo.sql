set client_encoding = 'UTF8';
-- Dados de exemplo para o sistema antigo (capítulo 22): 2.000 clientes
-- cadastrados ao longo de anos, por caixas diferentes, sem muita validação.
-- Os problemas aparecem em proporções fixas, para o teste ser repetível:
--   CPF com máscara (metade), sem máscara (outra metade), inválido, vazio
--   e repetido; e-mail ausente, inválido ou de outra pessoa; telefone sem
--   DDD; data de nascimento impossível.

-- Calcula um CPF válido a partir de um número (só para gerar exemplos).
create or replace function cpf_exemplo(n integer) returns varchar as $$
declare
  base varchar := lpad((100000000 + n * 7919 % 800000000)::text, 9, '0');
  soma integer;
  d1 integer;
  d2 integer;
begin
  soma := 0;
  for i in 1..9 loop
    soma := soma + substr(base, i, 1)::integer * (11 - i);
  end loop;
  d1 := 11 - soma % 11;
  if d1 >= 10 then d1 := 0; end if;
  soma := 0;
  for i in 1..9 loop
    soma := soma + substr(base, i, 1)::integer * (12 - i);
  end loop;
  soma := soma + d1 * 2;
  d2 := 11 - soma % 11;
  if d2 >= 10 then d2 := 0; end if;
  return base || d1 || d2;
end $$ language plpgsql immutable;

insert into CLIENTE (COD_CLI, NOME, CPF, FONE, EMAIL, DT_NASC, DT_CADASTRO)
select
  n,
  -- Nomes em maiúsculas, como muitos sistemas antigos gravavam.
  upper((array['Ana','Bruno','Carla','Diego','Elisa','Fabio','Gabriela','Heitor','Iara','Joao',
               'Karina','Lucas','Marina','Nelson','Olivia','Paulo','Queila','Rafael','Sonia','Tiago'])[1 + n % 20]
     || ' ' ||
        (array['Silva','Souza','Oliveira','Santos','Pereira','Costa','Rodrigues','Almeida','Nunes','Lima',
               'Araujo','Fernandes','Carvalho','Gomes','Martins','Rocha','Ribeiro','Barbosa','Moreira','Teixeira'])[1 + (n / 20) % 20]),
  case
    when n % 50 = 7 then '111.111.111-11'                       -- 2%: inválido
    when n % 100 = 13 then null                                 -- 1%: vazio
    when n % 2 = 0 then regexp_replace(cpf_exemplo(n), '(\d{3})(\d{3})(\d{3})(\d{2})', '\1.\2.\3-\4')
    else cpf_exemplo(n)
  end,
  case
    when n % 10 = 3 then '9' || lpad((n * 37 % 100000000)::text, 8, '0')                -- sem DDD
    when n % 3 = 0 then '(31) 9' || lpad((n * 53 % 10000)::text, 4, '0') || '-' || lpad((n * 17 % 10000)::text, 4, '0')
    when n % 3 = 1 then '319' || lpad((n * 91 % 100000000)::text, 8, '0')
    else null
  end,
  case
    when n % 5 in (1, 2) then null                              -- 40%: sem e-mail
    when n % 100 = 45 then 'cliente' || n || '@'                -- 1%: inválido
    else ' ' || upper(substr('abcdefghijklmnopqrst', 1 + n % 20, 1)) || 'cliente' || n || '@Exemplo.com.br '
  end,
  case
    when n % 40 = 9 then '31/02/1985'                           -- data impossível
    when n % 4 = 0 then null
    else lpad((1 + n % 28)::text, 2, '0') || '/' || lpad((1 + n % 12)::text, 2, '0') || '/' || (1950 + n % 55)
  end,
  timestamp '2008-01-01' + (n || ' days')::interval
from generate_series(1, 2000) n;

-- 10 pessoas cadastradas duas vezes, com o mesmo CPF (código novo, mesmo CPF).
insert into CLIENTE (COD_CLI, NOME, CPF, FONE, EMAIL, DT_NASC)
select 2000 + k, c.NOME, c.CPF, c.FONE, null, c.DT_NASC
  from generate_series(1, 10) k
  join CLIENTE c on c.COD_CLI = 100 * k + 1;

-- 5 e-mails usados por duas pessoas diferentes (a família que divide o e-mail).
update CLIENTE set EMAIL = (select EMAIL from CLIENTE where COD_CLI = 200 * k + 4)
  from generate_series(1, 5) k
 where COD_CLI = 200 * k + 8;

select setval('GEN_CLIENTE', (select max(COD_CLI) from CLIENTE));

insert into VENDA (COD_CLI, DESCRICAO, VALOR, DT_VENDA)
select 1 + n % 2000, 'Ingresso de balcão', 80 + n % 5 * 10, timestamp '2015-01-01' + (n || ' hours')::interval
  from generate_series(1, 5000) n;
