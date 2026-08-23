<script setup>
import { computed } from 'vue'
import { useInventoryStore } from '../../../stores/inventory'
import { formatCurrency } from '../../../utils/formatCurrency'

const store = useInventoryStore()
const movements = computed(() => store.movements)
const typeLabels = { purchase: 'Compra', online_order: 'Pedido online', transfer: 'Transferencia', sale: 'Venta', return: 'Devolución', adjustment: 'Ajuste', damage: 'Daño' }

function productName(movement) {
  return store.catalog.find((product) => product.id === movement.productId)?.name || 'Producto eliminado'
}

function variantName(movement) {
  return store.variants.find((variant) => variant.id === movement.variantId)?.name || ''
}

function formatDate(value) {
  return value ? new Date(value).toLocaleString('es-CO', { dateStyle: 'short', timeStyle: 'short' }) : '—'
}
</script>

<template>
  <div class="space-y-6">
    <div><h2 class="text-2xl font-bold text-black">Historial de movimientos</h2><p class="mt-1 text-sm text-neutral-500">Consulta cada entrada, salida y transferencia de inventario.</p></div>
    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm"><table class="w-full min-w-220 text-sm"><thead><tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500"><th class="px-5 py-4">Fecha</th><th class="px-5 py-4">Producto</th><th class="px-5 py-4">Variante</th><th class="px-5 py-4">Tipo</th><th class="px-5 py-4">Cantidad</th><th class="px-5 py-4">Costo unitario</th><th class="px-5 py-4">Referencia</th></tr></thead><tbody><tr v-for="movement in movements" :key="movement.id" class="border-b border-pink-50"><td class="whitespace-nowrap px-5 py-4 text-neutral-500">{{ formatDate(movement.createdAt) }}</td><td class="px-5 py-4 font-semibold">{{ productName(movement) }}</td><td class="px-5 py-4">{{ variantName(movement) || 'Producto base' }}</td><td class="px-5 py-4"><span class="rounded-full bg-pink-100 px-3 py-1 text-xs font-bold text-[var(--primary)]">{{ typeLabels[movement.type] || movement.type }}</span></td><td class="px-5 py-4 font-bold" :class="movement.quantity >= 0 ? 'text-emerald-600' : 'text-red-500'">{{ movement.quantity > 0 ? '+' : '' }}{{ movement.quantity }}</td><td class="px-5 py-4">{{ formatCurrency(movement.unitCost) }}</td><td class="px-5 py-4 text-neutral-500">{{ movement.referenceType || '—' }}{{ movement.referenceId ? ` #${movement.referenceId}` : '' }}</td></tr></tbody></table><p v-if="!movements.length" class="p-10 text-center text-neutral-500">Aún no hay movimientos registrados.</p></div>
  </div>
</template>
