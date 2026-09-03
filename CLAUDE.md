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
├── CLAUDE.md                                  ← este archivo
├── HANDOFF.md                                 ← estado vivo del trabajo
├── docs/
│   └── arquitectura-proyecto-strawberry.md    ← documento maestro (~59 KB)
└── main/                                      ← la aplicación
    ├── .env                                   (git-ignored)
    ├── .env.example                           plantilla de credenciales
    ├── vite.config.js
    ├── package.json
    ├── src/
    │   ├── App.vue                            splash, layout, init de inventario
    │   ├── router/index.js                    rutas + guard admin
    │   ├── lib/
    │   │   ├── supabase.js                    cliente (falla si no hay .env)
    │   │   └── auditLog.js                    helper único de auditoría
    │   ├── utils/
    │   │   ├── formatCurrency.js
    │   │   └── orderStatus.js                 mapeo único de estados
    │   ├── stores/                            Pinia: inventory, orders, cart, admin, audit
    │   ├── data/mockData.js                   SOLO configuración de vitrina (ver §4)
    │   ├── views/                             Home, Shop, ProductDetail, Cart, About…
    │   └── components/
    │       ├── layout/ home/ products/ cart/
    │       └── admin/                         panel + admin/inventory/*
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
npm run build           # única verificación automática hoy: correr SIEMPRE antes de terminar
npm run preview
```

No hay linter, tests ni CI todavía (deuda D-6).

**Supabase es obligatorio.** Sin `.env`, `lib/supabase.js` lanza un error y la
app no arranca. Esto es deliberado: antes existía un "modo demo" que servía
datos falsos y autenticaba el panel contra `localStorage`, lo que escondía
fallos de red y dejaba el admin abierto en cualquier build sin configurar.

---

## 4. Arquitectura del frontend

### Stores (Pinia, `src/stores/`)

| Store | Rol | Nota |
|---|---|---|
| `inventory.js` | Catálogo, variantes, proveedores, compras, bodega, inventario de venta, ventas POS | **~39 KB, monolito. No lo hagas crecer más** (deuda D-1) |
| `orders.js` | Pedidos online, cambios de estado, RPC `create_order_with_stock` | |
| `cart.js` | Carrito, persistido en `localStorage` | |
| `admin.js` | Auth admin vía Supabase Auth | |
| `audit.js` | Lectura de `audit_logs` | |

### Convenciones

- Componentes en `<script setup>`, español para el texto de UI, inglés para
  identificadores de código.
- Las vistas leen de los stores; **no llames a `supabase` directamente desde un
  componente `.vue`** — el acceso a datos vive en los stores.
- Moneda: usa `utils/formatCurrency.js`, no formatees a mano.
- Estados de pedido: usa **siempre** `utils/orderStatus.js`
  (`toDbStatus`, `toUiStatus`, `isActive`, `isReturned`). Nunca escribas el mapa
  español↔inglés a mano: estaba duplicado y las copias ya habían divergido.
- Auditoría de eventos de negocio: usa `lib/auditLog.js`. Los INSERT/UPDATE fila
  a fila ya los captura un trigger en Postgres, no los dupliques.
- **Nada de fallbacks silenciosos.** Si Supabase falla, el error sube a la
  interfaz. `mockData.js` sobrevive solo para configuración de vitrina
  (`storeSettings`, `socialLinks`, `defaultPromotions`, `adminUsers`); no debe
  volver a usarse como respaldo de datos reales.

### Cómo leer el stock (importante)

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
4. `products` **no tiene columna `stock`**. `product_variants.stock` existe pero
   es **legacy**: no lo escribas desde código nuevo.
5. Antes de escribir una columna desde el frontend, **confirma que existe en el
   SQL vigente**.
6. La regla de stock vive en `movement_sale_delta()` y
   `movement_warehouse_delta()`. Si cambia la semántica de un tipo de
   movimiento, se cambia **ahí**, no en tres copias.
7. Las devoluciones insertan un movimiento `return` compensatorio.
   **Nunca borres filas de `inventory_movements`**: el historial es la fuente de
   verdad y la auditoría.

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
   frontend, `npm run build` es el mínimo.
6. **Actualiza `HANDOFF.md`** al terminar: qué se hizo, qué se rompió, qué sigue.
   Si la decisión afecta el modelo de negocio o de datos, actualiza también
   `docs/arquitectura-proyecto-strawberry.md`.
7. **Antes de un cambio destructivo** (drop, delete masivo, reescritura de un
   store completo, rotación de llaves): pregunta primero.
8. Español en la comunicación con el usuario y en el texto de UI.

---

## 8. Deuda técnica conocida

Resumen; el detalle y la prioridad están en `HANDOFF.md`.

- `inventory.js` sigue siendo un monolito con rutas legacy
  (`addPurchaseOrderLegacy`, `addToSaleInventoryLocal`).
- `product_variants.stock` sigue existiendo y contradice la fuente de verdad.
- Promociones: el esquema tiene `promotions` / `promotion_products`, pero el
  admin las guarda en `localStorage`.
- `Shop.vue` importa categorías de `mockData` en vez del store.
- Imágenes duplicadas (`assets/images/` y `assets/styles/images/carrusel-home/`),
  ~10 MB sin optimizar.
- Sin tests, sin lint, sin CI. El bundle pasa de 500 KB sin code-splitting.
