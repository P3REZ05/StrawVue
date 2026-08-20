<script setup>
import { ref } from 'vue'
import AdminDashboard from './AdminDashboard.vue'
import AdminPedidos from './AdminPedidos.vue'
import AdminHistorial from './AdminHistorial.vue'
import AdminConfiguracion from './AdminConfiguracion.vue'
import InventorySection from './inventory/InventorySection.vue'

const activeSection = ref('productos')
</script>

<template>
  <div class="flex min-h-screen bg-pink-50/40">
    <!-- Sidebar -->
    <aside class="w-64 shrink-0 border-r border-pink-100 bg-white">
      <div class="border-b border-pink-100 px-6 py-5">
        <h3 class="text-xl font-bold text-[var(--primary)]">Panel de Admin</h3>
      </div>
      <nav class="p-4">
        <ul class="space-y-1">
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'productos' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'productos'"
            >
              <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 8l-9-5-9 5v8l9 5 9-5V8z"/><path d="M3 8l9 5 9-5"/><path d="M12 13v8"/></svg>
              <span>Productos</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'inventario' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'inventario'"
            >
              <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 8l-9-5-9 5v8l9 5 9-5V8z"/><path d="M3 8l9 5 9-5"/><path d="M12 13v8"/></svg>
              <span>Inventario</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'pedidos' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'pedidos'"
            >
              <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 4h2l2.2 11.1a2 2 0 0 0 2 1.6h7.6a2 2 0 0 0 2-1.6L20 8H7"/><circle cx="10" cy="20" r="1"/><circle cx="17" cy="20" r="1"/></svg>
              <span>Pedidos</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'historial' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'historial'"
            >
              <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/></svg>
              <span>Historial</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'configuracion' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'configuracion'"
            >
              <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.6-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3h0a1.7 1.7 0 0 0 1-1.6V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.6h0a1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9v0a1.7 1.7 0 0 0 1.6 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>
              <span>Configuración</span>
            </button>
          </li>
        </ul>
      </nav>
    </aside>

    <!-- Main content -->
    <main class="flex-1 p-6 sm:p-8">
      <AdminDashboard v-if="activeSection === 'productos'" />
      <InventorySection v-else-if="activeSection === 'inventario'" />
      <AdminPedidos v-else-if="activeSection === 'pedidos'" />
      <AdminHistorial v-else-if="activeSection === 'historial'" />
      <AdminConfiguracion v-else />
    </main>
  </div>
</template>