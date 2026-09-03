-- =====================================================================
-- 001_rls_restore_admin_policies.sql
-- Corrige: B-13 (crítico)
--
-- CONTEXTO
-- `add_audit_logs.sql` ejecuta `drop table public.admin_profiles cascade`.
-- Ese CASCADE arrastró 19 políticas RLS que dependían de admin_profiles.
-- `fix_admin_rls.sql` restauró solo 6. Las otras 13 siguen ausentes.
--
-- Una tabla con RLS activo y SIN políticas es inaccesible: PostgREST
-- devuelve 0 filas en los SELECT y 0 filas afectadas en los UPDATE,
-- SIN error. Por eso el panel admin "funciona" pero nada persiste.
--
-- Tablas afectadas hoy: orders, order_items, payments, customers,
-- shipments, sales, sale_items, promotion_products, categories,
-- store_settings, admins.
--
-- Idempotente: se puede reejecutar sin efectos secundarios.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Función de autorización única. SECURITY DEFINER para que la lectura de
-- admin_profiles no vuelva a pasar por RLS (evita recursión infinita).
-- ---------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_profiles
    where id = auth.uid()
      and role in (
        'super_admin', 'admin', 'inventory_admin',
        'sales_admin', 'orders_admin', 'inventory_manager'
      )
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------
-- CLIENTES: el storefront inserta; solo el admin lee.
-- ---------------------------------------------------------------------
alter table public.customers enable row level security;

drop policy if exists "customers_public_insert" on public.customers;
create policy "customers_public_insert" on public.customers
for insert to anon, authenticated with check (true);

drop policy if exists "customers_admin_read" on public.customers;
create policy "customers_admin_read" on public.customers
for select to authenticated using (public.is_admin());

drop policy if exists "customers_admin_update" on public.customers;
create policy "customers_admin_update" on public.customers
for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- PEDIDOS: el storefront inserta; solo el admin lee y cambia de estado.
-- Aquí estaba el fragmento incompleto de schema.sql: `orders_admin_update`
-- se creaba sin `for update`, sin `using` y sin `with check`.
-- ---------------------------------------------------------------------
alter table public.orders enable row level security;

drop policy if exists "orders_public_insert" on public.orders;
create policy "orders_public_insert" on public.orders
for insert to anon, authenticated with check (true);

drop policy if exists "orders_admin_read" on public.orders;
create policy "orders_admin_read" on public.orders
for select to authenticated using (public.is_admin());

drop policy if exists "orders_admin_update" on public.orders;
create policy "orders_admin_update" on public.orders
for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- ITEMS DEL PEDIDO
-- ---------------------------------------------------------------------
alter table public.order_items enable row level security;

drop policy if exists "order_items_public_insert" on public.order_items;
create policy "order_items_public_insert" on public.order_items
for insert to anon, authenticated with check (true);

drop policy if exists "order_items_admin_read" on public.order_items;
create policy "order_items_admin_read" on public.order_items
for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------
-- PAGOS: sin el UPDATE, confirmar un pago era imposible.
-- ---------------------------------------------------------------------
alter table public.payments enable row level security;

drop policy if exists "payments_public_insert" on public.payments;
create policy "payments_public_insert" on public.payments
for insert to anon, authenticated with check (true);

drop policy if exists "payments_admin_read" on public.payments;
create policy "payments_admin_read" on public.payments
for select to authenticated using (public.is_admin());

drop policy if exists "payments_admin_update" on public.payments;
create policy "payments_admin_update" on public.payments
for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- ENVÍOS: no tenía ninguna política, la tabla estaba cerrada por completo.
-- ---------------------------------------------------------------------
alter table public.shipments enable row level security;

drop policy if exists "shipments_admin_all" on public.shipments;
create policy "shipments_admin_all" on public.shipments
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- El RPC create_order_with_stock es SECURITY DEFINER, así que puede insertar
-- el envío inicial sin necesitar una política pública aquí.

-- ---------------------------------------------------------------------
-- VENTAS FÍSICAS (POS): tampoco tenían políticas.
-- ---------------------------------------------------------------------
alter table public.sales enable row level security;

drop policy if exists "sales_admin_all" on public.sales;
create policy "sales_admin_all" on public.sales
for all to authenticated using (public.is_admin()) with check (public.is_admin());

alter table public.sale_items enable row level security;

drop policy if exists "sale_items_admin_all" on public.sale_items;
create policy "sale_items_admin_all" on public.sale_items
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- PROMOCIONES
-- ---------------------------------------------------------------------
alter table public.promotions enable row level security;

drop policy if exists "promotions_public_read" on public.promotions;
create policy "promotions_public_read" on public.promotions
for select using (active = true);

drop policy if exists "promotions_admin_write" on public.promotions;
create policy "promotions_admin_write" on public.promotions
for all to authenticated using (public.is_admin()) with check (public.is_admin());

alter table public.promotion_products enable row level security;

drop policy if exists "promotion_products_public_read" on public.promotion_products;
create policy "promotion_products_public_read" on public.promotion_products
for select using (true);

drop policy if exists "promotion_products_admin_write" on public.promotion_products;
create policy "promotion_products_admin_write" on public.promotion_products
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- CATEGORÍAS: sin el write, el módulo dinámico no podía crear nada.
-- ---------------------------------------------------------------------
alter table public.categories enable row level security;

drop policy if exists "categories_public_read" on public.categories;
create policy "categories_public_read" on public.categories
for select using (true);

drop policy if exists "categories_admin_write" on public.categories;
create policy "categories_admin_write" on public.categories
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- CONFIGURACIÓN DE TIENDA
-- ---------------------------------------------------------------------
alter table public.store_settings enable row level security;

drop policy if exists "settings_public_read" on public.store_settings;
create policy "settings_public_read" on public.store_settings
for select using (true);

drop policy if exists "settings_admin_write" on public.store_settings;
create policy "settings_admin_write" on public.store_settings
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- TABLAS MAESTRAS DINÁMICAS: unificar con is_admin().
-- product_catalog_migration.sql las creó con un `exists(...)` inline que
-- no filtra por rol y no es SECURITY DEFINER.
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['brands', 'skin_types', 'finishes', 'coverages'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_public_read', t);
    execute format('create policy %I on public.%I for select using (active = true)', t || '_public_read', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_all', t);
    execute format(
      'create policy %I on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())',
      t || '_admin_all', t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- SALDO PÚBLICO DE VENTA: lectura abierta (no expone bodega ni historial).
-- ---------------------------------------------------------------------
alter table public.inventory_sale_balances enable row level security;

drop policy if exists "inventory_sale_balances_public_read" on public.inventory_sale_balances;
create policy "inventory_sale_balances_public_read" on public.inventory_sale_balances
for select using (true);

-- ---------------------------------------------------------------------
-- Verificación: no debe quedar ninguna tabla con RLS y sin políticas.
-- ---------------------------------------------------------------------
do $$
declare huerfanas text;
begin
  select string_agg(c.relname, ', ' order by c.relname) into huerfanas
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  where c.relkind = 'r'
    and c.relrowsecurity
    and c.relname <> 'admins'  -- legacy, se retira en 006
    and not exists (select 1 from pg_policy p where p.polrelid = c.oid);

  if huerfanas is not null then
    raise warning 'Tablas con RLS y sin politicas (inaccesibles): %', huerfanas;
  else
    raise notice 'OK: todas las tablas con RLS tienen politicas.';
  end if;
end $$;
