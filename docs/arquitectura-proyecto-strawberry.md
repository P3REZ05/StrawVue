# Strawberry Makeup - Arquitectura del proyecto, módulos y base de datos

## 1. Objetivo del proyecto

Strawberry Makeup es una tienda de cosméticos y maquillaje pensada para vender por WhatsApp, con gestión interna de inventario, compras, stock, pedidos, promociones, pagos y administración. El enfoque principal no es solo mostrar productos, sino construir un sistema operativo real para una marca de belleza que pueda crecer de forma ordenada.

La base actual ya tiene una muy buena idea de negocio, pero requiere una limpieza en la estructura de datos para que todo quede funcional y escalable. El punto más importante es separar correctamente tres conceptos que suelen mezclarse en ecommerce:

1. Catálogo comercial
2. Inventario real
3. Pedidos y ventas

Mientras estas tres capas no estén bien definidas, se genera riesgo de sobreventa, inconsistencias y pérdida de control.

---

## 2. Visión de negocio

La marca quiere operar de la siguiente forma:

- La tienda publica productos y categorías de maquillaje y skincare.
- El administrador crea un producto dentro del catálogo.
- Luego se realiza la compra al proveedor.
- La mercadería entra a bodega.
- Desde bodega se decide qué cantidad pasa al inventario de venta.
- Los productos en venta se muestran a los clientes.
- El cliente compra por WhatsApp.
- El pedido se registra en la base de datos.
- Se genera la factura y se comparte el resumen por WhatsApp.
- El administrador cambia el estado del pedido: pendiente, enviado, entregado, cancelado, etc.
- Se registra un historial completo de cada cambio.
- Se gestionan promociones, marcas, tonos y productos recomendados.

Esto es más sólido y profesional que vender solo desde un carrito visual sin control de stock.

---

## 3. Módulos del proyecto

### 3.1 Módulo de gestión de productos

Será el módulo principal para organizar el catálogo y el inventario comercial. Agrupará las siguientes secciones:

- Productos
- Variantes
- Inventario de compras / bodega
- Compras
- Inventario de venta
- Categorías y atributos

Las ventas físicas/POS, pedidos online, pagos, envíos, reportes y auditoría permanecen como módulos independientes.

#### Productos

Responsable únicamente de la ficha comercial. No debe recibir ni modificar existencias.

Debe incluir:

- nombre del producto
- marca dinámica
- categoría y subcategoría dinámicas
- tipo de piel dinámico, habilitado solo para la categoría Cuidado facial
- acabado dinámico, habilitado para bases, fijadores, labiales y correctores
- cobertura dinámica, habilitada para bases
- contenido neto, habilitado para productos líquidos
- código de barras
- producto destacado
- producto nuevo
- producto recomendado
- estado de publicación: borrador, activo, pausado o archivado
- descripción
- imagen principal
- imágenes adicionales
- precio base
- precio promocional
- SKU / referencia interna cuando corresponda a la variante
- activo / pausado / archivado

Los campos de tipo de piel, acabado, cobertura y contenido neto se mostrarán mediante una opción de activación en el formulario. Al marcarla, se habilitará el selector dinámico correspondiente; al desmarcarla, el campo no aplicará al producto y deberá quedar vacío.

`Producto nuevo`, `Producto destacado` y `Producto recomendado` son opciones independientes y editables. Todo producto puede comenzar como nuevo, pero el administrador puede desactivar esa marca posteriormente.

#### Variantes

Las variantes se gestionarán en un módulo independiente del formulario principal del producto. Allí se crearán tonos, tamaños o referencias con su SKU, código de barras y precio propio cuando corresponda. Las variantes no serán la fuente de verdad del stock: el inventario se calculará mediante movimientos.

Ejemplo:

- Producto: Base Velvet Skin
- Variante: Tono 01
- Variante: Tono 02
- Variante: Tono 03

Esto es importante porque en maquillaje casi siempre hay tonos, pigments y referencias distintas.

### 3.2 Módulo de categorías y atributos

Este será un mini módulo dinámico dentro de Gestión de productos. Permitirá crear, editar, activar, pausar y almacenar:

- categorías
- subcategorías
- marcas
- tipos de piel
- acabados
- coberturas

Los productos utilizarán selectores alimentados por estas tablas. Así se evita escribir valores manualmente y se pueden agregar opciones sin modificar el código.

Las categorías controlarán qué atributos aparecen en el formulario de producto. Por ejemplo, tipo de piel solo se habilitará para Cuidado facial; cobertura solo para Bases; y acabado solo para Bases, Fijadores, Labiales y Correctores.

### 3.3 Módulo de proveedores

Debe manejar la compra de productos a distribuidores o marcas.

Campos recomendados:

- nombre
- nit o documento
- contacto principal
- teléfono
- email
- dirección
- ciudad
- condiciones de pago
- observaciones
- activo

Esto sirve para construir un historial de compras y entender qué proveedor entrega más volumen, cuál tarda más, etc.

### 3.4 Módulo de compras

Responsable de registrar las compras de productos a proveedores.

Flujo recomendado:

1. Se crea la orden de compra.
2. Se agregan los productos en detalle.
3. La compra queda registrada.
4. La mercadería entra a bodega.
5. El sistema registra el movimiento de inventario.

Esto aplica para la regla que ya definiste:

- todo entra primero a bodega
- luego se decide si pasa a inventario de venta

### 3.5 Módulo de bodega/inventario

Tener bodega y venta es una buena decisión, porque evita vender sin control.

Debe existir una diferencia clara entre:

- stock en bodega
- stock disponible para venta
- stock reservado
- stock en tránsito o pendiente

Regla de negocio:

- Si llega una compra, el sistema suma al stock de bodega.
- Si el administrador decide pasar unidades a venta, se mueve stock desde bodega hacia venta.
- Si un producto se vende, se descuenta de la venta.
- Si se retorna, se devuelve al inventario correcto.

### 3.6 Módulo de ventas online

Es donde ocurre el pedido del cliente.

Debe manejar:

- cliente (nombre, contacto, ciudad, dirección)
- pedido
- productos del pedido
- subtotal
- costo de envío
- total
- método de pago
- comprobante de pago (archivo, imagen o PDF)
- estado del pedido
- transportadora
- guía
- fecha estimada de entrega
- fecha de envío
- comprobante de entrega

Además, la compra debe registrarse antes de abrir el WhatsApp, para que quede trazable. El WhatsApp debe ser un canal de coordinación, no la única fuente de verdad.

### 3.7 Módulo de ventas físicas / POS

Esto es útil si quieres vender en tienda o en eventos.

Debe registrar:

- fecha de venta
- producto
- cantidad
- precio de venta
- método de pago
- empleado responsable
- nota de la venta

