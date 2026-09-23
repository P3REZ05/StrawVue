-- =====================================================================
-- 024_compra_sin_delete_sin_where.sql
-- «DELETE requires a WHERE clause» al registrar una compra.
--
-- CONTEXTO
-- Supabase tiene activada la protección `safeupdate`, que rechaza cualquier
-- `DELETE` o `UPDATE` sin cláusula `WHERE`. Es una red de seguridad sensata:
-- un `delete from pedidos` sin `where` de madrugada se lleva la tienda por
-- delante.
--
-- `save_purchase_order` (migración 022) creaba dos tablas temporales con
-- `create temporary table if not exists` y las vaciaba con `delete from tabla;`
-- —sin `where`, porque la intención era vaciarlas enteras—. La protección lo
-- bloqueaba y la compra no se registraba nunca.
--
-- Esto no se vio al probar la 022 en un Postgres local porque `safeupdate` es
-- una extensión que Supabase carga y el Postgres de pruebas no tenía. Queda
-- apuntado en CLAUDE.md: el SQL de este proyecto no lleva DML sin `WHERE`,
-- ni siquiera sobre tablas temporales.
--
-- QUÉ CAMBIA
-- La función deja de usar dos tablas temporales y usa una, creada **ya llena**
-- con `create table as` a partir del JSON. Sin `delete`, sin `insert` previo y
-- con un paso menos: la normalización y la agrupación son ahora una sola
-- consulta.
--
-- El resto de la función no cambia: mismo contrato, mismas comprobaciones,
-- misma forma de anular una compra corregida sin borrar historial.
--
-- AL EJECUTARLA, el editor de Supabase avisa de que «se crea una tabla sin
-- Row Level Security». Elige **Run without RLS**: es una tabla TEMPORAL, vive
-- dentro de la propia transacción y solo la ve la conexión que la creó; no hay
-- nada que proteger ni nadie a quien dejar fuera. El aviso salta porque el
-- editor busca el texto `create table`, no porque haya un riesgo real.
-- =====================================================================

create or replace function public.save_purchase_order(
  p_order_id     bigint,
  p_supplier_id  bigint,
  p_order_number text,
  p_order_date   date,
  p_notes        text,
  p_items        jsonb
) returns bigint
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  id_orden     bigint := p_order_id;
  numero       text;
  es_correccion boolean := p_order_id is not null;
  total_orden  numeric(12,2) := 0;
  linea        jsonb;
  fila         record;
  quedaria     integer;
  en_bodega    integer;
