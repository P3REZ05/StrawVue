# Plan de pruebas — Strawberry Makeup

Guion completo para probar el sistema antes de abrir la tienda. Está pensado
para ejecutarse **a mano, en local**, marcando cada casilla.

- **Versión:** 14 de septiembre de 2026
- **Cubre:** migraciones 001–019, panel completo y tienda pública
- **Dura:** unas 4–6 horas repartidas. No hace falta seguirlo de un tirón,
  **pero sí en orden**: cada bloque deja montado lo que necesita el siguiente.

---

## Antes de empezar

### 0.1 Dónde van a caer los datos

> **Léelo antes de tocar nada.** Estas pruebas crean pedidos, ventas y
> movimientos de inventario **reales**. Si las corres contra `StrawBack`, esos
> datos falsos se mezclan con los del negocio y contaminan los reportes. Ya
> pasó el 8 de septiembre: hubo que vaciar la base porque los ingresos
> mostraban ~$300.000 que nunca existieron.

- [ ] Crear un segundo proyecto en Supabase llamado `StrawBack-pruebas`
      (el plan gratuito permite **2 proyectos activos**)
- [ ] Aplicar en ese proyecto, **en orden**, `schema.sql`, `add_audit_logs.sql`
      y las migraciones `001` a `019`
- [ ] Crear el bucket de imágenes si la migración 008 no lo creó sola
- [ ] Apuntar `main/.env` a las credenciales del proyecto de pruebas
- [ ] Crear un usuario admin en ese proyecto e insertarlo en `admin_profiles`
      con `role = 'super_admin'`

**Alternativa si no quieres el segundo proyecto:** correr todo contra
`StrawBack` y al terminar ejecutar `supabase/reset_datos_prueba.sql`. Funciona,
pero borra el historial de movimientos y hay que reconstruir el stock real
desde cero.

### 0.2 Migraciones pendientes

- [ ] **019** aplicada (`019_ofertas_portada.sql`) — sin ella la sección
      «Ofertas especiales» de la portada no existe y la pantalla Portada del
      panel da error
- [ ] **018** aplicada (`018_retirar_legacy.sql`) — solo limpia columnas
      muertas, no bloquea nada

### 0.3 Verificación automática

```bash
cd main
npm ci
npm run verify      # lint + build + prueba de humo + responsive
```

- [ ] `npm run lint` → **0 errores** (3 advertencias de archivos muertos: normal)
- [ ] `npm run build` → compila
- [ ] `npm run smoke` → 9 rutas correctas
- [ ] `npm run responsive` → sin desbordes ni áreas táctiles pequeñas

### 0.4 Las dos reglas que explican casi todos los fallos de este proyecto

1. **«Guardado» no es guardado.** Cuatro veces una pantalla confirmó y la base
   quedó vacía (mostrador, compras, configuración, contacto). **Después de cada
   guardado de esta guía: recarga la página (F5) y comprueba que sigue ahí.**
   Si no lo dice explícitamente el paso, hazlo igual.
2. **RLS no da error, devuelve cero filas.** Una tabla sin permiso responde
   «vacío» sin fallar: un SELECT parece vacío y un UPDATE parece exitoso. Si
   algo "funciona pero no guarda", ejecuta `migrations/000_diagnostico.sql`
   antes de buscar en el código.

### 0.5 Cómo anotar un fallo

Para cada casilla que no pase, anota: **qué hiciste · qué esperabas · qué pasó ·
qué dice la consola del navegador (F12)**. Sin esos cuatro datos el fallo no se
puede reproducir.

---

## 1 · Acceso y seguridad

El panel protege precios, costos, proveedores y datos de clientas.

- [ ] **1.1** Entrar a `/admin` sin sesión → aparece el login, no el panel
- [ ] **1.2** Intentar `/admin/dashboard` escribiendo la URL sin sesión →
      redirige al login
