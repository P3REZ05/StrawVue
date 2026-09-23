<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  BarChart3,
  Boxes,
  ChartColumnBig,
  ClipboardList,
  Settings,
  Tag,
  Tags,
  ShieldCheck,
  ShoppingCart,
  Truck,
  LayoutDashboard,
  History, Mail, Sparkles } from 'lucide-vue-next'
import { useInventoryStore } from '../../stores/inventory'
import { useOrdersStore } from '../../stores/orders'
import { useAdminStore } from '../../stores/admin'
import AdminDashboard from './AdminDashboard.vue'
import AdminEtiquetas from './AdminEtiquetas.vue'
import AdminPedidos from './AdminPedidos.vue'
import AdminHistorial from './AdminHistorial.vue'
import AdminMensajes from './AdminMensajes.vue'
import { useContactStore } from '../../stores/contact'
import AdminReportes from './AdminReportes.vue'
import AdminConfiguracion from './AdminConfiguracion.vue'
import AdminPromociones from './AdminPromociones.vue'
import AdminOfertas from './AdminOfertas.vue'
import InventorySection from './inventory/InventorySection.vue'
import AuditLogs from './inventory/AuditLogs.vue'
import Suppliers from './inventory/Suppliers.vue'
import MovementHistory from './inventory/MovementHistory.vue'
import CatalogSettings from './CatalogSettings.vue'
import SalesRegister from './inventory/SalesRegister.vue'

const activeSection = ref('dashboard')
const adminStore = useAdminStore()
const inventoryStore = useInventoryStore()
const ordersStore = useOrdersStore()
const router = useRouter()

const loadError = ref('')

// Para el contador de mensajes sin leer de la barra lateral.
const contacto = useContactStore()

// init() ahora propaga los errores en vez de tragárselos. Si RLS bloquea la
// lectura o el perfil admin no existe, el panel debe DECIRLO en vez de mostrar
// tablas vacías, que es exactamente el fallo silencioso que veníamos arrastrando.
onMounted(async () => {
  try {
    await Promise.all([inventoryStore.initPanel(), ordersStore.init()])
  } catch (error) {
    loadError.value = error?.message || 'No se pudieron cargar los datos del panel.'
  }
  // Los mensajes van aparte: solo alimentan el contador de la barra lateral,
  // así que un fallo aquí no debe impedir usar el resto del panel.
  contacto.init().catch(() => {})
})

async function logout() {
  await adminStore.logout()
  router.push('/admin')
}
</script>

<template>
  <div class="flex min-h-screen bg-pink-50/40">
    <aside class="flex min-h-screen w-64 shrink-0 flex-col border-r border-pink-100 bg-white">
      <div class="border-b border-pink-100 px-6 py-5">
        <h3 class="text-xl font-bold text-[var(--primary)]">Panel de Admin</h3>
        <p class="mt-1 text-xs text-neutral-500">Acceso: {{ adminStore.role }}</p>
      </div>
      <nav class="flex-1 p-4">
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
              :class="activeSection === 'catalogo' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'catalogo'"
            >
              <ClipboardList class="size-5" />
              <span>Categorías y atributos</span>
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
              :class="activeSection === 'ventas' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'ventas'"
            >
              <ShoppingCart class="size-5" />
              <span>Ventas</span>
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
              :class="activeSection === 'mensajes' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'mensajes'"
            >
              <Mail class="size-5" />
              <span>Mensajes</span>
              <span
                v-if="contacto.sinLeer"
                class="ml-auto rounded-full px-2 py-0.5 text-[11px] font-bold"
                :class="activeSection === 'mensajes' ? 'bg-white text-[var(--primary)]' : 'bg-[var(--primary)] text-white'"
              >{{ contacto.sinLeer }}</span>
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
              :class="activeSection === 'promociones' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'promociones'"
            >
              <Tag class="size-5" />
              <span>Promociones</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'ofertas' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'ofertas'"
            >
              <Sparkles class="size-5" />
              <span>Portada</span>
            </button>
          </li>
          <li>
            <button
              class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold transition"
              :class="activeSection === 'etiquetas' ? 'bg-[var(--primary)] text-white' : 'text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
              @click="activeSection = 'etiquetas'"
            >
              <Tags class="size-5" />
              <span>Etiquetas</span>
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
      <div class="border-t border-pink-100 p-4">
        <button
          class="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-bold text-red-500 transition hover:bg-red-50"
          type="button"
          @click="logout"
        >
          <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/></svg>
          <span>Cerrar sesión</span>
        </button>
      </div>
    </aside>

    <main class="min-w-0 flex-1 p-6 sm:p-8">
      <div v-if="loadError" class="mb-6 rounded-2xl border border-red-200 bg-red-50 p-4">
        <p class="text-sm font-bold text-red-700">No se pudieron cargar los datos</p>
        <p class="mt-1 text-sm text-red-600">{{ loadError }}</p>
        <p class="mt-2 text-xs text-red-500">
          Si el problema persiste, revisa que tu usuario tenga perfil en <code>admin_profiles</code>
          y que las políticas RLS estén aplicadas.
        </p>
      </div>
      <div class="w-full min-w-0">
        <AdminDashboard v-if="activeSection === 'dashboard'" />
        <CatalogSettings v-else-if="activeSection === 'catalogo'" />
        <InventorySection v-else-if="activeSection === 'inventario'" />
        <SalesRegister v-else-if="activeSection === 'ventas'" />
        <AdminPedidos v-else-if="activeSection === 'pedidos'" />
        <AdminHistorial v-else-if="activeSection === 'historial'" />
        <AdminMensajes v-else-if="activeSection === 'mensajes'" />
        <Suppliers v-else-if="activeSection === 'proveedores'" />
        <MovementHistory v-else-if="activeSection === 'movimientos'" />
        <AdminPromociones v-else-if="activeSection === 'promociones'" />
        <AdminOfertas v-else-if="activeSection === 'ofertas'" />
        <AdminEtiquetas v-else-if="activeSection === 'etiquetas'" />
        <AdminReportes v-else-if="activeSection === 'reportes'" />
        <AuditLogs v-else-if="activeSection === 'auditoria'" />
        <AdminConfiguracion v-else />
      </div>
    </main>
  </div>
</template>
