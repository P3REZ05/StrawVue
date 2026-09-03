<script setup>
import { computed, onMounted } from 'vue'
import { useInventoryStore } from '../../stores/inventory'
import { useOrdersStore } from '../../stores/orders'
import { formatCurrency } from '../../utils/formatCurrency'

const inventoryStore = useInventoryStore()
const ordersStore = useOrdersStore()
const products = computed(() => inventoryStore.catalogWithStock)
const orders = computed(() => ordersStore.orders)

const totalRevenue = computed(() => {
  return orders.value.reduce((sum, order) => {
    const itemsTotal = (order.items || []).reduce((itemSum, item) => itemSum + Number(item.price || 0) * Number(item.quantity || 0), 0)
    return sum + itemsTotal + Number(order.shipping || 0)
  }, 0)
})

const pendingOrders = computed(() => orders.value.filter((order) => ['pendiente', 'pending'].includes(String(order.status).toLowerCase())).length)
const paidOrders = computed(() => orders.value.filter((order) => ['pagado', 'paid'].includes(String(order.status).toLowerCase())).length)
const shippedOrders = computed(() => orders.value.filter((order) => ['enviado', 'shipped'].includes(String(order.status).toLowerCase())).length)
const returnedOrders = computed(() => orders.value.filter((order) => ['devuelto', 'returned'].includes(String(order.status).toLowerCase())).length)

const lowStockProducts = computed(() => {
  return products.value
    .filter((product) => Number(product.stock || 0) <= 5)
    .slice(0, 5)
})

const bestSellers = computed(() => {
  const salesByProduct = new Map()

  orders.value.forEach((order) => {
    ;(order.items || []).forEach((item) => {
      const key = item.productName || item.name || 'Producto'
      const previous = salesByProduct.get(key) || { name: key, quantity: 0 }
      previous.quantity += Number(item.quantity || 0)
      salesByProduct.set(key, previous)
    })
  })

  return [...salesByProduct.values()].sort((a, b) => b.quantity - a.quantity).slice(0, 5)
})

const recentOrders = computed(() => {
  return [...orders.value]
    .sort((a, b) => new Date(b.createdAt || b.created_at || 0) - new Date(a.createdAt || a.created_at || 0))
    .slice(0, 5)
})

onMounted(async () => {
  try {
    await Promise.all([inventoryStore.init(), ordersStore.init()])
  } catch {
    // El error ya se muestra en AdminPanel.
  }
})
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Dashboard</h2>
      <p class="mt-1 text-sm text-neutral-500">Resumen operativo del negocio y estado general del ecommerce.</p>
    </div>

    <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <article class="rounded-2xl bg-gradient-to-br from-pink-500 to-rose-500 p-4 text-white shadow-sm">
        <p class="text-sm text-pink-100">Ingresos totales</p>
        <p class="mt-2 text-3xl font-bold">{{ formatCurrency(totalRevenue) }}</p>
      </article>
      <article class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <p class="text-sm text-neutral-500">Pedidos pendientes</p>
        <p class="mt-2 text-3xl font-bold text-neutral-800">{{ pendingOrders }}</p>
      </article>
      <article class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <p class="text-sm text-neutral-500">Pagados</p>
        <p class="mt-2 text-3xl font-bold text-neutral-800">{{ paidOrders }}</p>
      </article>
      <article class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <p class="text-sm text-neutral-500">Enviados</p>
        <p class="mt-2 text-3xl font-bold text-neutral-800">{{ shippedOrders }}</p>
      </article>
    </section>

    <section class="grid gap-4 xl:grid-cols-[1.2fr,0.8fr]">
      <div class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <div class="mb-4 flex items-center justify-between">
          <h3 class="text-lg font-bold text-black">Top productos vendidos</h3>
          <span class="text-xs font-medium uppercase tracking-wide text-neutral-400">Últimos pedidos</span>
        </div>
        <div class="space-y-3">
          <div
            v-for="item in bestSellers"
            :key="item.name"
            class="flex items-center justify-between rounded-xl bg-pink-50 px-3 py-2"
          >
            <div>
              <p class="font-semibold text-black">{{ item.name }}</p>
              <p class="text-xs text-neutral-500">Unidades vendidas</p>
            </div>
            <span class="text-lg font-bold text-[var(--primary)]">{{ item.quantity }}</span>
          </div>
          <p v-if="!bestSellers.length" class="text-sm text-neutral-500">Aún no hay ventas registradas.</p>
        </div>
      </div>

      <div class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <h3 class="mb-4 text-lg font-bold text-black">Riesgo de stock</h3>
        <div class="space-y-3">
          <div
            v-for="product in lowStockProducts"
            :key="product.id"
            class="flex items-center justify-between rounded-xl bg-amber-50 px-3 py-2"
          >
            <div>
              <p class="font-semibold text-black">{{ product.name }}</p>
              <p class="text-xs text-neutral-500">{{ product.category }}</p>
            </div>
            <span class="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-bold text-amber-700">{{ product.stock }}</span>
          </div>
          <p v-if="!lowStockProducts.length" class="text-sm text-neutral-500">Todo el inventario está estable.</p>
        </div>
      </div>
    </section>

    <section class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-bold text-black">Pedidos recientes</h3>
        <span class="text-sm text-neutral-500">{{ returnedOrders }} devoluciones</span>
      </div>
      <div class="space-y-3">
        <div
          v-for="order in recentOrders"
          :key="order.id"
          class="flex items-center justify-between border-b border-neutral-100 pb-2 last:border-none last:pb-0"
        >
          <div>
            <p class="font-semibold text-black">Pedido #{{ order.id }}</p>
            <p class="text-xs text-neutral-500">{{ order.customerName || order.customer_name || 'Cliente' }} · {{ order.status }}</p>
          </div>
          <span class="text-sm font-bold text-[var(--primary)]">{{ formatCurrency(order.total || 0) }}</span>
        </div>
        <p v-if="!recentOrders.length" class="text-sm text-neutral-500">No hay pedidos recientes.</p>
      </div>
    </section>
  </div>
</template>
