-- =====================================================================
-- 012_reportes.sql
-- Vistas de reporte: utilidad real por producto, tono, categoria y periodo.
--
-- CONTEXTO
-- El panel ya sabe descontar pero no sabe cuanto gana. Un 20% sobre un
-- producto con 30% de margen se lleva dos tercios de la utilidad, y hoy no
-- hay ninguna pantalla que lo diga.
--
-- QUE CUENTA COMO VENTA
--   online: pedidos en paid, shipped o delivered
--           (pending todavia no se cobro; returned se anulo)
--   fisica: todas las ventas del POS
--
-- El costo es el promedio ponderado de las compras, que es lo unico que
-- se puede calcular sin lotes.
-- =====================================================================

-- El descuento por cupon no se guardaba en ningun lado, asi que era
-- imposible medir cuanto costo una promocion.
alter table public.orders
  add column if not exists discount_total numeric(12,2) not null default 0;

comment on column public.orders.discount_total is
  'Descuento aplicado por cupon. Los descuentos de producto ya vienen restados en order_items.unit_price.';

-- ---------------------------------------------------------------------
-- Costo promedio ponderado de las entradas por compra.
-- ---------------------------------------------------------------------
create or replace function public.costo_promedio(p_product_id bigint, p_variant_id bigint default null)
returns numeric
language sql stable
as $$
  select coalesce(
    sum(quantity * coalesce(unit_cost, 0)) / nullif(sum(quantity), 0),
    0
  )::numeric(12,2)
  from public.inventory_movements
  where movement_type = 'purchase'
    and quantity > 0
    and product_id = p_product_id
    and (p_variant_id is null or variant_id is not distinct from p_variant_id);
$$;

grant execute on function public.costo_promedio(bigint, bigint) to authenticated;

-- ---------------------------------------------------------------------
-- Linea de venta unificada: online y fisica en la misma forma.
-- security_invoker deja que RLS haga su trabajo: solo un admin ve esto.
-- ---------------------------------------------------------------------
drop view if exists public.report_ventas_linea cascade;
create view public.report_ventas_linea with (security_invoker = true) as
select
  'online'::text                                as canal,
  o.id                                          as documento_id,
  o.order_number                                as documento,
  o.created_at::date                            as fecha,
  o.status                                      as estado,
  oi.product_id,
  oi.variant_id,
  oi.product_name,
  oi.quantity,
  oi.unit_price,
  (oi.quantity * oi.unit_price)::numeric(12,2)  as ingreso,
  (oi.quantity * public.costo_promedio(oi.product_id, oi.variant_id))::numeric(12,2) as costo,
  (public.costo_promedio(oi.product_id, oi.variant_id) > 0)                            as costo_conocido
from public.order_items oi
join public.orders o on o.id = oi.order_id
where o.status in ('paid', 'shipped', 'delivered')

union all

select
  'fisica'::text,
  s.id,
  'POS-' || s.id,
  s.sale_date,
  'delivered',
  si.product_id,
  si.variant_id,
  coalesce(p.name, '(producto eliminado)'),
  si.quantity,
  si.unit_price,
  (si.quantity * si.unit_price)::numeric(12,2),
  (si.quantity * public.costo_promedio(si.product_id, si.variant_id))::numeric(12,2),
  (public.costo_promedio(si.product_id, si.variant_id) > 0)
from public.sale_items si
join public.sales s on s.id = si.sale_id
left join public.products p on p.id = si.product_id;

grant select on public.report_ventas_linea to authenticated;

-- ---------------------------------------------------------------------
-- Agregados. El margen se expresa sobre el ingreso, que es como se lee
-- en comercio: "me queda el 52% de lo que vendo".
-- ---------------------------------------------------------------------
create or replace view public.report_por_producto with (security_invoker = true) as
select
  l.product_id,
  max(p.name)                    as producto,
  max(p.category)                as categoria,
  sum(l.quantity)::integer       as unidades,
  sum(l.ingreso)::numeric(12,2)  as ingreso,
  sum(l.costo)::numeric(12,2)    as costo,
  (sum(l.ingreso) - sum(l.costo))::numeric(12,2) as utilidad,
  case when sum(l.ingreso) > 0
       then round((sum(l.ingreso) - sum(l.costo)) / sum(l.ingreso) * 100, 1)
       else 0 end                as margen_pct,
  -- Sin compras registradas el costo sale 0 y el margen aparenta ser del
  -- 100%. Marcarlo evita celebrar una utilidad que no existe.
  bool_and(l.costo_conocido)     as costo_confiable
