# =====================================================================
#  Strawberry Makeup - subir cambios a GitHub
#
#  Ejecutar en PowerShell desde C:\Users\Usuario\Documents\StrawBerry
#      .\subir-cambios.ps1
#
#  Que hace: agrupa todo lo que hay sin versionar en commits tematicos,
#  en el orden en que se construyo, y al final ofrece publicar.
#
#  Es seguro repetirlo. Cada bloque solo crea el commit si de verdad
#  quedo algo preparado, asi que si un archivo ya estaba subido el
#  bloque se salta solo y no aparece un commit vacio. Si se corta a la
#  mitad, se vuelve a ejecutar y sigue donde iba.
#
#  No publica nada sin preguntar. El push es la ultima pregunta.
# =====================================================================

# A proposito NO se usa $ErrorActionPreference = 'Stop'. En PowerShell 5.1
# cualquier cosa que git escriba en stderr -avisos de fin de linea, por
# ejemplo- se convierte en excepcion y aborta el script a mitad de camino,
# con parte de los commits hechos. Aqui se mira el codigo de salida de git,
# que es lo que de verdad dice si fallo.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$RAIZ = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RAIZ

$FIRMA = @'

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01XyVXjVrfMwmDTmwta4odcA
'@

$creados = 0
$saltados = 0

function Abortar($texto) {
  Write-Host ''
  Write-Host "ABORTADO: $texto" -ForegroundColor Red
  Write-Host 'Los commits que ya se crearon siguen ahi. Arregla el problema y vuelve a ejecutar.' -ForegroundColor Yellow
  exit 1
}

# Agrega solo lo que existe. Un archivo que ya no esta no es un error:
# puede que ese commit ya se hubiera hecho en una ejecucion anterior.
function Agregar([string[]] $rutas) {
  foreach ($ruta in $rutas) {
    if (Test-Path $ruta) {
      git add -- $ruta
      if ($LASTEXITCODE -ne 0) { Abortar "git add fallo en $ruta" }
    } else {
      Write-Host "    - no existe, se salta: $ruta" -ForegroundColor DarkGray
    }
  }
}

# Borra de verdad, no solo del indice. Si el archivo nunca estuvo en git,
# se borra del disco y ya.
function Borrar([string[]] $rutas) {
  foreach ($ruta in $rutas) {
    git ls-files --error-unmatch -- $ruta 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      git rm -q -f -- $ruta
      if ($LASTEXITCODE -ne 0) { Abortar "git rm fallo en $ruta" }
      Write-Host "    - eliminado: $ruta" -ForegroundColor DarkYellow
    } elseif (Test-Path $ruta) {
      Remove-Item -Force -- $ruta
      Write-Host "    - eliminado del disco (no estaba en git): $ruta" -ForegroundColor DarkYellow
    } else {
      Write-Host "    - ya no estaba: $ruta" -ForegroundColor DarkGray
    }
  }
}

# El commit solo se hace si hay algo preparado. Esto es lo que vuelve
# repetible el script.
function Confirmar([string] $mensaje) {
  git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) {
    Write-Host '    sin cambios que guardar, se salta' -ForegroundColor DarkGray
    $script:saltados++
    return
  }
  # El mensaje va por ARCHIVO, no con `-m`.
  #
  # PowerShell vuelve a partir en palabras cualquier argumento de un programa
  # externo que lleve comillas dobles dentro. El mensaje del bloque 2 cita
  # «duplicate key ... "ux_product_badges_slug"», y git recibia cada palabra
  # suelta como si fuera una ruta: «error: pathspec 'key' did not match any
  # file(s)». Con `-F` el texto no pasa nunca por la linea de comandos, asi que
  # da igual lo que lleve dentro: comillas, acentos, saltos de linea.
  #
  # UTF8 sin BOM: git lee el archivo tal cual, y un BOM al principio acabaria
  # como tres caracteres raros en la primera linea del commit.
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("commit-" + [guid]::NewGuid().ToString('N') + ".txt")
  [System.IO.File]::WriteAllText($tmp, $mensaje + $FIRMA, (New-Object System.Text.UTF8Encoding $false))
  git commit -F $tmp | Out-Null
  $codigoCommit = $LASTEXITCODE
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  if ($codigoCommit -ne 0) { Abortar 'git commit fallo' }
  $script:creados++
  Write-Host '    commit creado' -ForegroundColor Green
}

function Paso([string] $titulo) {
  Write-Host ''
  Write-Host "  $titulo" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------
#  Revision previa
# ---------------------------------------------------------------------
Write-Host ''
Write-Host '=== Strawberry Makeup - subir cambios ===' -ForegroundColor Magenta
Write-Host ''

git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Abortar "aqui no hay un repositorio git ($RAIZ)" }

$rama = (git rev-parse --abbrev-ref HEAD).Trim()
Write-Host "Rama actual: $rama"
Write-Host ''
Write-Host 'Cambios sin versionar:' -ForegroundColor Cyan
git status --short
Write-Host ''

# El .env tiene las llaves de Supabase. Deberia estar ignorado por
# .gitignore, pero si alguna vez aparece aqui, se para en seco: una llave
# publicada en GitHub hay que rotarla, no se puede "deshacer" con un commit.
$fuga = git status --short | Select-String -Pattern '(^|[\\/ ])\.env($|[^.])'
if ($fuga) {
  Write-Host 'PELIGRO: aparece un archivo .env entre los cambios.' -ForegroundColor Red
  Write-Host $fuga -ForegroundColor Red
  Write-Host 'Ese archivo lleva las llaves de Supabase. Revisa .gitignore antes de seguir.' -ForegroundColor Red
  exit 1
}

if (-not (git status --short)) {
  Write-Host 'No hay nada que versionar. Todo esta ya en commits.' -ForegroundColor Green
  exit 0
}

