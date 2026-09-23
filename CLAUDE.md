# CLAUDE.md — Strawberry Makeup

Guía operativa para cualquier sesión de Claude que trabaje en este repositorio.
Léela completa antes de tocar código.

---

## 1. Qué es este proyecto

**Strawberry Makeup** es un ecommerce de maquillaje y skincare para Colombia que
vende por WhatsApp, con un **ERP ligero interno**: catálogo, variantes por tono,
proveedores, compras, bodega, inventario de venta, pedidos, pagos, envíos y
auditoría.

La idea central del negocio son **tres capas que nunca se deben mezclar**:

| Capa | Fuente de verdad | Qué NO hace |
|---|---|---|
| Catálogo | `products`, `product_variants` | No guarda existencias |
| Inventario | `inventory_movements` (histórico) | No define precio comercial |
| Pedidos/Ventas | `orders`, `sales` | No escribe stock directo, solo movimientos |

**Flujo de negocio canónico:**

```
Producto (catálogo)
  → Orden de compra a proveedor
    → Entrada a BODEGA        (movimiento `purchase`, +)
      → Transferencia a VENTA (movimiento `transfer`: − bodega / + venta)
        → Cliente compra (web) → pedido con reserva atómica de stock
          → Pago confirmado → Envío → Entrega
            → Devolución: reingreso de stock por movimiento `return`
```

Cada paso deja rastro en `inventory_movements` y en `audit_logs`.

---

## 2. Estructura del repositorio

```
StrawBerry/
├── README.md                                  ← presentación del proyecto
├── .github/workflows/verificar.yml            lint + build + prueba de humo
├── CLAUDE.md                                  ← este archivo
├── HANDOFF.md                                 ← estado vivo del trabajo
├── PRUEBAS.md                                 ← plan de pruebas manual (ver §3)
├── subir-cambios.ps1                          ← agrupa los cambios en commits (ver §6)
├── docs/
│   └── arquitectura-proyecto-strawberry.md    ← documento maestro (~59 KB)
└── main/                                      ← la aplicación
    ├── .env                                   (git-ignored)
    ├── .env.example                           plantilla de credenciales
    ├── vite.config.js                      reparto de chunks
    ├── eslint.config.js                    reglas del linter (ver §3)
    ├── scripts/smoke.mjs                   prueba de humo del build
    ├── scripts/responsive.mjs              auditoría de celular/tablet (ver §3)
    ├── package.json
    ├── src/
    │   ├── App.vue                            splash, layout, init de inventario
    │   ├── router/index.js                    rutas (import dinámico) + guard admin
    │   ├── lib/
    │   │   ├── supabase.js                    cliente (falla si no hay .env)
    │   │   └── auditLog.js                    helper único de auditoría
    │   ├── utils/
    │   │   ├── formatCurrency.js
    │   │   └── orderStatus.js                 mapeo único de estados
    │   ├── stores/                            Pinia (ver §4)
    │   ├── composables/
    │   │   └── useInventoryRows.js            filas de bodega y de venta, en un solo sitio
    │   ├── views/                             Home, Shop, ProductDetail, Cart, About…
    │   └── components/
    │       ├── layout/ home/ products/ cart/
    │       └── admin/                         panel + admin/inventory/* (ver §4)
    └── supabase/
        ├── README.md                          modelo de datos, RLS, flujo de pedidos
        ├── schema.sql, add_audit_logs.sql…    histórico, YA APLICADO
        └── migrations/                        migraciones numeradas (ver §5)
```

**`docs/arquitectura-proyecto-strawberry.md` es la especificación del proyecto.**
Ante cualquier duda de negocio o de modelo de datos, esa es la referencia.
Si una decisión cambia, se actualiza ese documento **en el mismo cambio**.

---

## 3. Stack y comandos

