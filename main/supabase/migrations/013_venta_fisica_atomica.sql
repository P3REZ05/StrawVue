-- =====================================================================
-- 013_venta_fisica_atomica.sql
-- La venta del mostrador pasa a ser atómica y con precio del servidor.
--
-- ANTES (src/stores/inventory.js, ruta vieja)
--   1. se descontaba el stock en memoria del navegador
--   2. insert en `sales`      -> si fallaba: console.error y `return id`
--   3. insert en `sale_items` -> si fallaba: console.error y seguir
--   4. insert en movimientos  -> ni se comprobaba
--   y el componente ni siquiera esperaba la promesa: vaciaba el carrito y
--   cerraba el modal antes de saber nada.
--
--   Resultados posibles, todos mostrados como éxito:
--     · venta perdida por completo
--     · venta con total pero sin líneas (ingreso sin productos)
--     · venta registrada sin descontar stock
--     · dos cajeros vendiendo la misma última unidad
--   Además el POS mandaba solo `product_id`: con un catálogo de tonos, la
--   venta no decía cuál se llevó el cliente y el movimiento caía sobre el
--   producto en vez del tono.
--
-- AHORA una sola llamada hace todo dentro de una transacción, con el mismo
-- criterio que ya usa el pedido online (`create_order_with_stock`):
--   · bloqueo por producto/tono para que dos cajas no se pisen
--   · stock validado contra `available_sale_stock()`
--   · precio unitario resuelto por `precio_efectivo()`, no por el navegador
--   · sale + sale_items + inventory_movements, o nada
--
-- Si algo falla, la excepción revierte la transacción entera: no quedan
-- ventas huérfanas ni stock descuadrado.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trazabilidad de la venta física. `sales` no tenía dónde anotar quién
-- cobró ni una nota de mostrador, y sin número de venta no hay nada que
-- decirle al cliente ni que buscar después en el historial.
-- ---------------------------------------------------------------------
alter table public.sales add column if not exists sale_number text;
alter table public.sales add column if not exists notes text;
alter table public.sales add column if not exists subtotal numeric(12,2);

create unique index if not exists ux_sales_sale_number
  on public.sales (sale_number) where sale_number is not null;

-- Las ventas que ya existen se quedan sin número; se lo damos ahora para
-- que el historial no tenga huecos.
update public.sales
   set sale_number = 'POS-' || id
 where sale_number is null;

comment on column public.sales.sale_number is
  'Identificador legible de la venta de mostrador (POS-<id>).';
comment on column public.sales.subtotal is
  'Suma de las lineas antes de cualquier ajuste. Hoy coincide con total.';

-- ---------------------------------------------------------------------
-- create_pos_sale
--
-- items_data: [{ "product_id": 5, "variant_id": 2, "quantity": 1 }, ...]
--   El precio NO viaja en el payload a propósito. Si el navegador pudiera
--   mandarlo, cualquiera con la consola abierta podría registrar una venta
--   a $1 — el mismo agujero que tenía el pedido online antes de la 011.
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
  calc_unidades     integer := 0;
begin
  -- Solo el panel vende en mostrador. `security definer` salta RLS, así que
  -- la puerta hay que cerrarla aquí a mano: sin esto, la función quedaría
  -- expuesta a `anon` igual que el pedido online, que sí debe serlo.
  if not public.is_admin() then
    raise exception 'Solo un administrador puede registrar ventas de mostrador';
  end if;

  if items_data is null or jsonb_array_length(items_data) = 0 then
    raise exception 'La venta debe contener al menos un producto';
  end if;

  -- 1) Bloqueo ordenado por producto/tono. El orden importa: dos cajas
  --    tomando los mismos candados en distinto orden se abrazarían.
  for linea in
    select distinct product_id, variant_id
    from jsonb_to_recordset(items_data) as filas(product_id bigint, variant_id bigint)
    order by product_id nulls last, variant_id nulls last
  loop
    perform pg_advisory_xact_lock(
      hashtextextended(coalesce(linea.product_id::text,'') || ':' || coalesce(linea.variant_id::text,''), 0)
    );
  end loop;

  -- 2) Validar y calcular con los precios de la base.
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

    -- El mostrador sí puede vender un producto pausado en la tienda: que no
    -- se exhiba en la web no significa que no esté en la vitrina física.
    -- Lo que no puede es vender uno que ya no existe.
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

  -- 3) Cabecera
  insert into public.sales (sale_date, customer_name, subtotal, total, payment_method, notes)
  values (
    current_date,
    nullif(trim(coalesce(customer_name, '')), ''),
    calc_subtotal,
    calc_subtotal,
    coalesce(nullif(trim(coalesce(payment_method, '')), ''), 'cash'),
    nullif(trim(coalesce(notes, '')), '')
  )
  returning id into nueva_sale_id;

  nuevo_sale_number := 'POS-' || nueva_sale_id;
  update public.sales set sale_number = nuevo_sale_number where id = nueva_sale_id;

  -- 4) Líneas, agrupadas y con el precio del servidor.
  insert into public.sale_items (sale_id, product_id, variant_id, quantity, unit_price)
  select
    nueva_sale_id,
    f.product_id,
    f.variant_id,
    sum(f.quantity)::integer,
    public.precio_efectivo(f.product_id, f.variant_id)
  from jsonb_to_recordset(items_data) as f(product_id bigint, variant_id bigint, quantity integer)
  group by f.product_id, f.variant_id;

  -- 5) Salida de stock. `movement_sale_delta` ya trata 'sale' como salida
  --    del inventario de venta, así que no hay regla nueva que inventar.
  insert into public.inventory_movements
    (product_id, variant_id, movement_type, quantity, reference_type, reference_id, notes)
  select
    f.product_id,
    f.variant_id,
    'sale',
    -sum(f.quantity)::integer,
    'sale',
    nueva_sale_id,
    'Salida por venta de mostrador ' || nuevo_sale_number
  from jsonb_to_recordset(items_data) as f(product_id bigint, variant_id bigint, quantity integer)
  group by f.product_id, f.variant_id;

  return query
    select nueva_sale_id, nuevo_sale_number, calc_subtotal, calc_subtotal, calc_unidades;
end;
$$;

-- `anon` no entra aquí: vender en mostrador es una operación del panel.
revoke all on function public.create_pos_sale(jsonb, text, text, text) from public, anon;
grant execute on function public.create_pos_sale(jsonb, text, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- Los reportes leen la venta física por `s.sale_date` y `si.unit_price`;
-- ambos siguen igual, así que `report_ventas_linea` no cambia. Se recrea
-- igualmente el comentario para dejar constancia de que el canal 'fisica'
-- ahora tiene número de venta propio.
-- ---------------------------------------------------------------------
comment on view public.report_ventas_linea is
  'Linea de venta unificada: pedidos online (paid/shipped/delivered) y ventas de mostrador. El costo sale de costo_promedio().';
