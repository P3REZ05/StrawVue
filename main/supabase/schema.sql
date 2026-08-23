-- =============================================
-- STRAWBERRY MAKEUP - ESQUEMA SUPABASE V2
-- Ejecutar en Supabase SQL Editor
-- =============================================

-- =============================================
-- 1. TABLA: PRODUCTOS
-- =============================================
create table if not exists public.products (
  id bigint generated always as identity primary key,
  name text not null,
  brand text,
  category text not null,
  subcategory text,
  description text,
  price numeric(12,2) default 0,
  sale_price numeric(12,2),
  original_price numeric(12,2),
  image text,
  skin_type text,
  finish text,
  coverage text,
  net_content_ml integer,
  barcode text,
  is_featured boolean default false,
  is_new boolean default true,
  is_recommended boolean default false,
  status text not null default 'draft' check (status in ('draft', 'active', 'paused', 'archived')),
  slug text unique,
  image_url text,
  active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =============================================
-- 2. TABLA: VARIANTES DE PRODUCTO
-- =============================================
create table if not exists public.product_variants (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id) on delete restrict,
  name text not null,
  sku text,
  barcode text,
  variant_type text default 'tone',
  option_value text,
  price numeric(12,2) default 0,
  compare_at_price numeric(12,2),
  stock integer default 0,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index if not exists ux_product_variants_sku on public.product_variants(sku) where sku is not null;

-- =============================================
-- 3. TABLA: PROVEEDORES
-- =============================================
create table if not exists public.suppliers (
  id bigint generated always as identity primary key,
  name text not null,
  document_number text,
  contact_name text,
  phone text,
  email text,
  address text,
  city text,
  payment_terms text,
  notes text,
  active boolean default true,
  created_at timestamptz default now()
);

-- =============================================
-- 4. TABLA: ÓRDENES DE COMPRA
-- =============================================
create table if not exists public.purchase_orders (
  id bigint generated always as identity primary key,
  supplier_id bigint references public.suppliers(id) on delete restrict,
  order_number text unique,
  order_date date default current_date,
  notes text,
  status text default 'pending' check (status in ('pending', 'received', 'partial', 'cancelled')),
  total numeric(12,2) default 0,
  created_at timestamptz default now()
);

-- =============================================
-- 5. TABLA: ITEMS DE COMPRA
-- =============================================
create table if not exists public.purchase_order_items (
  id bigint generated always as identity primary key,
  purchase_order_id bigint not null references public.purchase_orders(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  quantity integer not null default 0,
  unit_cost numeric(12,2) default 0,
  destination text default 'warehouse',
  created_at timestamptz default now()
);

-- =============================================
-- 6. TABLA: MOVIMIENTOS DE INVENTARIO
-- =============================================
create table if not exists public.inventory_movements (
  id bigint generated always as identity primary key,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  movement_type text not null check (movement_type in ('purchase', 'sale', 'online_order', 'return', 'transfer', 'adjustment', 'damage')),
  quantity integer not null,
  unit_cost numeric(12,2),
  reference_type text,
  reference_id bigint,
  notes text,
  created_by uuid,
  created_at timestamptz default now()
);

-- Saldo de venta público: no expone existencias de bodega ni movimientos.
drop view if exists public.inventory_sale_balances;

create table if not exists public.inventory_sale_balances (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id) on delete cascade,
  variant_id bigint references public.product_variants(id) on delete cascade,
  sale_stock integer not null default 0
);

create unique index if not exists ux_inventory_sale_balances_key
on public.inventory_sale_balances (product_id, coalesce(variant_id, 0));

/*
  La tabla se mantiene con un trigger al final del archivo. El storefront solo
  puede leer este saldo agregado y no tiene acceso al historial privado.
*/
alter table public.inventory_sale_balances enable row level security;

drop policy if exists "inventory_sale_balances_public_read" on public.inventory_sale_balances;
create policy "inventory_sale_balances_public_read" on public.inventory_sale_balances
for select using (true);

create or replace function public.refresh_inventory_sale_balance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_product_id bigint := coalesce(new.product_id, old.product_id);
  affected_variant_id bigint := coalesce(new.variant_id, old.variant_id);
  calculated_stock integer;
begin
  select coalesce(sum(case
    when movement_type = 'transfer' and reference_type = 'sale_inventory' then quantity
    when movement_type in ('sale', 'online_order') then quantity
    else 0
  end), 0)::integer
  into calculated_stock
  from public.inventory_movements
  where product_id = affected_product_id
    and variant_id is not distinct from affected_variant_id;

  delete from public.inventory_sale_balances
  where product_id = affected_product_id
    and variant_id is not distinct from affected_variant_id;

  if calculated_stock <> 0 then
    insert into public.inventory_sale_balances (product_id, variant_id, sale_stock)
    values (affected_product_id, affected_variant_id, calculated_stock);
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists refresh_inventory_sale_balance_trigger on public.inventory_movements;
create trigger refresh_inventory_sale_balance_trigger
after insert or update or delete on public.inventory_movements
for each row execute function public.refresh_inventory_sale_balance();

-- Vista administrativa con el saldo completo y las políticas de la tabla base.
drop view if exists public.inventory_balances;
create or replace view public.inventory_balances with (security_invoker = true) as
select
  product_id,
  variant_id,
  coalesce(sum(case
    when movement_type = 'purchase' then quantity
    when movement_type = 'transfer' and reference_type = 'warehouse' then quantity
    else 0
  end), 0)::integer as warehouse_stock,
  coalesce(sum(case
    when movement_type = 'transfer' and reference_type = 'sale_inventory' then quantity
    when movement_type in ('sale', 'online_order') then quantity
    else 0
  end), 0)::integer as sale_stock
from public.inventory_movements
where product_id is not null
group by product_id, variant_id;

-- Migración opcional de instalaciones antiguas. No falla si las tablas ya no existen.
do $$
begin
  if to_regclass('public.purchase_inventory') is not null then
    execute $sql$
      insert into public.inventory_movements (product_id, movement_type, quantity, unit_cost, reference_type, notes)
      select pi.product_id, 'purchase', pi.quantity, pi.cost_price, 'warehouse', 'Migrado desde purchase_inventory'
      from public.purchase_inventory pi
      where not exists (
        select 1 from public.inventory_movements im
        where im.reference_type = 'warehouse'
          and im.notes = 'Migrado desde purchase_inventory'
          and im.product_id = pi.product_id
      )
    $sql$;
  end if;

  if to_regclass('public.sale_inventory') is not null then
    execute $sql$
      insert into public.inventory_movements (product_id, movement_type, quantity, unit_cost, reference_type, notes)
      select si.product_id, 'transfer', si.quantity, si.cost_price, 'sale_inventory', 'Migrado desde sale_inventory'
      from public.sale_inventory si
      where not exists (
        select 1 from public.inventory_movements im
        where im.reference_type = 'sale_inventory'
          and im.notes = 'Migrado desde sale_inventory'
          and im.product_id = si.product_id
      )
    $sql$;
  end if;
end $$;

-- =============================================
-- 7. TABLA: CLIENTES
-- =============================================
create table if not exists public.customers (
  id bigint generated always as identity primary key,
  full_name text not null,
  phone text,
  email text,
  document_number text,
  city text,
  address text,
  notes text,
  created_at timestamptz default now()
);

-- =============================================
-- 8. TABLA: PEDIDOS ONLINE
-- =============================================
create table if not exists public.orders (
  id bigint generated always as identity primary key,
  customer_id bigint references public.customers(id) on delete restrict,
  order_number text unique,
  subtotal numeric(12,2) default 0,
  shipping_cost numeric(12,2) default 0,
  total numeric(12,2) default 0,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'paid', 'preparing', 'shipped', 'delivered', 'cancelled', 'returned')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =============================================
-- 9. TABLA: ITEMS DEL PEDIDO
-- =============================================
create table if not exists public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  product_name text not null,
  quantity integer not null default 1,
  unit_price numeric(12,2) default 0,
  created_at timestamptz default now()
);

