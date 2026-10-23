\echo ==== A. faturamento de um mes, COM o indice parcial
explain (analyze, costs off, timing on)
select date_trunc('day', created_at)::date, count(*), sum(quantity), sum(total)
  from reservation
 where status = 'ACTIVE' and created_at >= '2025-03-01' and created_at < '2025-04-01'
 group by 1 order by 1;

\echo ==== B. o mesmo mes, SEM o indice (drop dentro de transacao + rollback)
begin;
drop index ix_reservation_active_created;
explain (analyze, costs off, timing on)
select date_trunc('day', created_at)::date, count(*), sum(quantity), sum(total)
  from reservation
 where status = 'ACTIVE' and created_at >= '2025-03-01' and created_at < '2025-04-01'
 group by 1 order by 1;
rollback;

\echo ==== C. o ano inteiro, COM o indice
explain (analyze, costs off, timing on)
select date_trunc('month', created_at)::date, count(*), sum(quantity), sum(total)
  from reservation
 where status = 'ACTIVE' and created_at >= '2025-01-01' and created_at < '2026-01-01'
 group by 1 order by 1;

\echo ==== D. vendas do evento 3, COM o indice por lote
explain (analyze, costs off, timing on)
select b.id, b.price, b.quantity, b.sold,
       count(r.id) filter (where r.status = 'ACTIVE'),
       count(r.id) filter (where r.status = 'CANCELLED'),
       coalesce(sum(r.total) filter (where r.status = 'ACTIVE'), 0)
  from batch_inventory b
  left join reservation r on r.batch_id = b.id
 where b.event_id = 3
 group by b.id order by b.id;

\echo ==== E. vendas do evento 3, SEM o indice por lote
begin;
drop index ix_reservation_batch;
explain (analyze, costs off, timing on)
select b.id, b.price, b.quantity, b.sold,
       count(r.id) filter (where r.status = 'ACTIVE'),
       count(r.id) filter (where r.status = 'CANCELLED'),
       coalesce(sum(r.total) filter (where r.status = 'ACTIVE'), 0)
  from batch_inventory b
  left join reservation r on r.batch_id = b.id
 where b.event_id = 3
 group by b.id order by b.id;
rollback;

\echo ==== F. indices da tabela reservation
select indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) from pg_indexes where tablename = 'reservation' order by 1;
