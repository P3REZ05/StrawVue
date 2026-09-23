-- =====================================================================
-- 019_ofertas_portada.sql
-- "Ofertas Especiales" deja de estar escrita a mano en el componente.
--
-- CONTEXTO
-- `HomeAds.vue` tenía las cuatro tarjetas dentro del propio archivo: tres
-- degradados y una imagen importada, con los textos "Skincare", "Bases mate"
-- y "Paleta de sombras" escritos en el HTML. Cambiar una oferta significaba
-- editar código y volver a desplegar, así que en la práctica no se cambiaba
-- nunca. El botón "Ver más" tampoco tenía destino: era un adorno.
--
-- Es el mismo error que ya se corrigió dos veces en este proyecto —los
-- banners que vivían en `localStorage` y las quince categorías escritas a
-- mano en `HomeCategories.vue`—: contenido comercial atrapado en el código.
--
-- DECISIONES
--
--  1. TAMAÑOS CON NOMBRE, no medidas libres. Cuatro piezas —destacada, ancha,
--     alta y pequeña— que ocupan 2x2, 2x1, 1x2 y 1x1 en una cuadrícula. Con
--     medidas libres se puede componer algo bonito en un monitor que se
--     deshace en un celular, y habría que mantener dos diseños. Con piezas
--     que encajan, la misma composición se reordena sola.
--
--  2. BORRADOR Y PUBLICADA son estados distintos. `published = false` deja la
--     tarjeta guardada y visible en la vista previa del panel, pero fuera de
--     la tienda. Es lo que permite dejar la campaña del viernes lista el
--     martes sin que nadie la vea.
--
--  3. EL DESTINO ES EXPLÍCITO. `link_type` dice si la tarjeta lleva a una
--     categoría, a un producto o a una dirección libre, y un `check` impide
--     guardar un tipo sin su dato. Una tarjeta grande que no lleva a ninguna
--     parte frustra, sobre todo en el celular, donde todo invita a tocarse.
--
--  4. EL VELO ES UN NÚMERO, no una clase de CSS. Una foto clara necesita más
--     oscurecido que una oscura para que el texto encima se lea. Dejarlo fijo
--     obligaba a elegir entre fotos ilegibles o fotos apagadas.
-- =====================================================================

create table if not exists public.home_offers (
  id            bigint generated always as identity primary key,

  title         text not null,
  subtitle      text,
  badge         text,                                    -- la etiqueta: NUEVO, OFERTA…

  size          text not null default 'pequena',
  image_url     text,
  image_path    text,                                    -- ruta en el bucket, para poder borrar el archivo

  -- Sin foto, la tarjeta es un degradado. Son los colores de la marca por
  -- defecto para que una tarjeta recién creada ya se vea bien.
  color_desde   text not null default '#ff85c1',
  color_hasta   text not null default '#d291bc',

  overlay       integer not null default 35,             -- 0 a 80: cuánto se oscurece la foto
  text_color    text not null default 'light',           -- light | dark, según la foto

  link_type     text not null default 'none',            -- none | category | product | url
  link_category text,
  link_product  bigint references public.products(id) on delete set null,
  link_url      text,

  position      integer not null default 0,
  published     boolean not null default false,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint home_offers_size_check
    check (size in ('destacada', 'ancha', 'alta', 'pequena')),

  constraint home_offers_overlay_check
    check (overlay between 0 and 80),

  constraint home_offers_text_color_check
    check (text_color in ('light', 'dark')),

  constraint home_offers_link_check
    check (
      link_type = 'none'
      or (link_type = 'category' and link_category is not null and link_category <> '')
      or (link_type = 'product'  and link_product is not null)
      or (link_type = 'url'      and link_url is not null and link_url <> '')
    )
);

comment on table public.home_offers is
  'Tarjetas de "Ofertas Especiales" de la portada. Es escaparate: NO cambia precios. Los descuentos de verdad viven en `promotions`.';
comment on column public.home_offers.size is
  'destacada = 2x2, ancha = 2x1, alta = 1x2, pequena = 1x1 en la cuadricula de la portada.';
comment on column public.home_offers.overlay is
  'Velo oscuro sobre la foto, 0-80. Sube si el texto no se lee encima.';
comment on column public.home_offers.published is
  'false = borrador: se ve en la vista previa del panel, no en la tienda.';
comment on column public.home_offers.image_path is
  'Ruta dentro del bucket product-images, para poder borrar el archivo al borrar la fila.';

create index if not exists ix_home_offers_orden
  on public.home_offers (published, position);

drop trigger if exists trg_home_offers_updated_at on public.home_offers;
create trigger trg_home_offers_updated_at
  before update on public.home_offers
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- RLS. Mismas reglas que `home_banners`, con una diferencia importante:
-- el público solo ve las PUBLICADAS. Un borrador filtrado por la API sería
-- una campaña destapada antes de tiempo.
-- ---------------------------------------------------------------------
alter table public.home_offers enable row level security;

drop policy if exists "home_offers_public_select" on public.home_offers;
create policy "home_offers_public_select" on public.home_offers
  for select using (published = true);

drop policy if exists "home_offers_admin_all" on public.home_offers;
create policy "home_offers_admin_all" on public.home_offers
  for all using (public.is_admin()) with check (public.is_admin());

grant select on public.home_offers to anon, authenticated;
grant insert, update, delete on public.home_offers to authenticated;

drop trigger if exists trg_home_offers_audit on public.home_offers;
create trigger trg_home_offers_audit
  after insert or update or delete on public.home_offers
  for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------
-- Siembra: las cuatro tarjetas que hoy están escritas en `HomeAds.vue`.
--
-- Se copian tal cual y **como borrador**, para que la portada no cambie sola
-- al aplicar esta migración: primero se revisan y se publican desde el panel.
-- La foto de "Colección semanal" no se puede sembrar porque hoy es un archivo
-- del repositorio, no del bucket; se sube desde el editor.
--
-- Solo se siembra si la tabla está vacía: aplicar la migración dos veces no
-- debe duplicar las tarjetas.
-- ---------------------------------------------------------------------
insert into public.home_offers (title, subtitle, badge, size, color_desde, color_hasta, overlay, link_type, position, published)
select * from (values
  ('Colección semanal', null,                              'NUEVO',           'destacada', '#ff85c1', '#d291bc', 45, 'none', 1, false),
  ('Skincare',          'Hasta 30% OFF',                   'OFERTA',          'pequena',   '#d291bc', '#ffc1cc', 15, 'none', 2, false),
  ('Bases mate',        'Nueva colección',                 'TRENDING',        'pequena',   '#ff85c1', '#d291bc', 15, 'none', 3, false),
  ('Paleta de sombras', 'Descubre los nuevos tonos metálicos', 'EDICIÓN LIMITADA', 'ancha', '#000000', '#4a173e', 10, 'none', 4, false)
) as v(title, subtitle, badge, size, color_desde, color_hasta, overlay, link_type, position, published)
where not exists (select 1 from public.home_offers);

-- ---------------------------------------------------------------------
-- Comprobación.
-- ---------------------------------------------------------------------
select size, count(*) as tarjetas,
       count(*) filter (where published) as publicadas
from public.home_offers
group by size
order by size;
