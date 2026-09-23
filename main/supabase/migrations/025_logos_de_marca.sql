-- =====================================================================
-- 025_logos_de_marca.sql
-- Las marcas tienen logo, y la clienta puede verlas.
--
-- CONTEXTO
-- `brands` existía desde el principio con lo justo —nombre y activa— porque
-- solo servía para clasificar productos en el panel. La portada nunca las
-- mostró.
--
-- Ahora el Home lleva una pasarela con los logos, así que hacen falta dos
-- cosas: dónde guardar el logo, y que la clienta pueda leer la tabla.
--
-- DECISIONES
--
--  1. EL LOGO VA EN `brands`, NO EN UNA TABLA NUEVA. La tentación era crear
--     `home_marcas` con su propia lista de imágenes, como se hizo con las
--     ofertas de portada. Sería un error: las marcas ya existen, ya se crean
--     al dar de alta un producto, y una segunda lista obligaría a mantener las
--     dos a mano y a que se desincronizaran. La pasarela no es un carrusel de
--     imágenes sueltas: es la lista real de marcas, las que tengan logo.
--
--  2. `logo_path` ADEMÁS DE `logo_url`. La URL es lo que pinta el navegador;
--     la ruta es lo que permite borrar el archivo del bucket al cambiar el
--     logo. Sin ella, cada logo sustituido dejaba basura ocupando cuota para
--     siempre. Mismo par que ya usan `home_offers` y `home_banners`.
--
--  3. LECTURA PÚBLICA DE LAS MARCAS ACTIVAS. Hasta hoy `brands` solo tenía
--     política de admin, así que una clienta anónima recibía **cero filas y
--     ningún error** — la trampa de RLS de siempre. La pasarela habría salido
--     vacía en la tienda y llena en el panel, que es el peor de los fallos:
--     el que solo se ve desde fuera.
--     El nombre de una marca no es dato sensible; es lo que va impreso en la
--     caja del producto.
--
--  4. `position` PARA ORDENAR. Qué marca va primero es una decisión comercial
--     —normalmente la que más vendes o la que te interesa destacar—, no
--     alfabética ni por fecha de alta.
-- =====================================================================

alter table public.brands
  add column if not exists logo_url  text,
  add column if not exists logo_path text,
  add column if not exists position  integer not null default 0;

comment on column public.brands.logo_url is
  'URL publica del logo en Storage. Si es null, la marca no sale en la pasarela del Home.';
comment on column public.brands.logo_path is
  'Ruta dentro del bucket product-images, para poder borrar el archivo al cambiar el logo.';
comment on column public.brands.position is
  'Orden en la pasarela del Home. Menor primero. Es una decision comercial, no alfabetica.';

create index if not exists ix_brands_pasarela
  on public.brands (position)
  where logo_url is not null;

-- ---------------------------------------------------------------------
-- RLS: la clienta puede leer las marcas activas.
-- ---------------------------------------------------------------------
alter table public.brands enable row level security;

drop policy if exists "brands_public_select" on public.brands;
create policy "brands_public_select" on public.brands
  for select using (active = true);

grant select on public.brands to anon, authenticated;

-- ---------------------------------------------------------------------
-- Comprobación: cuántas marcas hay y cuántas saldrían ya en la pasarela.
-- ---------------------------------------------------------------------
select count(*)                                              as marcas,
       count(*) filter (where active)                        as activas,
       count(*) filter (where logo_url is not null)          as con_logo,
       count(*) filter (where active and logo_url is not null) as en_la_pasarela
from public.brands;
