-- =====================================================================
-- 016_combos_2x1.sql
-- El motor de promociones aprende a contar unidades.
--
-- CONTEXTO
-- `promotions.buy_quantity` y `get_quantity` existen desde la migración 010
-- y nunca se evaluaron: se podía crear un 2x1 en el panel y no descontaba
-- nada. El tipo `bundle` estaba en el `check` de la tabla y en el comentario
-- de la columna, pero no en el código.
--
-- POR QUÉ NO CABÍA EN `precio_efectivo`
-- Esa función responde "¿cuánto vale UNA unidad de esto?", y un 2x1 no tiene
-- respuesta a esa pregunta: la segunda unidad vale cero y la tercera vuelve a
-- costar. El descuento depende de cuántas lleves, así que se calcula sobre el
-- carrito entero, no sobre la línea.
--
-- DECISIONES DE NEGOCIO, tomadas a propósito
--
--  1. El combo cruza líneas. "2x1 en labiales" significa dos labiales
--     cualesquiera, no dos veces el mismo tono. Es lo que entiende la
--     clienta y lo que hace cualquier tienda.
--
--  2. Se regalan las unidades MÁS BARATAS del grupo. Si lleva un labial de
--     $30.000 y otro de $20.000, el gratis es el de $20.000. Al revés sería
--     regalar margen, y ninguna tienda lo hace.
--
--  3. Solo se aplica UN combo, el que más descuento deje. Es la misma regla
--     que ya sigue `promo_para_producto` para `percent` y `fixed`: acumular
--     descuentos sin querer es como se regala el margen.
--
--  4. El combo SÍ se suma a un cupón, porque son ejes distintos: el combo
--     premia llevar cantidad y el cupón es una campaña. Eso ya pasaba con
--     `percent` + cupón, así que no se introduce una inconsistencia nueva.
--
--  5. Las unidades se valoran a `precio_efectivo`, no al precio de lista: si
--     el labial ya está al -20%, la unidad regalada vale lo que la clienta
--     habría pagado, no lo que decía la etiqueta.
-- =====================================================================

-- `bundle` ya estaba permitido en el check original de `promotions.type`.
-- Se reafirma aquí por si el esquema se reconstruyera desde cero.
alter table public.promotions drop constraint if exists promotions_type_check;
alter table public.promotions add constraint promotions_type_check
  check (type in ('percent', 'fixed', 'bundle', 'shipping', 'coupon', 'category'));

-- Un combo sin cantidades es un combo que no hace nada. Mejor que la base lo
-- rechace al crearlo que descubrirlo cuando una clienta no ve su descuento.
alter table public.promotions drop constraint if exists promotions_bundle_check;
alter table public.promotions add constraint promotions_bundle_check
  check (
    type <> 'bundle'
    or (
      buy_quantity is not null and buy_quantity >= 2
      and get_quantity is not null and get_quantity >= 1
      and get_quantity < buy_quantity
    )
  );

comment on column public.promotions.buy_quantity is
  'Solo para type = bundle. Unidades que hay que llevar. En un 2x1, 2.';
comment on column public.promotions.get_quantity is
  'Solo para type = bundle. Unidades que se pagan. En un 2x1, 1.';

-- ---------------------------------------------------------------------
-- ¿Esta línea entra en esta promoción?
--
-- Misma regla de alcance que `promo_para_producto`, extraída aparte porque
-- ahora la usan dos sitios y tenerla duplicada es como divergen.
-- ---------------------------------------------------------------------
create or replace function public.promo_cubre_producto(
  p_promotion_id bigint,
  p_product_id   bigint,
  p_variant_id   bigint default null
) returns boolean
language sql stable
as $$
  select exists (
    select 1
    from public.promotions pr
    left join public.products p on p.id = p_product_id
    where pr.id = p_promotion_id
      and (
        pr.applies_to = 'all'
        or (pr.applies_to = 'category' and pr.category_id is not distinct from p.category_id)
        or (pr.applies_to = 'products' and exists (
              select 1 from public.promotion_products pp
              where pp.promotion_id = pr.id
                and pp.product_id = p_product_id
                and (pp.variant_id is null or pp.variant_id = p_variant_id)
           ))
      )
  );
$$;

grant execute on function public.promo_cubre_producto(bigint, bigint, bigint) to anon, authenticated;