# ---------------------------------------------------------------------
#  Limpieza previa
#
#  Archivos que quedaron del trabajo anterior y hoy solo estorban. Va ANTES
#  de la verificacion a proposito: `pruebas-colecciones-panel.mjs` se fundio
#  con `pruebas-colecciones.mjs` y el que sobra rompe el lint, asi que si se
#  borrara mas abajo la verificacion abortaria sin llegar nunca a borrarlo.
# ---------------------------------------------------------------------
$sobrantes = @(
  'main/scripts/pruebas-colecciones-panel.mjs',
  'main/src/components/home/BrandRunway.vue',
  'main/src/components/admin/PasarelaMarcas.vue'
)
$hayQueLimpiar = $sobrantes | Where-Object { Test-Path (Join-Path $RAIZ $_) }
if ($hayQueLimpiar) {
  Write-Host ''
  Write-Host 'Quedan archivos que ya no usa nadie y que rompen la verificacion:' -ForegroundColor Yellow
  $hayQueLimpiar | ForEach-Object { Write-Host "    $_" }
  Borrar $hayQueLimpiar
  Write-Host 'Limpiado.' -ForegroundColor Green
}

# ---------------------------------------------------------------------
#  Verificacion antes de guardar
# ---------------------------------------------------------------------
Write-Host 'Antes de hacer commits conviene comprobar que el proyecto compila.' -ForegroundColor Yellow
Write-Host '  r = rapido   (lint + build, ~1 min)'
Write-Host '  c = completo (lint + build + humo + responsive, varios minutos)'
Write-Host '  n = ninguna'
$v = Read-Host 'Que verificacion corro? (r/c/n)'

if ($v -eq 'r' -or $v -eq 'c') {
  Push-Location (Join-Path $RAIZ 'main')
  if ($v -eq 'c') { npm run verify } else { npm run lint; if ($LASTEXITCODE -eq 0) { npm run build } }
  $codigo = $LASTEXITCODE
  Pop-Location
  if ($codigo -ne 0) { Abortar 'la verificacion fallo. No se hizo ningun commit.' }
  Write-Host ''
  Write-Host 'Verificacion OK.' -ForegroundColor Green
}

Write-Host ''
$r = Read-Host 'Continuar y crear los commits? (s/n)'
if ($r -ne 's') { Write-Host 'Cancelado. No se toco nada.'; exit }

# =====================================================================
#  1. Colecciones en el Home
# =====================================================================
Paso '[1/20] Colecciones en el Home'
# La cuadricula de categorias que ocupaba este sitio. Los archivos de la
# pasarela de marcas ya los quito la limpieza previa.
Borrar @('main/src/components/home/HomeCategories.vue')
Agregar @(
  'main/supabase/migrations/025_logos_de_marca.sql',
  'main/supabase/migrations/026_colecciones.sql',
  'main/supabase/migrations/027_retirar_pasarela_marcas.sql',
  'main/supabase/migrations/028_politicas_admin_solo_authenticated.sql',
  'main/src/stores/collections.js',
  'main/src/stores/settings.js',
  'main/src/stores/catalog.js',
  'main/src/lib/storage.js',
  'main/src/components/home/HomeCollections.vue',
  'main/src/components/home/CollectionRow.vue',
  'main/src/components/admin/AdminColecciones.vue',
  'main/src/components/admin/AdminConfiguracion.vue',
  'main/src/components/admin/AdminOfertas.vue',
  'main/src/components/admin/CatalogSettings.vue',
  'main/src/views/Home.vue',
  'main/src/views/Shop.vue',
  'main/src/views/admin/ProductEditor.vue',
  'main/scripts/pruebas-colecciones.mjs',
  'main/scripts/responsive.mjs'
)
Confirmar @'
feat(home): colecciones con carrusel de productos, en lugar de la cuadricula

«Encuentra lo tuyo» eran dieciseis categorias en cuadricula ocupando el final
de la portada: mucha superficie para una lista que la clienta ya tiene en el
menu y en los filtros de la tienda. Fuera.

En su sitio, las COLECCIONES. Una coleccion agrupa productos que se venden
juntos aunque no compartan categoria ni marca — «Coleccion Alisia» puede
llevar una base, dos labiales y un rubor —, y en la portada cada una es una
FILA: titulo, subtitulo, foto de cabecera opcional, enlace «Ver todo» y un
carrusel con sus productos.

Las tarjetas del carrusel son el MISMO `ProductCard.vue` que usa la tienda, con
su precio, su promocion, su etiqueta, su corazon y su boton. Una tarjeta
reducida «para el home» habria acabado mostrando un precio distinto del real,
que es justo el dato que no puede divergir: ya paso con el costo de envio.

El carrusel es scroll nativo (`overflow-x-auto` + `scroll-snap`), sin libreria
y sin `transform` calculado a mano. El dedo, el trackpad y el teclado ya saben
desplazarse; las flechas solo llaman a `scrollBy`, se desactivan en los
extremos, no se pintan si todo cabe en pantalla y van `aria-hidden` porque
duplican algo que el lector de pantalla ya puede hacer. En el movil la
siguiente tarjeta asoma, que es lo que invita a arrastrar.

Tres decisiones de fondo:

- **Un producto pertenece como mucho a una coleccion.** Es una columna
  (`products.collection_id`), no una tabla de cruce.
- **Borrar una coleccion NO borra sus productos.** `on delete set null` los
  deja sueltos. Lo contrario seria que retirar una campaña te vaciara el
  catalogo.
- **Sale en la portada la coleccion publicada CON al menos un producto.** Una
  fila con el titulo puesto y cero tarjetas se lee como una pagina rota, y ese
  es el estado normal mientras se monta la campaña. La foto de cabecera es
  opcional; el filtro de la tienda solo pide que este publicada.

El interruptor de la seccion entera vive en `store_settings`
(`homeCollectionsVisible`) y la apaga sin despublicar ninguna coleccion.

