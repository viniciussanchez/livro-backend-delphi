# Capítulo 22 (E05): a limpeza dos itens antigos com e sem "skip locked".
# Roda dentro do contêiner do PostgreSQL: docker exec -i cap22-postgres bash -s < deadlock-demo.sh
P="psql -U eventos -d fila_demo -q -t -A -v ON_ERROR_STOP=1"
psql -U eventos -d eventos -q -c "drop database if exists fila_demo" -c "create database fila_demo"
$P -c "create table SYNC_FILA (ID int primary key, TABELA varchar(30), CHAVE int, STATUS char(1))"
for VARIANTE in antiga nova; do
  $P -c "truncate SYNC_FILA" -c "insert into SYNC_FILA values (1,'CLIENTE',42,'P'),(2,'CLIENTE',42,'P')"
  if [ $VARIANTE = antiga ]; then
    LIMPEZA="update SYNC_FILA set STATUS='O' where TABELA='CLIENTE' and CHAVE=42 and ID < 2 and STATUS in ('P','R')"
  else
    LIMPEZA="update SYNC_FILA set STATUS='O' where ID in (select ID from SYNC_FILA where TABELA='CLIENTE' and CHAVE=42 and ID < 2 and STATUS in ('P','R') for update skip locked)"
  fi
  ANTES=$(psql -U eventos -d eventos -t -A -c "select deadlocks from pg_stat_database where datname='fila_demo'")
  # Thread B: pega o item 1 e depois espera a trava do cliente.
  ( $P -c "begin" -c "select ID from SYNC_FILA where ID = 1 for update skip locked" -c "select pg_sleep(1)" \
       -c "select pg_advisory_xact_lock(hashtext('CLIENTE'), 42)" -c "commit" >/tmp/b.txt 2>&1; echo "B saiu com $?" >>/tmp/b.txt ) &
  sleep 0.3
  # Thread A: pega a trava do cliente e o item 2, envia e limpa os antigos.
  $P -c "begin" -c "select pg_advisory_xact_lock(hashtext('CLIENTE'), 42)" \
     -c "select ID from SYNC_FILA where ID = 2 for update skip locked" -c "select pg_sleep(2)" \
     -c "$LIMPEZA" -c "commit" >/tmp/a.txt 2>&1; echo "A saiu com $?" >>/tmp/a.txt
  wait
  sleep 1
  DEPOIS=$(psql -U eventos -d eventos -t -A -c "select deadlocks from pg_stat_database where datname='fila_demo'")
  echo "-- limpeza $VARIANTE: deadlocks antes $ANTES, depois $DEPOIS"
  grep -h "saiu\|ERROR\|deadlock" /tmp/a.txt /tmp/b.txt | sed 's/^/   /'
done
psql -U eventos -d eventos -q -c "drop database fila_demo"
