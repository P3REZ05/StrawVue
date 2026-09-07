# Migraciones

Cada archivo es **idempotente**: se puede volver a ejecutar sin daño. Se
aplican en orden numérico desde el SQL Editor de Supabase.

Antes de aplicar nada, ejecuta `000_diagnostico.sql`: es solo de lectura y te
dice en qué estado está la base.

| # | Archivo | Corrige | Destructivo | Aplicada |
|---|---|---|---|---|
| 000 | `000_diagnostico.sql` | — (solo lectura) | no | n/a |
| 001 | `001_rls_restore_admin_policies.sql` | B-13 | no | ☑ 2026-09-03 |
| 002 | `002_audit_logs_contract.sql` | B-1 | no · migra datos | ☑ 2026-09-03 |
| 003 | `003_updated_at.sql` | B-2 | no | ☑ 2026-09-03 |
| 004 | `004_inventory_stock_rules.sql` | B-10 | no · recalcula saldos | ☑ 2026-09-03 |
| 005 | `005_atomic_order_hardening.sql` | B-7, B-9, B-11 | no | ☑ 2026-09-03 |
| 006 | `006_cleanup_legacy.sql` | S-3 | **sí — borra `public.admins`** | ☑ 2026-09-03 |
| 007 | `007_shade_model.sql` | modelo de tonos, B-17 | no | ☑ 2026-09-03 |
| 008 | `008_storage_imagenes.sql` | B-15 | no | ☑ 2026-09-03 |
| 009 | `009_comprobantes_pago.sql` | comprobantes de pago | no | ☑ 2026-09-03 |
| 010 | `010_promociones.sql` | modulo de promociones | no | ☑ 2026-09-03 |
| 011 | `011_pedido_precio_servidor.sql` | B-18 (precio del cliente) | no | ☑ 2026-09-03 |
| 012 | `012_reportes.sql` | reportes y margen real | no | ☑ 2026-09-03 |

Todas aplicadas sobre el proyecto **StrawBack**. Marca la casilla cuando apliques una nueva.

### Al ejecutar desde el SQL Editor

Supabase muestra un diálogo *"Potential issue detected — This query includes
destructive operations"* ante cualquier `drop policy`, `drop trigger` o
`drop table`. Hay que pulsar **Run query** para confirmarlo. Si no se confirma,
la consulta **no se ejecuta** y el panel sigue mostrando el resultado anterior,
que se lee igual que un éxito. Pasó con la 003 y solo se detectó al verificar
las columnas después. Verifica siempre el efecto, no el mensaje.

---

## Qué hace cada una

**001 — Restaurar políticas RLS del admin.** `add_audit_logs.sql` ejecutaba
`drop table public.admin_profiles cascade` y el CASCADE se llevó 19 políticas.
`fix_admin_rls.sql` restauró 6; faltaban 13. Como una tabla con RLS y sin
políticas devuelve 0 filas **sin error**, el panel no podía leer pedidos,
pagos, clientes ni envíos, y los UPDATE fallaban en silencio. Esta migración
las restaura todas sobre `is_admin()`.

**002 — Un solo contrato de auditoría.** Había dos definiciones incompatibles
de `audit_logs`. Se adopta la de `add_audit_logs.sql`
(`table_name / record_id / action / old_data / new_data / changed_by / changed_at`),
que es más rica y tiene triggers automáticos. La migración convierte la tabla
existente **sin perder datos** y extiende los triggers a `orders`, `payments`,
`shipments`, `suppliers` y `purchase_orders`.

**003 — `updated_at`.** El frontend escribía `updated_at` en `payments` y
`shipments`, columnas que no existían. Se añaden con trigger, así el frontend
ya no tiene que mandarlas.

**004 — Regla única de stock.** La fórmula estaba copiada en tres sitios y las
tres ignoraban `return`, `adjustment` y `damage`: una devolución no devolvía
stock. Ahora la regla vive en `movement_sale_delta()` y
`movement_warehouse_delta()`, y la vista, el trigger de saldos y el RPC las
usan. Al final recalcula todos los saldos.

**005 — Blindaje del pedido atómico.** Corrige la ambigüedad de la variable
`item` que impedía ejecutar `create_order_with_stock`, añade el índice único
que impide el doble descuento si alguien reejecuta `schema.sql`, y crea
`return_order_stock()` para que las devoluciones sean un movimiento
compensatorio en vez de un `DELETE` sobre el historial.