TAMAÑOS DE IMAGEN EN EL PANEL. Donde se sube una foto ahora dice cuanto debe
medir, porque sin ese dato se suben capturas verticales y la pieza las recorta
por el centro: banner de portada 1920x800, cabecera de coleccion 1600x500, y en
Ofertas segun el tipo de tarjeta (destacada 1200x700, ancha 1200x340, alta
600x700, pequeña 600x340).

De paso, un fallo viejo de la tienda: cada filtro escribia la URL entera, asi
que elegir una categoria te sacaba de «Ofertas». Ahora se conserva lo que ya
estuviera puesto.

Este bloque incluye tambien la PASARELA DE MARCAS que ocupo este sitio durante
una sesion y se retiro entera antes de publicarse. Se conservan las migraciones
025 y 027 porque la 025 SI llego a aplicarse en la base real y la 027 es la que
revierte sus columnas dejando respaldo en el esquema `respaldo`: borrar la 025
del repositorio dejaria el historico contando algo distinto de lo que la base
vivio. La 028 acota a `to authenticated` seis politicas de admin que se habian
quedado aplicando tambien a `anon`.

Verificado sobre el build de produccion con Supabase sembrado:
`scripts/pruebas-colecciones.mjs`, 37 comprobaciones entre tienda y panel — que
la portada solo pinte colecciones publicadas con productos, el orden por
posicion, que el carrusel lleve solo las tarjetas de esa coleccion y con su
precio, que las flechas desplacen y se desactiven en los extremos, que una fila
corta no las muestre, «Ver todo», el desplegable, que elegir coleccion no borre
la categoria de la URL, el interruptor, el alta sin `slug` (lo pone la base),
publicar, reordenar reescribiendo todas las posiciones, el aviso de cuantos
productos quedan sueltos al borrar, el tamaño recomendado escrito en el panel y
que el editor de producto mande `collection_id`. Mas lint, build, prueba de
humo y la auditoria responsive en seis anchos.
'@

# =====================================================================
#  2. El identificador de la etiqueta lo genera la base
# =====================================================================
Paso '[2/20] Correcciones de SQL: etiquetas y registro de compras'
Agregar @(
  'main/supabase/migrations/023_slug_etiqueta_en_la_base.sql',
  'main/supabase/migrations/024_compra_sin_delete_sin_where.sql',
  'main/src/stores/catalog.js',
  'main/src/components/admin/AdminEtiquetas.vue'
)
Confirmar @'
fix(sql): el slug lo genera la base, y ningun DML sin WHERE

Crear una etiqueta fallaba con "duplicate key value violates unique
constraint ux_product_badges_slug", que no le dice nada a quien solo queria
ponerle un nombre.

La 020 dejo el slug como not null con indice unico y lo calculaba el
frontend: lo sacaba del nombre, miraba su lista local de etiquetas y numeraba
los repetidos. Eso funciona solo mientras esa lista este completa y al dia, y
hay varias formas de que no lo este — la pantalla abierta antes de que
terminara de cargar el catalogo, otra pestana creando etiquetas, una carga
fallida en silencio. En todos esos casos el INSERT llega con un slug ya usado.

Es el mismo error de fondo que el costo de envio y el precio de los combos:
dos sitios calculando el mismo valor. La unicidad de una clave solo la puede
garantizar quien ve todas las filas, y ese es Postgres. Ahora el frontend
manda el nombre y ya; un trigger genera el slug y, si choca, numera. Dos
etiquetas llamadas NUEVO se quedan en nuevo y nuevo-2 en vez de fallar: son
raras pero no son un error del usuario, y perder lo escrito por un detalle
interno que nadie ve si lo seria.

El panel avisa —sin bloquear— cuando el nombre ya existe, porque dos
etiquetas que se leen igual en la tarjeta suele ser un despiste.

Y en la misma linea, la 024: registrar una compra fallaba con "DELETE
requires a WHERE clause". Supabase carga la extension `safeupdate` para los
roles anon y authenticated, que rechaza cualquier DELETE sin WHERE — y
`save_purchase_order` vaciaba dos tablas temporales asi. No salio al probar la
022 en local porque el editor SQL corre como postgres y no tiene esa
proteccion: una migracion se aplica sin quejarse y falla solo cuando la llama
la app. Ahora la funcion usa una sola tabla temporal creada ya llena con
`create table as`: sin delete, sin insert previo y con un paso menos.

Probado en Postgres local y en la base real: acentos, mayusculas, simbolos,
nombres solo de emoji y el mismo nombre tres veces seguidas.
'@

# =====================================================================
#  3. La tienda pintaba todo como agotado
# =====================================================================
Paso '[3/20] Correccion: existencias invisibles en la tienda'
Agregar @(
  'main/src/App.vue',
  'main/src/assets/styles/main.css',
  'main/src/views/Favorites.vue',
  'main/src/stores/inventory.js',
  'main/src/composables/useInventoryRows.js',
  'main/src/components/admin/inventory/SaleInventory.vue',
  'main/src/components/admin/inventory/Warehouse.vue',
  'main/src/components/admin/inventory/PurchaseOrders.vue',
  'main/src/views/admin/ProductEditor.vue',
  'main/scripts/responsive.mjs'
)
Confirmar @'
fix(tienda): los productos a la venta salian como agotados

Dos causas distintas del mismo sintoma, y ninguna daba error.

LA PRIMERA, de permisos. La tienda leia las existencias de la vista
`inventory_balances`, que esta declarada con `security_invoker = true`: al
consultarla se leen por debajo los `inventory_movements` con los permisos de
quien pregunta, y la unica politica de esa tabla es
`TO authenticated USING (is_admin())`. Una clienta anonima no cumple ninguna
de las dos cosas, asi que recibia CERO FILAS Y NINGUN ERROR — la trampa de
RLS que el propio CLAUDE.md ya documentaba. Resultado: `saleStock = 0` para
todo el catalogo y un «Agotado» en cada tarjeta, con la mercancia puesta a la
venta y sin un solo error en consola.