- Vue 3.5 (`<script setup>`) · Vite 6 · Pinia 3 · vue-router 4
- Tailwind CSS 4 vía `@tailwindcss/vite` (sin `tailwind.config.js`)
- Supabase JS 2 (Postgres + Auth + RLS)
- `lucide-vue-next` para iconos

```bash
cd main
cp .env.example .env    # completar con las credenciales del proyecto
npm install
npm run dev
npm run lint            # ESLint: debe quedar en 0 errores
npm run build           # correr SIEMPRE antes de terminar
npm run preview

npx playwright install chromium   # solo la primera vez
npm run smoke           # prueba de humo sobre el build: 9 rutas, sin pantallas en blanco
npm run responsive      # desbordes, botones pequeños y texto diminuto, en 6 anchos
npm run responsive -- --fotos   # además guarda capturas en .responsive/

npm run verify          # los cuatro de golpe
```

**`PRUEBAS.md` (raíz del repo) es el plan de pruebas manual**: 192 comprobaciones
en 17 bloques, ordenadas por el flujo real del negocio. Lo que `smoke` y
`responsive` no pueden ver —que el precio cobrado sea el correcto, que un combo
descuente lo que dice, que el WhatsApp llegue— se comprueba ahí a mano. Arranca
con un aviso importante: hazlo contra un proyecto de Supabase aparte, no contra
el de producción, o los datos de prueba quedan mezclados con los reales.

`npm run build` no detecta una página en blanco: un import circular o un
componente que revienta al montar compilan igual. Por eso existe
`npm run smoke` (`scripts/smoke.mjs`), que sirve el `dist/` real y comprueba
que cada ruta renderiza, que no hay errores de consola y que **el panel de
administración no se descarga en rutas públicas**. Las llamadas a Supabase se
interceptan, así que corre sin credenciales.

**El linter no está para discutir de estilo.** `eslint.config.js` tiene las
reglas de formato apagadas a propósito: sirve para atrapar lo que `vite build`
compila sin quejarse —una variable mal escrita, un import muerto, un `confirm()`
colado, un `v-for` sin `key`—. Un linter que grita por una coma entrena a la
gente a ignorarlo, y entonces tampoco ve el error de verdad. Debe quedar en
**cero errores**; las advertencias que quedan son de archivos muertos
pendientes de borrar.

`require-atomic-updates` se probó y se descartó: marcaba trece sitios, los trece
correctos. Limpiar un formulario después de que la base confirma es el patrón
normal en Vue, no una condición de carrera. Está documentado en el propio
`eslint.config.js` para que nadie lo vuelva a activar sin saberlo.

**`npm run responsive` es lo que sustituye a "ábrelo en el celular".** Busca
tres cosas concretas en siete páginas × seis anchos: desborde horizontal —un
solo elemento más ancho que la pantalla hace que TODA la página se arrastre de
lado—, áreas táctiles de menos de 40 px y texto por debajo de 12 px. Sirve el
`dist/` real y siembra respuestas de Supabase con datos incómodos a propósito
(nombres largos, precios de seis cifras, muchos tonos): una página vacía nunca
desborda.

Igual que el linter, está afinado para no gritar en falso. Para los enlaces de
texto no mide el alto sino la **banda libre** —alto más el hueco hasta el
vecino tocable—, porque lo que falla el pulgar no es un enlace bajito sino un
enlace bajito pegado a otro. Antes de subir el listón, comprueba que lo que
marca es un fallo de verdad; un verificador que cría lobos se acaba ignorando.

`.github/workflows/verificar.yml` corre los cuatro en cada push y cada PR sobre
`main` y `dev`. Sigue sin haber tests unitarios de lógica (deuda D-6).

**Supabase es obligatorio.** Sin `.env`, `lib/supabase.js` lanza un error y la
app no arranca. Esto es deliberado: antes existía un "modo demo" que servía
datos falsos y autenticaba el panel contra `localStorage`, lo que escondía
fallos de red y dejaba el admin abierto en cualquier build sin configurar.

