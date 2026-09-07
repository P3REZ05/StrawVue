<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { Pencil, Plus, Power, Tag, Trash2 } from 'lucide-vue-next'
import { usePromotionsStore, TIPOS, ALCANCES } from '../../stores/promotions'
import { useCatalogStore } from '../../stores/catalog'
import { formatCurrency } from '../../utils/formatCurrency'

// Administración de descuentos.
//
// No confundir con los banners del carrusel, que viven en Configuración:
// aquellos son imágenes, estos cambian el precio que paga el cliente.

const promos = usePromotionsStore()
const catalogo = useCatalogStore()

const error = ref('')
const guardando = ref(false)
const editando = ref(false)

const form = reactive({
  id: null, title: '', label: '', description: '', type: 'percent', value: 10,
  code: '', requiresCode: false, minPurchase: '', startsAt: '', endsAt: '', priority: 0,
  appliesTo: 'all', categoryId: '', maxUses: '', active: true, productIds: []
})

onMounted(async () => {
  try {
    await Promise.all([promos.init(), catalogo.init()])
  } catch (e) {
    error.value = e?.message || 'No se pudieron cargar las promociones.'
  }
})

const tipoActual = computed(() => TIPOS.find((t) => t.value === form.type))
const necesitaValor = computed(() => ['percent', 'fixed'].includes(form.type))
const esCupon = computed(() => form.requiresCode)

// Vista previa del efecto sobre un precio de referencia: ver el número final
// evita el clásico "puse 20 pensando en pesos y era porcentaje".
const PRECIO_EJEMPLO = 40000
const previsualizacion = computed(() => {
  const v = Number(form.value) || 0
  if (form.type === 'percent') return Math.max(PRECIO_EJEMPLO - (PRECIO_EJEMPLO * v) / 100, 0)
  if (form.type === 'fixed') return Math.max(PRECIO_EJEMPLO - v, 0)
  return null
})

function nuevo() {
  Object.assign(form, {
    id: null, title: '', label: '', description: '', type: 'percent', value: 10,
    code: '', requiresCode: false, minPurchase: '', startsAt: '', endsAt: '', priority: 0,
    appliesTo: 'all', categoryId: '', maxUses: '', active: true, productIds: []
  })
  editando.value = true
  error.value = ''
}

function editar(promo) {
  Object.assign(form, {
    ...promo,
    minPurchase: promo.minPurchase ?? '',
    maxUses: promo.maxUses ?? '',
    categoryId: promo.categoryId ?? '',
    productIds: promos.productosDe(promo.id).map((l) => l.product_id)
  })
  editando.value = true
  error.value = ''
}

async function guardar() {
  error.value = ''
  guardando.value = true
  try {
    await promos.save({ ...form })
    await catalogo.refresh()   // los precios de la vitrina cambiaron
    editando.value = false
  } catch (e) {
    error.value = e?.message || 'No se pudo guardar.'
  } finally {
    guardando.value = false
  }
}

async function accion(fn) {
  error.value = ''
  try { await fn() } catch (e) { error.value = e?.message || 'No se pudo completar la acción.' }
}

function resumen(promo) {
  const cupon = promo.code ? `Cupón ${promo.code} · ` : ''
  if (promo.type === 'percent') return `${cupon}${promo.value}% de descuento`
  if (promo.type === 'fixed') return `${cupon}${formatCurrency(promo.value)} de descuento`
  if (promo.type === 'shipping') return promo.minPurchase ? `Envío gratis desde ${formatCurrency(promo.minPurchase)}` : 'Envío gratis'
  return promo.type
}