Esto tiene sentido para diferenciar ventas online vs venta presencial.

### 3.8 Módulo de pedidos y seguimiento

Estados recomendados:

- pendiente
- confirmado
- pagado
- preparando
- enviado
- entregado
- cancelado
- devolucion
- devuelto

Regla recomendada:

- El usuario solo puede comprar, ver su factura y recibir información por WhatsApp.
- No debe poder acceder a todo el panel de pedidos.
- La persona recibe un link de seguimiento o una respuesta por WhatsApp.

### 3.9 Módulo de pagos

Debe evaluar el tipo de pago y comprobante.

Métodos que usas: efectivo contra entrega, transferencia bancaria, Nequi, Daviplata.

Campos recomendados:

- payment_method
- amount
- status
- reference_code
- proof_url
- proof_name
- created_at
- updated_at

### 3.10 Módulo de envío

Aunque la transportadora calcula el valor final, tu sistema debe guardar:

- ciudad de destino
- dirección completa
- costo estimado
- costo final
- transportadora
- guía
- fecha de envío
- fecha estimada
- estado del envío

Esto permite controlar la logística y preparar el pedido adecuadamente.

### 3.11 Módulo de promociones

Para la marca de maquillaje es importante porque ayuda a mover volumen y a generar más ventas.

Debe soportar:

- descuento por porcentaje
- precio especial
- segunda unidad con descuento
- combo / kit
- envío gratis
- cupón
- promoción por categoría
- fecha de inicio y fin
- productos aplicables
- prioridad
- estado activo

Ejemplos:

- 20% en bases
- 2x1 en labiales
- Envío gratis en compras mayores a cierto valor
- Combo skincare + base

### 3.12 Módulo de administración y seguridad

La mejor práctica es usar Supabase Auth en lugar de crear tu propio sistema con password_hash en la app.

Recomendación actual del proyecto:

- `auth.users` de Supabase maneja la autenticación.
- `admin_profiles` almacena el perfil del administrador.
- Se trabaja con un único administrador maestro para arrancar.

Modelo operativo definido:

- `super_admin`: cuenta principal, acceso total al panel.

Este enfoque es intencional: facilita la operación inicial, reduce errores de permisos y deja el sistema estable antes de abrir más perfiles. Si más adelante se requiere, se puede ampliar a roles, pero no como base inicial.

### 3.13 Módulo de auditoría

Esto es clave para la operación y para tu decisión de que necesitas historial.

Cada cambio importante debe quedar en una tabla de auditoría:

- cambio de precio
- actualización de stock
- cambio de estado del pedido
- cambio de estado de pago
- cancelación
- creación de producto
- activación o pausa de producto

No solo sirve para control interno, sino para resolver dudas con proveedores, clientes y ventas.

### 3.14 Estado actual del proyecto y sprint operativo

El proyecto ya dejó de ser solo una vitrina visual y pasó a una etapa de operación real. La base funcional ya está construida alrededor de un modelo de negocio más serio para maquillaje y skincare:

- catálogo con productos y variantes
- inventario orientado a movimientos reales
- compras y proveedores
- pedidos con validación de stock
- pagos con confirmación
- estados operativos del pedido
- auditoría de cambios
- autenticación admin mediante Supabase Auth

A partir de aquí, el enfoque del proyecto se centra en cerrar la operación comercial real, no en agregar más “features” decorativas.

#### Estados operativos activos del sprint actual

Se simplificó la operación para mantener una lógica clara y usable desde el inicio:

- `pending`: pedido creado, esperando pago
- `paid`: pago confirmado y stock validado
- `shipped`: pedido enviado
- `returned`: devolución o reingreso de productos

Se decidió descartar estados no necesarios para la fase inicial si no afectan directamente la operación. Si un caso real aparece más adelante, se incorpora con un cambio controlado y documentado, sin romper la lógica base.

#### Sprint 1 completado

Se cerró la primera capa funcional crítica:

- validación de stock antes de crear el pedido
- reserva de stock por variante / producto
- creación del pedido con control de inventario
- estado de pedido en los flujos relevantes
- confirmación de pago y cambio a `paid`
- devolución con reingreso de stock cuando aplica
- auditoría de cambios en `audit_logs`

Esto deja el flujo ecommerce operativo para una primera fase real: producto disponible, pedido creado, pago confirmado, envío y devolución con trazabilidad.

#### Siguiente capa de trabajo

La siguiente fase del proyecto es la de cierre operativo y administración:

- seguimiento de envíos con estado `shipped`
- gestión de devoluciones con `returned`
- vista del admin con pedidos activos y pagos pendientes
- dashboard de ventas por producto, categoría y tendencias
- reportes finales de inventario y ventas
- validación end-to-end del flujo real desde carrito hasta entrega

La estrategia es mantener la lógica operativa simple, robusta y trazable, y solo ampliar cuando la operación lo demande. Este enfoque previene errores de inventario, sobreventas y confusión entre catálogo, bodega y ventas.

---

## 4. Recomendación de arquitectura de base de datos

La base actual tiene una buena idea, pero debe evolucionar para una operación real. La recomendación es esta:

### 4.1 Base de verdad (fuente de datos)

La fuente de verdad no debe ser una mezcla de `products`, `sale_inventory` y `purchase_inventory` por separado.

La fuente de verdad debe ser:

- `products`: catálogo general
- `product_variants`: variantes por tono / referencia
- `inventory_movements`: historial real del stock
- `orders`: compras online
- `sales`: ventas físicas
- `payments`: pagos
- `shipments`: envíos
- `suppliers`: proveedores

Esto es más robusto 
que depender de “stock de venta” y “stock de bodega” solamente como dos tablas independientes sin historial.

### 4.2 Regla de negocio principal

Para que todo quede ordenado, sigue esta lógica:

1. Se crea el producto.
2. Se crean variantes si aplica.
3. Se registra la compra al proveedor.
4. La compra entra a bodega mediante un movimiento de inventario.
5. El administrador decide pasar unidades a venta.
6. El inventario de venta es lo que el cliente ve.
7. La venta online o física descuenta stock del inventario disponible.
8. Cada movimiento queda guardado en `inventory_movements`.

Esto permite saber en todo momento qué pasó y por qué.

### 4.3 Cambios aprobados para Supabase

Sí, es necesario actualizar Supabase para que el nuevo flujo no dependa de valores escritos manualmente.

#### Tablas maestras dinámicas

Se conservará `categories` y se ampliará el modelo con una relación padre para subcategorías. También se crearán tablas maestras para `brands`, `skin_types`, `finishes` y `coverages`.