---

## 4. Arquitectura del frontend

### Stores (Pinia, `src/stores/`)

Cada store responde a **una** pregunta. Si al añadir algo dudas de dónde va,
la pregunta que responde decide, no la pantalla que lo usa.

| Store | Responde a | Nota |
|---|---|---|
| `catalog.js` | Qué vendemos | Productos, tonos, imágenes y tablas maestras |
| `inventory.js` | Cuántas unidades hay y dónde | Solo existencias. Derivadas de `inventory_movements` |
| `suppliers.js` | A quién le compramos | |
| `purchases.js` | Qué le compramos | Órdenes de compra; toda entrada va **primero a bodega** |
| `pos.js` | Qué se vendió en el mostrador | RPC `create_pos_sale` |
| `orders.js` | Qué se vendió en línea | RPC `create_order_with_stock` |
| `promotions.js` | Con qué descuento | Promociones y cupones |
| `cart.js` | Qué lleva la clienta | Persistido en `localStorage` |
| `favorites.js` | Qué le gustó y no compró | Solo ids, en `localStorage`. El producto se resuelve al pintar |
| `settings.js` | Cómo está configurada la tienda | Fuente única del costo de envío y los banners del carrusel |
| `offers.js` | Qué se anuncia en la portada | Tarjetas de «Ofertas especiales». **Escaparate, no precio** |
| `contact.js` | Quién escribió | Bandeja del formulario público |
| `reports.js` | Cómo va el negocio | Vistas `report_*`, solo lectura |
| `audit.js` | Quién cambió qué | Lectura de `audit_logs` |
| `admin.js` | Quién entró | Auth vía Supabase Auth |

**Dos arranques, a propósito.** `inventory.init()` carga lo mínimo para que la
tienda funcione —catálogo y saldos— y `inventory.initPanel()` añade lo que solo
el panel necesita: movimientos, proveedores, compras y mostrador. Antes había un
solo `init()` que lo pedía todo, así que una clienta mirando un labial disparaba
cuatro consultas a tablas que RLS no le deja leer. No fallaba nunca porque una
tabla sin permiso devuelve **cero filas sin error** (§5), que es justo lo que
hace que este tipo de derroche no se note.

### Convenciones

- Componentes en `<script setup>`, español para el texto de UI, inglés para
  identificadores de código.
- Las vistas leen de los stores; **no llames a `supabase` directamente desde un
  componente `.vue`** — el acceso a datos vive en los stores.
- Moneda: usa `utils/formatCurrency.js`, no formatees a mano.
- Estados de pedido: usa **siempre** `utils/orderStatus.js`
  (`toDbStatus`, `toUiStatus`, `isActive`, `isReturned`). Nunca escribas el mapa
  español↔inglés a mano: estaba duplicado y las copias ya habían divergido.
