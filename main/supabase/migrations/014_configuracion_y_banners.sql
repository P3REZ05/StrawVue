-- =====================================================================
-- 014_configuracion_y_banners.sql
-- La pantalla de Configuración deja de ser decorativa.
--
-- ANTES
--   · `AdminConfiguracion.vue` leía de `mockData` y escribía en
--     `localStorage`. Cero Supabase.
--   · Los banners del inicio vivían en `localStorage` bajo la clave
--     'strawberry-home-promotions', **con las imágenes en base64 dentro**.
--     Es decir: la administradora configuraba un banner, lo veía en su
--     propio navegador, y ningún cliente lo veía nunca. Encima, dos o tres
--     fotos en base64 revientan la cuota de ~5 MB de localStorage.
--   · El costo de envío que mostraba el carrito salía de una constante en
--     `mockData.js`, mientras el pedido lo cobraba desde `store_settings`.
--     Cambiar el envío en la base hacía que la tienda mostrara un precio y
--     el servidor cobrara otro.
--
-- AHORA
--   · `store_settings` gana las claves de redes sociales que faltaban y un
--     trigger de `updated_at` (la columna existía y nunca se actualizaba).
--   · `home_banners` guarda los banners de verdad, con la imagen en Storage
--     como el resto del catálogo.
--
-- `store_settings` ya tenía sus políticas (lectura pública, escritura de
-- admin) y se comprobó contra la base real antes de escribir esto: un
-- `GET` con solo la apikey anónima devuelve las tres filas, y un `UPDATE`
-- con sesión de admin afecta 1 fila. No hace falta tocarlas.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Claves que el frontend tenía harcodeadas en mockData.js
-- ---------------------------------------------------------------------
insert into public.store_settings (key, value) values
  ('socialFacebook',  'https://www.facebook.com/strawberry_makeup05'),
  ('socialTiktok',    'https://www.tiktok.com/@strawberry_makeup05'),
  ('socialInstagram', 'https://www.instagram.com/strawberry_makeup05')
on conflict (key) do nothing;

-- `updated_at` estaba en la tabla desde el principio y nadie la tocaba, así
-- que era imposible saber cuándo se cambió el costo de envío.
drop trigger if exists trg_store_settings_updated_at on public.store_settings;
create trigger trg_store_settings_updated_at
  before update on public.store_settings
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 2. Banners del inicio
--
-- No son promociones: no cambian ningún precio. Son el carrusel de la
-- portada, y por eso viven aparte de `promotions` — mezclarlos fue una
-- confusión que ya costó una vuelta de diseño.
-- ---------------------------------------------------------------------
create table if not exists public.home_banners (
  id          bigint generated always as identity primary key,
  title       text not null,
  subtitle    text,
  accent      text,
  link        text default '/tienda',
  image_url   text,
  image_path  text,
  position    integer not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.home_banners is
  'Carrusel de la portada. No afecta precios: para eso esta `promotions`.';
comment on column public.home_banners.image_path is
  'Ruta dentro del bucket product-images, para poder borrar el archivo al borrar la fila.';

create index if not exists ix_home_banners_orden
  on public.home_banners (active, position);

drop trigger if exists trg_home_banners_updated_at on public.home_banners;
create trigger trg_home_banners_updated_at
  before update on public.home_banners
  for each row execute function public.set_updated_at();

alter table public.home_banners enable row level security;

-- Una tabla con RLS activo y sin políticas devuelve 0 filas SIN error: la
-- portada saldría vacía y nada en la consola lo diría. Por eso las dos
-- políticas van en la misma migración que la tabla.
drop policy if exists "home_banners_public_select" on public.home_banners;
create policy "home_banners_public_select" on public.home_banners
  for select using (active = true);

drop policy if exists "home_banners_admin_all" on public.home_banners;
create policy "home_banners_admin_all" on public.home_banners
  for all using (public.is_admin()) with check (public.is_admin());

grant select on public.home_banners to anon, authenticated;
grant insert, update, delete on public.home_banners to authenticated;

-- ---------------------------------------------------------------------
-- 3. Auditoría, igual que el resto de tablas de negocio.
-- ---------------------------------------------------------------------
drop trigger if exists trg_home_banners_audit on public.home_banners;
create trigger trg_home_banners_audit
  after insert or update or delete on public.home_banners
  for each row execute function public.audit_trigger();

drop trigger if exists trg_store_settings_audit on public.store_settings;
create trigger trg_store_settings_audit
  after insert or update or delete on public.store_settings
  for each row execute function public.audit_trigger();
