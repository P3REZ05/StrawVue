-- =====================================================================
-- 010_promociones.sql
-- Motor de promociones y calculo de precios en el servidor.
--
-- CONTEXTO
-- Las tablas `promotions` y `promotion_products` existen desde el primer
-- esquema y nunca se usaron: el panel guardaba las promos en localStorage,
-- asi que no afectaban a ningun precio real.
--
-- PROBLEMA DE FONDO QUE SE CORRIGE AQUI
-- `create_order_with_stock` insertaba el `unit_price` y el `total` tal como
-- llegaban del navegador. Cualquiera podia pedir una base de $38.900 por $1.
-- Con promociones eso empeora: el precio pasa a variar por motivos legitimos
-- y un total extraño deja de ser sospechoso.
--
-- A partir de aqui el precio lo calcula la base. El cliente solo dice QUE
-- quiere y CUANTO; el CUANTO CUESTA lo decide el servidor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Ampliar el modelo de promociones
-- ---------------------------------------------------------------------
alter table public.promotions
  add column if not exists code         text,
  add column if not exists description  text,
  add column if not exists min_purchase numeric(12,2),
  add column if not exists buy_quantity integer,
  add column if not exists get_quantity integer,
  add column if not exists priority     integer not null default 0,
  add column if not exists applies_to   text not null default 'all',
  add column if not exists category_id  bigint references public.categories(id) on delete cascade,
  add column if not exists max_uses     integer,
  add column if not exists uses_count   integer not null default 0,
  add column if not exists updated_at   timestamptz default now();

alter table public.promotions drop constraint if exists promotions_applies_to_check;
alter table public.promotions add constraint promotions_applies_to_check
  check (applies_to in ('all', 'category', 'products'));

-- El cupon se compara sin distinguir mayusculas: nadie escribe "VERANO20"
-- exactamente igual dos veces.
create unique index if not exists ux_promotions_code
on public.promotions (upper(code)) where code is not null;

create index if not exists idx_promotions_vigencia
on public.promotions (active, starts_at, ends_at);

create index if not exists idx_promotion_products_promo on public.promotion_products(promotion_id);
create index if not exists idx_promotion_products_prod  on public.promotion_products(product_id);

comment on column public.promotions.type is
  'percent = % de descuento · fixed = monto fijo de descuento · shipping = envio gratis sobre min_purchase · coupon = requiere code · bundle = lleva buy_quantity paga get_quantity';
comment on column public.promotions.applies_to is
  'all = todo el catalogo · category = solo category_id · products = solo los de promotion_products';

-- ---------------------------------------------------------------------
-- 2) Vigencia: una sola definicion, usada en todas partes
-- ---------------------------------------------------------------------
create or replace function public.promo_vigente(p promotions)
returns boolean
language sql immutable
as $$
  select p.active
     and (p.starts_at is null or now() >= p.starts_at)
     and (p.ends_at   is null or now() <= p.ends_at)
     and (p.max_uses  is null or p.uses_count < p.max_uses);
$$;

-- ---------------------------------------------------------------------
-- 3) Precio base de un producto o tono, antes de promociones.
--    El tono hereda del producto cuando su precio es NULL.
-- ---------------------------------------------------------------------
create or replace function public.precio_base(p_product_id bigint, p_variant_id bigint default null)
returns numeric
language sql stable
as $$
  select coalesce(
    (select v.price from public.product_variants v where v.id = p_variant_id),
    (select p.sale_price from public.products p where p.id = p_product_id),
    (select p.price from public.products p where p.id = p_product_id),
    0
  )::numeric(12,2);
$$;

