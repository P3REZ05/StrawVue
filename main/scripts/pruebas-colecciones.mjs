/**
 * Prueba de COLECCIONES contra el build de producción.
 *
 * Corre sobre `dist/` servido por `vite preview`, con Supabase interceptado y
 * sembrado: se prueba el código que se despliega, sin credenciales y sin tocar
 * la base real.
 *
 * Dos partes en un solo archivo porque comparten el intercept y los datos —
 * tenerlo en dos duplicaba sesenta líneas que luego hay que cambiar a la vez.
 *
 * TIENDA
 *   1. La portada pinta una fila por colección publicada CON productos, y solo
 *      las tarjetas de esa colección, con su precio.
 *   2. Las filas van en el orden de `position`; la colección sin productos no
 *      aparece, ni la que está sin publicar.
 *   3. Las flechas desplazan el carrusel y se desactivan en los extremos.
 *   4. «Ver todo» abre la tienda filtrada, y el desplegable de Colecciones
 *      filtra y actualiza la URL sin borrar la categoría que ya estaba.
 *   5. `homeCollectionsVisible = 'false'` esconde la sección y no rompe la tienda.
 *
 * PANEL
 *   6. El módulo está en Configuración y dice por qué una colección no sale.
 *   7. Crear manda un INSERT **sin `slug`** (lo pone la base, migración 026).
 *   8. Publicar, reordenar (reescribiendo TODAS las posiciones) y el aviso de
 *      cuántos productos quedan sueltos al borrar.
 *   9. El editor de producto guarda `collection_id`.
 *
 * Uso:
 *   npm run build
 *   SMOKE_CHROMIUM=/ruta/al/chrome node scripts/pruebas-colecciones.mjs
 */
import { chromium } from 'playwright'
import { preview } from 'vite'

const PUERTO = Number(process.env.SMOKE_PORT || 4188)
const BASE = `http://127.0.0.1:${PUERTO}`
const REF = 'gjchbbvqoigvhildddfw'

const COLECCIONES = [
  { id: 1, name: 'Alisia', slug: 'alisia', description: 'Todo lo que usa Alisia', image_url: 'https://ejemplo.test/a.webp', image_path: 'colecciones/a.webp', position: 2, published: true },
  { id: 2, name: 'Navidad', slug: 'navidad', description: '', image_url: null, image_path: null, position: 1, published: true },
  // Publicada pero SIN productos: sale en el desplegable de la tienda, no en
  // la portada — una fila con título y cero tarjetas se lee como algo roto.
  { id: 3, name: 'Vacia', slug: 'vacia', description: '', image_url: null, image_path: null, position: 3, published: true },
  // Sin publicar: no sale en ninguno de los dos sitios.
  { id: 4, name: 'Borrador', slug: 'borrador', description: '', image_url: null, image_path: null, position: 4, published: false }
]

const PRODUCTOS = [
  { id: 1, name: 'Base Alisia', category: 'Bases', collection_id: 1, price: 50000 },
  { id: 2, name: 'Labial Alisia', category: 'Labios', collection_id: 1, price: 30000 },
  { id: 3, name: 'Rubor Alisia', category: 'Rubores', collection_id: 1, price: 45000 },
  { id: 4, name: 'Polvo Alisia', category: 'Polvos', collection_id: 1, price: 38000 },
  { id: 5, name: 'Sombra Alisia', category: 'Ojos', collection_id: 1, price: 27000 },
  { id: 6, name: 'Gorro Navidad', category: 'Ojos', collection_id: 2, price: 40000 },
  { id: 7, name: 'Mascara suelta', category: 'Ojos', collection_id: null, price: 20000 }
].map((p) => ({
  description: '', category_id: null, subcategory_id: null, brand_id: null,
  skin_type_id: null, finish_id: null, coverage_id: null, net_content_ml: null,
  barcode: null, sale_price: null, status: 'active', active: true,
  updated_at: '2026-01-01T00:00:00Z', ...p
}))

// Todos con existencias: si no, la tienda los pinta agotados y el recuento
// mediría otra cosa.
const SALDOS = PRODUCTOS.map((p) => ({ product_id: p.id, variant_id: null, sale_stock: 10 }))

const CATEGORIAS = ['Bases', 'Labios', 'Rubores', 'Polvos', 'Ojos']
  .map((name, i) => ({ id: 10 + i, name, parent_id: null, image: null, active: true }))

let seccionEncendida = true
const escrituras = []

