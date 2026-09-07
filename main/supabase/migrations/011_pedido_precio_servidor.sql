-- =====================================================================
-- 011_pedido_precio_servidor.sql
-- El precio del pedido lo calcula la base, no el navegador.
--
-- ANTES
--   insert into order_items (..., unit_price)
--   select ..., unit_price from jsonb_to_recordset(items_data)
--   -- y el total del pedido y del pago salian de order_data->>'total'
--
-- Es decir: el cliente decidia cuanto pagaba. Con promociones activas el
-- problema se agrava, porque un total distinto al de lista deja de ser una
-- señal de alarma.
--
-- AHORA el cliente manda solo producto, tono, cantidad y, si lo tiene, el
-- codigo del cupon. Todo lo demas lo resuelve el servidor:
--   precio unitario -> precio_efectivo() con la mejor promocion vigente
--   subtotal        -> suma de lineas
--   cupon           -> validado contra la base, con su compra minima
--   envio           -> store_settings, gratis si supera el umbral
--   total           -> subtotal - descuento + envio
--
-- El RPC devuelve los importes calculados para que la interfaz muestre
-- exactamente lo que quedo guardado.
-- =====================================================================

-- Cambia la firma de salida (ahora devuelve los importes calculados), asi que
-- hay que soltar la version anterior antes de recrearla.
drop function if exists public.create_order_with_stock(jsonb, jsonb, jsonb, text);