- [ ] **1.3** Login con contraseña incorrecta → mensaje de error, no entra
- [ ] **1.4** Login correcto → entra y muestra «Acceso: super_admin»
- [ ] **1.5** Cerrar sesión → vuelve al login; pulsar «atrás» en el navegador
      **no** devuelve al panel
- [ ] **1.6** Con sesión abierta, entrar a `/admin` → redirige al dashboard

**Prueba de fuga de datos (importante).** En una ventana de incógnito, sin
iniciar sesión, abre la consola (F12) y ejecuta:

```js
const k = 'TU_ANON_KEY'
const url = 'https://TU-PROYECTO.supabase.co/rest/v1'
for (const t of ['suppliers','purchase_orders','inventory_movements','contact_messages','customers','orders','audit_logs','admin_profiles']) {
  const r = await fetch(`${url}/${t}?select=*&limit=1`, { headers: { apikey: k } })
  console.log(t, r.status, (await r.json()).length ?? '—')
}
```

- [ ] **1.7** Las ocho tablas devuelven **0 filas** (o 401). Si alguna devuelve
      datos, hay una fuga: proveedores, costos o teléfonos de clientas
      expuestos a cualquiera

---

## 2 · Catálogo: crear un producto

- [ ] **2.1** Productos → «Nuevo producto» → guardar sin nombre → avisa y no guarda
- [ ] **2.2** Escribir solo el nombre y pulsar **Imágenes** → guarda el borrador
      solo y abre la pestaña (el candado desaparece)
- [ ] **2.3** Se creó **un** producto, no varios (revisa la lista)
- [ ] **2.4** Completar la ficha: marca, categoría, precio, contenido, descripción
- [ ] **2.5** Crear una marca y una categoría **desde el propio editor**
      (creación al vuelo) → quedan seleccionadas
- [ ] **2.6** Los atributos cambian según la categoría: cobertura y acabado
      aparecen en Bases, no en Brochas
- [ ] **2.7** Recargar (F5) → todo lo escrito sigue ahí

### Tonos

- [ ] **2.8** Pestaña Tonos → crear 4 tonos con el pegado por lotes
- [ ] **2.9** Cada tono recibe un **SKU único** automático
- [ ] **2.10** Poner precio solo al producto → los 4 tonos **heredan** ese precio
- [ ] **2.11** Cambiar el precio de **un** tono → los otros 3 **no** se mueven
- [ ] **2.12** Dejar el precio de ese tono vacío otra vez → vuelve a heredar
      (heredar ≠ gratis: debe mostrar el precio del producto, no $0)
- [ ] **2.13** Cambiar el precio del **producto** → los que heredan se mueven, el editado no

### Imágenes

- [ ] **2.14** Subir una foto **arrastrándola** a la zona de subida
- [ ] **2.15** Subir 3 más; la primera queda marcada como principal
- [ ] **2.16** Cambiar cuál es la principal
- [ ] **2.17** Borrar una imagen → desaparece de la lista
- [ ] **2.18** Subir una foto a **un tono concreto**
- [ ] **2.19** Subir un archivo que no sea imagen (un PDF) → lo rechaza sin romperse
- [ ] **2.20** Recargar → las imágenes siguen ahí (no son URLs `blob:` muertas)

### Duplicar y archivar

- [ ] **2.21** Duplicar un producto con tonos → copia ficha y gama, **SKU nuevos**,
      nace en borrador, **sin stock ni imágenes**
- [ ] **2.22** Archivar un producto → pide confirmación y desaparece de la tienda
- [ ] **2.23** Buscar por nombre, por marca, por tono y por SKU → encuentra
- [ ] **2.24** Filtrar por categoría y por estado; ordenar por precio y por stock

---

## 3 · Proveedores

- [ ] **3.1** Crear un proveedor con todos los campos
- [ ] **3.2** Guardar sin nombre → avisa
- [ ] **3.3** Editar sus notas → **recargar** → el cambio persiste
- [ ] **3.4** Desactivar un proveedor → sale de la lista
- [ ] **3.5** Sus órdenes de compra anteriores siguen existiendo