function datosDe(tabla) {
  switch (tabla) {
    case 'collections': return COLECCIONES
    case 'products': return PRODUCTOS
    case 'categories': return CATEGORIAS
    case 'inventory_sale_balances': return SALDOS
    case 'admin_profiles': return [{ id: '00000000-0000-0000-0000-000000000001', role: 'admin', active: true }]
    case 'store_settings': return [
      { key: 'whatsappNumber', value: '573000000000' },
      { key: 'homeCollectionsVisible', value: seccionEncendida ? 'true' : 'false' }
    ]
    default: return []
  }
}

const servidor = await preview({ preview: { port: PUERTO, host: '127.0.0.1' } })
const navegador = await chromium.launch(
  process.env.SMOKE_CHROMIUM ? { executablePath: process.env.SMOKE_CHROMIUM } : {}
)
const contexto = await navegador.newContext({ viewport: { width: 1280, height: 900 } })

// Sesión de administradora, con la misma clave que usa supabase-js. No es una
// credencial real: las respuestas están interceptadas, no llega a ninguna parte.
await contexto.addInitScript(([ref]) => {
  globalThis.localStorage.setItem(`sb-${ref}-auth-token`, JSON.stringify({
    access_token: 'prueba', token_type: 'bearer', expires_in: 3600,
    expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: 'prueba',
    user: { id: '00000000-0000-0000-0000-000000000001', email: 'admin@prueba.test', aud: 'authenticated', role: 'authenticated' }
  }))
}, [REF])

const pagina = await contexto.newPage()

await pagina.route('**/*.supabase.co/**', async (r) => {
  const peticion = r.request()
  const url = peticion.url()
  const metodo = peticion.method()

  if (url.includes('/auth/v1/')) {
    return r.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        access_token: 'prueba', token_type: 'bearer', expires_in: 3600, refresh_token: 'prueba',
        user: { id: '00000000-0000-0000-0000-000000000001', email: 'admin@prueba.test' }
      })
    })
  }

  const tabla = (url.split('/rest/v1/')[1] || '').split('?')[0]
  let cuerpo = null
  try { cuerpo = peticion.postDataJSON() } catch { cuerpo = peticion.postData() }
  if (metodo !== 'GET') escrituras.push({ tabla, metodo, cuerpo })

  // Las escrituras devuelven la fila resultante: los stores usan
  // `.select().single()` y sin fila tratarían el guardado como fallido.
  if (metodo !== 'GET' && !Array.isArray(cuerpo)) {
    const base = tabla === 'products' ? PRODUCTOS[0] : COLECCIONES[0]
    return r.fulfill({
      status: metodo === 'POST' ? 201 : 200,
      contentType: 'application/json',
      body: JSON.stringify([{ ...base, id: metodo === 'POST' ? 99 : base.id, slug: 'la-nueva', ...cuerpo }])
    })
  }

  await r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(datosDe(tabla)) })
})

const errores = []
pagina.on('pageerror', (e) => errores.push(String(e).slice(0, 200)))

let fallos = 0
function comprobar(nombre, condicion, detalle = '') {
  if (condicion) console.log(`ok     ${nombre}`)
  else {
    fallos += 1
    console.log(`FALLA  ${nombre}${detalle ? `\n         ${detalle}` : ''}`)
  }
}

async function irA(ruta) {
  await pagina.goto(BASE + ruta, { waitUntil: 'networkidle', timeout: 30000 })
  await pagina.waitForTimeout(900)
}

const conteoTienda = async () => {
  const t = await pagina.locator('text=/producto\\(s\\) encontrado/').first().innerText()
  return Number(t.match(/(\d+)/)[1])
}

// ============================================================ TIENDA
console.log('\n--- portada y tienda ---')
await irA('/')

const seccion = pagina.locator('#colecciones')
const filas = seccion.locator('section')
await seccion.waitFor({ timeout: 10000 }).catch(() => {})

const titulos = await filas.locator('h3').allInnerTexts()
comprobar(
  'una fila por colección publicada CON productos (la vacía y la borrador no)',
  titulos.length === 2,
  `filas: ${JSON.stringify(titulos)}`
)
comprobar(
  'las ordena por posición, no por nombre ni por id',
  titulos.map((t) => t.trim()).join('|') === 'Navidad|Alisia',
  JSON.stringify(titulos)
)

const filaAlisia = filas.filter({ hasText: 'Alisia' }).first()
const tarjetas = filaAlisia.locator('li article')
comprobar('el carrusel lleva solo los productos de esa colección',
  (await tarjetas.count()) === 5, `tarjetas: ${await tarjetas.count()}`)

