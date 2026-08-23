<script setup>
import { ref } from 'vue'
import {
  Boxes,
  ShoppingCart,
  Store,
  BadgeDollarSign
} from 'lucide-vue-next'
import PurchaseInventory from './PurchaseInventory.vue'
import PurchaseOrders from './PurchaseOrders.vue'
import SaleInventory from './SaleInventory.vue'
import SalesRegister from './SalesRegister.vue'

const activeTab = ref('purchase-inventory')

const tabs = [
  { id: 'purchase-inventory', label: 'Inventario de Compras', icon: Boxes },
  { id: 'purchases', label: 'Compras', icon: ShoppingCart },
  { id: 'sale-inventory', label: 'Inventario de Venta', icon: Store },
  { id: 'sales', label: 'Ventas', icon: BadgeDollarSign }
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
        <component :is="tab.icon" class="size-4" />
        {{ tab.label }}
      </button>
    </div>

    <PurchaseInventory v-if="activeTab === 'purchase-inventory'" />
    <PurchaseOrders v-else-if="activeTab === 'purchases'" />
    <SaleInventory v-else-if="activeTab === 'sale-inventory'" />
    <SalesRegister v-else />
  </div>
</template>