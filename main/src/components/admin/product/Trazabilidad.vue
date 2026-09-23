<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { PackagePlus, ArrowRightLeft, ShoppingCart, Undo2, Pencil, Palette, AlertTriangle } from 'lucide-vue-next'
import { useCatalogStore } from '../../../stores/catalog'
import { formatCurrency } from '../../../utils/formatCurrency'

const props = defineProps({ productId: { type: Number, required: true } })

const catalogo = useCatalogStore()
const eventos = ref([])
const cargando = ref(true)
const error = ref('')
const filtro = ref('todo')

const FILTROS = [
  { id: 'todo', label: 'Todo' },
  { id: 'inventario', label: 'Inventario' },
  { id: 'ficha', label: 'Ficha' },
  { id: 'tono', label: 'Tonos' }
]

// Cada tipo de evento tiene su icono y su color. El color NO es lo único que
// distingue: cada fila lleva su título escrito, porque un semáforo de puntitos
// sin texto obliga a memorizar una leyenda.
const ESTILOS = {
  'Entrada a bodega':              { icono: PackagePlus,     clase: 'text-emerald-600 bg-emerald-50' },
  'Salida de bodega':              { icono: ArrowRightLeft,  clase: 'text-amber-600 bg-amber-50' },
  'Entrada a inventario de venta': { icono: ArrowRightLeft,  clase: 'text-emerald-600 bg-emerald-50' },
  'Venta de mostrador':            { icono: ShoppingCart,    clase: 'text-[var(--primary)] bg-pink-50' },
  'Pedido online':                 { icono: ShoppingCart,    clase: 'text-[var(--primary)] bg-pink-50' },
  'Devolución':                    { icono: Undo2,           clase: 'text-amber-600 bg-amber-50' },
  'Baja por daño':                 { icono: AlertTriangle,   clase: 'text-red-600 bg-red-50' },
  'Ajuste de inventario':          { icono: AlertTriangle,   clase: 'text-neutral-600 bg-neutral-100' }
}

function estilo(ev) {
  if (ESTILOS[ev.titulo]) return ESTILOS[ev.titulo]
  if (ev.familia === 'tono') return { icono: Palette, clase: 'text-violet-600 bg-violet-50' }
  return { icono: Pencil, clase: 'text-[#2a78d6] bg-blue-50' }
}

const filtrados = computed(() =>
  filtro.value === 'todo' ? eventos.value : eventos.value.filter((e) => e.familia === filtro.value)
)

// Agrupado por día: una lista plana de cincuenta filas con la hora en cada una
// se lee como un log. Por días se lee como una historia.
const porDia = computed(() => {
  const grupos = new Map()
  for (const ev of filtrados.value) {
    const dia = String(ev.fecha).slice(0, 10)
    if (!grupos.has(dia)) grupos.set(dia, [])
    grupos.get(dia).push(ev)
  }
  return [...grupos.entries()].map(([dia, items]) => ({ dia, items }))
})

const resumen = computed(() => {
  const inv = eventos.value.filter((e) => e.familia === 'inventario')
  const entradas = inv.filter((e) => e.unidades > 0).reduce((s, e) => s + e.unidades, 0)
  const salidas = inv.filter((e) => e.unidades < 0).reduce((s, e) => s + Math.abs(e.unidades), 0)
  return { entradas, salidas, eventos: eventos.value.length }
})

function fechaLarga(dia) {
  const [a, m, d] = dia.split('-')
  const hoy = new Date().toISOString().slice(0, 10)
  if (dia === hoy) return 'Hoy'
  return new Date(Number(a), Number(m) - 1, Number(d))
    .toLocaleDateString('es-CO', { day: 'numeric', month: 'long', year: 'numeric' })
}

function hora(iso) {
  return new Date(iso).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' })
}

function nombreTono(variantId) {
  if (!variantId) return ''
  return catalogo.shades.find((t) => t.id === variantId)?.name || `Tono #${variantId}`
}

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    eventos.value = await catalogo.trazabilidadDe(props.productId)
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => props.productId, cargar)
</script>

