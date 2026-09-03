import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { logAudit } from '../lib/auditLog'
import { isActive, isReturned, toDbStatus, toUiStatus } from '../utils/orderStatus'
import { useInventoryStore } from './inventory'

export const useOrdersStore = defineStore('orders', {
  state: () => ({
    orders: [],
    loading: false,
    error: null,
    initialized: false
  }),
  getters: {
    // Pedidos en curso.
    activeOrders: (state) => state.orders.filter((order) => isActive(order.status)),
    // Antes se llamaba `deliveredOrders` pero filtraba devoluciones:
    // el nombre mentía y cualquier reporte que lo usara quedaba mal.
    returnedOrders: (state) => state.orders.filter((order) => isReturned(order.status))
  },
  actions: {
    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null

      try {
        const { data: orders, error } = await supabase
          .from('orders')
          .select('*, customer:customers(*), order_items(*)')
          .order('created_at', { ascending: false })

        if (error) throw error

        this.orders = (orders || []).map((order) => ({
          id: order.id,
          orderNumber: order.order_number,
          customer: {
            name: order.customer?.full_name || '',
            document: order.customer?.document_number || '',
            phone: order.customer?.phone || '',
            city: order.customer?.city || '',
            address: order.customer?.address || '',
            notes: order.customer?.notes || order.notes || ''
          },
          items: (order.order_items || []).map((item) => ({
            productId: item.product_id,
            variantId: item.variant_id,
            productName: item.product_name,
            quantity: item.quantity,
            price: Number(item.unit_price) || 0
          })),
          subtotal: Number(order.subtotal) || 0,
          shipping: Number(order.shipping_cost) || 0,
          total: Number(order.total) || 0,
          status: toUiStatus(order.status),
          createdAt: order.created_at?.slice(0, 10) || ''
        }))

        this.initialized = true
      } catch (error) {
        // Antes esto caía en silencio a datos mock y el admin creía estar
        // viendo pedidos reales. Ahora el error sube a la interfaz.
        this.error = error.message || 'No se pudieron cargar los pedidos.'
        console.error('Error cargando pedidos:', error)
        throw error
      } finally {
        this.loading = false
      }
    },

    async addOrder(orderData) {
      const inventoryStore = useInventoryStore()
      const stockValidation = inventoryStore.validateOrderItems(orderData.items || [])

      if (!stockValidation.valid) {
        throw new Error(stockValidation.issues[0]?.message || 'No hay suficiente stock para completar este pedido.')
      }

      // La reserva real la hace la base en una sola transacción; esta
      // validación previa solo evita un viaje inútil al servidor.
      const { data: order, error } = await supabase.rpc('create_order_with_stock', {
        customer_data: orderData.customer,
        order_data: {
          subtotal: orderData.subtotal,
          shipping: orderData.shipping,
          total: orderData.total
        },
        items_data: (orderData.items || []).map((item) => ({
          product_id: item.productId || item.id || null,
          variant_id: item.variantId || null,
          product_name: item.name || item.productName,
          quantity: item.quantity,
          unit_price: item.price
        })),
        payment_method: orderData.paymentMethod || 'transfer'
      }).single()

      if (error) throw new Error(error.message || 'No se pudo crear el pedido.')

      const newOrder = {
        id: order.order_id,
        orderNumber: order.order_number,
        customer: orderData.customer,
        items: orderData.items,
        subtotal: orderData.subtotal,
        shipping: orderData.shipping,
        total: orderData.total,
        status: 'pendiente',
        createdAt: new Date().toISOString().slice(0, 10)
      }
      this.orders.unshift(newOrder)

      // El stock cambió en la base: refrescar los saldos locales.
      await inventoryStore.refreshBalances()

      return newOrder
    },

    async updateStatus(orderId, newStatus) {
      const order = this.orders.find((item) => item.id === orderId)
      const databaseStatus = toDbStatus(newStatus)
      const previousStatus = order?.status || ''

      // El estado local NO se toca hasta que la base confirme. Antes se
      // mutaba primero y, si la escritura fallaba, la interfaz quedaba
      // mostrando un estado que nunca llegó a persistir.
      const { data: updated, error } = await supabase
        .from('orders')
        .update({ status: databaseStatus })
        .eq('id', orderId)
        .select('id')

      if (error) throw new Error(error.message || 'No se pudo actualizar el estado del pedido.')

      // RLS bloqueado devuelve 0 filas SIN error: hay que comprobarlo a mano.
      if (!updated || updated.length === 0) {
        throw new Error('No se pudo actualizar el pedido. Verifica que tu usuario tenga perfil de administrador.')
      }

      if (databaseStatus === 'paid') {
        const { error: paymentError } = await supabase
          .from('payments').update({ status: 'paid' }).eq('order_id', orderId)
        if (paymentError) throw new Error('El pedido se marcó como pagado, pero no se pudo actualizar el pago.')
      }

      if (databaseStatus === 'shipped') {
        const { error: shipmentError } = await supabase
          .from('shipments')
          .update({ status: 'shipped', shipped_at: new Date().toISOString() })
          .eq('order_id', orderId)
        if (shipmentError) throw new Error('El pedido se marcó como enviado, pero no se pudo actualizar el envío.')
      }

      if (databaseStatus === 'returned') {
        // Reingreso por movimiento compensatorio, no borrando historial.
        // El store de inventario ya refresca los saldos al terminar.
        await useInventoryStore().releaseOrderStock(orderId)
        await supabase.from('payments').update({ status: 'refunded' }).eq('order_id', orderId)
      }

      if (order) order.status = toUiStatus(newStatus)

      await logAudit({
        table: 'orders',
        recordId: orderId,
        action: 'STATUS_CHANGED',
        oldData: { status: toDbStatus(previousStatus) },
        newData: { status: databaseStatus },
        note: `Estado cambiado de ${previousStatus || 'desconocido'} a ${toUiStatus(newStatus)}`
      })

      return true
    }
  }
})