- Auditoría de eventos de negocio: usa `lib/auditLog.js` **solo para lo que el
  trigger no puede nombrar** (por ejemplo "duplicado de otro producto" o "el
  admin confirmó el pago"). Los INSERT/UPDATE fila a fila ya los captura
  `audit_trigger` en Postgres **con el diff completo**. Duplicarlos hacía que
  la trazabilidad contara el mismo cambio dos veces; ya pasó con
  `setProductStatus`, `setShadePrice` y el antiguo `updateSalePrice`.
  La regla práctica: si tu `logAudit` solo repite campos que acabas de escribir
  en esa misma tabla, sobra.
- **Nada de `prompt()`, `confirm()` ni `alert()`.** Los diálogos del navegador
  bloquean la pestaña, no se leen bien en el móvil, no validan hasta después de
  aceptar y no dejan explicar qué implica la acción. Usa un modal del panel: ya
  hay tres de referencia en `SaleInventory.vue`, `AdminProductos.vue` y
  `Suppliers.vue`.
- **Precio de producto y precio de tono son cosas distintas.** El precio de un
  tono en `null` significa *hereda*, no *gratis*. Para cambiar el precio de un
  tono usa `catalog.setShadePrice`; `catalog.setProductPrice` mueve el producto
  y con él todos los tonos que heredan.
- **Una colección en la portada es una fila de tarjetas de producto, no una
  foto.** `CollectionRow.vue` monta el mismo `ProductCard.vue` que la tienda.
  No hagas una tarjeta reducida «para el home»: dos tarjetas de producto en el
  mismo sitio acaban divergiendo en el precio, que es el único dato que no
  puede divergir. Sale en la portada la colección **publicada y con al menos un
  producto a la venta**; la foto de cabecera es opcional.
- **El carrusel es scroll nativo (`overflow-x-auto` + `scroll-snap`), no una
  librería ni un `transform` calculado.** El dedo, el trackpad y el teclado ya
  saben desplazarse; las flechas solo llaman a `scrollBy` y van `aria-hidden`
  porque duplican algo que el lector de pantalla ya puede hacer. Si añades un
  carrusel en otro sitio, cópialo de ahí antes que instalar nada.
- **La sección Colecciones tiene DOS interruptores y no son el mismo.**
  `store_settings.homeCollectionsVisible` apaga el bloque entero de la portada
  sin tocar ninguna colección —al encenderlo todo vuelve como estaba—, y
  `collections.published` retira una colección concreta de la portada y de la
  tienda. Apagar la sección no rompe el filtro `?coleccion=` de la tienda.
- **Un producto pertenece como mucho a una colección**, y es una columna
  (`products.collection_id`), no una tabla de cruce. Decisión explícita del
  usuario. Borrar una colección **no borra sus productos**: `on delete set
  null` los deja sueltos. Si algún día hace falta que un producto esté en dos,
  hay que migrar a muchos-a-muchos; no lo simules con una segunda columna.
- **Escaparate y precio son cosas distintas.** `home_offers` (la sección
  «Ofertas especiales») **no descuenta nada**: una tarjeta que dice "30% OFF"
  lo anuncia, no lo crea. El descuento vive en `promotions` y lo cobra el
  servidor. Si algún día se enlazan, que sea la tarjeta la que *lea* la
  promoción, nunca al revés — dos sitios calculando el mismo importe es como
  se rompió el costo de envío.
- **Una vista previa monta el componente de verdad.** `AdminOfertas.vue` no
  redibuja la portada: importa el mismo `OffersGrid.vue` que usa la tienda. Una
  previa que reimplementa el diseño miente en cuanto alguien toca uno de los
  dos, y entonces deja de servir para lo único que existe.
- **No pongas índices dinámicos sobre un store** (`store[variable]`). El linter
  no puede ver dentro de un corchete, así que renombrar la propiedad deja la
  pantalla vacía sin que nada falle. Usa un mapa explícito: pasó en
  `CatalogSettings.vue`, y lo destapó el refactor, no un usuario.
- **Nada de fallbacks silenciosos.** Si Supabase falla, el error sube a la
  interfaz. **`src/data/mockData.js` ya no lo importa nadie y está pendiente de
  borrar**: no vuelvas a leer de ahí. La configuración de tienda (envío, WhatsApp, redes,
  banners) vive en `stores/settings.js`, que lee de `store_settings` y
  `home_banners`.
- **Un producto no se publica sin unidades a la venta.** La regla vive en la
  base (trigger `exigir_stock_para_publicar`, migración 021) y solo mira la
  *transición* a publicado: un producto ya activo que se agota se sigue
  pudiendo editar. El panel repite la comprobación para poder explicarla antes
  de que alguien pulse, pero **la base es la que manda** — no conviertas eso en
  la única defensa.
- **Escaparate y precio son cosas distintas** (segunda vez que aparece esta
  regla, ahora con etiquetas). `product_badges` —VIRAL, NUEVO, 2x1— **no
  descuenta nada**. El descuento vive en `promotions` y lo cobra el servidor.
- **El historial de compras no se reescribe.** Corregir una orden de compra
  (`save_purchase_order`, migración 022) escribe una compra negativa que anula
  la anterior y vuelve a meter la correcta. Se anula con `purchase` negativo y
  **no con `adjustment`**: un ajuste no cuenta para `costo_promedio`, así que
  anular con ajustes dejaría la media calculada sobre unidades que nunca se
  compraron, y el margen de Reportes saldría mal sin que nadie lo notara.
- **Un campo que necesita explicación lleva un `AyudaInfo`, no un párrafo
  gris.** `components/admin/AyudaInfo.vue` es el botón de «i» que dice qué hace
  el campo y —lo que de verdad faltaba— **dónde se ve** en la tienda. Un texto
  de ayuda permanente debajo de cada campo convierte el formulario en un muro
  que nadie lee justamente porque siempre está ahí.
- **Una pestaña que exige un registro guardado, lo guarda ella.** En
  `ProductEditor.vue`, Tonos, Imágenes y Trazabilidad necesitan un producto con
  `id`; antes estaban bloqueadas y nada lo decía, así que la pantalla parecía
  rota. Ahora `irASeccion()` guarda y entra. Y si el guardado **no devuelve un
  `id`, no avanza**: sin esa guarda, cada clic creaba un producto nuevo.
- **El pie va pegado abajo, y eso es cosa del layout global.** `#app` es una
  columna flex de alto mínimo `100dvh` (en `main.css`) y el bloque que envuelve
  al `RouterView` lleva `flex-1`. No le pongas `min-h-[...]` a una vista para
  empujar el pie: eso arregla una página y deja rotas las demás, que es
  exactamente lo que había pasado. `dvh` y no `vh` porque en el móvil `vh`
  cuenta la ventana con la barra del navegador escondida.
- **Un recuadro de imagen tiene alto propio.** Si el alto lo pone la foto, una
  vertical estira el bloque, una horizontal lo encoge y cambiar de miniatura
  hace saltar la página. Proporción fija (`aspect-square`) + `object-contain`.
- **Toda escritura se espera y se comprueba.** `await`, `try/catch`, y el modal
  se cierra *después* de que la base confirme. Este proyecto ha tenido el mismo
  bug tres veces —POS, Compras, Configuración—: la pantalla decía que había
  guardado y no había guardado nada. Tras un UPDATE, comprueba además que
  volvió al menos una fila (ver la trampa de RLS en §5).
- **Las rutas se cargan con `import()`.** Solo la portada es estática. Si
  añades una vista al router con un import normal, el panel entero vuelve al
  bundle público; `npm run smoke` lo detecta.
- **El precio nunca se calcula dos veces.** Si la tienda tiene que mostrar un
  importe que luego cobra el servidor —envío, promoción, combo— se le
  *pregunta* a la base (`precio_efectivo`, `descuento_combos`,
  `config_numero`), no se replica la fórmula en JavaScript. Cada copia acaba
  discrepando: pasó con el costo de envío, que salía de una constante mientras
  el servidor cobraba otra cosa.

### El inventario son cuatro paradas, en ese orden

`admin/inventory/InventorySection.vue` monta cuatro pestañas numeradas que son
el recorrido real de la mercancía, con flechas de siguiente y anterior:

| # | Pestaña | Componente | Qué es |
|---|---|---|---|
| 1 | Productos | `AdminProductos.vue` | La ficha. **Crear un producto NO crea existencias** |
| 2 | Compras | `PurchaseOrders.vue` | Lo que le compras al proveedor. **Entra a bodega** |
| 3 | Bodega | `Warehouse.vue` | Lo recibido. **La clienta todavía no lo ve** |
| 4 | Listo para vender | `SaleInventory.vue` | Lo que la clienta puede comprar ahora |

**Productos ya no es una sección suelta del menú.** Estaba aparte, así que
crear un producto y meterlo en inventario parecían dos tareas distintas cuando
son la misma, en orden. No la vuelvas a sacar del recorrido.

Antes eran otras tres y una sobraba. «Inventario de Compras» no era un
inventario: era el catálogo completo otra vez, con un creador recortado a tres
campos que paría productos sin precio, sin marca, sin tonos y sin fotos. Se
eliminó. **Los productos se crean en un solo sitio: la sección Productos.** Si
vuelves a ver un formulario de "producto nuevo" fuera de ahí, es el bug otra vez.

La bodega, en cambio, no tenía pantalla: vivía como una rejilla al final de la
pestaña *siguiente*. Ahora es una parada propia, y `ProductoEnBodega.vue` es su
ficha: muestra de qué compra vino cada unidad y **la nota que se escribió al
registrarla**, que es el dato que nadie podía ver.

Bodega y Venta arman la misma fila a partir de `balances`, así que ese armado
vive una sola vez en `composables/useInventoryRows.js` (`filasEnBodega`,
`filasEnVenta`, `etiquetaDe`). No lo copies a una tercera pantalla.

El precio se edita **solo** en «Listo para vender», que es donde se ve junto al
margen. En Bodega solo se transfiere.

### Cómo leer el stock (importante)

**Hay dos fuentes y no son intercambiables.**

| Quién pregunta | De dónde sale | Trae |
|---|---|---|
| La tienda pública | tabla `inventory_sale_balances` (`refreshSaleBalances`) | solo lo que está a la venta |
| El panel | vista `inventory_balances` (`refreshBalances`) | venta **y** bodega |

`inventory_balances` está declarada con `security_invoker = true`, así que al
consultarla se leen por debajo los `inventory_movements` **con los permisos de
quien pregunta** — y la única política de esa tabla es
`TO authenticated USING (is_admin())`. Una clienta anónima recibe **cero filas
y ningún error**. Eso fue exactamente el bug del 15 de septiembre: la tienda
calculaba `saleStock = 0` para todo el catálogo y pintaba «Agotado» en cada
tarjeta, con la mercancía puesta a la venta y sin nada en consola.
**No vuelvas a leer `inventory_balances` desde una pantalla pública.**
`inventory_sale_balances` la mantiene un trigger con los mismos movimientos:
es la misma cuenta, publicada, no una segunda fuente de verdad.

**Con tonos, el stock es del tono, no del producto.** `catalogWithStock` suma
tono a tono cuando el producto tiene tonos, porque un color concreto es lo que
la clienta elige y lo que hay que sacar de la caja. Unas unidades registradas
contra el producto base en un producto con tonos **no las ve nadie**: la
composable las marca como `huerfano` y Bodega y Listo para vender avisan.
Compras ya no deja crearlas.

`inventoryStore.balances` viene de la vista `inventory_balances`. Su campo
`saleStock` **es el disponible para vender**, no una reserva. Restarlo de otra
cosa es un error: eso fue exactamente el bug B-8, que hacía que
`validateOrderItems` rechazara todos los pedidos.

Para consultar disponibilidad usa siempre
`getProductAvailableStock(productId, variantId)`.

---

## 5. Base de datos (Supabase)

### Migraciones

Los archivos sueltos de `main/supabase/` son el **histórico ya aplicado**. Las
migraciones nuevas van en `main/supabase/migrations/`, numeradas e idempotentes.
`migrations/README.md` lleva el índice y el estado de cada una.

**Reglas al tocar SQL:**

1. Nunca edites `schema.sql` para un cambio incremental. Crea un archivo nuevo
   con el siguiente número y déjalo idempotente (`if not exists`, `or replace`,
   `drop policy if exists` antes de `create policy`).
2. **Nunca reejecutes `schema.sql` ni `add_audit_logs.sql`.** El primero recrea
   un trigger que duplicaría el descuento de stock; el segundo empieza con
   `drop table public.admin_profiles cascade`, que borra el perfil admin y las
   políticas RLS que dependen de él. Ya pasó una vez (bug B-13).
3. Nunca uses `drop table` sobre una tabla con datos sin avisar al usuario y
   ofrecer respaldo primero.
4. **No hay ninguna columna `stock`** en `products` ni en `product_variants`
   (la última se soltó en la migración 018). El stock se deriva de
   `inventory_movements` y se lee por la vista `inventory_balances`. Si ves un
   campo `stock` en un objeto del frontend, es un valor **derivado** que arma
   `enrichedProducts`, no una columna.
   Lo mismo con las fotos: `products.image` también se soltó en la 018. La
   única fuente es `product_images`.
5. **Nada de `DELETE` ni `UPDATE` sin `WHERE`, ni siquiera sobre una tabla
   temporal.** Supabase carga la extensión `safeupdate` para los roles `anon` y
   `authenticated`, que los rechaza con «DELETE requires a WHERE clause». El
   editor SQL corre como `postgres` y **no** tiene esa protección, así que una
   migración puede aplicarse sin problema y luego fallar solo cuando la app la
   llama: pasó con `save_purchase_order` (migración 024). Para vaciar una tabla
   temporal, créala ya llena con `create table as` en vez de vaciarla.
6. Antes de escribir una columna desde el frontend, **confirma que existe en el
   SQL vigente**. `products.is_featured`, `is_new` e `is_recommended` **ya no
   existen** (migración 020): las etiquetas viven en `product_badges` y
   `product_badge_assignments`.
7. La regla de stock vive en `movement_sale_delta()` y
   `movement_warehouse_delta()`. Si cambia la semántica de un tipo de
   movimiento, se cambia **ahí**, no en tres copias.
8. Las devoluciones insertan un movimiento `return` compensatorio.
   **Nunca borres filas de `inventory_movements`**: el historial es la fuente de
   verdad y la auditoría. Un pedido equivocado se corrige con una devolución,
   que deja rastro, no borrando su historia.
   *Excepción tomada una sola vez:* el 8 de septiembre de 2026 se vació la base
   de datos de prueba antes de empezar a vender, con autorización explícita y
   respaldo previo. Está documentado en `main/supabase/reset_datos_prueba.sql`.
   No es un permiso permanente.

### Seguridad

- Auth: **Supabase Auth** + perfil en `admin_profiles`. Rol activo: `super_admin`.
- Autorización: función `public.is_admin()` (SECURITY DEFINER, para no recursar
  sobre RLS). Todas las políticas de admin la usan.
- **Trampa de RLS:** una tabla con RLS activo y sin políticas queda inaccesible,
  y PostgREST devuelve **0 filas sin error**. Un SELECT parece vacío y un UPDATE
  parece exitoso. Si algo del panel "funciona pero no guarda", corre
  `migrations/000_diagnostico.sql` antes de buscar en el frontend.
- Por eso, tras un UPDATE que deba afectar filas, usa `.select('id')` y
  **comprueba que volvió al menos una fila**.
- **Nunca escribas credenciales, URLs de proyecto ni llaves en archivos
  versionados.** Todo va en `main/.env`, que está en `.gitignore`.

---

## 6. Git

- Remoto: `https://github.com/P3REZ05/StrawVue.git`
- Rama de trabajo: **`dev`**. `main` es la estable.
- Trabaja siempre en `dev` o en una rama de feature salida de `dev`. No commits
  directos a `main`.
- Mensajes de commit: imperativo, con alcance.
  `fix(orders): unificar mapeo de estados`, no `cambios en la web y mejoras`.
  Cuerpo en texto plano sin acentos, explicando **qué estaba mal**, no qué
  archivos se tocaron: eso ya lo dice el diff.
- **`subir-cambios.ps1`** (raíz) agrupa todo lo que haya sin versionar en
  commits temáticos y ofrece publicar al final. Desde PowerShell:

  ```powershell
  cd C:\Users\Usuario\Documents\StrawBerry
  .\subir-cambios.ps1
  ```

  Es repetible: cada bloque solo crea el commit si de verdad quedó algo
  preparado, así que si se corta a la mitad se vuelve a ejecutar y sigue donde
  iba. Se para en seco si aparece un `.env` entre los cambios — una llave
  publicada en GitHub hay que rotarla, no se deshace con un commit. No hace
  push sin preguntar.
  Si añades archivos nuevos al proyecto, añádelos también al bloque que les
  corresponda; lo que no encaje en ninguno cae en el commit final de resto.

---

## 7. Cómo trabajar aquí (reglas para Claude)

1. **Lee `HANDOFF.md` primero.** Contiene el estado vivo, los bugs abiertos y la
   prioridad actual. `CLAUDE.md` dice *cómo*; `HANDOFF.md` dice *qué sigue*.
2. **Un cambio, un propósito.** No mezcles refactor con feature con fix de SQL.
3. **No inventes columnas ni tablas.** Verifica contra `main/supabase/*.sql`.
4. **No agregues features nuevas mientras haya bugs de contrato abiertos** en el
   HANDOFF. La prioridad es cerrar la operación, no ampliarla.
5. **Verifica de verdad.** El SQL se prueba antes de proponerlo: se puede
   levantar un PostgreSQL local, emular el esquema `auth` de Supabase, aplicar
   el histórico y luego las migraciones nuevas. Así se descubrió B-13. Para el
   frontend, `npm run build` es el mínimo y `npm run smoke` es lo que de
   verdad detecta una pantalla en blanco.
6. **Actualiza `HANDOFF.md`** al terminar: qué se hizo, qué se rompió, qué sigue.
   Si la decisión afecta el modelo de negocio o de datos, actualiza también
   `docs/arquitectura-proyecto-strawberry.md`.
7. **Antes de un cambio destructivo** (drop, delete masivo, reescritura de un
   store completo, rotación de llaves): pregunta primero.
8. Español en la comunicación con el usuario y en el texto de UI.

---

## 8. Deuda técnica conocida

Resumen; el detalle y la prioridad están en `HANDOFF.md`.

- **Código muerto pendiente de borrar:** `AdminVariants.vue`, `AdminFilter.vue`,
  `AdminAddFilter.vue` y `src/data/mockData.js`. **Nadie los importa** —
  comprobado— así que no llegan al bundle y no rompen nada. `AdminVariants.vue`
  y `AdminAddFilter.vue` sí llaman a métodos de `inventory.js` que ya no
  existen: si algún día alguien los reengancha, fallarán. Bórralos, no los
  arregles.
- Imágenes duplicadas (`assets/images/` y `assets/styles/images/carrusel-home/`),
  ~10 MB sin optimizar. Los quince PNG de categoría **ya no los usa nadie**
  desde el rediseño de `HomeCategories.vue`; se pueden borrar con el resto.
- Sin tests unitarios de lógica. Ya hay `npm run lint`, `npm run build` y
  `npm run smoke`, y CI que los corre; falta probar precios heredados, envío,
  combos y estados de pedido.

**Lo que NO es deuda, aunque lo parezca:**

- `admin.js:hasAccess()` devuelve `true` para todo **a propósito**. El usuario
  decidió el 8 de septiembre de 2026 que no habrá roles: la tienda la
  administra una sola persona, y un sistema de permisos para un usuario es
  código que hay que mantener y que no protege de nada. No lo "arregles".
- No hay cuentas de clienta. Sus datos viajan con el pedido y quedan en el
  caché de su navegador; no hay registro ni login público. También es una
  decisión.
- El panel en el móvil está **aplazado**, no olvidado.
