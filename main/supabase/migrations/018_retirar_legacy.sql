-- =====================================================================
-- 018_retirar_legacy.sql
-- Suelta dos columnas que ya no se leen ni se escriben en ningún sitio.
--
-- CONTEXTO
-- Las dos vienen del esquema original, de antes de que existieran
-- `inventory_movements` (migración 004) y `product_images` (migración 008).
-- Desde entonces sobreviven como columnas fantasma: nadie las usa, pero
-- cualquiera que lea el esquema por primera vez asume que sí, y ese es
-- exactamente el error que hay que impedir.
--
--  1. `product_variants.stock`
--     El stock se deriva de `inventory_movements` y se lee por
--     `inventory_balances`. Esta columna se quedó en 0 (o en un número
--     inventado) desde el día que se dejó de escribir. Un reporte que la
--     sumara por error daría existencias falsas sin fallar.
--
--  2. `products.image`
--     Las fotos viven en `product_images` (Storage). Lo único que quedaba
--     aquí era una URL `blob:` muerta del producto 4 —un `blob:` solo existe
--     en la pestaña que lo creó, así que ni siquiera cargaba— y el frontend
--     ya la filtraba explícitamente.
--
-- COMPROBADO ANTES DE SOLTARLAS
--   · ninguna vista, función, trigger ni política las menciona;
--   · el frontend no las escribe;
--   · `products.image`: 4 productos en la base, 1 con valor, y ese valor
--     era `blob:http://localhost:5173/...`.
--
-- La auditoría no se pierde: `audit_logs` guarda el diff como jsonb, así que
-- los cambios históricos de `image` siguen ahí y se siguen leyendo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Respaldo de lo poco que había. Barato, y evita el "¿y si?".
-- ---------------------------------------------------------------------
create schema if not exists respaldo;
revoke all on schema respaldo from anon, authenticated;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products' and column_name = 'image'
  ) and not exists (
    select 1 from information_schema.tables
    where table_schema = 'respaldo' and table_name = 'products_image_20260909'
  ) then
    execute 'create table respaldo.products_image_20260909 as
             select id, name, image from public.products where image is not null';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'product_variants' and column_name = 'stock'
  ) and not exists (
    select 1 from information_schema.tables
    where table_schema = 'respaldo' and table_name = 'variants_stock_20260909'
  ) then
    execute 'create table respaldo.variants_stock_20260909 as
             select id, product_id, name, stock from public.product_variants';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. Fuera.
-- ---------------------------------------------------------------------
alter table public.products         drop column if exists image;
alter table public.product_variants drop column if exists stock;

-- ---------------------------------------------------------------------
-- 3. Que quede escrito dónde vive cada cosa ahora, para el que llegue después.
-- ---------------------------------------------------------------------
comment on table public.product_images is
  'Unica fuente de las fotos de producto. products.image se elimino en 018.';

comment on table public.inventory_movements is
  'Unica fuente del stock. Se lee agregado por la vista inventory_balances; '
  'no hay ninguna columna stock en products ni en product_variants.';

-- ---------------------------------------------------------------------
-- 4. Comprobación: las dos columnas deben haber desaparecido.
-- ---------------------------------------------------------------------
select
  coalesce((select count(*) from information_schema.columns
            where table_schema = 'public' and table_name = 'products'
              and column_name = 'image'), 0)  as products_image_quedan,
  coalesce((select count(*) from information_schema.columns
            where table_schema = 'public' and table_name = 'product_variants'
              and column_name = 'stock'), 0)  as variants_stock_quedan;
