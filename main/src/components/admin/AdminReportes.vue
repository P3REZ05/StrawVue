<script setup>
import { computed } from 'vue'
import { useInventoryStore } from '../../stores/inventory'
import { useOrdersStore } from '../../stores/orders'
import { formatCurrency } from '../../utils/formatCurrency'

const inventoryStore = useInventoryStore()
const ordersStore = useOrdersStore()

const products = computed(() => inventoryStore.catalogWithStock || [])
const orders = computed(() => ordersStore.orders || [])

const totalRevenue = computed(() => {
  return orders.value.reduce((sum, order) => {
    const itemsTotal = (order.items || []).reduce(
      (itemSum, item) => itemSum + Number(item.price || 0) * Number(item.quantity || 0),
      0
    )
    return sum + itemsTotal + Number(order.shipping || 0)
  }, 0)
})

const totalOrders = computed(() => orders.value.length)
const soldUnits = computed(() => {
  return orders.value.reduce((sum, order) => {
    return sum + (order.items || []).reduce((itemSum, item) => itemSum + Number(item.quantity || 0), 0)
  }, 0)
})

const averageTicket = computed(() => {
  return totalOrders.value ? totalRevenue.value / totalOrders.value : 0
})

const pendingOrders = computed(() => orders.value.filter((order) => ['pendiente', 'pending'].includes(String(order.status).toLowerCase())).length)
const paidOrders = computed(() => orders.value.filter((order) => ['pagado', 'paid'].includes(String(order.status).toLowerCase())).length)
const shippedOrders = computed(() => orders.value.filter((order) => ['enviado', 'shipped'].includes(String(order.status).toLowerCase())).length)
const returnedOrders = computed(() => orders.value.filter((order) => ['devuelto', 'returned'].includes(String(order.status).toLowerCase())).length)

const lowStockCount = computed(() => {
  return products.value.filter((product) => Number(product.stock || 0) <= 5).length
})

const totalStock = computed(() => {
  return products.value.reduce((sum, product) => sum + Number(product.stock || 0), 0)
})

const statusBreakdown = computed(() => {
  const breakdown = { pendiente: 0, pagado: 0, enviado: 0, devuelto: 0 }

  orders.value.forEach((order) => {
    const normalized = String(order.status || '').toLowerCase()
    if (breakdown[normalized] !== undefined) breakdown[normalized] += 1
    else if (normalized === 'pending') breakdown.pendiente += 1
    else if (normalized === 'paid') breakdown.pagado += 1
    else if (normalized === 'shipped') breakdown.enviado += 1
    else if (normalized === 'returned') breakdown.devuelto += 1
  })

  return breakdown
})

const topProducts = computed(() => {
  const salesByProduct = new Map()

  orders.value.forEach((order) => {
    ;(order.items || []).forEach((item) => {
      const key = item.productName || item.name || 'Producto'
      const current = salesByProduct.get(key) || { name: key, units: 0, revenue: 0 }
      current.units += Number(item.quantity || 0)
      current.revenue += Number(item.price || 0) * Number(item.quantity || 0)
      salesByProduct.set(key, current)
    })
  })

  return [...salesByProduct.values()].sort((a, b) => b.units - a.units || b.revenue - a.revenue).slice(0, 5)
})

