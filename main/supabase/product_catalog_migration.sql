-- Strawberry Makeup: catalogo dinamico y relaciones de productos
-- Migracion no destructiva. Ejecutar despues de schema.sql.

create table if not exists public.brands (
  id bigint generated always as identity primary key,
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.skin_types (
  id bigint generated always as identity primary key,
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.finishes (
  id bigint generated always as identity primary key,
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.coverages (
  id bigint generated always as identity primary key,
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.categories
  add column if not exists parent_id bigint references public.categories(id) on delete restrict;

alter table public.products
  add column if not exists brand_id bigint references public.brands(id) on delete restrict,
  add column if not exists category_id bigint references public.categories(id) on delete restrict,
  add column if not exists subcategory_id bigint references public.categories(id) on delete restrict,
  add column if not exists skin_type_id bigint references public.skin_types(id) on delete restrict,
  add column if not exists finish_id bigint references public.finishes(id) on delete restrict,
  add column if not exists coverage_id bigint references public.coverages(id) on delete restrict;

create index if not exists idx_categories_parent_id on public.categories(parent_id);
create index if not exists idx_products_brand_id on public.products(brand_id);
create index if not exists idx_products_category_id on public.products(category_id);
create index if not exists idx_products_subcategory_id on public.products(subcategory_id);
create index if not exists idx_products_skin_type_id on public.products(skin_type_id);
create index if not exists idx_products_finish_id on public.products(finish_id);
create index if not exists idx_products_coverage_id on public.products(coverage_id);

-- Copia los valores de texto existentes a las tablas maestras.
insert into public.brands (name)
select distinct trim(brand)
from public.products
where nullif(trim(brand), '') is not null
on conflict (name) do nothing;

insert into public.skin_types (name)
select distinct trim(skin_type)
from public.products
where nullif(trim(skin_type), '') is not null
on conflict (name) do nothing;

insert into public.finishes (name)
select distinct trim(finish)
from public.products
where nullif(trim(finish), '') is not null
on conflict (name) do nothing;

insert into public.coverages (name)
select distinct trim(coverage)
from public.products
where nullif(trim(coverage), '') is not null
on conflict (name) do nothing;

update public.products product
set brand_id = brand.id
from public.brands brand
where product.brand_id is null
  and nullif(trim(product.brand), '') is not null
  and lower(brand.name) = lower(trim(product.brand));

update public.products product
set skin_type_id = skin_type.id
from public.skin_types skin_type
where product.skin_type_id is null
  and nullif(trim(product.skin_type), '') is not null
  and lower(skin_type.name) = lower(trim(product.skin_type));

update public.products product
set finish_id = finish.id
from public.finishes finish
where product.finish_id is null
  and nullif(trim(product.finish), '') is not null
  and lower(finish.name) = lower(trim(product.finish));

update public.products product
set coverage_id = coverage.id
from public.coverages coverage
where product.coverage_id is null
  and nullif(trim(product.coverage), '') is not null
  and lower(coverage.name) = lower(trim(product.coverage));

-- Politicas: lectura publica solo de opciones activas; escritura solo admin.
alter table public.brands enable row level security;
alter table public.skin_types enable row level security;
alter table public.finishes enable row level security;
alter table public.coverages enable row level security;

 drop policy if exists "brands_public_read" on public.brands;
create policy "brands_public_read" on public.brands
for select using (active = true);

 drop policy if exists "brands_admin_all" on public.brands;
create policy "brands_admin_all" on public.brands
for all using (exists (select 1 from public.admin_profiles ap where ap.id = auth.uid()));

 drop policy if exists "skin_types_public_read" on public.skin_types;
create policy "skin_types_public_read" on public.skin_types
for select using (active = true);

 drop policy if exists "skin_types_admin_all" on public.skin_types;
create policy "skin_types_admin_all" on public.skin_types
for all using (exists (select 1 from public.admin_profiles ap where ap.id = auth.uid()));

 drop policy if exists "finishes_public_read" on public.finishes;
create policy "finishes_public_read" on public.finishes
for select using (active = true);

 drop policy if exists "finishes_admin_all" on public.finishes;
create policy "finishes_admin_all" on public.finishes
for all using (exists (select 1 from public.admin_profiles ap where ap.id = auth.uid()));

 drop policy if exists "coverages_public_read" on public.coverages;
create policy "coverages_public_read" on public.coverages
for select using (active = true);

 drop policy if exists "coverages_admin_all" on public.coverages;
create policy "coverages_admin_all" on public.coverages
for all using (exists (select 1 from public.admin_profiles ap where ap.id = auth.uid()));

-- Subcategorias y categorias activas: la politica actual de categories sigue aplicando.
