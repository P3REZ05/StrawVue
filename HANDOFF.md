# HANDOFF.md — Strawberry Makeup

Estado vivo del proyecto. Se actualiza **al final de cada sesión de trabajo**.
Para saber *cómo* trabajar en el repo, lee `CLAUDE.md`. Este archivo dice *qué sigue*.

- **Última actualización:** 7 de septiembre de 2026
- **Rama activa:** `dev` (remoto `P3REZ05/StrawVue`)
- **Fase:** cierre operativo. No se agregan features hasta validar el flujo real.
- **Sprint A:** ✅ **completo.** Código verificado y las 6 migraciones aplicadas en Supabase.
- **Sprint B:** ✅ **cerrado.** El pedido funciona de punta a punta, verificado dos veces con datos reales.
- **Refactor de productos:** etapas 1–5 y 7 completas. Faltan la 6 (trazabilidad) y la 8 (retirar legacy).
- **Ciclo del pedido:** cerrado (estado entregado, datos de envío, comprobante de pago).
- **Promociones:** motor funcionando, con precios calculados en el servidor.
- **Reportes y margen:** ✅ construido. Utilidad real contra el costo promedio ponderado de las compras.
- **Proyecto Supabase real:** `StrawBack` (`gjchbbvqoigvhildddfw`), org `Strawberry-Makeup`.

---

## 0. LO PRIMERO AL RETOMAR

**El proyecto ya vende.** El pedido se probó completo dos veces con datos reales:
carrito con tonos → pedido → pago → envío con guía → entregado, y también la
variante con devolución. El stock se descuenta y reingresa por tono, y el
historial de movimientos queda intacto.

Migraciones aplicadas: **001 a 012**. Ninguna pendiente.

**Lo que bloquea vender de verdad hoy:**

1. **No hay fotos de producto.** La infraestructura está completa (bucket,
   optimizador, subida con arrastrar y soltar) pero el catálogo está vacío de
   imágenes. Esto es tuyo, no de Claude.
2. ~~**No se ve el margen.**~~ Resuelto: la sección **Reportes** muestra ingreso,
   costo, utilidad y margen por día, producto, tono y categoría, más las alertas
   de stock. Antes de aplicar un descuento ya se puede ver qué margen se está
   comiendo.

**Pedidos de prueba en la base:** ORD-1 (devuelto), ORD-2 (entregado) y algunos
más de las pruebas del cupón. Se pueden dejar: sirven de referencia y el stock
ya volvió a su sitio.

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

## 2a. Refactor del módulo de productos

Diseño completo en `docs/refactor-modulo-productos.md`. Decisiones tomadas:
editor a página completa, el precio del tono **hereda** del producto (NULL =
hereda), y entrega por etapas.

| Etapa | Estado |
|---|---|
| 1 · Migración 007: modelo de tonos e imágenes | ✅ aplicada y verificada |
| 2 · Supabase Storage + optimizador de imágenes | ✅ bucket creado, código listo |
| 3 · Extraer el store de catálogo | ✅ `catalog.js` creado, panel verificado |
| 4 · Editor de producto a página completa | ✅ verificado en vivo |
| 5 · Editor de tonos con swatches | ✅ chips, lotes y orden; falta subir swatch por tono |
| 6 · Ficha de trazabilidad por producto | pendiente |
| 7 · Chips y filtros en la tienda | ✅ verificado en vivo |
| 8 · Retirar `product_variants.stock` y `products.image` | pendiente |

**Optimizador de imágenes** (`lib/imageOptimizer.js`). Medido sobre las imágenes
reales del proyecto: `pexels.jpg` 4.472 KB → 256 KB (−94 %), banner 1.233 KB →
82 KB (−93 %), logo PNG → WebP sin pérdida −56 % idéntico pixel a pixel.
Con 1 GB del plan gratuito eso son ~4.000 imágenes en vez de 220.

Dato clave para maquillaje: se midió la desviación de color en Delta-E
CIEDE2000 sobre una carta de 10 tonos. Sin pérdida da dE 0,00; WebP q=95 llega a
dE 2,17 en el interior de cada franja, perceptible lado a lado. Por eso el
perfil `swatch` prueba también PNG sin pérdida y se queda con él cuando pesa
menos. El color exacto vive además en `swatch_hex`.

**Separación de stores.** `inventory.js` bajó de 41 KB a 24 KB; el catálogo vive
ahora en `catalog.js`. Los accesos antiguos (`inventory.catalog`,
`inventory.addProduct`…) siguen funcionando como delegaciones para no romper las
pantallas durante la migración; **el código nuevo debe usar `useCatalogStore`**.

Corregido de paso: `updateSalePrice` actualizaba la columna `price` en la base
pero escribía `salePrice` en el objeto local, así que justo después de editar se
veía un precio y al recargar otro.

---

## 2b. Bugs abiertos encontrados durante el Sprint B

### B-15 · Las imágenes de producto no se guardan — **infraestructura lista, falta conectarla**

