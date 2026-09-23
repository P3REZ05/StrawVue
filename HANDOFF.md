# HANDOFF.md — Strawberry Makeup

Estado vivo del proyecto. Se actualiza **al final de cada sesión de trabajo**.
Para saber *cómo* trabajar en el repo, lee `CLAUDE.md`. Este archivo dice *qué sigue*.

- **Última actualización:** 21 de septiembre de 2026
- **Rama activa:** `dev` (remoto `P3REZ05/StrawVue`)
- **Fase:** cierre operativo. No se agregan features hasta validar el flujo real.
- **Sprint A:** ✅ **completo.** Código verificado y las 6 migraciones aplicadas en Supabase.
- **Sprint B:** ✅ **cerrado.** El pedido funciona de punta a punta, verificado dos veces con datos reales.
- **Refactor de productos:** ✅ **completo.** Las ocho etapas, incluidas la 6 (trazabilidad) y la 8 (retirar legacy).
- **Ciclo del pedido:** cerrado (estado entregado, datos de envío, comprobante de pago).
- **Promociones:** motor funcionando, con precios calculados en el servidor.
- **Reportes y margen:** ✅ construido. Utilidad real contra el costo promedio ponderado de las compras.
- **Venta de mostrador:** ✅ atómica y con precio del servidor, igual que el pedido online (migración 013).
- **Configuración:** ✅ real contra `store_settings`, migración 014 aplicada y verificada. Banners de portada en base de datos.
- **Lint y CI:** ✅ ESLint 9 en cero errores y un workflow de GitHub Actions que corre `lint` + `build` + `smoke`.
- **Portada:** ✅ «Ofertas especiales» se edita desde el panel, con vista previa antes de publicar. Categorías rehechas.
- **Responsive:** ✅ auditado en 6 anchos y sin hallazgos; `npm run responsive` lo vigila en cada push.
- **Stores:** ✅ el monolito se partió. `inventory.js` pasó de 662 a 366 líneas y solo lleva existencias (deuda D-1 cerrada).
- **Inventario:** ✅ tres paradas en el orden real (Compras → Bodega → Listo para vender). Bodega tiene pantalla y ficha propias.
- **Plan de pruebas:** ✅ `PRUEBAS.md`, 192 comprobaciones manuales ordenadas por el flujo del negocio.
- **Subir cambios:** ✅ `subir-cambios.ps1` agrupa lo que haya sin versionar en commits temáticos y ofrece publicar.
- **Favoritos:** ✅ corazón en la tarjeta y en la ficha, contador en la cabecera y página propia.
- **Etiquetas:** ✅ VIRAL, NUEVO y las que crees, con su color, editables desde el panel.
- **Publicar:** ✅ la base impide poner un producto a la venta sin unidades en la vitrina.
- **Compras:** ✅ se pueden corregir, con varias líneas por orden y en una sola transacción.
- **Colecciones:** ✅ cada una es una fila en la portada con su título y un carrusel de sus productos; también filtran la tienda.
- **Proyecto Supabase real:** `StrawBack` (`gjchbbvqoigvhildddfw`), org `Strawberry-Makeup`.

---

## 0. LO PRIMERO AL RETOMAR

**El proyecto ya vende.** El pedido se probó completo dos veces con datos reales:
carrito con tonos → pedido → pago → envío con guía → entregado, y también la
variante con devolución. El stock se descuenta y reingresa por tono, y el
historial de movimientos queda intacto.

**Migraciones aplicadas: 001 a 028.** Las tres últimas se aplicaron el 21 de
septiembre desde el SQL Editor, en orden y verificando cada una:

- **026** — `collections` creada (10 columnas, 2 políticas RLS),
  `products.collection_id` presente, `homeCollectionsVisible = true`.
- **027** — las tres columnas de logo de `brands` ya no están
  (`brands_logo_restante = 0`) y su respaldo quedó en
  `respaldo.brands_logos_027`.
- **028** — las seis políticas de admin quedaron acotadas a `authenticated`;
  la comprobación final devuelve cero políticas todavía abiertas a `public`.

**Migraciones aplicadas antes de esta sesión: 001 a 024.** Las cinco que faltaban —018, 019, 020,
021 y 022— se aplicaron el 15 de septiembre, y la **023** y la **024** el mismo día desde el SQL Editor, en ese orden,
comprobando el resultado de cada una. Estado verificado después:
`home_offers` y `product_badges` existen, el trigger
`trg_products_exigir_stock` y la función `save_purchase_order` existen, y las
columnas `products.is_featured` y `product_variants.stock` ya no están.

Dos cosas que dejaron las migraciones y conviene mirar:

1. **La etiqueta NUEVO quedó puesta a 5 productos** —todo el catálogo—, porque
   la columna `is_new` tenía `default true` y nadie la había decidido nunca.
   Repásala en el panel, sección **Etiquetas**, y quítala de lo que ya no sea
   nuevo. DESTACADO quedó en 1 producto y RECOMENDADO en 3; VIRAL, en ninguno.
2. **Hay un producto publicado sin existencias:** el id 9, «Base de prueba»,
   en `active` con 0 en bodega y 0 a la venta. La migración 021 **no lo tocó a
   propósito** —despublicar en frío sin avisar es peor—, pero la clienta lo ve
   y no se lo puedes vender. O le registras la compra, o lo pasas a borrador.

**La pasarela de marcas se retiró entera.** Duró una sesión: se montó el 15 de
septiembre y el usuario dijo que no era lo que esperaba. En su sitio, en la
portada, están ahora las **colecciones**. Se borraron `BrandRunway.vue` y
`PasarelaMarcas.vue`, y las columnas de logo en `brands` las quita la 027. No
quedan restos a medias.

**También pendiente y tuyo:** copiar `.github/workflows/verificar.yml` a la
raíz del repositorio. Esa carpeta está protegida y Claude no puede escribir en
ella; el archivo te llegó en el chat.

