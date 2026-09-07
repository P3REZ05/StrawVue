import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { logAudit } from '../lib/auditLog'
import { subirComprobante, verComprobante } from '../lib/storage'
import { isActive, isClosed, isDelivered, isReturned, toDbStatus, toUiStatus } from '../utils/orderStatus'
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
    returnedOrders: (state) => state.orders.filter((order) => isReturned(order.status)),
    deliveredOrders: (state) => state.orders.filter((order) => isDelivered(order.status)),
    // Todo lo que ya cerró su ciclo, para el historial.
    closedOrders: (state) => state.orders.filter((order) => isClosed(order.status))
  },
  actions: {
    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null

      try {
        const { data: orders, error } = await supabase
          .from('orders')
          .select('*, customer:customers(*), order_items(*), payments(*), shipments(*)')
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
          createdAt: order.created_at?.slice(0, 10) || '',
          // El pago y el envio viajan con el pedido: sin ellos el panel no
          // puede cerrar el ciclo ni decirle al cliente donde va su compra.
          payment: order.payments?.[0]
            ? {
                id: order.payments[0].id,
                method: order.payments[0].payment_method,
                status: order.payments[0].status,
                amount: Number(order.payments[0].amount) || 0,
                proofPath: order.payments[0].proof_url || '',
                proofName: order.payments[0].proof_name || '',
                reference: order.payments[0].reference_code || ''
              }
            : null,
          shipment: order.shipments?.[0]
            ? {
                id: order.shipments[0].id,
                carrier: order.shipments[0].carrier || '',
                tracking: order.shipments[0].tracking_number || '',
                estimated: order.shipments[0].estimated_delivery || '',
                shippedAt: order.shipments[0].shipped_at || '',
                deliveredAt: order.shipments[0].delivered_at || '',
                status: order.shipments[0].status || 'pending'
              }
            : null
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

    /**
     * Crea el pedido.
     *
     * El cliente manda QUÉ quiere y CUÁNTO; el precio lo decide el servidor.
     * Antes se enviaba `unit_price` y `total` desde el navegador, así que
     * cualquiera podía pedir una base de $38.900 por $1. Con promociones eso
     * empeoraba: un total distinto al de lista dejaba de ser sospechoso.
     *
     * Devuelve los importes que realmente quedaron guardados, para que la
     * interfaz muestre lo mismo que la base y no su propia estimación.
     */
    async addOrder(orderData) {
      const inventoryStore = useInventoryStore()
      const stockValidation = inventoryStore.validateOrderItems(orderData.items || [])

      if (!stockValidation.valid) {
        throw new Error(stockValidation.issues[0]?.message || 'No hay suficiente stock para completar este pedido.')
      }

      const { data: order, error } = await supabase.rpc('create_order_with_stock', {
        customer_data: orderData.customer,
        // Solo el cupón viaja aquí: los importes los calcula la base.
        order_data: { coupon: orderData.coupon || null },
        items_data: (orderData.items || []).map((item) => ({
          product_id: item.productId || item.id || null,
          variant_id: item.variantId || null,
          quantity: item.quantity
        })),
        payment_method: orderData.paymentMethod || 'transfer'
      }).single()

      if (error) throw new Error(error.message || 'No se pudo crear el pedido.')

      const newOrder = {
        id: order.order_id,
        orderNumber: order.order_number,
        customer: orderData.customer,
        items: orderData.items,
        subtotal: Number(order.subtotal) || 0,
        discount: Number(order.discount) || 0,
        shipping: Number(order.shipping) || 0,
        total: Number(order.total) || 0,
        promoNote: order.promo_note || '',
        status: 'pendiente',
        createdAt: new Date().toISOString().slice(0, 10)
      }
      this.orders.unshift(newOrder)

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

      if (databaseStatus === 'delivered') {
        const { error: entregaError } = await supabase
          .from('shipments')
          .update({ status: 'delivered', delivered_at: new Date().toISOString() })
          .eq('order_id', orderId)
        if (entregaError) throw new Error('El pedido se marcó como entregado, pero no se pudo cerrar el envío.')
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
    },

    /** Guarda transportadora, guía y fecha estimada del envío. */
    async saveShipment(orderId, { carrier, tracking, estimated } = {}) {
      const { data, error } = await supabase
        .from('shipments')
        .update({
          carrier: carrier?.trim() || null,
          tracking_number: tracking?.trim() || null,
          estimated_delivery: estimated || null
        })
        .eq('order_id', orderId)
        .select()
        .single()

      if (error) throw new Error(`No se pudieron guardar los datos del envío: ${error.message}`)

      const pedido = this.orders.find((o) => o.id === orderId)
      if (pedido) {
        pedido.shipment = {
          ...(pedido.shipment || {}),
          id: data.id,
          carrier: data.carrier || '',
          tracking: data.tracking_number || '',
          estimated: data.estimated_delivery || '',
          status: data.status
        }
      }

      await logAudit({
        table: 'shipments',
        recordId: data.id,
        action: 'SHIPPING_UPDATED',
        newData: { carrier: data.carrier, tracking: data.tracking_number },
        note: `Envío actualizado: ${data.carrier || 'sin transportadora'} ${data.tracking_number || ''}`.trim()
      })

      return pedido?.shipment
    },

    /** Sube el comprobante de pago al bucket privado y lo enlaza. */
    async uploadPaymentProof(orderId, archivo, referencia = null) {
      const pedido = this.orders.find((o) => o.id === orderId)
      const pago = await subirComprobante(archivo, {
        orderId,
        paymentId: pedido?.payment?.id,
        referencia
      })

      if (pedido) {
        pedido.payment = {
          ...(pedido.payment || {}),
          id: pago.id,
          proofPath: pago.proof_url,
          proofName: pago.proof_name,
          reference: pago.reference_code || ''
        }
      }

      await logAudit({
        table: 'payments',
        recordId: pago.id,
        action: 'PROOF_UPLOADED',
        newData: { proof_name: pago.proof_name },
        note: 'Comprobante de pago adjuntado'
      })

      return pedido?.payment
    },

    /** URL temporal para ver el comprobante. El bucket es privado. */
    async getProofUrl(orderId) {
      const pedido = this.orders.find((o) => o.id === orderId)
      if (!pedido?.payment?.proofPath) return null
      return verComprobante(pedido.payment.proofPath)
    }
  }
})
