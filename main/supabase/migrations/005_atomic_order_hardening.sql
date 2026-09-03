-- =====================================================================
-- 005_atomic_order_hardening.sql
-- Corrige: B-7 (crítico), B-11
--
-- CONTEXTO
-- B-11: en create_order_with_stock, `item` estaba declarado como variable
--       RECORD y usado a la vez como alias de una subconsulta. Con el
--       ajuste por defecto plpgsql.variable_conflict = error, Postgres
--       aborta con "column reference item.product_id is ambiguous".
--       La reserva atómica nunca pudo ejecutarse.
--
-- B-7:  schema.sql crea el trigger order_item_inventory_movement, que
--       descuenta stock al insertar order_items. atomic_order.sql lo
--       borra porque el RPC ya inserta los movimientos. Si alguien vuelve
--       a ejecutar schema.sql completo, el trigger reaparece y cada
--       pedido descuenta DOS veces, en silencio.
--       Se añade un índice único que convierte ese doble descuento en un
--       error inmediato en vez de una pérdida silenciosa de inventario.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) El RPC es el único que registra la salida de stock del pedido.
-- ---------------------------------------------------------------------
drop trigger if exists order_item_inventory_movement on public.order_items;

-- ---------------------------------------------------------------------
-- 2) Red de seguridad estructural contra el doble descuento.
--    Sobrevive a una reejecución de schema.sql (que no borra índices).
-- ---------------------------------------------------------------------
create unique index if not exists ux_inventory_movements_pedido_unico
on public.inventory_movements (reference_id, product_id, coalesce(variant_id, 0))
where movement_type = 'online_order' and reference_type = 'order';

-- ---------------------------------------------------------------------
-- 3) RPC de creación atómica, corregido.
-- ---------------------------------------------------------------------
create or replace function public.create_order_with_stock(
  customer_data jsonb,
  order_data jsonb,
  items_data jsonb,
  payment_method text default 'transfer'
)
returns table (order_id bigint, order_number text)
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo_customer_id bigint;
  nuevo_order_id    bigint;
  nuevo_order_number text;
  linea             record;
  stock_disponible  integer;
begin
  if items_data is null or jsonb_array_length(items_data) = 0 then
    raise exception 'El pedido debe contener al menos un producto';
  end if;

  -- 3.1 Bloqueo consistente y ORDENADO por producto/variante.
  --     El orden determinista evita interbloqueos entre pedidos
  --     concurrentes que comparten productos.
  for linea in
    select distinct product_id, variant_id
    from jsonb_to_recordset(items_data) as filas(product_id bigint, variant_id bigint)
    order by product_id nulls last, variant_id nulls last
  loop
    perform pg_advisory_xact_lock(
      hashtextextended(
        coalesce(linea.product_id::text, '') || ':' || coalesce(linea.variant_id::text, ''),
        0
      )
    );
  end loop;

  -- 3.2 Validar stock ya con los bloqueos tomados.
  for linea in
    select product_id,
           variant_id,
           sum(quantity)::integer as quantity,
           max(product_name)      as product_name
    from jsonb_to_recordset(items_data)
      as filas(product_id bigint, variant_id bigint, quantity integer, product_name text)
    group by product_id, variant_id
  loop
    if linea.quantity is null or linea.quantity <= 0 then
      raise exception 'La cantidad solicitada debe ser mayor a cero';
    end if;

    stock_disponible := public.available_sale_stock(linea.product_id, linea.variant_id);

    if linea.quantity > stock_disponible then
      raise exception 'Stock insuficiente para % (disponibles: %)',
        coalesce(linea.product_name, 'el producto'), stock_disponible;
    end if;
  end loop;

  -- 3.3 Cliente
  insert into public.customers (full_name, document_number, phone, email, city, address, notes)
  values (
    customer_data->>'name',
    nullif(customer_data->>'document', ''),
    customer_data->>'phone',
    nullif(customer_data->>'email', ''),
    customer_data->>'city',
    customer_data->>'address',
    nullif(customer_data->>'notes', '')
  )
  returning id into nuevo_customer_id;

  -- 3.4 Pedido
  insert into public.orders (customer_id, subtotal, shipping_cost, total, status, notes)
  values (
    nuevo_customer_id,
    coalesce((order_data->>'subtotal')::numeric, 0),
    coalesce((order_data->>'shipping')::numeric, 0),
    coalesce((order_data->>'total')::numeric, 0),
    'pending',
    nullif(customer_data->>'notes', '')
  )
  returning id into nuevo_order_id;

  nuevo_order_number := 'ORD-' || nuevo_order_id;
  update public.orders set order_number = nuevo_order_number where id = nuevo_order_id;

  -- 3.5 Items del pedido
  insert into public.order_items (order_id, product_id, variant_id, product_name, quantity, unit_price)
  select nuevo_order_id, product_id, variant_id, product_name, quantity, unit_price
  from jsonb_to_recordset(items_data)
    as filas(product_id bigint, variant_id bigint, product_name text, quantity integer, unit_price numeric);

  -- 3.6 Salida de stock. AGRUPADA: una sola fila por producto/variante,
  --     que es lo que exige el índice único ux_inventory_movements_pedido_unico.
  insert into public.inventory_movements (
    product_id, variant_id, movement_type, quantity, reference_type, reference_id, notes
  )
  select product_id, variant_id, 'online_order', -sum(quantity)::integer, 'order', nuevo_order_id,
         'Salida por pedido online ' || nuevo_order_number
  from jsonb_to_recordset(items_data) as filas(product_id bigint, variant_id bigint, quantity integer)
  group by product_id, variant_id;

  -- 3.7 Pago y envío en estado inicial
  insert into public.payments (order_id, payment_method, amount, status)
  values (
    nuevo_order_id,
    coalesce(nullif(payment_method, ''), 'transfer'),
    coalesce((order_data->>'total')::numeric, 0),
    'pending'
  );

  insert into public.shipments (order_id, shipping_cost, status)
  values (nuevo_order_id, coalesce((order_data->>'shipping')::numeric, 0), 'pending');

  return query select nuevo_order_id, nuevo_order_number;
end;
$$;

grant execute on function public.create_order_with_stock(jsonb, jsonb, jsonb, text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 4) Devolución: reingresa stock con un movimiento COMPENSATORIO.
--    Antes el frontend hacía DELETE sobre inventory_movements, lo que
--    destruía la trazabilidad, que es justamente el principio central
--    del proyecto (B-9).
-- ---------------------------------------------------------------------
create or replace function public.return_order_stock(p_order_id bigint)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  filas_insertadas integer := 0;
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;

  -- Idempotente: si ya se devolvió, no vuelve a reingresar.
  if exists (
    select 1 from public.inventory_movements
    where reference_id = p_order_id and movement_type = 'return'
  ) then
    return 0;
  end if;

  insert into public.inventory_movements (
    product_id, variant_id, movement_type, quantity, reference_type, reference_id, notes
  )
  select product_id,
         variant_id,
         'return',
         -quantity,                -- la salida fue negativa: el reingreso es positivo
         'sale_inventory',         -- el producto vuelve al inventario de venta
         p_order_id,
         'Reingreso por devolucion del pedido ' || p_order_id
  from public.inventory_movements
  where reference_type = 'order'
    and reference_id = p_order_id
    and movement_type = 'online_order';

  get diagnostics filas_insertadas = row_count;
  return filas_insertadas;
end;
$$;

grant execute on function public.return_order_stock(bigint) to authenticated;
