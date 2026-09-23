import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { optimizarImagen } from '../lib/imageOptimizer'
import { BUCKET } from '../lib/storage'

/**
 * Las tarjetas de "Ofertas Especiales" de la portada.
 *
 * Es ESCAPARATE, no precio. Esta tabla no descuenta nada: una tarjeta que
 * dice "Hasta 30% OFF" no crea el descuento, solo lo anuncia. El descuento de
 * verdad se configura en Promociones y lo cobra el servidor. Mezclarlo sería
 * repetir el fallo del costo de envío, que se mostraba desde una constante y
 * se cobraba desde la base.
 *
 * Antes esto vivía escrito a mano dentro de `HomeAds.vue`.
 */

// Las cuatro piezas. La cuadrícula tiene 2 columnas en el celular y 4 desde
// tablet; cada pieza ocupa las mismas celdas en ambas, así que la misma
// composición se reordena sola en vez de romperse.
export const TAMANOS = [
  { id: 'destacada', etiqueta: 'Destacada', descripcion: 'Cuadrada grande, 2x2. Para la campaña principal.', clases: 'col-span-2 row-span-2' },
  { id: 'ancha', etiqueta: 'Ancha', descripcion: 'Franja horizontal, 2x1. Para un anuncio con texto largo.', clases: 'col-span-2 row-span-1' },
  { id: 'alta', etiqueta: 'Alta', descripcion: 'Vertical, 1x2. Luce bien con fotos de producto de pie.', clases: 'col-span-1 row-span-2' },
  { id: 'pequena', etiqueta: 'Pequeña', descripcion: 'Cuadrada, 1x1. Para rellenar y para ofertas sueltas.', clases: 'col-span-1 row-span-1' }
]

// Cuántas celdas ocupa cada pieza: [ancho, alto].
const CELDAS = { destacada: [2, 2], ancha: [2, 1], alta: [1, 2], pequena: [1, 1] }

/**
 * Simula el acomodo de la cuadrícula y devuelve cuántas celdas quedan vacías
 * en la última fila.
 *
 * Existe porque una composición puede dejar un hueco grande y feo a la
 * derecha —dos piezas pequeñas al final de una fila de cuatro— y desde el
 * panel no es evidente hasta verlo. La vista previa lo enseña; este número lo
 * explica y dice cuánto falta para cerrarlo.
 *
 * Reproduce el `grid-flow-dense` del navegador: cada pieza va al primer sitio
 * donde cabe, no necesariamente al siguiente.
 */
export function huecosDeLaRejilla(ofertas, columnas) {
  const ocupado = []
  const libre = (fila, col, ancho, alto) => {
    for (let f = fila; f < fila + alto; f++) {
      for (let c = col; c < col + ancho; c++) {
        if (ocupado[f]?.[c]) return false
      }
    }
    return true
  }
  const marcar = (fila, col, ancho, alto) => {
    for (let f = fila; f < fila + alto; f++) {
      ocupado[f] ??= new Array(columnas).fill(false)
      for (let c = col; c < col + ancho; c++) ocupado[f][c] = true
    }
  }

  for (const oferta of ofertas) {
    const [ancho, alto] = CELDAS[oferta.size] || CELDAS.pequena
    const a = Math.min(ancho, columnas)
    let puesto = false
    for (let fila = 0; !puesto; fila++) {
      ocupado[fila] ??= new Array(columnas).fill(false)
      for (let col = 0; col + a <= columnas; col++) {
        if (libre(fila, col, a, alto)) {
          marcar(fila, col, a, alto)
          puesto = true
          break
        }
      }
    }
  }

  if (!ocupado.length) return 0
  // Solo cuentan los huecos de la última fila usada: un hueco intermedio ya lo
  // rellena el navegador con la pieza siguiente que quepa.
  return ocupado[ocupado.length - 1].filter((c) => !c).length
}

export const TIPOS_DESTINO = [
  { id: 'category', etiqueta: 'Una categoría' },
  { id: 'product', etiqueta: 'Un producto' },
  { id: 'url', etiqueta: 'Una dirección web' },
  { id: 'none', etiqueta: 'Ninguno (solo decorativa)' }
]