Ahora la tienda lee `inventory_sale_balances`, que es una tabla con lectura
publica mantenida por trigger a partir de los mismos movimientos. No es una
segunda fuente de verdad: es la misma cuenta, publicada. Lo que no trae —y no
debe— es la bodega. El panel sigue leyendo la vista completa.

LA SEGUNDA, de modelo. En un producto con tonos las unidades pertenecen a un
tono concreto: es lo que la clienta elige y lo que hay que sacar de la caja al
empacar. Unas unidades registradas contra el "producto base" no pertenecen a
ninguno, asi que la tienda —que suma tono a tono— no las cuenta, y el producto
sale agotado teniendolas en la vitrina. Compras ya no deja registrar una linea
sin tono cuando el producto tiene tonos, y Bodega y Listo para vender avisan
de las partidas que quedaron asi, diciendo cuantas son y como arreglarlas.

De paso, el editor de producto pide los saldos completos: para distinguir "no
lo has comprado" de "lo tienes en bodega" hay que poder ver la bodega, y su
ruta no monta el panel.

Y el pie, pegado abajo. `#app` medía lo que midieran sus hijos, asi que en una
pagina corta —favoritos con un producto, terminos, una busqueda sin
resultados— el pie negro quedaba a media pantalla y debajo se veia una franja
blanca hasta el final de la ventana. Ahora `#app` es una columna de alto
minimo `100dvh` con el bloque de la vista estirado: el pie cae al fondo cuando
sobra sitio y baja cuando falta. Es layout de la aplicacion entera, no de una
pagina, asi que vive en main.css y no en cada vista — el `min-h` que se habia
puesto en Favoritos era un parche y se retira. `dvh` y no `vh` por el movil:
`vh` cuenta la ventana con la barra del navegador escondida.
'@

# =====================================================================
#  4. Base de datos
# =====================================================================
Paso '[4/20] Migraciones 013 a 019'
Agregar @(
  'main/supabase/migrations/013_venta_fisica_atomica.sql',
  'main/supabase/migrations/014_configuracion_y_banners.sql',
  'main/supabase/migrations/015_mensajes_contacto.sql',
  'main/supabase/migrations/016_combos_2x1.sql',
  'main/supabase/migrations/017_trazabilidad_producto.sql',
  'main/supabase/migrations/018_retirar_legacy.sql',
  'main/supabase/migrations/019_ofertas_portada.sql',
  'main/supabase/migrations/README.md'
)
Confirmar @'
feat(db): venta fisica, configuracion, combos, trazabilidad y ofertas

Siete migraciones que cierran lo que faltaba del modelo:

013 venta fisica atomica. La venta en mostrador descontaba stock con un
    select y luego un insert: dos clientes vendiendo la ultima unidad a la
    vez la vendian los dos. Ahora es una funcion con pg_advisory_xact_lock
    por producto, asi que la segunda espera y se rechaza con stock cero.

014 configuracion del sitio y banners editables desde el panel, en vez de
    constantes escritas en el codigo.

015 mensajes de contacto. El formulario publico escribe aqui; solo el
    admin lee.

016 combos y promociones 2x1, con el precio calculado en el servidor
    (descuentos_combos). El cliente nunca manda un precio.

017 trazabilidad del producto: de que compra vino cada unidad.

018 retira lo legacy. products.image y product_variants.stock eran
    columnas que ya nadie escribia pero que seguian ahi para confundir:
    el stock sale de inventory_movements y las fotos de product_images.
    Antes de borrarlas las copia al esquema respaldo.

019 home_offers, la seccion de ofertas de la portada. Tamanos con nombre,
    borrador contra publicado, y el destino del enlace validado por CHECK.

Todas con RLS: lectura publica solo de lo publicado, escritura solo admin.
'@

# =====================================================================
#  2. Punto de venta
# =====================================================================
Paso '[5/20] Venta fisica y pedidos'
Agregar @(
  'main/src/components/admin/inventory/SalesRegister.vue',
  'main/src/components/admin/inventory/MovementHistory.vue',
  'main/src/components/admin/AdminPedidos.vue',
  'main/src/stores/orders.js',
  'main/src/utils/orderStatus.js',
  'main/src/lib/storage.js'
)
Confirmar @'
feat(pos): venta en mostrador contra la base, no contra la pantalla

El registro de venta fisica armaba el pedido en memoria y confiaba en que
el stock que tenia a la vista siguiera ahi. Ahora llama a la funcion
atomica de la 013: la base decide si hay unidades y devuelve el error si
no las hay, y el mensaje de "venta registrada" solo aparece despues de que
la base confirmo.

- el historial de movimientos muestra de donde salio cada unidad
- comprobantes de pago subidos a Storage, con la ruta guardada en el pedido
- los estados del pedido viven en un solo sitio (orderStatus.js) en vez de
  estar escritos a mano en cada pantalla
'@

# =====================================================================
#  3. Promociones
# =====================================================================
Paso '[6/20] Promociones y combos'
Agregar @(
  'main/src/stores/promotions.js',
  'main/src/components/admin/AdminPromociones.vue',
  'main/src/views/Cart.vue'
)
Confirmar @'
feat(promos): combos y descuentos calculados en el servidor

El carrito mostraba el precio con descuento que calculaba el navegador y
lo mandaba en el pedido. Cualquiera podia cambiarlo. Ahora el carrito solo
manda producto y cantidad; el precio y el descuento los calcula la base
(precio_efectivo y descuentos_combos) y lo que muestra el carrito es una
vista previa de eso mismo.

Panel para crear combos 2x1 y promociones por producto o por categoria,
con vigencia por fechas.
'@

