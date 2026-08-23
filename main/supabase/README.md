# 🍓 Strawberry Makeup - Conexión a Supabase

## 📋 Requisitos previos

1. Crear una cuenta gratuita en [supabase.com](https://supabase.com)
2. Crear un nuevo proyecto (elige un nombre como `strawberry-makeup`)
3. Anotar la **URL del proyecto** y la **API Key (anon)** que aparecen en:
   - Supabase Dashboard → Settings → API

## 🗄️ Paso 1: Crear la base de datos

1. Ve a **Supabase Dashboard** → tu proyecto → **SQL Editor**
2. Copia TODO el contenido del archivo `main/supabase/schema.sql`
3. Pégalo en el editor SQL
4. Haz clic en **Run** (o Ctrl+Enter)

Esto creará:
- 13 tablas (products, purchase_inventory, sale_inventory, purchase_orders, purchase_order_items, sales, sale_items, orders, order_items, admins, store_settings, categories, promotions)
- Datos iniciales (categorías, configuración de tienda, admin)
- Políticas de seguridad RLS

## 🔑 Paso 2: Crear el usuario admin en Supabase Auth

1. Ve a **Supabase Dashboard** → **Authentication** → **Users**
2. Haz clic en **Add user** → **Create new user**
3. Ingresa:
   - **Email:** `admin@strawberrymakeup.com`
   - **Password:** `admin123` (cámbiala después)
4. Haz clic en **Create user**

## 🔌 Paso 3: Obtener las credenciales

1. Ve a **Supabase Dashboard** → **Settings** → **API**
2. Copia estos dos valores:
   - **Project URL:** `https://TU-PROYECTO.supabase.co`
   - **anon public key:** `eyJhbGciOi...`

   https://vzsdubpklknbccvgvukl.supabase.co
   sb_publishable_XQi_S88S6vHiTwn5k9hQxg_MGbHZXks

## 📁 Paso 4: Configurar el proyecto 

1. Crea un archivo `.env` en la carpeta `main/`:

```env
VITE_SUPABASE_URL=https://TU-PROYECTO.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOi...
```

2. Instala la librería de Supabase:

```bash
cd main
npm install @supabase/supabase-js
```

## 🧪 Paso 5: Probar la conexión

Crea un archivo `main/src/lib/supabase.js`:

```js
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

## 📊 Estructura de la base de datos

### Tablas principales

| Tabla | Descripción |
|-------|-------------|
| `products` | Catálogo maestro de productos |
| `purchase_inventory` | Productos en bodega (comprados, no a la venta) |
| `sale_inventory` | Productos listos para vender con stock |
| `purchase_orders` | Órdenes de compra a proveedores |
| `purchase_order_items` | Detalle de cada compra |
| `sales` | Ventas físicas (POS) |
| `sale_items` | Detalle de cada venta |
| `orders` | Pedidos online de clientes |
| `order_items` | Detalle de cada pedido online |
| `admins` | Administradores del sistema |
| `store_settings` | Configuración (envío gratis, WhatsApp, etc.) |
| `categories` | Categorías de productos |
| `promotions` | Promociones activas |

### Campos clave

**products:**
- `id` - Identificador único
- `name` - Nombre del producto
- `category` - Categoría
- `description` - Descripción
- `price` - Precio de venta
- `sale_price` - Precio rebajado (opcional)
- `original_price` - Precio original (para tachado)
- `image` - URL de la imagen
- `active` - Si está activo (true/false)

**sale_inventory:**
- `product_id` - Referencia al producto
- `quantity` - Stock disponible
- `cost_price` - Costo de compra (para calcular ganancias)

**orders:**
- `order_number` - Número de orden (ej: ORD-1001)
- `customer_name` - Nombre del cliente
- `customer_phone` - Teléfono
- `customer_city` - Ciudad
- `customer_address` - Dirección
- `subtotal` - Subtotal
- `shipping` - Costo de envío
- `total` - Total
- `status` - pendiente / enviado / entregado / cancelado

## 🔒 Seguridad (RLS)

Las políticas de seguridad ya están configuradas en el SQL:

- **Lectura pública:** products, categories, promotions, orders, order_items, store_settings
- **Solo admin (autenticado):** purchase_inventory, sale_inventory, purchase_orders, purchase_order_items, sales, sale_items, admins
- **Escritura pública:** orders, order_items (para que los clientes puedan crear pedidos)
- **Escritura admin:** products, categories, promotions, store_settings

## 🚀 Siguientes pasos

1. ✅ Crear la base de datos (schema.sql)
2. ✅ Crear usuario admin en Auth
3. ✅ Configurar `.env` con credenciales
4. ⬜ Conectar los stores de Pinia con Supabase
5. ⬜ Proteger rutas del admin con autenticación
6. ⬜ Sincronizar inventario con la tienda pública