/** Fila de la base → objeto que entienden los componentes. */
function mapear(fila) {
  return {
    id: fila.id,
    title: fila.title,
    subtitle: fila.subtitle || '',
    badge: fila.badge || '',
    size: fila.size,
    imageUrl: fila.image_url || '',
    imagePath: fila.image_path || '',
    colorDesde: fila.color_desde,
    colorHasta: fila.color_hasta,
    overlay: Number(fila.overlay) || 0,
    textColor: fila.text_color,
    linkType: fila.link_type,
    linkCategory: fila.link_category || '',
    linkProduct: fila.link_product || null,
    linkUrl: fila.link_url || '',
    position: fila.position,
    published: fila.published
  }
}

/** Objeto de la interfaz → fila de la base. */
function aFila(o) {
  const titulo = String(o.title || '').trim()
  if (!titulo) throw new Error('La tarjeta necesita un título.')

  const tipo = o.linkType || 'none'
  if (tipo === 'category' && !String(o.linkCategory || '').trim()) {
    throw new Error('Elige la categoría a la que lleva la tarjeta.')
  }
  if (tipo === 'product' && !o.linkProduct) {
    throw new Error('Elige el producto al que lleva la tarjeta.')
  }
  if (tipo === 'url' && !String(o.linkUrl || '').trim()) {
    throw new Error('Escribe la dirección a la que lleva la tarjeta.')
  }

  return {
    title: titulo,
    subtitle: String(o.subtitle || '').trim() || null,
    badge: String(o.badge || '').trim() || null,
    size: o.size || 'pequena',
    image_url: o.imageUrl || null,
    image_path: o.imagePath || null,
    color_desde: o.colorDesde || '#ff85c1',
    color_hasta: o.colorHasta || '#d291bc',
    overlay: Math.min(80, Math.max(0, Number(o.overlay) || 0)),
    text_color: o.textColor === 'dark' ? 'dark' : 'light',
    link_type: tipo,
    // Se limpian los destinos que no corresponden al tipo elegido: si no, un
    // cambio de "producto" a "categoría" dejaría el producto viejo guardado y
    // el `check` de la base o la próxima edición se comportarían raro.
    link_category: tipo === 'category' ? String(o.linkCategory).trim() : null,
    link_product: tipo === 'product' ? Number(o.linkProduct) : null,
    link_url: tipo === 'url' ? String(o.linkUrl).trim() : null,
    position: Number(o.position) || 0,
    published: o.published === true
  }
}

