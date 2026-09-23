<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Copy, Pencil, Archive, Pause, Play, Search } from 'lucide-vue-next'
import { useInventoryStore } from '../../stores/inventory'
import { useCatalogStore } from '../../stores/catalog'
import { formatCurrency } from '../../utils/formatCurrency'

const inventoryStore = useInventoryStore()
const catalogo = useCatalogStore()
const router = useRouter()

// La lista sale de un `computed`, no de una copia guardada en un `ref`.
// Antes se copiaba el catálogo una sola vez al montar y se filtraba mutando
// esa copia: crear o archivar un producto desde otra pantalla no se veía
// hasta recargar, y el filtro trabajaba sobre datos viejos.
const productos = computed(() => inventoryStore.catalogWithStock)

const busqueda = ref('')
const categoria = ref('')
const estado = ref('')
const orden = ref('nombre')
const pagina = ref(1)
const POR_PAGINA = 24

const menuAbierto = ref(null)
const confirmacion = ref(null)
const aviso = ref('')
const error = ref('')
const ocupado = ref(false)

const ESTADOS = {
  active: { texto: 'Activo', clase: 'bg-emerald-500' },
  paused: { texto: 'Pausado', clase: 'bg-amber-400' },
  draft: { texto: 'Borrador', clase: 'bg-neutral-400' },
  archived: { texto: 'Archivado', clase: 'bg-neutral-600' }
}

onMounted(async () => {
  try {
    await inventoryStore.initPanel()
  } catch {
    // El error ya se muestra en AdminPanel.
  }
})

