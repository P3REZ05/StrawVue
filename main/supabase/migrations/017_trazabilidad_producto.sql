-- =====================================================================
-- 017_trazabilidad_producto.sql
-- Etapa 6 del refactor: la historia de un producto, contada.
--
-- CONTEXTO
-- Los datos existen desde hace tiempo y nadie puede leerlos. Están en dos
-- sitios con formas distintas:
--   · `inventory_movements` — qué entró y qué salió, en unidades.
--   · `audit_logs`          — qué cambió en la ficha, en `jsonb` crudo.
--
-- Abrir `audit_logs` y ver `{"price": 38900, "name": "Base...", ...}` frente
-- a otro objeto igual pero con un campo distinto no es trazabilidad: es un
-- volcado. El trabajo de verdad de esta migración es **traducir**.
--
-- LO QUE SE CONSTRUYE
--   1. `describir_cambio()` — convierte dos `jsonb` en "Precio: $38.900 →
--      $45.900", saltándose el ruido (`updated_at` y compañía).
--   2. `report_trazabilidad` — une movimientos y auditoría en una sola línea
--      de tiempo por producto, con títulos en español.
--
-- POR QUÉ UNA VISTA Y NO UNA CONSULTA EN EL FRONTEND
-- Porque son tres fuentes con formas distintas (movimientos, auditoría de
-- producto, auditoría de tonos) y unirlas en JavaScript significaría tres
-- viajes y una traducción duplicada. La base ya sabe hacer esto.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Nombres legibles de las columnas que le importan a una persona.
--
-- Lo que no está aquí se muestra con su nombre técnico: es mejor enseñar
-- `skin_type_id` que esconder un cambio que sí ocurrió.
-- ---------------------------------------------------------------------
create or replace function public.etiqueta_columna(p_columna text)
returns text
language sql immutable
as $$
  select case p_columna
    when 'name'             then 'Nombre'
    when 'description'      then 'Descripción'
    when 'price'            then 'Precio'
    when 'sale_price'       then 'Precio de oferta'
    when 'category'         then 'Categoría'
    when 'category_id'      then 'Categoría'
    when 'subcategory_id'   then 'Subcategoría'
    when 'brand_id'         then 'Marca'
    when 'status'           then 'Estado'
    when 'active'           then 'Visible en tienda'
    when 'barcode'          then 'Código de barras'
    when 'net_content_ml'   then 'Contenido'
    when 'is_featured'      then 'Destacado'
    when 'is_new'           then 'Novedad'
    when 'is_recommended'   then 'Recomendado'
    when 'shade_code'       then 'Código de tono'
    when 'sku'              then 'SKU'
    when 'swatch_hex'       then 'Color'
    when 'swatch_image_url' then 'Imagen del tono'
    when 'undertone_id'     then 'Subtono'
    when 'shade_family_id'  then 'Familia de tono'
    when 'depth'            then 'Profundidad'
    when 'position'         then 'Orden'
    when 'is_default'       then 'Tono por defecto'
    when 'is_active'        then 'Tono activo'
    when 'compare_at_price' then 'Precio comparativo'
    when 'skin_type_id'     then 'Tipo de piel'
    when 'finish_id'        then 'Acabado'
    when 'coverage_id'      then 'Cobertura'
    when 'image'            then 'Imagen (legacy)'
    else p_columna
  end;
$$;

-- ---------------------------------------------------------------------
-- describir_cambio
--
-- Compara dos versiones de una fila y devuelve solo lo que cambió, en
-- lenguaje humano. Devuelve NULL si no cambió nada relevante —y eso importa:
-- la vista descarta esas filas para que la línea de tiempo no se llene de
-- "actualizado" sin contenido.
-- ---------------------------------------------------------------------
-- Un valor tal como se le enseña a una persona.
--
-- `38900.00` es un dato; `$ 38.900` es un precio. La diferencia decide si la
-- pantalla se lee de un vistazo o hay que descifrarla. Los booleanos igual:
-- "true" no dice nada, "sí" sí.
create or replace function public.valor_legible(p_columna text, p_valor text)
returns text
language sql immutable
as $$
  select case
    when p_valor is null or p_valor = '' then null
    when p_columna in ('price','sale_price','compare_at_price','unit_cost','total','subtotal')
      -- Formato colombiano: punto para los miles y sin decimales. `to_char`
      -- con `G` usa los separadores del locale de la base, que es C y pone
      -- comas; se fuerza a mano para que coincida con `formatCurrency` de la
      -- interfaz y no salgan dos formatos de precio en la misma pantalla.
      then '$ ' || replace(to_char(round(p_valor::numeric), 'FM999,999,999,999'), ',', '.')
    when p_valor = 'true'  then 'sí'
    when p_valor = 'false' then 'no'
    else p_valor
  end;