---

## 4 · Compras → bodega

- [ ] **4.1** Inventario → Compras → registrar una compra de **100 unidades**
      de un tono, con costo unitario, proveedor y **una nota escrita**
- [ ] **4.2** Guardar sin producto o con cantidad 0 → avisa
- [ ] **4.3** La orden aparece en la lista con su número, proveedor y total
- [ ] **4.4** **Bodega** muestra las 100 unidades
- [ ] **4.5** «Listo para vender» **no** las muestra (todavía no están a la venta)
- [ ] **4.6** La tienda pública sigue mostrando el producto como agotado
- [ ] **4.7** Movimientos registra una entrada `purchase` de +100 con su costo

### La ficha de bodega

- [ ] **4.8** Pulsar la fila en Bodega → abre la ficha completa
- [ ] **4.9** **La nota que escribiste en 4.1 aparece destacada arriba**
- [ ] **4.10** Muestra proveedor, orden, costo unitario, margen y los atributos
      del producto resueltos a nombres (no a números)
- [ ] **4.11** «Editar ficha completa» lleva al editor del producto

---

## 5 · Bodega → venta

- [ ] **5.1** Bodega → «Pasar a venta» → pedir **999** → avisa «Solo hay 100»
      y el botón queda bloqueado
- [ ] **5.2** Pedir **2.5** → avisa que no se pueden transferir fracciones
- [ ] **5.3** Pedir **0** o vacío → avisa
- [ ] **5.4** Transferir **30** con una nota
- [ ] **5.5** Bodega baja a 70; «Listo para vender» muestra 30
- [ ] **5.6** Movimientos registra **dos** movimientos: −30 de bodega y +30 a venta
- [ ] **5.7** La nota aparece en el historial
- [ ] **5.8** La tienda pública ya muestra ese tono disponible
- [ ] **5.9** Desde «Listo para vender», el botón «Hay 70 en bodega» salta a Bodega

---

## 6 · La tienda pública

- [ ] **6.1** La portada carga: banner, ofertas, categorías, historia
- [ ] **6.2** Las categorías muestran el **conteo real** de productos
- [ ] **6.3** Una categoría vacía dice «próximamente»
- [ ] **6.4** Pulsar una categoría → la tienda abre filtrada por ella
- [ ] **6.5** «Ver todo» lleva a la tienda sin filtros

### Ficha de producto

- [ ] **6.6** Abrir un producto con varias fotos → **pulsar una miniatura cambia
      la foto grande** y esa miniatura queda marcada
- [ ] **6.7** Elegir otro tono → aparece la foto de ese tono
- [ ] **6.8** Un tono agotado se ve deshabilitado y no se puede elegir
- [ ] **6.9** El precio mostrado es el del tono elegido
- [ ] **6.10** No se puede añadir al carrito sin elegir tono
- [ ] **6.11** No se puede pedir más unidades de las disponibles

### Filtros

- [ ] **6.12** Buscar por nombre encuentra el producto
- [ ] **6.13** Filtrar por categoría, precio, subtono y familia
- [ ] **6.14** «En stock» oculta los agotados
- [ ] **6.15** «Limpiar» restablece todo y desaparece
- [ ] **6.16** En celular los filtros van **dos por fila**, no apilados

---

## 7 · Carrito y pedido

- [ ] **7.1** Añadir un producto con tono → el carrito muestra nombre, tono y color
- [ ] **7.2** Cambiar cantidades; no deja pasar del stock
- [ ] **7.3** Eliminar una línea
- [ ] **7.4** Cerrar el navegador y volver → **el carrito sigue ahí**
- [ ] **7.5** Configuración → poner envío en $14.500 y envío gratis desde $150.000
- [ ] **7.6** Carrito con subtotal bajo → cobra $14.500 de envío
- [ ] **7.7** Carrito por encima de $150.000 → envío GRATIS
- [ ] **7.8** El aviso «te faltan X para envío gratis» calcula bien

### El pedido, de punta a punta