# =====================================================================
#  4. Configuracion y contacto
# =====================================================================
Paso '[7/20] Configuracion del sitio y mensajes'
Agregar @(
  'main/src/stores/settings.js',
  'main/src/stores/contact.js',
  'main/src/stores/admin.js',
  'main/src/components/admin/AdminConfiguracion.vue',
  'main/src/components/admin/AdminMensajes.vue',
  'main/src/components/layout/Footer.vue',
  'main/src/components/layout/Header.vue',
  'main/src/components/cart/CartDrawer.vue',
  'main/src/router/index.js',
  'main/src/App.vue',
  'main/vite.config.js'
)
Confirmar @'
feat(config): datos del sitio editables y bandeja de mensajes

La pantalla de Configuracion escribia en localStorage: se veia guardado en
ese navegador y no lo estaba en ningun lado. Ahora escribe en la tabla de
configuracion y la pagina publica lee de ahi, asi que el WhatsApp, el
horario y las redes se cambian sin tocar codigo.

Los mensajes del formulario de contacto quedan en una bandeja del panel,
con marca de leido. Antes el formulario decia "enviado" sin guardar nada.
'@

# =====================================================================
#  5. Ofertas de portada
# =====================================================================
Paso '[8/20] Seccion de ofertas de la portada'
Agregar @(
  'main/src/stores/offers.js',
  'main/src/components/admin/AdminOfertas.vue',
  'main/src/components/home/OffersGrid.vue',
  'main/src/components/home/HomeAds.vue',
  'main/src/components/home/HomeCategories.vue',
  'main/src/components/home/Hero.vue',
  'main/src/components/products/ProductCard.vue',
  'main/src/views/Shop.vue',
  'main/src/views/About.vue',
  'main/src/lib/imageOptimizer.js'
)
Confirmar @'
feat(ofertas): seccion de ofertas editable, con vista previa real

La portada tenia las ofertas escritas en el HTML. Ahora salen de
home_offers y se editan desde el panel: tamano por nombre (destacada,
ancha, alta, pequena), borrador o publicada, y el destino del enlace.

La vista previa del panel monta el MISMO componente que la tienda
(OffersGrid.vue), no una imitacion: lo que se ve editando es exactamente
lo que ve el cliente. La rejilla usa grid-flow-dense, asi que el store
incluye el calculo de los huecos para avisar cuando una combinacion de
tamanos deja un espacio vacio.

Las imagenes se convierten a WebP antes de subir.
'@

# =====================================================================
#  6. Inventario
# =====================================================================
Paso '[9/20] Inventario: partir el store y reordenar las paradas'
Borrar @('main/src/components/admin/inventory/PurchaseInventory.vue')
Agregar @(
  'main/src/stores/inventory.js',
  'main/src/stores/suppliers.js',
  'main/src/stores/purchases.js',
  'main/src/stores/pos.js',
  'main/src/composables/useInventoryRows.js',
  'main/src/components/admin/inventory/InventorySection.vue',
  'main/src/components/admin/inventory/Warehouse.vue',
  'main/src/components/admin/inventory/ProductoEnBodega.vue',
  'main/src/components/admin/inventory/SaleInventory.vue',
  'main/src/components/admin/inventory/PurchaseOrders.vue',
  'main/src/components/admin/inventory/Suppliers.vue',
  'main/src/components/admin/AdminPanel.vue',
  'main/src/components/admin/AdminDashboard.vue'
)
Confirmar @'
refactor(inventario): tres paradas en el orden del flujo real

Inventario tenia tres pestanas y una sobraba. "Inventario de Compras" no
era un inventario: era el catalogo completo otra vez, con un creador
recortado a tres campos que paria productos sin precio, sin marca, sin
tonos y sin fotos, y con un boton de archivar que no pedia confirmacion.
Se elimina; los productos se crean en un solo sitio, Productos.

La bodega, en cambio, no tenia pantalla: vivia como una rejilla al final
de "Inventario de Venta", que es el paso siguiente. Ahora es una parada
propia con su ficha de producto, donde se ve la nota de la compra de la
que vino cada unidad.

Las pestanas quedan numeradas y en el orden del recorrido:
  1 Compras -> 2 Bodega -> 3 Listo para vender

Y inventory.js, que eran 41 KB con proveedores, compras, punto de venta y
saldos mezclados, se parte en suppliers.js, purchases.js y pos.js. El
armado de filas, que estaba duplicado en Bodega y en Venta, sale a
useInventoryRows.js.
'@

# =====================================================================
#  7. Productos
# =====================================================================
Paso '[10/20] Creacion de productos y galeria'
Agregar @(
  'main/src/views/admin/ProductEditor.vue',
  'main/src/components/admin/product/QuickCreate.vue',
  'main/src/components/admin/product/ShadeEditor.vue',
  'main/src/components/admin/product/ImageUploader.vue',
  'main/src/components/admin/product/Trazabilidad.vue',
  'main/src/components/admin/AdminProductos.vue',
  'main/src/components/admin/CatalogSettings.vue',
  'main/src/stores/catalog.js'
)
Confirmar @'
fix(productos): guardar solo al pasar de seccion y galeria navegable

Las pestanas de Tonos, Imagenes y Trazabilidad necesitan un producto ya
creado, asi que estaban bloqueadas hasta guardar; pero nada lo decia, y
quien llegaba ahi creia que la pantalla estaba rota. Ahora al pulsarlas se
guarda solo y se entra. Si el guardado no devuelve un id, no se avanza: es
justo el caso en el que antes se creaba un producto por cada clic.

La galeria del producto no era navegable: las miniaturas eran imagenes
sueltas, no botones, asi que el cliente veia que habia mas fotos y no
podia abrirlas.
'@

# =====================================================================
#  8. Tienda
# =====================================================================
Paso '[11/20] Detalle de producto y rebote vertical'
Agregar @(
  'main/src/views/ProductDetail.vue',
  'main/src/assets/styles/main.css'
)
Confirmar @'
fix(tienda): recuadro de foto fijo y sin rebote vertical

