-- =====================================================================
-- 020_etiquetas_producto.sql
-- Las etiquetas de la tarjeta dejan de ser tres casillas fijas.
--
-- CONTEXTO
-- `products` tenía tres booleanos —`is_featured`, `is_new`, `is_recommended`—
-- y el editor los pintaba como tres casillas. Dos problemas:
--
--   1. No se podía crear una cuarta. Para poner "VIRAL" en una tarjeta había
--      que añadir una columna, un `check`, una casilla en el editor y un
--      `v-if` en la tarjeta. Una decisión comercial de cinco segundos costaba
--      un despliegue.
--   2. **Ninguno se veía en la tienda.** Se marcaban en el panel y no
--      aparecían en ninguna parte: tres casillas que no hacían nada. El único
--      distintivo que salía en la tarjeta era la etiqueta de promoción, que la
--      pone el motor de promociones y no se puede escribir a mano.
--
-- DECISIONES
--
--  1. UNA TABLA DE ETIQUETAS, no columnas. Crear "VIRAL" es insertar una fila.
--     La etiqueta lleva su propio color, así que "AGOTÁNDOSE" puede ir en
--     naranja sin tocar código.
--
--  2. LA RELACIÓN ES MUCHOS A MUCHOS. Un producto puede ser "NUEVO" y "VIRAL"
--     a la vez; con columnas eso ya funcionaba, y no se pierde.
--
--  3. LOS TRES BOOLEANOS SE MIGRAN Y SE SUELTAN. Quedarse con los dos sistemas
--     a la vez es la trampa de las dos fuentes de verdad que este proyecto ya
--     pagó con el costo de envío. Se copian a etiquetas, se respalda la
--     columna en el esquema `respaldo` y se sueltan.
--
--     >>> APLICA ESTA MIGRACIÓN JUNTO CON EL CAMBIO DE FRONTEND. <<<
--     El `catalog.js` anterior escribe esas tres columnas al guardar un
--     producto; si sueltas las columnas con el código viejo en marcha,
--     guardar un producto empieza a fallar.
--
--  4. EL TEXTO SE GUARDA COMO SE ESCRIBE. Sin mayúsculas forzadas en la base:
--     que "VIRAL" se vea en mayúsculas es cosa del CSS, y quien mañana quiera
--     "Edición limitada" en minúsculas no tiene que pelearse con un trigger.
--
--  5. UNA ETIQUETA SE APAGA, NO SE BORRA. `active = false` la retira de la
--     tienda y del selector sin perder a qué productos estuvo puesta. Borrarla
--     de verdad también se puede, y entonces sí se lleva sus asignaciones.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Las etiquetas
-- ---------------------------------------------------------------------
create table if not exists public.product_badges (
  id           bigint generated always as identity primary key,

  name         text not null,                    -- lo que lee la clienta: VIRAL
  slug         text not null,                    -- identificador estable, no cambia al renombrar
  description  text,                             -- para qué la usas; solo se ve en el panel

  color_fondo  text not null default '#a855f7',
  color_texto  text not null default '#ffffff',

  position     integer not null default 0,
  active       boolean not null default true,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint product_badges_name_no_vacio
    check (length(btrim(name)) between 1 and 24),

  -- Los colores tienen que ser hexadecimales CSS válidos: si no, el chip sale
  -- roto y no hay forma de saber por qué. Misma comprobación que `swatch_hex`.
  constraint product_badges_color_fondo_check
    check (color_fondo ~* '^#[0-9a-f]{6}$'),
  constraint product_badges_color_texto_check
    check (color_texto ~* '^#[0-9a-f]{6}$')
);

create unique index if not exists ux_product_badges_slug
  on public.product_badges (slug);

comment on table public.product_badges is
  'Etiquetas de la tarjeta de producto (VIRAL, NUEVO, 2x1...). Es escaparate: NO cambia precios ni stock.';
comment on column public.product_badges.slug is
  'Identificador estable. Renombrar la etiqueta no lo toca, asi que nada se rompe al cambiar el texto.';
comment on column public.product_badges.active is
  'false = retirada de la tienda y del selector, sin perder a que productos estuvo puesta.';