-- ---------------------------------------------------------------------
-- 4) Mejor promocion de producto aplicable.
--
--    Solo se consideran `percent` y `fixed`: son las que cambian el precio
--    de una linea. Envio gratis y cupones actuan sobre el carrito completo
--    y se resuelven en el RPC del pedido.
--
--    Si varias aplican gana la de mayor prioridad y, a igualdad, la que
--    deje el precio mas bajo. Nunca se acumulan: acumular descuentos sin
--    querer es como se regala margen.
-- ---------------------------------------------------------------------
create or replace function public.promo_para_producto(p_product_id bigint, p_variant_id bigint default null)
returns table (
  promotion_id bigint,
  titulo text,
  etiqueta text,
  tipo text,
  precio_final numeric(12,2),
  descuento numeric(12,2)
)
language sql stable
as $$
  with base as (
    select public.precio_base(p_product_id, p_variant_id) as precio,
           (select category_id from public.products where id = p_product_id) as cat
  ),
  candidatas as (
    select pr.id, pr.title, pr.label, pr.type, pr.priority,
           case
             when pr.type = 'percent' then greatest(b.precio - (b.precio * pr.value / 100.0), 0)
             when pr.type = 'fixed'   then greatest(b.precio - pr.value, 0)
           end::numeric(12,2) as precio_final,
           b.precio as precio_base
    from public.promotions pr, base b
    where pr.type in ('percent', 'fixed')
      and public.promo_vigente(pr)
      and pr.code is null                      -- los cupones no se aplican solos
      and (
        pr.applies_to = 'all'
        or (pr.applies_to = 'category' and pr.category_id is not distinct from b.cat)
        or (pr.applies_to = 'products' and exists (
              select 1 from public.promotion_products pp
              where pp.promotion_id = pr.id
                and pp.product_id = p_product_id
                and (pp.variant_id is null or pp.variant_id = p_variant_id)
           ))
      )
  )
  select id, title, label, type, precio_final, (precio_base - precio_final)::numeric(12,2)
  from candidatas
  where precio_final < precio_base
  order by priority desc, precio_final asc
  limit 1;
$$;

grant execute on function public.promo_vigente(promotions)        to anon, authenticated;
grant execute on function public.precio_base(bigint, bigint)      to anon, authenticated;
grant execute on function public.promo_para_producto(bigint, bigint) to anon, authenticated;

-- Precio unitario definitivo. Es lo que cobra el pedido.
create or replace function public.precio_efectivo(p_product_id bigint, p_variant_id bigint default null)
returns numeric
language sql stable
as $$
  select coalesce(
    (select precio_final from public.promo_para_producto(p_product_id, p_variant_id)),
    public.precio_base(p_product_id, p_variant_id)
  );
$$;

grant execute on function public.precio_efectivo(bigint, bigint) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 5) La vitrina ve el precio ya resuelto, con su etiqueta.
-- ---------------------------------------------------------------------
drop view if exists public.storefront_shades;
create view public.storefront_shades with (security_invoker = true) as
select
  v.id                        as variant_id,
  v.product_id,
  v.name                      as shade_name,
  v.shade_code,
  v.sku,
  public.precio_base(v.product_id, v.id)     as base_price,
  public.precio_efectivo(v.product_id, v.id) as effective_price,
  (select etiqueta from public.promo_para_producto(v.product_id, v.id)) as promo_label,
  (select titulo   from public.promo_para_producto(v.product_id, v.id)) as promo_title,
  v.swatch_hex,
  v.swatch_image_url,
  v.depth,
  v.position,
  v.is_default,
  u.code                      as undertone_code,
  u.name                      as undertone_name,
  f.name                      as shade_family,
  coalesce(b.sale_stock, 0)   as sale_stock
from public.product_variants v
join public.products p on p.id = v.product_id
left join public.undertones u on u.id = v.undertone_id
left join public.shade_families f on f.id = v.shade_family_id
left join public.inventory_sale_balances b
       on b.product_id = v.product_id and b.variant_id = v.id
where v.is_active;

grant select on public.storefront_shades to anon, authenticated;

-- Lo mismo para productos sin tonos.
drop view if exists public.storefront_products;
create view public.storefront_products with (security_invoker = true) as
select
  p.id as product_id,
  p.name,
  p.category,
  p.category_id,
  public.precio_base(p.id, null)     as base_price,
  public.precio_efectivo(p.id, null) as effective_price,
  (select etiqueta from public.promo_para_producto(p.id, null)) as promo_label,
  (select titulo   from public.promo_para_producto(p.id, null)) as promo_title,
  coalesce(b.sale_stock, 0) as sale_stock
from public.products p
left join public.inventory_sale_balances b on b.product_id = p.id and b.variant_id is null
where p.active;

grant select on public.storefront_products to anon, authenticated;

-- ---------------------------------------------------------------------
-- 6) Configuracion de tienda tipada, para no leer texto suelto.
-- ---------------------------------------------------------------------
create or replace function public.config_numero(p_key text, p_default numeric default 0)
returns numeric
language sql stable
as $$
  select coalesce((select nullif(value, '')::numeric from public.store_settings where key = p_key), p_default);
$$;

grant execute on function public.config_numero(text, numeric) to anon, authenticated;
