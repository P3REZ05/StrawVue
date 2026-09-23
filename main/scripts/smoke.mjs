/**
 * Prueba de humo del build de producción.
 *
 * No sustituye a unos tests de verdad, pero cubre el fallo que más veces se
 * nos ha colado en este proyecto: la página en blanco. Un import circular,
 * un chunk mal partido o un componente que revienta al montar no los detecta
 * `npm run build` —el build pasa igual— y solo se ven abriendo el navegador.
 *
 * Comprueba, sobre el build real servido por `vite preview`:
 *   1. que cada ruta renderiza algo (no una página en blanco);
 *   2. que ninguna suelta errores en consola;
 *   3. que el panel de administración NO se descarga en rutas públicas.
 *
 * El punto 3 es el que protege el code-splitting: es fácil volver a meter el
 * panel en el bundle público con un import estático sin darse cuenta, y el
 * único síntoma sería que la tienda tarda más en cargar.
 *
 * Uso:
 *   npm run build
 *   npx playwright install chromium     # solo la primera vez
 *   npm run smoke
 *
 * Variables opcionales:
 *   SMOKE_URL        probar contra un servidor ya levantado (p. ej. producción)
 *   SMOKE_CHROMIUM   ruta a un Chromium ya instalado, en vez del de Playwright
 *
 * El script levanta y apaga `vite preview` por su cuenta con la API de Vite,
 * en vez de encadenar comandos con `&`: eso no funciona en PowerShell, que es
 * donde se trabaja en este proyecto.
 *
 * Las llamadas a Supabase se interceptan a propósito: esto prueba que la
 * aplicación arranca, no que la base responda. Así corre en cualquier sitio,
 * incluida una CI sin credenciales.
 */
import { chromium } from 'playwright'
import { preview } from 'vite'

const PUERTO = Number(process.env.SMOKE_PORT || 4173)
const BASE = process.env.SMOKE_URL || `http://127.0.0.1:${PUERTO}`

// Si se pasa SMOKE_URL, se prueba contra ese servidor (útil para probar el
// despliegue real). Si no, se sirve el `dist/` local.
let servidor = null
if (!process.env.SMOKE_URL) {
  servidor = await preview({ preview: { port: PUERTO, host: '127.0.0.1' } })
}

const RUTAS = [
  { ruta: '/', esperada: '/' },
  { ruta: '/tienda', esperada: '/tienda' },
  { ruta: '/producto/5', esperada: '/producto/5' },
  { ruta: '/carrito', esperada: '/carrito' },
  { ruta: '/favoritos', esperada: '/favoritos' },
  { ruta: '/nosotros', esperada: '/nosotros' },
  { ruta: '/contacto', esperada: '/contacto' },
  { ruta: '/terminos', esperada: '/terminos' },
  { ruta: '/admin', esperada: '/admin' },
  // Una URL inexistente debe redirigir, no dejar la pantalla vacía.
  { ruta: '/esta-ruta-no-existe', esperada: '/' }
]

const MINIMO_CARACTERES = 80
const CHUNKS_DE_ADMIN = ['AdminPanel', 'ProductEditor']

// Ruido del entorno que no dice nada del código.
const IGNORAR = [/favicon/i, /ERR_TUNNEL/i, /net::ERR_INTERNET_DISCONNECTED/i]

// En una CI o en un contenedor suele haber ya un Chromium instalado con otra
// revisión que la que espera Playwright. `SMOKE_CHROMIUM` deja apuntar a ese
// binario en vez de descargar otro de 150 MB.
const navegador = await chromium.launch(
  process.env.SMOKE_CHROMIUM ? { executablePath: process.env.SMOKE_CHROMIUM } : {}
)
const pagina = await navegador.newPage()

await pagina.route('**/*.supabase.co/**', async (r) => {
  const url = r.request().url()
  const cuerpo = url.includes('/auth/v1/') ? '{"data":{"session":null},"error":null}' : '[]'
  await r.fulfill({ status: 200, contentType: 'application/json', body: cuerpo })
})

const errores = []
const descargados = new Set()
pagina.on('console', (m) => {
  if (m.type() !== 'error') return
  const t = m.text()
  if (!IGNORAR.some((re) => re.test(t))) errores.push(t.slice(0, 160))
})
pagina.on('pageerror', (e) => errores.push('PAGEERROR: ' + String(e).slice(0, 200)))
pagina.on('response', (r) => {
  const archivo = r.url().split('/').pop()
  if (r.url().includes('/assets/')) descargados.add(archivo)
})

let fallos = 0

for (const { ruta, esperada } of RUTAS) {
  descargados.clear()
  const erroresAntes = errores.length

  await pagina.goto(BASE + ruta, { waitUntil: 'networkidle', timeout: 30000 })
  await pagina.waitForTimeout(800)

  const texto = (await pagina.locator('body').innerText()).trim()
  const destino = new URL(pagina.url()).pathname
  const panel = [...descargados].filter((f) => CHUNKS_DE_ADMIN.some((c) => f.startsWith(c)))
  const esPublica = !ruta.startsWith('/admin')

  const problemas = []
  if (texto.length < MINIMO_CARACTERES) problemas.push(`pantalla casi vacía (${texto.length} caracteres)`)
  if (destino !== esperada) problemas.push(`terminó en ${destino}, se esperaba ${esperada}`)
  if (errores.length > erroresAntes) problemas.push(`${errores.length - erroresAntes} error(es) en consola`)
  if (esPublica && panel.length) problemas.push(`descargó el panel: ${panel.join(', ')}`)

  if (problemas.length) {
    fallos += 1
    console.log(`FALLA  ${ruta}\n         ${problemas.join('\n         ')}`)
  } else {
    console.log(`ok     ${ruta}`)
  }
}

if (errores.length) {
  console.log('\nErrores de consola:')
  for (const e of [...new Set(errores)]) console.log('  ' + e)
}

await navegador.close()
await servidor?.close()

console.log(fallos ? `\n${fallos} ruta(s) con problemas.` : `\n${RUTAS.length} rutas correctas.`)
process.exit(fallos ? 1 : 0)