$$;

grant execute on function public.valor_legible(text, text) to authenticated;

-- Las claves foráneas guardan un número. "Cobertura: (vacío) → 1" no le dice
-- nada a nadie; "Cobertura: (vacío) → Alta" sí. Se resuelven contra sus tablas
-- maestras, que son pequeñas y con nombre único.
create or replace function public.nombre_referencia(p_columna text, p_id text)
returns text
language sql stable
as $$
  select case p_columna
    when 'category_id'     then (select name from public.categories      where id = p_id::bigint)
    when 'subcategory_id'  then (select name from public.categories      where id = p_id::bigint)
    when 'brand_id'        then (select name from public.brands          where id = p_id::bigint)
    when 'skin_type_id'    then (select name from public.skin_types      where id = p_id::bigint)
    when 'finish_id'       then (select name from public.finishes        where id = p_id::bigint)
    when 'coverage_id'     then (select name from public.coverages       where id = p_id::bigint)
    when 'undertone_id'    then (select name from public.undertones      where id = p_id::bigint)
    when 'shade_family_id' then (select name from public.shade_families  where id = p_id::bigint)
    else null
  end;
$$;

grant execute on function public.nombre_referencia(text, text) to authenticated;

create or replace function public.describir_cambio(p_old jsonb, p_new jsonb)
returns text
language sql stable
as $$
  with campos as (
    select key,
           nullif(p_old ->> key, '') as antes,
           nullif(p_new ->> key, '') as ahora
    from jsonb_object_keys(coalesce(p_new, '{}'::jsonb)) as key
    -- Ruido: cambian en cada guardado y no dicen nada del negocio.
    where key not in ('updated_at', 'created_at', 'id', 'product_id')
  ),
  cambiados as (
    select key, antes, ahora from campos
    where antes is distinct from ahora
  )
  select nullif(string_agg(
    public.etiqueta_columna(key) || ': ' ||
    -- Un precio de tono vacío no es "nada": es que hereda el del producto.
    -- Decir "(vacío)" ahí seria mentir por omisión.
    coalesce(
      public.nombre_referencia(key, antes),
      public.valor_legible(key, antes),
      case when key = 'price' then 'heredado del producto' else '(vacío)' end
    ) || ' → ' ||
    coalesce(
      public.nombre_referencia(key, ahora),
      public.valor_legible(key, ahora),
      case when key = 'price' then 'heredado del producto' else '(vacío)' end
    ),
    ' · ' order by key
  ), '')
  from cambiados;
$$;

grant execute on function public.etiqueta_columna(text)       to authenticated;
grant execute on function public.describir_cambio(jsonb, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- report_trazabilidad
--
-- Una fila por evento. `security_invoker` deja que RLS haga su trabajo:
-- `audit_logs` e `inventory_movements` son de admin, así que esto también.
-- ---------------------------------------------------------------------
drop view if exists public.report_trazabilidad;

create view public.report_trazabilidad with (security_invoker = true) as

-- 1) Movimientos de inventario
select
  m.product_id,
  m.variant_id,
  m.created_at                                   as fecha,
  'inventario'::text                             as familia,
  case
    when m.movement_type = 'purchase'                                    then 'Entrada a bodega'
    when m.movement_type = 'transfer' and m.quantity < 0                 then 'Salida de bodega'
    when m.movement_type = 'transfer' and m.quantity > 0                 then 'Entrada a inventario de venta'
    when m.movement_type = 'sale'                                        then 'Venta de mostrador'
    when m.movement_type = 'online_order'                                then 'Pedido online'
    when m.movement_type = 'return'                                      then 'Devolución'
    when m.movement_type = 'damage'                                      then 'Baja por daño'
    else 'Ajuste de inventario'
  end                                            as titulo,
  m.notes                                        as detalle,
  m.quantity                                     as unidades,
  m.unit_cost                                    as costo_unitario,
  case
    when m.reference_type = 'order' then (select o.order_number from public.orders o where o.id = m.reference_id)
    when m.reference_type = 'sale'  then (select coalesce(s.sale_number, 'POS-' || s.id) from public.sales s where s.id = m.reference_id)
    else null
  end                                            as documento,
  m.created_by::text                             as quien
from public.inventory_movements m

