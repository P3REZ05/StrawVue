-- =====================================================================
-- 007_shade_model.sql
-- Modelo de tonos para maquillaje + imágenes reales de producto.
--
-- CONTEXTO
-- `product_variants` guardaba un tono como texto ('Tono 01'): sin color,
-- sin subtono y sin profundidad. En maquillaje el tono ES el producto, y
-- un catálogo que no muestra el color no se puede comprar.
--
-- Se adopta el esquema estándar de la industria: cada tono es un registro
-- con atributos gobernados (swatch, subtono, profundidad, acabado), y el
-- código de tono codifica subtono + profundidad al estilo NC42 de MAC.
--
-- También crea `product_images`, que resuelve dos cosas de una: la galería
-- del producto y la foto por tono. Sustituye a la URL `blob:` que se venía
-- guardando en products.image y que moría al recargar la página (B-15).
--
-- Idempotente. No destructiva: no borra ninguna columna existente.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Subtono. Para bases, correctores y polvos.
--    El código es la letra que aparece en el código de tono (NC42 -> N + C).
-- ---------------------------------------------------------------------
create table if not exists public.undertones (
  id bigint generated always as identity primary key,
  code text unique not null,
  name text not null,
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.undertones (code, name, description) values
  ('C', 'Frío',   'Subtonos rosados, rojizos o azulados'),
  ('N', 'Neutro', 'Equilibrio entre cálido y frío'),
  ('W', 'Cálido', 'Subtonos dorados, amarillos o melocotón'),
  ('O', 'Oliva',  'Subtonos verdosos, frecuentes en piel mediterránea y latina')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------
-- 2) Familia de tono. Para labiales, sombras y rubores, donde el subtono
--    no aplica pero sí la familia cromática.
-- ---------------------------------------------------------------------
create table if not exists public.shade_families (
  id bigint generated always as identity primary key,
  name text unique not null,
  swatch_hex text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.shade_families (name, swatch_hex) values
  ('Nudes',     '#C9A08A'),
  ('Rosados',   '#E5859B'),
  ('Corales',   '#F08060'),
  ('Rojos',     '#C1272D'),
  ('Vinos',     '#722F37'),
  ('Marrones',  '#7B4B32'),
  ('Bronces',   '#A9743F'),
  ('Morados',   '#7D4C8C'),
  ('Neutros',   '#B9A79A')
on conflict (name) do nothing;

-- ---------------------------------------------------------------------
-- 3) product_variants pasa a ser una ficha de tono.
--
--    swatch_hex Y swatch_image_url conviven a propósito: el hexadecimal
--    permite dibujar el chip, ordenar y filtrar (es dato estructurado);
--    la imagen es la verdad, porque un metalizado o un glitter no se
--    representan con un color plano. Si hay imagen, manda la imagen.
--
--    depth es numérico (1 = más clara, 100 = más profunda) para poder
--    ordenar una gama de bases de clara a profunda, que es como el
--    cliente la recorre. El orden alfabético no significa nada.
-- ---------------------------------------------------------------------
alter table public.product_variants
  add column if not exists shade_code       text,
  add column if not exists swatch_hex       text,
  add column if not exists swatch_image_url text,
  add column if not exists undertone_id     bigint references public.undertones(id) on delete set null,
  add column if not exists shade_family_id  bigint references public.shade_families(id) on delete set null,
  add column if not exists depth            smallint,
  add column if not exists position         integer not null default 0,
  add column if not exists is_default       boolean not null default false;

-- El hexadecimal debe ser un color CSS válido: si no, el chip sale roto.
alter table public.product_variants
  drop constraint if exists product_variants_swatch_hex_check;
alter table public.product_variants
  add constraint product_variants_swatch_hex_check
  check (swatch_hex is null or swatch_hex ~* '^#[0-9a-f]{6}$');

alter table public.product_variants
  drop constraint if exists product_variants_depth_check;
