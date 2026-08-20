<script setup>
import { ref } from 'vue'
import PurchaseInventory from './PurchaseInventory.vue'
import PurchaseOrders from './PurchaseOrders.vue'
import SaleInventory from './SaleInventory.vue'
import SalesRegister from './SalesRegister.vue'

const activeTab = ref('purchase-inventory')

const tabs = [
  { id: 'purchase-inventory', label: 'Inventario de Compras', icon: 'box' },
  { id: 'purchases', label: 'Compras', icon: 'cart' },
  { id: 'sale-inventory', label: 'Inventario de Venta', icon: 'tag' },
  { id: 'sales', label: 'Ventas', icon: 'cash' }
]
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Inventario</h2>
      <p class="mt-1 text-sm text-neutral-500">Gestiona el catálogo, compras, inventario de venta y ventas físicas.</p>
    </div>

    <!-- Tabs -->
    <div class="flex flex-wrap gap-2">
      <button
        v-for="tab in tabs"
        :key="tab.id"
        class="inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-bold transition"
        :class="activeTab === tab.id ? 'bg-[var(--primary)] text-white shadow-md' : 'bg-white text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
        @click="activeTab = tab.id"
      >
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 8l-9-5-9 5v8l9 5 9-5V8z"/>
          <path d="M3 8l9 5 9-5"/>
          <path d="M12 13v8"/>
          <path d="M3 4h2l2.2 11.1a2 2 0 0 0 2 1.6h7.6a2 2 0 0 0 2-1.6L20 8H7"/>
          <circle cx="10" cy="20" r="1"/>
          <circle cx="17" cy="20" r="1"/>
          <path d="M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L2 12V2h10l8.6 8.6a2 2 0 0 1 0 2.8z"/>
          <circle cx="7" cy="7" r="1.5"/>
          <path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
        </svg>
        {{ tab.label }}
      </button>
    </div>

    <PurchaseInventory v-if="activeTab === 'purchase-inventory'" />
    <PurchaseOrders v-else-if="activeTab === 'purchases'" />
    <SaleInventory v-else-if="activeTab === 'sale-inventory'" />
    <SalesRegister v-else />
  </div>
</template>