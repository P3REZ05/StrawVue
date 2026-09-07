<script setup>
import { computed, onMounted, ref } from 'vue'
import { AlertTriangle, PackageX, RefreshCw, Snowflake, TrendingDown } from 'lucide-vue-next'
import { useReportsStore, PERIODOS_DISPONIBLES } from '../../stores/reports'
import { formatCurrency } from '../../utils/formatCurrency'
import LineaTiempo from './reportes/LineaTiempo.vue'
import BarrasUtilidad from './reportes/BarrasUtilidad.vue'

const reportes = useReportsStore()
const error = ref('')
const verTabla = ref(false)

onMounted(async () => {
  try {
    await reportes.init()
  } catch (e) {
    error.value = e?.message || 'No se pudieron cargar los reportes.'
  }
})

const t = computed(() => reportes.totales)

// Cada alerta lleva icono y texto: el color nunca carga el significado solo.
const ALERTAS = {
  agotado:         { texto: 'Agotado',              icono: PackageX,      clase: 'text-[#d03b3b]' },
  reponer_vitrina: { texto: 'Reponer desde bodega', icono: AlertTriangle, clase: 'text-[#ec835a]' },
  stock_bajo:      { texto: 'Stock bajo',           icono: TrendingDown,  clase: 'text-[#fab219]' },
  sin_rotacion:    { texto: 'Sin rotación',         icono: Snowflake,     clase: 'text-[#52514e]' }
}

async function recargar() {
  error.value = ''
  try { await reportes.refresh() } catch (e) { error.value = e?.message || 'No se pudo recargar.' }
}
</script>

