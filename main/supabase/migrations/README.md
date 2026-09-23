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
| 013 | `013_venta_fisica_atomica.sql` | B-19 (venta de mostrador) | no | ☑ 2026-09-07 |
| 014 | `014_configuracion_y_banners.sql` | Configuración real + banners | no | ☑ 2026-09-08 |
| 015 | `015_mensajes_contacto.sql` | Formulario de contacto | no | ☑ 2026-09-08 |
| 016 | `016_combos_2x1.sql` | Combos 2x1 + ingreso neto | no | ☑ 2026-09-08 |
| 017 | `017_trazabilidad_producto.sql` | Etapa 6: historia del producto | no | ☑ 2026-09-08 |

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

**013 — Venta de mostrador atómica.** `create_pos_sale(items, metodo, cliente,
nota)` más las columnas `sale_number`, `notes` y `subtotal` en `sales`. Hace lo
mismo que `create_order_with_stock` pero para el punto físico: bloqueo
`pg_advisory_xact_lock` por producto y tono, stock validado contra
`available_sale_stock()`, precio unitario de `precio_efectivo()` y escritura de
`sales` + `sale_items` + `inventory_movements` en una sola transacción.

El precio **no** viaja en el payload, igual que en la 011: si el navegador
pudiera mandarlo, cualquiera con la consola abierta registraría una venta a $1.

A diferencia del pedido online, esta función **no** se concede a `anon`: se
hace `revoke ... from public, anon` y solo `authenticated` puede ejecutarla,
con una comprobación extra de `is_admin()` dentro (necesaria porque
`security definer` salta RLS).

El mostrador sí puede vender un producto pausado en la tienda —que no se
exhiba en la web no significa que no esté en la vitrina física— pero no uno
que ya no existe, ni un tono que no pertenezca a su producto.

**014 — Configuración y banners.** Añade a `store_settings` las claves `socialFacebook`,
`socialTiktok` y `socialInstagram`, más un trigger de `updated_at` — la
columna existía desde el principio y nadie la tocaba, así que era imposible
saber cuándo se cambió el costo de envío.

Crea `home_banners` para el carrusel de la portada, con RLS (lectura pública
solo de los activos, escritura de admin), índice de orden, trigger de
`updated_at` y trigger de auditoría. Las políticas van en la **misma**
migración que la tabla a propósito: una tabla con RLS activo y sin políticas
devuelve 0 filas sin error, y la portada saldría vacía sin que nada lo dijera.

No toca las políticas de `store_settings`: se comprobó contra la base real
que un `GET` con solo la apikey anónima devuelve las tres filas y que un
`UPDATE` con sesión de admin afecta 1 fila.

**015 — Mensajes de contacto.** `contact_messages` con estados
`new / read / answered / archived`, índice de bandeja, `updated_at` y
auditoría.

El reparto de permisos es deliberado y va en tres políticas separadas en vez
de un `for all`: **cualquiera inserta** (es un formulario público, igual que
el pedido) pero **nadie anónimo lee**. La tabla guarda nombre, correo y
teléfono de personas reales; una política de lectura pública convertiría el
formulario en un directorio de datos personales servido por la API. Se
verificó en la base real: un `GET` anónimo devuelve **401**.

Tampoco hay `delete` para nadie, ni siquiera para el admin: un mensaje se
archiva. Si alguien pide que se eliminen sus datos, se hace a mano y queda
constancia.

**016 — Combos 2x1.** `descuento_combos(items)` evalúa por fin
`buy_quantity` / `get_quantity`, que existían desde la 010 y nunca se usaron.

No cabía en `precio_efectivo` porque esa función responde *cuánto vale UNA
unidad*, y un 2x1 no tiene respuesta a eso: la segunda vale cero y la tercera
vuelve a costar. Se calcula sobre el carrito entero.

Reglas, todas decisiones de negocio explícitas: el combo **cruza líneas** (dos
labiales distintos cuentan como dos), se regalan las unidades **más baratas**,
solo se aplica **un** combo —el que más descuento deje—, **sí** se suma a un
cupón, y las unidades se valoran a `precio_efectivo`, no al precio de lista.

El cupón se calcula después del combo, sobre lo que realmente se está pagando.
Al revés, un 2x1 con un cupón del 20% descontaría dos veces sobre la unidad
regalada.

Se reescriben `create_order_with_stock` y `create_pos_sale` para aplicarlo. El
mostrador cobra lo mismo que la web, por decisión del negocio.

