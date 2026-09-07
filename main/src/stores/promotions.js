import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { logAudit } from '../lib/auditLog'
import { useCatalogStore } from './catalog'

// Store de promociones comerciales.
//
// OJO con el nombre: lo que la sección Configuración llama "promociones" son
// los BANNERS del carrusel del inicio, que son imágenes. Esto es otra cosa:
// descuentos que cambian el precio que paga el cliente.
//
// El precio con descuento lo calcula la base (`precio_efectivo`), no el
// navegador. Aquí solo se administran las reglas.

// El TIPO dice QUÉ descuenta. Que necesite código o no es una propiedad
// aparte, no otro tipo: un cupón puede ser porcentual o de monto fijo.
// Tratarlo como tipo obligaba a duplicar la lógica de cálculo.
export const TIPOS = [
  { value: 'percent',  label: 'Porcentaje de descuento', ayuda: 'Resta un % al precio. Ej: 20 = 20% menos.' },
  { value: 'fixed',    label: 'Monto fijo de descuento', ayuda: 'Resta un valor en pesos al precio.' },
  { value: 'shipping', label: 'Envío gratis',            ayuda: 'Quita el costo de envío desde la compra mínima.' }
]

export const ALCANCES = [
  { value: 'all',      label: 'Todo el catálogo' },
  { value: 'category', label: 'Una categoría' },
  { value: 'products', label: 'Productos elegidos' }
]

function mapear(fila) {
  return {
    id: fila.id,
    title: fila.title,
    label: fila.label || '',
    description: fila.description || '',
    type: fila.type,
    value: Number(fila.value) || 0,
    code: fila.code || '',
    // Con código = cupón: no se aplica solo, el cliente lo escribe.
    requiresCode: Boolean(fila.code),
    minPurchase: fila.min_purchase != null ? Number(fila.min_purchase) : null,
    startsAt: fila.starts_at ? fila.starts_at.slice(0, 10) : '',
    endsAt: fila.ends_at ? fila.ends_at.slice(0, 10) : '',
    priority: fila.priority ?? 0,
    appliesTo: fila.applies_to || 'all',
    categoryId: fila.category_id,
    maxUses: fila.max_uses,
    usesCount: fila.uses_count ?? 0,
    active: fila.active !== false
  }
}

/** Vigencia calculada igual que en la base, para no mentirle a la pantalla. */
function estaVigente(promo) {
  if (!promo.active) return false
  const hoy = new Date().toISOString().slice(0, 10)
  if (promo.startsAt && hoy < promo.startsAt) return false
  if (promo.endsAt && hoy > promo.endsAt) return false
  if (promo.maxUses != null && promo.usesCount >= promo.maxUses) return false
  return true
}

