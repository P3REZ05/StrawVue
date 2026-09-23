import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { subirImagenSuelta, borrarArchivo } from '../lib/storage'

/**
 * COLECCIONES.
 *
 * El tercer eje del catálogo. Las categorías dicen QUÉ es un producto (base,
 * labial, rubor) y la marca dice QUIÉN lo hace; la colección dice CON QUÉ VA:
 * «Colección Alisia» son doce productos de categorías distintas que se venden
 * juntos porque la clienta los busca juntos.
 *
 * En la portada, cada colección publicada es una fila propia: su título, su
 * subtítulo y un carrusel con SUS PRODUCTOS —foto, precio y botón, las mismas
 * tarjetas de la tienda—, con flechas para recorrerlo. Al final de la fila,
 * un enlace que abre la tienda filtrada por ella.
 *
 * POR QUÉ UN STORE PROPIO Y NO UNA PARTE DE `catalog.js`
 *
 * Porque la tienda pública lo necesita y el panel no siempre. `catalog.js`
 * carga en cada visita productos, tonos, imágenes, seis tablas maestras y las
 * etiquetas; meter aquí las colecciones significaría que la portada no puede
 * pintar la sección sin arrastrar todo eso. Son 60 líneas de tabla y se
 * cargan solas en una consulta.
 *
 * La relación producto → colección sí vive en `catalog.js`, porque es una
 * columna de `products` (`collection_id`, migración 026). Este store no
 * escribe productos nunca.
 */

function mapear(fila) {
  return {
    id: fila.id,
    name: fila.name,
    slug: fila.slug,
    description: fila.description || '',
    imageUrl: fila.image_url || '',
    imagePath: fila.image_path || '',
    position: fila.position ?? 0,
    published: fila.published === true
  }
}

