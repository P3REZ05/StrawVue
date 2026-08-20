import { defineStore } from 'pinia'
import { adminOrders } from '../data/mockData'

export const useOrdersStore = defineStore('orders', {
  state: () => ({
    orders: [...adminOrders]
  }),
  getters: {
    activeOrders: (state) => state.orders.filter((order) => order.status !== 'entregado'),
    deliveredOrders: (state) => state.orders.filter((order) => order.status === 'entregado')
  },
  actions: {
    updateStatus(orderId, newStatus) {
      const order = this.orders.find((item) => item.id === orderId)
      if (order) {
        order.status = newStatus
      }
    }
  }
})