La tabla `products` deberá guardar referencias a estas tablas mediante identificadores, en lugar de depender únicamente de textos libres. Se recomienda conservar temporalmente los campos de texto actuales durante la migración, copiar sus valores a las tablas maestras y retirarlos después de validar el frontend.

El modelo objetivo será:

```text
categories
  └── subcategories
brands
skin_types
finishes
coverages
      ↓
products
      ↓
product_variants
```

#### Existencias fuera del catálogo

`products` no tendrá `stock`. El esquema V2 ya no define esa columna, por lo que el campo Stock del formulario de Productos debe eliminarse del frontend.

`product_variants.stock` todavía existe en el esquema y en el store, pero contradice la fuente de verdad basada en movimientos. Debe tratarse como campo legacy: primero se dejará de editarlo desde la interfaz, después se migrarán sus valores iniciales a movimientos y finalmente se eliminará cuando no existan dependencias.

La cantidad disponible se derivará de `inventory_movements`:

- `purchase` positivo: entrada a bodega.
- `transfer` negativo con referencia `warehouse`: salida de bodega.
- `transfer` positivo con referencia `sale_inventory`: entrada a venta.
- `sale` o `online_order` negativo: salida por venta.
- `return` positivo: reingreso según el destino definido.

#### Flujo de compra y transferencia

Toda compra recibida debe crear un movimiento `purchase` hacia bodega. No se debe permitir que una compra salte directamente al inventario de venta.

Cuando el administrador decida publicar unidades para venta, se ejecutará una transferencia con dos movimientos relacionados: salida de bodega y entrada a inventario de venta. La cantidad puede ser parcial. Las unidades no transferidas permanecen almacenadas y no aparecen disponibles en el storefront.

#### Migración SQL prevista

La actualización de Supabase deberá incluir, como mínimo:

```sql
create table if not exists public.brands (
  id bigint generated always as identity primary key,
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists public.skin_types (
  id bigint generated always as identity primary key,
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists public.finishes (
  id bigint generated always as identity primary key,
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists public.coverages (
  id bigint generated always as identity primary key,
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz default now()
);

alter table public.categories
  add column if not exists parent_id bigint references public.categories(id) on delete restrict;

alter table public.products
  add column if not exists brand_id bigint references public.brands(id) on delete restrict,
  add column if not exists subcategory_id bigint references public.categories(id) on delete restrict,
  add column if not exists skin_type_id bigint references public.skin_types(id) on delete restrict,
  add column if not exists finish_id bigint references public.finishes(id) on delete restrict,
  add column if not exists coverage_id bigint references public.coverages(id) on delete restrict;
```

Este bloque crea la estructura, pero no elimina todavía los campos antiguos ni `product_variants.stock`. La migración de datos y la eliminación de legacy deben hacerse después de adaptar el frontend y verificar los registros existentes.

---

## 5. Estructura recomendada por módulo

### Tabla: products

```sql
create table if not exists public.products (
  id bigint generated always as identity primary key,
  name text not null,
  brand text,
  category text not null,
  subcategory text,
  description text,
  price numeric(12,2) default 0,
  sale_price numeric(12,2),
  original_price numeric(12,2),
  image text,
  skin_type text,
  finish text,
  coverage text,
  net_content_ml integer,
  barcode text,
  is_featured boolean default false,
  is_new boolean default true,
  is_recommended boolean default false,
  status text not null default 'draft' check (status in ('draft','active','paused','archived')),
  slug text unique,
  image_url text,
  active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

### Tabla: product_variants

```sql
create table if not exists public.product_variants (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id) on delete restrict,
  name text not null,
  sku text,
  barcode text,
  variant_type text default 'tono',
  option_value text,
  price numeric(12,2) default 0,
  compare_at_price numeric(12,2),
  stock integer default 0,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

### Tabla: suppliers

```sql
create table if not exists public.suppliers (
  id bigint generated always as identity primary key,
  name text not null,
  document_number text,
  contact_name text,
  phone text,
  email text,
  address text,
  city text,
  payment_terms text,
  notes text,
  active boolean default true,
  created_at timestamptz default now()
);
```

### Tabla: purchase_orders

```sql
create table if not exists public.purchase_orders (
  id bigint generated always as identity primary key,
  supplier_id bigint references public.suppliers(id) on delete restrict,
  order_number text unique,
  order_date date default current_date,
  notes text,
  status text default 'pending' check (status in ('pending','received','partial','cancelled')),
  total numeric(12,2) default 0,
  created_at timestamptz default now()
);
```

### Tabla: purchase_order_items

```sql
create table if not exists public.purchase_order_items (
  id bigint generated always as identity primary key,
  purchase_order_id bigint not null references public.purchase_orders(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  quantity integer not null default 0,
  unit_cost numeric(12,2) default 0,
  destination text default 'warehouse',
  created_at timestamptz default now()
);
```

### Tabla: inventory_movements

```sql
create table if not exists public.inventory_movements (
  id bigint generated always as identity primary key,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  movement_type text not null check (movement_type in ('purchase','sale','online_order','return','transfer','adjustment','damage')),
  quantity integer not null,
  unit_cost numeric(12,2),
  reference_type text,
  reference_id bigint,
  notes text,
  created_by uuid,
  created_at timestamptz default now()
);
```

### Tabla: customers

```sql
create table if not exists public.customers (
  id bigint generated always as identity primary key,
  full_name text not null,
  phone text,
  email text,
  document_number text,
  city text,
  address text,
  notes text,
  created_at timestamptz default now()
);
```

### Tabla: orders

