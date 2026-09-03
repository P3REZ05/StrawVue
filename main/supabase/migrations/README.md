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

**006 — Limpieza legacy.** Normaliza los roles de `admin_profiles` y **borra**
`public.admins`, la tabla con `password_hash` que ya no usa nadie. Ejecútala
solo después de confirmar que entras al panel con Supabase Auth.

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
