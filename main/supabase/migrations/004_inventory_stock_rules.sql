-- =====================================================================
-- 004_inventory_stock_rules.sql
-- Corrige: B-10 (crítico), y habilita el arreglo de B-9
--
-- CONTEXTO
-- La fórmula de stock estaba escrita a mano en TRES lugares distintos
-- (refresh_inventory_sale_balance, la vista inventory_balances y el RPC
-- create_order_with_stock) y las tres ignoraban los movimientos
-- 'return', 'adjustment' y 'damage'.
--
-- Consecuencia: una devolución no devolvía el stock a la venta, y un
-- ajuste o una merma registrados por el admin no cambiaban nada.
--
-- Aquí se define la regla UNA sola vez, en dos funciones inmutables, y
-- todo lo demás las usa.
--
-- REGLA CANÓNICA
--   Stock de VENTA:
--     · sale / online_order            -> siempre (cantidad negativa)
--     · transfer/return/adjustment/damage con reference_type='sale_inventory'
--   Stock de BODEGA:
--     · purchase                       -> siempre entra a bodega
--     · transfer/return/adjustment/damage con reference_type='warehouse'
-- =====================================================================

create or replace function public.movement_sale_delta(
  p_movement_type text,
  p_reference_type text,
  p_quantity integer
) returns integer
language sql immutable
as $$
  select case
    when p_movement_type in ('sale', 'online_order') then p_quantity
    when p_movement_type in ('transfer', 'return', 'adjustment', 'damage')
         and p_reference_type = 'sale_inventory' then p_quantity
    else 0
  end;
$$;

create or replace function public.movement_warehouse_delta(
  p_movement_type text,
  p_reference_type text,
  p_quantity integer
) returns integer
language sql immutable
as $$
  select case
    when p_movement_type = 'purchase' then p_quantity
    when p_movement_type in ('transfer', 'return', 'adjustment', 'damage')
         and p_reference_type = 'warehouse' then p_quantity
    else 0
  end;
$$;

grant execute on function public.movement_sale_delta(text, text, integer)      to anon, authenticated;
grant execute on function public.movement_warehouse_delta(text, text, integer) to anon, authenticated;

-- Stock de venta disponible para un producto/variante concreto.
create or replace function public.available_sale_stock(
  p_product_id bigint,
  p_variant_id bigint
) returns integer
language sql stable security definer
set search_path = public
as $$
  select coalesce(sum(public.movement_sale_delta(movement_type, reference_type, quantity)), 0)::integer
  from public.inventory_movements
  where product_id = p_product_id
    and variant_id is not distinct from p_variant_id;
$$;

grant execute on function public.available_sale_stock(bigint, bigint) to anon, authenticated;

-- ---------------------------------------------------------------------
-- Vista administrativa: saldo completo por producto/variante.
-- ---------------------------------------------------------------------
drop view if exists public.inventory_balances;
create view public.inventory_balances with (security_invoker = true) as
select
  product_id,
  variant_id,
  coalesce(sum(public.movement_warehouse_delta(movement_type, reference_type, quantity)), 0)::integer as warehouse_stock,
  coalesce(sum(public.movement_sale_delta(movement_type, reference_type, quantity)), 0)::integer      as sale_stock
from public.inventory_movements
where product_id is not null
group by product_id, variant_id;

grant select on public.inventory_balances to authenticated;

-- ---------------------------------------------------------------------
-- Tabla de saldo público: se mantiene con trigger, usando la misma regla.
-- ---------------------------------------------------------------------
create or replace function public.refresh_inventory_sale_balance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  afectado_product_id bigint := coalesce(new.product_id, old.product_id);
  afectado_variant_id bigint := coalesce(new.variant_id, old.variant_id);
  stock_calculado integer;
begin
  stock_calculado := public.available_sale_stock(afectado_product_id, afectado_variant_id);

  delete from public.inventory_sale_balances
  where product_id = afectado_product_id
    and variant_id is not distinct from afectado_variant_id;

  if stock_calculado <> 0 then
    insert into public.inventory_sale_balances (product_id, variant_id, sale_stock)
    values (afectado_product_id, afectado_variant_id, stock_calculado);
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists refresh_inventory_sale_balance_trigger on public.inventory_movements;
create trigger refresh_inventory_sale_balance_trigger
after insert or update or delete on public.inventory_movements
for each row execute function public.refresh_inventory_sale_balance();

-- ---------------------------------------------------------------------
-- Recalcular todos los saldos con la fórmula nueva.
-- ---------------------------------------------------------------------
delete from public.inventory_sale_balances;

insert into public.inventory_sale_balances (product_id, variant_id, sale_stock)
select product_id, variant_id, sale_stock
from public.inventory_balances
where sale_stock <> 0;
