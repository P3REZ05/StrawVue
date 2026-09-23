import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { useInventoryStore } from './inventory'

// Órdenes de compra al proveedor.
//
// Es el único sitio por el que entra mercancía nueva al negocio. Toda compra
// entra PRIMERO a bodega; el paso a inventario de venta es una transferencia
// aparte y puede ser parcial. Esa regla no está aquí por casualidad: separa
// "lo que tengo" de "lo que estoy vendiendo", que es lo que permite comprar
// cien unidades y sacar veinte a la vitrina.
//
// El stock NO se toca desde aquí. La base inserta los movimientos y los saldos
// se releen. La versión anterior mutaba una copia local a mano y así había dos
// fuentes de verdad para el mismo número.
//
// REGISTRAR Y CORREGIR SON LA MISMA LLAMADA (`save_purchase_order`, migración
// 022). Antes registrar eran tres INSERT seguidos desde el navegador —cabecera,
// líneas, movimientos— y corregir no existía: si tecleabas mal una cantidad,
// la orden quedaba mal para siempre y con ella el costo promedio del que sale
// el margen de los reportes. Ahora es una transacción en la base, y corregir
// escribe movimientos que anulan los anteriores sin borrar una sola fila del
// historial.

function mapear(orden) {
  return {
    id: orden.id,
    orderNumber: orden.order_number || `PO-${orden.id}`,
    supplierId: orden.supplier_id,
    date: orden.order_date,
    notes: orden.notes || '',
    status: orden.status,
    total: Number(orden.total) || 0,
    items: (orden.purchase_order_items || []).map((item) => ({
      productId: item.product_id,
      variantId: item.variant_id,
      quantity: item.quantity,
      costPrice: Number(item.unit_cost) || 0,
      destination: item.destination || 'warehouse'
    }))
  }
}

export const usePurchasesStore = defineStore('purchases', {
  state: () => ({
    purchaseOrders: [],
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    // Lo comprado a un proveedor, para su ficha.
    deProveedor: (state) => (supplierId) =>
      state.purchaseOrders.filter((o) => o.supplierId === Number(supplierId)),

    porId: (state) => (id) => state.purchaseOrders.find((o) => o.id === Number(id))
  },

  actions: {
    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null
      try {
        const { data, error } = await supabase
          .from('purchase_orders')
          .select('*, purchase_order_items(*)')
          .order('id', { ascending: false })

        if (error) throw error
        this.purchaseOrders = (data || []).map(mapear)
        this.initialized = true
      } catch (fallo) {
        this.error = fallo.message || 'No se pudieron cargar las órdenes de compra.'
        throw fallo
      } finally {
        this.loading = false
      }
    },

    /** Vuelve a leer una orden concreta desde la base, con sus líneas. */
    async recargarOrden(id) {
      const { data, error } = await supabase
        .from('purchase_orders')
        .select('*, purchase_order_items(*)')
        .eq('id', id)
        .single()
      if (error) throw new Error(`La compra se guardó pero no se pudo releer: ${error.message}`)

      const orden = mapear(data)
      const i = this.purchaseOrders.findIndex((o) => o.id === orden.id)
      if (i === -1) this.purchaseOrders.unshift(orden)
      else this.purchaseOrders[i] = orden
      return orden
    },

    /**
     * Registra una compra nueva o corrige una existente.
     *
     * `orden.id` nulo = nueva. Con id, la base anula lo que esa orden había
     * metido en bodega y vuelve a meter lo que digan las líneas nuevas, todo
     * en la misma transacción. Si parte de la mercancía ya salió a la vitrina
     * y la corrección dejaría la bodega en negativo, la base lo rechaza con un
     * mensaje que dice cuál es la cantidad mínima posible.
     */
    async savePurchaseOrder(orden) {
      const lineas = (orden.items || []).filter((i) => i.productId && Number(i.quantity) > 0)
      if (!lineas.length) throw new Error('La orden de compra debe tener al menos un producto.')

      const { data, error } = await supabase.rpc('save_purchase_order', {
        p_order_id: orden.id || null,
        p_supplier_id: orden.supplierId || null,
        p_order_number: orden.orderNumber || null,
        p_order_date: orden.date || new Date().toISOString().slice(0, 10),
        p_notes: orden.notes || null,
        p_items: lineas.map((item) => ({
          product_id: Number(item.productId),
          variant_id: item.variantId ? Number(item.variantId) : null,
          quantity: Number(item.quantity),
          unit_cost: Number(item.costPrice) || 0
        }))
      })

      if (error) {
        // El mensaje de la base ya explica qué falta y qué hacer; repetirlo con
        // un "no se pudo registrar la compra" genérico sería tapar el único
        // dato útil.
        throw new Error(error.message || 'No se pudo guardar la compra.')
      }

      await this.recargarOrden(data)

      // Los saldos los calcula la base a partir de los movimientos.
      await useInventoryStore().refreshBalances()
      return data
    },

    /** Compatibilidad con el nombre anterior. Una sola implementación. */
    async addPurchaseOrder(orden) {
      return this.savePurchaseOrder({ ...orden, id: null })
    }
  }
})
