# Refactor del módulo de productos — Strawberry Makeup

Diseño para convertir el módulo de productos en algo apto para una marca de
maquillaje real: creación rápida, tonos bien modelados y trazabilidad completa.

Fecha: 3 de septiembre de 2026 · Estado: propuesta

---

## 1. El diagnóstico

Lo que hay hoy funciona como catálogo genérico, pero no como catálogo **de
maquillaje**. Cuatro problemas de fondo:

**1. Los tonos no existen como concepto.** `product_variants` guarda `name`,
`sku`, `variant_type` y `option_value`. Un tono de base es "Tono 01" — un texto.
No hay color, ni subtono, ni profundidad, ni familia. El cliente no puede ver de
qué color es lo que va a comprar, y la administradora no puede ordenar la gama
de clara a profunda.

En maquillaje esto no es un detalle cosmético: **el tono es el producto**. Una
base son 40 productos distintos que comparten fórmula.

**2. Crear un producto son cuatro viajes.** Categorías y atributos → Productos →
Variantes → Inventario. Y si a mitad del formulario falta una marca, hay que
salir, crearla, y volver a empezar porque el modal se cierra.

**3. Los atributos dinámicos están a medias.** Las tablas maestras
(`skin_types`, `finishes`, `coverages`) existen, la arquitectura define cuándo
aplica cada una, pero el formulario de alta no tiene los selectores. Los campos
se guardan vacíos siempre.

**4. No hay ficha del producto.** La información existe repartida —`audit_logs`
sabe quién lo creó y cuándo cambió de precio, `inventory_movements` sabe qué se
compró y a quién— pero no hay ninguna pantalla que lo cuente junto.

---

## 2. Cómo lo resuelven las marcas reales

Antes de inventar, esto es lo que hace la industria.

**El swatch manda sobre el nombre.** El motivo principal de abandono en tiendas
de cosmética es que los tonos se etiquetan solo con nombre o código — "#01 Rose
Pink" — sin mostrar el color. La recomendación es imagen de swatch real, porque
un hexadecimal no distingue un mate de un glitter ni de un metalizado.

**Cada tono es un registro con atributos gobernados.** La práctica estándar en
PIM de belleza es que cada tono tenga, como mínimo: nombre e identificador,
imagen de swatch, **subtono**, **profundidad** y **acabado**. Consistentes entre
todos los tonos, para poder filtrar y comparar.

**El código de tono codifica subtono + profundidad.** El sistema de MAC es el
ejemplo canónico: `NC42` = letras de subtono (NC neutral-cool, NW neutral-warm,
N neutral, C cool) + número de profundidad. Ese esquema —letra de subtono,
número de profundidad— es lo que permite a una clienta que sabe que es "NC42"
encontrar su equivalente en cualquier marca.

**La matriz crece rápido.** Una base en 40 tonos y 2 tamaños son 80 variantes de
un solo producto; si además hay dos acabados, 160. Crear eso de una en una no es
viable: hace falta generación por lotes.

---

## 3. Modelo de datos propuesto

### 3.1 Tablas maestras nuevas

```sql
-- Subtono: para bases, correctores, polvos.
create table undertones (
  id bigint generated always as identity primary key,
  code text unique not null,      -- 'C', 'N', 'W', 'O'
  name text not null,             -- 'Frío', 'Neutro', 'Cálido', 'Oliva'
  active boolean not null default true
);

-- Familia de tono: para labiales, sombras, rubores.
create table shade_families (
  id bigint generated always as identity primary key,
  name text unique not null,      -- 'Nudes', 'Rosados', 'Rojos', 'Vinos', 'Corales', 'Bronces'
  active boolean not null default true
);
```

### 3.2 `product_variants` se convierte en "tono"

```sql
alter table product_variants
  add column shade_code       text,      -- 'NC42', '01', 'Rojo Cereza'
  add column swatch_hex       text,      -- '#E8C39E' — el chip de color
  add column swatch_image_url text,      -- foto real del swatch
  add column undertone_id     bigint references undertones(id),
  add column shade_family_id  bigint references shade_families(id),
  add column depth            smallint,  -- 1 (más clara) .. 100 (más profunda)
  add column position         integer default 0,
  add column is_default       boolean default false;
```

**Por qué hexadecimal *y* imagen.** El hex sirve para el chip, para ordenar y
para filtrar; es dato estructurado. La imagen sirve para la verdad: un tono
metalizado o con glitter no se representa con un color plano. Cuando hay imagen,
manda la imagen; si no, se dibuja el chip con el hex.

**Por qué `depth` numérico.** Permite ordenar la gama de clara a profunda, que es
exactamente como una clienta recorre una línea de bases. Sin esto, el orden es
alfabético, que no significa nada.

**Por qué `position` e `is_default`.** La administradora decide el orden de
exhibición y cuál se muestra seleccionado al abrir la ficha.

### 3.3 Imágenes de verdad (resuelve B-15)

```sql
create table product_images (
  id bigint generated always as identity primary key,
  product_id bigint not null references products(id) on delete cascade,
  variant_id bigint references product_variants(id) on delete cascade,
  url text not null,              -- URL pública de Supabase Storage
  storage_path text not null,     -- para poder borrarla después
  alt text,
  position integer default 0,
  is_primary boolean default false,
  created_at timestamptz default now()
);
```

Una tabla resuelve dos cosas: la galería del producto y **la foto por tono**, que
es lo que hace que el cliente vea el labial en el color que va a comprar.

Requiere un bucket público `product-images` en Supabase Storage con escritura
solo para administradores.

### 3.4 Qué se retira