```sql
create table if not exists public.orders (
  id bigint generated always as identity primary key,
  customer_id bigint references public.customers(id) on delete restrict,
  order_number text unique,
  subtotal numeric(12,2) default 0,
  shipping_cost numeric(12,2) default 0,
  total numeric(12,2) default 0,
  status text not null default 'pending' check (status in ('pending','confirmed','paid','preparing','shipped','delivered','cancelled','returned')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

### Tabla: order_items

```sql
create table if not exists public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  product_name text not null,
  quantity integer not null default 1,
  unit_price numeric(12,2) default 0,
  created_at timestamptz default now()
);
```

### Tabla: payments

```sql
create table if not exists public.payments (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  payment_method text not null check (payment_method in ('cash','transfer','nequi','daviplata')),
  amount numeric(12,2) not null,
  status text default 'pending' check (status in ('pending','paid','failed','refunded')),
  proof_url text,
  proof_name text,
  reference_code text,
  created_at timestamptz default now()
);
```

### Tabla: shipments

```sql
create table if not exists public.shipments (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  carrier text,
  tracking_number text,
  shipping_cost numeric(12,2) default 0,
  estimated_delivery date,
  shipped_at timestamptz,
  delivered_at timestamptz,
  status text default 'pending' check (status in ('pending','assigned','shipped','delivered','failed')),
  created_at timestamptz default now()
);
```

### Tabla: sales

```sql
create table if not exists public.sales (
  id bigint generated always as identity primary key,
  sale_date date default current_date,
  customer_name text,
  total numeric(12,2) default 0,
  payment_method text default 'cash',
  created_by uuid,
  created_at timestamptz default now()
);
```

### Tabla: sale_items

```sql
create table if not exists public.sale_items (
  id bigint generated always as identity primary key,
  sale_id bigint not null references public.sales(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  quantity integer not null default 1,
  unit_price numeric(12,2) default 0,
  created_at timestamptz default now()
);
```

### Tabla: promotions

```sql
create table if not exists public.promotions (
  id bigint generated always as identity primary key,
  title text not null,
  label text,
  type text not null check (type in ('percent','fixed','bundle','shipping','coupon','category')),
  value numeric(12,2) default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean default true,
  created_at timestamptz default now()
);
```

### Tabla: promotion_products

```sql
create table if not exists public.promotion_products (
  id bigint generated always as identity primary key,
  promotion_id bigint not null references public.promotions(id) on delete cascade,
  product_id bigint references public.products(id) on delete cascade,
  variant_id bigint references public.product_variants(id) on delete cascade,
  created_at timestamptz default now()
);
```

### Tabla: admin_profiles

```sql
create table if not exists public.admin_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text unique not null,
  role text not null default 'super_admin' check (role in ('super_admin','inventory_admin','sales_admin','orders_admin')),
  created_at timestamptz default now()
);
```

### Tabla: audit_logs

```sql
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  entity_type text not null,
  entity_id bigint,
  action text not null,
  details jsonb,
  created_by uuid,
  created_at timestamptz default now()
);
```

---

## 6. SQL de migración recomendado

Este bloque es la base para modernizar tu estructura actual de Supabase.

```sql
-- 1) Productos: añadir campos para maquillaje
alter table public.products
  add column if not exists brand text,
  add column if not exists skin_type text,
  add column if not exists finish text,
  add column if not exists coverage text,
  add column if not exists net_content_ml integer,
  add column if not exists barcode text,
  add column if not exists is_featured boolean default false,
  add column if not exists is_new boolean default true,
  add column if not exists is_recommended boolean default false,
  add column if not exists status text default 'draft',
  add column if not exists slug text,
  add column if not exists image_url text,
  add column if not exists updated_at timestamptz default now();

-- 2) Crear variantes por tono/referencia
create table if not exists public.product_variants (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id) on delete restrict,
  name text not null,
  sku text,
  barcode text,
  variant_type text default 'tone',
  option_value text,
  price numeric(12,2) default 0,
  compare_at_price numeric(12,2),
  stock integer default 0,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index if not exists ux_product_variants_sku on public.product_variants(sku) where sku is not null;

-- 3) Proveedores
create table if not exists public.suppliers (
  id bigint generated always as identity primary key,
  name text not null,
  document_number text,
  contact_name text,
  phone text,
  email text,
  address text,
  city text,
  payment_terms text,
  notes text,
  active boolean default true,
  created_at timestamptz default now()
);

-- 4) Compras
create table if not exists public.purchase_orders (
  id bigint generated always as identity primary key,
  supplier_id bigint references public.suppliers(id) on delete restrict,
  order_number text unique,
  order_date date default current_date,
  notes text,
  status text default 'pending',
  total numeric(12,2) default 0,
  created_at timestamptz default now()
);

create table if not exists public.purchase_order_items (
  id bigint generated always as identity primary key,
  purchase_order_id bigint not null references public.purchase_orders(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  quantity integer not null default 0,
  unit_cost numeric(12,2) default 0,
  destination text default 'warehouse',
  created_at timestamptz default now()
);

-- 5) Historial de inventario
create table if not exists public.inventory_movements (
  id bigint generated always as identity primary key,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  movement_type text not null check (movement_type in ('purchase','sale','online_order','return','transfer','adjustment','damage')),
  quantity integer not null,
  unit_cost numeric(12,2),
  reference_type text,
  reference_id bigint,
  notes text,
  created_by uuid,
  created_at timestamptz default now()
);

-- 6) Cliente
create table if not exists public.customers (
  id bigint generated always as identity primary key,
  full_name text not null,
  phone text,
  email text,
  document_number text,
  city text,
  address text,
  notes text,
  created_at timestamptz default now()
);

-- 7) Pedidos online
create table if not exists public.orders (
  id bigint generated always as identity primary key,
  customer_id bigint references public.customers(id) on delete restrict,
  order_number text unique,
  subtotal numeric(12,2) default 0,
  shipping_cost numeric(12,2) default 0,
  total numeric(12,2) default 0,
  status text not null default 'pending',
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  product_name text not null,
  quantity integer not null default 1,
  unit_price numeric(12,2) default 0,
  created_at timestamptz default now()
);

-- 8) Pagos
create table if not exists public.payments (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  payment_method text not null,
  amount numeric(12,2) not null,
  status text default 'pending',
  proof_url text,
  proof_name text,
  reference_code text,
  created_at timestamptz default now()
);

-- 9) Envíos
create table if not exists public.shipments (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  carrier text,
  tracking_number text,
  shipping_cost numeric(12,2) default 0,
  estimated_delivery date,
  shipped_at timestamptz,
  delivered_at timestamptz,
  status text default 'pending',
  created_at timestamptz default now()
);

-- 10) Ventas físicas
create table if not exists public.sales (
  id bigint generated always as identity primary key,
  sale_date date default current_date,
  customer_name text,
  total numeric(12,2) default 0,
  payment_method text default 'cash',
  created_by uuid,
  created_at timestamptz default now()
);

create table if not exists public.sale_items (
  id bigint generated always as identity primary key,
  sale_id bigint not null references public.sales(id) on delete cascade,
  product_id bigint references public.products(id) on delete restrict,
  variant_id bigint references public.product_variants(id) on delete restrict,
  quantity integer not null default 1,
  unit_price numeric(12,2) default 0,
  created_at timestamptz default now()
);

-- 11) Promociones
create table if not exists public.promotions (
  id bigint generated always as identity primary key,
  title text not null,
  label text,
  type text not null,
  value numeric(12,2) default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.promotion_products (
  id bigint generated always as identity primary key,
  promotion_id bigint not null references public.promotions(id) on delete cascade,
  product_id bigint references public.products(id) on delete cascade,
  variant_id bigint references public.product_variants(id) on delete cascade,
  created_at timestamptz default now()
);

-- 12) Perfil admin con auth.users
create table if not exists public.admin_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text unique not null,
  role text not null default 'super_admin',
  created_at timestamptz default now()
);

