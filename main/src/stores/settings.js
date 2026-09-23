import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { optimizarImagen } from '../lib/imageOptimizer'
import { BUCKET } from '../lib/storage'
import { logAudit } from '../lib/auditLog'

/**
 * Ajustes de la tienda y banners de la portada.
 *
 * Antes esto no existía: `AdminConfiguracion.vue` leía de `mockData` y
 * escribía en `localStorage`, y el carrito leía el costo de envío de una
 * constante en ese mismo archivo. El pedido, en cambio, lo cobraba desde
 * `store_settings` vía `config_numero()`. Dos fuentes para el mismo número,
 * y la que veía el cliente no era la que se cobraba.
 *
 * Ahora hay una sola: la tabla. `config_numero()` la lee en el servidor y
 * este store la lee en el navegador.
 */

// Valores de respaldo por si la tabla todavía no tiene una clave. No son
// datos de mentira: son los mismos que sembró `schema.sql`, y evitan que la
// portada quede sin número de WhatsApp si alguien borra una fila.
const POR_DEFECTO = {
  shippingCost: 0,
  freeShippingThreshold: 0,
  whatsappNumber: '',
  socialFacebook: '',
  socialTiktok: '',
  socialInstagram: '',
  // Interruptor de la sección Colecciones de la portada (migración 026). Se
  // guarda como texto porque `store_settings.value` es texto: toda clave que
  // no sea exactamente 'false' cuenta como encendida, así que un valor
  // corrupto deja la sección visible en vez de hacerla desaparecer sin
  // explicación.
  homeCollectionsVisible: 'true'
}

const NUMERICAS = ['shippingCost', 'freeShippingThreshold']

