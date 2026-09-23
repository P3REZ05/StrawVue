-- =====================================================================
-- 023_slug_etiqueta_en_la_base.sql
-- El identificador de una etiqueta lo genera la base, no el navegador.
--
-- CONTEXTO
-- La 020 dejó `product_badges.slug` como `not null` con un índice único, y
-- quien lo calculaba era el frontend: `catalog.js` sacaba el slug del nombre,
-- miraba su lista local de etiquetas y, si ya estaba, numeraba (`viral-2`).
--
-- Eso funciona sólo mientras esa lista local sea completa y esté al día, y hay
-- varias formas de que no lo esté: la pantalla se abrió antes de que el
-- catálogo terminara de cargar, otra pestaña creó una etiqueta entretanto, o
-- sencillamente la carga falló en silencio. En todos esos casos el INSERT
-- llega con un slug ya usado y la base lo rechaza con
-- «duplicate key value violates unique constraint», que no le dice nada a
-- quien solo quería ponerle un nombre a una etiqueta. Es lo que pasó.
--
-- Es el mismo error de fondo que el proyecto ya pagó con el costo de envío y
-- con el precio de los combos: **dos sitios calculando el mismo valor**. La
-- unicidad de una clave solo la puede garantizar quien tiene todas las filas
-- delante, y ese es Postgres.
--
-- DECISIONES
--
--  1. EL SLUG SE GENERA EN UN TRIGGER. El frontend manda el nombre y ya. Si
--     el slug llega vacío —que es lo que hará a partir de ahora—, se calcula.
--
--  2. SI CHOCA, SE NUMERA, NO SE FALLA. Dos etiquetas llamadas «NUEVO» son
--     raras pero no son un error del usuario: se quedan en `nuevo` y
--     `nuevo-2`. Perder lo escrito por un detalle interno que nadie ve sí
--     sería un error.
--
--  3. EL BUCLE ES ACOTADO. Prueba hasta `-999`; si ni así, usa el reloj. Un
--     `while true` en un trigger es una forma elegante de colgar la base.
--
--  4. RENOMBRAR NO CAMBIA EL SLUG. Solo se genera al insertar. Es un
--     identificador estable: si cambiara al renombrar, cualquier cosa que lo
--     hubiera guardado dejaría de encontrar la etiqueta.
-- =====================================================================

-- Quitar espacios, acentos y símbolos. Misma regla que usaba el frontend, para
-- que las etiquetas ya creadas sigan teniendo el slug que tienen.
-- `unaccent` es una extensión de Postgres que puede no estar instalada en el
-- proyecto; esto hace lo mismo para lo que hace falta aquí (español) sin
-- depender de ella.
create or replace function public.unaccent_simple(p_texto text)
returns text
language sql
immutable
as $$
  select translate(
    coalesce(p_texto, ''),
    'áàäâãÁÀÄÂÃéèëêÉÈËÊíìïîÍÌÏÎóòöôõÓÒÖÔÕúùüûÚÙÜÛñÑçÇ',
    'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUnNcC'
  );
$$;

-- Quitar espacios, acentos y símbolos. Misma regla que usaba el frontend, para
-- que las etiquetas ya creadas conserven el slug que tienen.
create or replace function public.slug_de_texto(p_texto text)
returns text
language sql
immutable
as $$
  select left(
    trim(both '-' from
      regexp_replace(
        lower(public.unaccent_simple(coalesce(p_texto, ''))),
        '[^a-z0-9]+', '-', 'g'
      )
    ),
    32
  );
$$;

comment on function public.slug_de_texto(text) is
  'Identificador estable a partir de un texto: sin acentos, minusculas, guiones. Maximo 32 caracteres.';

-- ---------------------------------------------------------------------
-- El trigger
-- ---------------------------------------------------------------------
create or replace function public.generar_slug_etiqueta()
returns trigger
language plpgsql
as $$
declare
  base       text;
  candidato  text;
  n          integer := 1;
begin
  -- Solo si no viene uno. Así una migración o una carga masiva pueden seguir
  -- fijando el slug a mano.
  if new.slug is not null and btrim(new.slug) <> '' then
    return new;
  end if;

  base := public.slug_de_texto(new.name);
  if base = '' then
    base := 'etiqueta';
  end if;

  candidato := base;
  while exists (select 1 from public.product_badges where slug = candidato) loop
    n := n + 1;
    if n > 999 then
      -- Salida de emergencia. No debería llegar aquí nunca, pero un trigger
      -- que puede girar para siempre es peor que un slug feo.
      candidato := left(base, 20) || '-' || extract(epoch from clock_timestamp())::bigint;
      exit;
    end if;
    candidato := left(base, 28) || '-' || n;
  end loop;

  new.slug := candidato;
  return new;
end;
$$;

comment on function public.generar_slug_etiqueta() is
  'Rellena product_badges.slug al insertar si viene vacio, numerando si choca. La unicidad la decide la base, que es la unica que ve todas las filas.';

-- El slug pasa a tener valor por defecto para que el frontend pueda omitirlo.
alter table public.product_badges alter column slug set default '';

drop trigger if exists trg_product_badges_slug on public.product_badges;
create trigger trg_product_badges_slug
  before insert on public.product_badges
  for each row execute function public.generar_slug_etiqueta();

-- ---------------------------------------------------------------------
-- Comprobación: crear dos etiquetas con el mismo nombre no debe fallar.
-- ---------------------------------------------------------------------
do $$
declare
  a bigint;
  b bigint;
  slug_a text;
  slug_b text;
begin
  insert into public.product_badges (name) values ('Prueba Acentuación') returning id into a;
  insert into public.product_badges (name) values ('Prueba Acentuación') returning id into b;

  select slug into slug_a from public.product_badges where id = a;
  select slug into slug_b from public.product_badges where id = b;

  raise notice 'Dos etiquetas con el mismo nombre -> % y %', slug_a, slug_b;

  delete from public.product_badges where id in (a, b);
end $$;

select id, name, slug, active from public.product_badges order by position;
