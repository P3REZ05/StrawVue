import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { logAudit } from '../lib/auditLog'
import { registrarImagenProducto, eliminarImagen, marcarPrincipal } from '../lib/storage'

// Store de catálogo: productos, tonos y tablas maestras.
//
// Se separó de `inventory.js` porque son dos responsabilidades distintas y el
// monolito ya rozaba los 40 KB. Aquí vive la ficha comercial; las existencias
// viven en `inventory.js` y se derivan de `inventory_movements`.
//
// REGLA: este store NUNCA escribe stock. Si algo aquí necesita saber cuántas
// unidades hay, se lo pregunta al store de inventario.

// Tablas maestras que alimentan los selectores del formulario de producto.
const TABLAS_MAESTRAS = {
  brands: 'brands',
  skinTypes: 'skin_types',
  finishes: 'finishes',
  coverages: 'coverages',
  undertones: 'undertones',
  shadeFamilies: 'shade_families'
}

// Qué atributos aplican a qué categoría. La arquitectura pide que el
// formulario solo muestre lo que tiene sentido: cobertura únicamente en bases,
// tipo de piel únicamente en cuidado facial.
const ATRIBUTOS_POR_CATEGORIA = {
  skinType: ['cuidado facial', 'skincare'],
  finish: ['bases', 'primer y fijador', 'labios', 'labiales', 'correctores', 'sombras'],
  coverage: ['bases', 'correctores'],
  netContent: ['bases', 'skincare', 'cuidado facial', 'primer y fijador'],
  // El subtono solo tiene sentido donde se busca igualar el tono de piel.
  undertone: ['bases', 'correctores', 'polvos'],
  // La familia cromática aplica al maquillaje de color.
  shadeFamily: ['labios', 'labiales', 'sombras', 'rubores', 'iluminadores']
}

function normalizar(texto) {
  return String(texto || '').trim().toLowerCase()
}

function mapearProducto(fila) {
  return {
    id: fila.id,
    name: fila.name,
    description: fila.description || '',
    category: fila.category || '',
    categoryId: fila.category_id,
    subcategoryId: fila.subcategory_id,
    brandId: fila.brand_id,
    skinTypeId: fila.skin_type_id,
    finishId: fila.finish_id,
    coverageId: fila.coverage_id,
    netContentMl: fila.net_content_ml,
    barcode: fila.barcode || '',
    price: Number(fila.price) || 0,
    salePrice: fila.sale_price != null ? Number(fila.sale_price) : null,
    image: fila.image || '',
    isFeatured: fila.is_featured === true,
    isNew: fila.is_new !== false,
    isRecommended: fila.is_recommended === true,
    status: fila.status || 'draft',
    active: fila.active !== false,
    updatedAt: fila.updated_at
  }
}

function mapearTono(fila) {
  return {
    id: fila.id,
    productId: fila.product_id,
    name: fila.name,
    shadeCode: fila.shade_code || '',
    sku: fila.sku || '',
    barcode: fila.barcode || '',
    // null = hereda el precio del producto. No se convierte a 0: son cosas
    // distintas y confundirlas haría que un tono heredado parezca gratis.
    price: fila.price != null ? Number(fila.price) : null,
    compareAtPrice: fila.compare_at_price != null ? Number(fila.compare_at_price) : null,
    swatchHex: fila.swatch_hex || '',
    swatchImageUrl: fila.swatch_image_url || '',
    undertoneId: fila.undertone_id,
    shadeFamilyId: fila.shade_family_id,
    depth: fila.depth,
    position: fila.position ?? 0,
    isDefault: fila.is_default === true,
    isActive: fila.is_active !== false
  }
}

