# Secuencia de commits para el refactor de productos.
# Ejecutar en PowerShell desde C:\Users\Usuario\Documents\StrawBerry
#   .\commits.ps1

$ErrorActionPreference = 'Stop'

Write-Host 'Archivos que se van a versionar:' -ForegroundColor Cyan
git status --short
Write-Host ''
if (git status --short | Select-String -Pattern '\.env$') {
  Write-Host 'AVISO: aparece un archivo .env en los cambios. Revisa antes de continuar.' -ForegroundColor Red
  exit 1
}
$r = Read-Host 'Continuar con los 6 commits? (s/n)'
if ($r -ne 's') { Write-Host 'Cancelado.'; exit }

# ---------------------------------------------------------------
# 1. Correcciones de inventario y del panel
# ---------------------------------------------------------------
Write-Host ''
Write-Host '[1/6] Correcciones de inventario y del panel' -ForegroundColor Green
git add 'main/src/stores/inventory.js'
git add 'main/src/components/admin/inventory/SaleInventory.vue'
git add 'main/src/components/admin/AdminPanel.vue'
git add 'main/src/components/admin/AdminDashboard.vue'
git add 'main/src/components/admin/AdminProductos.vue'
git add 'main/src/components/admin/AdminVariants.vue'
git add 'main/src/components/admin/AdminAddFilter.vue'
git add 'main/src/components/admin/AdminHistorial.vue'
git add 'main/src/components/admin/AdminPedidos.vue'
git add 'main/src/components/admin/CatalogSettings.vue'
git add 'main/src/views/ProductDetail.vue'
$msg = @'
fix(inventario): transferencias por tono y saldos desde la base

La transferencia de bodega a venta ignoraba el variantId, asi que una compra
registrada contra un tono se transferia como si fuera del producto base y los
saldos nunca cuadraban. El boton ademas comprobaba el valor de retorno de una
funcion asincrona como si fuera sincrona, de modo que el error nunca llegaba
a la pantalla.

Compras y transferencias mutaban una copia local mientras la base calculaba el
stock por movimientos: dos fuentes de verdad para el mismo numero. Ahora releen
desde la base al terminar.

- updateSalePrice actualizaba la columna price pero escribia salePrice en local
- el panel muestra los errores de carga en vez de tablas vacias
- la seccion Historial decia Entregados cuando lista devoluciones
- eliminado codigo legacy: addPurchaseOrderLegacy, addToSaleInventory y los
  helpers locales; inventory.js pasa de 41 KB a 24 KB

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01XyVXjVrfMwmDTmwta4odcA
'@
git commit -m $msg

# ---------------------------------------------------------------
# 2. Modelo de datos de tonos e imagenes
# ---------------------------------------------------------------
Write-Host ''
Write-Host '[2/6] Modelo de datos de tonos e imagenes' -ForegroundColor Green
git add 'main/supabase/migrations/007_shade_model.sql'
git add 'main/supabase/migrations/008_storage_imagenes.sql'
git add 'main/supabase/migrations/README.md'
$msg = @'
feat(db): modelo de tonos de maquillaje y almacenamiento de imagenes

product_variants pasa a ser una ficha de tono: swatch_hex para el chip, el
orden y los filtros; swatch_image_url para la verdad, porque un metalizado no
se representa con un color plano. Anade subtono, familia cromatica,
profundidad 1-100 para ordenar de clara a profunda, posicion y tono por
defecto.

El precio del tono admite NULL = hereda del producto, para que subir el precio
de una linea de 40 tonos sea una sola edicion.

product_images con variant_id opcional resuelve galeria y foto por tono en una
tabla. Bucket product-images con lectura publica y escritura solo admin.

Valida en base: hexadecimal CSS, profundidad en rango, un solo tono por
defecto y una sola imagen principal. Auditoria extendida a las tablas
maestras de catalogo.

Probado en PostgreSQL 16 local con el historico aplicado, incluidos los casos
de rechazo y la idempotencia.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01XyVXjVrfMwmDTmwta4odcA
'@
git commit -m $msg

# ---------------------------------------------------------------
# 3. Optimizador de imagenes
# ---------------------------------------------------------------
Write-Host ''
Write-Host '[3/6] Optimizador de imagenes' -ForegroundColor Green
git add 'main/src/lib/imageOptimizer.js'
git add 'main/src/lib/storage.js'
$msg = @'
feat(imagenes): compresion en el cliente antes de subir

El plan gratuito de Supabase da 1 GB. Una foto de movil sin tratar pesa entre
3 y 6 MB: doscientas fotos lo llenan.