**El remoto está atrasado.** GitHub se quedó en el 6 de septiembre y desde
entonces hay ocho frentes de trabajo sin publicar. Para ponerlo al día, desde
PowerShell en la raíz:

```powershell
cd C:\Users\Usuario\Documents\StrawBerry
.\subir-cambios.ps1
```

Agrupa todo en commits temáticos, ofrece correr `lint` + `build` antes de
guardar nada, y pregunta antes de publicar. Es repetible: si se corta a la
mitad, se vuelve a ejecutar y sigue donde iba. Al final ofrece además borrar el
código muerto (`AdminVariants.vue`, `AdminFilter.vue`, `AdminAddFilter.vue`,
`src/data/mockData.js`) en un commit aparte — es la deuda D de §4, y decir que
sí la cierra.

**Lo único que bloquea vender de verdad hoy son las fotos.** La
infraestructura está completa —bucket, optimizador, subida con arrastrar y
soltar— pero el catálogo no tiene ni una imagen. Esto es tuyo, no de Claude.

**La base está limpia.** El 8 de septiembre se borraron todos los datos de
prueba (3 pedidos, 1 venta, 3 clientes, 21 movimientos, 1 mensaje y su
auditoría), con respaldo completo en el esquema `respaldo` de la propia base.
El catálogo, las promociones y la configuración se conservaron.