<template>
  <section class="space-y-4">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h3 class="text-sm font-bold text-black">Línea de tiempo</h3>
        <p class="mt-1 text-sm text-neutral-500">
          Todo lo que le ha pasado a este producto: cambios de ficha, tonos, compras,
          transferencias y ventas.
        </p>
      </div>
      <button
        class="rounded-full border border-pink-200 px-4 py-1.5 text-xs font-bold text-neutral-700 transition hover:bg-pink-50"
        @click="cargar"
      >
        Actualizar
      </button>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="cargando" class="rounded-xl border border-dashed border-pink-200 p-8 text-center text-sm text-neutral-500">
      Cargando la historia…
    </p>

    <template v-else-if="eventos.length">
      <div class="grid gap-3 sm:grid-cols-3">
        <div class="rounded-xl bg-emerald-50 px-4 py-3">
          <p class="text-xl font-bold text-emerald-700">+{{ resumen.entradas }}</p>
          <p class="text-xs font-semibold text-emerald-700/70">unidades que han entrado</p>
        </div>
        <div class="rounded-xl bg-pink-50 px-4 py-3">
          <p class="text-xl font-bold text-[var(--primary)]">−{{ resumen.salidas }}</p>
          <p class="text-xs font-semibold text-[var(--primary)]/70">unidades que han salido</p>
        </div>
        <div class="rounded-xl bg-neutral-100 px-4 py-3">
          <p class="text-xl font-bold text-neutral-700">{{ resumen.eventos }}</p>
          <p class="text-xs font-semibold text-neutral-500">eventos registrados</p>
        </div>
      </div>

      <div class="flex flex-wrap gap-2">
        <button
          v-for="f in FILTROS"
          :key="f.id"
          class="rounded-full px-3 py-1.5 text-xs font-bold transition"
          :class="filtro === f.id ? 'bg-[var(--primary)] text-white' : 'bg-white text-neutral-600 ring-1 ring-pink-100 hover:bg-pink-50'"
          @click="filtro = f.id"
        >
          {{ f.label }}
        </button>
      </div>

      <div v-for="grupo in porDia" :key="grupo.dia" class="space-y-2">
        <p class="sticky top-0 bg-white/95 py-1 text-xs font-bold uppercase tracking-wide text-neutral-400 backdrop-blur">
          {{ fechaLarga(grupo.dia) }}
        </p>

        <div
          v-for="(ev, i) in grupo.items"
          :key="`${grupo.dia}-${i}`"
          class="flex gap-3 rounded-xl border border-pink-100 p-3"
        >
          <span class="grid size-9 shrink-0 place-items-center rounded-full" :class="estilo(ev).clase">
            <component :is="estilo(ev).icono" class="size-4" />
          </span>

          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-baseline gap-x-2">
              <strong class="text-sm text-black">{{ ev.titulo }}</strong>
              <span v-if="ev.variant_id" class="text-xs font-semibold text-violet-700">
                {{ nombreTono(ev.variant_id) }}
              </span>
              <span class="text-xs text-neutral-400">{{ hora(ev.fecha) }}</span>
            </div>
            <p v-if="ev.detalle" class="mt-0.5 text-sm leading-6 text-neutral-600">{{ ev.detalle }}</p>
            <p v-if="ev.documento || ev.costo_unitario" class="mt-1 text-xs text-neutral-400">
              <span v-if="ev.documento">{{ ev.documento }}</span>
              <span v-if="ev.documento && ev.costo_unitario"> · </span>
              <span v-if="ev.costo_unitario">costo {{ formatCurrency(ev.costo_unitario) }} por unidad</span>
            </p>
          </div>

          <span
            v-if="ev.unidades"
            class="shrink-0 self-center text-sm font-bold tabular-nums"
            :class="ev.unidades > 0 ? 'text-emerald-600' : 'text-[var(--primary)]'"
          >
            {{ ev.unidades > 0 ? '+' : '' }}{{ ev.unidades }}
          </span>
        </div>
      </div>

      <p v-if="!filtrados.length" class="rounded-xl border border-dashed border-pink-200 p-6 text-center text-sm text-neutral-500">
        No hay eventos de ese tipo.
      </p>
    </template>

    <p v-else class="rounded-xl border border-dashed border-pink-200 p-8 text-center text-sm text-neutral-500">
      Todavía no hay historia que contar. Aparecerá en cuanto edites la ficha,
      registres una compra o vendas una unidad.
    </p>
  </section>
</template>