from public.report_ventas_linea l
left join public.products p on p.id = l.product_id
group by l.product_id;

create or replace view public.report_por_tono with (security_invoker = true) as
select
  l.variant_id,
  l.product_id,
  max(p.name)                    as producto,
  max(coalesce(v.shade_code || ' ' || v.name, 'Sin tono')) as tono,
  max(v.swatch_hex)              as swatch_hex,
  sum(l.quantity)::integer       as unidades,
  sum(l.ingreso)::numeric(12,2)  as ingreso,
  (sum(l.ingreso) - sum(l.costo))::numeric(12,2) as utilidad,
  case when sum(l.ingreso) > 0
       then round((sum(l.ingreso) - sum(l.costo)) / sum(l.ingreso) * 100, 1)
       else 0 end                as margen_pct,
  -- Si no hay compras registradas el costo sale 0 y el margen aparenta ser
  -- del 100%. Marcarlo evita celebrar una utilidad que no existe.
  bool_and(l.costo_conocido)     as costo_confiable
from public.report_ventas_linea l
left join public.products p on p.id = l.product_id
left join public.product_variants v on v.id = l.variant_id
group by l.variant_id, l.product_id;

create or replace view public.report_por_dia with (security_invoker = true) as
select
  l.fecha,
  count(distinct l.documento_id)::integer as documentos,
  sum(l.quantity)::integer                as unidades,
  sum(l.ingreso)::numeric(12,2)           as ingreso,
  (sum(l.ingreso) - sum(l.costo))::numeric(12,2) as utilidad,
  bool_and(l.costo_conocido)              as costo_confiable
from public.report_ventas_linea l
group by l.fecha;

create or replace view public.report_por_categoria with (security_invoker = true) as
select
  coalesce(max(p.category), 'Sin categoria') as categoria,
  sum(l.quantity)::integer      as unidades,
  sum(l.ingreso)::numeric(12,2) as ingreso,
  (sum(l.ingreso) - sum(l.costo))::numeric(12,2) as utilidad
from public.report_ventas_linea l
left join public.products p on p.id = l.product_id
group by p.category;

grant select on public.report_por_producto, public.report_por_tono,
                public.report_por_dia, public.report_por_categoria to authenticated;

-- ---------------------------------------------------------------------
-- Riesgo de inventario: que se esta quedando sin stock y que no rota.
-- ---------------------------------------------------------------------
create or replace view public.report_riesgo_stock with (security_invoker = true) as
select
  b.product_id,
  b.variant_id,
  max(p.name)                                        as producto,
  max(coalesce(v.shade_code || ' ' || v.name, ''))   as tono,
  max(b.sale_stock)                                  as stock_venta,
  max(b.warehouse_stock)                             as stock_bodega,
  coalesce(sum(l.quantity), 0)::integer              as vendidas,
  case
    when max(b.sale_stock) = 0 and max(b.warehouse_stock) > 0 then 'reponer_vitrina'
    when max(b.sale_stock) = 0                                then 'agotado'
    when max(b.sale_stock) <= 3                               then 'stock_bajo'
    when coalesce(sum(l.quantity), 0) = 0                     then 'sin_rotacion'
    else 'ok'
  end as alerta
from public.inventory_balances b
left join public.products p on p.id = b.product_id
left join public.product_variants v on v.id = b.variant_id
left join public.report_ventas_linea l
       on l.product_id = b.product_id
      and l.variant_id is not distinct from b.variant_id
group by b.product_id, b.variant_id;

grant select on public.report_riesgo_stock to authenticated;
