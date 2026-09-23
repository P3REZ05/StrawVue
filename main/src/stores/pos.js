import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { logAudit } from '../lib/auditLog'
import { useInventoryStore } from './inventory'

// Venta de mostrador (POS).
//
// El otro canal de venta, junto con el pedido online de `orders.js`. Se
// separan porque son flujos distintos: el pedido pasa por pago y envío, la
// venta de mostrador se cobra y se acabó. Lo que sí comparten es la regla
// importante: el precio y el stock los decide el servidor, nunca el navegador.

export const usePosStore = defineStore('pos', {
  state: () => ({
    sales: [],
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    // Ventas de hoy, para el cierre de caja.
    deHoy: (state) => {
      const hoy = new Date().toISOString().slice(0, 10)
      return state.sales.filter((v) => String(v.date).slice(0, 10) === hoy)
    },
    totalDeHoy() {
      return this.deHoy.reduce((suma, v) => suma + v.total, 0)
    }
  },

  actions: {
    async init() {
      if (this.initialized) return
      await this.loadSales()
      this.initialized = true
    },

    /**
     * Trae las ventas de mostrador desde la base.
     *
     * La versión anterior leía `sale.date` y `item.price`; las columnas son
     * `sale_date` y `unit_price`, así que el historial mostraba la fecha en
     * blanco y cada línea a $0. Como nada fallaba, nadie lo notó.
     */
    async loadSales() {
      this.loading = true
      try {
        const { data, error } = await supabase
          .from('sales')
          .select('*, sale_items(*)')
          .order('id', { ascending: false })

        if (error) throw new Error('No se pudieron cargar las ventas de mostrador.')

        this.sales = (data || []).map((venta) => ({
          id: venta.id,
          number: venta.sale_number || `POS-${venta.id}`,
          date: venta.sale_date,
          customerName: venta.customer_name || '',
          notes: venta.notes || '',
          total: Number(venta.total) || 0,
          paymentMethod: venta.payment_method,
          items: (venta.sale_items || []).map((item) => ({
            productId: item.product_id,
            variantId: item.variant_id,
            quantity: item.quantity,
            price: Number(item.unit_price) || 0
          }))
        }))
        return this.sales
      } finally {
        this.loading = false
      }
    },

    /**
     * Registra una venta de mostrador. Todo el trabajo lo hace el servidor.
     *
     * Antes esto descontaba stock en memoria, insertaba `sales`, luego
     * `sale_items` y luego los movimientos, comprobando cada paso solo con un
     * `console.error`. Cualquier fallo intermedio dejaba una venta a medias
     * —cabecera sin líneas, o venta sin descontar stock— y la interfaz decía
     * que todo había salido bien. Encima el precio salía del navegador.
     *
     * Ahora es una sola llamada atómica (`create_pos_sale`, migración 013):
     * valida el stock con bloqueo por tono, pone el precio del servidor y
     * escribe venta, líneas y movimientos, o no escribe nada.
     */
    async registerSale({ items, paymentMethod, customerName = '', notes = '' }) {
      if (!items?.length) throw new Error('La venta debe tener al menos un producto.')

      const { data, error } = await supabase.rpc('create_pos_sale', {
        items_data: items.map((item) => ({
          product_id: item.productId,
          variant_id: item.variantId ?? null,
          quantity: Number(item.quantity)
        })),
        payment_method: paymentMethod || 'efectivo',
        customer_name: customerName || null,
        notes: notes || null
      })

      if (error) throw new Error(error.message || 'No se pudo registrar la venta.')

      const venta = Array.isArray(data) ? data[0] : data
      if (!venta?.sale_id) throw new Error('La venta no se registró. Revisa el stock e inténtalo de nuevo.')

      // El stock lo derivan los movimientos, así que se relee en vez de
      // ajustarse a mano: cualquier cuenta local acabaría discrepando.
      await Promise.all([useInventoryStore().refreshBalances(), this.loadSales()])

      await logAudit({
        table: 'sales',
        recordId: venta.sale_id,
        action: 'POS_SALE_CREATED',
        newData: { total: venta.total, unidades: venta.unidades, lineas: items.length },
        note: `Venta de mostrador ${venta.sale_number}`
      })

      return venta
    }
  }
})