El recuadro de la foto no tenia alto propio: lo ponia la imagen. Una foto
vertical lo estiraba, una horizontal lo encogia, y al cambiar de miniatura
la pagina daba un salto. Ahora es un cuadrado fijo y la foto se acomoda
dentro con object-contain, completa y sin deformar.

Y al empujar el scroll mas alla del final se veia una franja blanca: el
navegador separa la pagina y deja ver el fondo del documento, que era
blanco, mientras el pie es negro. Cabecera y pie tienen colores distintos,
asi que ningun fondo unico los contenta a los dos; lo que se quita es el
rebote, con overscroll-behavior-y: none. De paso, el scroll ya no se
encadena al fondo cuando se llega al final de un modal o del carrito.
'@

# =====================================================================
#  9. Contacto
# =====================================================================
Paso '[12/20] Pagina de contacto y plan emprendedor'
Agregar @('main/src/views/Contact.vue')
Confirmar @'
feat(contacto): ventajas de comprar y plan emprendedor

Contacto era un formulario y poco mas. Ahora explica por que comprar aqui
y abre la puerta al plan emprendedor, para quien quiera empezar a revender.

Sin cifras ni porcentajes inventados: las condiciones se hablan por
WhatsApp, y cada boton abre el chat con el mensaje ya escrito segun de
donde se pulse. El numero sale de la configuracion del sitio y se limpia
antes de armar el enlace, porque wa.me no admite espacios ni el signo mas.

El formulario sigue siendo el de verdad: escribe en contact_messages y
solo dice "recibido" cuando la base lo confirma.
'@

# =====================================================================
#  10. Calidad y documentacion
# =====================================================================
Paso '[13/20] Lint, pruebas y documentacion'
Agregar @(
  'main/eslint.config.js',
  'main/package.json',
  'main/package-lock.json',
  'main/.gitignore',
  'main/scripts/smoke.mjs',
  'main/scripts/responsive.mjs',
  '.github/workflows/verificar.yml',
  'CLAUDE.md',
  'HANDOFF.md',
  'PRUEBAS.md',
  'docs',
  'subir-cambios.ps1'
)
Confirmar @'
chore(calidad): eslint, pruebas de humo, auditoria responsive y docs

npm run verify encadena lint, build, humo y responsive.

El humo levanta la build real en Playwright con las respuestas de Supabase
simuladas y recorre las pantallas: comprueba que cargan, que no hay errores
de consola y que el panel se puede abrir con una sesion sembrada.

La auditoria de responsive revisa 7 paginas en 6 anchos y reporta desborde
horizontal, zonas pulsables de menos de 40 px y texto de menos de 12 px.

Las reglas de formato de eslint estan apagadas a proposito: el formateo lo
hace prettier y tenerlo en los dos sitios solo produce peleas. En el
archivo queda anotado por que se descarto require-atomic-updates (trece
falsos positivos, todos patrones correctos de Vue).

PRUEBAS.md es el plan de pruebas manual, ordenado por el flujo real del
negocio, con el aviso de usar un proyecto de Supabase aparte para no
ensuciar los datos de produccion.
'@

# =====================================================================
#  11. Favoritos y etiquetas
# =====================================================================
Paso '[14/20] Favoritos de la clienta y etiquetas de producto'
Agregar @(
  'main/supabase/migrations/020_etiquetas_producto.sql',
  'main/src/stores/favorites.js',
  'main/src/views/Favorites.vue',
  'main/src/components/admin/AdminEtiquetas.vue',
  'main/src/components/layout/Header.vue',
  'main/src/components/products/ProductCard.vue',
  'main/src/views/ProductDetail.vue',
  'main/src/router/index.js'
)
Confirmar @'
feat(tienda): favoritos y etiquetas editables en la tarjeta

Dos cosas que la tarjeta pedia y no tenia.

FAVORITOS. Corazon en la tarjeta y en la ficha, contador junto al carrito y
pagina /favoritos con quitar y pasar al carrito. Se guardan en el navegador,
como el carrito: la tienda no tiene cuentas de cliente y no las va a tener.
La lista guarda solo identificadores, asi que el precio y la foto se resuelven
al pintar y un producto retirado desaparece en vez de quedarse con datos
viejos. El corazon va FUERA del enlace de la foto: dentro, cada pulsacion
seria tambien una navegacion.

ETIQUETAS. Eran tres casillas fijas —Destacado, Nuevo, Recomendado— con dos
problemas: no se podia crear una cuarta sin tocar codigo, y ninguna de las
tres se veia en la tienda. Se marcaban y no pasaba nada. Ahora son filas de
`product_badges` con su color, se crean y se editan desde el panel, y se
pintan sobre la foto. Los tres booleanos se migran a etiquetas, se respaldan
en el esquema respaldo y se sueltan.

Una etiqueta es escaparate: NO cambia el precio. Una que diga 2x1 lo anuncia;
el descuento lo sigue cobrando el servidor desde promotions.
'@

# =====================================================================
#  12. Publicar exige stock, y el inventario es un solo recorrido
# =====================================================================
Paso '[15/20] Regla de publicacion y los cuatro pasos de inventario'
Agregar @(
  'main/supabase/migrations/021_publicar_con_stock.sql',
  'main/src/components/admin/AyudaInfo.vue',
  'main/src/components/admin/AdminPanel.vue',
  'main/src/components/admin/inventory/InventorySection.vue',
  'main/src/views/admin/ProductEditor.vue',
  'main/src/stores/catalog.js',
  'main/src/stores/inventory.js'
)
Confirmar @'
feat(panel): no se publica un producto sin unidades en la vitrina

El estado del producto y sus existencias no se hablaban: se podia crear un
producto, ponerlo en activo y quedaba en la tienda sin haberle comprado una
sola unidad al proveedor. La clienta lo veia, lo metia al carrito y el pedido
se rechazaba por falta de stock.

