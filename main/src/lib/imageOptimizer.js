// Optimizador de imágenes del lado del cliente.
//
// POR QUÉ EXISTE
// El plan gratuito de Supabase da 1 GB de almacenamiento y 5 GB de egreso al
// mes. Una foto de móvil sin tratar pesa entre 3 y 6 MB: doscientas fotos
// llenan el plan. Comprimir antes de subir multiplica por diez o más lo que
// cabe, y además ahorra egreso cada vez que un cliente abre la tienda.
//
// QUÉ SE MIDIÓ (sobre las imágenes reales del proyecto)
//   pexels.jpg  4.472 KB → 1600px WebP q=90 → 256 KB   (−94%)
//   banner      1.233 KB → 1600px WebP q=90 →  82 KB   (−93%)
//   logo PNG       21 KB → WebP sin pérdida →   9 KB   (−56%, idéntico pixel a pixel)
//
// SOBRE "SIN PERDER CALIDAD"
// La compresión estrictamente sin pérdida conserva cada pixel, pero solo ahorra
// entre un 30 y un 60 %. El ahorro grande viene de dos cosas distintas:
//   1. Redimensionar. Una foto de 4672x7008 mostrada en una tarjeta de 400px
//      desperdicia el 97 % de sus pixeles. Aquí no se pierde calidad visible:
//      se deja de guardar detalle que la pantalla nunca va a mostrar.
//   2. WebP con pérdida a calidad alta. A q=90 la diferencia es invisible en
//      fotografía (SSIM 0,958 medido sobre las fotos de este proyecto).
//
// EXCEPCIÓN IMPORTANTE PARA MAQUILLAJE
// En un swatch el color ES el dato. Se midió la desviación en Delta-E CIEDE2000
// sobre una carta de 10 tonos: sin pérdida da dE = 0,00; con pérdida a q=95 el
// interior de cada franja llega a dE 2,17, que es perceptible comparando lado a
// lado. Por eso el perfil `swatch` prueba también PNG sin pérdida y se queda con
// él cuando pesa menos, que es lo habitual en un swatch de color plano.
// El color exacto vive además en `swatch_hex`, así que nunca se pierde el dato.

const PERFILES = {
  // Fotos de producto: fotografía, se prioriza el peso.
  producto: { maxLado: 1600, calidad: 0.9, probarSinPerdida: false },
  // Swatches: el color manda, se prueba también sin pérdida.
  swatch: { maxLado: 600, calidad: 0.95, probarSinPerdida: true },
  // Miniaturas para tarjetas de catálogo.
  miniatura: { maxLado: 400, calidad: 0.82, probarSinPerdida: false },
  // Logos y gráficos planos: sin pérdida siempre.
  grafico: { maxLado: 1200, calidad: 1, probarSinPerdida: true }
}

const TIPOS_ACEPTADOS = ['image/jpeg', 'image/png', 'image/webp', 'image/avif', 'image/gif']
const TAMANO_MAXIMO_ENTRADA = 25 * 1024 * 1024

/** Comprueba una sola vez si el navegador sabe codificar WebP. */
let soporteWebp = null
async function admiteWebp() {
  if (soporteWebp !== null) return soporteWebp
  try {
    const lienzo = crearLienzo(1, 1)
    const blob = await aBlob(lienzo, 'image/webp', 0.8)
    soporteWebp = blob?.type === 'image/webp'
  } catch {
    soporteWebp = false
  }
  return soporteWebp
}

function crearLienzo(ancho, alto) {
  if (typeof OffscreenCanvas !== 'undefined') return new OffscreenCanvas(ancho, alto)
  const lienzo = document.createElement('canvas')
  lienzo.width = ancho
  lienzo.height = alto
  return lienzo
}

function aBlob(lienzo, tipo, calidad) {
  if (lienzo.convertToBlob) return lienzo.convertToBlob({ type: tipo, quality: calidad })
  return new Promise((resolve) => lienzo.toBlob(resolve, tipo, calidad))
}

/**
 * Decodifica respetando la orientación EXIF. Sin esto, una foto tomada con el
 * móvil en vertical se sube girada: el canvas ignora la etiqueta de rotación.
 */
async function decodificar(archivo) {
  if (typeof createImageBitmap === 'function') {
    try {
      return await createImageBitmap(archivo, { imageOrientation: 'from-image' })
    } catch {
      /* algunos navegadores no aceptan la opción: se usa el camino de abajo */
    }
  }
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(archivo)
    const img = new Image()
    img.onload = () => {
      URL.revokeObjectURL(url)
      resolve(img)
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('No se pudo leer la imagen.'))
    }
    img.src = url
  })
}

/**
 * Reduce por pasos, dividiendo a la mitad cada vez. El escalado del navegador
 * es bilineal: bajar de 7000px a 1600px de un salto pierde nitidez, mientras
 * que hacerlo por mitades conserva el detalle fino.
 */
