/**
 * Auditoría de responsive de las páginas públicas.
 *
 * Busca los tres fallos que de verdad se sufren en un celular y que
 * `npm run build` y `npm run smoke` no ven:
 *
 *   1. DESBORDE HORIZONTAL. Un solo elemento más ancho que la pantalla hace
 *      que TODA la página se pueda arrastrar de lado. Es el defecto móvil más
 *      común y el más fácil de no notar en un monitor.
 *   2. ÁREAS TÁCTILES PEQUEÑAS. Un botón o enlace de menos de 40 px no se
 *      acierta con el pulgar. El mínimo recomendado son 44 px.
 *   3. TEXTO DIMINUTO. Por debajo de 12 px no se lee sin acercar la pantalla.
 *
 * Sirve el `dist/` real y siembra respuestas de Supabase con datos de forma y
 * longitud realistas —nombres largos, precios de seis cifras, muchos tonos—,
 * porque una página vacía nunca desborda: los fallos aparecen cuando hay
 * contenido.
 *
 * Uso:
 *   npm run build
 *   npm run responsive
 *   npm run responsive -- --fotos     # además guarda capturas en .responsive/
 */
import { chromium } from 'playwright'
import { preview } from 'vite'
import { mkdir } from 'node:fs/promises'

const PUERTO = Number(process.env.RESP_PORT || 4174)
const BASE = process.env.RESP_URL || `http://127.0.0.1:${PUERTO}`
const FOTOS = process.argv.includes('--fotos')
const CARPETA = '.responsive'

const ANCHOS = [
  { nombre: 'movil-pequeno', width: 360, height: 780 },
  { nombre: 'movil', width: 390, height: 844 },
  { nombre: 'movil-grande', width: 430, height: 932 },
  { nombre: 'tablet', width: 768, height: 1024 },
  { nombre: 'laptop', width: 1024, height: 800 },
  { nombre: 'escritorio', width: 1440, height: 900 }
]

const RUTAS = ['/', '/tienda', '/producto/1', '/carrito', '/favoritos', '/nosotros', '/contacto', '/terminos']

const TACTIL_MINIMO = 40   // por debajo de esto se falla el toque con el pulgar
const TEXTO_MINIMO = 12    // por debajo de esto no se lee sin acercar

// ---------------------------------------------------------------------
// Datos sembrados. Deliberadamente incómodos: nombres largos, precios de
// seis cifras y una etiqueta de promoción que no cabe. Si el diseño aguanta
// esto, aguanta el catálogo real.
// ---------------------------------------------------------------------
const CATEGORIAS = ['Bases', 'Labios', 'Skincare', 'Sombras', 'Brochas', 'Primer y Fijador',
  'Correctores', 'Rubores', 'Iluminadores', 'Cejas', 'Pestañas', 'Delineadores',
  'Polvos', 'Accesorios', 'Pestañinas'].map((name, i) => ({
  id: i + 1, name, slug: name.toLowerCase(), parent_id: null, active: true, image: null, position: i
}))

const PRODUCTOS = Array.from({ length: 12 }, (_, i) => ({
  id: i + 1,
  name: i % 3 === 0
    ? 'Base de Larga Duración Velvet Skin Matte Profesional'
    : `Producto de prueba ${i + 1}`,
  slug: `producto-${i + 1}`,
  description: 'Descripción de catálogo con largo realista para comprobar que la tarjeta no se estira.',
  category: CATEGORIAS[i % CATEGORIAS.length].name,
  category_id: (i % CATEGORIAS.length) + 1,
  brand: 'Marca de prueba',
  brand_id: 1,
  // Repartidos entre las cuatro colecciones sembradas, para que el filtro
  // `?coleccion=` de la tienda tenga algo que enseñar en la auditoría.
  collection_id: (i % 4) + 1,
  price: 128900,
  sale_price: i % 4 === 0 ? 99900 : null,
  status: 'active',
  active: true,
  barcode: null,
  net_content_ml: 30,
  updated_at: new Date().toISOString()
}))

const TONOS = PRODUCTOS.flatMap((p) =>
  Array.from({ length: 6 }, (_, j) => ({
    id: p.id * 100 + j,
    product_id: p.id,
    name: `Tono ${j + 1} Beige Arena Natural`,
    shade_code: `NW${j + 1}0`,
    sku: `SKU-${p.id}-${j}`,
    price: null,
    is_active: true,
    is_default: j === 0,
    position: j,
    swatch_hex: ['#e8c39e', '#d9a679', '#c68642', '#8d5524', '#f1c27d', '#ffdbac'][j],
    swatch_image_url: null,
    undertone_id: (j % 3) + 1,
    shade_family_id: (j % 4) + 1,
    variant_type: 'shade',
    option_value: null
  }))
)