La regla vive en la base (trigger de la migracion 021), no en un boton
deshabilitado: un `disabled` se salta desde otra pantalla o desde la API, y
este proyecto ya tiene cuatro casos de "la pantalla decia una cosa y la base
otra". Solo se comprueba AL PUBLICAR: un producto activo que se agota se
sigue pudiendo editar, porque agotarse es normal y la tienda ya lo muestra.
El error dice que falta: no es lo mismo "nunca lo has comprado" que "lo
tienes en bodega y falta pasarlo a la vitrina".

Y el recorrido se lee entero por fin. Productos era una seccion aparte del
menu, asi que crear un producto y meterlo en inventario parecian dos tareas
distintas cuando son la misma, en orden. Ahora Inventario es:

  1 Productos -> 2 Compras -> 3 Bodega -> 4 Listo para vender

con flechas de siguiente y anterior, tambien en el editor de producto.

Cada paso y cada campo tiene un boton de info que dice que hace y, sobre
todo, DONDE SE VE: era el dato que faltaba para entender el panel.
'@

# =====================================================================
#  13. Corregir una compra
# =====================================================================
Paso '[16/20] Corregir compras al proveedor'
Agregar @(
  'main/supabase/migrations/022_editar_compra.sql',
  'main/src/stores/purchases.js',
  'main/src/components/admin/inventory/PurchaseOrders.vue',
  'main/scripts/smoke.mjs',
  'main/scripts/responsive.mjs'
)
Confirmar @'
feat(compras): una compra se puede corregir, y varias lineas caben en una

Registrar una compra era un camino de ida: un cero de mas en la cantidad
quedaba para siempre, y con el, el costo promedio del que sale el margen de
Reportes. Y el registro tampoco era atomico — tres INSERT seguidos desde el
navegador, con mensajes de error que explicaban como arreglarlo a mano, que
es la señal de que hacia falta una transaccion.

Ahora `save_purchase_order` crea y corrige en una sola llamada. La correccion
NO borra historial: escribe una compra negativa que anula la entrada anterior
y vuelve a meter la cantidad correcta, asi que el historial cuenta lo que
paso de verdad. Se anula con `purchase` negativo y no con `adjustment` porque
un ajuste no cuenta para el costo promedio: anular con ajustes dejaria la
media calculada sobre unidades que nunca se compraron.

No se puede bajar una compra por debajo de lo que ya salio de bodega a la
vitrina — esas unidades ya se pueden haber vendido. La base lo rechaza y dice
cual es la cantidad minima posible.

Ademas, una compra ya admite varias lineas: una factura del proveedor con
ocho productos eran ocho ordenes distintas.
'@

# =====================================================================
#  17. Las tarjetas de portada ensenan solo la imagen
# =====================================================================
Paso '[17/20] Ofertas y banner: solo la imagen'
Agregar @(
  'main/src/components/home/OffersGrid.vue',
  'main/src/components/admin/AdminOfertas.vue'
)
Confirmar @'
feat(portada): las tarjetas de ofertas y el banner ensenan solo la imagen

El texto de una promocion va dentro del volante que se diseña aparte, con su
tipografia y su color. Escribirlo ademas en la pagina, superpuesto, era tener
dos textos que mantener iguales — y ninguno de los dos quedaba bien encima del
otro: el titulo web tapaba justo la parte que importaba de la foto.

Fuera de las tarjetas de Ofertas: etiqueta, titulo, subtitulo, «Ver mas» y el
velo oscuro, que existia unicamente para que ese texto se leyera. Lo que la
tarjeta conserva es **a donde lleva**, que es lo unico que la pagina tiene que
aportar.

Consecuencia: una tarjeta sin imagen ya no tiene nada que enseñar, asi que en
la tienda no se pinta. En la vista previa del panel si sale, marcada «falta la
imagen», para poder arreglarla antes de publicar.

En el panel, «Titulo» pasa a ser **Nombre (solo para ti)** y se retiran los
controles que dejaron de hacer algo: subtitulo, etiqueta, paletas de color,
oscurecido y color de texto. Las columnas siguen en la base con su valor por
defecto — no se sueltan en una migracion por un cambio de diseño; si en un
tiempo siguen sin usarse, entonces si.

TAMAÑOS DE IMAGEN, escritos donde se sube cada una. Sin ese dato se suben
capturas verticales y la pieza las recorta por el centro: destacada 1200x700,
ancha 1200x340, alta 600x700, pequeña 600x340.
'@

# =====================================================================
#  18. Tipografia e iconos
# =====================================================================
Paso '[18/20] Tipografia Poppins e iconos de garantias'
Agregar @(
  'main/index.html',
  'main/src/assets/styles/variables.css',
  'main/src/assets/styles/main.css',
  'main/src/assets/icons/camion-envio.svg',
  'main/src/assets/icons/estrella-premium.svg',
  'main/src/assets/icons/capas-mayoreo.svg',
  'main/src/components/home/HomeText.vue'
)
Confirmar @'
feat(diseño): Poppins en toda la tienda y tira de garantias con iconos

`--font-primary` decia `'Roboto'` pero Roboto no se cargaba en ninguna parte:
la tienda venia renderizando con la fuente por defecto del sistema, distinta en
cada equipo. Ahora hay una decision tipografica de verdad — Poppins, con
`preconnect` y `display=swap`, y la pila del sistema de reserva por si Google
Fonts no responde.

Se probo Fraunces (serif) para los titulares y se descarto: en mayusculas y con
peso alto, que es como estan escritos casi todos aqui, se lee mas pesada que
elegante.

LA TIRA DE GARANTIAS. Eran tres bloques con un emoji gigante, un titular en
mayusculas y un parrafo de cuatro lineas: doce lineas entre el banner y las
ofertas que nadie lee. Ahora son tres circulos rosas con su icono y dos
palabras — envio, calidad, mayoreo—, que es lo que se entiende de un vistazo.