-- 13) Auditoría
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  entity_type text not null,
  entity_id bigint,
  action text not null,
  details jsonb,
  created_by uuid,
  created_at timestamptz default now()
);
```

---

## 7. Reglas de seguridad recomendadas (RLS)

### Objetivo

- El público solo puede crear pedidos y consultar su factura si se le facilita un token o el pedido exacto.
- Los administradores son los únicos que ven todo.
- No se debe permitir lectura masiva de pedidos sin autenticación.

### RLS recomendado

```sql
-- products: lectura pública solo si active=true y status='active'
create policy "products_public_read" on public.products
for select using (active = true and status = 'active');

create policy "products_admin_write" on public.products
for all using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- customers: insert público, select solo admin
create policy "customers_public_insert" on public.customers
for insert with check (true);

create policy "customers_admin_read" on public.customers
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- orders: insert público
create policy "orders_public_insert" on public.orders
for insert with check (true);

-- orders: lectura solo admin
create policy "orders_admin_read" on public.orders
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

create policy "orders_admin_update" on public.orders
create policy "order_items_public_insert" on public.order_items
for insert with check (true);

create policy "order_items_admin_read" on public.order_items
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid()
  )
);

-- admin_profiles: solo admin
create policy "admin_profiles_admin_read" on public.admin_profiles
for select using (
  exists (
    select 1 from public.admin_profiles ap
    where ap.id = auth.uid() and ap.role = 'super_admin'
  )
);
```


---

## 8. Flujo recomendado de operación

### Flujo 1: creación del producto
1. El administrador crea el producto.
2. Define marca, categoría, descripción, tipo de piel, acabado, cobertura, etc.
3. Se publica o se deja en borrador.
4. Si hay variantes, se crean bajo ese producto.

### Flujo 2: compra a proveedor

1. Se crea la orden de compra.
2. Se agregan los artículos.
3. La compra se registra con costo unitario.
4. La cantidad entra a bodega.
5. Se genera un movimiento de inventario tipo `purchase`.

### Flujo 3: movimiento a inventario de venta

2. Decide qué cantidad pasa a venta.
3. Se genera movimiento tipo `transfer`.
4. El stock disponible para vender se actualiza.

### Flujo 4: venta online

1. El cliente compra por WhatsApp o formulario.
2. Se crea el cliente (si aplica) o se guarda solo la información del pedido.
3. Se registra la orden.
4. Se registran los items del pedido.
5. Se registra el método de pago y comprobante.
6. El stock disponible se descuenta.
7. Se genera movimiento tipo `online_order`.
8. Se actualiza el estado del pedido.
9. Se envía la factura y el estado por WhatsApp.

### Flujo 5: venta física

2. Se crea la venta en `sales`.
3. Se agregan los `sale_items`.
4. Se descuenta stock del inventario disponible.
5. Se genera movimiento `sale`.

### Flujo 6: cambios y devoluciones

1. El cliente solicita cambio o devolución.
2. El administrador revisa motivo y estado.
3. Se registra un movimiento de devolución o ajuste.
4. El stock vuelve a inventario si aplica.
5. Se guarda en auditoría.

---


### 9.1 Sobre los productos y variantes

Sí, para maquillaje es más viable usar variantes. Esto permite trabajar ordenadamente con tonos y referencias.

Ejemplo:

- Producto: Base líquida Velvet Skin
- Variante 01: 01 Warm
- Variante 02: 02 Beige
- Variante 03: 03 Honey

Eso permite:

- vender cada tono por separado
- controlar stock por tono
- mostrar imagen y tono distintos
- generar recomendaciones por categoría
- tener una estructura más profesional

### 9.2 Sobre el manejo de stock


- el stock real se mueve por movimientos de inventario
- se evita que `products.stock` sea la fuente de verdad
- `inventory_movements` es lo que debe sostener la operación

Esto es clave para evitar errores de inventario.

### 9.3 Sobre la seguridad administrativa

Es importante que la app se conecte a Supabase Auth y no a un login local con `localStorage` solamente.

---

## 10. Estado actual de implementación

### Resumen ejecutado del proyecto

El proyecto ya dejó de ser una propuesta visual y está avanzando hacia un ecommerce operativo de maquillaje, con una lógica más cercana a una marca real:

- Se consolidó el modelo catálogo + variantes + movimientos de inventario + pedidos + pagos + auditoría.
- El inventario ya no depende de tablas mockeadas para stock visible, sino de movimientos históricos con saldos derivados.
- El admin funciona con una única cuenta maestra, lo que simplifica la operación inicial y reduce errores de permisos.
- El storefront y el admin están conectados a la lógica de Supabase con una estructura más realista para producción.

### Completado

- El esquema V2 principal está en `main/supabase/schema.sql` y define productos, variantes, proveedores, compras, movimientos, pedidos, pagos, envíos, promociones y perfiles admin.
- La base de datos fue organizada con una lógica de verdad: catálogo, variantes, compras, inventario por movimientos y pedidos transaccionales.
- Las políticas RLS principales están definidas para separar lectura pública (storefront) y operaciones administrativas (panel).
- El catálogo usa el store de inventario y muestra stock público derivado de movimientos (`inventory_sale_balances`).
- El panel de productos y el inventario usan el mismo store para crear/editar/pausar productos; las variantes ahora se gestionan desde un módulo independiente.
- Variantes activas se cargan para cada producto; la vista de detalle exige selección de variante (tono/referencia) y aplica el límite de cantidad por variante.
- El panel admin permite crear y desactivar variantes (nombre, SKU y precio) desde el módulo independiente de Variantes; las existencias no se editan desde esa pantalla.
- El panel de inventario permite registrar órdenes de compra (supplier, variante, cantidad, costo) e ingresa stock a bodega como movimientos `purchase`.
- Las transferencias de bodega a venta generan movimientos `transfer` (salida negativa de bodega y entrada positiva a venta).
- Las ventas físicas generan movimientos `sale` y los pedidos online generan movimientos `online_order` mediante la RPC atómica `create_order_with_stock()`.
- El flujo principal usa `inventory_movements` y las vistas de saldos derivadas, pero `src/stores/inventory.js` todavía conserva código legacy que consulta o escribe `sale_inventory` y `purchase_inventory`; esas tablas no forman parte del esquema V2 actual.
- El acceso del panel utiliza Supabase Auth cuando las variables están configuradas y la sesión se restaura antes de proteger rutas.
- El carrito limita las cantidades según stock por variante y bloquea productos agotados en el storefront.
- Existe auditoría para variantes, productos e inventario mediante `main/supabase/add_audit_logs.sql`, pero ese archivo reemplaza el contrato de `audit_logs` definido en `schema.sql`; ambos SQL deben consolidarse antes de ejecutar una instalación limpia.
- El panel admin ya incluye la vista de auditoría y lectura de logs.
- La tabla `categories` ya existe y ahora tiene un mini módulo dinámico para administrar categorías y subcategorías.
- Ya se creó `product_catalog_migration.sql` con tablas maestras, relaciones e índices para categorías, subcategorías, marcas, tipos de piel, acabados y coberturas; todavía falta ejecutarlo en Supabase.
- Se creó el módulo administrativo de Categorías y atributos y el módulo independiente de Variantes.
- El formulario de alta y edición de productos ya no muestra `stock`, usa categorías/marcas dinámicas, incluye casillas condicionales y permite editar las banderas de nuevo, destacado y recomendado.
- La lectura de órdenes de compra ya usa las columnas V2 (`supplier_id`, `order_date`, `unit_cost`, `destination`) y las compras nuevas entran a bodega mediante movimientos `purchase`.
- La compilación de producción se validó con `npm run build` y quedó correcta.

### Cambios recientes de arquitectura

- Se añadió `main/supabase/add_audit_logs.sql` para crear la tabla `audit_logs`, la función `audit_trigger()` y los triggers necesarios para registrar cambios por tabla.
- Se agregó el store Pinia `src/stores/audit.js` para consultar logs desde Supabase.
- Se agregó el componente `src/components/admin/inventory/AuditLogs.vue` para visualizar los eventos de auditoría.
- Se consolidó un modelo de administración con único administrador maestro (`super_admin`) para arrancar con claridad operativa.
- Se dejó el sistema preparado para crecer sin complicar la operación inicial.

### Estado actual del proyecto

El proyecto está en una etapa sólida de base operativa, con varias capas ya estructuradas y funcionales:

- Catálogo real
- Variantes por tono / referencia
- Compras a proveedor
- Inventario por movimientos
- Transferencias internas
- Ventas por pedido o venta física
- Panel administrativo protegido
- Auditoría de cambios

Lo que sigue en orden lógico es:

1. Cierre de la lógica transaccional para evitar sobreventas.
2. Integración de pagos reales y comprobantes.
3. Estados del pedido más completos y trazables.
4. Facturación / seguimiento / envío.
5. Pruebas end-to-end en entorno real.

### Pendiente / próximos pasos

- Implementar reserva de stock y validación atómica al crear pedidos para evitar sobreventa concurrente.
- Integrar la pasarela de pagos y actualizar el estado `paid` en `payments` y `orders`.
- Completar el flujo de envío y entrega con trazabilidad real.
- Añadir más filtros en auditoría e historial de inventario (fecha, variante, producto, usuario).
- Probar la operación completa desde el admin hasta la compra del cliente.
- Versionar mejor la base de datos y dejar una migración final consistente para producción.

### Verificación reciente

- `npm run build` finalizó correctamente y la aplicación compila sin errores.

### Orden de continuación (prioridad inmediata)

1. Implementar reserva de stock al crear un pedido.
2. Añadir flujo de pagos con comprobante y actualización de estado del pedido.
3. Cerrar la trazabilidad de envío / entrega.
4. Reforzar la auditoría con filtros y validación de usuario para cada acción.
5. Ejecutar pruebas E2E del checkout y del inventario real.

### 10.1 Regla operativa final del proyecto

La estructura final deseada del negocio es la siguiente:

- el usuario compra
- el pedido queda guardado en la base de datos
- el stock se valida antes de confirmar la venta
- el admin revisa el pedido desde el panel
- se registra el pago y su comprobante
- se actualiza el estado del pedido
- se registra cada cambio en auditoría
- el cliente recibe información clara por WhatsApp o confirmación interna

Esto es la mejor versión para una marca de belleza que quiere vender con orden, trazabilidad y control.

### 10.2 Decisión de administración

Se decidió operar con un único administrador maestro al inicio para mantener estabilidad, claridad y control total del negocio. Esto es la base correcta para arrancar sin errores de permiso ni sobrecomplicación.

En el futuro, si la operación crece, se podrá abrir la lógica de perfiles adicionales sin romper la estructura actual.

### 10.3 Revisión contra el código actual (23 de agosto de 2026)

Esta revisión compara el documento con el código presente en `main/`. El resultado distingue entre estructura creada, flujo conectado y funcionalidad todavía pendiente.

#### Lo que sí llevamos

- Storefront Vue con rutas para inicio, tienda, detalle de producto, carrito, información, contacto y términos.
- Panel administrativo con dashboard, productos, inventario, compras, proveedores, ventas físicas, pedidos, reportes, configuración y auditoría.
- Catálogo conectado a `products`, variantes activas conectadas a `product_variants` y selección obligatoria de variante cuando el producto la tiene.
- Compras e inventario modelados en Supabase con `purchase_orders`, `purchase_order_items`, `inventory_movements`, `inventory_sale_balances` e `inventory_balances`.
- Flujo de checkout que valida cantidades, crea cliente, pedido, items, pago pendiente y envío pendiente; después abre WhatsApp con el resumen.
- Estados operativos usados por la interfaz: `pending`, `paid`, `shipped` y `returned`.
- Ventas físicas, movimientos de venta, transferencias de bodega a venta y lectura del historial de movimientos.
- Autenticación con Supabase Auth cuando existen las variables de entorno y modo demo local cuando no está configurado Supabase.
- RLS para separar lectura pública del catálogo y operaciones administrativas, además de inserción pública de clientes, pedidos, items y pagos.
- La arquitectura aprobada ahora agrupa Productos, Variantes, Inventario de compras, Compras, Inventario de venta y Categorías/atributos bajo Gestión de productos; Ventas y los demás módulos operativos permanecen independientes.

#### Diferencias importantes encontradas

1. **La reserva atómica ya fue implementada y desplegada; falta probarla.** El flujo anterior tenía un trigger que generaba un movimiento `online_order` negativo y luego `reserveOrderStock()` intentaba insertar otro movimiento positivo. Ahora `main/supabase/atomic_order.sql` elimina ese trigger y crea `create_order_with_stock()`, que bloquea los productos/variantes afectados y crea cliente, pedido, items, descuento de stock, pago y envío dentro de una sola transacción. La migración ya fue ejecutada en Supabase; queda probar pedidos concurrentes, devoluciones y el stock resultante.
2. **La auditoría tiene dos contratos incompatibles.** `schema.sql` define `audit_logs` con `entity_type`, `entity_id`, `details`, `created_by` y `created_at`. `add_audit_logs.sql` elimina y recrea la tabla con `table_name`, `record_id`, `changed_by`, `changed_at`, `old_data` y `new_data`. El store y el componente de auditoría usan el segundo contrato, mientras `orders.js` inserta campos del primero. Además, el script adicional usa `drop table ... cascade`, por lo que no debe tratarse como una migración no destructiva.
3. **Persisten caminos legacy de inventario.** `inventory.js` todavía contiene `addPurchaseOrderLegacy()` y operaciones sobre `sale_inventory` y `purchase_inventory`, aunque esas tablas no se crean en el esquema V2. El código principal ya usa movimientos, pero los caminos antiguos no están retirados.
4. **El stock por variante necesita revisión.** `getVariantAvailableStock()` resta `balance.saleStock` al campo `variant.stock`, aunque `saleStock` ya es un saldo derivado de movimientos. Esto puede descontar dos veces el stock disponible.
5. **Compras: escritura V2 y lectura legacy.** La creación usa `supplier_id`, `order_date`, `unit_cost` y `destination`, que coinciden con `schema.sql`; la lectura posterior todavía busca `supplier`, `date`, `cost_price` y `to_sale`. El registro puede crearse y luego mostrarse incompleto o con valores vacíos.
6. **Pagos están preparados, pero no integrados por completo.** El checkout siempre registra un pago `pending` con método `transfer`. No hay carga de comprobante, referencia ni selección real de `cash`, `nequi` o `daviplata`. El admin cambia el estado del pago al pasar el pedido a `paid`, pero el código actualiza `updated_at` en `payments`, columna que no existe en `schema.sql`.
7. **Envíos están preparados, pero no tienen gestión completa.** La interfaz cambia el pedido a `shipped` y actualiza el envío, pero no captura transportadora, guía, fecha estimada, fecha de entrega ni seguimiento público. También se actualiza `updated_at` en `shipments`, columna que tampoco existe en `schema.sql`.
8. **Los estados del esquema son más amplios que los de la interfaz.** La base permite `confirmed`, `preparing`, `delivered` y `cancelled`, pero el panel opera principalmente con pendiente, pagado, enviado y devuelto. El getter `deliveredOrders` además agrupa devoluciones, no el estado `delivered`.
9. **Las promociones del esquema no están conectadas al negocio.** `AdminConfiguracion.vue` guarda banners/promociones visuales en `localStorage` (`strawberry-home-promotions`). No se usan `promotions` ni `promotion_products` para calcular descuentos, cupones, combos o promociones por categoría.
10. **Roles y autenticación tienen alcance limitado.** Existe `admin_profiles`, pero `hasAccess()` concede acceso general y el store fuerza `super_admin`. También permanece la tabla compatible `admins` con `password_hash` y el modo demo con credenciales/localStorage; por tanto, Supabase Auth no es el único camino en todos los entornos.
11. **El CRUD del catálogo no cubre todo el esquema.** El panel gestiona principalmente nombre, categoría, descripción, precio, imagen y activo. Marca, tipo de piel, acabado, cobertura, contenido neto, código de barras, slug y banderas de destacado/recomendado no están completos en el flujo administrativo.
12. **La política RLS documentada tiene un fragmento incompleto.** En el bloque de recomendaciones aparece `create policy "orders_admin_update" on public.orders` sin `for update`, `using` ni `with check`; ese SQL no está listo para ejecutar tal como aparece en el documento.
13. **La nueva organización todavía no está reflejada completamente en la interfaz ni en Supabase.** Proveedores, categorías, marcas, tipos de piel, acabados y coberturas deben administrarse desde un módulo dinámico; hoy solo existen proveedores y categorías parciales, y los demás atributos se manejan principalmente como texto o datos mock.
14. **El formulario de Productos ya no mezcla catálogo e inventario.** Se eliminó la entrada de `stock` de alta, edición y variantes. La cantidad inicial se registra en Compras, entra a Bodega y se transfiere después a Inventario de venta. La pantalla de inventario aún conserva nombres legacy por compatibilidad, pero el flujo V2 usa movimientos.

#### Estado de producción

La arquitectura base y el recorrido visual están avanzados, pero todavía no debe considerarse un flujo ecommerce seguro para producción. `atomic_order.sql` ya fue ejecutado en Supabase; antes de publicarlo hay que probar la reserva atómica y validar los contratos de pagos, envíos y auditoría. La revisión de código fue estática; la compilación mencionada anteriormente no se volvió a ejecutar durante esta actualización.

#### Prioridad actualizada

1. Validar `atomic_order.sql` con un pedido real de prueba, pedidos concurrentes y liberación por devolución.
2. Ejecutar y validar la migración de tablas maestras y relaciones dinámicas para categorías, subcategorías, marcas, tipos de piel, acabados y coberturas.
3. Probar el nuevo formulario de catálogo y cargar los valores iniciales del negocio.
4. Hacer que toda compra entre a bodega y que la transferencia a venta sea parcial o total mediante movimientos.
5. Consolidar `audit_logs`, retirar caminos legacy y corregir los contratos de pagos/envíos.
6. Completar comprobantes, datos de envío, estados soportados y pruebas E2E.

#### Cambios de Supabase requeridos por esta decisión

Los cambios de Supabase todavía no se han ejecutado. La migración descrita en la sección 4.3 es necesaria para crear las tablas maestras y relacionarlas con `products`. Debe ejecutarse después de respaldar la base y revisar los valores actuales de `brand`, `skin_type`, `finish` y `coverage`.

La migración no debe borrar datos ni eliminar inmediatamente `product_variants.stock`. Primero se deben copiar los valores existentes, adaptar el frontend para que no edite stock desde Productos/Variantes y verificar los saldos de `inventory_movements`. Solo después se podrá retirar el campo legacy.

---

## 11. Recomendación final

El proyecto ya no está en una fase de mockups ni de catálogo estático. Está caminando hacia un sistema operativo real de ecommerce de maquillaje con control de inventario y trazabilidad.

La estrategia correcta es mantener la lógica de negocio clara: catálogo, inventario, compra, venta, pago y auditoría, siempre separadas y con historial.

Si se mantiene esta estructura, la marca podrá escalar sin perder control de stock ni de operación.

---

## 12. Datos de prueba recomendados

Estos datos sirven para testear el proyecto y verificar que la estructura funciona antes de ponerlo en producción.

### 12.1 Proveedores
```sql
insert into public.suppliers (name, document_number, contact_name, phone, email, address, city, payment_terms, notes)
values
  ('Distribuidora Maquillaje Pro', '900123456-1', 'Laura Gómez', '3001112233', 'laura@distribuidora1.com', 'Cra 23 # 45-12', 'Manizales', '30 días', 'Proveedor base de bases y sombras'),
  ('Beauty Supply Co', '900987654-2', 'Daniel Restrepo', '3104456677', 'daniel@beautysupply.com', 'Cl 10 # 77-33', 'Bogotá', '15 días', 'Proveedor de skincare'),
  ('Cosmetica Natural SAS', '901223344-5', 'Valentina Ruiz', '3157789900', 'ventas@cosmeticanatural.com', 'Av. Central 88', 'Pereira', '45 días', 'Productos naturales');