Medido sobre las imagenes reales del proyecto:
  pexels.jpg  4.472 KB -> 256 KB  (-94%)
  banner      1.233 KB ->  82 KB  (-93%)
  logo PNG       21 KB ->   9 KB  (-56%, identico pixel a pixel)

Los swatches llevan perfil aparte. Medido en Delta-E CIEDE2000 sobre una carta
de 10 tonos: sin perdida da dE 0,00, mientras que WebP q=95 llega a dE 2,17 en
el interior de cada franja, perceptible lado a lado. En un swatch el color es
el dato, asi que el perfil prueba tambien PNG sin perdida y se queda con el
cuando pesa menos.

Respeta la orientacion EXIF, reduce por pasos para no perder nitidez, compara
siempre contra el original y borra el archivo si el registro en base falla.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01XyVXjVrfMwmDTmwta4odcA
'@
git commit -m $msg

# ---------------------------------------------------------------
# 4. Separacion de stores
# ---------------------------------------------------------------
Write-Host ''
Write-Host '[4/6] Separacion de stores' -ForegroundColor Green
git add 'main/src/stores/catalog.js'
$msg = @'
refactor(stores): extraer el catalogo de inventory.js

Productos, tonos y tablas maestras pasan a catalog.js. inventory.js se queda
solo con las existencias, que se derivan de inventory_movements.

Incluye el parser de tonos por lotes: acepta tabulaciones, comas, hexadecimal
con o sin almohadilla y nombres de varias palabras. Probado en 9 casos, entre
ellos subtono desconocido y profundidad fuera de rango, que antes se pegaban
en silencio al nombre del tono.

Los accesos antiguos siguen funcionando como delegaciones para no romper las
pantallas durante la migracion. El codigo nuevo debe usar useCatalogStore.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01XyVXjVrfMwmDTmwta4odcA
'@
git commit -m $msg

# ---------------------------------------------------------------
# 5. Editor de producto y vitrina con tonos
# ---------------------------------------------------------------
Write-Host ''
Write-Host '[5/6] Editor de producto y vitrina con tonos' -ForegroundColor Green
git add 'main/src/views/admin/ProductEditor.vue'
git add 'main/src/components/admin/product/'
git add 'main/src/components/products/ProductCard.vue'
git add 'main/src/views/Shop.vue'
git add 'main/src/router/index.js'
$msg = @'
feat(catalogo): editor de producto por secciones y tonos en la tienda

Editor a pagina completa en /admin/productos/:id con seis secciones. El
producto se guarda como borrador en cuanto tiene nombre, asi que tonos e
imagenes estan disponibles enseguida y nada se pierde a medias.

- creacion al vuelo de marca, categoria y atributos sin salir del formulario
- los atributos se muestran solo si aplican a la categoria
- editor de tonos con selector de color, pegado por lotes con vista previa de
  los chips, reordenacion y SKU automatico marca-producto-codigo
- subida real de imagenes con arrastrar y soltar

En la tienda: chips de color, la imagen cambia al elegir tono, stock por tono
con los agotados deshabilitados y filtros por subtono y familia. El agotado se
marca con una diagonal, no solo con opacidad.

Corrige que la ficha leyera variant.stock, columna legacy que ya no se carga:
mostraba undefined disponibles y nunca deshabilitaba los tonos agotados.
Las categorias de la tienda salen del catalogo real y no de mockData.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01XyVXjVrfMwmDTmwta4odcA
'@
git commit -m $msg

# ---------------------------------------------------------------
# 6. Documentacion
# ---------------------------------------------------------------
Write-Host ''
Write-Host '[6/6] Documentacion' -ForegroundColor Green
git add 'docs/refactor-modulo-productos.md'
git add 'HANDOFF.md'
git add 'CLAUDE.md'
git add 'git'
git add 'add'
git add -A
git add '#'
git add 'cualquier'
git add 'resto'
git add 'pendiente'
$msg = @'
docs: diseno del refactor de productos y estado del proyecto

Diseno completo del modulo con la investigacion de como modela tonos la
industria cosmetica, el plan en 8 etapas y las decisiones tomadas.

HANDOFF al dia: etapas 1 a 5 y 7 completas, y la revision critica de lo que
falta para que sea un panel profesional, incluida la trazabilidad regulatoria
que exige INVIMA (notificacion sanitaria, lote y fecha de vencimiento).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01XyVXjVrfMwmDTmwta4odcA
'@
git commit -m $msg

Write-Host ''
Write-Host 'Commits creados. Revisalos antes de publicar:' -ForegroundColor Cyan
git log --oneline -6
Write-Host ''
$p = Read-Host 'Hacer push a origin/dev? (s/n)'
if ($p -eq 's') { git push origin dev } else { Write-Host 'Sin publicar. Cuando quieras: git push origin dev' }