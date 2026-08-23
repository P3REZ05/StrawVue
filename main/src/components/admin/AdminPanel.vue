<script setup>
import { onMounted, ref } from 'vue'
import {
  BarChart3,
  Boxes,
  ChartColumnBig,
  ClipboardList,
  Package,
  Settings,
  ShieldCheck,
  ShoppingCart,
  Truck,
  LayoutDashboard,
  History
} from 'lucide-vue-next'
import { useInventoryStore } from '../../stores/inventory'
import { useOrdersStore } from '../../stores/orders'
import { useAdminStore } from '../../stores/admin'
import AdminDashboard from './AdminDashboard.vue'
import AdminProductos from './AdminProductos.vue'
import AdminPedidos from './AdminPedidos.vue'
import AdminHistorial from './AdminHistorial.vue'
import AdminReportes from './AdminReportes.vue'
import AdminConfiguracion from './AdminConfiguracion.vue'
import InventorySection from './inventory/InventorySection.vue'
import AuditLogs from './inventory/AuditLogs.vue'
import Suppliers from './inventory/Suppliers.vue'
import MovementHistory from './inventory/MovementHistory.vue'

const activeSection = ref('dashboard')
const adminStore = useAdminStore()
const inventoryStore = useInventoryStore()
const ordersStore = useOrdersStore()

onMounted(() => {
  inventoryStore.init()
  ordersStore.init()
})
</script>

<template>
  <div class="flex min-h-screen bg-pink-50/40">
    <aside class="w-64 shrink-0 border-r border-pink-100 bg-white">
      <div class="border-b border-pink-100 px-6 py-5">
        <h3 class="text-xl font-bold text-[var(--primary)]">Panel de Admin</h3>
        <p class="mt-1 text-xs text-neutral-500">Acceso: {{ adminStore.role }}</p>
      </div>
      <nav class="p-4">
        <ul class="space-y-1">
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'dashboard' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'dashboard'"
            >
              <LayoutDashboard class="size-5" />
              <span>Dashboard</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'productos' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'productos'"
            >
              <Package class="size-5" />
              <span>Productos</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'inventario' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'inventario'"
            >
              <Boxes class="size-5" />
              <span>Inventario</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'pedidos' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'pedidos'"
            >
              <ShoppingCart class="size-5" />
              <span>Pedidos</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'historial' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'historial'"
            >
              <History class="size-5" />
              <span>Historial</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'proveedores' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'proveedores'"
            >
              <Truck class="size-5" />
              <span>Proveedores</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'movimientos' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'movimientos'"
            >
              <ChartColumnBig class="size-5" />
              <span>Movimientos</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'reportes' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'reportes'"
            >
              <BarChart3 class="size-5" />
              <span>Reportes</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'auditoria' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'auditoria'"
            >
              <ShieldCheck class="size-5" />
              <span>Auditoría</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'configuracion' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'configuracion'"
            >
              <Settings class="size-5" />
              <span>Configuración</span>
            </button>
          </li>
        </ul>
      </nav>
    </aside>

    <main class="flex-1 p-6 sm:p-8">
      <AdminDashboard v-if="activeSection === 'dashboard'" />
      <AdminProductos v-else-if="activeSection === 'productos'" />
      <InventorySection v-else-if="activeSection === 'inventario'" />
      <AdminPedidos v-else-if="activeSection === 'pedidos'" />
      <AdminHistorial v-else-if="activeSection === 'historial'" />
      <Suppliers v-else-if="activeSection === 'proveedores'" />
      <MovementHistory v-else-if="activeSection === 'movimientos'" />
      <AdminReportes v-else-if="activeSection === 'reportes'" />
      <AuditLogs v-else-if="activeSection === 'auditoria'" />
      <AdminConfiguracion v-else />
    </main>
  </div>
</template>
