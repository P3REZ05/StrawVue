-- =====================================================================
-- 026_colecciones.sql
-- Colecciones: agrupar productos que van juntos y enseñarlos con una foto.
--
-- CONTEXTO
-- El catálogo se clasifica por categoría (qué es: base, labial, rubor) y por
-- marca (quién lo hace). Falta el tercer eje, que es comercial: **con qué van
-- juntos**. «Colección Alisia» son doce productos distintos —una base, dos
-- labiales, un rubor— que no comparten ni categoría ni marca; lo que comparten
-- es que se venden juntos y que la clienta los busca juntos.
--
-- Esto ocupa el sitio de la portada donde estuvo la pasarela de marcas, que se
-- retira en la 027.
--
-- DECISIONES
--
--  1. UN PRODUCTO, UNA COLECCIÓN. Es una columna en `products`, no una tabla
--     de cruce. Decisión explícita del usuario. Si algún día un producto tiene
--     que estar en dos, habrá que migrar a muchos-a-muchos — el cambio no es
--     gratis, pero la simplicidad de hoy vale más que la flexibilidad de un
--     caso que todavía no existe.
--
--     `on delete set null`: borrar una colección **no borra sus productos**,
--     los deja sueltos. Lo contrario sería que quitar una campaña de la
--     portada te vaciara el catálogo.
--
--  2. LA COLECCIÓN SE PUBLICA O NO, COMO LAS OFERTAS. `published = false` la
--     deja guardada y fuera de la tienda: la de Navidad se prepara en octubre.
--
--  3. EL SLUG LO GENERA LA BASE. Misma lección que las etiquetas (migración
--     023): el navegador no puede garantizar que una clave sea única porque no
--     ve todas las filas. Se reutiliza `slug_de_texto` y el mismo patrón de
--     numerar si choca.
--
--  4. LA FOTO ES OBLIGATORIA EN LA PRÁCTICA, no en el esquema. Sin foto la
--     colección no sale en la portada —es lo único que se enseña de ella—,
--     pero se permite crearla sin foto para poder ir montándola por partes.
--
--  5. EL INTERRUPTOR DE LA SECCIÓN ENTERA vive en `store_settings`, con las
--     demás preferencias del sitio, no como una columna en ninguna tabla:
--     «¿se ve la sección Colecciones?» es configuración de la tienda, no un
--     atributo de una colección.
-- =====================================================================

create table if not exists public.collections (
  id           bigint generated always as identity primary key,

  name         text not null,
  slug         text not null default '',
  description  text,

  image_url    text,
  image_path   text,                       -- ruta en el bucket, para borrar el archivo

  position     integer not null default 0,
  published    boolean not null default false,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint collections_name_no_vacio
    check (length(btrim(name)) between 1 and 60)
);

create unique index if not exists ux_collections_slug on public.collections (slug);
create index if not exists ix_collections_orden on public.collections (published, position);

comment on table public.collections is
  'Grupos comerciales de productos (Coleccion Alisia, Navidad...). Un producto pertenece como mucho a una.';
comment on column public.collections.published is
  'false = guardada pero fuera de la tienda. Permite preparar la campana con antelacion.';
comment on column public.collections.image_path is
  'Ruta dentro del bucket product-images, para poder borrar el archivo al cambiar la foto.';

-- ---------------------------------------------------------------------
-- El slug, en la base. Ver migración 023: calcularlo en el navegador rompe
-- en cuanto su lista local no está completa.
-- ---------------------------------------------------------------------
create or replace function public.generar_slug_coleccion()
returns trigger
language plpgsql
as $$
declare
  base      text;
  candidato text;
  n         integer := 1;
begin
  if new.slug is not null and btrim(new.slug) <> '' then
    return new;
  end if;

  base := public.slug_de_texto(new.name);
  if base = '' then base := 'coleccion'; end if;

  candidato := base;
  while exists (select 1 from public.collections where slug = candidato and id is distinct from new.id) loop
    n := n + 1;
    if n > 999 then
      candidato := left(base, 20) || '-' || extract(epoch from clock_timestamp())::bigint;
      exit;
    end if;
    candidato := left(base, 28) || '-' || n;
  end loop;

  new.slug := candidato;
  return new;
end;
$$;

drop trigger if exists trg_collections_slug on public.collections;
create trigger trg_collections_slug
  before insert on public.collections
  for each row execute function public.generar_slug_coleccion();

drop trigger if exists trg_collections_updated_at on public.collections;
create trigger trg_collections_updated_at
  before update on public.collections
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- A qué colección pertenece cada producto.
-- ---------------------------------------------------------------------
alter table public.products
  add column if not exists collection_id bigint references public.collections(id) on delete set null;

create index if not exists ix_products_collection on public.products (collection_id);

comment on column public.products.collection_id is
  'Coleccion a la que pertenece el producto, o null. Borrar la coleccion deja el producto suelto, no lo borra.';

-- ---------------------------------------------------------------------
-- RLS. La clienta ve las colecciones publicadas; el resto, solo el admin.
-- Una colección en borrador que se colara por la API sería una campaña
-- destapada antes de tiempo, igual que con `home_offers`.
-- ---------------------------------------------------------------------
alter table public.collections enable row level security;

drop policy if exists "collections_public_select" on public.collections;
create policy "collections_public_select" on public.collections
  for select using (published = true);

-- `to authenticated` a propósito: sin eso la política aplica también a `anon`,
-- que acabaría evaluando `is_admin()` —una consulta con SECURITY DEFINER
-- contra `admin_profiles`— en cada lectura pública, y dependiendo de que anon
-- conserve permiso para ejecutarla. Es el patrón de la migración 001; las 019
-- y 020 se le escaparon y la 028 las corrige.
drop policy if exists "collections_admin_all" on public.collections;
create policy "collections_admin_all" on public.collections
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

grant select                 on public.collections to anon, authenticated;
grant insert, update, delete on public.collections to authenticated;

drop trigger if exists trg_collections_audit on public.collections;
create trigger trg_collections_audit
  after insert or update or delete on public.collections
  for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------
-- El interruptor de la sección entera, con las demás preferencias del sitio.
-- Arranca encendido: si alguien crea una colección y la publica, lo normal es
-- que quiera verla, no descubrir que hay un segundo interruptor escondido.
-- ---------------------------------------------------------------------
insert into public.store_settings (key, value)
values ('homeCollectionsVisible', 'true')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- Comprobación.
-- ---------------------------------------------------------------------
select
  (select count(*) from public.collections)                         as colecciones,
  (select count(*) from public.collections where published)         as publicadas,
  (select count(*) from public.products where collection_id is not null) as productos_asignados,
  (select value from public.store_settings where key = 'homeCollectionsVisible') as seccion_visible;