const textoPrimera = await tarjetas.first().innerText()
comprobar('cada tarjeta es la de la tienda: nombre y precio',
  /Base Alisia/.test(textoPrimera) && /\$\s?50/.test(textoPrimera), textoPrimera.replace(/\n/g, ' | '))

comprobar('el subtítulo que puso la administradora se ve bajo el título',
  /Todo lo que usa Alisia/.test(await filaAlisia.innerText()))

// ---- flechas
const pista = filaAlisia.locator('ul')
// Las flechas van `aria-hidden` a propósito (el scroll y «Ver todo» ya cubren
// teclado y lector de pantalla), así que se localizan por el contenedor y no
// por rol: por rol se acabaría pulsando el «Al carrito» de una tarjeta.
const anterior = filaAlisia.locator('[data-flechas] button').first()
const siguiente = filaAlisia.locator('[data-flechas] button').last()

comprobar('al cargar, la flecha de retroceder está desactivada', await anterior.isDisabled())

const antes = await pista.evaluate((el) => el.scrollLeft)
await siguiente.click()
await pagina.waitForTimeout(900)
const despues = await pista.evaluate((el) => el.scrollLeft)
comprobar('la flecha de avanzar desplaza el carrusel', despues > antes, `${antes} → ${despues}`)
comprobar('y entonces la de retroceder se activa', !(await anterior.isDisabled()))

const filaNavidad = filas.filter({ hasText: 'Navidad' }).first()
comprobar('una colección de un solo producto no muestra flechas',
  (await filaNavidad.locator('[data-flechas]').count()) === 0)

// ---- «Ver todo»
await filaAlisia.getByRole('link', { name: /Ver todo/ }).click()
await pagina.waitForURL('**/tienda?coleccion=alisia', { timeout: 10000 })
await pagina.waitForTimeout(800)
comprobar('«Ver todo» abre la tienda filtrada por la colección', (await conteoTienda()) === 5)

const desplegable = 'select[aria-label="Filtrar por colección"]'
comprobar('el desplegable llega marcando la colección de la URL',
  (await pagina.locator(desplegable).inputValue()) === 'alisia')

const opciones = await pagina.locator(`${desplegable} option`).allInnerTexts()
comprobar('ofrece las publicadas, con productos o sin ellos, y no las borradores',
  opciones.map((t) => t.trim()).join('|') === 'Colecciones|Navidad|Alisia|Vacia',
  JSON.stringify(opciones.map((t) => t.trim())))

await pagina.selectOption(desplegable, 'navidad')
await pagina.waitForTimeout(600)
comprobar('elegir otra colección vuelve a filtrar', (await conteoTienda()) === 1)
comprobar('y lo refleja en la URL, para poder compartirla',
  pagina.url().includes('coleccion=navidad'), pagina.url())

await pagina.selectOption(desplegable, '')
await pagina.waitForTimeout(600)
comprobar('quitar la colección devuelve el catálogo entero', (await conteoTienda()) === 7)
comprobar('y saca el parámetro de la URL', !pagina.url().includes('coleccion='), pagina.url())

await irA('/tienda?categoria=Bases')
await pagina.selectOption(desplegable, 'alisia')
await pagina.waitForTimeout(600)
const query = new URL(pagina.url()).searchParams
comprobar('elegir colección conserva la categoría que ya estaba en la URL',
  query.get('categoria') === 'Bases' && query.get('coleccion') === 'alisia', pagina.url())
comprobar('y los dos filtros se aplican a la vez', (await conteoTienda()) === 1)

seccionEncendida = false
await irA('/')
comprobar('con el interruptor apagado la sección no se pinta', (await seccion.count()) === 0)
await irA('/tienda')
comprobar('pero el filtro de la tienda sigue existiendo',
  (await pagina.locator(desplegable).count()) === 1)
seccionEncendida = true

// ============================================================ PANEL
console.log('\n--- panel ---')
await irA('/admin')
const pestana = pagina.getByRole('button', { name: /configuraci/i }).first()
if (await pestana.count()) await pestana.click()
await pagina.waitForTimeout(1200)

comprobar('el módulo de Colecciones está en Configuración',
  (await pagina.getByRole('heading', { name: 'Colecciones' }).count()) > 0)

const enPanel = pagina.locator('li').filter({ hasText: 'producto(s)' })
comprobar('lista todas las colecciones, publicadas o no', (await enPanel.count()) === 4)