-- ---------------------------------------------------------------------
-- descuento_combos
--
-- Recibe el carrito y devuelve el mejor combo aplicable, si hay alguno.
--   items_data: [{ "product_id": 5, "variant_id": 2, "quantity": 3 }, ...]
--
-- Devuelve una sola fila (o ninguna): la promoción que más descuento deja.
-- ---------------------------------------------------------------------
create or replace function public.descuento_combos(items_data jsonb)
returns table (
  promotion_id    bigint,
  titulo          text,
  etiqueta        text,
  unidades_gratis integer,
  descuento       numeric(12,2)
)
language sql stable
as $$
  with lineas as (
    select f.product_id, f.variant_id, sum(f.quantity)::integer as cantidad,
           public.precio_efectivo(f.product_id, f.variant_id) as precio
    from jsonb_to_recordset(coalesce(items_data, '[]'::jsonb))
         as f(product_id bigint, variant_id bigint, quantity integer)
    where f.product_id is not null and f.quantity > 0
    group by f.product_id, f.variant_id
  ),
  combos as (
    select pr.id, pr.title, pr.label, pr.buy_quantity, pr.get_quantity, pr.priority
    from public.promotions pr
    where pr.type = 'bundle'
      and pr.code is null              -- un combo con código lo activa el cupón
      and public.promo_vigente(pr)
  ),
  -- Cada unidad por separado, para poder elegir cuáles se regalan.
  unidades as (
    select c.id as promo_id, l.precio
    from combos c
    join lineas l on public.promo_cubre_producto(c.id, l.product_id, l.variant_id)
    cross join lateral generate_series(1, l.cantidad)
  ),
  -- Las más baratas primero: esas son las que se regalan.
  ordenadas as (
    select promo_id, precio,
           row_number() over (partition by promo_id order by precio asc) as puesto
    from unidades
  ),
  cuentas as (
    select c.id, c.title, c.label, c.priority,
           (count(o.*) / c.buy_quantity) * (c.buy_quantity - c.get_quantity) as gratis
    from combos c
    join ordenadas o on o.promo_id = c.id
    group by c.id, c.title, c.label, c.priority, c.buy_quantity, c.get_quantity
  )
  select cu.id, cu.title, cu.label, cu.gratis::integer,
         coalesce((
           select sum(o.precio) from ordenadas o
           where o.promo_id = cu.id and o.puesto <= cu.gratis
         ), 0)::numeric(12,2) as descuento
  from cuentas cu
  where cu.gratis > 0
  order by descuento desc, cu.priority desc
  limit 1;
$$;

grant execute on function public.descuento_combos(jsonb) to anon, authenticated;

comment on function public.descuento_combos(jsonb) is
  'Mejor combo aplicable al carrito. Regala las unidades mas baratas y nunca acumula dos combos.';

-- ---------------------------------------------------------------------
-- El pedido online aplica el combo.
--
-- Se reescribe `create_order_with_stock` entera porque cambia su firma de
-- salida: ahora devuelve tambien el descuento por combo, para que la
-- interfaz pueda decir POR QUE el total bajo.
-- ---------------------------------------------------------------------
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
  combo              record;
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

  -- 3) Combo (2x1 y similares). Va antes del cupon a proposito: el cupon se
  --    calcula sobre lo que realmente se esta pagando, no sobre el subtotal
  --    de lista. Al reves, un 2x1 con un cupon del 20% descontaria dos veces
  --    sobre la unidad regalada.
  select * into combo from public.descuento_combos(items_data);
  if found and combo.descuento > 0 then
    calc_descuento := calc_descuento + combo.descuento;
    nota := trim(both ' · ' from nota || ' · ' || combo.titulo ||
                 format(' (%s unidad(es) gratis)', combo.unidades_gratis));
  end if;

  -- 4) Cupon, si lo hay. Se valida contra la base: vigencia, usos y compra minima.
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
      calc_descuento := calc_descuento
        + round(greatest(calc_subtotal - calc_descuento, 0) * cupon.value / 100.0, 2);
    elsif cupon.type in ('fixed', 'coupon') then
      calc_descuento := calc_descuento
        + least(cupon.value, greatest(calc_subtotal - calc_descuento, 0));
    end if;

    nota := trim(both ' · ' from nota || ' · ' || format('Cupon %s aplicado', upper(codigo_cupon)));
    update public.promotions set uses_count = uses_count + 1 where id = cupon.id;
  end if;

  calc_descuento := least(calc_descuento, calc_subtotal);

  -- 5) Envio. Gratis por encima del umbral, o por una promocion de tipo shipping.
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

  -- 6) Cliente
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

  -- 7) Pedido con los importes calculados aqui
  insert into public.orders (customer_id, subtotal, discount_total, shipping_cost, total, status, notes)
  values (
    nuevo_customer_id, calc_subtotal, calc_descuento, calc_envio, calc_total, 'pending',
    trim(both ' · ' from coalesce(nullif(customer_data->>'notes',''), '') || case when nota <> '' then ' · ' || nota else '' end)
  )
  returning id into nuevo_order_id;

  nuevo_order_number := 'ORD-' || nuevo_order_id;
  update public.orders set order_number = nuevo_order_number where id = nuevo_order_id;

  -- 8) Lineas, con el precio del servidor y el nombre del tono resuelto aqui.
  --    El descuento del combo NO se reparte entre las lineas: queda como
  --    descuento de pedido. Repartirlo daria precios unitarios raros en la
  --    factura ("$0" en una unidad) y complicaria una devolucion parcial.
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

  -- 9) Salida de stock, agrupada: una fila por producto/tono.
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