Los SVG van en linea (`?raw` + `v-html`) y no como `<img>`: un `<img>` no se
puede recolorear desde CSS y estos tienen que tomar el rosa de la marca. A cada
uno se le quitaron 8 KB de metadatos C2PA — el dibujo ocupa 300 bytes — y su
`stroke` fijo pasa a `currentColor`.
'@

# =====================================================================
#  19. El banner se desliza
# =====================================================================
Paso '[19/20] El banner de la portada se desliza al cambiar'
Agregar @('main/src/components/home/Hero.vue')
Confirmar @'
fix(portada): el banner se desliza al cambiar, en vez de parpadear

Se cambiaba el `src` de una sola imagen, asi que al pasar de un banner a otro
habia un fogonazo mientras cargaba el siguiente. Ahora estan todos en una tira,
uno al lado del otro, y lo que se mueve es la tira entera con `translateX`.

Se anima `transform` y no `left` a proposito: es lo unico que el navegador
puede mover sin recalcular el diseño de la pagina, asi que va fluido tambien en
un celular de gama baja. Con `prefers-reduced-motion` el banner cambia sin
recorrido.

El banner entero es el enlace, y las flechas y los puntos van por encima
(`z-10`): pasar de un banner a otro no navega. Las flechas y los puntos solo se
pintan si hay mas de un banner.
'@

# =====================================================================
#  20. Sobre nosotros
# =====================================================================
Paso '[20/20] Sobre nosotros: el panel rosa descuadrado'
Agregar @('main/src/components/home/HomeHistory.vue')
Confirmar @'
fix(portada): el panel rosa de «Sobre nosotros» se descuadraba en pantalla ancha

El bloque rosa era `absolute inset-y-0 right-0 w-[32%]`: se colocaba contra el
borde de la VENTANA, mientras la foto vivia dentro de un contenedor centrado de
1280 px. En cuanto la pantalla pasaba de ese ancho los dos dejaban de tocarse y
el rosa quedaba flotando a la derecha, separado de todo, como si la seccion se
hubiera roto. Ahora el fondo es hermano de la foto dentro de la misma rejilla:
se mueven juntos mida lo que mida la pantalla.

Segundo fallo, del mismo sitio: «¡Visita nuestros productos!» era un `<button>`
sin `@click`. La clienta lo pulsaba y no pasaba nada. Es un enlace a la tienda.

De paso, la seccion se rehizo: titulo mas corto, tres cifras que responden lo
que la clienta se pregunta antes de escribir por WhatsApp (originales, tiempo
de respuesta, cobertura de envio), y la foto recortada a alto fijo — el
original es vertical y estiraba la seccion a casi mil pixeles, una pantalla
entera para un parrafo de tres lineas. Fuera tambien la `drop-shadow` rosa
desenfocada del titular, que sobre texto se lee como un error de impresion.
'@

# =====================================================================
#  Extra: archivos muertos (se pregunta aparte)
# =====================================================================
$muertos = @(
  'main/src/components/admin/AdminVariants.vue',
  'main/src/components/admin/AdminFilter.vue',
  'main/src/components/admin/AdminAddFilter.vue',
  'main/src/data/mockData.js'
)
$existen = $muertos | Where-Object { Test-Path $_ }
if ($existen) {
  Write-Host ''
  Write-Host 'Quedan archivos que ya no importa nadie:' -ForegroundColor Yellow
  $existen | ForEach-Object { Write-Host "    $_" }
  Write-Host 'AdminVariants y AdminFilter los reemplazo el editor de tonos; mockData eran'
  Write-Host 'los datos de mentira de antes de conectar Supabase. Nada los importa hoy.'
  $b = Read-Host 'Borrarlos en un commit aparte? (s/n)'
  if ($b -eq 's') {
    Borrar $muertos
    Confirmar @'
chore: eliminar componentes y datos de mentira que ya no usa nadie

AdminVariants y AdminFilter los reemplazo el editor de tonos; AdminAddFilter
era su formulario. mockData.js eran los datos falsos de antes de conectar
Supabase. Ningun archivo los importa: quedaban como ruido y como trampa,
porque parecian la pantalla vigente al buscar por nombre.
'@
  }
}

# =====================================================================
#  Lo que haya quedado suelto
# =====================================================================
$resto = git status --short
if ($resto) {
  Write-Host ''
  Write-Host 'Quedo esto sin versionar:' -ForegroundColor Yellow
  git status --short
  $x = Read-Host 'Meterlo todo en un commit final? (s/n)'
  if ($x -eq 's') {
    git add -A
    Confirmar @'
chore: resto de cambios de la sesion

Archivos que no entraron en ninguno de los bloques anteriores.
'@
  }
}

# =====================================================================
#  Resumen y publicacion
# =====================================================================
Write-Host ''
Write-Host "Commits creados: $creados   ·   bloques sin cambios: $saltados" -ForegroundColor Magenta
if ($creados -eq 0) {
  Write-Host 'No habia nada nuevo que guardar.' -ForegroundColor Green
  exit 0
}
Write-Host ''
Write-Host 'Revisalos antes de publicar:' -ForegroundColor Cyan
git log --oneline -n ($creados + 2)
Write-Host ''
Write-Host "Se publicaria en: origin/$rama" -ForegroundColor Cyan
$p = Read-Host 'Hacer push? (s/n)'
if ($p -eq 's') {
  git push origin $rama
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'El push fallo. Los commits estan hechos; cuando lo arregles:' -ForegroundColor Red
    Write-Host "    git push origin $rama" -ForegroundColor Red
    exit 1
  }
  Write-Host 'Publicado.' -ForegroundColor Green
} else {
  Write-Host "Sin publicar. Cuando quieras:  git push origin $rama"
}