-- ---------------------------------------------------------------------
-- 2. Qué etiqueta lleva cada producto
-- ---------------------------------------------------------------------
create table if not exists public.product_badge_assignments (
  product_id bigint not null references public.products(id)       on delete cascade,
  badge_id   bigint not null references public.product_badges(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (product_id, badge_id)
);

create index if not exists ix_product_badge_assignments_badge
  on public.product_badge_assignments (badge_id);

comment on table public.product_badge_assignments is
  'Que etiquetas lleva cada producto. Muchos a muchos: un producto puede ser NUEVO y VIRAL a la vez.';

drop trigger if exists trg_product_badges_updated_at on public.product_badges;
create trigger trg_product_badges_updated_at
  before update on public.product_badges
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 3. RLS
--
-- La clienta tiene que poder leerlas: la etiqueta se pinta en la tarjeta de
-- la tienda. Pero solo las activas — una etiqueta apagada que siguiera
-- llegando por la API aparecería en la tienda aunque la hubieras retirado.
--
-- Las asignaciones sí se leen enteras: sin la etiqueta activa no pintan nada,
-- y filtrarlas por un `exists` en cada fila sale caro para lo que protege.
-- ---------------------------------------------------------------------
alter table public.product_badges            enable row level security;
alter table public.product_badge_assignments enable row level security;

drop policy if exists "product_badges_public_select" on public.product_badges;
create policy "product_badges_public_select" on public.product_badges
  for select using (active = true);

drop policy if exists "product_badges_admin_all" on public.product_badges;
create policy "product_badges_admin_all" on public.product_badges
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "product_badge_assignments_public_select" on public.product_badge_assignments;
create policy "product_badge_assignments_public_select" on public.product_badge_assignments
  for select using (true);

drop policy if exists "product_badge_assignments_admin_all" on public.product_badge_assignments;
create policy "product_badge_assignments_admin_all" on public.product_badge_assignments
  for all using (public.is_admin()) with check (public.is_admin());

grant select                     on public.product_badges            to anon, authenticated;
grant insert, update, delete     on public.product_badges            to authenticated;
grant select                     on public.product_badge_assignments to anon, authenticated;
grant insert, update, delete     on public.product_badge_assignments to authenticated;

drop trigger if exists trg_product_badges_audit on public.product_badges;
create trigger trg_product_badges_audit
  after insert or update or delete on public.product_badges
  for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------
-- 4. Siembra: las tres de siempre, más VIRAL.
--
-- Solo si la tabla está vacía, para que aplicar la migración dos veces no
-- duplique nada.
-- ---------------------------------------------------------------------
insert into public.product_badges (name, slug, description, color_fondo, color_texto, position)
select * from (values
  ('DESTACADO',   'destacado',   'Lo que quieres que se vea primero.',                 '#ff85c1', '#ffffff', 1),
  ('NUEVO',       'nuevo',       'Recien llegado. Quitala cuando deje de serlo.',      '#22c55e', '#ffffff', 2),
  ('RECOMENDADO', 'recomendado', 'Tu recomendacion personal a la clienta.',            '#0ea5e9', '#ffffff', 3),
  ('VIRAL',       'viral',       'Lo que esta sonando en redes.',                      '#a855f7', '#ffffff', 4)
) as v(name, slug, description, color_fondo, color_texto, position)
where not exists (select 1 from public.product_badges);

-- ---------------------------------------------------------------------
-- 5. Pasar los tres booleanos a etiquetas.
--
-- `is_new` tenía `default true`, así que casi todo el catálogo está marcado
-- como nuevo sin que nadie lo decidiera. Se copia igual —es el dato que hay—
-- y se avisa: revisa la etiqueta NUEVO en el panel después de aplicar esto.
-- ---------------------------------------------------------------------
do $$
declare
  hay_columnas boolean;
begin
  select count(*) = 3 into hay_columnas
  from information_schema.columns
  where table_schema = 'public' and table_name = 'products'
    and column_name in ('is_featured', 'is_new', 'is_recommended');

  if not hay_columnas then
    raise notice 'Las columnas is_featured/is_new/is_recommended ya no estan. Nada que migrar.';
    return;
  end if;

  -- Respaldo antes de soltar, igual que en la 018.
  create schema if not exists respaldo;
  execute $sql$
    create table if not exists respaldo.products_etiquetas_020 as
    select id, is_featured, is_new, is_recommended, now() as respaldado_en
    from public.products
  $sql$;

  execute $sql$
    insert into public.product_badge_assignments (product_id, badge_id)
    select p.id, b.id
    from public.products p
    cross join lateral (values
      ('destacado',   p.is_featured is true),
      ('nuevo',       p.is_new is not false),
      ('recomendado', p.is_recommended is true)
    ) as x(slug, puesta)
    join public.product_badges b on b.slug = x.slug
    where x.puesta
    on conflict do nothing
  $sql$;

  alter table public.products drop column if exists is_featured;
  alter table public.products drop column if exists is_new;
  alter table public.products drop column if exists is_recommended;

  raise notice 'Booleanos migrados a etiquetas y respaldados en respaldo.products_etiquetas_020.';
end $$;

-- ---------------------------------------------------------------------
-- 6. Comprobación.
-- ---------------------------------------------------------------------
select b.name,
       b.color_fondo,
       b.active,
       count(a.product_id) as productos
from public.product_badges b
left join public.product_badge_assignments a on a.badge_id = b.id
group by b.id, b.name, b.color_fondo, b.active
order by b.position;
