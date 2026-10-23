-- 10 lotes (eventos 3 a 12) e 300 mil reservas espalhadas por 2025.
insert into batch_inventory (id, event_id, price, quantity, sold, sales_start, sales_end, updated_at)
select 900 + n, 3 + n, 120, 1000000, 0, '2025-01-01', '2026-01-01', now()
  from generate_series(0, 9) n;

insert into reservation (customer_id, batch_id, event_id, quantity, unit_price, total, status, created_at, cancelled_at)
select 1000 + g % 50000, 900 + g % 10, 3 + g % 10, x.q, 120, x.q * 120,
       case when g % 7 = 0 then 'CANCELLED' else 'ACTIVE' end,
       x.ts,
       case when g % 7 = 0 then x.ts + interval '1 day' end
  from generate_series(1, 300000) g,
       lateral (select 1 + g % 4 as q,
                       timestamp '2025-01-01' + (g * 105.12) * interval '1 second' as ts) x;

update batch_inventory b
   set sold = s.total
  from (select batch_id, sum(quantity) as total
          from reservation where status = 'ACTIVE' group by batch_id) s
 where s.batch_id = b.id and b.id >= 900;

analyze batch_inventory;
analyze reservation;

select count(*) as reservas, sum(total) filter (where status = 'ACTIVE') as faturamento from reservation;