- `product_variants.stock` — legacy, contradice la fuente de verdad por movimientos.
- `products.image` — se migra a `product_images` y queda como columna derivada
  de la imagen principal, o se elimina tras migrar.

---

## 4. Cómo se administra

### 4.1 Un editor de producto, no cuatro pantallas

Se reemplaza el modal actual por un **editor de producto** con secciones. El
producto se guarda como borrador desde la primera sección, así nada se pierde.

```
┌─ Editor de producto ─────────────────────────────────┐
│  ① Básicos    ② Atributos   ③ Tonos                  │
│  ④ Imágenes   ⑤ Precio       ⑥ Trazabilidad          │
└──────────────────────────────────────────────────────┘
```

**① Básicos** — nombre, marca, categoría, subcategoría, descripción.
Marca y categoría con botón **"+ Crear"** al lado: abre un mini-diálogo, la crea
y la deja seleccionada. Sin salir del editor.

**② Atributos** — los campos condicionales que ya define la arquitectura, ahora
sí conectados: tipo de piel (solo Cuidado facial), acabado (bases, fijadores,
labiales, correctores), cobertura (solo bases), contenido neto (líquidos).
La categoría decide qué aparece; lo que no aplica, no se muestra.

**③ Tonos** — la sección que hoy no existe. Ver 4.2.

**④ Imágenes** — subida real a Storage, arrastrar para ordenar, marcar principal.

**⑤ Precio y publicación** — precio base, precio promocional, destacado / nuevo /
recomendado, y el estado real: borrador → activo → pausado → archivado.

**⑥ Trazabilidad** — ver 4.3.

### 4.2 El editor de tonos

Tres formas de cargar tonos, de menos a más volumen:

**Uno a uno.** Fila con: código, nombre, selector de color, subir swatch,
subtono, profundidad, SKU, precio propio (opcional), activo.

**Por lotes — pegar lista.** Un textarea donde se pega:

```
01  Marfil        #F5DCC4  C  10
02  Arena         #E8C39E  N  25
03  Miel          #D2A679  W  40
04  Canela        #B07D56  W  60
```

`código · nombre · hex · subtono · profundidad`. Se previsualiza la tabla con
los chips ya pintados y se confirma. Cuarenta tonos en un pegado.

**Generador de matriz.** Para cuando hay dos ejes: se eligen los tonos y los
tamaños, y se generan las combinaciones con SKU automático.

**SKU automático:** `{MARCA}-{PRODUCTO}-{CÓDIGO}` → `ANIK-BROCHAS-01`. Editable,
pero nunca vacío.

**Vista previa del cliente:** al lado del editor, los chips exactamente como los
verá quien entre a la tienda. Se corrige el color mirándolo, no imaginándolo.

### 4.3 Ficha de trazabilidad

Una línea de tiempo por producto, que ya se puede construir con lo que hay:
`audit_logs` (creación, cambios de precio, pausas) más `inventory_movements`
(compras, transferencias, ventas, devoluciones), ordenados por fecha.

```
15 sep  Creado por Alejandro
15 sep  Compra a Proveedor de prueba · +10 a bodega · $18.000 c/u
16 sep  Transferidas 6 a inventario de venta
17 sep  Precio: $38.900 → $42.900
18 sep  Pedido ORD-12 · −2
```

Responde de un vistazo las preguntas reales del negocio: cuánto me costó, a
quién se lo compré, cuánto llevo vendido, quién cambió el precio y cuándo.

---

## 5. Qué cambia en la tienda

- **Chips de color** en la ficha de producto y en la tarjeta del catálogo.
- **La imagen cambia al elegir tono**, cuando el tono tiene foto propia.
- **Stock por tono**: "Tono 02 agotado" en vez de un agotado global que esconde
  que hay otros seis tonos disponibles.
- **Filtro por subtono y por familia** en la tienda: "bases cálidas",
  "labiales nude".
- Los tonos se ordenan por `position`, y las bases por `depth` de clara a
  profunda.

---

## 6. Plan de ejecución

| # | Etapa | Entregable |
|---|---|---|
| 1 | Migración `007` | `undertones`, `shade_families`, columnas de tono, `product_images`, semillas de subtonos y familias |
| 2 | Storage | Bucket `product-images` con políticas, helper de subida y borrado |
| 3 | Store | Partir `inventory.js`: `catalog.js` (productos, tonos, atributos) sale de ahí |
| 4 | Editor | Editor de producto por secciones con creación al vuelo de marca y categoría |
| 5 | Tonos | Editor de tonos: uno a uno, pegado por lotes, selector de color, swatch |
| 6 | Trazabilidad | Ficha de línea de tiempo por producto |
| 7 | Tienda | Chips, imagen por tono, stock por tono, filtros de subtono y familia |
| 8 | Limpieza | Retirar `product_variants.stock` y `products.image` tras migrar |

Las etapas 1 y 2 desbloquean todo lo demás. La 3 conviene hacerla antes de la 4
para no construir el editor nuevo sobre el monolito.

---

## 7. Decisiones que hay que tomar antes de empezar

1. **¿Editor a página completa o modal grande?** Página completa
   (`/admin/productos/:id`) da espacio para la matriz de tonos y permite
   compartir el enlace; el modal es menos cambio pero se queda corto con 40 tonos.
2. **¿Los tonos comparten precio con el producto o cada uno tiene el suyo?**
   Lo habitual es que compartan y solo se sobrescriba por excepción (tamaños).
3. **¿Cuánto alcance de una vez?** Se puede entregar por etapas y validar cada
   una, o hacer el módulo completo y probarlo entero.