```

### 12.2 Productos

```sql
insert into public.products (
  name, brand, category, description, skin_type, finish, coverage, net_content_ml,
  barcode, is_featured, is_new, is_recommended, status, slug, image_url, active
)
values
  ('Base Velvet Skin', 'Strawberry', 'Bases', 'Base líquida con acabado natural y duración media.', 'mixta', 'mate', 'media', 30, '750123456001', true, true, true, 'active', 'base-velvet-skin', 'https://example.com/base.jpg', true),
  ('Corrector Full Coverage', 'Strawberry', 'Correctores', 'Corrector de alta cobertura para ojeras y imperfecciones.', 'todos', 'natural', 'alta', 15, '750123456002', true, true, true, 'active', 'corrector-full-coverage', 'https://example.com/corrector.jpg', true),
  ('Labial Cherry Pop', 'Strawberry', 'Labios', 'Labial de acabado satinado y duración prolongada.', 'todos', 'satinado', 'alta', 0, '750123456003', false, true, true, 'active', 'labial-cherry-pop', 'https://example.com/labial.jpg', true),
  ('Serum Vitamina C', 'Strawberry', 'Skincare', 'Serum para luminosidad y revitalización.', 'grasa', 'luminoso', null, 30, '750123456004', true, true, true, 'active', 'serum-vitamina-c', 'https://example.com/serum.jpg', true),
