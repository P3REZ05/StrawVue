# HANDOFF.md — Strawberry Makeup

Estado vivo del proyecto. Se actualiza **al final de cada sesión de trabajo**.
Para saber *cómo* trabajar en el repo, lee `CLAUDE.md`. Este archivo dice *qué sigue*.

- **Última actualización:** 3 de septiembre de 2026
- **Rama activa:** `dev` (remoto `P3REZ05/StrawVue`)
- **Fase:** cierre operativo. No se agregan features hasta validar el flujo real.
- **Sprint A:** ✅ **completo.** Código verificado y las 6 migraciones aplicadas en Supabase.
- **Proyecto Supabase real:** `StrawBack` (`gjchbbvqoigvhildddfw`), org `Strawberry-Makeup`.

---

## 0. LO PRIMERO AL RETOMAR

Sprint A está cerrado: las migraciones `001`–`006` **ya están aplicadas** en el
proyecto `StrawBack` y verificadas contra la base real. El siguiente paso es la
**prueba end-to-end con datos reales** (§5).

Antes de tocar nada:

1. `cd main && npm install` (si es una máquina nueva). El `.env` ya apunta al
   proyecto correcto; si no existe, copia `.env.example`. **Sin `.env` la app no arranca.**
2. Corre `main/supabase/migrations/000_diagnostico.sql` (solo lectura) para
   confirmar que el estado sigue sano. Lo esperado hoy:
   `tablas_rls_SIN_politicas` **vacío** y `trigger_duplicador_existe` **false**.
3. Si vas a ejecutar SQL desde el SQL Editor, recuerda que Supabase muestra un
   diálogo de confirmación ante cualquier `drop`. Si no lo confirmas, la
   consulta no corre y el panel sigue mostrando el resultado anterior, que se
   lee igual que un éxito. Verifica el efecto, no el mensaje.

## 1. Qué se hizo en el Sprint A

### Bugs cerrados

| # | Problema | Solución |
|---|---|---|
| **B-13** | `add_audit_logs.sql` hacía `drop table admin_profiles cascade` y se llevó **19 políticas RLS**. `fix_admin_rls.sql` restauró 6. Las 13 restantes dejaron `orders`, `order_items`, `payments`, `customers`, `shipments`, `sales`, `sale_items`, `categories`, `store_settings` y `promotion_products` **inaccesibles**. Como PostgREST devuelve 0 filas sin error, el panel parecía funcionar y no guardaba nada. | `001` restaura todas sobre `is_admin()` |
| **B-1** | Dos definiciones incompatibles de `audit_logs`; `orders.js` escribía una forma y `audit.js` leía la otra | `002` converge a un contrato único sin perder datos; `lib/auditLog.js` es el único punto de escritura |
| **B-2** | Se escribía `updated_at` en `payments` y `shipments`, columnas inexistentes | `003` las crea con trigger; el frontend ya no las envía |
| **B-8** | `getProductAvailableStock` calculaba `variant.stock (legacy, casi siempre 0) − balance.saleStock`, tratando el disponible como si fuera una reserva. Daba 0 siempre, así que `validateOrderItems` **rechazaba todo pedido** | Corregido en `inventory.js`: `saleStock` es el disponible |
| **B-9** | `releaseOrderStock` hacía `DELETE` sobre `inventory_movements`, destruyendo la trazabilidad | `005` añade `return_order_stock()`, que inserta un movimiento `return` compensatorio e idempotente |
| **B-10** | La fórmula de stock estaba copiada en 3 sitios y las 3 ignoraban `return`, `adjustment` y `damage`: una devolución no devolvía stock | `004` centraliza la regla en `movement_sale_delta()` y `movement_warehouse_delta()` |
| **B-7** | Reejecutar `schema.sql` recreaba el trigger `order_item_inventory_movement` → doble descuento silencioso | `005` añade el índice único `ux_inventory_movements_pedido_unico`: ahora falla ruidosamente |
| **B-11** | En `create_order_with_stock`, `item` era variable RECORD y alias de subconsulta a la vez → `column reference item.product_id is ambiguous`. La reserva atómica **nunca pudo ejecutarse** | `005` reescribe el RPC con bloqueos ordenados en un `FOR` explícito |
| **B-3** | `deliveredOrders` devolvía devoluciones | Renombrado a `returnedOrders` |
| **B-4** | Mapeo de estados duplicado y divergente | `utils/orderStatus.js` |
| **S-1** | Credenciales en `main/supabase/README.md` | README reescrito sin secretos, `.env.example` creado. Ver §3: el ref filtrado era de un proyecto que ya no existe |
| **S-2** | Modo demo con `admin@strawberrymakeup.com / strawberry2026` hardcodeadas | Eliminado por completo |
| **S-3** | Tabla legacy `admins` con `password_hash` | `006` la borra (opt-in) |
| **D-3** | `package-lock.json` en `.gitignore` | Quitado |
| **D-8** | Fallback silencioso a `mockData` en los stores | Eliminado; los errores suben a la UI, con pantalla de error en `App.vue` |
| **D-10** | `README.md` decía `#Firt README` | README real |