union all

-- 2) Auditoría de la ficha del producto
select
  a.record_id                                    as product_id,
  null::bigint                                   as variant_id,
  a.changed_at                                   as fecha,
  'ficha'::text                                  as familia,
  case a.action
    when 'INSERT'         then 'Producto creado'
    when 'DELETE'         then 'Producto eliminado'
    when 'STATUS_CHANGED' then 'Cambio de publicación'
    when 'PRICE_CHANGED'  then 'Cambio de precio'
    when 'DUPLICATED'     then 'Creado como copia de otro'
    else 'Ficha actualizada'
  end                                            as titulo,
  -- Para un INSERT no hay nada que comparar: la nota del evento explica más
  -- que listar los treinta campos con los que nació.
  coalesce(
    case when a.action = 'INSERT' then a.note else null end,
    public.describir_cambio(a.old_data, a.new_data),
    a.note
  )                                              as detalle,
  null::integer                                  as unidades,
  null::numeric                                  as costo_unitario,
  null::text                                     as documento,
  a.changed_by                                   as quien
from public.audit_logs a
where a.table_name = 'products'
  -- Un UPDATE que solo movió `updated_at` no es un evento que contar.
  and (a.action <> 'UPDATE' or public.describir_cambio(a.old_data, a.new_data) is not null)
  -- Y al revés: hasta hoy, cambiar precio o estado escribía DOS filas —la del
  -- trigger y una `logAudit` a mano—, así que la línea de tiempo contaba el
  -- mismo cambio dos veces. El código ya no las duplica, pero el histórico
  -- que quedó sí, y se colapsa aquí: gana la del trigger, que trae el diff
  -- completo en vez de una nota escrita a mano.
  and not (
    a.action in ('PRICE_CHANGED', 'STATUS_CHANGED')
    and exists (
      select 1 from public.audit_logs t
      where t.table_name = a.table_name and t.record_id = a.record_id
        and t.action = 'UPDATE'
        and abs(extract(epoch from (t.changed_at - a.changed_at))) < 5
    )
  )

union all

-- 3) Auditoría de los tonos
--
-- `record_id` es el id del tono, así que hay que resolver a qué producto
-- pertenece. Si el tono ya no existe, se recupera del propio `new_data`:
-- el evento sigue siendo parte de la historia del producto.
select
  coalesce(v.product_id, (a.new_data ->> 'product_id')::bigint, (a.old_data ->> 'product_id')::bigint) as product_id,
  a.record_id                                    as variant_id,
  a.changed_at                                   as fecha,
  'tono'::text                                   as familia,
  case a.action
    when 'INSERT'        then 'Tono añadido'
    when 'DELETE'        then 'Tono eliminado'
    when 'PRICE_CHANGED' then 'Cambio de precio del tono'
    when 'BATCH_INSERT'  then 'Tonos añadidos por lote'
    else 'Tono actualizado'
  end                                            as titulo,
  -- En un alta de tono el nombre ya se muestra como etiqueta al lado del
  -- título; repetirlo en el detalle dejaba "Tono añadido / Marfil / Marfil".
  case when a.action = 'INSERT' then nullif(a.note, a.new_data ->> 'name')
       else coalesce(public.describir_cambio(a.old_data, a.new_data), a.note)
  end                                            as detalle,
  null::integer, null::numeric, null::text,
  a.changed_by                                   as quien
from public.audit_logs a
left join public.product_variants v on v.id = a.record_id
where a.table_name = 'product_variants'
  and (a.action <> 'UPDATE' or public.describir_cambio(a.old_data, a.new_data) is not null)
  and not (
    a.action = 'PRICE_CHANGED'
    and exists (
      select 1 from public.audit_logs t
      where t.table_name = a.table_name and t.record_id = a.record_id
        and t.action = 'UPDATE'
        and abs(extract(epoch from (t.changed_at - a.changed_at))) < 5
    )
  );

grant select on public.report_trazabilidad to authenticated;

comment on view public.report_trazabilidad is
  'Linea de tiempo por producto: movimientos de inventario + auditoria de ficha y tonos, ya traducida a lenguaje humano.';

-- El editor pide la historia de UN producto y la ordena por fecha: sin esto
-- se recorre `audit_logs` entera cada vez que se abre la pestaña.
create index if not exists ix_audit_logs_tabla_registro
  on public.audit_logs (table_name, record_id, changed_at desc);

create index if not exists ix_inventory_movements_producto_fecha
  on public.inventory_movements (product_id, created_at desc);