begin
  -- `security definer` salta RLS: la puerta la ponemos aquí.
  if not public.is_admin() then
    raise exception 'Solo un administrador puede registrar compras.'
      using errcode = 'insufficient_privilege';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'La orden de compra debe tener al menos un producto.'
      using errcode = 'check_violation';
  end if;

  -- Validación línea a línea antes de tocar nada.
  for linea in select * from jsonb_array_elements(p_items) loop
    if (linea->>'product_id') is null then
      raise exception 'Hay una linea de la compra sin producto.' using errcode = 'check_violation';
    end if;
    if coalesce((linea->>'quantity')::integer, 0) <= 0 then
      raise exception 'Las cantidades de la compra deben ser mayores a cero.' using errcode = 'check_violation';
    end if;
  end loop;

  -- Las líneas, normalizadas y agrupadas: dos líneas del mismo producto y
  -- tono son una sola compra de la suma, con el costo ponderado. Si no se
  -- agrupan, la comparación contra lo que ya hay en bodega se haría dos veces
  -- sobre la misma fila.
  --
  -- La tabla se crea YA LLENA con `create table as` y se tira antes por si
  -- acaso. La versión anterior la creaba vacía con `if not exists` y la
  -- vaciaba con un `delete` sin `where`, y eso es justo lo que rechaza la
  -- protección `safeupdate` que Supabase tiene activada: «DELETE requires a
  -- WHERE clause». Era un error de esta función, no de la configuración —
  -- vaciar una tabla entera es `truncate`, y no hacía falta ni eso.
  -- `drop table if exists pg_temp....` avisa en cada llamada mientras la
  -- sesión no haya creado todavía ninguna tabla temporal («schema pg_temp does
  -- not exist»). No es un error, pero ensucia el log de cada compra.
  if to_regclass('pg_temp.tmp_lineas_final') is not null then
    execute 'drop table pg_temp.tmp_lineas_final';
  end if;

  create temporary table tmp_lineas_final on commit drop as
  select (item->>'product_id')::bigint                                  as product_id,
         nullif(item->>'variant_id', '')::bigint                        as variant_id,
         sum((item->>'quantity')::integer)::integer                     as quantity,
         (sum((item->>'quantity')::integer * coalesce((item->>'unit_cost')::numeric, 0))
            / nullif(sum((item->>'quantity')::integer), 0))::numeric(12,2) as unit_cost
  from jsonb_array_elements(p_items) as item
  group by 1, 2;

  select coalesce(sum(quantity * unit_cost), 0) into total_orden from tmp_lineas_final;

  -- -------------------------------------------------------------------
  -- Cabecera
  -- -------------------------------------------------------------------
  if es_correccion then
    -- Dos pestañas corrigiendo la misma orden a la vez se pisarían los
    -- movimientos de corrección. La segunda espera.
    perform pg_advisory_xact_lock(hashtext('purchase_order'), id_orden::integer);

    select order_number into numero from public.purchase_orders where id = id_orden for update;
    if not found then
      raise exception 'La orden de compra % ya no existe.', id_orden using errcode = 'no_data_found';
    end if;

    update public.purchase_orders
       set supplier_id  = p_supplier_id,
           order_number = coalesce(nullif(btrim(p_order_number), ''), order_number),
           order_date   = coalesce(p_order_date, order_date),
           notes        = p_notes,
           total        = total_orden
     where id = id_orden;
  else
    insert into public.purchase_orders (supplier_id, order_number, order_date, notes, status, total)
    values (p_supplier_id,
            nullif(btrim(p_order_number), ''),
            coalesce(p_order_date, current_date),
            p_notes,
            'received',
            total_orden)
    returning id, order_number into id_orden, numero;

    perform pg_advisory_xact_lock(hashtext('purchase_order'), id_orden::integer);
  end if;

  numero := coalesce(numero, 'PO-' || id_orden);

  -- -------------------------------------------------------------------
  -- Comprobar ANTES de tocar nada que la corrección es posible.
  --
  -- Lo que esta orden metió en bodega, contra lo que la orden va a decir
  -- ahora. Si la diferencia deja la bodega en negativo, es que parte de esa
  -- mercancía ya salió: no se puede desdecir.
  -- -------------------------------------------------------------------
  if es_correccion then
    for fila in
      select coalesce(l.product_id, s.product_id) as product_id,
             coalesce(l.variant_id, s.variant_id) as variant_id,
             coalesce(s.puestas, 0)               as puestas,
             coalesce(l.quantity, 0)              as nuevas
      from (
        select product_id, variant_id, sum(quantity)::integer as puestas
        from public.inventory_movements
        where movement_type = 'purchase'
          and reference_type = 'purchase_order'
          and reference_id = id_orden
        group by product_id, variant_id
        having sum(quantity) <> 0
      ) s
      full outer join tmp_lineas_final l
        on l.product_id = s.product_id
       and l.variant_id is not distinct from s.variant_id
    loop
      if fila.nuevas - fila.puestas < 0 then
        -- Bodega de ESA combinación producto+tono, no del producto entero:
        -- bajar la compra de un tono no se puede pagar con el stock de otro.
        select coalesce(sum(public.movement_warehouse_delta(movement_type, reference_type, quantity)), 0)::integer
          into en_bodega
          from public.inventory_movements
         where product_id = fila.product_id
           and variant_id is not distinct from fila.variant_id;

        quedaria := en_bodega + (fila.nuevas - fila.puestas);
        if quedaria < 0 then
          raise exception
            'No se puede bajar esa linea a % unidad(es): ya pasaste parte de la mercancia a la vitrina y la bodega quedaria en %. Devuelvela primero desde «Listo para vender», o deja la cantidad en % o mas.',
            fila.nuevas, quedaria, fila.puestas - en_bodega
            using errcode = 'check_violation';
        end if;
      end if;
    end loop;

    -- Anular lo que esta orden había metido. Se agrupa por costo para que la
    -- anulación sea exacta y para que corregir dos veces no cuente doble.
    insert into public.inventory_movements
      (product_id, variant_id, movement_type, quantity, unit_cost, reference_type, reference_id, notes)
    select product_id, variant_id, 'purchase', -sum(quantity), unit_cost,
           'purchase_order', id_orden,
           'Correccion de la compra ' || numero || ': anula la entrada anterior'
    from public.inventory_movements
    where movement_type = 'purchase'
      and reference_type = 'purchase_order'
      and reference_id = id_orden
    group by product_id, variant_id, unit_cost
    having sum(quantity) <> 0;

    delete from public.purchase_order_items where purchase_order_id = id_orden;
  end if;

  -- -------------------------------------------------------------------
  -- Líneas y entrada a bodega
  -- -------------------------------------------------------------------
  insert into public.purchase_order_items
    (purchase_order_id, product_id, variant_id, quantity, unit_cost, destination)
  select id_orden, product_id, variant_id, quantity, unit_cost, 'warehouse'
  from tmp_lineas_final;

  insert into public.inventory_movements
    (product_id, variant_id, movement_type, quantity, unit_cost, reference_type, reference_id, notes)
  select product_id, variant_id, 'purchase', quantity, unit_cost,
         'purchase_order', id_orden,
         case when es_correccion
              then 'Entrada a bodega por compra · corregida ' || numero
              else 'Entrada a bodega por compra' end
  from tmp_lineas_final;

  return id_orden;
end;
$$;


comment on function public.save_purchase_order(bigint, bigint, text, date, text, jsonb) is
  'Crea (p_order_id nulo) o corrige una orden de compra, con sus lineas y su entrada a bodega, en una sola transaccion. La correccion anula con movimientos nuevos; no borra historial. Sin DML sin WHERE: la proteccion safeupdate de Supabase lo rechaza.';

grant execute on function public.save_purchase_order(bigint, bigint, text, date, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- Comprobación: la función no debe contener ningún DELETE ni UPDATE sin
-- WHERE. Se mira el propio código fuente guardado en el catálogo.
-- ---------------------------------------------------------------------
select
  (select count(*) from pg_proc where proname = 'save_purchase_order')                  as existe,
  (select prosrc ~* '(delete\s+from|update)\s+[a-z_.]+\s*;' from pg_proc
    where proname = 'save_purchase_order')                                              as tiene_dml_sin_where;