### Verificación ejecutada

Las migraciones se probaron sobre **PostgreSQL 16 con RLS activo**, reproduciendo
el estado real de la base (`schema.sql` → `add_audit_logs.sql` →
`atomic_order.sql` → `product_catalog_migration.sql` → `fix_admin_rls.sql`) con
un esquema `auth` emulado:

- Se aplican dos veces seguidas sin error (idempotencia).
- Flujo completo con RLS: compra 10 → bodega 10 → transferencia 6 → pedido
  anónimo de 4 → venta 2 / bodega 4 → pago confirmado → devolución → venta 6.
- Sobreventa rechazada: *"Stock insuficiente para Base (disponibles: 2)"*.
- **10 pedidos simultáneos por la última unidad → 1 aceptado, 9 rechazados,
  stock nunca negativo.**
- Recreando el trigger duplicador, el pedido falla de forma ruidosa en vez de
  descontar dos veces.
- Tras la devolución quedan los 5 movimientos: ninguno se borró.
- `audit_logs` registró los INSERT/UPDATE de todas las tablas cubiertas.
- Frontend: `npm run build` pasa (1861 módulos).

### Archivos nuevos

```
README.md                                  (reescrito)
main/.env.example
main/supabase/README.md                    (reescrito, sin credenciales)
main/supabase/migrations/README.md
main/supabase/migrations/000_diagnostico.sql
main/supabase/migrations/001_rls_restore_admin_policies.sql
main/supabase/migrations/002_audit_logs_contract.sql
main/supabase/migrations/003_updated_at.sql
main/supabase/migrations/004_inventory_stock_rules.sql
main/supabase/migrations/005_atomic_order_hardening.sql
main/supabase/migrations/006_cleanup_legacy.sql
main/src/lib/auditLog.js
main/src/utils/orderStatus.js
```

Modificados: `main/.gitignore`, `main/src/lib/supabase.js`,
`main/src/stores/{admin,orders,inventory}.js`, `main/src/App.vue`,
`main/src/views/admin/AdminLogin.vue`,
`main/src/components/admin/AdminHistorial.vue`.

---

## 2. Lección que conviene no olvidar

**Una tabla con RLS activo y sin políticas no da error: da vacío.**

`select` devuelve 0 filas y `update` reporta éxito habiendo afectado 0 filas.
Combinado con el fallback a datos mock que había en los stores, el panel admin
parecía funcionar perfectamente mientras la base no recibía nada. Ese es el
motivo real de que el flujo nunca se cerrara, y no se ve leyendo el frontend.

Por eso: tras un UPDATE que deba afectar filas, usar `.select('id')` y comprobar
que volvió al menos una. `orders.js → updateStatus` ya lo hace.

---

## 3. Seguridad — estado

El ref de Supabase que estaba commiteado en `main/supabase/README.md`
(`vzsdubpklknbccvgvukl`) **no corresponde a este proyecto**. El real es
`gjchbbvqoigvhildddfw` ("StrawBack"), y su anon key nunca estuvo en el
repositorio. La llave filtrada apuntaba a un proyecto que ya no existe en la
cuenta, así que **no se rota** (decisión tomada el 2026-09-03).

Lo que sí conviene hacer, y Claude no puede:

- **Cambiar la contraseña del usuario admin** (`dpanimalito@gmail.com`) si sigue
  siendo débil. El README sugería `admin123` y estaba en el repo.

Ya resuelto: no quedan credenciales en archivos versionados, el modo demo con
credenciales embebidas se eliminó, y la tabla legacy `admins` con
`password_hash` se borró.

## 4. Deuda técnica pendiente

| # | Tema | Impacto | Esfuerzo |
|---|---|---|---|
| D-1 | `inventory.js`: ~39 KB, mezcla catálogo + proveedores + compras + bodega + venta + POS, con rutas legacy (`addPurchaseOrderLegacy`, `addToSaleInventoryLocal`) | alto | alto |
| D-4 | El histórico de `main/supabase/*.sql` sigue sin numerar. Las migraciones nuevas sí lo están | bajo | bajo |
| D-5 | `assets/images/` y `assets/styles/images/carrusel-home/` son los mismos 15 PNG duplicados; `pexels.jpg` pesa 4,5 MB. ~10 MB innecesarios | medio | bajo |
| D-6 | Sin tests, sin ESLint, sin CI. `.prettierrc` existe pero nadie lo corre | medio | medio |
| D-9 | `promotions` / `promotion_products` existen en la base pero el admin guarda promos en `localStorage` | medio | medio |
| D-11 | `product_variants.stock` sigue existiendo y contradice la fuente de verdad | medio | medio |
| D-12 | `Shop.vue` importa `categories` de `mockData` en vez de leerlas del store | bajo | trivial |
| D-13 | Bundle de 528 KB en un solo chunk, sin code-splitting por ruta | bajo | bajo |
| D-14 | El panel admin no captura transportadora, guía ni fecha estimada; `shipments` tiene las columnas pero la UI no las usa | medio | medio |
| D-15 | Comprobantes de pago (`proof_url`, `proof_name`) sin interfaz de carga | medio | medio |