const SALDOS = TONOS.map((t) => ({
  product_id: t.product_id,
  variant_id: t.id,
  warehouse_stock: 10,
  sale_stock: t.product_id % 5 === 0 ? 0 : 7
}))

const SIEMBRA = {
  categories: CATEGORIAS,
  products: PRODUCTOS,
  product_variants: TONOS,
  product_images: [],
  brands: [
    'Marca de prueba', 'Cosmética Natural Colombiana', 'Ruby Rose', 'Esika',
    'Maybelline New York', 'Vogue', 'Jolie de Vogue'
  ].map((name, i) => ({ id: i + 1, name, active: true })),
  // Con foto y con productos, para que la sección Colecciones del Home entre
  // en la auditoría: un carrusel horizontal es justo lo que desborda de lado
  // si está mal hecho. Nombres largos a propósito.
  collections: [
    'Alisia', 'Navidad en Strawberry', 'Edición limitada de verano', 'Básicos'
  ].map((name, i) => ({
    id: i + 1, name, slug: `coleccion-${i + 1}`,
    description: 'Subtítulo de prueba con largo realista para ver si rompe la cabecera',
    image_url: `data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='${400 + i * 60}' height='400'%3E%3Crect width='100%25' height='100%25' fill='%23f3d9e6'/%3E%3C/svg%3E`,
    image_path: `colecciones/${i}.webp`, position: i + 1, published: true
  })),
  skin_types: [], finishes: [], coverages: [],
  undertones: [
    { id: 1, name: 'Cálido', active: true },
    { id: 2, name: 'Frío', active: true },
    { id: 3, name: 'Neutro', active: true }
  ],
  shade_families: ['Nudes', 'Rosados', 'Rojos', 'Vinos'].map((name, i) => ({ id: i + 1, name, active: true })),
  inventory_balances: SALDOS,
  // Lo que de verdad lee la tienda pública: `inventory_balances` está detrás
  // de RLS y a una clienta anónima le devuelve cero filas sin error.
  inventory_sale_balances: SALDOS.map((s, i) => ({
    id: i + 1, product_id: s.product_id, variant_id: s.variant_id, sale_stock: s.sale_stock
  })),
  storefront_products: PRODUCTOS.map((p) => ({
    product_id: p.id,
    base_price: p.price,
    effective_price: p.sale_price || p.price,
    promo_label: p.sale_price ? 'PROMO DE TEMPORADA -30%' : null,
    promo_title: p.sale_price ? 'Descuento de temporada' : null
  })),
  storefront_shades: TONOS.map((t) => ({
    variant_id: t.id, product_id: t.product_id,
    base_price: 128900, effective_price: 128900, promo_label: null, promo_title: null
  })),
  store_settings: [
    { key: 'shippingCost', value: '14500' },
    { key: 'freeShippingThreshold', value: '150000' },
    { key: 'whatsappNumber', value: '573001234567' },
    { key: 'socialInstagram', value: 'https://instagram.com/strawberry' },
    { key: 'homeCollectionsVisible', value: 'true' }
  ],
  home_banners: [{
    id: 1, title: 'Colección de temporada con nombre largo', subtitle: 'Hasta 30% de descuento',
    accent: 'NUEVO', link: '/tienda', image_url: null, image_path: null, position: 0, active: true
  }],
  home_offers: [
    { id: 1, title: 'Colección semanal de octubre', subtitle: 'Lo nuevo ya está aquí', badge: 'NUEVO', size: 'destacada', image_url: null, color_desde: '#ff85c1', color_hasta: '#d291bc', overlay: 20, text_color: 'light', link_type: 'category', link_category: 'Bases', position: 1, published: true },
    { id: 2, title: 'Skincare', subtitle: 'Hasta 30% OFF', badge: 'OFERTA', size: 'pequena', image_url: null, color_desde: '#80cbc4', color_hasta: '#00897b', overlay: 15, text_color: 'light', link_type: 'category', link_category: 'Skincare', position: 2, published: true },
    { id: 3, title: 'Bases mate', subtitle: 'Nueva colección', badge: 'TRENDING', size: 'pequena', image_url: null, color_desde: '#e0b088', color_hasta: '#b57a52', overlay: 15, text_color: 'light', link_type: 'category', link_category: 'Bases', position: 3, published: true },
    { id: 4, title: 'Paleta de sombras', subtitle: 'Descubre los nuevos tonos metálicos', badge: 'EDICIÓN LIMITADA', size: 'ancha', image_url: null, color_desde: '#4a173e', color_hasta: '#000000', overlay: 10, text_color: 'light', link_type: 'url', link_url: 'https://instagram.com/x', position: 4, published: true },
    { id: 5, title: 'Brochas', subtitle: 'Set de 12 piezas', badge: '', size: 'alta', image_url: null, color_desde: '#b39ddb', color_hasta: '#7e57c2', overlay: 15, text_color: 'light', link_type: 'category', link_category: 'Brochas', position: 5, published: true },
    { id: 6, title: 'Labiales', subtitle: '2x1 toda la semana', badge: '2x1', size: 'pequena', image_url: null, color_desde: '#ffab91', color_hasta: '#e64a19', overlay: 15, text_color: 'light', link_type: 'category', link_category: 'Labios', position: 6, published: true }
  ],
  // Etiquetas con el texto más largo que admite la base (24 caracteres): si
  // el diseño aguanta «EDICIÓN LIMITADA VERANO», aguanta «VIRAL».
  product_badges: [
    { id: 1, name: 'VIRAL', slug: 'viral', description: null, color_fondo: '#a855f7', color_texto: '#ffffff', position: 1, active: true },
    { id: 2, name: 'EDICION LIMITADA VERANO', slug: 'edicion-limitada', description: null, color_fondo: '#111111', color_texto: '#ffffff', position: 2, active: true },
    { id: 3, name: 'NUEVO', slug: 'nuevo', description: null, color_fondo: '#22c55e', color_texto: '#ffffff', position: 3, active: true }
  ],
  product_badge_assignments: PRODUCTOS.flatMap((p) =>
    p.id % 3 === 0
      ? [{ product_id: p.id, badge_id: 1 }, { product_id: p.id, badge_id: 2 }, { product_id: p.id, badge_id: 3 }]
      : p.id % 2 === 0 ? [{ product_id: p.id, badge_id: 1 }] : []
  ),
  promotions: [], promotion_products: [], contact_messages: []
}