-- ---------------------------------------------------------------------
-- El mostrador tambien aplica el combo.
--
-- Decision del negocio: el punto fisico cobra lo mismo que la web. Una
-- clienta que ve el 2x1 en Instagram y va al local espera el mismo precio.
-- ---------------------------------------------------------------------
drop function if exists public.create_pos_sale(jsonb, text, text, text);

create or replace function public.create_pos_sale(
  items_data     jsonb,
  payment_method text default 'cash',
  customer_name  text default null,
  notes          text default null
)
returns table (
  sale_id     bigint,
  sale_number text,
  subtotal    numeric,
  descuento   numeric,
  total       numeric,
  unidades    integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  nueva_sale_id     bigint;
  nuevo_sale_number text;
  linea             record;
  stock_disponible  integer;
  calc_subtotal     numeric(12,2) := 0;
  calc_descuento    numeric(12,2) := 0;
  calc_unidades     integer := 0;
  combo             record;
  nota_final        text;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede registrar ventas de mostrador';
  end if;

  if items_data is null or jsonb_array_length(items_data) = 0 then
    raise exception 'La venta debe contener al menos un producto';
  end if;

  for linea in
    select distinct product_id, variant_id
    from jsonb_to_recordset(items_data) as filas(product_id bigint, variant_id bigint)
    order by product_id nulls last, variant_id nulls last
  loop
    perform pg_advisory_xact_lock(
      hashtextextended(coalesce(linea.product_id::text,'') || ':' || coalesce(linea.variant_id::text,''), 0)
    );
  end loop;

  for linea in
    select product_id, variant_id, sum(quantity)::integer as quantity
    from jsonb_to_recordset(items_data) as filas(product_id bigint, variant_id bigint, quantity integer)
    group by product_id, variant_id
  loop
    if linea.product_id is null then
      raise exception 'Cada linea de la venta debe indicar un producto';
    end if;
    if linea.quantity is null or linea.quantity <= 0 then
      raise exception 'La cantidad debe ser mayor a cero';
    end if;

    -- El mostrador si puede vender un producto pausado en la tienda.
    if not exists (select 1 from public.products where id = linea.product_id) then
      raise exception 'Uno de los productos ya no existe';
    end if;

    if linea.variant_id is not null and not exists (
      select 1 from public.product_variants
      where id = linea.variant_id and product_id = linea.product_id
    ) then
      raise exception 'El tono seleccionado no pertenece a ese producto';
    end if;

    stock_disponible := public.available_sale_stock(linea.product_id, linea.variant_id);
    if linea.quantity > stock_disponible then
      raise exception 'Stock insuficiente para % (disponibles: %)',
        coalesce(
          (select trim(p.name || coalesce(' - ' || v.name, ''))
             from public.products p
             left join public.product_variants v on v.id = linea.variant_id
            where p.id = linea.product_id),
          'el producto'),
        stock_disponible;
    end if;

    calc_subtotal := calc_subtotal + linea.quantity * public.precio_efectivo(linea.product_id, linea.variant_id);
    calc_unidades := calc_unidades + linea.quantity;
  end loop;

  nota_final := nullif(trim(coalesce(notes, '')), '');

  select * into combo from public.descuento_combos(items_data);
  if found and combo.descuento > 0 then
    calc_descuento := least(combo.descuento, calc_subtotal);
    nota_final := trim(both ' · ' from coalesce(nota_final, '') || ' · ' || combo.titulo ||
                       format(' (%s unidad(es) gratis)', combo.unidades_gratis));
  end if;

  insert into public.sales (sale_date, customer_name, subtotal, total, payment_method, notes)
  values (
    current_date,
    nullif(trim(coalesce(customer_name, '')), ''),
    calc_subtotal,
    calc_subtotal - calc_descuento,
    coalesce(nullif(trim(coalesce(payment_method, '')), ''), 'cash'),
    nota_final
  )
  returning id into nueva_sale_id;

  nuevo_sale_number := 'POS-' || nueva_sale_id;
  update public.sales set sale_number = nuevo_sale_number where id = nueva_sale_id;

  insert into public.sale_items (sale_id, product_id, variant_id, quantity, unit_price)
  select
    nueva_sale_id, f.product_id, f.variant_id,
    sum(f.quantity)::integer,
    public.precio_efectivo(f.product_id, f.variant_id)
  from jsonb_to_recordset(items_data) as f(product_id bigint, variant_id bigint, quantity integer)
  group by f.product_id, f.variant_id;

  insert into public.inventory_movements
    (product_id, variant_id, movement_type, quantity, reference_type, reference_id, notes)
  select
    f.product_id, f.variant_id, 'sale',
    -sum(f.quantity)::integer, 'sale', nueva_sale_id,
    'Salida por venta de mostrador ' || nuevo_sale_number
  from jsonb_to_recordset(items_data) as f(product_id bigint, variant_id bigint, quantity integer)
  group by f.product_id, f.variant_id;

  return query
    select nueva_sale_id, nuevo_sale_number, calc_subtotal, calc_descuento,
           (calc_subtotal - calc_descuento)::numeric(12,2), calc_unidades;
end;
$$;

revoke all on function public.create_pos_sale(jsonb, text, text, text) from public, anon;
grant execute on function public.create_pos_sale(jsonb, text, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- Reportes: el ingreso pasa a ser NETO.
--
-- `report_ventas_linea` calculaba el ingreso como `quantity * unit_price`,
-- es decir el bruto de la linea. El descuento a nivel de documento —hasta
-- hoy solo el cupon, ahora tambien el combo— no se restaba en ninguna parte.
--
-- Esto ya estaba mal antes de los combos: un pedido con cupon del 20%
-- aparecia en Reportes por el importe SIN descuento, inflando el ingreso y
-- el margen. Se descubrio al anadir el 2x1, que lo habria hecho mucho mas
-- visible.
--
-- El descuento se reparte entre las lineas en proporcion a lo que pesa cada
-- una. Repartirlo es necesario porque los agregados por producto, tono y
-- categoria suman lineas: si el descuento viviera solo en la cabecera, cada
-- corte del reporte volveria a mostrar el bruto.
--
-- Se usa `create or replace` a proposito: las cinco vistas de agregado
-- dependen de esta, y un `drop ... cascade` se las llevaria por delante.
-- ---------------------------------------------------------------------
create or replace view public.report_ventas_linea as
with online as (
  select
    o.id, o.order_number, o.created_at::date as fecha, o.status,
    coalesce(nullif(o.subtotal, 0), 1) as base_reparto,
    coalesce(o.discount_total, 0)      as descuento_doc
  from public.orders o
  where o.status in ('paid', 'shipped', 'delivered')
),
fisica as (
  select
    s.id, coalesce(s.sale_number, 'POS-' || s.id) as documento, s.sale_date as fecha,
    coalesce(nullif(s.subtotal, 0), nullif(s.total, 0), 1) as base_reparto,
    greatest(coalesce(s.subtotal, s.total) - s.total, 0)   as descuento_doc
  from public.sales s
)
select
  'online'::text                                as canal,
  o.id                                          as documento_id,
  o.order_number                                as documento,
  o.fecha,
  o.status                                      as estado,
  oi.product_id,
  oi.variant_id,
  oi.product_name,
  oi.quantity,
  oi.unit_price,
  -- Bruto de la linea menos la parte del descuento que le toca.
  greatest(
    (oi.quantity * oi.unit_price)
    - (o.descuento_doc * (oi.quantity * oi.unit_price) / o.base_reparto),
    0
  )::numeric(12,2)                              as ingreso,
  (oi.quantity * public.costo_promedio(oi.product_id, oi.variant_id))::numeric(12,2) as costo,
  (public.costo_promedio(oi.product_id, oi.variant_id) > 0)                          as costo_conocido
from public.order_items oi
join online o on o.id = oi.order_id

union all

select
  'fisica'::text,
  f.id,
  f.documento,
  f.fecha,
  'delivered',
  si.product_id,
  si.variant_id,
  coalesce(p.name, '(producto eliminado)'),
  si.quantity,
  si.unit_price,
  greatest(
    (si.quantity * si.unit_price)
    - (f.descuento_doc * (si.quantity * si.unit_price) / f.base_reparto),
    0
  )::numeric(12,2),
  (si.quantity * public.costo_promedio(si.product_id, si.variant_id))::numeric(12,2),
  (public.costo_promedio(si.product_id, si.variant_id) > 0)
from public.sale_items si
join fisica f on f.id = si.sale_id
left join public.products p on p.id = si.product_id;

comment on view public.report_ventas_linea is
  'Linea de venta unificada (online + mostrador). `ingreso` es NETO: lleva restada la parte proporcional del descuento de cupon o combo.';

comment on column public.sales.subtotal is
  'Suma de las lineas antes del combo. `total` es lo que se cobro.';