export const useSettingsStore = defineStore('settings', {
  state: () => ({
    valores: { ...POR_DEFECTO },
    banners: [],
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    costoEnvio: (state) => Number(state.valores.shippingCost) || 0,
    umbralEnvioGratis: (state) => Number(state.valores.freeShippingThreshold) || 0,
    whatsapp: (state) => state.valores.whatsappNumber || '',
    /** ¿Se muestra la sección Colecciones en la portada? */
    coleccionesVisibles: (state) => state.valores.homeCollectionsVisible !== 'false',

    redes: (state) => ({
      facebook: state.valores.socialFacebook || '',
      tiktok: state.valores.socialTiktok || '',
      instagram: state.valores.socialInstagram || ''
    }),

    /** Banners visibles en la portada, en su orden. */
    bannersActivos: (state) =>
      state.banners.filter((b) => b.active).sort((a, b) => a.position - b.position),

    /**
     * Envío para un subtotal dado. Es la MISMA regla que aplica el servidor
     * en `create_order_with_stock`: gratis por encima del umbral. Se duplica
     * aquí solo para poder mostrarlo antes de confirmar; quien manda sigue
     * siendo el importe que devuelve el RPC.
     */
    envioPara: (state) => (subtotal) => {
      const umbral = Number(state.valores.freeShippingThreshold) || 0
      const costo = Number(state.valores.shippingCost) || 0
      if (umbral > 0 && Number(subtotal) >= umbral) return 0
      return costo
    }
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
        const [ajustes, banners] = await Promise.all([
          supabase.from('store_settings').select('key, value'),
          supabase.from('home_banners').select('*').order('position')
        ])

        if (ajustes.error) throw new Error('No se pudieron cargar los ajustes de la tienda.')
        if (banners.error) throw new Error('No se pudieron cargar los banners de la portada.')

        const mapa = { ...POR_DEFECTO }
        for (const fila of ajustes.data || []) {
          if (fila.value != null && fila.value !== '') mapa[fila.key] = fila.value
        }
        this.valores = mapa
        this.banners = banners.data || []
      } catch (fallo) {
        this.error = fallo.message
        throw fallo
      } finally {
        this.loading = false
      }
    },

    /**
     * Guarda varias claves de una vez.
     *
     * Se comprueba que el UPDATE devolvió filas: con RLS activo, una
     * escritura sin permiso no da error, simplemente no afecta a nada y
     * parece que guardó. Es la trampa que documenta CLAUDE.md.
     */
    async saveSettings(cambios) {
      const entradas = Object.entries(cambios).filter(([k]) => k in POR_DEFECTO)
      if (!entradas.length) return this.valores

      for (const [clave, valor] of entradas) {
        const texto = String(valor ?? '').trim()

        if (NUMERICAS.includes(clave)) {
          const n = Number(texto)
          if (!Number.isFinite(n) || n < 0) {
            throw new Error(`"${texto}" no es un valor válido para ${clave}.`)
          }
        }

        const { data, error } = await supabase
          .from('store_settings')
          .upsert({ key: clave, value: texto }, { onConflict: 'key' })
          .select('key')

        if (error) throw new Error(`No se pudo guardar ${clave}: ${error.message}`)
        if (!data?.length) {
          throw new Error(`No se guardó ${clave}: la base rechazó la escritura sin dar error. Revisa tu sesión de administrador.`)
        }
      }

      await this.load()
      await logAudit({
        table: 'store_settings',
        recordId: null,
        action: 'SETTINGS_UPDATED',
        newData: Object.fromEntries(entradas),
        note: `Ajustes actualizados: ${entradas.map(([k]) => k).join(', ')}`
      })
      return this.valores
    },

    // ================================================================
    // Banners de la portada
    // ================================================================

    /**
     * Sube la imagen del banner al mismo bucket que las fotos de producto.
     *
     * Antes la imagen se guardaba como base64 dentro de `localStorage`: solo
     * existía en el navegador que la subió, y dos o tres fotos agotaban la
     * cuota de ~5 MB. Ahora es un archivo real con URL pública.
     */
    async subirImagenBanner(archivo) {
      const optimizada = await optimizarImagen(archivo, 'producto')
      const id = globalThis.crypto?.randomUUID?.().slice(0, 8) || Math.random().toString(36).slice(2, 10)
      const ruta = `banners/${id}-${optimizada.nombre}`

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

    async saveBanner(banner) {
      if (!banner.title?.trim()) throw new Error('El banner necesita un título.')

      const fila = {
        title: banner.title.trim(),
        subtitle: banner.subtitle?.trim() || null,
        accent: banner.accent?.trim() || null,
        link: banner.link?.trim() || '/tienda',
        image_url: banner.image_url || null,
        image_path: banner.image_path || null,
        position: banner.position ?? this.banners.length + 1,
        active: banner.active !== false
      }

      if (banner.id) {
        const { data, error } = await supabase
          .from('home_banners').update(fila).eq('id', banner.id).select().single()
        if (error) throw new Error(`No se pudo actualizar el banner: ${error.message}`)
        const i = this.banners.findIndex((b) => b.id === banner.id)
        if (i !== -1) this.banners[i] = data
        return data
      }

      const { data, error } = await supabase.from('home_banners').insert(fila).select().single()
      if (error) throw new Error(`No se pudo crear el banner: ${error.message}`)
      this.banners.push(data)
      return data
    },

    async toggleBanner(banner) {
      return this.saveBanner({ ...banner, active: !banner.active })
    },

    /**
     * Borra el banner y su archivo.
     *
     * Aquí sí se borra de verdad, a diferencia de los productos: un banner no
     * aparece en ningún pedido ni movimiento, así que no hay historial que
     * romper. El archivo se borra después de la fila: si el Storage falla,
     * queda un huérfano en el bucket, que es mucho menos grave que una fila
     * apuntando a una imagen que ya no existe.
     */
    async deleteBanner(banner) {
      const { error } = await supabase.from('home_banners').delete().eq('id', banner.id)
      if (error) throw new Error(`No se pudo borrar el banner: ${error.message}`)
      this.banners = this.banners.filter((b) => b.id !== banner.id)

      if (banner.image_path) {
        const { error: fallo } = await supabase.storage.from(BUCKET).remove([banner.image_path])
        if (fallo) console.error('El banner se borró, pero su imagen quedó en el bucket:', fallo.message)
      }
    }
  }
})
