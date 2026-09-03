# 🍓 Strawberry Makeup

Tienda de maquillaje y skincare con gestión interna de inventario, compras,
pedidos, pagos y auditoría. La venta se cierra por WhatsApp, pero **el pedido se
registra en la base antes** de abrir el chat: WhatsApp es el canal de
coordinación, no la fuente de verdad.

## Qué es en realidad

No es solo un catálogo. Es un ERP ligero de belleza construido sobre tres capas
que nunca se mezclan:

| Capa | Fuente de verdad | Qué no hace |
|---|---|---|
| **Catálogo** | `products`, `product_variants` | no guarda existencias |
| **Inventario** | `inventory_movements` | no define precio comercial |
| **Operación** | `orders`, `sales`, `payments`, `shipments` | no escribe stock directo |

Flujo canónico:

```
Producto → Compra a proveedor → BODEGA → transferencia (parcial o total)
  → INVENTARIO DE VENTA → pedido del cliente (reserva atómica)
    → pago → envío → entrega   ·   devolución → reingreso por movimiento
```

Cada paso deja rastro en `inventory_movements` y en `audit_logs`. El stock nunca
es una columna: se deriva del historial.

## Stack

Vue 3 · Vite 6 · Pinia 3 · Vue Router 4 · Tailwind CSS 4 · Supabase (Postgres,
Auth, RLS) · lucide-vue-next

## Puesta en marcha

```bash
cd main
cp .env.example .env      # completa URL y anon key de tu proyecto Supabase
npm install
npm run dev
```

Supabase es obligatorio: sin `.env` la app falla de inmediato con un mensaje
claro. No hay modo demo.

Para crear la base desde cero, seguir `main/supabase/README.md`.

```bash
npm run build     # build de producción
npm run preview   # previsualizar el build
```

## Estructura

```
StrawBerry/
├── CLAUDE.md      cómo trabajar en este repositorio
├── HANDOFF.md     estado vivo: bugs abiertos y prioridad actual
├── docs/          documento maestro de arquitectura
└── main/          la aplicación
    ├── src/       componentes, vistas, stores de Pinia
    └── supabase/  esquema y migraciones numeradas
```

## Documentación

- **`docs/arquitectura-proyecto-strawberry.md`** — especificación del negocio y
  del modelo de datos. Referencia ante cualquier duda.
- **`HANDOFF.md`** — qué está hecho, qué está roto y qué sigue.
- **`CLAUDE.md`** — convenciones y reglas de trabajo.
- **`main/supabase/README.md`** — base de datos, RLS y flujo de pedidos.
- **`main/supabase/migrations/README.md`** — migraciones y su estado.

## Ramas

`dev` es la rama de trabajo, `main` la estable. No se commitea directo a `main`.