Resuelto en la base y en la capa de datos: bucket `product-images`, tabla
`product_images`, `lib/storage.js` y `lib/imageOptimizer.js`. **Falta** que el
formulario de producto los use en vez de `URL.createObjectURL`. Hasta entonces
el síntoma sigue vivo: `Brochas Ani-k` tiene guardada una URL `blob:` muerta y
es el único error de consola del panel.

Descripción original del problema:

`AdminProductos.vue` hace `URL.createObjectURL(newProduct.image)` y guarda el
resultado en `products.image`. Ejemplo real en la base:

```
blob:http://localhost:5173/e56228e7-6a88-452c-8d5a-b816177c0
```

Un `blob:` URL solo existe en la pestaña que lo creó. Al recargar está roto, y
para cualquier cliente que entre a la tienda nunca existió. **No hay subida a
almacenamiento en ningún punto del código.**

*Trabajo necesario:* crear un bucket público en Supabase Storage con sus
políticas, subir el archivo al guardar el producto, almacenar la URL pública en
`products.image`, y manejar el reemplazo y borrado al editar. No es trivial.

### B-16 · El formulario de alta no cubre los atributos dinámicos

Corregido a medias. Ya se guardan `category_id` y `brand_id` (antes se perdían:
`AdminProductos.vue` descartaba el `categoryId` que el formulario sí calculaba, y
no existía selector de marca). **Siguen sin selector** en el alta:
`skin_type_id`, `finish_id` y `coverage_id`. Los checkboxes de activación existen
pero no hay desplegable detrás, así que esos campos siempre quedan vacíos.

Completa la §3.1 del documento de arquitectura: los campos condicionales por
categoría (tipo de piel solo en Cuidado facial, cobertura solo en Bases…).

### B-17 · La auditoría no cubre las tablas maestras

El trigger `audit_trigger` se aplicó a 8 tablas, pero no a `categories`,
`brands`, `skin_types`, `finishes` ni `coverages`. Crear o pausar una categoría
cambia qué se le ofrece al cliente y debería dejar rastro. Es una migración `007`
de pocas líneas, reutilizando el bucle del `002`.

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

## 2c. Qué falta

Ordenado por lo que más duele. Se descartó por decisión del usuario todo lo
relativo a lotes, vencimiento y registro sanitario INVIMA.

