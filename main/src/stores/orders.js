import { defineStore } from 'pinia'
import { isSupabaseConfigured, supabase } from '../lib/supabase'
import { adminOrders } from '../data/mockData'
import { useInventoryStore } from './inventory'

export const useOrdersStore = defineStore('orders', {
  state: () => ({
    orders: [...adminOrders],
    loading: false,
    initialized: false
  }),
  getters: {
    activeOrders: (state) => state.orders.filter((order) => !['returned', 'devuelto', 'entregado', 'cancelado'].includes(String(order.status).toLowerCase())),
    deliveredOrders: (state) => state.orders.filter((order) => ['returned', 'devuelto'].includes(String(order.status).toLowerCase()))
  },
  actions: {
    async init() {
      if (this.initialized) return
      this.loading = true

      try {
        const { data: orders, error } = await supabase
          .from('orders')
          .select('*, customer:customers(*), order_items(*)')
          .order('created_at', { ascending: false })

        if (!error && orders?.length) {
          this.orders = orders.map((order) => ({
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
              productName: item.product_name,
              quantity: item.quantity,
              price: Number(item.unit_price) || 0
            })),
            shipping: Number(order.shipping_cost) || 0,
            status: { pending: 'pendiente', paid: 'pagado', shipped: 'enviado', returned: 'devuelto' }[order.status] || order.status,
            createdAt: order.created_at?.slice(0, 10) || order.date
          }))
        }

        this.initialized = true
      } catch (error) {
        console.error('Error inicializando pedidos desde Supabase:', error)
      } finally {
        this.loading = false
      }
    },

    async addOrder(orderData) {
      const inventoryStore = useInventoryStore()
      const stockValidation = inventoryStore.validateOrderItems(orderData.items || [])

      if (!stockValidation.valid) {
        const failure = stockValidation.issues[0]
        throw new Error(failure?.message || 'No hay suficiente stock para completar este pedido.')
      }

      if (!isSupabaseConfigured) {
        const localId = Date.now()
        const localOrder = {
          id: localId,
          orderNumber: `DEMO-${String(localId).slice(-6)}`,
          customer: orderData.customer,
          items: orderData.items,
          shipping: orderData.shipping,
          status: 'pendiente',
          createdAt: new Date().toISOString().slice(0, 10)
        }
        this.orders.unshift(localOrder)
        return localOrder
      }

      const { data: order, error: orderError } = await supabase.rpc('create_order_with_stock', {
        customer_data: orderData.customer,
        order_data: {
          subtotal: orderData.subtotal,
          shipping: orderData.shipping,
          total: orderData.total
        },
        items_data: orderData.items.map((item) => ({
          product_id: item.productId || null,
          variant_id: item.variantId || null,
          product_name: item.name || item.productName,
          quantity: item.quantity,
          unit_price: item.price
        })),
        payment_method: orderData.paymentMethod || 'transfer'
      }).single()

      if (orderError) throw new Error(orderError.message || 'No se pudo crear el pedido.')

      const newOrder = {
        id: order.order_id,
        orderNumber: order.order_number,
        customer: orderData.customer,
        items: orderData.items,
        shipping: orderData.shipping,
        status: 'pendiente',
        createdAt: new Date().toISOString().slice(0, 10)
      }
      this.orders.unshift(newOrder)
      return newOrder
    },

    async updateStatus(orderId, newStatus) {
      const order = this.orders.find((item) => item.id === orderId)
      const normalizedStatus = String(newStatus || '').toLowerCase()
      const statusMap = {
        pendiente: 'pending',
        pending: 'pending',
        pagado: 'paid',
        paid: 'paid',
        enviado: 'shipped',
        shipped: 'shipped',
        devuelto: 'returned',
        returned: 'returned'
      }
      const databaseStatus = statusMap[normalizedStatus] || normalizedStatus
      const previousStatus = order?.status || ''
      if (order) {
        order.status = newStatus
      }

      if (!isSupabaseConfigured) return

      const { error } = await supabase
        .from('orders')
        .update({ status: databaseStatus, updated_at: new Date().toISOString() })
        .eq('id', orderId)

      if (error) throw new Error('No se pudo actualizar el estado del pedido.')

      if (databaseStatus === 'paid') {
        await supabase
          .from('payments')
          .update({ status: 'paid', updated_at: new Date().toISOString() })
          .eq('order_id', orderId)
      }

      if (databaseStatus === 'shipped') {
        await supabase
          .from('shipments')
          .update({
            status: 'shipped',
            shipped_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
          })
          .eq('order_id', orderId)
      }

      if (databaseStatus === 'returned') {
        const inventoryStore = useInventoryStore()
        await inventoryStore.releaseOrderStock(orderId)
        await supabase
          .from('payments')
          .update({ status: 'refunded', updated_at: new Date().toISOString() })
          .eq('order_id', orderId)
      }

      await supabase.from('audit_logs').insert({
        entity_type: 'order',
        entity_id: orderId,
        action: 'status_changed',
        details: { from: previousStatus, to: newStatus }
      })
    }
  }
})