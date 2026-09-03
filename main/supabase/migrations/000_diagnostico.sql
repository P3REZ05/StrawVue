-- =====================================================================
-- 000_diagnostico.sql  ·  SOLO LECTURA. No modifica nada.
-- Ejecutar primero en el SQL Editor para saber en qué estado está la base.
-- =====================================================================

-- 1) ¿Qué forma tiene audit_logs hoy?
select 'audit_logs' as tabla, column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'audit_logs'
order by ordinal_position;

-- 2) ¿payments y shipments tienen updated_at?
select table_name, column_name
from information_schema.columns
where table_schema = 'public'
  and table_name in ('orders', 'payments', 'shipments')
  and column_name = 'updated_at'
order by table_name;

-- 3) Tablas con RLS activo y sus políticas.
--    Una tabla con RLS y '(SIN POLITICAS)' es INACCESIBLE para todos
--    los roles salvo el propietario. Ahí es donde el panel admin falla en silencio.
select c.relname as tabla,
       coalesce(string_agg(p.polname, ', ' order by p.polname), '(SIN POLITICAS)') as politicas
from pg_class c
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
left join pg_policy p on p.polrelid = c.oid
where c.relkind = 'r' and c.relrowsecurity
group by c.relname
order by c.relname;

-- 4) ¿Existe el trigger que duplicaría el descuento de stock?
--    Si aparece 'order_item_inventory_movement', cada pedido descuenta DOS veces.
select tgname as trigger_name, relname as tabla
from pg_trigger t join pg_class c on c.oid = t.tgrelid
where not t.tgisinternal and c.relname in ('order_items', 'inventory_movements')
order by relname, tgname;

-- 5) Perfiles administrativos existentes.
select id, email, role from public.admin_profiles order by created_at;

-- 6) Saldos actuales de inventario (para comparar antes/después de la migración).
select product_id, variant_id, sale_stock
from public.inventory_sale_balances
order by product_id, variant_id;

-- 7) Conteo de movimientos por tipo.
select movement_type, reference_type, count(*), sum(quantity) as suma_cantidad
from public.inventory_movements
group by movement_type, reference_type
order by movement_type, reference_type;