| # | Qué | Por qué |
|---|---|---|
| 1 | **Fotos reales** | Tarea del usuario. Sin fotos no se vende |
| 2 | Quitar los `prompt()` del navegador | `SaleInventory.vue:54` y `:85`. Transferir a venta —el paso que decide qué ve el cliente— se hace con un diálogo del navegador |
| 3 | Duplicar producto | Una segunda base son 40 tonos tecleados otra vez |
| 4 | Buscador y paginación en productos | Con 200 productos la lista colapsa |
| 5 | Combos y 2x1 | Modelados (`buy_quantity`, `get_quantity`) pero sin evaluar |
| 6 | Trazabilidad del producto (etapa 6) | Los datos están en `audit_logs` e `inventory_movements`; falta la pantalla |
| 7 | Retirar legacy (etapa 8) | `product_variants.stock`, `products.image` |
| 8 | Roles | Quien despache pedidos ve costos, márgenes y proveedores |
| 9 | Móvil | Tablas de diez columnas y se administrará desde el teléfono |
| 10 | Tests, lint, CI | `npm run build` es la única red |

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
| D-16 | Los productos existentes tienen `category` como texto libre y `category_id` nulo; hace falta un backfill una vez que el alta esté correcta | bajo | bajo |

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
| 2026-09-07 | Claude | **Reportes y margen.** Migración 012: `costo_promedio()` (promedio ponderado de compras), vista unificada `report_ventas_linea` que junta online y punto físico, agregados por producto, tono, día y categoría, `report_riesgo_stock` y `orders.discount_total`. Pantalla de Reportes con fichas, gráficos SVG propios (sin dependencia de librería), vista de tabla y paleta validada con el verificador de daltonismo. Números cuadrados contra la base: $113.700 de ingreso, $54.000 de costo, 52,5 % de margen. Corregidos dos fallos de agrupación que partían un mismo producto en varias filas por leer el nombre guardado en la venta (`"Producto — Tono"`, con separador cambiado entre versiones) en vez del catálogo: uno en Reportes y otro en el Dashboard. En el Dashboard, además, los ingresos sumaban pedidos pendientes y devueltos y contaban el envío como venta, así que no coincidían con Reportes; ahora ambos usan la misma regla (`paid`/`shipped`/`delivered`, sin envío). Corregido también el gráfico de línea: con un solo día dibujaba un `moveto` y nada más, así que el panel se veía vacío justo en el caso normal al arrancar; ahora marca los puntos y etiqueta el valor directamente. |
| 2026-08-23 | — | Revisión de arquitectura contra el código; 14 diferencias documentadas en `docs/arquitectura-proyecto-strawberry.md` §10.3 |
| 2026-09-03 | Claude | Lectura completa del proyecto. Se crearon `CLAUDE.md` y `HANDOFF.md`. Identificados B-1 a B-4, S-1 a S-3, D-1 a D-11 |
| 2026-09-03 | Claude | **Sprint A — código.** Encontrados 5 bugs críticos más (B-7 a B-11) y, al reproducir la base en PostgreSQL local, el B-13 de las políticas RLS perdidas. 6 migraciones numeradas e idempotentes, verificadas con pruebas de flujo, concurrencia e idempotencia. Frontend: modo demo eliminado, cálculo de stock corregido, auditoría unificada, mapeo de estados centralizado. `npm run build` pasa. |
| 2026-09-03 | Claude | **Promociones y precios en el servidor.** Migraciones 010 y 011. Descubierto que el RPC aceptaba `unit_price` y `total` del navegador: se probó el ataque (pedir 2 unidades a $1) y ahora el servidor cobra el precio real. Motor de promociones con prioridad, vigencia, cupones con código, compra mínima, usos máximos y envío gratis; verificado en Postgres local con siete casos. Panel de promociones conectado a la base. Aclarado que los "banners del inicio" no son descuentos. Corregido el modelo: el cupón es una propiedad, no un tipo. |
| 2026-09-03 | Claude | **Ciclo del pedido cerrado.** Migración 009 con bucket PRIVADO para comprobantes de pago (llevan datos bancarios del cliente; se ven con URLs firmadas de 5 minutos). Añadido el estado `entregado`, que no existía: los pedidos se quedaban en "enviado" para siempre. Captura de transportadora, guía y fecha estimada. Verificado con ORD-2 de punta a punta. |
| 2026-09-03 | Claude | **Prueba end-to-end del pedido, por fin.** ORD-1 completo: tono 02 Arena, stock 8→6, pago, envío, devolución, stock 6→8 con movimiento compensatorio y la salida original intacta. Encontrado y corregido que el tono no aparecía en ninguna parte del pedido: ni en el carrito, ni en el mensaje de WhatsApp, ni en `order_items.product_name`. Quien empaca no sabía qué tono sacar. |
| 2026-09-03 | Claude | **Refactor de productos, etapas 4, 5 y 7.** Editor a página completa con seis secciones, creación al vuelo de marca y categoría, atributos condicionales por categoría y subida real de imágenes. Editor de tonos con chips, pegado por lotes y reordenación. Vitrina: chips de color, imagen que cambia con el tono, stock por tono y filtros por subtono y familia. Verificado en vivo creando `Base Velvet Skin` con 5 tonos: SKU automáticos, subtonos resueltos, herencia de precio (5 tonos pasaron de $0 a $38.900 con una sola edición), tonos agotados deshabilitados y filtro de subtono devolviendo 1 de 3 productos. Corregido `variant.stock`, columna legacy que ya no se carga y hacía que la ficha mostrara "undefined disponibles". |
| 2026-09-03 | Claude | **Refactor de productos, etapas 1–3.** Investigación sobre modelado de tonos en cosmética (swatch sobre nombre, atributos gobernados, código NC/NW = subtono + profundidad). Migración 007 con `undertones`, `shade_families`, 8 columnas de tono, `product_images` y la vista `storefront_shades`; probada en Postgres local con casos de hex inválido, profundidad fuera de rango, tono por defecto duplicado e imagen principal duplicada. Migración 008: bucket con políticas. Optimizador de imágenes medido con Delta-E. `catalog.js` extraído con parser de lotes de tonos probado en 9 casos. Panel verificado en vivo: 12 secciones sin errores nuevos. |
| 2026-09-03 | Claude | **Sprint B — arranque.** Verificada la app real contra la base migrada: tienda pública y las 12 secciones del panel sin errores de consola, auditoría con registros, y escrituras confirmadas (categoría, marca, proveedor, producto). Corregido el manejo de errores del panel y los textos de la sección Historial. Encontrados B-15 (imágenes en `blob:`), B-16 (atributos dinámicos sin selector) y B-17 (auditoría sin tablas maestras); B-14 corregido: el alta ya guarda `category_id` y `brand_id`. |
| 2026-09-03 | Claude | **Sprint A — migraciones aplicadas.** El diagnóstico confirmó B-13 en producción: `sales`, `sale_items`, `shipments`, `promotion_products` y `admins` sin ninguna política, y `orders`/`payments`/`customers`/`order_items` solo con el insert público. Aplicadas 001–006. La 003 tuvo que repetirse: el diálogo de confirmación de Supabase no se aceptó y el panel mostró el resultado anterior como si hubiera funcionado. Estado final verificado: ninguna tabla con RLS sin políticas, `updated_at` en las 5 tablas, 8 funciones y 8 triggers de auditoría, índice antidoble presente, `public.admins` eliminada. También se descubrió que el ref de Supabase del README era de otro proyecto. |