---

## 5. Sprint B — validar la operación

Las migraciones ya están aplicadas. Lo que falta es probar el flujo con datos
reales, que es lo único que nunca se ha hecho.

1. **Prueba end-to-end** contra la base, con capturas en cada paso:
   producto → variante → proveedor → orden de compra → entrada a bodega →
   transferencia parcial a venta → pedido desde el storefront → confirmación de
   pago → envío → devolución. Verificar saldos y `audit_logs` en cada paso.
2. Probar dos pedidos concurrentes reales por la última unidad, desde dos
   navegadores distintos.
3. Verificar que el panel admin **guarda de verdad** ahora que las políticas RLS
   están: crear una categoría, una marca, cambiar un precio, y confirmar en la
   base. Esto es lo que antes fallaba en silencio.
4. Confirmar que la tienda pública ya no muestra "sin stock" con stock
   disponible (era el bug B-8).
5. Revisar el Advisor Center de Supabase por si las políticas nuevas levantan
   alguna advertencia de rendimiento.

## 6. Sprint C — sostenibilidad

8. D-1: partir `inventory.js` en `catalog.js`, `suppliers.js`, `purchases.js`,
   `warehouse.js`, `saleInventory.js`, `pos.js`. Borrar rutas legacy.
9. D-6: ESLint + Prettier + workflow de GitHub Actions con `npm run build`.
10. D-5: deduplicar y comprimir imágenes a WebP.
11. D-9: conectar el módulo de promociones a la base.
12. D-11: migrar `product_variants.stock` a movimientos y eliminar la columna.
13. D-14 y D-15: completar datos de envío y comprobantes de pago.

---

## 7. Decisiones tomadas (no volver a discutir sin motivo)

- Venta por WhatsApp, pero **el pedido se registra en la base antes** de abrir WhatsApp.
- Un solo rol admin: `super_admin`. Sin roles granulares en esta fase.
- Estados de pedido: `pending`, `paid`, `shipped`, `returned`.
- Toda compra entra **primero a bodega**; el paso a venta es una transferencia
  aparte y puede ser parcial.
- El stock **nunca** es una columna: se deriva de `inventory_movements`.
- Las devoluciones son movimientos compensatorios. **No se borra historial.**
- No se borran productos históricos; se pausan o archivan.
- Supabase Auth es el único mecanismo de autenticación. **No hay modo demo.**
- Nada de fallbacks silenciosos: si la base falla, la interfaz lo dice.

---

## 8. Bitácora

| Fecha | Sesión | Qué se hizo |
|---|---|---|
| 2026-08-23 | — | Revisión de arquitectura contra el código; 14 diferencias documentadas en `docs/arquitectura-proyecto-strawberry.md` §10.3 |
| 2026-09-03 | Claude | Lectura completa del proyecto. Se crearon `CLAUDE.md` y `HANDOFF.md`. Identificados B-1 a B-4, S-1 a S-3, D-1 a D-11 |
| 2026-09-03 | Claude | **Sprint A — código.** Encontrados 5 bugs críticos más (B-7 a B-11) y, al reproducir la base en PostgreSQL local, el B-13 de las políticas RLS perdidas. 6 migraciones numeradas e idempotentes, verificadas con pruebas de flujo, concurrencia e idempotencia. Frontend: modo demo eliminado, cálculo de stock corregido, auditoría unificada, mapeo de estados centralizado. `npm run build` pasa. |
| 2026-09-03 | Claude | **Sprint A — migraciones aplicadas.** El diagnóstico confirmó B-13 en producción: `sales`, `sale_items`, `shipments`, `promotion_products` y `admins` sin ninguna política, y `orders`/`payments`/`customers`/`order_items` solo con el insert público. Aplicadas 001–006. La 003 tuvo que repetirse: el diálogo de confirmación de Supabase no se aceptó y el panel mostró el resultado anterior como si hubiera funcionado. Estado final verificado: ninguna tabla con RLS sin políticas, `updated_at` en las 5 tablas, 8 funciones y 8 triggers de auditoría, índice antidoble presente, `public.admins` eliminada. También se descubrió que el ref de Supabase del README era de otro proyecto. |