```

### 12.3 Variantes de ejemplo

```sql
insert into public.product_variants (product_id, name, sku, barcode, variant_type, option_value, price, compare_at_price, stock, is_active)
values
  (1, 'Base Velvet Skin - Tono 01', 'BASE-01', '750123456010', 'tone', '01', 38900, 45900, 12, true),
  (2, 'Corrector Full Coverage - Tono 01', 'COR-01', '750123456020', 'tone', '01', 25900, 31900, 16, true),
  (3, 'Labial Cherry Pop - Rojo intenso', 'LAB-RED', '750123456030', 'tone', 'rojo', 24900, 29900, 20, true),
  (4, 'Serum Vitamina C - 30ml', 'SER-30', '750123456040', 'size', '30ml', 42900, 49900, 7, true);
```

### 12.4 Proveedor y compra de prueba

```sql
insert into public.purchase_orders (supplier_id, order_number, order_date, notes, status, total)
values
  (1, 'PO-2026-001', current_date - 3, 'Compra inicial de bases y correctores', 'received', 540000);

insert into public.purchase_order_items (purchase_order_id, product_id, variant_id, quantity, unit_cost, destination)
values
  (1, 1, 1, 10, 18000, 'warehouse'),
  (1, 1, 2, 8, 18000, 'warehouse'),
  (1, 2, 3, 12, 12000, 'warehouse');