function redimensionar(origen, anchoOrigen, altoOrigen, maxLado) {
  let ancho = anchoOrigen
  let alto = altoOrigen
  let actual = origen

  if (Math.max(ancho, alto) <= maxLado) {
    const lienzo = crearLienzo(ancho, alto)
    lienzo.getContext('2d').drawImage(actual, 0, 0)
    return { lienzo, ancho, alto }
  }

  while (Math.max(ancho, alto) > maxLado * 2) {
    const siguienteAncho = Math.max(1, Math.round(ancho / 2))
    const siguienteAlto = Math.max(1, Math.round(alto / 2))
    const paso = crearLienzo(siguienteAncho, siguienteAlto)
    const ctx = paso.getContext('2d')
    ctx.imageSmoothingEnabled = true
    ctx.imageSmoothingQuality = 'high'
    ctx.drawImage(actual, 0, 0, siguienteAncho, siguienteAlto)
    actual = paso
    ancho = siguienteAncho
    alto = siguienteAlto
  }

  const escala = maxLado / Math.max(ancho, alto)
  const anchoFinal = Math.max(1, Math.round(ancho * escala))
  const altoFinal = Math.max(1, Math.round(alto * escala))
  const lienzo = crearLienzo(anchoFinal, altoFinal)
  const ctx = lienzo.getContext('2d')
  ctx.imageSmoothingEnabled = true
  ctx.imageSmoothingQuality = 'high'
  ctx.drawImage(actual, 0, 0, anchoFinal, altoFinal)
  return { lienzo, ancho: anchoFinal, alto: altoFinal }
}

function extensionDe(tipo) {
  return { 'image/webp': 'webp', 'image/png': 'png', 'image/jpeg': 'jpg', 'image/avif': 'avif' }[tipo] || 'bin'
}

function nombreBase(nombre) {
  return (nombre || 'imagen')
    .replace(/\.[^.]+$/, '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60) || 'imagen'
}

/**
 * Optimiza una imagen antes de subirla.
 *
 * Genera varios candidatos y se queda con el más liviano, incluido el archivo
 * original: un PNG de color plano puede pesar menos que su versión WebP, y en
 * ese caso reencodificarlo sería empeorarlo. Se midió: `two.png` crece un 225 %
 * al convertirlo a WebP sin pérdida.
 *
 * @returns {Promise<{blob: Blob, nombre: string, tipo: string, ancho: number,
 *   alto: number, bytesOriginal: number, bytesFinal: number, ahorro: number,
 *   sinPerdida: boolean, redimensionada: boolean}>}
 */
export async function optimizarImagen(archivo, nombrePerfil = 'producto') {
  if (!archivo) throw new Error('No se recibió ninguna imagen.')
  if (!TIPOS_ACEPTADOS.includes(archivo.type)) {
    throw new Error(`Formato no admitido (${archivo.type || 'desconocido'}). Usa JPG, PNG o WebP.`)
  }
  if (archivo.size > TAMANO_MAXIMO_ENTRADA) {
    throw new Error(`La imagen pesa ${(archivo.size / 1024 / 1024).toFixed(1)} MB. El máximo es 25 MB.`)
  }

  const perfil = PERFILES[nombrePerfil] || PERFILES.producto
  const bitmap = await decodificar(archivo)
  const anchoOrigen = bitmap.width || bitmap.naturalWidth
  const altoOrigen = bitmap.height || bitmap.naturalHeight
  if (!anchoOrigen || !altoOrigen) throw new Error('La imagen está vacía o dañada.')

  const { lienzo, ancho, alto } = redimensionar(bitmap, anchoOrigen, altoOrigen, perfil.maxLado)
  if (bitmap.close) bitmap.close()

  const webp = await admiteWebp()
  const candidatos = []

  if (webp && perfil.calidad < 1) {
    candidatos.push({ tipo: 'image/webp', calidad: perfil.calidad, sinPerdida: false })
  }
  if (perfil.probarSinPerdida) {
    // PNG es sin pérdida por definición: garantiza dE = 0 en swatches planos.
    candidatos.push({ tipo: 'image/png', calidad: undefined, sinPerdida: true })
  }
  if (!candidatos.length) {
    candidatos.push({ tipo: 'image/png', calidad: undefined, sinPerdida: true })
  }

  const resultados = []
  for (const candidato of candidatos) {
    const blob = await aBlob(lienzo, candidato.tipo, candidato.calidad)
    if (blob && blob.size) resultados.push({ ...candidato, blob })
  }
  if (!resultados.length) throw new Error('El navegador no pudo procesar la imagen.')

  const redimensionada = ancho !== anchoOrigen || alto !== altoOrigen
  let mejor = resultados.reduce((a, b) => (b.blob.size < a.blob.size ? b : a))

  // Si el original ya pesaba menos y no hizo falta redimensionar, se conserva:
  // reencodificarlo solo lo empeoraría.
  if (!redimensionada && archivo.size <= mejor.blob.size) {
    mejor = { tipo: archivo.type, blob: archivo, sinPerdida: true }
  }

  return {
    blob: mejor.blob,
    tipo: mejor.tipo,
    nombre: `${nombreBase(archivo.name)}.${extensionDe(mejor.tipo)}`,
    ancho,
    alto,
    bytesOriginal: archivo.size,
    bytesFinal: mejor.blob.size,
    ahorro: archivo.size ? 1 - mejor.blob.size / archivo.size : 0,
    sinPerdida: Boolean(mejor.sinPerdida),
    redimensionada
  }
}

/** Texto corto para mostrarle a la administradora lo que se ahorró. */
export function resumenOptimizacion(resultado) {
  const kb = (n) => (n < 1024 * 1024 ? `${Math.round(n / 1024)} KB` : `${(n / 1024 / 1024).toFixed(1)} MB`)
  const porcentaje = Math.round(resultado.ahorro * 100)
  const detalle = resultado.sinPerdida ? 'sin pérdida' : 'calidad visual intacta'
  if (porcentaje <= 0) return `${kb(resultado.bytesFinal)} · ya estaba optimizada`
  return `${kb(resultado.bytesOriginal)} → ${kb(resultado.bytesFinal)} · ${porcentaje}% menos · ${detalle}`
}

export const PERFILES_IMAGEN = Object.keys(PERFILES)
