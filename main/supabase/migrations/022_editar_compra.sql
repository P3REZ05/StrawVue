-- =====================================================================
-- 022_editar_compra.sql
-- Una compra al proveedor se puede corregir.
--
-- CONTEXTO
-- Registrar una compra era un camino de ida. Si te equivocabas al teclear la
-- cantidad o el costo, no había forma de arreglarlo desde el panel: la orden
-- quedaba mal para siempre y con ella el costo promedio, que es de donde sale
-- el margen de los reportes.
--
-- Y el registro tampoco era atómico. `purchases.js` hacía tres INSERT
-- seguidos —cabecera, líneas, movimientos— y su propio comentario admitía el
-- problema: si fallaba el segundo, quedaba una orden sin productos; si fallaba
-- el tercero, una orden con productos que nunca entraron a bodega. Los
-- mensajes de error explicaban cómo arreglarlo a mano, que es la señal de que
-- hacía falta una transacción.
--
-- DECISIONES
--
--  1. UN SOLO CAMINO PARA CREAR Y CORREGIR. `save_purchase_order` con
--     `p_order_id` nulo crea; con id, corrige. Dos funciones casi iguales
--     acaban divergiendo, como pasó con el mapeo de estados del pedido.
--
--  2. NO SE BORRA NI UNA FILA DE `inventory_movements`. La corrección se
--     escribe como movimientos nuevos que anulan los anteriores y vuelven a
--     meter la cantidad correcta. El historial cuenta lo que pasó de verdad:
--     que te equivocaste y lo arreglaste. Es la misma regla que ya se aplica
--     a las devoluciones.
--
--  3. LA ANULACIÓN ES UN `purchase` NEGATIVO, no un `adjustment`. Un ajuste no
--     cuenta para el costo promedio, así que anular con ajustes dejaría el
--     promedio calculado sobre unidades que nunca se compraron: el margen de
--     los reportes saldría mal y nadie lo notaría. Con un `purchase` del signo
--     contrario y el mismo costo, la media se corrige sola.
--     (Esto obliga a tocar `costo_promedio`, abajo.)
--
--  4. NO SE PUEDE BAJAR UNA COMPRA POR DEBAJO DE LO QUE YA SALIÓ DE BODEGA.
--     Si compraste 40, pasaste 30 a la vitrina y ahora dices que fueron 20,
--     la bodega quedaría en −10. La función lo comprueba y lo explica.
--
--  5. EL PROVEEDOR Y EL NÚMERO DE ORDEN SÍ SE CAMBIAN LIBREMENTE: no mueven
--     ni una unidad.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. `costo_promedio` deja de ignorar las cantidades negativas.
--
-- Filtraba `quantity > 0` porque hasta hoy no existían compras negativas.
-- A partir de ahora una corrección es exactamente eso, y si se filtra, anular
-- una compra de 40 unidades a $30.000 dejaría esas 40 contando para siempre
-- en la media. Sin el filtro, la suma ponderada se cancela sola:
--   (40 × 30.000) + (−40 × 30.000) + (25 × 32.000)  /  (40 − 40 + 25) = 32.000
-- ---------------------------------------------------------------------
create or replace function public.costo_promedio(
  p_product_id bigint,
  p_variant_id bigint default null
) returns numeric
language sql stable security definer
set search_path = public
as $$
  select coalesce(
    sum(quantity * coalesce(unit_cost, 0)) / nullif(sum(quantity), 0),
    0
  )::numeric(12,2)
  from public.inventory_movements
  where movement_type = 'purchase'
    and product_id = p_product_id
    and (p_variant_id is null or variant_id is not distinct from p_variant_id);
$$;

comment on function public.costo_promedio(bigint, bigint) is
  'Costo promedio ponderado de las compras. Cuenta tambien las compras negativas, que es como se anula una compra mal registrada (migracion 022).';

grant execute on function public.costo_promedio(bigint, bigint) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Crear o corregir una orden de compra, en una sola transacción.
-- ---------------------------------------------------------------------
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

  -- Las líneas, normalizadas y agrupadas: dos líneas del mismo producto y
  -- tono son una sola compra de la suma. Si no se agrupan, la comparación
  -- contra lo que ya hay en bodega se hace dos veces sobre la misma fila.
  create temporary table if not exists tmp_lineas_compra (
    product_id bigint,
    variant_id bigint,
    quantity   integer,
    unit_cost  numeric(12,2)
  ) on commit drop;
  delete from tmp_lineas_compra;

  for linea in select * from jsonb_array_elements(p_items) loop
    if (linea->>'product_id') is null then
      raise exception 'Hay una linea de la compra sin producto.' using errcode = 'check_violation';
    end if;
    if coalesce((linea->>'quantity')::integer, 0) <= 0 then
      raise exception 'Las cantidades de la compra deben ser mayores a cero.' using errcode = 'check_violation';
    end if;

    insert into tmp_lineas_compra (product_id, variant_id, quantity, unit_cost)
    values (
      (linea->>'product_id')::bigint,
      nullif(linea->>'variant_id', '')::bigint,
      (linea->>'quantity')::integer,
      coalesce((linea->>'unit_cost')::numeric, 0)
    );
  end loop;

  -- Agrupar duplicados conservando el costo ponderado.
  create temporary table if not exists tmp_lineas_final (
    product_id bigint,
    variant_id bigint,
    quantity   integer,
    unit_cost  numeric(12,2)
  ) on commit drop;
  delete from tmp_lineas_final;

  insert into tmp_lineas_final (product_id, variant_id, quantity, unit_cost)
  select product_id,
         variant_id,
         sum(quantity)::integer,
         (sum(quantity * unit_cost) / nullif(sum(quantity), 0))::numeric(12,2)
  from tmp_lineas_compra
  group by product_id, variant_id;

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
  'Crea (p_order_id nulo) o corrige una orden de compra, con sus lineas y su entrada a bodega, en una sola transaccion. La correccion anula con movimientos nuevos; no borra historial.';

grant execute on function public.save_purchase_order(bigint, bigint, text, date, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Comprobación.
-- ---------------------------------------------------------------------
select 'save_purchase_order' as funcion,
       (select count(*) from pg_proc where proname = 'save_purchase_order') as existe;
