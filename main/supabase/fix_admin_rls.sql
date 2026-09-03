-- Corrige la autorizacion RLS del panel administrativo.
-- Ejecutar en Supabase SQL Editor estando autenticado como propietario.

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
      and role in ('super_admin', 'admin', 'inventory_admin', 'sales_admin', 'orders_admin', 'inventory_manager')
  );
$$;

grant execute on function public.is_admin() to authenticated;

drop policy if exists "suppliers_admin_all" on public.suppliers;
create policy "suppliers_admin_all" on public.suppliers
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "products_admin_write" on public.products;
create policy "products_admin_write" on public.products
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "inventory_admin_all" on public.inventory_movements;
create policy "inventory_admin_all" on public.inventory_movements
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "purchase_orders_admin_all" on public.purchase_orders;
create policy "purchase_orders_admin_all" on public.purchase_orders
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "purchase_order_items_admin_all" on public.purchase_order_items;
create policy "purchase_order_items_admin_all" on public.purchase_order_items
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "variants_admin_write" on public.product_variants;
create policy "variants_admin_write" on public.product_variants
for all to authenticated
using (public.is_admin())
with check (public.is_admin());