const operationalAlerts = computed(() => {
  return products.value
    .filter((product) => Number(product.stock || 0) <= 5)
    .slice(0, 4)
    .map((product) => ({
      id: product.id,
      name: product.name,
      stock: Number(product.stock || 0),
      category: product.category || 'Sin categoría'
    }))
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h2 class="text-2xl font-bold text-black">Reportes operativos</h2>
        <p class="mt-1 text-sm text-neutral-500">Visión general del negocio: ventas, pedidos, inventario y riesgo comercial.</p>
      </div>
    </div>

    <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <article class="rounded-2xl bg-gradient-to-br from-pink-500 to-rose-500 p-4 text-white shadow-sm">
        <p class="text-sm text-pink-100">Ingresos</p>
        <p class="mt-2 text-3xl font-bold">{{ formatCurrency(totalRevenue) }}</p>
      </article>
      <article class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <p class="text-sm text-neutral-500">Pedidos</p>
        <p class="mt-2 text-3xl font-bold text-neutral-800">{{ totalOrders }}</p>
      </article>
      <article class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <p class="text-sm text-neutral-500">Unidades vendidas</p>
        <p class="mt-2 text-3xl font-bold text-neutral-800">{{ soldUnits }}</p>
      </article>
      <article class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <p class="text-sm text-neutral-500">Ticket promedio</p>
        <p class="mt-2 text-3xl font-bold text-neutral-800">{{ formatCurrency(averageTicket) }}</p>
      </article>
    </section>

    <section class="grid gap-4 xl:grid-cols-[1.1fr,0.9fr]">
      <div class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <h3 class="mb-4 text-lg font-bold text-black">Estados de pedidos</h3>
        <div class="space-y-3">
          <div class="flex items-center justify-between rounded-xl bg-neutral-50 px-3 py-2">
            <span class="text-sm text-neutral-600">Pendientes</span>
            <span class="text-lg font-bold text-neutral-800">{{ statusBreakdown.pendiente }}</span>
          </div>
          <div class="flex items-center justify-between rounded-xl bg-neutral-50 px-3 py-2">
            <span class="text-sm text-neutral-600">Pagados</span>
            <span class="text-lg font-bold text-neutral-800">{{ statusBreakdown.pagado }}</span>
          </div>
          <div class="flex items-center justify-between rounded-xl bg-neutral-50 px-3 py-2">
            <span class="text-sm text-neutral-600">Enviados</span>
            <span class="text-lg font-bold text-neutral-800">{{ statusBreakdown.enviado }}</span>
          </div>
          <div class="flex items-center justify-between rounded-xl bg-neutral-50 px-3 py-2">
            <span class="text-sm text-neutral-600">Devueltos</span>
            <span class="text-lg font-bold text-neutral-800">{{ statusBreakdown.devuelto }}</span>
          </div>
        </div>
      </div>

      <div class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <h3 class="mb-4 text-lg font-bold text-black">Inventario</h3>
        <div class="space-y-3">
          <div class="flex items-center justify-between rounded-xl bg-pink-50 px-3 py-2">
            <span class="text-sm text-neutral-600">Total stock</span>
            <span class="text-lg font-bold text-[var(--primary)]">{{ totalStock }}</span>
          </div>
          <div class="flex items-center justify-between rounded-xl bg-amber-50 px-3 py-2">
            <span class="text-sm text-neutral-600">Stock crítico</span>
            <span class="text-lg font-bold text-amber-700">{{ lowStockCount }}</span>
          </div>
          <div class="flex items-center justify-between rounded-xl bg-emerald-50 px-3 py-2">
            <span class="text-sm text-neutral-600">Pedidos pagados</span>
            <span class="text-lg font-bold text-emerald-700">{{ paidOrders }}</span>
          </div>
          <div class="flex items-center justify-between rounded-xl bg-sky-50 px-3 py-2">
            <span class="text-sm text-neutral-600">Pedidos enviados</span>
            <span class="text-lg font-bold text-sky-700">{{ shippedOrders }}</span>
          </div>
        </div>
      </div>
    </section>

    <section class="grid gap-4 xl:grid-cols-[1.1fr,0.9fr]">
      <div class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <h3 class="mb-4 text-lg font-bold text-black">Top productos</h3>
        <div class="space-y-3">
          <div
            v-for="product in topProducts"
            :key="product.name"
            class="flex items-center justify-between rounded-xl bg-neutral-50 px-3 py-2"
          >
            <div>
              <p class="font-semibold text-black">{{ product.name }}</p>
              <p class="text-xs text-neutral-500">{{ product.units }} unidades</p>
            </div>
            <span class="text-sm font-bold text-[var(--primary)]">{{ formatCurrency(product.revenue) }}</span>
          </div>
          <p v-if="!topProducts.length" class="text-sm text-neutral-500">Aún no hay ventas registradas.</p>
        </div>
      </div>

      <div class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
        <h3 class="mb-4 text-lg font-bold text-black">Alertas operativas</h3>
        <div class="space-y-3">
          <div
            v-for="item in operationalAlerts"
            :key="item.id"
            class="flex items-center justify-between rounded-xl bg-amber-50 px-3 py-2"
          >
            <div>
              <p class="font-semibold text-black">{{ item.name }}</p>
              <p class="text-xs text-neutral-500">{{ item.category }}</p>
            </div>
            <span class="rounded-full bg-amber-100 px-2 py-1 text-xs font-bold text-amber-700">{{ item.stock }}</span>
          </div>
          <p v-if="!operationalAlerts.length" class="text-sm text-neutral-500">No hay alertas de inventario.</p>
        </div>
      </div>
    </section>

    <section class="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100">
      <h3 class="mb-4 text-lg font-bold text-black">Resumen ejecutivo</h3>
      <ul class="space-y-2 text-sm text-neutral-600">
        <li>• El negocio tiene {{ pendingOrders }} pedidos pendientes y {{ paidOrders }} por confirmar o preparar.</li>
        <li>• {{ shippedOrders }} pedidos ya fueron enviados, y {{ returnedOrders }} han sido devueltos.</li>
        <li>• Hay {{ lowStockCount }} productos con stock en riesgo y requieren revisión de compra o reposición.</li>
        <li>• El ticket promedio se mantiene en {{ formatCurrency(averageTicket) }}, con foco en los productos más vendidos.</li>
      </ul>
    </section>
  </div>
</template>
