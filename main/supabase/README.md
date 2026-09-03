# Base de datos — Strawberry Makeup

Toda la estructura vive en Supabase (Postgres + Auth + RLS).

> **Credenciales:** este archivo no contiene ninguna. La URL y la clave del
> proyecto van en `main/.env`, que está en `.gitignore`. Usa
> `main/.env.example` como plantilla.

---

## Orden de ejecución

Los scripts sueltos de esta carpeta son el **estado histórico** de la base y
ya están aplicados. Las migraciones nuevas viven en `migrations/` y están
numeradas. Ver `migrations/README.md` para el detalle y el estado de cada una.

| # | Archivo | Estado |
|---|---|---|
| 1 | `schema.sql` | aplicado — **no reejecutar** (ver aviso abajo) |
| 2 | `add_audit_logs.sql` | aplicado — **no reejecutar** (hace `drop table ... cascade`) |
| 3 | `atomic_order.sql` | aplicado, reemplazado por `migrations/005` |
| 4 | `product_catalog_migration.sql` | aplicado |
| 5 | `fix_admin_rls.sql` | aplicado, ampliado por `migrations/001` |
| — | `verify_admin_access.sql` | utilidad de diagnóstico, no es migración |
| 6+ | `migrations/*.sql` | ver `migrations/README.md` |

### Aviso: no reejecutes `schema.sql`

`schema.sql` crea el trigger `order_item_inventory_movement`, que descuenta
stock al insertar un `order_item`. Desde `migrations/005` ese descuento lo hace
el RPC `create_order_with_stock`. Si el trigger vuelve a existir, cada pedido
descontaría el stock **dos veces**.

Hay una red de seguridad: el índice único `ux_inventory_movements_pedido_unico`
convierte ese caso en un error visible en vez de una pérdida silenciosa de
inventario. Aun así, no lo reejecutes.

### Aviso: no reejecutes `add_audit_logs.sql`

Empieza con `drop table public.admin_profiles cascade`. Ese CASCADE borra tu
perfil de administrador **y** las políticas RLS que dependen de él. Fue lo que
dejó 13 tablas sin políticas y el panel admin sin poder leer pedidos ni pagos.

---

## Puesta en marcha desde cero

1. Crear el proyecto en [supabase.com](https://supabase.com).
2. **SQL Editor** → ejecutar en orden los archivos de la tabla de arriba.
3. **Authentication → Users → Add user**: crear el usuario administrador con
   una contraseña fuerte y única.
4. Copiar su UUID y ejecutar `verify_admin_access.sql` reemplazando el
   marcador, para darle el perfil `super_admin` en `admin_profiles`.
5. Copiar `main/.env.example` a `main/.env` y completar URL y anon key
   (Settings → API).
6. `cd main && npm install && npm run dev`.

---

## Modelo de datos

Tres capas que no se mezclan:

| Capa | Tablas | Regla |
|---|---|---|
| Catálogo | `products`, `product_variants`, `categories`, `brands`, `skin_types`, `finishes`, `coverages` | no guarda existencias |
| Inventario | `inventory_movements` (historial), `inventory_sale_balances` (saldo público), vista `inventory_balances` | única fuente de verdad del stock |
| Operación | `orders`, `order_items`, `payments`, `shipments`, `customers`, `sales`, `sale_items`, `purchase_orders`, `purchase_order_items`, `suppliers` | nunca escribe stock directo, solo movimientos |

Soporte: `admin_profiles` (perfiles admin), `audit_logs` (auditoría),
`promotions` / `promotion_products`, `store_settings`.

### El stock no es una columna

`products` no tiene `stock`. `product_variants.stock` existe pero es **legacy**
y no debe escribirse desde código nuevo. El disponible se deriva de
`inventory_movements` con esta regla, definida una sola vez en
`movement_sale_delta()` y `movement_warehouse_delta()`:

**Stock de venta**
- `sale` / `online_order` → siempre (cantidad negativa)
- `transfer` / `return` / `adjustment` / `damage` con `reference_type = 'sale_inventory'`

**Stock de bodega**
- `purchase` → siempre entra a bodega
- `transfer` / `return` / `adjustment` / `damage` con `reference_type = 'warehouse'`

### Flujo de un pedido

1. El storefront llama al RPC `create_order_with_stock(...)`.
2. El RPC toma un advisory lock por producto/variante, en orden determinista.
3. Valida el stock disponible con `available_sale_stock()`.
4. Crea cliente, pedido, items, movimiento de salida, pago y envío, todo en
   una sola transacción.
5. Si no alcanza el stock, lanza excepción y no queda nada a medias.

Probado con 10 pedidos simultáneos por la última unidad: uno pasa, nueve se
rechazan, el stock nunca queda negativo.

### Devoluciones

`return_order_stock(p_order_id)` inserta un movimiento `return` compensatorio.
**Nunca** se borran filas de `inventory_movements`: el historial es la fuente
de verdad y la auditoría. La función es idempotente.

---

## Seguridad

- Autenticación: **Supabase Auth** + perfil en `admin_profiles`. No existe
  login local ni modo demo.
- Autorización: la función `public.is_admin()` (SECURITY DEFINER, para no
  recursar sobre RLS) se usa en todas las políticas de admin.
- Escritura pública limitada a `customers`, `orders`, `order_items` y
  `payments`, solo INSERT, para que el cliente pueda crear su pedido.
- Lectura pública: catálogo, categorías, tablas maestras activas, promociones
  activas, `store_settings` y `inventory_sale_balances` (saldo agregado; no
  expone bodega ni historial).
- `audit_logs` no tiene política de UPDATE ni de DELETE: un registro de
  auditoría que se puede editar no es auditoría.

> **Cuidado con RLS:** una tabla con RLS activo y sin políticas queda
> inaccesible, y PostgREST devuelve 0 filas **sin error**. Un SELECT parece
> vacío y un UPDATE parece exitoso. Si algo del panel "funciona pero no
> guarda", revisa las políticas primero con `migrations/000_diagnostico.sql`.