function alcance(promo) {
  if (promo.appliesTo === 'all') return 'Todo el catálogo'
  if (promo.appliesTo === 'category') return catalogo.categories.find((c) => c.id === promo.categoryId)?.name || 'Categoría'
  return `${promos.productosDe(promo.id).length} producto(s)`
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 class="text-2xl font-bold text-black">Promociones</h2>
        <p class="mt-1 text-sm text-neutral-500">
          Descuentos que cambian el precio que ve y paga el cliente. El cálculo lo hace la base de datos,
          así que nadie puede manipularlo desde el navegador.
        </p>
      </div>
      <button
        class="inline-flex items-center gap-2 rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="nuevo"
      >
        <Plus class="size-4" /> Nueva promoción
      </button>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-600">{{ error }}</p>

    <!-- Formulario -->
    <div v-if="editando" class="rounded-2xl border border-pink-100 bg-white p-5 shadow-sm">
      <h3 class="font-bold text-black">{{ form.id ? 'Editar promoción' : 'Nueva promoción' }}</h3>

      <div class="mt-4 grid gap-4 md:grid-cols-2">
        <label class="text-sm font-bold text-neutral-700">Nombre interno *
          <input v-model="form.title" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" placeholder="Lanzamiento de bases" />
        </label>
        <label class="text-sm font-bold text-neutral-700">Etiqueta que ve el cliente
          <input v-model="form.label" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" placeholder="-20%" />
        </label>

        <label class="text-sm font-bold text-neutral-700">Tipo
          <select v-model="form.type" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal">
            <option v-for="t in TIPOS" :key="t.value" :value="t.value">{{ t.label }}</option>
          </select>
          <span class="mt-1 block text-xs font-normal text-neutral-500">{{ tipoActual?.ayuda }}</span>
        </label>

        <label v-if="necesitaValor" class="text-sm font-bold text-neutral-700">
          {{ form.type === 'percent' || form.type === 'coupon' ? 'Porcentaje' : 'Monto' }}
          <input v-model="form.value" type="number" min="0" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" />
          <span v-if="previsualizacion !== null" class="mt-1 block text-xs font-normal text-emerald-600">
            Un producto de {{ formatCurrency(PRECIO_EJEMPLO) }} quedaría en {{ formatCurrency(previsualizacion) }}
          </span>
        </label>

        <label v-if="form.type !== 'shipping'" class="flex items-start gap-2 text-sm font-bold text-neutral-700">
          <input v-model="form.requiresCode" type="checkbox" class="mt-1 size-4 accent-[var(--primary)]" />
          <span>
            Requiere código (cupón)
            <span class="mt-0.5 block text-xs font-normal text-neutral-500">
              Sin marcar, el descuento se aplica solo a todo el que compre. Marcado, solo si el cliente escribe el código.
            </span>
          </span>
        </label>

        <label v-if="esCupon" class="text-sm font-bold text-neutral-700">Código del cupón *
          <input v-model="form.code" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal uppercase" placeholder="BIENVENIDA15" />
        </label>

        <label class="text-sm font-bold text-neutral-700">Compra mínima
          <input v-model="form.minPurchase" type="number" min="0" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" placeholder="Sin mínimo" />
        </label>

        <label class="text-sm font-bold text-neutral-700">Aplica a
          <select v-model="form.appliesTo" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal">
            <option v-for="a in ALCANCES" :key="a.value" :value="a.value">{{ a.label }}</option>
          </select>
        </label>

        <label v-if="form.appliesTo === 'category'" class="text-sm font-bold text-neutral-700">Categoría *
          <select v-model="form.categoryId" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal">
            <option value="">Seleccionar</option>
            <option v-for="c in catalogo.rootCategories" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </label>

        <label class="text-sm font-bold text-neutral-700">Desde
          <input v-model="form.startsAt" type="date" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" />
        </label>
        <label class="text-sm font-bold text-neutral-700">Hasta
          <input v-model="form.endsAt" type="date" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" />
        </label>

        <label class="text-sm font-bold text-neutral-700">Prioridad
          <input v-model="form.priority" type="number" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" />
          <span class="mt-1 block text-xs font-normal text-neutral-500">
            Si dos promociones aplican al mismo producto gana la de mayor prioridad. Nunca se suman.
          </span>
        </label>

        <label v-if="esCupon" class="text-sm font-bold text-neutral-700">Usos máximos
          <input v-model="form.maxUses" type="number" min="1" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" placeholder="Sin límite" />
        </label>
      </div>

      <div v-if="form.appliesTo === 'products'" class="mt-4">
        <p class="text-sm font-bold text-neutral-700">Productos incluidos</p>
        <div class="mt-2 max-h-48 overflow-y-auto rounded-xl border border-pink-100 p-3">
          <label v-for="p in catalogo.products" :key="p.id" class="flex items-center gap-2 py-1 text-sm">
            <input v-model="form.productIds" type="checkbox" :value="p.id" class="size-4 accent-[var(--primary)]" />
            {{ p.name }}
          </label>
        </div>
      </div>

      <label class="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-neutral-700">
        <input v-model="form.active" type="checkbox" class="size-4 accent-[var(--primary)]" /> Activa
      </label>

      <div class="mt-5 flex gap-2">
        <button
          :disabled="guardando"
          class="rounded-full bg-[var(--primary)] px-6 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          @click="guardar"
        >
          {{ guardando ? 'Guardando…' : 'Guardar' }}
        </button>
        <button class="rounded-full border border-pink-200 px-5 py-2.5 text-sm font-bold" @click="editando = false">Cancelar</button>
      </div>
    </div>

    <!-- Listado -->
    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-200 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Promoción</th>
            <th class="px-5 py-4">Descuento</th>
            <th class="px-5 py-4">Aplica a</th>
            <th class="px-5 py-4">Vigencia</th>
            <th class="px-5 py-4">Usos</th>
            <th class="px-5 py-4">Estado</th>
            <th class="px-5 py-4"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="promo in promos.promotions" :key="promo.id" class="border-b border-pink-50 hover:bg-pink-50/40">
            <td class="px-5 py-4">
              <span class="flex items-center gap-2 font-semibold">
                <Tag class="size-4 text-[var(--primary)]" /> {{ promo.title }}
              </span>
              <span v-if="promo.label" class="ml-6 text-xs text-neutral-500">Etiqueta: {{ promo.label }}</span>
            </td>
            <td class="px-5 py-4">{{ resumen(promo) }}</td>
            <td class="px-5 py-4 text-neutral-600">{{ alcance(promo) }}</td>
            <td class="px-5 py-4 text-xs text-neutral-500">
              <template v-if="promo.startsAt || promo.endsAt">
                {{ promo.startsAt || 'siempre' }} → {{ promo.endsAt || 'sin fin' }}
              </template>
              <template v-else>Sin límite de fechas</template>
            </td>
            <td class="px-5 py-4 text-xs">
              {{ promo.usesCount }}<template v-if="promo.maxUses"> / {{ promo.maxUses }}</template>
            </td>
            <td class="px-5 py-4">
              <span class="inline-flex rounded-full px-3 py-1 text-xs font-bold text-white" :class="promos.estado(promo).clase">
                {{ promos.estado(promo).texto }}
              </span>
            </td>
            <td class="px-5 py-4">
              <span class="flex justify-end gap-1">
                <button class="rounded-full p-1.5 text-neutral-400 hover:text-[var(--primary)]" title="Editar" @click="editar(promo)">
                  <Pencil class="size-4" />
                </button>
                <button
                  class="rounded-full p-1.5 text-neutral-400 hover:text-amber-600"
                  :title="promo.active ? 'Pausar' : 'Activar'"
                  @click="accion(() => promos.toggle(promo))"
                >
                  <Power class="size-4" />
                </button>
                <button
                  class="rounded-full p-1.5 text-neutral-400 hover:text-red-600" title="Eliminar"
                  @click="accion(() => promos.remove(promo))"
                >
                  <Trash2 class="size-4" />
                </button>
              </span>
            </td>
          </tr>
          <tr v-if="!promos.promotions.length">
            <td colspan="7" class="p-10 text-center text-neutral-500">
              Todavía no hay promociones. Crea la primera para que el catálogo muestre precios rebajados.
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