- [ ] **7.9** Completar datos de envío; los campos obligatorios se validan
- [ ] **7.10** Confirmar → **el total que cobra el servidor es exactamente el que
      mostraba el carrito** (apúntalos y compáralos)
- [ ] **7.11** Se abre WhatsApp con el resumen, **y el tono aparece en el mensaje**
- [ ] **7.12** El pedido aparece en el panel → Pedidos
- [ ] **7.13** El stock bajó por **tono**, no por producto
- [ ] **7.14** Movimientos registra la salida

### Ciclo de vida

- [ ] **7.15** Marcar como **pagado** → subir un comprobante
- [ ] **7.16** Marcar como **enviado** → transportadora, guía y fecha estimada
- [ ] **7.17** Marcar como **entregado**
- [ ] **7.18** Marcar un pedido como **devuelto** → el stock **vuelve a subir**
- [ ] **7.19** La devolución crea un movimiento `return` **sin borrar** la salida original
- [ ] **7.20** El pedido devuelto aparece en Historial

---

## 8 · Precios y promociones

> Aquí es donde se pierde dinero. Cada prueba compara **lo que muestra la
> tienda** contra **lo que cobra el servidor**.

- [ ] **8.1** Promoción **porcentaje** 20% sobre una categoría → la tienda muestra
      el precio rebajado y tachado el original
- [ ] **8.2** Hacer el pedido → el servidor cobra ese mismo precio
- [ ] **8.3** Promoción de **monto fijo** → ídem
- [ ] **8.4** Promoción con **fecha de fin pasada** → no se aplica
- [ ] **8.5** Promoción **desactivada** → no se aplica
- [ ] **8.6** Dos promociones sobre el mismo producto → se aplica **solo una**,
      la de mayor prioridad (no se acumulan)

### Combos

- [ ] **8.7** Crear un **2x1** sobre una categoría
- [ ] **8.8** Intentar guardar un «2x5» (llevas 2, pagas 5) → lo rechaza
- [ ] **8.9** Llevar **2 productos distintos** de esa categoría → aplica el combo
      (cruza líneas, no exige el mismo tono)
- [ ] **8.10** Con precios distintos, **la unidad gratis es la más barata**
- [ ] **8.11** El carrito muestra la línea verde con el descuento
- [ ] **8.12** **Confirmar el pedido: el servidor cobra exactamente ese total**
- [ ] **8.13** Llevar 3 unidades → solo una gratis (no 1,5)

### Cupones

- [ ] **8.14** Crear un cupón con código, compra mínima y usos máximos
- [ ] **8.15** Código inválido → avisa
- [ ] **8.16** Por debajo de la compra mínima → no aplica
- [ ] **8.17** Cupón válido → descuenta, y el total cobrado coincide
- [ ] **8.18** Agotar los usos → deja de funcionar
- [ ] **8.19** Cupón **+ combo** a la vez → el cupón se calcula **después** del
      combo (si no, descuenta dos veces sobre la unidad regalada)

### Intento de manipulación

En la consola del navegador, con el carrito lleno, intenta enviar un pedido con
`unit_price: 1`:

- [ ] **8.20** El servidor **ignora el precio del cliente** y cobra el real.
      Esta prueba ya pasó una vez; conviene repetirla tras cualquier cambio en pedidos

---

## 9 · Venta de mostrador (POS)

- [ ] **9.1** Ventas → la lista muestra lo disponible **por tono**
- [ ] **9.2** El precio mostrado es el **efectivo** (con promoción), con el de
      lista tachado si hay descuento
- [ ] **9.3** Añadir más unidades de las que hay → avisa
- [ ] **9.4** Registrar una venta con 2 tonos distintos
- [ ] **9.5** El stock baja **por tono**
- [ ] **9.6** La venta aparece en el historial con **fecha y precios correctos**
      (no fecha en blanco ni $0)
- [ ] **9.7** Aparece en Reportes con su costo y su margen
- [ ] **9.8** Movimientos registra la salida