-- =============================================
-- 10. TABLA: PAGOS
-- =============================================
create table if not exists public.payments (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  payment_method text not null check (payment_method in ('cash', 'transfer', 'nequi', 'daviplata')),
  amount numeric(12,2) not null,
  status text default 'pending' check (status in ('pending', 'paid', 'failed', 'refunded')),
  proof_url text,
  proof_name text,
  reference_code text,
  created_at timestamptz default now()
);

-- =============================================
-- 11. TABLA: ENVÍOS
-- =============================================
create table if not exists public.shipments (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  carrier text,
  tracking_number text,
  shipping_cost numeric(12,2) default 0,
  estimated_delivery date,
  shipped_at timestamptz,
  delivered_at timestamptz,
  status text default 'pending' check (status in ('pending', 'assigned', 'shipped', 'delivered', 'failed')),
  created_at timestamptz default now()
);

-- =============================================
-- 12. TABLA: VENTAS FÍSICAS
-- =============================================
create table if not exists public.sales (
  id bigint generated always as identity primary key,
  sale_date date default current_date,
  customer_name text,
  total numeric(12,2) default 0,
  payment_method text default 'cash',
  created_by uuid,
  created_at timestamptz default now()
);

create table if not exists public.sale_items (
  id bigint generated always as identity primary key,
  sale_id bigint not null references public.sales(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  quantity integer not null default 1,
  unit_price numeric(12,2) default 0,
  created_at timestamptz default now()
);

-- =============================================
-- 13. TABLA: PROMOCIONES
-- =============================================
create table if not exists public.promotions (
  id bigint generated always as identity primary key,
  title text not null,
  label text,
  type text not null check (type in ('percent', 'fixed', 'bundle', 'shipping', 'coupon', 'category')),
  value numeric(12,2) default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.promotion_products (
  id bigint generated always as identity primary key,
  promotion_id bigint not null references public.promotions(id) on delete cascade,
  product_id bigint references public.products(id) on delete cascade,
  variant_id bigint references public.product_variants(id) on delete cascade,
  created_at timestamptz default now()
);

-- =============================================
-- 14. TABLA: PERFIL DE ADMINISTRADORES
-- =============================================
create table if not exists public.admin_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text unique not null,
  role text not null default 'super_admin' check (role in ('super_admin', 'inventory_admin', 'sales_admin', 'orders_admin')),
  created_at timestamptz default now()
);

-- Compatibilidad con el proyecto anterior
create table if not exists public.admins (
  id bigint generated always as identity primary key,
  name text not null,
  email text unique not null,
  role text default 'admin',
  password_hash text,
  created_at timestamptz default now()
);

-- =============================================
-- 15. TABLA: CONFIGURACIÓN
-- =============================================
create table if not exists public.store_settings (
  id bigint generated always as identity primary key,
  key text unique not null,
  value text,
  updated_at timestamptz default now()
);

-- =============================================
-- 16. TABLA: CATEGORÍAS
-- =============================================
create table if not exists public.categories (
  id bigint generated always as identity primary key,
  name text unique not null,
  image text,
  active boolean default true,
  created_at timestamptz default now()
);

-- =============================================
-- 17. TABLA: AUDITORÍA
-- =============================================
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  entity_type text not null,
  entity_id bigint,
  action text not null,
  details jsonb,
  created_by uuid,
  created_at timestamptz default now()
);

