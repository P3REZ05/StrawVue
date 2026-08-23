-- Creacion atomica de pedidos online con validacion de stock.
-- Ejecutar despues de schema.sql.

drop trigger if exists order_item_inventory_movement on public.order_items;

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
  new_customer_id bigint;
  new_order_id bigint;
  new_order_number text;
  item record;
  available_stock integer;
begin
  if jsonb_array_length(items_data) = 0 then
    raise exception 'El pedido debe contener al menos un producto';
  end if;

  -- Serializa pedidos concurrentes que afectan el mismo producto o variante.
  perform pg_advisory_xact_lock(
    hashtextextended(coalesce(item.product_id::text, '') || ':' || coalesce(item.variant_id::text, ''), 0)
  )
  from (
    select distinct product_id, variant_id
    from jsonb_to_recordset(items_data) as rows(product_id bigint, variant_id bigint)
    order by product_id nulls last, variant_id nulls last
  ) as item;

  for item in
    select product_id, variant_id, sum(quantity)::integer as quantity, max(product_name) as product_name, max(unit_price) as unit_price
    from jsonb_to_recordset(items_data)
      as rows(product_id bigint, variant_id bigint, quantity integer, product_name text, unit_price numeric)
    group by product_id, variant_id
  loop
    if item.quantity is null or item.quantity <= 0 then
      raise exception 'La cantidad solicitada debe ser mayor a cero';
    end if;

    select coalesce(sum(case
      when movement_type = 'transfer' and reference_type = 'sale_inventory' then quantity
      when movement_type in ('sale', 'online_order') then quantity
      else 0
    end), 0)::integer
    into available_stock
    from public.inventory_movements
    where product_id = item.product_id
      and variant_id is not distinct from item.variant_id;

    if item.quantity > available_stock then
      raise exception 'Stock insuficiente para % (disponibles: %)', item.product_name, available_stock;
    end if;
  end loop;

  insert into public.customers (full_name, document_number, phone, city, address, notes)
  values (
    customer_data->>'name',
    nullif(customer_data->>'document', ''),
    customer_data->>'phone',
    customer_data->>'city',
    customer_data->>'address',
    nullif(customer_data->>'notes', '')
  )
  returning id into new_customer_id;

  insert into public.orders (customer_id, subtotal, shipping_cost, total, status, notes)
  values (
    new_customer_id,
    (order_data->>'subtotal')::numeric,
    (order_data->>'shipping')::numeric,
    (order_data->>'total')::numeric,
    'pending',
    nullif(customer_data->>'notes', '')
  )
  returning id into new_order_id;

  new_order_number := 'ORD-' || new_order_id;
  update public.orders
  set order_number = new_order_number
  where id = new_order_id;

  insert into public.order_items (order_id, product_id, variant_id, product_name, quantity, unit_price)
  select new_order_id, product_id, variant_id, product_name, quantity, unit_price
  from jsonb_to_recordset(items_data)
    as rows(product_id bigint, variant_id bigint, product_name text, quantity integer, unit_price numeric);

  insert into public.inventory_movements (
    product_id, variant_id, movement_type, quantity, reference_type, reference_id, notes
  )
  select product_id, variant_id, 'online_order', -quantity, 'order', new_order_id,
    'Salida atomica por pedido online'
  from jsonb_to_recordset(items_data)
    as rows(product_id bigint, variant_id bigint, quantity integer);

  insert into public.payments (order_id, payment_method, amount, status)
  values (new_order_id, coalesce(nullif(payment_method, ''), 'transfer'), (order_data->>'total')::numeric, 'pending');

  insert into public.shipments (order_id, shipping_cost, status)
  values (new_order_id, (order_data->>'shipping')::numeric, 'pending');

  return query select new_order_id, new_order_number;
end;
$$;

grant execute on function public.create_order_with_stock(jsonb, jsonb, jsonb, text) to anon, authenticated;