export const useCollectionsStore = defineStore('collections', {
  state: () => ({
    items: [],
    initialized: false
  }),

  getters: {
    /**
     * Las publicadas, en orden. Es lo que pinta la portada y lo que ofrece el
     * desplegable de la tienda.
     *
     * No se exige que tenga foto: lo que enseña una colección son sus
     * productos, y la foto de cabecera es opcional. Una colección publicada
     * sin productos no la pinta la portada —eso lo decide `HomeCollections`,
     * que es quien sabe del catálogo—, pero sí sale en el filtro.
     */
    publicadas: (state) =>
      state.items
        .filter((c) => c.published)
        .sort((a, b) => (a.position - b.position) || a.name.localeCompare(b.name)),

    /** Todas, en el mismo orden. Para la pantalla del panel. */
    ordenadas: (state) =>
      [...state.items].sort((a, b) => (a.position - b.position) || a.name.localeCompare(b.name)),

    porSlug: (state) => (slug) => state.items.find((c) => c.slug === slug) || null,
    porId: (state) => (id) => state.items.find((c) => c.id === Number(id)) || null
  },

  actions: {
    async init() {
      if (this.initialized) return
      await this.load()
      this.initialized = true
    },

    /**
     * Carga todas las que la sesión pueda ver.
     *
     * No se filtra por `published` en la consulta: de eso ya se encarga RLS.
     * Una clienta recibe solo las publicadas porque la política lo dice, y la
     * administradora las recibe todas con la misma llamada.
     */
    async load() {
      const { data, error } = await supabase
        .from('collections').select('*').order('position').order('name')
      if (error) throw new Error(`No se pudieron cargar las colecciones: ${error.message}`)
      this.items = (data || []).map(mapear)
    },

    /**
     * Crea o actualiza. Un solo camino para las dos cosas, como en el resto
     * del proyecto.
     *
     * El `slug` NO se manda: lo calcula un disparador de la base (migración
     * 026). Es la lección de las etiquetas —el navegador no puede garantizar
     * que una clave sea única porque no ve todas las filas, y ahí salió el
     * `duplicate key value violates unique constraint`.
     */
    async save(coleccion) {
      const nombre = String(coleccion.name || '').trim()
      if (!nombre) throw new Error('La colección necesita un nombre.')
      if (nombre.length > 60) throw new Error('El nombre no puede pasar de 60 caracteres.')

      const fila = {
        name: nombre,
        description: String(coleccion.description || '').trim() || null,
        image_url: coleccion.imageUrl || null,
        image_path: coleccion.imagePath || null,
        published: coleccion.published === true
      }

      if (coleccion.id) {
        const { data, error } = await supabase
          .from('collections').update(fila).eq('id', coleccion.id).select().single()
        if (error) throw new Error(`No se pudo guardar la colección: ${error.message}`)
        const i = this.items.findIndex((c) => c.id === coleccion.id)
        if (i !== -1) this.items[i] = mapear(data)
        return mapear(data)
      }

      // Al final de la fila. Sin esto todas nacen con posición 0 y el orden lo
      // acaba decidiendo el desempate por nombre, que no es lo que la
      // administradora ve al pulsar las flechas.
      fila.position = this.items.length
        ? Math.max(...this.items.map((c) => c.position)) + 1
        : 1

      const { data, error } = await supabase.from('collections').insert(fila).select().single()
      if (error) {
        if (error.code === '23505') throw new Error(`Ya existe una colección llamada "${nombre}".`)
        throw new Error(`No se pudo crear la colección: ${error.message}`)
      }
      const nueva = mapear(data)
      this.items.push(nueva)
      return nueva
    },

    /** Publicar o retirar de la tienda. */
    async togglePublicada(coleccion) {
      const { data, error } = await supabase
        .from('collections')
        .update({ published: !coleccion.published })
        .eq('id', coleccion.id)
        .select()
        .single()

      if (error) throw new Error(`No se pudo cambiar la visibilidad: ${error.message}`)
      // Con RLS activo una escritura sin permiso no da error: no afecta a
      // ninguna fila y parece que guardó. `.single()` lo convierte en error,
      // que es justo lo que se quiere.
      const i = this.items.findIndex((c) => c.id === coleccion.id)
      if (i !== -1) this.items[i] = mapear(data)
      return mapear(data)
    },

    /**
     * Pone o quita la foto de cabecera. `archivo` a null la quita.
     *
     * El archivo anterior se borra DESPUÉS de que la base confirme el cambio.
     * En ese orden: si se borrara primero y fallara el guardado, la colección
     * se quedaría sin imagen y sin forma de recuperarla.
     */
    async setImagen(collectionId, archivo = null) {
      const coleccion = this.porId(collectionId)
      if (!coleccion) throw new Error('No se encontró la colección.')

      const subida = archivo
        ? await subirImagenSuelta(archivo, 'colecciones', coleccion.name)
        : null

      const { data, error } = await supabase
        .from('collections')
        .update({ image_url: subida?.url ?? null, image_path: subida?.storage_path ?? null })
        .eq('id', coleccion.id)
        .select()
        .single()

      if (error) {
        // El archivo ya está en el bucket pero ninguna fila lo apunta: se
        // retira para no dejar basura ocupando la cuota del plan gratuito.
        if (subida) await borrarArchivo(subida.storage_path).catch(() => {})
        throw new Error(`No se pudo guardar la imagen: ${error.message}`)
      }

      const anterior = coleccion.imagePath
      const i = this.items.findIndex((c) => c.id === coleccion.id)
      if (i !== -1) this.items[i] = mapear(data)
      if (anterior && anterior !== data.image_path) await borrarArchivo(anterior).catch(() => {})

      return { ...mapear(data), optimizacion: subida?.optimizacion }
    },

    /**
     * Mueve una colección en la portada.
     *
     * Se reescriben TODAS las posiciones, no solo las dos que se intercambian:
     * con posiciones repetidas o con huecos el orden acaba dependiendo de cómo
     * desempate la base, y deja de ser reproducible. Es lo mismo que se hizo
     * con los banners.
     */
    async mover(collectionId, direccion) {
      const orden = this.ordenadas
      const i = orden.findIndex((c) => c.id === Number(collectionId))
      const j = i + (direccion === 'arriba' ? -1 : 1)
      if (i === -1 || j < 0 || j >= orden.length) return

      const movidas = [...orden]
      const [movida] = movidas.splice(i, 1)
      movidas.splice(j, 0, movida)

      // `upsert` necesita las columnas obligatorias de la tabla: `name` es
      // `not null`, así que va en cada fila aunque no cambie.
      const filas = movidas.map((c, indice) => ({ id: c.id, name: c.name, position: indice + 1 }))
      const { error } = await supabase.from('collections').upsert(filas, { onConflict: 'id' })
      if (error) throw new Error(`No se pudo reordenar: ${error.message}`)

      filas.forEach((fila) => {
        const item = this.items.find((c) => c.id === fila.id)
        if (item) item.position = fila.position
      })
    },

    /**
     * Borra la colección.
     *
     * Sus productos NO se borran: `on delete set null` en la migración 026 los
     * deja sueltos, con `collection_id` a null. Quitar una campaña de la
     * portada no puede vaciarte el catálogo.
     *
     * Quien llama debe avisar de cuántos productos quedan sueltos — la
     * pantalla del panel lo hace en el modal de confirmación.
     */
    async remove(coleccion) {
      const { error } = await supabase.from('collections').delete().eq('id', coleccion.id)
      if (error) throw new Error(`No se pudo borrar la colección: ${error.message}`)

      this.items = this.items.filter((c) => c.id !== coleccion.id)
      if (coleccion.imagePath) await borrarArchivo(coleccion.imagePath).catch(() => {})

      // Sin `logAudit`: el disparador `trg_collections_audit` de la migración
      // 026 ya registra este DELETE con la fila entera. Escribirlo también
      // desde aquí haría que la trazabilidad contara el mismo borrado dos
      // veces, que es el error que ya se corrigió en `setProductStatus`.
      return true
    }
  }
})