**007 — Modelo de tonos e imágenes.** Convierte `product_variants` en una ficha
de tono de maquillaje: `swatch_hex` (chip, orden y filtros) más
`swatch_image_url` (la verdad: un metalizado no se representa con color plano),
`undertone_id`, `shade_family_id`, `depth` 1–100 para ordenar de clara a
profunda, `position` e `is_default`. El precio del tono pasa a admitir NULL, que
significa "hereda el del producto". Crea `product_images` con `variant_id`
opcional —galería del producto y foto por tono en una sola tabla, que es lo que
resuelve B-15— la vista `storefront_shades` con el precio ya resuelto y el saldo
por tono, y extiende la auditoría a las tablas maestras de catálogo (B-17).

Validaciones que impone: hexadecimal CSS válido, profundidad entre 1 y 100, un
solo tono por defecto por producto y una sola imagen principal por producto.

**008 — Bucket de imágenes.** Crea `product-images` en Storage con lectura
pública y escritura solo para administradores, límite de 5 MB por archivo y
tipos permitidos. Se versiona aquí en vez de crearse a mano en el dashboard,
para que reconstruir el proyecto no dependa de recordar un clic.

**006 — Limpieza legacy.** Normaliza los roles de `admin_profiles` y **borra**
`public.admins`, la tabla con `password_hash` que ya no usa nadie. Ejecútala
solo después de confirmar que entras al panel con Supabase Auth.

**007 — Modelo de tonos.** Tablas maestras `undertones` y `shade_families`, ocho
columnas de tono en `product_variants` (swatch hex e imagen, subtono,
profundidad 1-100, familia), `product_images` y la vista `storefront_shades`.
Es la base del editor de producto de página completa.

**008 — Bucket de imágenes.** Bucket público `product-images`.

**009 — Comprobantes de pago.** Bucket **privado** `payment-proofs`. Privado a
propósito: un comprobante lleva datos bancarios del cliente, así que se sirve
con URL firmada y nunca por enlace público.

**010 — Promociones.** Modelo de promociones con vigencia y alcance, más las
funciones `promo_vigente`, `precio_base`, `promo_para_producto`,
`precio_efectivo` y `config_numero`, y las vistas de tienda que ya devuelven el
precio con descuento aplicado.

**011 — Precio calculado en el servidor.** Reescribe `create_order_with_stock`
para que el precio salga de la base y no del navegador. Antes el RPC confiaba
en el `unit_price` que mandaba el cliente: se comprobó enviando `unit_price: 1`
y el pedido se registró por ese valor. Ahora el cliente manda producto,
variante y cantidad; el precio lo pone el servidor.

**012 — Reportes y margen.** `costo_promedio()` (costo promedio ponderado de las
compras), la vista unificada `report_ventas_linea` que junta el canal online y
el punto físico en una sola forma, los agregados
`report_por_producto` / `report_por_tono` / `report_por_dia` /
`report_por_categoria`, `report_riesgo_stock` y la columna
`orders.discount_total`. El margen se expresa sobre el ingreso. Las líneas de
venta cuentan solo pedidos en `paid`, `shipped` o `delivered`: un pedido
pendiente todavía no es ingreso y uno devuelto dejó de serlo.

---

## Estado en producción tras aplicarlas

Verificado en la base real el 3 de septiembre de 2026:

- `tablas_rls_SIN_politicas`: **vacío** (antes: `admins`, `promotion_products`,
  `sale_items`, `sales`, `shipments`, más 7 tablas sin las políticas de admin).
- `orders`, `payments`, `shipments`, `sales`, `sale_items`, `categories` y
  `store_settings` ya tienen sus políticas de admin.
- `updated_at` presente en `orders`, `payments`, `shipments`, `products` y
  `product_variants`, con trigger.
- Funciones creadas: `is_admin`, `movement_sale_delta`,
  `movement_warehouse_delta`, `available_sale_stock`, `create_order_with_stock`,
  `return_order_stock`, `set_updated_at`, `audit_trigger`.
- Triggers de auditoría en 8 tablas; `ux_inventory_movements_pedido_unico`
  presente; el trigger duplicador **no** existe.
- `public.admins` eliminada. Perfil admin intacto con rol `super_admin`.

## Verificado antes de aplicar

Estas migraciones se probaron sobre PostgreSQL 16 con RLS activo, partiendo del
estado real de la base (`schema.sql` → `add_audit_logs.sql` → `atomic_order.sql`
→ `product_catalog_migration.sql` → `fix_admin_rls.sql`):

- se aplican dos veces seguidas sin error (idempotencia);
- flujo completo: compra → bodega → transferencia → pedido anónimo → pago →
  devolución, con los saldos correctos en cada paso;
- sobreventa rechazada con el mensaje correcto;
- 10 pedidos simultáneos por la última unidad → 1 aceptado, 9 rechazados, stock
  nunca negativo;
- recreando el trigger duplicador, el pedido falla de forma ruidosa en vez de
  descontar dos veces;
- el historial de movimientos queda completo tras una devolución;
- la auditoría registra los INSERT/UPDATE de todas las tablas cubiertas.