function cuerpoPara(url) {
  if (url.includes('/auth/v1/')) return '{"data":{"session":null},"error":null}'
  if (url.includes('/rpc/')) return '[]'
  const tabla = url.match(/\/rest\/v1\/([a-z_]+)/)?.[1]
  return JSON.stringify(SIEMBRA[tabla] ?? [])
}

// ---------------------------------------------------------------------

let servidor = null
if (!process.env.RESP_URL) {
  servidor = await preview({ preview: { port: PUERTO, host: '127.0.0.1' } })
}
if (FOTOS) await mkdir(CARPETA, { recursive: true })

const navegador = await chromium.launch(
  process.env.RESP_CHROMIUM ? { executablePath: process.env.RESP_CHROMIUM } : {}
)

// Lo que se mide dentro de la página. Va como string porque se evalúa allí.
const MEDIR = ({ tactilMinimo, textoMinimo }) => {
  const ancho = document.documentElement.clientWidth
  const visible = (el) => {
    const e = getComputedStyle(el)
    if (e.display === 'none' || e.visibility === 'hidden' || Number(e.opacity) === 0) return false
    const r = el.getBoundingClientRect()
    return r.width > 0 && r.height > 0
  }
  const nombrar = (el) => {
    const clases = String(el.className || '').split(/\s+/).filter(Boolean).slice(0, 3).join('.')
    const texto = (el.innerText || '').trim().replace(/\s+/g, ' ').slice(0, 30)
    return `${el.tagName.toLowerCase()}${clases ? '.' + clases : ''}${texto ? ` «${texto}»` : ''}`
  }

  const desbordes = []
  const tactiles = []
  const textos = []

  for (const el of document.querySelectorAll('body *')) {
    if (!visible(el)) continue
    const r = el.getBoundingClientRect()

    // Solo interesa el elemento que desborda, no sus cincuenta ancestros: se
    // descarta el que desborda porque un hijo suyo ya lo hace.
    if (r.right > ancho + 1 || r.left < -1) {
      const culpableHijo = [...el.children].some((h) => {
        const rh = h.getBoundingClientRect()
        return rh.right > ancho + 1 || rh.left < -1
      })
      if (!culpableHijo) desbordes.push({ el: nombrar(el), derecha: Math.round(r.right), ancho: Math.round(r.width) })
    }

    // Qué cuenta como "algo que hay que tocar". La regla fina importa: un
    // verificador que marca cada enlace de texto del pie enseña a ignorarlo,
    // igual que un linter que grita por una coma.
    //
    // Lo que de verdad falla el pulgar no es un enlace bajito, es un enlace
    // bajito PEGADO a otro. Un enlace de 20px con 20px de aire alrededor se
    // acierta; tres seguidos sin separación, no. Así que se mide la banda
    // libre: alto + la mitad del hueco hasta el vecino tocable más cercano.
    const estilo = getComputedStyle(el)
    const esBoton = el.tagName === 'BUTTON' || el.getAttribute('role') === 'button'
      || ['SELECT', 'TEXTAREA'].includes(el.tagName)
      || (el.tagName === 'INPUT' && !['checkbox', 'radio', 'hidden'].includes(el.type))
    const esEnlace = el.tagName === 'A' && el.hasAttribute('href')
    // Un enlace con fondo o borde propio se comporta como botón: se le exige lo mismo.
    const enlaceConAspectoDeBoton = esEnlace && (
      estilo.backgroundImage !== 'none'
      || !/^rgba\(0, 0, 0, 0\)$|^transparent$/.test(estilo.backgroundColor)
      || parseFloat(estilo.borderTopWidth) > 0
    )

    // Una casilla de 14px se toca por su <label>, que es lo que el dedo busca.
    const casillaConEtiqueta = el.tagName === 'INPUT'
      && ['checkbox', 'radio'].includes(el.type)
      && el.closest('label')
      && el.closest('label').getBoundingClientRect().height >= tactilMinimo

    if ((esBoton || esEnlace) && !casillaConEtiqueta) {
      const exigido = (esBoton || enlaceConAspectoDeBoton) ? tactilMinimo : 0
      let banda = r.height

      if (!exigido) {
        // Hueco vertical libre hasta el enlace o botón más cercano.
        let hueco = 24
        for (const otro of document.querySelectorAll('a[href], button, [role="button"]')) {
          if (otro === el || el.contains(otro) || otro.contains(el)) continue
          const ro = otro.getBoundingClientRect()
          if (ro.height === 0 || ro.right < r.left || ro.left > r.right) continue
          const d = ro.top >= r.bottom ? ro.top - r.bottom
            : ro.bottom <= r.top ? r.top - ro.bottom : 0
          if (d < hueco) hueco = d
        }
        banda = r.height + hueco
      }

      const referencia = exigido || tactilMinimo
      if (r.height > 0 && (banda < referencia || (exigido && r.width < exigido))) {
        tactiles.push({ el: nombrar(el), w: Math.round(r.width), h: Math.round(r.height), banda: Math.round(banda) })
      }
    }

    if (el.children.length === 0 && (el.innerText || '').trim()) {
      const px = parseFloat(getComputedStyle(el).fontSize)
      if (px && px < textoMinimo) textos.push({ el: nombrar(el), px: Math.round(px * 10) / 10 })
    }
  }

  return {
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: ancho,
    desbordes: desbordes.slice(0, 6),
    tactiles: tactiles.slice(0, 8),
    textos: textos.slice(0, 6)
  }
}

