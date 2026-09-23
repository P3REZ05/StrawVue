-- =====================================================================
-- 021_publicar_con_stock.sql
-- Un producto no se publica si no hay nada que vender.
--
-- CONTEXTO
-- El estado del producto y sus existencias no se hablaban. Se podía crear un
-- producto, ponerlo en `active` y quedaba en la tienda inmediatamente, sin
-- haberle comprado una sola unidad al proveedor. La clienta lo veía, lo
-- añadía al carrito y el pedido se rechazaba por falta de stock — o peor, se
-- aceptaba con el stock en cero y había que llamarla a explicar.
--
-- El recorrido correcto ya existía y estaba escrito en la propia pantalla de
-- Inventario: se compra al proveedor, entra a bodega, se pasa a la vitrina.
-- Lo que faltaba era que publicar dependiera de haberlo hecho.
--
-- DECISIONES
--
--  1. LA REGLA VIVE EN LA BASE, no en el botón. Un `disabled` en el panel se
--     salta desde otra pantalla, desde la API o desde un script; y este
--     proyecto ya tiene cuatro casos de "la pantalla decía una cosa y la base
--     otra". Donde se puede, la regla va donde están los datos.
--
--  2. SOLO SE COMPRUEBA AL PUBLICAR, no en cada guardado. Si se comprobara
--     siempre, un producto activo que se agota quedaría bloqueado: no se
--     podría ni corregirle una falta de ortografía hasta reponerlo. Agotarse
--     es normal y la tienda ya lo muestra como «Agotado».
--
--  3. EL ERROR DICE QUÉ FALTA, no «operación no permitida». No es lo mismo
--     «nunca lo has comprado» que «lo tienes en bodega y falta pasarlo a la
--     vitrina»: son dos botones distintos, en dos pantallas distintas.
--
--  4. PAUSAR Y ARCHIVAR SIGUEN LIBRES. La regla solo mira en una dirección:
--     retirar algo de la tienda nunca se bloquea.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Existencias totales de un producto, sumando el producto base y todos sus
-- tonos. `available_sale_stock` (migración 004) responde por una combinación
-- producto+tono concreta; esto responde «¿hay algo de este producto a la
-- venta, sea del tono que sea?».
-- ---------------------------------------------------------------------
create or replace function public.stock_total_en_venta(p_product_id bigint)
returns integer
language sql stable security definer
set search_path = public
as $$
  select coalesce(sum(public.movement_sale_delta(movement_type, reference_type, quantity)), 0)::integer
  from public.inventory_movements
  where product_id = p_product_id;
$$;

create or replace function public.stock_total_en_bodega(p_product_id bigint)
returns integer
language sql stable security definer
set search_path = public
as $$
  select coalesce(sum(public.movement_warehouse_delta(movement_type, reference_type, quantity)), 0)::integer
  from public.inventory_movements
  where product_id = p_product_id;
$$;

comment on function public.stock_total_en_venta(bigint) is
  'Unidades a la venta de un producto, sumando el base y todos sus tonos.';
comment on function public.stock_total_en_bodega(bigint) is
  'Unidades en bodega de un producto, sumando el base y todos sus tonos.';

grant execute on function public.stock_total_en_venta(bigint)  to anon, authenticated;
grant execute on function public.stock_total_en_bodega(bigint) to anon, authenticated;

-- ---------------------------------------------------------------------
-- La regla.
-- ---------------------------------------------------------------------
create or replace function public.exigir_stock_para_publicar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  pasa_a_publicado boolean;
  en_venta  integer;
  en_bodega integer;
begin
  -- ¿Es este cambio una publicación? Insertar ya publicado cuenta; seguir
  -- publicado, no. Así un producto activo y agotado se puede seguir editando.
  pasa_a_publicado :=
    (tg_op = 'INSERT' and (new.status = 'active' or new.active is true))
    or (tg_op = 'UPDATE'
        and (new.status = 'active' or new.active is true)
        and coalesce(old.status, '') is distinct from 'active'
        and coalesce(old.active, false) is distinct from true);

  if not pasa_a_publicado then
    return new;
  end if;

  en_venta := public.stock_total_en_venta(new.id);
  if en_venta > 0 then
    return new;
  end if;

  en_bodega := public.stock_total_en_bodega(new.id);

  if en_bodega > 0 then
    raise exception
      'No se puede publicar «%»: tiene % unidad(es) en bodega y ninguna a la venta. Pasalas a la vitrina desde Inventario > Bodega y vuelve a intentarlo.',
      new.name, en_bodega
      using errcode = 'check_violation';
  end if;

  raise exception
    'No se puede publicar «%»: todavia no tiene existencias. Registra la compra al proveedor en Inventario > Compras, pasala de bodega a la vitrina y entonces publicalo.',
    new.name
    using errcode = 'check_violation';
end;
$$;

comment on function public.exigir_stock_para_publicar() is
  'Impide pasar un producto a publicado sin unidades a la venta. Solo mira la transicion a publicado: un producto ya activo que se agota se sigue pudiendo editar.';

drop trigger if exists trg_products_exigir_stock on public.products;
create trigger trg_products_exigir_stock
  before insert or update on public.products
  for each row execute function public.exigir_stock_para_publicar();

-- ---------------------------------------------------------------------
-- Diagnóstico: qué productos están publicados hoy sin nada que vender.
--
-- No se tocan. Despublicarlos en frío dejaría la tienda medio vacía sin
-- avisar; la lista es para que decidas tú, producto por producto.
-- ---------------------------------------------------------------------
select p.id,
       p.name,
       p.status,
       public.stock_total_en_bodega(p.id) as en_bodega,
       public.stock_total_en_venta(p.id)  as en_venta
from public.products p
where (p.status = 'active' or p.active is true)
  and public.stock_total_en_venta(p.id) <= 0
order by p.name;