export const useOffersStore = defineStore('offers', {
  state: () => ({
    ofertas: [],
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    /** Lo que ve la clienta: publicadas, en su orden. */
    publicadas: (state) =>
      state.ofertas.filter((o) => o.published).sort((a, b) => a.position - b.position),

    /** Lo que ve el panel: todo, borradores incluidos. */
    todas: (state) => [...state.ofertas].sort((a, b) => a.position - b.position),

    borradores: (state) => state.ofertas.filter((o) => !o.published).length
  },

  actions: {
    async init() {
      if (this.initialized) return
      await this.load()
      this.initialized = true
    },

    async load() {
      this.loading = true
      this.error = null
      try {
        const { data, error } = await supabase
          .from('home_offers')
          .select('*')
          .order('position')

        if (error) throw new Error('No se pudieron cargar las ofertas de la portada.')
        this.ofertas = (data || []).map(mapear)
      } catch (fallo) {
        this.error = fallo.message
        throw fallo
      } finally {
        this.loading = false
      }
    },

    async save(oferta) {
      const fila = aFila(oferta)

      if (oferta.id) {
        const { data, error } = await supabase
          .from('home_offers').update(fila).eq('id', oferta.id).select().single()
        if (error) throw new Error(`No se pudo guardar la tarjeta: ${error.message}`)
        const i = this.ofertas.findIndex((o) => o.id === oferta.id)
        if (i !== -1) this.ofertas[i] = mapear(data)
        return this.ofertas[i]
      }

      // Una tarjeta nueva va al final y nace como borrador.
      fila.position = this.ofertas.length
        ? Math.max(...this.ofertas.map((o) => o.position)) + 1
        : 1
      const { data, error } = await supabase.from('home_offers').insert(fila).select().single()
      if (error) throw new Error(`No se pudo crear la tarjeta: ${error.message}`)
      const nueva = mapear(data)
      this.ofertas.push(nueva)
      return nueva
    },

    /**
     * Publicar y despublicar. Es una acción aparte de guardar, a propósito:
     * se puede dejar la campaña del viernes lista el martes sin que nadie la
     * vea, y despublicarla cuando acabe sin borrar nada.
     */
    async setPublished(oferta, publicada) {
      const { data, error } = await supabase
        .from('home_offers')
        .update({ published: publicada })
        .eq('id', oferta.id)
        .select()

      if (error) throw new Error(`No se pudo cambiar el estado: ${error.message}`)
      // Con RLS activo, un UPDATE sin permiso no da error: no afecta a nada y
      // parece que guardó. Comprobar que volvió una fila es lo que lo detecta.
      if (!data?.length) {
        throw new Error('No se cambió ninguna tarjeta. Verifica que tu sesión de administrador siga activa.')
      }

      const i = this.ofertas.findIndex((o) => o.id === oferta.id)
      if (i !== -1) this.ofertas[i] = mapear(data[0])
      return this.ofertas[i]
    },

    /** Mueve una tarjeta un puesto arriba o abajo y reescribe el orden. */
    async mover(oferta, direccion) {
      const lista = this.todas
      const i = lista.findIndex((o) => o.id === oferta.id)
      const j = i + (direccion === 'arriba' ? -1 : 1)
      if (i === -1 || j < 0 || j >= lista.length) return

      const reordenada = [...lista]
      ;[reordenada[i], reordenada[j]] = [reordenada[j], reordenada[i]]

      // Se renumera todo de una vez: mantener huecos ("1, 3, 7") es como los
      // órdenes acaban empatados y la portada se recoloca sola.
      const cambios = reordenada.map((o, indice) => ({ id: o.id, position: indice + 1 }))
      for (const c of cambios) {
        const { error } = await supabase
          .from('home_offers').update({ position: c.position }).eq('id', c.id)
        if (error) throw new Error(`No se pudo reordenar: ${error.message}`)
        const k = this.ofertas.findIndex((o) => o.id === c.id)
        if (k !== -1) this.ofertas[k].position = c.position
      }
    },

    /**
     * Borra la tarjeta y su archivo.
     *
     * Aquí sí se borra de verdad, a diferencia de un producto: una tarjeta de
     * portada no aparece en ningún pedido ni movimiento, así que no hay
     * historial que romper. El archivo se borra DESPUÉS de la fila: si el
     * Storage falla, queda un huérfano en el bucket, que es mucho menos grave
     * que una fila apuntando a una imagen que ya no existe.
     */
    async remove(oferta) {
      const { data, error } = await supabase
        .from('home_offers').delete().eq('id', oferta.id).select('id')
      if (error) throw new Error(`No se pudo borrar la tarjeta: ${error.message}`)
      if (!data?.length) throw new Error('No se borró ninguna tarjeta. Verifica tu sesión de administrador.')

      this.ofertas = this.ofertas.filter((o) => o.id !== oferta.id)

      if (oferta.imagePath) {
        const { error: fallo } = await supabase.storage.from(BUCKET).remove([oferta.imagePath])
        if (fallo) console.error('La tarjeta se borró, pero su imagen quedó en el bucket:', fallo.message)
      }
    },

    /**
     * Sube la imagen al mismo bucket que las fotos de producto.
     *
     * Perfil `banner`, no `producto`: estas fotos se ven a ancho completo y
     * una miniatura de catálogo se vería pixelada estirada a 2x2.
     */
    async subirImagen(archivo) {
      const optimizada = await optimizarImagen(archivo, 'banner')
      const id = globalThis.crypto?.randomUUID?.().slice(0, 8) || Math.random().toString(36).slice(2, 10)
      const ruta = `ofertas/${id}-${optimizada.nombre}`

      const { error } = await supabase.storage
        .from(BUCKET)
        .upload(ruta, optimizada.blob, {
          contentType: optimizada.tipo,
          cacheControl: '31536000',
          upsert: false
        })
      if (error) throw new Error(`No se pudo subir la imagen: ${error.message}`)

      const { data } = supabase.storage.from(BUCKET).getPublicUrl(ruta)
      return { url: data.publicUrl, path: ruta, optimizada }
    },

    /** Quita la imagen de una tarjeta y borra el archivo si ya no lo usa nadie. */
    async quitarImagen(oferta) {
      const ruta = oferta.imagePath
      const guardada = await this.save({ ...oferta, imageUrl: '', imagePath: '' })
      if (ruta) {
        const { error } = await supabase.storage.from(BUCKET).remove([ruta])
        if (error) console.error('La imagen se quitó de la tarjeta pero quedó en el bucket:', error.message)
      }
      return guardada
    }
  }
})