create or replace function public.create_order_with_stock(
  customer_data jsonb,
  order_data jsonb,
  items_data jsonb,
  payment_method text default 'transfer'
)
returns table (
  order_id bigint,
  order_number text,
  subtotal numeric,
  discount numeric,
  shipping numeric,
  total numeric,
  promo_note text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  nuevo_customer_id  bigint;
  nuevo_order_id     bigint;
  nuevo_order_number text;
  linea              record;
  stock_disponible   integer;
  calc_subtotal      numeric(12,2) := 0;
  calc_descuento     numeric(12,2) := 0;
  calc_envio         numeric(12,2) := 0;
  calc_total         numeric(12,2) := 0;
  costo_envio        numeric(12,2);
  umbral_gratis      numeric(12,2);
  codigo_cupon       text;
  cupon              public.promotions%rowtype;
  nota               text := '';
begin
  if items_data is null or jsonb_array_length(items_data) = 0 then
    raise exception 'El pedido debe contener al menos un producto';
  end if;

  -- 1) Bloqueo ordenado por producto/tono, para que dos pedidos simultaneos
  --    por la ultima unidad no se pisen.
  for linea in
    select distinct product_id, variant_id
    from jsonb_to_recordset(items_data) as filas(product_id bigint, variant_id bigint)
    order by product_id nulls last, variant_id nulls last
  loop
    perform pg_advisory_xact_lock(
      hashtextextended(coalesce(linea.product_id::text,'') || ':' || coalesce(linea.variant_id::text,''), 0)
    );
  end loop;

  -- 2) Validar stock y calcular el subtotal con precios de la base.
  for linea in
    select product_id, variant_id, sum(quantity)::integer as quantity
    from jsonb_to_recordset(items_data) as filas(product_id bigint, variant_id bigint, quantity integer)
    group by product_id, variant_id
  loop
    if linea.quantity is null or linea.quantity <= 0 then
      raise exception 'La cantidad solicitada debe ser mayor a cero';
    end if;

    if not exists (select 1 from public.products where id = linea.product_id and active) then
      raise exception 'Uno de los productos ya no esta disponible';
    end if;

    stock_disponible := public.available_sale_stock(linea.product_id, linea.variant_id);
    if linea.quantity > stock_disponible then
      raise exception 'Stock insuficiente para % (disponibles: %)',
        coalesce((select name from public.products where id = linea.product_id), 'el producto'),
        stock_disponible;
    end if;

    calc_subtotal := calc_subtotal + linea.quantity * public.precio_efectivo(linea.product_id, linea.variant_id);
  end loop;

  -- 3) Cupon, si lo hay. Se valida contra la base: vigencia, usos y compra minima.
  codigo_cupon := nullif(trim(order_data->>'coupon'), '');
  if codigo_cupon is not null then
    select * into cupon from public.promotions
    where code is not null and upper(code) = upper(codigo_cupon);

    if not found then
      raise exception 'El cupon "%" no existe', codigo_cupon;
    end if;
    if not public.promo_vigente(cupon) then
      raise exception 'El cupon "%" ya no esta vigente', codigo_cupon;
    end if;
    if cupon.min_purchase is not null and calc_subtotal < cupon.min_purchase then
      raise exception 'El cupon "%" requiere una compra minima de %', codigo_cupon, cupon.min_purchase;
    end if;

    if cupon.type = 'percent' then
      calc_descuento := round(calc_subtotal * cupon.value / 100.0, 2);
    elsif cupon.type in ('fixed', 'coupon') then
      calc_descuento := least(cupon.value, calc_subtotal);
    end if;

    nota := format('Cupon %s aplicado', upper(codigo_cupon));
    update public.promotions set uses_count = uses_count + 1 where id = cupon.id;
  end if;

  -- 4) Envio. Gratis por encima del umbral, o por una promocion de tipo shipping.
  costo_envio   := public.config_numero('shippingCost', 0);
  umbral_gratis := public.config_numero('freeShippingThreshold', 0);
  calc_envio    := costo_envio;

  if umbral_gratis > 0 and (calc_subtotal - calc_descuento) >= umbral_gratis then
    calc_envio := 0;
    nota := trim(both ' · ' from nota || ' · Envio gratis por monto');
  else
    if exists (
      select 1 from public.promotions pr
      where pr.type = 'shipping' and pr.code is null and public.promo_vigente(pr)
        and (pr.min_purchase is null or (calc_subtotal - calc_descuento) >= pr.min_purchase)
    ) then
      calc_envio := 0;
      nota := trim(both ' · ' from nota || ' · Envio gratis por promocion');
    end if;
  end if;

  calc_total := greatest(calc_subtotal - calc_descuento, 0) + calc_envio;

  -- 5) Cliente
  insert into public.customers (full_name, document_number, phone, email, city, address, notes)
  values (
    customer_data->>'name',
    nullif(customer_data->>'document',''),
    customer_data->>'phone',
    nullif(customer_data->>'email',''),
    customer_data->>'city',
    customer_data->>'address',
    nullif(customer_data->>'notes','')
  )
  returning id into nuevo_customer_id;

  -- 6) Pedido con los importes calculados aqui
  insert into public.orders (customer_id, subtotal, shipping_cost, total, status, notes)
  values (
    nuevo_customer_id, calc_subtotal, calc_envio, calc_total, 'pending',
    trim(both ' · ' from coalesce(nullif(customer_data->>'notes',''), '') || case when nota <> '' then ' · ' || nota else '' end)
  )
  returning id into nuevo_order_id;

  nuevo_order_number := 'ORD-' || nuevo_order_id;
  update public.orders set order_number = nuevo_order_number where id = nuevo_order_id;

  -- 7) Lineas, con el precio del servidor y el nombre del tono resuelto aqui,
  --    para que la factura no dependa de lo que mandara el navegador.
  insert into public.order_items (order_id, product_id, variant_id, product_name, quantity, unit_price)
  select
    nuevo_order_id,
    f.product_id,
    f.variant_id,
    trim(p.name || coalesce(' - ' || nullif(trim(coalesce(v.shade_code,'') || ' ' || v.name), ''), '')),
    sum(f.quantity)::integer,
    public.precio_efectivo(f.product_id, f.variant_id)
  from jsonb_to_recordset(items_data) as f(product_id bigint, variant_id bigint, quantity integer)
  join public.products p on p.id = f.product_id
  left join public.product_variants v on v.id = f.variant_id
  group by f.product_id, f.variant_id, p.name, v.shade_code, v.name;

  -- 8) Salida de stock, agrupada: una fila por producto/tono.
  insert into public.inventory_movements (product_id, variant_id, movement_type, quantity, reference_type, reference_id, notes)
  select product_id, variant_id, 'online_order', -sum(quantity)::integer, 'order', nuevo_order_id,
         'Salida por pedido online ' || nuevo_order_number
  from jsonb_to_recordset(items_data) as f(product_id bigint, variant_id bigint, quantity integer)
  group by product_id, variant_id;

  insert into public.payments (order_id, payment_method, amount, status)
  values (nuevo_order_id, coalesce(nullif(payment_method,''), 'transfer'), calc_total, 'pending');

  insert into public.shipments (order_id, shipping_cost, status)
  values (nuevo_order_id, calc_envio, 'pending');

  return query select nuevo_order_id, nuevo_order_number, calc_subtotal, calc_descuento, calc_envio, calc_total, nullif(nota,'');
end;
$$;

grant execute on function public.create_order_with_stock(jsonb, jsonb, jsonb, text) to anon, authenticated;
