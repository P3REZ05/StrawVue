-- =====================================================================
-- 027_retirar_pasarela_marcas.sql
-- Fuera la pasarela de marcas. Su sitio en la portada lo ocupan las
-- colecciones (migración 026).
--
-- CONTEXTO
-- La 025 añadió `logo_url`, `logo_path` y `position` a `brands` para una
-- pasarela de logos al final del Home. No era lo que el usuario esperaba de
-- esa parte de la portada y se retira entera: componente, módulo del panel y
-- columnas.
--
-- Se sueltan las columnas en vez de dejarlas «por si acaso». Este proyecto ya
-- pagó lo que cuesta acumular columnas fantasma —`products.image` y
-- `product_variants.stock` sobrevivieron meses hasta la 018—: nadie las
-- escribe, pero quien lee el esquema por primera vez asume que significan
-- algo, y eso es exactamente el error que hay que impedir.
--
-- Lo que NO se borra: los archivos de logo que hubiera en el bucket. Borrar
-- archivos de Storage desde SQL no es posible, y tampoco conviene hacerlo a
-- ciegas. Si llegaste a subir alguno, están en `product-images/marcas/` y los
-- puedes borrar desde el panel de Storage de Supabase. La lista de cuáles
-- eran queda respaldada abajo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Respaldo. Barato, y deja apuntado qué archivos quedaron huérfanos.
-- ---------------------------------------------------------------------
create schema if not exists respaldo;
revoke all on schema respaldo from anon, authenticated;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'brands' and column_name = 'logo_url'
  ) and not exists (
    select 1 from information_schema.tables
    where table_schema = 'respaldo' and table_name = 'brands_logos_027'
  ) then
    execute 'create table respaldo.brands_logos_027 as
             select id, name, logo_url, logo_path, "position", now() as respaldado_en
             from public.brands
             where logo_url is not null or logo_path is not null';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. Fuera.
-- ---------------------------------------------------------------------
drop index if exists public.ix_brands_pasarela;

alter table public.brands drop column if exists logo_url;
alter table public.brands drop column if exists logo_path;
alter table public.brands drop column if exists "position";

-- La lectura pública de las marcas se queda: la puso la 025 para la pasarela,
-- pero es correcta por sí sola —el nombre de una marca es lo que va impreso en
-- la caja— y la tienda la necesita para el filtro de marca del catálogo.
-- Quitarla ahora sería volver a dejar `brands` invisible para la clienta.

-- ---------------------------------------------------------------------
-- 3. Comprobación: las tres columnas deben haber desaparecido.
-- ---------------------------------------------------------------------
select
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'brands'
      and column_name in ('logo_url', 'logo_path', 'position'))        as columnas_que_quedan,
  (select count(*) from information_schema.tables
    where table_schema = 'respaldo' and table_name = 'brands_logos_027') as hay_respaldo;