let fallos = 0
const resumen = []

for (const medida of ANCHOS) {
  const contexto = await navegador.newContext({
    viewport: { width: medida.width, height: medida.height },
    deviceScaleFactor: 1,
    isMobile: medida.width < 768,
    hasTouch: medida.width < 768
  })
  const pagina = await contexto.newPage()
  await pagina.route('**/*.supabase.co/**', async (r) => {
    await r.fulfill({ status: 200, contentType: 'application/json', body: cuerpoPara(r.request().url()) })
  })

  for (const ruta of RUTAS) {
    await pagina.goto(BASE + ruta, { waitUntil: 'networkidle', timeout: 30000 })
    await pagina.waitForTimeout(600)

    const r = await pagina.evaluate(MEDIR, { tactilMinimo: TACTIL_MINIMO, textoMinimo: TEXTO_MINIMO })
    const desborda = r.scrollWidth > r.clientWidth + 1

    const lineas = []
    if (desborda) {
      lineas.push(`desborde horizontal: la página mide ${r.scrollWidth}px en una pantalla de ${r.clientWidth}px`)
      for (const d of r.desbordes) lineas.push(`   · ${d.el} llega a ${d.derecha}px`)
    }
    // Solo en móvil se exige el tamaño táctil: con ratón, 32px se acierta.
    if (medida.width < 768) {
      for (const t of r.tactiles) lineas.push(`área táctil ${t.w}×${t.h}px, banda libre ${t.banda}px (mínimo ${TACTIL_MINIMO}): ${t.el}`)
      for (const t of r.textos) lineas.push(`texto de ${t.px}px: ${t.el}`)
    }

    if (lineas.length) {
      fallos += 1
      resumen.push(`\n${medida.nombre} (${medida.width}px)  ${ruta}`)
      for (const l of lineas) resumen.push('   ' + l)
    }

    if (FOTOS) {
      const nombre = `${CARPETA}/${medida.nombre}${ruta.replace(/\//g, '_') || '_home'}.png`
      await pagina.screenshot({ path: nombre, fullPage: true })
    }
  }

  await contexto.close()
  console.log(`revisado  ${medida.nombre} (${medida.width}px)`)
}

await navegador.close()
await servidor?.close()

if (resumen.length) {
  console.log('\n===== HALLAZGOS =====')
  console.log(resumen.join('\n'))
  console.log(`\n${fallos} combinación(es) ancho×página con problemas.`)
} else {
  console.log('\nSin desbordes, áreas táctiles pequeñas ni texto diminuto.')
}
process.exit(0)