**Consecuencia: el stock está en cero para todo.** Se reconstruye registrando
las compras reales al proveedor → bodega → transferencia a venta. Es el flujo
canónico, no un rodeo.

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
| 2 | **Borrar código muerto** | `AdminVariants.vue`, `AdminFilter.vue`, `AdminAddFilter.vue` y `src/data/mockData.js`: nadie los importa. **Tarea del usuario: Claude no puede borrar archivos de tu disco** |
| 3 | **Aplicar las migraciones 019 y 018** | Tarea del usuario. La **019 hace falta** para que funcione «Ofertas especiales»; la 018 solo limpia. Las dos probadas en Postgres local. El panel de Supabase no carga en el navegador de Claude |
| 4 | Copiar el workflow de CI | Tarea del usuario. `.github/` está protegida y Claude no puede escribir ahí |
| 5 | Ampliar las pruebas | `npm run smoke` cubre que nada esté en blanco. Falta probar la lógica: precios heredados, envío, combos, estados de pedido. **Es lo único de código que queda** |
| 6 | Panel usable en el móvil | Aplazado por decisión del usuario. Sigue pendiente: tablas de diez columnas y el panel se administrará desde el teléfono |
| 7 | Precio de "Brochas Ani-k" | Guardado como `40`, no `40.000`. Dato, no código: corrígelo desde el editor |
| 8 | Borrar `StrawBerry\supabase\` | Carpeta suelta creada por error en una sesión anterior. La buena es `StrawBerry\main\supabase\` |

**Roles: descartados.** No es deuda pendiente, es una decisión —ver §7.

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
| D-1 | ~~`inventory.js` monolito~~ — resuelto el 2026-09-09: extraídos `suppliers.js`, `purchases.js` y `pos.js`, y borrada la capa de delegaciones al catálogo | — | — |
| D-4 | El histórico de `main/supabase/*.sql` sigue sin numerar. Las migraciones nuevas sí lo están | bajo | bajo |
| D-5 | `assets/images/` y `assets/styles/images/carrusel-home/` son los mismos 15 PNG duplicados; `pexels.jpg` pesa 4,5 MB. ~10 MB innecesarios | medio | bajo |
| D-6 | Sin tests **automáticos** de lógica. ~~ESLint~~ y ~~CI~~ resueltos el 2026-09-09, y el 2026-09-14 `PRUEBAS.md` cubre la parte manual; falta automatizar precios heredados, envío, combos y estados de pedido | medio | medio |
| D-9 | ~~El admin guardaba promos en `localStorage`~~ — resuelto con las migraciones 010 y 011: el panel escribe en `promotions` y el precio lo calcula el servidor | — | — |
| D-11 | ~~`product_variants.stock`~~ — resuelto en la migración 018, junto con `products.image` | — | — |
| D-12 | ~~`Shop.vue` importaba `categories` de `mockData`~~ — resuelto; `mockData.js` ya no lo importa nadie | — | — |
| D-13 | ~~Bundle de 528 KB en un solo chunk~~ — resuelto con `import()` por ruta y `manualChunks` | — | — |
| D-14 | ~~Sin captura de transportadora, guía ni fecha estimada~~ — resuelto con la migración 009 y el estado `entregado` | — | — |
| D-15 | ~~Comprobantes de pago sin interfaz de carga~~ — resuelto: bucket privado con URLs firmadas de 5 minutos (migración 009) | — | — |
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
- **Un solo rol admin: `super_admin`. Sin roles granulares, y no se van a
  construir** (decisión del usuario, 2026-09-08). La tienda la administra una
  sola persona; un sistema de permisos para un usuario es código que hay que
  mantener y que no protege de nada. `admin.js:hasAccess()` devuelve `true`
  para todo **a propósito** — no es un bug pendiente. Si algún día entra una
  segunda persona al panel, se replantea entonces.
- **Del cliente no se guarda cuenta.** Sus datos viajan con el pedido y quedan
  en el caché del navegador; no hay registro ni login de clientas.
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
| 2026-09-21 | Claude | **Las colecciones se rehicieron: de una foto a una fila de productos.** La primera versión enseñaba solo la imagen de cada colección; el usuario aclaró que quería lo contrario — tarjetas de producto con su precio, tipo tienda, con flechas para recorrerlas y un título que él pueda escribir. Ahora cada colección publicada es una fila (`CollectionRow.vue`) con título, subtítulo, foto de cabecera opcional, «Ver todo» y un carrusel que monta el **mismo** `ProductCard.vue` de la tienda: una tarjeta reducida «para el home» habría acabado mostrando un precio distinto del real. El carrusel es scroll nativo con `scroll-snap` — sin librería y sin `transform` calculado —, las flechas solo llaman a `scrollBy`, se desactivan en los extremos y no se pintan si todo cabe en pantalla; en el móvil la siguiente tarjeta asoma, que es lo que invita a arrastrar. Sale en la portada la colección publicada **con al menos un producto**: una fila con título y cero tarjetas se lee como una página rota. El campo que era «nota interna» pasó a ser el subtítulo público (sin migración: la columna ya estaba). **Tamaños de imagen escritos en el panel**, que era el otro pedido: 1920×800 px para el banner de portada, 1600×500 para la cabecera de colección, y por tipo de tarjeta en Ofertas (destacada 1200×700, ancha 1200×340, alta 600×700, pequeña 600×340), con el aviso de que se recortan por el centro. De paso se aplicó la revisión de sobreingeniería sobre el trabajo del día: fuera `refresh()`, `updatedAt`, los `loading`/`error` de solo escritura y un getter duplicado del store; `saveImagen`+`removeImagen` fundidos en `setImagen`; `subirImagenSuelta` sin objeto de opciones; y los dos guiones de prueba en uno solo (`scripts/pruebas-colecciones.mjs`, 37 comprobaciones), unas 280 líneas menos. Lint, build, humo, responsive en seis anchos y las 37 comprobaciones, todo en verde. |
| 2026-09-21 | Claude | **Colecciones, en el sitio donde estuvo la pasarela de marcas.** La pasarela duró una sesión: el usuario la vio y dijo que no era lo que esperaba, así que se retiró entera —`BrandRunway.vue`, `PasarelaMarcas.vue`, las cuatro acciones del store y el cartel de «Categorías y atributos»— en vez de dejarla apagada acumulando código muerto. En su lugar, **colecciones**: grupos comerciales de productos que no comparten ni categoría ni marca («Colección Alisia» puede llevar una base, dos labiales y un rubor) y de los que **solo se enseña su foto**, que fue el pedido literal. Al tocar una se abre la tienda filtrada por ella (`/tienda?coleccion=alisia`), y allí hay un desplegable de Colecciones junto al de Categorías. Tres decisiones que conviene no revisar sin motivo: **un producto pertenece como mucho a una colección** (columna `products.collection_id`, no tabla de cruce — decisión explícita del usuario); **borrar una colección no borra sus productos** (`on delete set null`); y **la foto solo es obligatoria para la portada**, no para el filtro de la tienda, así que hay dos getters distintos (`visibles` y `publicadas`) y unificarlos rompería uno de los dos. El interruptor de la sección entera vive en `store_settings.homeCollectionsVisible` y la apaga sin despublicar nada. De paso se arregló un fallo viejo de la tienda: cada filtro escribía la URL entera, así que elegir una categoría te sacaba de «Ofertas»; ahora se conserva lo que ya estuviera puesto. Migraciones **026** (colecciones), **027** (retirar los logos de marca de la 025, con respaldo) y **028** (seis políticas de admin acotadas a `to authenticated`), probadas en un PostgreSQL 16 local — idempotencia, colisión de slugs, borrado que deja los productos vivos, y el formulario de contacto anónimo intacto tras la 028. Verificación del frontend: `lint` + `build` + prueba de humo de las 10 rutas, más dos guiones nuevos contra el build real con Supabase sembrado — `scripts/pruebas-colecciones.mjs` (15 comprobaciones: portada, orden, enlaces, filtrado, URL compartible, interruptor) y `scripts/pruebas-colecciones-panel.mjs` (16: alta sin slug, publicar, reordenar reescribiendo todas las posiciones, aviso de productos que quedan sueltos y el selector del editor de producto). Todas en verde. |
| 2026-09-15 | Claude | **Dos errores que solo aparecen contra Supabase, no contra un Postgres de pruebas.** **(1) «DELETE requires a WHERE clause»** al registrar una compra. Supabase carga la extensión `safeupdate` para los roles `anon` y `authenticated`, que rechaza cualquier DELETE o UPDATE sin `WHERE` — una red de seguridad sensata—, y `save_purchase_order` vaciaba dos tablas temporales con `delete from tabla;`. Lo importante es **por qué no se vio antes**: el editor SQL de Supabase corre como `postgres`, que no tiene esa protección, así que la migración 022 se aplicó sin una queja y falló solo cuando la llamó la aplicación. Migración **024**: la función usa ahora una sola tabla temporal creada **ya llena** con `create table as` a partir del JSON — sin `delete`, sin `insert` previo y con un paso menos, porque normalizar y agrupar pasan a ser una sola consulta. Repasadas todas las migraciones en busca de más DML sin `WHERE`: solo quedaba uno, en la 004, y es de un script que ya se ejecutó como `postgres`. Queda escrito en `CLAUDE.md` como regla. **(2) El slug de las etiquetas.** Crear una etiqueta fallaba con `duplicate key value violates unique constraint`: lo calculaba el frontend mirando su lista local, que puede estar incompleta. Migración **023**: lo genera un trigger y, si choca, numera —«NUEVO» dos veces son `nuevo` y `nuevo-2`—, en vez de perder lo escrito por un detalle interno que el usuario no ve. Probado con acentos, mayúsculas, símbolos, nombres de solo emoji y el mismo nombre tres veces, en local y en la base real. Las dos migraciones aplicadas y verificadas. |
| 2026-09-15 | Claude | **Dos fallos de la sesión anterior, y las migraciones por fin aplicadas.** Al usar lo construido salieron dos cosas. **(1) La tienda pintaba todo «Agotado».** Leía las existencias de la vista `inventory_balances`, que tiene `security_invoker = true`: al consultarla se leen por debajo los `inventory_movements` con los permisos de quien pregunta, y la única política de esa tabla es `TO authenticated USING (is_admin())`. Una clienta anónima recibía **cero filas y ningún error** —la trampa de RLS que el propio `CLAUDE.md` ya documentaba—, así que `saleStock` salía 0 para todo el catálogo. Comprobado en Postgres local: el mismo producto con 10 unidades devuelve 10 como admin y 0 filas como anónimo. Ahora la tienda lee `inventory_sale_balances`, tabla de lectura pública mantenida por trigger con los mismos movimientos; el panel sigue con la vista completa. Y una segunda causa del mismo síntoma: unas unidades compradas contra el «producto base» en un producto con tonos no las cuenta nadie, porque la tienda suma tono a tono — Compras ya no deja crearlas y Bodega y Listo para vender avisan de las que hubiera. **(2) No se podían crear etiquetas**, fallaba con `duplicate key value violates unique constraint`. El slug lo calculaba el frontend mirando su lista local, que puede no estar completa; migración **023**: lo genera un trigger y, si choca, numera. Mismo error de fondo que el costo de envío y el precio de los combos —dos sitios calculando el mismo valor—, y misma solución: lo calcula quien ve todas las filas. **Y lo importante: las migraciones 018 a 023 están aplicadas.** El panel de Supabase, que llevaba días saliendo en blanco, esta vez cargó, así que se aplicaron una por una comprobando el resultado de cada una. Aparecieron dos cosas que el usuario debe decidir: la etiqueta NUEVO quedó puesta a los 5 productos (porque `is_new` tenía `default true` y nadie lo decidió nunca), y hay un producto publicado sin existencias, el id 9 «Base de prueba», que la 021 detectó y **no tocó a propósito**. |
| 2026-09-15 | Claude | **Favoritos, etiquetas, y dos reglas que faltaban.** Cinco frentes. **(1) Favoritos.** Corazón en la tarjeta y en la ficha, contador junto al carrito y página propia con quitar y «pasar al carrito e ir a pagar». Se guardan en el navegador, como el carrito: la tienda no tiene cuentas de cliente y es una decisión tomada, no una carencia. La lista guarda **solo identificadores**, así que el precio y la foto se resuelven al pintar y un producto retirado desaparece en vez de quedarse como un fantasma con datos viejos. El corazón va **fuera** del enlace de la foto: dentro, cada pulsación sería también una navegación, y `.prevent` no basta en el móvil. Un favorito con tonos no se pasa al carrito desde la lista —habría que elegir color por ella, que es justo el error que hace llegar el pedido equivocado—: lleva a la ficha. **(2) Etiquetas.** Eran tres casillas fijas con dos problemas: no se podía crear una cuarta sin tocar código, y **ninguna de las tres se veía en la tienda** — se marcaban y no pasaba nada. Migración **020** con `product_badges`, su color y su pantalla en el panel; los tres booleanos se migran a etiquetas, se respaldan y se sueltan. Siguen siendo escaparate: una que diga «2x1» lo anuncia, el descuento lo cobra el servidor. **(3) Publicar exige stock.** Se podía crear un producto, ponerlo en activo y quedaba en la tienda sin haberle comprado una unidad al proveedor: la clienta lo metía al carrito y el pedido se rechazaba. Migración **021**, un trigger que solo mira la *transición* a publicado —un producto activo que se agota se sigue pudiendo editar— y cuyo error dice qué falta, porque «nunca lo has comprado» y «lo tienes en bodega y falta pasarlo a la vitrina» son dos botones distintos en dos pantallas distintas. **(4) El inventario se lee entero.** Productos era una sección aparte del menú, así que crear un producto y meterlo en inventario parecían dos tareas distintas cuando son la misma: ahora es el paso 1 de cuatro, con flechas de siguiente y anterior también en el editor de producto, y cada paso y cada campo con un botón de «i» que dice qué hace y **dónde se ve** — el dato que de verdad faltaba. **(5) Las compras se corrigen.** Registrar era un camino de ida y un cero de más quedaba para siempre, arrastrando el costo promedio del que sale el margen; además no era atómico —tres INSERT desde el navegador, con errores que explicaban cómo arreglarlo a mano—. Migración **022** con `save_purchase_order`: crea y corrige en una transacción, y la corrección **no borra historial**, escribe una compra negativa que anula la anterior. Se anula con `purchase` negativo y no con `adjustment` porque un ajuste no cuenta para `costo_promedio`: anular con ajustes dejaría la media sobre unidades que nunca se compraron. No se puede bajar una compra por debajo de lo que ya salió a la vitrina, y la base dice cuál es el mínimo. De paso, una compra ya admite varias líneas. **Verificado:** las tres migraciones en Postgres local sobre el histórico completo, con 8 casos de la regla de publicación y 7 de la corrección de compras (incluidas dos correcciones seguidas sin contar doble, el límite con mercancía ya transferida, y que una línea inválida no deje rastro); lint en cero, build, 10 rutas de humo, las seis anchuras sin hallazgos, y 41 comprobaciones con Playwright sobre la build real —16 de tienda y 25 de panel— sin un solo error de consola. |
| 2026-09-14 | Claude | **Cuatro arreglos de tienda y un script para publicar.** **(1) El recuadro de la foto del producto no tenía alto propio**: lo ponía la imagen, así que una foto vertical estiraba el bloque, una horizontal lo encogía, y al pasar de una miniatura a otra la página entera daba un salto — el defecto se notaba justo al hacer lo que queremos que haga la clienta, mirar todas las fotos. Ahora es un cuadrado fijo con `object-contain`: la foto se ve completa, sin recortar ni deformar, y el recuadro no se mueve. **(2) El rebote vertical.** Al empujar el scroll más allá del final aparecía una franja blanca arriba o abajo: el navegador separa la página y deja ver el fondo del documento. La tentación era pintar ese fondo del color del pie, pero la cabecera es rosa y el pie negro, así que **ningún fondo único contenta a los dos**; lo que se quita es el rebote, con `overscroll-behavior-y: none`. De regalo, el scroll ya no se encadena al fondo cuando se llega al final de un modal o del carrito. **(3) Contacto, rehecha.** Era un formulario y poco más. Ahora tiene portada con dos llamadas, seis ventajas de comprar aquí, una sección propia para el **plan emprendedor** —para quien quiera revender— y cinco preguntas frecuentes. **Sin cifras inventadas**: decisión explícita del usuario, las condiciones se hablan por WhatsApp. Cada botón abre el chat con el mensaje ya escrito según de dónde se pulse, y el número sale de la configuración del sitio y se limpia antes de armar el enlace, porque `wa.me` no admite espacios ni el signo más. El formulario sigue siendo el de verdad: escribe en `contact_messages` y solo dice «recibido» cuando la base confirma. **(4) `subir-cambios.ps1`.** El remoto llevaba desde el 6 de septiembre sin actualizarse y ocho frentes de trabajo esperando. El script agrupa lo que haya sin versionar en diez commits temáticos con su mensaje ya escrito, ofrece correr `lint` + `build` (o la verificación completa) antes de guardar nada, y pregunta antes de publicar. Dos decisiones que importan: **cada bloque comprueba si de verdad quedó algo preparado** antes de hacer `commit`, así que es repetible y no deja commits vacíos si se corta a la mitad; y **no usa `$ErrorActionPreference = 'Stop'`**, porque en PowerShell 5.1 cualquier aviso que git escriba en stderr se convierte en excepción y abortaría el script con la mitad de los commits hechos — mira el código de salida de git, que es lo que de verdad dice si falló. Se probó de verdad: se levantó un repositorio de mentira con los 58 archivos del estado del 6 de septiembre más los 29 cambios, y se ejecutó. Resultado: 8 commits creados, 4 bloques saltados solos por no tener cambios, `PurchaseInventory.vue` eliminado con `git rm`, y una segunda pasada que dijo «no hay nada que versionar». La guarda del `.env` también se probó quitándolo del `.gitignore`: el script se paró en seco. Verificado el resto: lint en cero errores, build, y Playwright sobre la build real confirmando que el enlace de WhatsApp normaliza `+57 323 527 5634` a `wa.me/573235275634`, que el ancla del plan emprendedor funciona, que el acordeón abre y que no hay errores de consola ni a 1280 ni a 390 px. |
| 2026-09-14 | Claude | **El plan de pruebas.** `PRUEBAS.md`: 192 comprobaciones en 17 bloques, ordenadas por el recorrido real del negocio —configurar, crear producto, comprar al proveedor, pasar a bodega, sacar a la vitrina, vender, cobrar, enviar, devolver— y no por pantallas del panel, que es como se escriben los planes que nadie termina. Cada caso dice qué hacer, qué debe pasar y **cómo comprobar que pasó de verdad** (releer tras recargar, mirar el movimiento en el historial), porque el fallo recurrente de este proyecto es justamente el contrario: la pantalla dice que guardó y no guardó. Abre con un aviso: hazlo contra un proyecto de Supabase aparte —`StrawBack-pruebas`, el plan gratuito permite dos—, o los pedidos y las ventas de prueba quedan mezclados con los reales y no hay forma limpia de separarlos después. |
| 2026-09-14 | Claude | **Inventario: tres paradas, y una pestaña que sobraba.** El usuario no entendía el flujo para crear un producto, y tenía razón: había dos puertas. «Inventario de Compras» **no era un inventario** — era el catálogo completo otra vez, la misma lista que la sección Productos, con un creador recortado a tres campos que paría productos sin precio, sin marca, sin tonos y sin fotos, que luego había que ir a arreglar a la otra pantalla; su botón de archivar, además, no pedía confirmación. Eliminada. Los productos se crean en un solo sitio. La bodega tenía el problema simétrico: **no tenía pantalla**, vivía como una rejilla de tarjetas al final de «Inventario de Venta», que es el paso *siguiente*, así que la mercancía recién comprada había que buscarla dentro de la pantalla de lo que ya estaba a la venta. Ahora es `Warehouse.vue`, parada propia, con unidades, referencias y valor al costo. Y `ProductoEnBodega.vue` es su ficha: une los movimientos con las órdenes de compra para enseñar **la nota que se escribió al registrar la compra**, que era justo lo que el usuario pedía poder ver y no existía en ninguna pantalla. Las pestañas quedan numeradas y en el orden del recorrido: 1 Compras → 2 Bodega → 3 Listo para vender, cada una con una línea que dice qué es. El armado de filas, que Bodega y Venta duplicaban, salió a `composables/useInventoryRows.js`. **Y dos arreglos que salieron por el camino:** las pestañas de Tonos, Imágenes y Trazabilidad del editor estaban bloqueadas hasta guardar el producto y nada lo decía —la pantalla parecía rota—, así que ahora guardan solas al entrar; al probarlo con Playwright se vio que cada clic creaba un producto nuevo, se añadió la guarda de «si el guardado no devuelve un `id`, no avanzo», y la comprobación final creó **exactamente uno**. La galería del producto tampoco era navegable: las miniaturas eran imágenes, no botones, así que la clienta veía que había más fotos y no podía abrirlas. Verificado con la transferencia real: dos movimientos compensatorios, −30 de bodega y +30 de venta. |
| 2026-09-09 | Claude | **La portada, rehecha; y el responsive deja de ser una opinión.** Tres frentes. **(1) Auditoría de responsive.** `npm run responsive` sirve el `dist/` real y recorre siete páginas × seis anchos buscando desborde horizontal, áreas táctiles de menos de 40px y texto bajo 12px, con datos sembrados incómodos a propósito —nombres largos, precios de seis cifras— porque una página vacía nunca desborda. Encontró, y se corrigieron: los puntitos del carrusel medían **8×8 px** (ahora van dentro de un botón de 40 sin engordar el diseño), los iconos de la cabecera 36×36, el botón del banner 32 de alto, la etiqueta "NUEVO" a 10px, y un **desborde real en /nosotros a 768px**: el correo `strawberrymakeupstore@gmail.com` mide 242px de una pieza en una columna de 222, y por esa sola palabra toda la web se podía arrastrar de lado. El verificador se afinó dos veces antes de darlo por bueno: la primera versión marcaba cada enlace del pie, así que ahora mide la *banda libre* —alto más el hueco al vecino tocable—, que es lo que de verdad falla el pulgar. **(2) Los filtros de la tienda en celular.** Eran siete bloques de ancho completo apilados: la clienta llegaba a la tienda y lo primero que veía era un formulario. Ahora van en cuadrícula de dos columnas, el buscador ocupa las dos, y "En stock" y "Ofertas" pasaron de casillas de 14px a interruptores de 44 que comparten fila. **(3) La portada.** «Nuestras categorías» eran tres tarjetas gigantes en un carrusel de cinco páginas: para ver las quince había que pulsar cuatro veces, y en el celular era una pantalla por categoría. Se rehízo como cuadrícula donde caben todas —tres columnas en el celular, ocho en escritorio—, con color, icono y nombre escrito (el color nunca es la única señal) y el conteo real de productos. Y «Ofertas especiales» dejó de estar escrita a mano dentro del componente: migración **019** con `home_offers`, editor propio en el panel, subida de imágenes, etiquetas, cuatro tamaños con nombre que encajan sin dejar huecos, destino elegible (categoría, producto o URL) y **borrador frente a publicada**, para dejar la campaña del viernes lista el martes. La vista previa **monta el mismo componente que la portada**, no una imitación, y avisa cuántas celdas quedan sueltas al final con un empaquetador que reproduce el `grid-flow-dense` del navegador. Verificado: lint en cero, build, 9 rutas de humo y las seis anchuras sin un solo hallazgo. |
| 2026-09-09 | Claude | **El monolito se partió (D-1).** `inventory.js` mezclaba existencias, proveedores, compras, mostrador y media API del catálogo reexportada. Ahora son cuatro archivos con una pregunta cada uno: `inventory.js` (cuántas unidades hay y dónde, 366 líneas), `suppliers.js` (a quién le compramos), `purchases.js` (qué le compramos) y `pos.js` (qué se vendió en el mostrador). Lo que más costaba de justificar era la capa de "delegaciones": veinte getters y acciones que solo reenviaban a `catalog.js`, puestas en su día para no romper pantallas durante aquella migración. Sobrevivieron meses, que es lo que suelen hacer las capas de compatibilidad — se borraron y las ocho pantallas que las usaban llaman ahora a `useCatalogStore()` directamente. `updateSalePrice` se mudó a `catalog.setProductPrice`, donde siempre debió estar: cambia el precio del producto, que es una decisión de catálogo, no de inventario. **Tres cosas aparecieron al mover:** (1) `CatalogSettings.vue` leía las cinco listas con `inventory[activeTab.value]`, un índice dinámico que el linter no puede ver — sustituido por un mapa explícito, porque con el corchete renombrar una lista deja la pestaña vacía sin que nada falle; (2) el `saveSupplier` viejo tenía dos ramas muertas que inventaban un `local-${Date.now()}` si Supabase no estaba configurado, un fallback silencioso contra la regla de §4 (y además imposible, porque `lib/supabase.js` ya revienta sin `.env`); (3) `deactivateSupplier` ponía `active = false` en pantalla **antes** de escribir, así que un fallo dejaba desactivado en la interfaz algo que en la base seguía activo — ahora escribe, comprueba que volvió una fila y luego actualiza. **Y un derroche que nadie iba a notar:** el `init()` único pedía proveedores, compras y ventas de mostrador también en la tienda pública; RLS devuelve cero filas sin error, así que las cuatro consultas de más eran invisibles. Ahora hay `init()` (catálogo y saldos) e `initPanel()`. Verificado en el navegador: las siete secciones tocadas y las tres pestañas de Inventario cargan con datos reales, y una edición de proveedor guardada, releída tras recargar y revertida. Lint en cero errores, build y las 9 rutas de humo pasan. |
| 2026-09-09 | Claude | **Retirar el legacy, y el proyecto por fin tiene linter y CI.** Tres columnas fantasma menos y una portada que ya no miente. `HomeCategories.vue` tenía las 15 categorías escritas a mano: crear "Contorno" en el panel no hacía nada en la portada, borrar una dejaba una tarjeta que llevaba a una tienda vacía, y el botón "Comprar ahora" no tenía destino ni manejador —era un adorno—. Ahora salen de `catalogo.rootCategories` y la tarjeta entera es un enlace a `/tienda?categoria=X`, que ya funcionaba. Las fotos locales se conservan como respaldo por nombre porque `categories.image` está vacío en la base: cambiar en frío habría dejado quince tarjetas grises. Migración **018**: fuera `product_variants.stock` y `products.image`. La segunda merece explicación —lo único que guardaba era `blob:http://localhost:5173/...` del producto 4, una URL que solo existía en la pestaña que la creó y que ni siquiera cargaba—; se comprobó consultando la base real antes de soltarla, y el respaldo de las dos columnas queda en el esquema `respaldo`. Probada en Postgres local: dos pasadas seguidas, las diez vistas siguen ejecutando, ninguna función las menciona, y tanto `create_pos_sale` como `create_order_with_stock` completan una operación real después del `drop`. **Y lo segundo: ESLint 9 y GitHub Actions.** El linter se configuró para atrapar lo que `vite build` compila sin quejarse —variables muertas, `confirm()` colados, `no-undef`— y no para discutir de comillas: las reglas de formato están apagadas a propósito, porque un linter que grita por una coma entrena a la gente a ignorarlo. Se probó `require-atomic-updates` y **se descartó documentándolo**: marcaba trece sitios, los trece correctos (limpiar un formulario después de que la base confirma es el patrón normal en Vue). Quedaron cinco restos reales de refactors viejos: un `formatCurrency` sin usar, un `storeToRefs` huérfano, y `anterior` y `localId`, variables que sobrevivieron a los cambios que las dejaron sin sentido. Cero errores. El workflow corre `lint` + `build` + `smoke` en push y en PR sobre `main` y `dev`, y guarda el `dist/` cuando algo falla. Las 9 rutas de la prueba de humo siguen pasando. |
| 2026-09-08 | Claude | **Etapa 6: trazabilidad del producto.** Los datos existían desde hacía meses y nadie podía leerlos: `inventory_movements` en unidades y `audit_logs` en `jsonb` crudo. La vista `report_trazabilidad` los une, pero el trabajo de verdad fue **traducir**: `etiqueta_columna()` pone nombres en español, `valor_legible()` formatea precios al estilo colombiano y booleanos a sí/no, y `nombre_referencia()` resuelve las claves foráneas —"Cobertura: → 1" pasó a "Cobertura: → Alta"—. `describir_cambio()` devuelve NULL cuando no cambió nada relevante, lo que deja fuera los UPDATE que solo movieron `updated_at`. Un detalle de negocio: en un tono, precio vacío no es "nada", es *hereda del producto*. Pantalla nueva `product/Trazabilidad.vue`: agrupada por día, con filtros, resumen de unidades entradas y salidas, e iconos con su título escrito al lado —no un semáforo de puntitos que haya que memorizar—. **Y destapó un fallo:** cambiar precio o estado escribía DOS filas de auditoría, la del trigger y una `logAudit` a mano, contra la regla que el propio `CLAUDE.md` ya documentaba; la línea de tiempo contaba cada cambio dos veces. Quitados los `logAudit` redundantes de tres acciones, y la vista colapsa el histórico duplicado quedándose con la del trigger. Verificado con un ciclo real: compra de 24 unidades con su costo, transferencia a venta y cambio de precio, de 18 eventos a 16 sin duplicados. |
| 2026-09-08 | Claude | **Verificación visual del 2x1 y limpieza de la base.** Comprobado en pantalla: el selector de tipo ofrece "Combo (2x1, 3x2…)", el formulario explica el efecto en palabras ("Llevando 2 productos que apliquen, paga 1 y la unidad más barata sale gratis") y rechaza un 2x5 antes de guardar. En el carrito: subtotal $60.640, línea verde "2x1 −$30.320", total $40.320. **Y la prueba que importaba: se hizo el pedido de verdad y el servidor cobró $40.320, exactamente lo que mostraba el carrito.** Después, borrado de datos de prueba autorizado por el usuario: respaldo previo de las 10 tablas (147 filas) en el esquema `respaldo` de la propia base —más robusto que un JSON descargado— y borrado de pedidos, ventas, clientes, movimientos, mensajes y su auditoría, con las secuencias reiniciadas. Se conservó catálogo, promociones y configuración. Documentado en `supabase/reset_datos_prueba.sql`, incluida la justificación de la excepción a la regla de no borrar `inventory_movements`. Las 10 secciones del panel siguen cargando con la base vacía. |
| 2026-09-08 | Claude | **Combos 2x1, y un fallo de reportes que llevaba desde la 010.** `buy_quantity` y `get_quantity` existían desde marzo y nunca se evaluaron: se podía crear un 2x1 en el panel y no descontaba nada. No cabía en `precio_efectivo` porque esa función responde *cuánto vale UNA unidad* y un 2x1 no tiene respuesta a eso; se calcula sobre el carrito entero con `descuento_combos`. Reglas decididas a propósito: cruza líneas (dos labiales distintos cuentan como dos), regala las unidades **más baratas**, solo se aplica un combo, y el cupón se calcula **después** sobre lo que queda —al revés, un 2x1 con cupón del 20% descontaría dos veces sobre la unidad regalada—. Aplicado a pedido online y a mostrador. El carrito lo muestra antes de confirmar preguntándole a la base, no recalculando en JavaScript: una segunda implementación acabaría discrepando, como ya pasó con el envío. **Y salió un fallo peor:** `report_ventas_linea` sumaba `quantity * unit_price`, el bruto, y el descuento de documento no se restaba en ningún sitio, así que un pedido con cupón venía inflando ingreso y margen desde la 010. Ahora se reparte proporcionalmente entre las líneas y la suma cuadra al céntimo con lo cobrado. Quince casos probados en Postgres local más una comprobación sobre la base real. Queda un "2x1 en bases" creado y apagado. |
| 2026-09-08 | Claude | **El panel de administración dejó de viajar a la tienda.** Todo el admin —productos, tonos, reportes con sus gráficos, auditoría, proveedores— se descargaba en el mismo archivo que pedía cualquier clienta al entrar a ver un labial. Rutas con `import()` salvo la portada, más reparto de dependencias en `vite.config.js` (`vendor-supabase`, `vendor-vue`, `vendor-iconos`) para que el navegador cachee lo que casi nunca cambia. La carga inicial pasa de **701 KB a 437 KB** en bruto y de **182 KB a 127 KB** comprimidos, un 30% menos; `AdminPanel` (147 KB) y `ProductEditor` (31 KB) solo se piden al entrar al panel. De paso, una ruta inexistente dejaba la pantalla en blanco sin 404 ni redirección: ahora vuelve a la portada. **Y el proyecto tiene su primera prueba automática:** `npm run smoke` (`scripts/smoke.mjs`) sirve el `dist/` real con la API de Vite —nada de encadenar comandos con `&`, que no funciona en PowerShell—, recorre las 9 rutas con Chromium y falla si alguna queda en blanco, suelta un error de consola o descarga el panel siendo pública. Esto último es lo que impide que el code-splitting se pierda con un import descuidado. Las llamadas a Supabase se interceptan, así que corre sin credenciales. Las 9 rutas pasan. |
| 2026-09-08 | Claude | **El formulario de contacto guardaba nada.** `Contact.vue:9` era literalmente `function submit() { sent.value = true }`: el cliente dejaba nombre, correo y teléfono, leía "¡Mensaje recibido!" y el mensaje se perdía. Como nada fallaba de forma visible, llevaba ahí desde el principio. Migración 015 con `contact_messages`, nuevo `stores/contact.js` y sección **Mensajes** en el panel, con contador de sin leer, enlace directo a WhatsApp con el número normalizado, nota interna y archivado. Los permisos van en tres políticas separadas a propósito: cualquiera inserta —es un formulario público— pero **nadie anónimo lee**, porque la tabla guarda datos personales y una lectura pública la convertiría en un directorio servido por la API; verificado contra la base real, un `GET` anónimo devuelve **401**. Tampoco hay `delete` para nadie: un mensaje se archiva. Probado de punta a punta: enviado desde `/contacto`, guardado, contador a 1, marcado leído al abrirlo y archivado. También se aplicó y verificó la **014**: cambié el envío a $14.500 desde el panel y el carrito de la tienda pasó a mostrar $14.500 —antes habría mostrado los $10.000 de `mockData` mientras el servidor cobraba otra cosa—, `config_numero()` devolvió el valor nuevo y un banner insertado en la base apareció en la portada y fue visible para un anónimo. Todo revertido después. |
| 2026-09-07 | Claude | **Configuración deja de ser decorativa.** La pantalla leía de `mockData` y escribía en `localStorage`: cero Supabase. Tres consecuencias, todas reales. (1) El costo de envío del carrito salía de una constante mientras el servidor cobraba el de `store_settings`, así que cambiar el envío en la base hacía que la tienda mostrara un precio y se cobrara otro. (2) **Los banners de la portada vivían en `localStorage`, con las imágenes en base64 dentro**: la administradora los configuraba, los veía en su propio navegador y ningún cliente los veía jamás — además de que dos o tres fotos revientan la cuota de ~5 MB. (3) Redes sociales y WhatsApp harcodeados. Migración 014: claves que faltaban, trigger de `updated_at` (la columna existía y nunca se actualizaba), tabla `home_banners` con RLS y auditoría. Nuevo `stores/settings.js` y `AdminConfiguracion.vue` reescrito con subida real de imágenes a Storage. `Cart`, `CartDrawer`, `Footer`, `About` y `Hero` pasan a leer de ahí. Resultado: **`mockData.js` ya no lo importa nadie**. También corregido `PurchaseInventory.vue`, que llamaba a `addProduct`/`updateProduct` sin `await` ni `try/catch` y cerraba el modal aunque la escritura fallara — el mismo patrón del POS. Migración probada dos veces en Postgres local: idempotente, políticas presentes, `updated_at` se mueve y la auditoría registra INSERT/UPDATE/DELETE. |
| 2026-09-07 | Claude | **B-19: la venta de mostrador podía perderse en silencio.** Auditoría completa del proyecto (8.882 líneas, 13 secciones del panel) que destapó el fallo más caro que quedaba. El POS descontaba stock en memoria, insertaba `sales`, `sale_items` y movimientos comprobando cada paso solo con `console.error`, y el componente ni siquiera esperaba la promesa: vaciaba el carrito y cerraba el modal antes de saber nada. Una venta podía perderse entera, quedar con total pero sin líneas, o registrarse sin descontar stock, y en los tres casos la pantalla decía que todo había salido bien. Además el POS solo mandaba `product_id`: con un catálogo de tonos, la venta no decía cuál se llevó el cliente. Migración 013 con `create_pos_sale`, el mismo blindaje que el pedido online: bloqueo por producto y tono, stock validado, precio del servidor y escritura atómica. Probado en Postgres local — 10 cajas simultáneas por la última unidad dan 1 aceptada y 9 rechazadas con stock final 0, y con `unit_price:1` en el payload cobra igual el precio real. Verificado en vivo con la venta POS-1 (2 tonos, stock por tono descontado, movimientos correctos, y aparece en Reportes con su costo y margen). De paso: el historial de ventas leía `sale.date` y `item.price` cuando las columnas son `sale_date` y `unit_price`, así que mostraba fecha en blanco y $0 por línea. Y el POS pintaba el precio de lista mientras el servidor cobraba el promocional; ahora muestra el efectivo con el de lista tachado. |
| 2026-09-07 | Claude | **Pulido del uso diario.** Fuera los diálogos del navegador: transferir a venta y cambiar precio en `SaleInventory.vue`, y desactivar proveedor en `Suppliers.vue`, ahora usan modales propios que validan mientras escribes (cantidad entera, mayor a cero y no mayor al stock de bodega) y explican qué implica cada acción; la transferencia acepta una nota que queda en `inventory_movements`. **Corregido un fallo silencioso de precios:** editar el precio desde la fila de un tono llamaba a `updateSalePrice`, que toca el producto entero, así que movía también el de todos los tonos que heredan; ahora hay `catalog.setShadePrice`, que distingue `null` (hereda) de `0` (gratis) y solo toca ese tono. Nuevo `catalog.duplicateProduct`: copia ficha y gama completa con SKU únicos (`suggestSku` recorta al mismo prefijo para "X" y "X (copia)" y el índice único habría partido el insert a la mitad), renumera posiciones, nace en borrador y no copia stock ni imágenes. `AdminProductos.vue` reescrito: la lista sale de un `computed` en vez de una copia congelada al montar, búsqueda en vivo por nombre, marca, tono y SKU, filtros de categoría y estado, orden, paginación de 24 y precios con `formatCurrency` (antes se imprimía el número crudo). Verificado en vivo: búsqueda por SKU y por marca, duplicado real de Base Velvet Skin con sus 6 tonos y SKU `-2`, transferencia de 2 unidades con nota en el historial, y el precio de un tono cambiado sin mover el del producto ni el de los otros cinco. Todo revertido después. |
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