export const useCatalogStore = defineStore('catalog', {
  state: () => ({
    products: [],
    shades: [],
    images: [],
    categories: [],
    brands: [],
    skinTypes: [],
    finishes: [],
    coverages: [],
    undertones: [],
    shadeFamilies: [],
    // Precios ya resueltos por la base, con la promoción aplicada.
    storefrontShades: [],
    storefrontProducts: [],
    promotions: [],
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    // Categorías raíz y sus hijas, para los dos selectores del formulario.
    rootCategories: (state) => state.categories.filter((c) => !c.parentId && c.active !== false),
    subcategoriesOf: (state) => (parentId) =>
      state.categories.filter((c) => c.parentId === parentId && c.active !== false),

    productById: (state) => (id) => state.products.find((p) => p.id === Number(id)),

    // Tonos de un producto, en el orden en que se exhiben: primero la posición
    // que fijó la administradora, y a igualdad de posición, de más clara a más
    // profunda, que es como se recorre una gama de bases.
    shadesOf: (state) => (productId) =>
      state.shades
        .filter((s) => s.productId === Number(productId) && s.isActive)
        .sort((a, b) => (a.position - b.position) || ((a.depth ?? 999) - (b.depth ?? 999))),

    imagesOf: (state) => (productId, variantId = null) =>
      state.images
        .filter((i) => i.product_id === Number(productId) && (i.variant_id ?? null) === (variantId ?? null))
        .sort((a, b) => a.position - b.position),

    primaryImageOf: (state) => (productId) =>
      state.images.find((i) => i.product_id === Number(productId) && i.is_primary) ||
      state.images.find((i) => i.product_id === Number(productId) && !i.variant_id) || null,

    // Nombre de una opción maestra, para mostrarla sin repetir búsquedas.
    optionName: (state) => (tipo, id) => state[tipo]?.find((o) => o.id === id)?.name || ''
  },

  actions: {
    /** Qué atributos debe mostrar el formulario para una categoría dada. */
    atributosAplicables(nombreCategoria) {
      const cat = normalizar(nombreCategoria)
      const aplica = {}
      for (const [atributo, categorias] of Object.entries(ATRIBUTOS_POR_CATEGORIA)) {
        aplica[atributo] = categorias.includes(cat)
      }
      return aplica
    },

    /** Precio efectivo de un tono: el suyo, o el del producto si hereda. */
    precioDeTono(tono) {
      if (tono?.price != null) return tono.price
      const producto = this.productById(tono?.productId)
      return producto?.salePrice ?? producto?.price ?? 0
    },

    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null

      try {
        const [productos, tonos, imagenes, categorias, vitrinaTonos, vitrinaProductos] = await Promise.all([
          supabase.from('products').select('*').order('id'),
          supabase.from('product_variants').select('*').order('product_id').order('position'),
          supabase.from('product_images').select('*').order('position'),
          supabase.from('categories').select('*').order('name'),
          supabase.from('storefront_shades').select('*'),
          supabase.from('storefront_products').select('*')
        ])

        if (productos.error) throw productos.error
        this.products = (productos.data || []).map(mapearProducto)
        this.shades = (tonos.data || []).map(mapearTono)
        this.images = imagenes.data || []
        this.storefrontShades = vitrinaTonos.data || []
        this.storefrontProducts = vitrinaProductos.data || []
        this.categories = (categorias.data || []).map((c) => ({
          id: c.id,
          name: c.name,
          parentId: c.parent_id,
          image: c.image,
          active: c.active !== false
        }))

        for (const [clave, tabla] of Object.entries(TABLAS_MAESTRAS)) {
          const { data, error } = await supabase.from(tabla).select('*').order('name')
          if (!error) {
            this[clave] = (data || []).map((o) => ({
              id: o.id,
              name: o.name,
              code: o.code || '',
              swatchHex: o.swatch_hex || '',
              active: o.active !== false
            }))
          }
        }

        this.initialized = true
      } catch (error) {
        this.error = error.message || 'No se pudo cargar el catálogo.'
        console.error('Error cargando el catálogo:', error)
        throw error
      } finally {
        this.loading = false
      }
    },

    async refresh() {
      this.initialized = false
      return this.init()
    },

    // ================================================================
    // PRODUCTOS
    // ================================================================

    /** Crea o actualiza un producto. Un solo camino para ambas cosas. */
    async saveProduct(producto) {
      if (!producto.name?.trim()) throw new Error('El nombre del producto es obligatorio.')

      const fila = {
        name: producto.name.trim(),
        description: producto.description || '',
        category: producto.category || '',
        category_id: producto.categoryId || null,
        subcategory_id: producto.subcategoryId || null,
        brand_id: producto.brandId || null,
        skin_type_id: producto.skinTypeId || null,
        finish_id: producto.finishId || null,
        coverage_id: producto.coverageId || null,
        net_content_ml: producto.netContentMl || null,
        barcode: producto.barcode || null,
        price: Number(producto.price) || 0,
        sale_price: producto.salePrice ? Number(producto.salePrice) : null,
        is_featured: producto.isFeatured === true,
        is_new: producto.isNew !== false,
        is_recommended: producto.isRecommended === true,
        status: producto.status || 'draft',
        // La tienda filtra por `active`; el estado de publicación manda sobre él.
        active: (producto.status || 'draft') === 'active'
      }

      if (producto.id) {
        const { data, error } = await supabase.from('products').update(fila).eq('id', producto.id).select().single()
        if (error) throw new Error(`No se pudo actualizar el producto: ${error.message}`)
        const i = this.products.findIndex((p) => p.id === producto.id)
        if (i !== -1) this.products[i] = mapearProducto(data)
        return this.products[i]
      }

      const { data, error } = await supabase.from('products').insert(fila).select().single()
      if (error) throw new Error(`No se pudo crear el producto: ${error.message}`)
      const nuevo = mapearProducto(data)
      this.products.push(nuevo)
      return nuevo
    },

    async setProductStatus(productId, status) {
      const producto = this.productById(productId)
      const anterior = producto?.status
      const { data, error } = await supabase
        .from('products')
        .update({ status, active: status === 'active' })
        .eq('id', productId)
        .select()
        .single()
      if (error) throw new Error(`No se pudo cambiar el estado: ${error.message}`)

      const i = this.products.findIndex((p) => p.id === productId)
      if (i !== -1) this.products[i] = mapearProducto(data)

      await logAudit({
        table: 'products',
        recordId: productId,
        action: 'STATUS_CHANGED',
        oldData: { status: anterior },
        newData: { status },
        note: `Publicación: ${anterior || 'sin estado'} → ${status}`
      })
      return this.products[i]
    },

    /**
     * Archiva en vez de borrar. La arquitectura lo pide explícitamente: un
     * producto histórico aparece en pedidos y movimientos pasados, y borrarlo
     * rompería esa trazabilidad.
     */
    async archiveProduct(productId) {
      return this.setProductStatus(productId, 'archived')
    },

    // ================================================================
    // TABLAS MAESTRAS · creación al vuelo desde el formulario
    // ================================================================

    async saveCategory(categoria) {
      const nombre = categoria.name?.trim()
      if (!nombre) throw new Error('El nombre de la categoría es obligatorio.')

      const fila = {
        name: nombre,
        parent_id: categoria.parentId || null,
        active: categoria.active !== false
      }

      if (categoria.id) {
        const { data, error } = await supabase.from('categories').update(fila).eq('id', categoria.id).select().single()
        if (error) throw new Error(`No se pudo actualizar la categoría: ${error.message}`)
        const i = this.categories.findIndex((c) => c.id === categoria.id)
        if (i !== -1) this.categories[i] = { ...this.categories[i], name: data.name, parentId: data.parent_id, active: data.active }
        return this.categories[i]
      }

      const { data, error } = await supabase.from('categories').insert(fila).select().single()
      if (error) {
        if (error.code === '23505') throw new Error(`Ya existe una categoría llamada "${nombre}".`)
        throw new Error(`No se pudo crear la categoría: ${error.message}`)
      }
      const nueva = { id: data.id, name: data.name, parentId: data.parent_id, active: data.active !== false }
      this.categories.push(nueva)
      return nueva
    },

    /** Crea o actualiza una opción de cualquier tabla maestra. */
    async saveOption(tipo, opcion) {
      const tabla = TABLAS_MAESTRAS[tipo]
      if (!tabla) throw new Error(`Tipo de opción desconocido: ${tipo}`)
      const nombre = opcion.name?.trim()
      if (!nombre) throw new Error('El nombre es obligatorio.')

      const fila = { name: nombre, active: opcion.active !== false }
      if (tipo === 'undertones') fila.code = opcion.code?.trim() || nombre.slice(0, 1).toUpperCase()
      if (tipo === 'shadeFamilies') fila.swatch_hex = opcion.swatchHex || null

      if (opcion.id) {
        const { data, error } = await supabase.from(tabla).update(fila).eq('id', opcion.id).select().single()
        if (error) throw new Error(`No se pudo actualizar: ${error.message}`)
        const i = this[tipo].findIndex((o) => o.id === opcion.id)
        if (i !== -1) this[tipo][i] = { ...this[tipo][i], name: data.name, active: data.active }
        return this[tipo][i]
      }

      const { data, error } = await supabase.from(tabla).insert(fila).select().single()
      if (error) {
        if (error.code === '23505') throw new Error(`"${nombre}" ya existe.`)
        throw new Error(`No se pudo crear: ${error.message}`)
      }
      const nueva = {
        id: data.id,
        name: data.name,
        code: data.code || '',
        swatchHex: data.swatch_hex || '',
        active: data.active !== false
      }
      this[tipo].push(nueva)
      return nueva
    },

    // ================================================================
    // TONOS
    // ================================================================

    /**
     * Sugiere un SKU legible: MARCA-PRODUCTO-CODIGO.
     * Un SKU vacío convierte el inventario en un rompecabezas, así que nunca
     * se deja en blanco: se propone uno y la administradora puede cambiarlo.
     */
    suggestSku(productId, shadeCode) {
      const producto = this.productById(productId)
      if (!producto) return ''
      const trozo = (texto, largo) =>
        String(texto || '')
          .normalize('NFD')
          .replace(/[\u0300-\u036f]/g, '')
          .toUpperCase()
          .replace(/[^A-Z0-9]/g, '')
          .slice(0, largo)

      const marca = trozo(this.optionName('brands', producto.brandId), 4)
      const nombre = trozo(producto.name, 6)
      const codigo = trozo(shadeCode, 6) || String(this.shadesOf(productId).length + 1).padStart(2, '0')
      return [marca, nombre, codigo].filter(Boolean).join('-')
    },

    /**
     * Interpreta una lista de tonos pegada de una hoja de cálculo o de la
     * ficha del proveedor. Cargar 40 tonos de uno en uno no es viable.
     *
     * Formato por línea, separado por tabulaciones, comas o espacios dobles:
     *   codigo · nombre · hex · subtono · profundidad
     * Los tres últimos son opcionales.
     *   01  Marfil  #F5DCC4  C  10
     *   02  Arena   #E8C39E  N  25
     *
     * Devuelve { tonos, errores } sin tocar la base: la idea es previsualizar
     * los chips ya pintados y confirmar después.
     */
    parseShadeList(texto) {
      const tonos = []
      const errores = []
      const lineas = String(texto || '').split(/\r?\n/).map((l) => l.trim()).filter(Boolean)

      lineas.forEach((linea, indice) => {
        const partes = linea.split(/\t|\s{2,}|\s*[;,|]\s*/).map((p) => p.trim()).filter(Boolean)
        if (!partes.length) return

        const numeroLinea = indice + 1
        const hexEncontrado = partes.find((p) => /^#?[0-9a-f]{6}$/i.test(p))
        const hex = hexEncontrado ? (hexEncontrado.startsWith('#') ? hexEncontrado : `#${hexEncontrado}`).toLowerCase() : ''

        const resto = partes.filter((p) => p !== hexEncontrado)

        // Se busca primero contra los códigos reales de subtono (que la
        // administradora puede haber ampliado). Si no hay coincidencia, una
        // letra suelta se trata como un intento de subtono mal escrito: es
        // más útil avisar que pegarla silenciosamente al nombre del tono.
        const codigosValidos = new Set(
          this.undertones.map((u) => String(u.code || '').toUpperCase()).filter(Boolean)
        )
        const codigoSubtono =
          resto.find((p) => codigosValidos.has(p.toUpperCase())) ||
          resto.find((p) => /^[A-Za-z]$/.test(p))

        const profundidadTexto = resto.find((p) => /^\d{1,3}$/.test(p) && p !== resto[0])
        const profundidad = profundidadTexto ? Number(profundidadTexto) : null

        const etiquetas = resto.filter((p) => p !== codigoSubtono && p !== profundidadTexto)
        const codigo = etiquetas.length > 1 ? etiquetas[0] : ''
        const nombre = etiquetas.length > 1 ? etiquetas.slice(1).join(' ') : etiquetas[0]

        if (!nombre) {
          errores.push(`Línea ${numeroLinea}: no se encontró el nombre del tono.`)
          return
        }
        if (profundidad !== null && (profundidad < 1 || profundidad > 100)) {
          errores.push(`Línea ${numeroLinea}: la profundidad debe estar entre 1 y 100.`)
          return
        }

        const subtono = codigoSubtono
          ? this.undertones.find((u) => String(u.code || '').toUpperCase() === codigoSubtono.toUpperCase())
          : null
        if (codigoSubtono && !subtono) {
          const validos = [...codigosValidos].join(', ')
          errores.push(`Línea ${numeroLinea}: subtono "${codigoSubtono}" desconocido. Válidos: ${validos}.`)
          return
        }

        tonos.push({
          shadeCode: codigo,
          name: nombre,
          swatchHex: hex,
          undertoneId: subtono?.id || null,
          depth: profundidad,
          position: tonos.length + 1
        })
      })

      return { tonos, errores }
    },

    /** Crea o actualiza un tono. */
    async saveShade(productId, tono) {
      if (!tono.name?.trim()) throw new Error('El nombre del tono es obligatorio.')
      if (tono.swatchHex && !/^#[0-9a-f]{6}$/i.test(tono.swatchHex)) {
        throw new Error(`"${tono.swatchHex}" no es un color válido. Usa el formato #RRGGBB.`)
      }
      if (tono.depth != null && tono.depth !== '' && (tono.depth < 1 || tono.depth > 100)) {
        throw new Error('La profundidad debe estar entre 1 y 100.')
      }

      const fila = {
        product_id: productId,
        name: tono.name.trim(),
        shade_code: tono.shadeCode?.trim() || null,
        sku: tono.sku?.trim() || this.suggestSku(productId, tono.shadeCode || tono.name),
        barcode: tono.barcode?.trim() || null,
        // null = hereda el precio del producto.
        price: tono.price === '' || tono.price == null ? null : Number(tono.price),
        compare_at_price: tono.compareAtPrice ? Number(tono.compareAtPrice) : null,
        swatch_hex: tono.swatchHex ? tono.swatchHex.toLowerCase() : null,
        swatch_image_url: tono.swatchImageUrl || null,
        undertone_id: tono.undertoneId || null,
        shade_family_id: tono.shadeFamilyId || null,
        depth: tono.depth === '' || tono.depth == null ? null : Number(tono.depth),
        position: tono.position ?? this.shadesOf(productId).length + 1,
        is_active: tono.isActive !== false
      }

      if (tono.id) {
        const { data, error } = await supabase.from('product_variants').update(fila).eq('id', tono.id).select().single()
        if (error) throw new Error(this.explicarErrorTono(error))
        const i = this.shades.findIndex((s) => s.id === tono.id)
        if (i !== -1) this.shades[i] = mapearTono(data)
        return this.shades[i]
      }

      const { data, error } = await supabase.from('product_variants').insert(fila).select().single()
      if (error) throw new Error(this.explicarErrorTono(error))
      const nuevo = mapearTono(data)
      this.shades.push(nuevo)
      return nuevo
    },

    /** Traduce los errores de la base a algo que se entienda. */
    explicarErrorTono(error) {
      const mensaje = error.message || ''
      if (mensaje.includes('product_variants_swatch_hex_check')) return 'El color debe tener el formato #RRGGBB.'
      if (mensaje.includes('product_variants_depth_check')) return 'La profundidad debe estar entre 1 y 100.'
      if (mensaje.includes('ux_product_variants_default')) return 'Ese producto ya tiene un tono marcado por defecto.'
      if (mensaje.includes('ux_product_variants_sku')) return 'Ese SKU ya existe en otro tono.'
      return `No se pudo guardar el tono: ${mensaje}`
    },

    /** Alta por lotes. Se insertan de una sola vez para no hacer 40 viajes. */
    async saveShadesBatch(productId, tonos) {
      if (!tonos?.length) return []

      const desde = this.shadesOf(productId).length
      const filas = tonos.map((tono, indice) => ({
        product_id: productId,
        name: tono.name.trim(),
        shade_code: tono.shadeCode?.trim() || null,
        sku: tono.sku?.trim() || this.suggestSku(productId, tono.shadeCode || tono.name),
        price: tono.price == null || tono.price === '' ? null : Number(tono.price),
        swatch_hex: tono.swatchHex ? tono.swatchHex.toLowerCase() : null,
        undertone_id: tono.undertoneId || null,
        shade_family_id: tono.shadeFamilyId || null,
        depth: tono.depth == null || tono.depth === '' ? null : Number(tono.depth),
        position: desde + indice + 1,
        is_active: true
      }))

      const { data, error } = await supabase.from('product_variants').insert(filas).select()
      if (error) throw new Error(this.explicarErrorTono(error))

      const nuevos = (data || []).map(mapearTono)
      this.shades.push(...nuevos)
      await logAudit({
        table: 'product_variants',
        recordId: productId,
        action: 'SHADES_BATCH_CREATED',
        newData: { cantidad: nuevos.length },
        note: `Se cargaron ${nuevos.length} tonos por lote`
      })
      return nuevos
    },

    /** Marca el tono que se muestra seleccionado al abrir la ficha. */
    async setDefaultShade(productId, shadeId) {
      await supabase.from('product_variants').update({ is_default: false }).eq('product_id', productId).eq('is_default', true)
      const { error } = await supabase.from('product_variants').update({ is_default: true }).eq('id', shadeId)
      if (error) throw new Error(this.explicarErrorTono(error))
      this.shades.forEach((s) => { if (s.productId === productId) s.isDefault = s.id === shadeId })
    },

    /** Reordena la exhibición. Recibe los ids ya en el orden deseado. */
    async reorderShades(productId, idsEnOrden) {
      const actualizaciones = idsEnOrden.map((id, indice) =>
        supabase.from('product_variants').update({ position: indice + 1 }).eq('id', id)
      )
      const resultados = await Promise.all(actualizaciones)
      const fallo = resultados.find((r) => r.error)
      if (fallo) throw new Error('No se pudo guardar el nuevo orden de los tonos.')

      idsEnOrden.forEach((id, indice) => {
        const tono = this.shades.find((s) => s.id === id)
        if (tono) tono.position = indice + 1
      })
    },

    /**
     * Desactiva un tono en vez de borrarlo: puede aparecer en pedidos y
     * movimientos anteriores, y borrarlo rompería esa trazabilidad.
     */
    async deactivateShade(shadeId) {
      const { error } = await supabase.from('product_variants').update({ is_active: false }).eq('id', shadeId)
      if (error) throw new Error(`No se pudo desactivar el tono: ${error.message}`)
      const tono = this.shades.find((s) => s.id === shadeId)
      if (tono) tono.isActive = false
    },

    // ================================================================
    // IMÁGENES
    // ================================================================

    async uploadImage(archivo, { productId, variantId = null, perfil = 'producto', esPrincipal = false, alt = null } = {}) {
      const posicion = this.imagesOf(productId, variantId).length
      const imagen = await registrarImagenProducto(archivo, {
        productId, variantId, perfil, esPrincipal, alt, position: posicion
      })
      if (esPrincipal) this.images.forEach((i) => { if (i.product_id === productId) i.is_primary = false })
      this.images.push(imagen)
      return imagen
    },

    async removeImage(imagen) {
      await eliminarImagen(imagen)
      this.images = this.images.filter((i) => i.id !== imagen.id)
    },

    async setPrimaryImage(imagen) {
      await marcarPrincipal(imagen)
      this.images.forEach((i) => { if (i.product_id === imagen.product_id) i.is_primary = i.id === imagen.id })
    }
  }
})
