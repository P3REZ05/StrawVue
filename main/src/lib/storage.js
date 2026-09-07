import { supabase } from './supabase'
import { optimizarImagen, resumenOptimizacion } from './imageOptimizer'

// Capa de almacenamiento de imágenes de producto.
//
// Sustituye a lo que había antes: `URL.createObjectURL(archivo)` guardado en
// `products.image`. Un `blob:` solo existe en la pestaña que lo creó — al
// recargar quedaba roto y para cualquier cliente nunca existió (B-15).
//
// Estructura de rutas dentro del bucket:
//   productos/{productId}/{uuid}-{nombre}.webp
//   productos/{productId}/tonos/{variantId}/{uuid}-{nombre}.webp
// Agrupar por producto permite borrar todo su material de una vez.

export const BUCKET = 'product-images'

function idUnico() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID().slice(0, 8)
  return Math.random().toString(36).slice(2, 10)
}

function construirRuta({ productId, variantId, nombre }) {
  const base = variantId
    ? `productos/${productId}/tonos/${variantId}`
    : `productos/${productId}`
  return `${base}/${idUnico()}-${nombre}`
}

/**
 * Optimiza y sube una imagen. Devuelve la fila lista para `product_images`
 * más el resumen de compresión para mostrárselo a la administradora.
 */
export async function subirImagen(archivo, { productId, variantId = null, perfil = 'producto', alt = null } = {}) {
  if (!productId) throw new Error('Falta el producto al que pertenece la imagen.')

  const optimizada = await optimizarImagen(archivo, perfil)
  const ruta = construirRuta({ productId, variantId, nombre: optimizada.nombre })

  const { error: errorSubida } = await supabase.storage
    .from(BUCKET)
    .upload(ruta, optimizada.blob, {
      contentType: optimizada.tipo,
      // Un año de caché: la ruta lleva un identificador único, así que una
      // imagen nunca cambia de contenido bajo la misma URL.
      cacheControl: '31536000',
      upsert: false
    })

  if (errorSubida) {
    if (errorSubida.message?.includes('Bucket not found')) {
      throw new Error(`No existe el bucket "${BUCKET}" en Supabase Storage. Créalo antes de subir imágenes.`)
    }
    throw new Error(`No se pudo subir la imagen: ${errorSubida.message}`)
  }

  const { data } = supabase.storage.from(BUCKET).getPublicUrl(ruta)

  return {
    url: data.publicUrl,
    storage_path: ruta,
    alt: alt || optimizada.nombre.replace(/\.[^.]+$/, '').replace(/-/g, ' '),
    ancho: optimizada.ancho,
    alto: optimizada.alto,
    optimizacion: {
      ...optimizada,
      blob: undefined,
      resumen: resumenOptimizacion(optimizada)
    }
  }
}

/** Sube y registra la imagen en `product_images` en un solo paso. */
export async function registrarImagenProducto(archivo, opciones) {
  const subida = await subirImagen(archivo, opciones)

  const fila = {
    product_id: opciones.productId,
    variant_id: opciones.variantId || null,
    url: subida.url,
    storage_path: subida.storage_path,
    alt: subida.alt,
    position: opciones.position ?? 0,
    is_primary: Boolean(opciones.esPrincipal)
  }

  // Solo puede haber una principal por producto (índice único en la base):
  // se baja la anterior antes de insertar la nueva.
  if (fila.is_primary) {
    await supabase
      .from('product_images')
      .update({ is_primary: false })
      .eq('product_id', opciones.productId)
      .eq('is_primary', true)
  }

  const { data, error } = await supabase.from('product_images').insert(fila).select().single()

  if (error) {
    // Si la fila no se pudo crear, el archivo subido quedaría huérfano
    // ocupando espacio del plan gratuito para siempre.
    await supabase.storage.from(BUCKET).remove([subida.storage_path])
    throw new Error(`No se pudo registrar la imagen: ${error.message}`)
  }

  return { ...data, optimizacion: subida.optimizacion }
}

/** Borra la imagen del registro y del almacenamiento. */
export async function eliminarImagen(imagen) {
  if (!imagen?.id) throw new Error('Imagen inválida.')

  const { error } = await supabase.from('product_images').delete().eq('id', imagen.id)
  if (error) throw new Error(`No se pudo eliminar la imagen: ${error.message}`)

  if (imagen.storage_path) {
    const { error: errorArchivo } = await supabase.storage.from(BUCKET).remove([imagen.storage_path])
    // El registro ya no existe; un archivo suelto es molesto pero no rompe nada.
    if (errorArchivo) console.warn('El archivo quedó en el almacenamiento:', errorArchivo.message)
  }
  return true
}

/** Borra todo el material de un producto. Útil al archivarlo. */
export async function eliminarImagenesDeProducto(productId) {
  const { data: imagenes } = await supabase
    .from('product_images')
    .select('storage_path')
    .eq('product_id', productId)

  const rutas = (imagenes || []).map((imagen) => imagen.storage_path).filter(Boolean)
  if (rutas.length) await supabase.storage.from(BUCKET).remove(rutas)

  await supabase.from('product_images').delete().eq('product_id', productId)
  return rutas.length
}

/** Marca una imagen como principal, respetando el índice único. */
export async function marcarPrincipal(imagen) {
  await supabase
    .from('product_images')
    .update({ is_primary: false })
    .eq('product_id', imagen.product_id)
    .eq('is_primary', true)

  const { error } = await supabase
    .from('product_images')
    .update({ is_primary: true })
    .eq('id', imagen.id)

  if (error) throw new Error(`No se pudo marcar como principal: ${error.message}`)
  return true
}

/** Cuánto espacio ocupan hoy las imágenes. El plan gratuito da 1 GB. */
export async function usoDeAlmacenamiento() {
  const { count } = await supabase
    .from('product_images')
    .select('id', { count: 'exact', head: true })
  return { imagenes: count || 0 }
}