export const usePromotionsStore = defineStore('promotions', {
  state: () => ({
    promotions: [],
    productLinks: [],
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    vigentes: (state) => state.promotions.filter(estaVigente),
    programadas: (state) => state.promotions.filter((p) => {
      const hoy = new Date().toISOString().slice(0, 10)
      return p.active && p.startsAt && hoy < p.startsAt
    }),
    vencidas: (state) => state.promotions.filter((p) => {
      const hoy = new Date().toISOString().slice(0, 10)
      return (p.endsAt && hoy > p.endsAt) || (p.maxUses != null && p.usesCount >= p.maxUses)
    }),
    estado: () => (promo) => {
      if (!promo.active) return { texto: 'Pausada', clase: 'bg-neutral-400' }
      const hoy = new Date().toISOString().slice(0, 10)
      if (promo.startsAt && hoy < promo.startsAt) return { texto: 'Programada', clase: 'bg-blue-500' }
      if (promo.endsAt && hoy > promo.endsAt) return { texto: 'Vencida', clase: 'bg-neutral-500' }
      if (promo.maxUses != null && promo.usesCount >= promo.maxUses) return { texto: 'Agotada', clase: 'bg-amber-500' }
      return { texto: 'Activa', clase: 'bg-emerald-500' }
    },
    productosDe: (state) => (promotionId) =>
      state.productLinks.filter((l) => l.promotion_id === promotionId)
  },

  actions: {
    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null
      try {
        const [promos, enlaces] = await Promise.all([
          supabase.from('promotions').select('*').order('priority', { ascending: false }).order('id'),
          supabase.from('promotion_products').select('*')
        ])
        if (promos.error) throw promos.error
        this.promotions = (promos.data || []).map(mapear)
        this.productLinks = enlaces.data || []
        this.initialized = true
      } catch (error) {
        this.error = error.message || 'No se pudieron cargar las promociones.'
        throw error
      } finally {
        this.loading = false
      }
    },

    async refresh() {
      this.initialized = false
      return this.init()
    },

    /** Valida lo que la base no puede explicar con un mensaje claro. */
    validar(promo) {
      if (!promo.title?.trim()) return 'La promoción necesita un nombre.'
      if (promo.type === 'percent' && (promo.value <= 0 || promo.value > 100)) {
        return 'El porcentaje debe estar entre 1 y 100.'
      }
      if (promo.type === 'fixed' && promo.value <= 0) {
        return 'El monto de descuento debe ser mayor a cero.'
      }
      if (promo.requiresCode && !promo.code?.trim()) {
        return 'Un cupón necesita un código para que el cliente lo escriba.'
      }
      if (promo.requiresCode && promo.type === 'shipping') {
        return 'El envío gratis se aplica solo; no admite código.'
      }
      if (promo.appliesTo === 'category' && !promo.categoryId) {
        return 'Elige la categoría a la que aplica.'
      }
      if (promo.startsAt && promo.endsAt && promo.startsAt > promo.endsAt) {
        return 'La fecha de fin no puede ser anterior a la de inicio.'
      }
      return null
    },

    async save(promo) {
      const problema = this.validar(promo)
      if (problema) throw new Error(problema)

      const fila = {
        title: promo.title.trim(),
        label: promo.label?.trim() || null,
        description: promo.description?.trim() || null,
        type: promo.type,
        value: Number(promo.value) || 0,
        // Una promo CON código no se aplica sola: `promo_para_producto` las
        // excluye a propósito y el RPC solo la usa si el cliente la escribe.
        code: promo.requiresCode && promo.code?.trim() ? promo.code.trim().toUpperCase() : null,
        min_purchase: promo.minPurchase ? Number(promo.minPurchase) : null,
        starts_at: promo.startsAt || null,
        ends_at: promo.endsAt ? `${promo.endsAt}T23:59:59` : null,
        priority: Number(promo.priority) || 0,
        applies_to: promo.appliesTo || 'all',
        category_id: promo.appliesTo === 'category' ? promo.categoryId : null,
        max_uses: promo.maxUses ? Number(promo.maxUses) : null,
        active: promo.active !== false
      }

      let guardada
      if (promo.id) {
        const { data, error } = await supabase.from('promotions').update(fila).eq('id', promo.id).select().single()
        if (error) throw new Error(this.explicar(error))
        guardada = mapear(data)
        const i = this.promotions.findIndex((p) => p.id === promo.id)
        if (i !== -1) this.promotions[i] = guardada
      } else {
        const { data, error } = await supabase.from('promotions').insert(fila).select().single()
        if (error) throw new Error(this.explicar(error))
        guardada = mapear(data)
        this.promotions.push(guardada)
      }

      if (promo.appliesTo === 'products') {
        await this.setProducts(guardada.id, promo.productIds || [])
      }

      await logAudit({
        table: 'promotions',
        recordId: guardada.id,
        action: promo.id ? 'PROMO_UPDATED' : 'PROMO_CREATED',
        newData: { title: guardada.title, type: guardada.type, value: guardada.value },
        note: `${promo.id ? 'Actualizada' : 'Creada'} la promoción "${guardada.title}"`
      })

      return guardada
    },

    explicar(error) {
      if (error.code === '23505' && error.message?.includes('ux_promotions_code')) {
        return 'Ya existe un cupón con ese código.'
      }
      if (error.message?.includes('promotions_type_check')) {
        return 'Ese tipo de promoción no está soportado.'
      }
      return `No se pudo guardar la promoción: ${error.message}`
    },

    /** Reemplaza los productos a los que aplica la promoción. */
    async setProducts(promotionId, productIds) {
      await supabase.from('promotion_products').delete().eq('promotion_id', promotionId)
      if (productIds.length) {
        const filas = productIds.map((id) => ({ promotion_id: promotionId, product_id: Number(id) }))
        const { error } = await supabase.from('promotion_products').insert(filas)
        if (error) throw new Error(`No se pudieron asociar los productos: ${error.message}`)
      }
      const { data } = await supabase.from('promotion_products').select('*')
      this.productLinks = data || []
    },

    async toggle(promo) {
      const { data, error } = await supabase
        .from('promotions')
        .update({ active: !promo.active })
        .eq('id', promo.id)
        .select()
        .single()
      if (error) throw new Error(`No se pudo cambiar el estado: ${error.message}`)
      const i = this.promotions.findIndex((p) => p.id === promo.id)
      if (i !== -1) this.promotions[i] = mapear(data)

      await logAudit({
        table: 'promotions',
        recordId: promo.id,
        action: data.active ? 'PROMO_ACTIVATED' : 'PROMO_PAUSED',
        note: `Promoción "${promo.title}" ${data.active ? 'activada' : 'pausada'}`
      })
      // Cambió un precio del catálogo: la vitrina tiene que releerlo.
      await useCatalogStore().refresh()
      return this.promotions[i]
    },

    async remove(promo) {
      const { error } = await supabase.from('promotions').delete().eq('id', promo.id)
      if (error) throw new Error(`No se pudo eliminar la promoción: ${error.message}`)
      this.promotions = this.promotions.filter((p) => p.id !== promo.id)
      this.productLinks = this.productLinks.filter((l) => l.promotion_id !== promo.id)
      await useCatalogStore().refresh()
    }
  }
})