<template>
  <div
    class="space-y-6"
    style="
      --viz-surface: #ffffff;
      --viz-ink: #0b0b0b;
      --viz-ink-2: #52514e;
      --viz-muted: #898781;
      --viz-grid: #e1e0d9;
      --viz-baseline: #c3c2b7;
      --viz-s1: #2a78d6;
      --viz-s2: #1baf7a;
    "
  >
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 class="text-2xl font-bold text-black">Reportes</h2>
        <p class="mt-1 text-sm text-neutral-500">
          Utilidad real: lo facturado menos el costo promedio ponderado de las compras.
        </p>
      </div>
      <div class="flex items-center gap-2">
        <select
          :value="reportes.periodo" class="rounded-xl border border-pink-100 bg-white px-3 py-2 text-sm"
          @change="reportes.setPeriodo($event.target.value)"
        >
          <option v-for="p in PERIODOS_DISPONIBLES" :key="p.value" :value="p.value">{{ p.label }}</option>
        </select>
        <button class="rounded-full border border-pink-200 p-2 text-neutral-600 hover:text-[var(--primary)]" title="Recargar" @click="recargar">
          <RefreshCw class="size-4" />
        </button>
      </div>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-600">{{ error }}</p>

    <p v-if="!t.costoConfiable && t.unidades" class="rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-800">
      <strong>Ojo con el margen.</strong> Hay productos vendidos sin compra registrada: su costo cuenta como cero
      y el margen aparenta ser del 100 %. Registra esas compras para que la utilidad sea real.
    </p>

    <!-- Cifras principales: números grandes, no gráficos -->
    <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <article class="rounded-2xl bg-white p-5 shadow-sm">
        <p class="text-xs font-bold uppercase tracking-wider text-neutral-500">Ingresos</p>
        <p class="mt-2 text-3xl font-bold text-black">{{ formatCurrency(t.ingreso) }}</p>
        <p class="mt-1 text-xs text-neutral-500">{{ t.documentos }} {{ t.documentos === 1 ? 'venta' : 'ventas' }} · {{ t.unidades }} {{ t.unidades === 1 ? 'unidad' : 'unidades' }}</p>
      </article>
      <article class="rounded-2xl bg-white p-5 shadow-sm">
        <p class="text-xs font-bold uppercase tracking-wider text-neutral-500">Utilidad</p>
        <p class="mt-2 text-3xl font-bold" :class="t.utilidad >= 0 ? 'text-[#0ca30c]' : 'text-[#d03b3b]'">
          {{ formatCurrency(t.utilidad) }}
        </p>
        <p class="mt-1 text-xs text-neutral-500">Costo {{ formatCurrency(t.costo) }}</p>
      </article>
      <article class="rounded-2xl bg-white p-5 shadow-sm">
        <p class="text-xs font-bold uppercase tracking-wider text-neutral-500">Margen</p>
        <p class="mt-2 text-3xl font-bold text-black">{{ t.margen.toFixed(1) }}%</p>
        <p class="mt-1 text-xs text-neutral-500">De cada peso vendido</p>
      </article>
      <article class="rounded-2xl bg-white p-5 shadow-sm">
        <p class="text-xs font-bold uppercase tracking-wider text-neutral-500">Ticket promedio</p>
        <p class="mt-2 text-3xl font-bold text-black">{{ formatCurrency(t.ticketPromedio) }}</p>
        <p class="mt-1 text-xs text-neutral-500">Por venta</p>
      </article>
    </div>

    <div class="rounded-2xl bg-white p-5 shadow-sm sm:p-6">
      <LineaTiempo :datos="reportes.serieDiaria" />
    </div>

    <div class="grid gap-5 lg:grid-cols-2">
      <div class="rounded-2xl bg-white p-5 shadow-sm sm:p-6">
        <BarrasUtilidad
          :filas="reportes.productosRankeados"
          titulo="Utilidad por producto"
          descripcion="Ordenado por lo que deja, no por lo que factura."
        />
      </div>
      <div class="rounded-2xl bg-white p-5 shadow-sm sm:p-6">
        <BarrasUtilidad
          :filas="reportes.tonosRankeados"
          titulo="Utilidad por tono"
          descripcion="Cuál de tus tonos deja plata y cuál solo ocupa bodega."
          usar-swatch
        />
      </div>
    </div>

    <!-- Alertas de inventario: icono + texto, nunca solo color -->
    <div v-if="reportes.alertas.length" class="rounded-2xl bg-white p-5 shadow-sm sm:p-6">
      <h3 class="text-sm font-bold text-black">Requiere atención</h3>
      <ul class="mt-3 divide-y divide-pink-50">
        <li v-for="a in reportes.alertas" :key="`${a.product_id}-${a.variant_id}`" class="flex items-center justify-between gap-3 py-2.5 text-sm">
          <span class="flex min-w-0 items-center gap-2">
            <component :is="ALERTAS[a.alerta]?.icono" class="size-4 shrink-0" :class="ALERTAS[a.alerta]?.clase" />
            <span class="truncate font-semibold">{{ a.producto }}</span>
            <span v-if="a.tono" class="shrink-0 text-neutral-500">{{ a.tono }}</span>
          </span>
          <span class="shrink-0 text-xs">
            <span class="font-bold" :class="ALERTAS[a.alerta]?.clase">{{ ALERTAS[a.alerta]?.texto }}</span>
            <span class="ml-2 text-neutral-500">venta {{ a.stock_venta }} · bodega {{ a.stock_bodega }}</span>
          </span>
        </li>
      </ul>
    </div>

    <!-- Vista de tabla: obligatoria cuando un color queda bajo 3:1 de contraste -->
    <div class="rounded-2xl bg-white p-5 shadow-sm sm:p-6">
      <button class="text-sm font-bold text-[var(--primary)]" @click="verTabla = !verTabla">
        {{ verTabla ? 'Ocultar' : 'Ver' }} los datos en tabla
      </button>
      <div v-if="verTabla" class="mt-4 overflow-x-auto">
        <table class="w-full min-w-150 text-sm">
          <thead>
            <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
              <th class="py-2 pr-3">Producto</th>
              <th class="py-2 pr-3">Tono</th>
              <th class="py-2 pr-3">Unidades</th>
              <th class="py-2 pr-3">Ingreso</th>
              <th class="py-2 pr-3">Utilidad</th>
              <th class="py-2">Margen</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="f in reportes.tonosRankeados" :key="f.key" class="border-b border-pink-50">
              <td class="py-2 pr-3">{{ f.etiqueta }}</td>
              <td class="py-2 pr-3 text-neutral-500">{{ f.tono }}</td>
              <td class="py-2 pr-3">{{ f.unidades }}</td>
              <td class="py-2 pr-3">{{ formatCurrency(f.ingreso) }}</td>
              <td class="py-2 pr-3 font-semibold">{{ formatCurrency(f.utilidad) }}</td>
              <td class="py-2">{{ f.margen.toFixed(1) }}%</td>
            </tr>
            <tr v-if="!reportes.tonosRankeados.length">
              <td colspan="6" class="py-8 text-center text-neutral-500">Sin ventas en este período.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
