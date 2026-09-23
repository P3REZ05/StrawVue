-- =====================================================================
-- reset_datos_prueba.sql
-- Deja la base lista para empezar a vender de verdad.
--
-- NO es una migración: no cambia el esquema, borra datos. Va aparte de
-- `migrations/` a propósito, para que nadie lo ejecute por accidente al
-- replicar el histórico en un entorno nuevo.
--
-- EJECUTADO UNA VEZ: 8 de septiembre de 2026, con autorización explícita.
--
-- ---------------------------------------------------------------------
-- AVISO: esto borra filas de `inventory_movements`, algo que CLAUDE.md §5
-- regla 7 prohíbe — el historial de movimientos es la fuente de verdad del
-- stock y su auditoría.
--
-- La excepción se tomó una sola vez y por un motivo concreto: todo lo que
-- había en esas tablas eran pedidos y ventas de prueba creados durante el
-- desarrollo, y dejarlos habría contaminado los reportes del negocio real
-- con ~$300.000 de ingresos que nunca existieron.
--
-- No es un permiso permanente. Una vez haya ventas reales, un pedido
-- equivocado se corrige con una devolución (`return_order_stock`), que deja
-- rastro, no borrando su historia.
-- ---------------------------------------------------------------------
--
-- SE CONSERVA: productos, tonos, imágenes, categorías, marcas, proveedores,
--              promociones, banners y la configuración de la tienda.
--
-- CONSECUENCIA: el stock queda en cero para todo. Se reconstruye
-- registrando las compras reales al proveedor, que es como debe entrar la
-- mercancía según el flujo canónico.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Respaldo. No es opcional.
-- ---------------------------------------------------------------------
create schema if not exists respaldo;

drop table if exists respaldo.orders_20260908;
drop table if exists respaldo.order_items_20260908;
drop table if exists respaldo.payments_20260908;
drop table if exists respaldo.shipments_20260908;
drop table if exists respaldo.customers_20260908;
drop table if exists respaldo.sales_20260908;
drop table if exists respaldo.sale_items_20260908;
drop table if exists respaldo.inventory_movements_20260908;
drop table if exists respaldo.contact_messages_20260908;
drop table if exists respaldo.audit_logs_20260908;

create table respaldo.orders_20260908              as select * from public.orders;
create table respaldo.order_items_20260908         as select * from public.order_items;
create table respaldo.payments_20260908            as select * from public.payments;
create table respaldo.shipments_20260908           as select * from public.shipments;
create table respaldo.customers_20260908           as select * from public.customers;
create table respaldo.sales_20260908               as select * from public.sales;
create table respaldo.sale_items_20260908          as select * from public.sale_items;
create table respaldo.inventory_movements_20260908 as select * from public.inventory_movements;
create table respaldo.contact_messages_20260908    as select * from public.contact_messages;
create table respaldo.audit_logs_20260908          as select * from public.audit_logs;

-- El respaldo lleva nombres y teléfonos de clientes: nadie entra por la API.
revoke all on schema respaldo from anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. Borrado, en orden de dependencias.
-- ---------------------------------------------------------------------
begin;

delete from public.order_items;
delete from public.payments;
delete from public.shipments;
delete from public.orders;
delete from public.customers;

delete from public.sale_items;
delete from public.sales;

delete from public.inventory_movements;

delete from public.contact_messages;

-- La auditoría del catálogo se conserva: esos productos siguen existiendo y
-- su historia de cambios sigue siendo válida.
delete from public.audit_logs
where table_name in ('orders','order_items','payments','shipments','customers',
                     'sales','sale_items','inventory_movements','contact_messages');

commit;

-- ---------------------------------------------------------------------
-- 3. Secuencias a cero.
--
-- Cosmético, pero un primer pedido llamado ORD-4 invita a preguntar dónde
-- están los tres anteriores.
-- ---------------------------------------------------------------------
alter sequence public.orders_id_seq restart with 1;
alter sequence public.sales_id_seq restart with 1;
alter sequence public.customers_id_seq restart with 1;
alter sequence public.order_items_id_seq restart with 1;
alter sequence public.sale_items_id_seq restart with 1;
alter sequence public.payments_id_seq restart with 1;
alter sequence public.shipments_id_seq restart with 1;
alter sequence public.inventory_movements_id_seq restart with 1;
alter sequence public.contact_messages_id_seq restart with 1;

-- ---------------------------------------------------------------------
-- 4. Comprobación.
-- ---------------------------------------------------------------------
select 'pedidos' t, count(*) n from public.orders
union all select 'ventas',       count(*) from public.sales
union all select 'clientes',     count(*) from public.customers
union all select 'movimientos',  count(*) from public.inventory_movements
union all select 'mensajes',     count(*) from public.contact_messages
union all select '--- se conserva ---', null
union all select 'productos',    count(*) from public.products
union all select 'tonos',        count(*) from public.product_variants
union all select 'promociones',  count(*) from public.promotions
union all select 'proveedores',  count(*) from public.suppliers
union all select 'ajustes',      count(*) from public.store_settings;

-- Cuando el respaldo ya no haga falta:
--   drop schema respaldo cascade;