```

### 12.5 Movimiento de inventario

```sql
insert into public.inventory_movements (product_id, variant_id, movement_type, quantity, unit_cost, reference_type, reference_id, notes)
values
  (1, 1, 'purchase', 10, 18000, 'purchase_order', 1, 'Ingreso a bodega'),
  (1, 2, 'purchase', 8, 18000, 'purchase_order', 1, 'Ingreso a bodega'),
  (2, 3, 'purchase', 12, 12000, 'purchase_order', 1, 'Ingreso a bodega');
```

### 12.6 Promociones de prueba

```sql
insert into public.promotions (title, label, type, value, starts_at, ends_at, active)
values
  ('Oferta de bases', 'OFERTA', 'percent', 20, now(), now() + interval '30 days', true),
  ('Envío gratis', 'ENVÍO', 'shipping', 0, now(), now() + interval '15 days', true),
  ('Combo skincare', 'BUNDLE', 'bundle', 0, now(), now() + interval '20 days', true);
```

---

## 13. Recomendación final de implementación

### Qué haría yo en este proyecto

1. Mantener la estructura visual actual de Vue.
2. Crear el módulo de Gestión de productos con Productos, Variantes, Inventario de compras, Compras, Inventario de venta y Categorías/atributos.
3. Crear las tablas maestras dinámicas en Supabase y relacionarlas con `products`.
4. Quitar `stock` del formulario de Productos y dejar las existencias bajo `inventory_movements`.
5. Mantener `products` como catálogo, con reglas condicionales para tipo de piel, acabado, cobertura y contenido neto.
6. Mantener `product_variants` para tonos y referencias, gestionadas desde su módulo independiente.
7. Garantizar que las compras entren primero a bodega y que las transferencias a venta sean posteriores y parciales o totales.
8. Añadir `suppliers`, `purchase_orders`, `payments`, `shipments`, `admins` con Supabase Auth y `admin_profiles`.
9. Quitar acceso público masivo a pedidos y dejar la consulta para un token o confirmación por WhatsApp.
10. Cuando todo esto quede estable, integrar pago online y factura digital.

### Qué no haría

- No seguir usando `localStorage` como autenticación real.
- No mantener `products.stock` como fuente de verdad.
- No depender únicamente de WhatsApp para registrar la operación.
- No dejar un stock sin historial.
- No eliminar productos históricos; solo pausarlos o archivarlos.

---

## 14. Estado final recomendado

El proyecto tiene buena base, buen nombre, buena estética y una lógica comercial clara. Lo que falta no es más diseño, sino una estructura de datos más serena, más comercial y más controlable.

Con esta arquitectura, la marca puede crecer de una forma mucho más profesional:

- mejor manejo de stock
- menos errores operativos
- mejores compras
- mejor control de pedidos
- mejor uso de promociones
- mejor administración
- preparación para pagos online y logística real

---

## 15. Resumen ejecutivo

La mejor decisión para este proyecto es:

- productos con atributos de maquillaje
- variantes por tono o referencia
- compras con proveedores
- bodega y almacenamiento real
- inventario de venta controlado
- historial de movimientos
- pagos por método y comprobante
- envíos con transportadora y guía
- pedidos online con control y factura
- seguridad real con Supabase Auth
- auditoría de cambios y estados

Eso hará que el negocio se vea serio, funcione bien y esté listo para crecer.

Si quieres, en el siguiente paso puedo dejarte ya la versión exacta de SQL final lista para ejecutar en Supabase junto con la estructura de archivos Vue para adaptar la tienda a este nuevo modelo.