function normalizar(texto) {
  return String(texto || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
}

// Busca también dentro de los tonos. Quien administra tiene el SKU o el
// nombre del tono a mano —viene en la caja o en la factura del proveedor—
// mucho más a menudo que el nombre exacto del producto.
function coincide(producto, aguja) {
  if (!aguja) return true
  const tonos = catalogo.shadesOf(producto.id)
  const campos = [
    producto.name,
    producto.category,
    producto.barcode,
    catalogo.optionName('brands', producto.brandId),
    ...tonos.map((t) => t.name),
    ...tonos.map((t) => t.sku),
    ...tonos.map((t) => t.shadeCode)
  ]
  return campos.some((campo) => normalizar(campo).includes(aguja))
}

const categoriasUsadas = computed(() => {
  const nombres = new Set(productos.value.map((p) => p.category).filter(Boolean))
  return [...nombres].sort((a, b) => a.localeCompare(b))
})

const filtrados = computed(() => {
  const aguja = normalizar(busqueda.value)
  const lista = productos.value.filter((p) => {
    if (categoria.value && p.category !== categoria.value) return false
    if (estado.value && (p.status || 'draft') !== estado.value) return false
    // Los archivados solo aparecen si se piden: son historia, no catálogo.
    if (!estado.value && (p.status || 'draft') === 'archived') return false
    return coincide(p, aguja)
  })

  const copia = [...lista]
  if (orden.value === 'nombre') copia.sort((a, b) => a.name.localeCompare(b.name))
  if (orden.value === 'precio') copia.sort((a, b) => (b.basePrice || 0) - (a.basePrice || 0))
  if (orden.value === 'stock') copia.sort((a, b) => (a.stock || 0) - (b.stock || 0))
  if (orden.value === 'reciente') copia.sort((a, b) => String(b.updatedAt || '').localeCompare(String(a.updatedAt || '')))
  return copia
})

const totalPaginas = computed(() => Math.max(1, Math.ceil(filtrados.value.length / POR_PAGINA)))
const pagados = computed(() => filtrados.value.slice((pagina.value - 1) * POR_PAGINA, pagina.value * POR_PAGINA))

// Filtrar deja la paginación fuera de rango: si estabas en la página 5 y la
// búsqueda deja 3 resultados, la cuadrícula sale vacía y parece que no hay nada.
watch([busqueda, categoria, estado, orden], () => { pagina.value = 1 })
watch(totalPaginas, (total) => { if (pagina.value > total) pagina.value = total })

function limpiar() {
  busqueda.value = ''
  categoria.value = ''
  estado.value = ''
  orden.value = 'nombre'
}

function editar(producto) {
  menuAbierto.value = null
  router.push(`/admin/productos/${producto.id}`)
}

// Confirmar dentro de la aplicación, no con `window.confirm`: el diálogo del
// navegador congela la pestaña, no se puede leer en el móvil y no dice qué
// significa archivar. Aquí se explica y se puede cancelar.
function pedirArchivar(producto) {
  menuAbierto.value = null
  const tonos = catalogo.shadesOf(producto.id).length
  confirmacion.value = {
    titulo: `¿Archivar "${producto.name}"?`,
    detalle: tonos
      ? `Dejará de verse en la tienda junto con sus ${tonos} tono(s). Conserva su historial de pedidos y movimientos, y puedes recuperarlo filtrando por Archivado.`
      : 'Dejará de verse en la tienda. Conserva su historial de pedidos y movimientos, y puedes recuperarlo filtrando por Archivado.',
    confirmar: 'Archivar',
    accion: () => catalogo.archiveProduct(producto.id)
  }
}

async function alternar(producto) {
  menuAbierto.value = null
  await ejecutar(() => catalogo.setProductStatus(producto.id, producto.active ? 'paused' : 'active'))
}

async function duplicar(producto) {
  menuAbierto.value = null
  const copia = await ejecutar(() => catalogo.duplicateProduct(producto.id))
  if (!copia) return
  aviso.value = `Se creó "${copia.name}" en borrador. Cambia el nombre, sube sus fotos y publícalo.`
  router.push(`/admin/productos/${copia.id}`)
}

async function confirmar() {
  const pendiente = confirmacion.value
  confirmacion.value = null
  if (pendiente) await ejecutar(pendiente.accion)
}

async function ejecutar(accion) {
  error.value = ''
  aviso.value = ''
  ocupado.value = true
  try {
    return await accion()
  } catch (fallo) {
    error.value = fallo.message || 'No se pudo completar la acción.'
    return null
  } finally {
    ocupado.value = false
  }
}
</script>

<template>
  <div class="space-y-6" @click="menuAbierto = null">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h2 class="text-2xl font-bold text-black">Productos</h2>
        <p class="mt-1 text-sm text-neutral-500">
          {{ filtrados.length }} de {{ productos.length }} producto(s)
        </p>
      </div>
      <button
        class="rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="router.push('/admin/productos/nuevo')"
      >
        + Nuevo producto
      </button>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="aviso" class="rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">{{ aviso }}</p>

    <div class="rounded-2xl bg-white p-4 shadow-sm">
      <div class="grid gap-3 md:grid-cols-[2fr_1fr_1fr_1fr_auto]">
        <label class="relative">
          <Search class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
          <input
            v-model="busqueda"
            type="search"
            class="w-full rounded-xl border border-pink-100 py-2.5 pl-10 pr-4 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
            placeholder="Nombre, marca, tono o SKU"
          />
        </label>

        <select v-model="categoria" class="rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]">
          <option value="">Todas las categorías</option>
          <option v-for="c in categoriasUsadas" :key="c" :value="c">{{ c }}</option>
        </select>

        <select v-model="estado" class="rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]">
          <option value="">Sin archivados</option>
          <option value="active">Activos</option>
          <option value="paused">Pausados</option>
          <option value="draft">Borradores</option>
          <option value="archived">Archivados</option>
        </select>

        <select v-model="orden" class="rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]">
          <option value="nombre">Nombre (A-Z)</option>
          <option value="precio">Precio (mayor primero)</option>
          <option value="stock">Stock (menor primero)</option>
          <option value="reciente">Modificados primero</option>
        </select>

        <button
          type="button"
          class="rounded-xl bg-neutral-200 px-4 py-2.5 text-sm font-bold text-neutral-700 transition hover:bg-neutral-300"
          @click="limpiar"
        >
          Limpiar
        </button>
      </div>
    </div>

    <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      <article
        v-for="producto in pagados"
        :key="producto.id"
        class="group relative overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-pink-100"
      >
        <div class="relative h-56 overflow-hidden bg-pink-50">
          <img v-if="producto.image" :src="producto.image" :alt="producto.name" class="h-full w-full object-contain p-3" />
          <div v-else class="grid h-full place-items-center text-xs font-semibold text-neutral-400">Sin foto</div>

          <div class="absolute right-3 top-3" @click.stop>
            <div class="relative">
              <button
                class="grid size-9 place-items-center rounded-full bg-white shadow-md transition hover:bg-pink-50"
                aria-label="Acciones del producto"
                @click="menuAbierto = menuAbierto === producto.id ? null : producto.id"
              >
                <svg class="size-4" viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/></svg>
              </button>
              <div
                v-if="menuAbierto === producto.id"
                class="absolute right-0 top-10 z-20 w-48 overflow-hidden rounded-xl bg-white py-1 shadow-xl ring-1 ring-pink-100"
              >
                <button class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-[var(--primary)]" @click="editar(producto)">
                  <Pencil class="size-4" /> Editar
                </button>
                <button :disabled="ocupado" class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-[var(--primary)] disabled:opacity-50" @click="duplicar(producto)">
                  <Copy class="size-4" /> Duplicar con tonos
                </button>
                <button :disabled="ocupado" class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-[var(--primary)] disabled:opacity-50" @click="alternar(producto)">
                  <component :is="producto.active ? Pause : Play" class="size-4" />
                  {{ producto.active ? 'Pausar' : 'Activar' }}
                </button>
                <button class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-red-500" @click="pedirArchivar(producto)">
                  <Archive class="size-4" /> Archivar
                </button>
              </div>
            </div>
          </div>

          <span
            class="absolute left-3 top-3 rounded-full px-3 py-1 text-xs font-bold text-white"
            :class="ESTADOS[producto.status || 'draft']?.clase"
          >
            {{ ESTADOS[producto.status || 'draft']?.texto }}
          </span>
        </div>

        <div class="p-4">
          <h3 class="font-bold text-black">{{ producto.name }}</h3>
          <p class="mt-1 text-xs font-semibold text-neutral-500">
            {{ producto.category || 'Sin categoría' }}
            <span v-if="producto.variants.length"> · {{ producto.variants.length }} tono(s)</span>
          </p>
          <div class="mt-2 flex items-baseline gap-2">
            <span class="text-lg font-bold text-[var(--primary)]">{{ formatCurrency(producto.basePrice) }}</span>
            <span v-if="producto.enPromocion" class="text-xs font-bold text-emerald-600">
              {{ formatCurrency(producto.promoPrice) }} con promo
            </span>
          </div>
          <p class="mt-2 text-xs font-semibold" :class="producto.stock > 0 ? 'text-neutral-500' : 'text-red-500'">
            {{ producto.stock }} en venta · {{ producto.warehouseStock }} en bodega
          </p>
        </div>
      </article>
    </div>

    <p v-if="!filtrados.length" class="rounded-2xl bg-white p-10 text-center text-neutral-500">
      Ningún producto coincide con la búsqueda.
    </p>

    <div v-if="totalPaginas > 1" class="flex items-center justify-center gap-3">
      <button
        :disabled="pagina === 1"
        class="rounded-full bg-white px-4 py-2 text-sm font-bold text-neutral-700 shadow-sm ring-1 ring-pink-100 transition hover:bg-pink-50 disabled:opacity-40"
        @click="pagina -= 1"
      >
        Anterior
      </button>
      <span class="text-sm font-semibold text-neutral-500">Página {{ pagina }} de {{ totalPaginas }}</span>
      <button
        :disabled="pagina === totalPaginas"
        class="rounded-full bg-white px-4 py-2 text-sm font-bold text-neutral-700 shadow-sm ring-1 ring-pink-100 transition hover:bg-pink-50 disabled:opacity-40"
        @click="pagina += 1"
      >
        Siguiente
      </button>
    </div>

    <div
      v-if="confirmacion"
      class="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4"
      @click.self="confirmacion = null"
    >
      <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
        <h3 class="text-lg font-bold text-black">{{ confirmacion.titulo }}</h3>
        <p class="mt-2 text-sm text-neutral-600">{{ confirmacion.detalle }}</p>
        <div class="mt-6 flex justify-end gap-3">
          <button class="rounded-full bg-neutral-200 px-5 py-2.5 text-sm font-bold text-neutral-700 transition hover:bg-neutral-300" @click="confirmacion = null">
            Cancelar
          </button>
          <button class="rounded-full bg-red-500 px-5 py-2.5 text-sm font-bold text-white transition hover:bg-red-600" @click="confirmar">
            {{ confirmacion.confirmar }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