### Concurrencia

- [ ] **9.9** Dejar **1 unidad** de un tono. Abrir la tienda en dos navegadores
      distintos y confirmar el pedido **a la vez** → uno pasa, el otro recibe
      «stock insuficiente». **Nunca deben pasar los dos**
- [ ] **9.10** Lo mismo entre un pedido online y una venta de mostrador simultáneos

---

## 10 · Reportes y dashboard

- [ ] **10.1** Dashboard: los ingresos cuentan solo pagado/enviado/entregado,
      **sin envío** y **sin devoluciones**
- [ ] **10.2** El número de ingresos del Dashboard **coincide con el de Reportes**
      (llegaron a discrepar: $209.500 contra $113.700)
- [ ] **10.3** Los más vendidos agrupan por producto, **no repiten el mismo
      producto en tres filas**
- [ ] **10.4** Reportes: ingreso, costo y margen cuadran con lo cobrado
- [ ] **10.5** Un pedido **con cupón** muestra el ingreso **neto**, no el bruto
- [ ] **10.6** Con un solo día de datos, el gráfico de línea **dibuja algo**
      (llegó a salir vacío)
- [ ] **10.7** Vista de tabla y cambio de rango de fechas
- [ ] **10.8** Reporte por tono, por categoría y riesgo de stock

---

## 11 · Trazabilidad y auditoría

- [ ] **11.1** Abrir un producto → pestaña Trazabilidad → aparecen todos los
      eventos: compra, transferencia, cambios de precio y de estado
- [ ] **11.2** Los cambios se leen en español («Cobertura: → Alta»), no en `jsonb` crudo
- [ ] **11.3** Los precios salen en formato colombiano ($ 38.900)
- [ ] **11.4** **Cada cambio aparece una sola vez** (llegó a contarse doble)
- [ ] **11.5** Los filtros por tipo funcionan
- [ ] **11.6** El resumen de unidades entradas y salidas cuadra
- [ ] **11.7** Auditoría registra quién hizo cada cambio y cuándo

---

## 12 · Configuración y portada

- [ ] **12.1** Cambiar el costo de envío → **el carrito de la tienda lo refleja**
- [ ] **12.2** Cambiar el número de WhatsApp → el mensaje del pedido va al nuevo
- [ ] **12.3** Cambiar las redes sociales → el pie de página las usa
- [ ] **12.4** Subir un banner de portada → **se ve en la tienda desde otro
      navegador sin sesión** (antes vivían en `localStorage` y no los veía nadie)
- [ ] **12.5** Desactivar un banner → desaparece

### Ofertas especiales *(requiere la migración 019)*

- [ ] **12.6** Portada → crear una tarjeta con imagen, etiqueta y destino
- [ ] **12.7** La **vista previa** muestra cómo va a quedar
- [ ] **12.8** Guardar **no** la publica: sigue como borrador y **no se ve en la tienda**
- [ ] **12.9** Publicarla → ahora sí aparece en la portada
- [ ] **12.10** Probar los cuatro tamaños (destacada, ancha, alta, pequeña)
- [ ] **12.11** El aviso de «queda un hueco de N celdas» acierta
- [ ] **12.12** Cambiar entre vista de escritorio y celular
- [ ] **12.13** Pulsar la tarjeta en la tienda → lleva a su destino
- [ ] **12.14** Reordenar y borrar tarjetas

---

## 13 · Formulario de contacto

- [ ] **13.1** Enviar un mensaje desde `/contacto`
- [ ] **13.2** **Aparece en el panel → Mensajes** (antes la pantalla decía
      «recibido» y no guardaba nada)
- [ ] **13.3** El contador de no leídos sube
- [ ] **13.4** Abrirlo lo marca como leído
- [ ] **13.5** El enlace de WhatsApp abre con el número normalizado
- [ ] **13.6** Añadir una nota interna y archivar
- [ ] **13.7** En incógnito, sin sesión, `GET contact_messages` → **401 o 0 filas**
      (guarda nombres y teléfonos)