const alisiaPanel = await enPanel.filter({ hasText: 'Alisia' }).first().innerText()
comprobar('cuenta los productos de cada colección', /5 producto\(s\)/.test(alisiaPanel), alisiaPanel)
comprobar('dice por qué una colección sin productos no sale en la portada',
  /sin productos/i.test(await enPanel.filter({ hasText: 'Vacia' }).first().innerText()))
comprobar('y por qué una sin publicar no sale',
  /Sin publicar/.test(await enPanel.filter({ hasText: 'Borrador' }).first().innerText()))

const ayudaPx = await pagina.locator('p').filter({ hasText: 'Foto de cabecera' }).allInnerTexts()
comprobar('el tamaño recomendado de la cabecera está escrito donde se sube',
  ayudaPx.some((t) => /1600/.test(t) && /500/.test(t)), JSON.stringify(ayudaPx))

await pagina.fill('input[placeholder*="Nombre de la colección"]', 'La nueva')
await pagina.getByRole('button', { name: 'Crear colección' }).click()
await pagina.waitForTimeout(800)

const alta = escrituras.find((e) => e.tabla === 'collections' && e.metodo === 'POST')
comprobar('crear manda un INSERT a collections', Boolean(alta))
comprobar('el INSERT NO lleva slug: lo calcula la base (migración 026)',
  alta && !('slug' in (alta.cuerpo || {})), JSON.stringify(alta?.cuerpo))
comprobar('y coloca la nueva al final de la fila',
  alta && alta.cuerpo.position === 5, `position enviada: ${alta?.cuerpo?.position}`)

await enPanel.filter({ hasText: 'Borrador' }).first().getByRole('button', { name: /Sin publicar/ }).click()
await pagina.waitForTimeout(800)
comprobar('publicar manda published = true',
  escrituras.some((e) => e.metodo === 'PATCH' && e.cuerpo?.published === true))

escrituras.length = 0
await enPanel.filter({ hasText: 'Alisia' }).first().getByLabel('Bajarla en la portada').click()
await pagina.waitForTimeout(800)
const orden = escrituras.find((e) => e.tabla === 'collections' && Array.isArray(e.cuerpo))
comprobar('reordenar reescribe TODAS las posiciones, no solo las dos que cambian',
  orden && orden.cuerpo.length >= 2 && orden.cuerpo.every((f, i) => f.position === i + 1),
  JSON.stringify(orden?.cuerpo))

escrituras.length = 0
await pagina.getByRole('button', { name: /Sección visible/ }).click()
await pagina.waitForTimeout(900)
const ajuste = escrituras.find((e) => e.tabla === 'store_settings')
const filaAjuste = Array.isArray(ajuste?.cuerpo) ? ajuste.cuerpo[0] : ajuste?.cuerpo
comprobar('apagar la sección escribe homeCollectionsVisible = false',
  filaAjuste?.key === 'homeCollectionsVisible' && filaAjuste?.value === 'false',
  JSON.stringify(ajuste?.cuerpo))

await enPanel.filter({ hasText: 'Alisia' }).first().getByLabel('Borrar la colección').click()
await pagina.waitForTimeout(500)
const modal = await pagina.locator('.fixed').last().innerText()
comprobar('el modal de borrado dice cuántos productos quedan sueltos',
  /5 producto\(s\)/.test(modal) && /No se borra ninguno/.test(modal), modal.replace(/\n/g, ' | '))

await pagina.keyboard.press('Escape')
escrituras.length = 0
await irA('/admin/productos/7')
const selector = pagina.locator('select').filter({ hasText: 'Sin colección' }).first()
comprobar('el editor de producto tiene selector de colección', (await selector.count()) === 1)
comprobar('y marca las colecciones que no están publicadas',
  (await selector.locator('option').allInnerTexts()).some((t) => /Borrador \(sin publicar\)/.test(t)))

await selector.selectOption({ label: 'Alisia' })
await pagina.getByRole('button', { name: /^Guardar/ }).first().click()
await pagina.waitForTimeout(1000)
const guardado = escrituras.find((e) => e.tabla === 'products' && e.metodo === 'PATCH')
comprobar('guardar el producto manda collection_id',
  guardado && guardado.cuerpo.collection_id === 1, JSON.stringify(guardado?.cuerpo?.collection_id))

comprobar('ninguna página lanzó una excepción', errores.length === 0, errores.join(' / '))

await navegador.close()
await servidor.close()

console.log(fallos ? `\n${fallos} comprobación(es) fallida(s).` : '\nTodas las comprobaciones pasaron.')
process.exit(fallos ? 1 : 0)