**017 — Trazabilidad del producto.** `report_trazabilidad` une los movimientos
de inventario con la auditoría de la ficha y de los tonos en una sola línea de
tiempo.

El trabajo de verdad no es unir, es **traducir**. Un `audit_logs` con
`{"price": 38900, ...}` frente a otro objeto casi igual no es trazabilidad, es
un volcado. Tres funciones lo convierten en algo legible:
`etiqueta_columna()` pone nombres en español, `valor_legible()` formatea
precios al estilo colombiano (`$ 38.900`, con el separador forzado a mano
porque el locale de la base pondría comas) y traduce booleanos a sí/no, y
`nombre_referencia()` resuelve las claves foráneas —"Cobertura: → 1" pasa a
"Cobertura: → Alta"—. `describir_cambio()` las combina y devuelve **NULL**
cuando no cambió nada relevante, lo que permite descartar los UPDATE que solo
movieron `updated_at`.

Un detalle de negocio: en un tono, `price` vacío no es "nada", es *hereda del
producto*. Mostrar "(vacío)" ahí sería mentir por omisión.

**Y destapó un fallo:** cambiar precio o estado escribía **dos** filas de
auditoría —la del trigger y una `logAudit` a mano en el store—, así que la
línea de tiempo contaba el mismo cambio dos veces. Va contra la regla que el
propio `CLAUDE.md` ya documentaba. Se quitaron los `logAudit` redundantes de
`catalog.setProductStatus`, `catalog.setShadePrice` e
`inventory.updateSalePrice`, y la vista colapsa el histórico que ya quedó
duplicado quedándose con la del trigger, que trae el diff completo.

**Y se corrige un fallo anterior:** `report_ventas_linea` calculaba el ingreso
como `quantity * unit_price`, el bruto. El descuento a nivel de documento no se
restaba en ninguna parte, así que **un pedido con cupón del 20% ya venía
inflando el ingreso y el margen** desde la 010. Ahora se reparte
proporcionalmente entre las líneas —proporcionalmente, porque los agregados por
producto, tono y categoría suman líneas—. Verificado: la suma del ingreso neto
de cada pedido cuadra al céntimo con lo cobrado sin envío.

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

Para la 014 y la 015 (PostgreSQL local, dos pasadas cada una):

- ambas son idempotentes;
- `home_banners` nace con sus dos políticas, `updated_at` se mueve al
  actualizar y la auditoría registra INSERT/UPDATE/DELETE;
- en `contact_messages`, con `set local role` dentro de una transacción:
  anon **inserta** pero recibe *permission denied* al leer; un usuario
  autenticado sin perfil admin ve **0 filas**; el admin lee y cambia estados;
  el `delete` está denegado incluso para el admin; y un estado fuera de la
  lista lo rechaza el `check`.

Para la 016, quince casos en PostgreSQL local:

- una unidad no descuenta; dos del mismo tono regalan una;
- con precios distintos se regala **el más barato** ($30.000 + $20.000 → 20.000);
- tres unidades = un solo grupo completo; cuatro = dos grupos;
- un 3x2 con seis unidades regala dos;
- un combo caducado o de otra categoría no aplica;
- la base rechaza un combo sin cantidades y uno donde se paga más de lo que se lleva;
- pedido con 2x1: subtotal 50.000, descuento 20.000, total 40.000 + envío;
- el mismo pedido con cupón del 20%: descuento 26.000 (20.000 del combo + 6.000
  del cupón sobre los 30.000 restantes), no 30.000;
- el ingreso neto de cada pedido cuadra con lo cobrado sin envío;
- la venta de mostrador con combo también cuenta neto en Reportes.

Y sobre la base real: dos bases a $30.320 con el 2x1 activo → una gratis,
$30.320 a pagar.

Para la 013, además:

- un usuario sin perfil de admin es rechazado (`Solo un administrador…`);
- sobreventa, cantidad cero, producto inexistente y tono que no pertenece al
  producto: los cuatro rechazados con su mensaje propio;
- 10 cajas simultáneas por la última unidad → 1 aceptada, 9 rechazadas, stock
  final exactamente 0 y nunca negativo;
- con `unit_price: 1` en el payload, la venta se registró igualmente a
  $38.900: el precio lo pone el servidor;
- tras las 9 transacciones abortadas, cero cabeceras sin líneas, cero ventas
  sin movimiento de inventario y el total de cada venta cuadra con la suma de
  sus líneas.
