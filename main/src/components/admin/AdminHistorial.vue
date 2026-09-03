<script setup>
import { storeToRefs } from 'pinia'
import { useOrdersStore } from '../../stores/orders'
import { formatCurrency } from '../../utils/formatCurrency'

const ordersStore = useOrdersStore()
const { returnedOrders } = storeToRefs(ordersStore)

function orderSubtotal(order) {
  return order.items.reduce((sum, item) => sum + item.price * item.quantity, 0)
}

function orderTotal(order) {
  return orderSubtotal(order) + order.shipping
}
</script>

<template>
  <div class="space-y-6">
    <h2 class="text-2xl font-bold text-black">Historial de Pedidos Entregados</h2>
    <p class="text-sm text-neutral-500">Aquí aparecen automáticamente los pedidos que se marcan como <strong class="text-emerald-600">entregado</strong> en la sección de Pedidos.</p>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-200 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Orden ID</th>
            <th class="px-5 py-4">Orden #</th>
            <th class="px-5 py-4">Cliente</th>
            <th class="px-5 py-4">Ciudad</th>
            <th class="px-5 py-4">Total</th>
            <th class="px-5 py-4">Fecha</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="order in returnedOrders" :key="order.id" class="border-b border-pink-50 transition hover:bg-pink-50/50">
            <td class="px-5 py-4 font-semibold">{{ order.id }}</td>
            <td class="px-5 py-4">{{ order.orderNumber }}</td>
            <td class="px-5 py-4">{{ order.customer?.name || 'N/A' }}</td>
            <td class="px-5 py-4">{{ order.customer?.city || 'N/A' }}</td>
            <td class="px-5 py-4 font-bold text-[var(--primary)]">{{ formatCurrency(orderTotal(order)) }}</td>
            <td class="px-5 py-4">{{ order.createdAt }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!returnedOrders.length" class="p-10 text-center text-neutral-500">
        No hay pedidos entregados todavía.
      </p>
    </div>
  </div>
</template>