alter table public.product_variants
  add constraint product_variants_depth_check
  check (depth is null or depth between 1 and 100);

-- El precio del tono HEREDA del producto: null significa "usa el del
-- producto". Así, subir el precio de una línea de 40 tonos es una sola
-- edición en vez de 40, y no quedan tonos con el precio viejo.
alter table public.product_variants alter column price drop not null;
update public.product_variants set price = null where price = 0;

comment on column public.product_variants.price is
  'Precio propio del tono. NULL = hereda el precio del producto. Solo se usa por excepción (p. ej. tamaños distintos).';

create index if not exists idx_product_variants_product   on public.product_variants(product_id);
create index if not exists idx_product_variants_undertone on public.product_variants(undertone_id);
create index if not exists idx_product_variants_family    on public.product_variants(shade_family_id);
create index if not exists idx_product_variants_orden     on public.product_variants(product_id, position, depth);

-- Un solo tono por defecto por producto.
create unique index if not exists ux_product_variants_default
on public.product_variants (product_id) where is_default;

-- ---------------------------------------------------------------------
-- 4) Imágenes reales. variant_id nulo = imagen del producto;
--    variant_id lleno = foto de ese tono.
-- ---------------------------------------------------------------------
create table if not exists public.product_images (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id) on delete cascade,
  variant_id bigint references public.product_variants(id) on delete cascade,
  url text not null,
  storage_path text not null,
  alt text,
  position integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_product_images_product on public.product_images(product_id, position);
create index if not exists idx_product_images_variant on public.product_images(variant_id);

-- Una sola imagen principal por producto.
create unique index if not exists ux_product_images_primary
on public.product_images (product_id) where is_primary;

-- ---------------------------------------------------------------------
-- 5) RLS: lectura pública (es catálogo), escritura solo admin.
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['undertones', 'shade_families'] loop
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

alter table public.product_images enable row level security;

drop policy if exists "product_images_public_read" on public.product_images;
create policy "product_images_public_read" on public.product_images
for select using (true);

drop policy if exists "product_images_admin_all" on public.product_images;
create policy "product_images_admin_all" on public.product_images
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- 6) Auditoría también en catálogo y tablas maestras (B-17).
--    Crear o pausar una categoría cambia lo que se le ofrece al cliente
--    y merece dejar rastro igual que un cambio de precio.
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'categories', 'brands', 'skin_types', 'finishes', 'coverages',
    'undertones', 'shade_families', 'product_images'
  ] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists %I on public.%I', 'trg_audit_' || t, t);
      execute format(
        'create trigger %I after insert or update or delete on public.%I
         for each row execute function public.audit_trigger()',
        'trg_audit_' || t, t
      );
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 7) Vista de catálogo público con el tono ya resuelto.
--    Evita que el frontend tenga que reimplementar la herencia de precio
--    y el saldo por tono en cada pantalla.
-- ---------------------------------------------------------------------
drop view if exists public.storefront_shades;
create view public.storefront_shades with (security_invoker = true) as
select
  v.id                                as variant_id,
  v.product_id,
  v.name                              as shade_name,
  v.shade_code,
  v.sku,
  coalesce(v.price, p.sale_price, p.price, 0)::numeric(12,2) as effective_price,
  v.swatch_hex,
  v.swatch_image_url,
  v.depth,
  v.position,
  v.is_default,
  u.code                              as undertone_code,
  u.name                              as undertone_name,
  f.name                              as shade_family,
  coalesce(b.sale_stock, 0)           as sale_stock
from public.product_variants v
join public.products p on p.id = v.product_id
left join public.undertones u on u.id = v.undertone_id
left join public.shade_families f on f.id = v.shade_family_id
left join public.inventory_sale_balances b
       on b.product_id = v.product_id and b.variant_id = v.id
where v.is_active;

grant select on public.storefront_shades to anon, authenticated;