-- =============================================
-- SEED INICIAL
-- =============================================
insert into public.categories (name) values
  ('Skincare'), ('Sombras'), ('Delineadores'), ('Pestañinas'),
  ('Bases'), ('Polvos'), ('Correctores'), ('Rubores'),
  ('Iluminadores'), ('Brochas'), ('Pestañas'), ('Cejas'),
  ('Labios'), ('Primer y Fijador'), ('Accesorios')
on conflict (name) do nothing;

insert into public.store_settings (key, value) values
  ('freeShippingThreshold', '200000'),
  ('shippingCost', '10000'),
  ('whatsappNumber', '573114088065')
on conflict (key) do nothing;

insert into public.admins (name, email, role, password_hash) values
  ('Admin Principal', 'admin@strawberrymakeup.com', 'super_admin', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy')
on conflict (email) do nothing;

-- =============================================
-- POLÍTICAS DE SEGURIDAD (RLS)
-- =============================================
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.suppliers enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_items enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.shipments enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.promotions enable row level security;
alter table public.promotion_products enable row level security;
alter table public.admin_profiles enable row level security;
alter table public.admins enable row level security;
alter table public.store_settings enable row level security;
alter table public.categories enable row level security;
alter table public.audit_logs enable row level security;

-- Productos públicos activos
create policy "products_public_read" on public.products
for select using (active = true and status = 'active');

create policy "products_admin_write" on public.products
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Variantes públicas activas
create policy "variants_public_read" on public.product_variants
for select using (is_active = true);

create policy "variants_admin_write" on public.product_variants
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Proveedores: solo admin
create policy "suppliers_admin_all" on public.suppliers
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Compras: solo admin
create policy "purchase_orders_admin_all" on public.purchase_orders
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

create policy "purchase_order_items_admin_all" on public.purchase_order_items
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Inventario: solo admin
create policy "inventory_admin_all" on public.inventory_movements
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Clientes: insert público, lectura solo admin
create policy "customers_public_insert" on public.customers
for insert with check (true);

create policy "customers_admin_read" on public.customers
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Pedidos y pagos: público crea, admin lee y actualiza
create policy "orders_public_insert" on public.orders
for insert with check (true);

create policy "orders_admin_read" on public.orders
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

create policy "orders_admin_update" on public.orders
for update using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

create policy "order_items_public_insert" on public.order_items
for insert with check (true);

create policy "order_items_admin_read" on public.order_items
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

create policy "payments_public_insert" on public.payments
for insert with check (true);

create policy "payments_admin_read" on public.payments
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

create policy "shipments_admin_all" on public.shipments
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Ventas físicas: solo admin
create policy "sales_admin_all" on public.sales
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

create policy "sale_items_admin_all" on public.sale_items
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Promos públicas activas
create policy "promotions_public_read" on public.promotions
for select using (active = true);

create policy "promotions_admin_write" on public.promotions
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

create policy "promotion_products_admin_write" on public.promotion_products
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Categorías públicas
create policy "categories_public_read" on public.categories
for select using (active = true);

create policy "categories_admin_write" on public.categories
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Configuración pública
create policy "settings_public_read" on public.store_settings
for select using (true);

create policy "settings_admin_write" on public.store_settings
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Admin profiles: solo super_admin
create policy "admin_profiles_admin_read" on public.admin_profiles
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid() and ap.role = 'super_admin'
  )
);

create policy "admin_profiles_self_read" on public.admin_profiles
for select using (id = auth.uid());

create policy "admins_admin_read" on public.admins
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- Auditoría: solo admin
create policy "audit_logs_admin_write" on public.audit_logs
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- =============================================
-- MOVIMIENTO AUTOMÁTICO DE INVENTARIO ONLINE
-- =============================================
-- Los pedidos públicos no escriben directamente en inventory_movements.
-- Este trigger registra la salida cuando se crean los items del pedido.
create or replace function public.register_online_order_movement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.inventory_movements (
    product_id,
    variant_id,
    movement_type,
    quantity,
    reference_type,
    reference_id,
    notes
  ) values (
    new.product_id,
    new.variant_id,
    'online_order',
    -new.quantity,
    'order',
    new.order_id,
    'Salida automática por pedido online'
  );

  return new;
end;
$$;

drop trigger if exists order_item_inventory_movement on public.order_items;

create trigger order_item_inventory_movement
after insert on public.order_items
for each row execute function public.register_online_order_movement();