---

## 14 · Celular y tablet

Prueba en un **teléfono real** o con las herramientas de desarrollo (F12 →
modo dispositivo). El panel todavía **no** está adaptado a móvil; aquí solo se
prueba la tienda pública.

- [ ] **14.1** Portada, tienda, ficha, carrito, nosotros, contacto y términos
      **no se arrastran de lado**
- [ ] **14.2** Los botones se aciertan con el pulgar
- [ ] **14.3** Los puntitos del carrusel se pueden pulsar
- [ ] **14.4** Los filtros van dos por fila
- [ ] **14.5** Completar un pedido entero **desde el celular**
- [ ] **14.6** Repetir en 360 px, 390 px y 768 px de ancho

---

## 15 · Cuando algo falla

- [ ] **15.1** Apagar el wifi y recargar → la tienda **dice** que no pudo
      conectar; no se queda en blanco ni finge estar vacía
- [ ] **15.2** Cerrar sesión en otra pestaña y luego guardar algo en el panel →
      sale un error claro, no un «guardado» falso
- [ ] **15.3** Entrar a `/producto/99999` → no deja la pantalla en blanco
- [ ] **15.4** Entrar a `/cualquier-cosa` → redirige a la portada
- [ ] **15.5** Con el catálogo vacío, ninguna pantalla revienta

---

## 16 · Antes de publicar

- [ ] **16.1** Todas las casillas anteriores marcadas, o su fallo anotado y corregido
- [ ] **16.2** Precio de **«Brochas Ani-k»** corregido (está en `40`, debería ser `40.000`)
- [ ] **16.3** Borrar el producto «Producto de prueba auditoría» del catálogo
- [ ] **16.4** Borrados los archivos muertos: `AdminVariants.vue`, `AdminFilter.vue`,
      `AdminAddFilter.vue`, `src/data/mockData.js`
- [ ] **16.5** Borrada la carpeta suelta `StrawBerry\supabase\`
      (la buena es `StrawBerry\main\supabase\`)
- [ ] **16.6** **Contraseña del admin cambiada** si sigue siendo la del README (`admin123`)
- [ ] **16.7** `.env` **no** está en git
- [ ] **16.8** El `.env` de producción apunta a `StrawBack`, no al de pruebas
- [ ] **16.9** Fotos reales subidas a todos los productos
- [ ] **16.10** Compras reales registradas y stock transferido a venta
- [ ] **16.11** Dominio de producción añadido en Supabase → Authentication →
      URL Configuration (si no, el login del panel falla en producción)
- [ ] **16.12** Todo el trabajo **subido a GitHub** (el remoto lleva desde el
      6 de septiembre sin actualizar)

---

## Resumen

| Bloque | Casillas | Hechas | Fallos |
|---|---|---|---|
| 0 · Preparación | 11 | | |
| 1 · Acceso y seguridad | 7 | | |
| 2 · Catálogo | 24 | | |
| 3 · Proveedores | 5 | | |
| 4 · Compras → bodega | 11 | | |
| 5 · Bodega → venta | 9 | | |
| 6 · Tienda pública | 16 | | |
| 7 · Carrito y pedido | 20 | | |
| 8 · Precios y promociones | 20 | | |
| 9 · Mostrador | 10 | | |
| 10 · Reportes | 8 | | |
| 11 · Trazabilidad | 7 | | |
| 12 · Configuración y portada | 14 | | |
| 13 · Contacto | 7 | | |
| 14 · Celular | 6 | | |
| 15 · Cuando algo falla | 5 | | |
| 16 · Antes de publicar | 12 | | |
| **Total** | **192** | | |

### Si solo tienes una hora

Estas son las que protegen dinero y datos: **1.7** (fuga de datos),
**7.10** (el total cobrado coincide), **8.12** y **8.20** (promociones y
manipulación de precio), **9.9** (dos clientas por la última unidad),
**7.18** (la devolución reingresa el stock) y **10.2** (los ingresos cuadran).
