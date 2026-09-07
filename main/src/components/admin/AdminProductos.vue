<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import AdminFilter from './AdminFilter.vue'
import { useInventoryStore } from '../../stores/inventory'

const inventoryStore = useInventoryStore()
const products = computed(() => inventoryStore.catalogWithStock)
const filteredProducts = ref([])
const selectedAction = ref(null)
const router = useRouter()


onMounted(async () => {
  try {
    await inventoryStore.init()
  } catch {
    // El error ya se muestra en AdminPanel; aquí solo evitamos una promesa sin capturar.
  }
  filteredProducts.value = products.value
})

function handleFilter(criteria) {
  if (!criteria.name && !criteria.category && !criteria.minPrice && !criteria.maxPrice) {
    filteredProducts.value = products.value
    return
  }

  filteredProducts.value = products.value.filter((product) => {
    const nameMatch = !criteria.name || product.name.toLowerCase().includes(criteria.name)
    const categoryMatch = !criteria.category || product.category.toLowerCase().includes(criteria.category)
    const minPriceMatch = !criteria.minPrice || product.price >= criteria.minPrice
    const maxPriceMatch = !criteria.maxPrice || product.price <= criteria.maxPrice
    return nameMatch && categoryMatch && minPriceMatch && maxPriceMatch
  })
}

function handleReset() {
  filteredProducts.value = products.value
}

function handleProductAction(action, product) {
  if (action === 'edit') {
    // El modal se quedaba corto: no tenía sitio para tonos ni imágenes y
    // obligaba a salir para crear una marca que faltara.
    router.push(`/admin/productos/${product.id}`)
  } else if (action === 'delete') {
    // Archivar, no borrar: el producto aparece en pedidos y movimientos
    // anteriores y borrarlo rompería esa trazabilidad.
    if (window.confirm(`¿Archivar "${product.name}"? Dejará de verse en la tienda pero conserva su historial.`)) {
      filteredProducts.value = filteredProducts.value.filter((p) => p.id !== product.id)
      inventoryStore.deleteProduct(product.id)
    }
  } else if (action === 'toggle') {
    inventoryStore.toggleProductActive(product.id, !product.active)
  }
  selectedAction.value = null
}



</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h2 class="text-2xl font-bold text-black">Productos</h2>
      <button
        class="rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="router.push('/admin/productos/nuevo')"
      >
        + Nuevo producto
      </button>
    </div>

    <AdminFilter @filter="handleFilter" @reset="handleReset" />

    <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      <article
        v-for="product in filteredProducts"
        :key="product.id"
        class="group relative overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-pink-100"
      >
        <div class="relative h-56 overflow-hidden bg-pink-50">
          <img
            :src="product.image"
            :alt="product.name"
            class="h-full w-full object-contain p-3"
          />
          <div class="absolute right-3 top-3">
            <div class="relative">
              <button
                class="grid size-9 place-items-center rounded-full bg-white shadow-md transition hover:bg-pink-50"
                aria-label="Acciones del producto"
                @click="selectedAction = selectedAction === product.id ? null : product.id"
              >
                <svg class="size-4" viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/></svg>
              </button>
              <div
                v-if="selectedAction === product.id"
                class="absolute right-0 top-10 z-10 w-40 overflow-hidden rounded-xl bg-white py-1 shadow-xl"
              >
                <button
                  class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                  @click="handleProductAction('edit', product)"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 3a2.8 2.8 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                  Editar
                </button>
                <button
                  class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-red-500"
                  @click="handleProductAction('delete', product)"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m3 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
                  Eliminar
                </button>
                <button
                  class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                  @click="handleProductAction('toggle', product)"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path v-if="product.active" d="M10 9l5 3-5 3V9z"/><path v-else d="M10 9l5 3-5 3V9z"/></svg>
                  {{ product.active ? 'Pausar' : 'Activar' }}
                </button>
              </div>
            </div>
          </div>
          <span
            v-if="!product.active"
            class="absolute left-3 top-3 rounded-full bg-amber-400 px-3 py-1 text-xs font-bold text-white"
          >
            Pausado
          </span>
        </div>
        <div class="p-4">
          <h3 class="font-bold text-black">{{ product.name }}</h3>
          <p class="mt-1 line-clamp-2 text-sm text-neutral-500">{{ product.description }}</p>
          <p class="mt-2 text-xs font-semibold text-neutral-500">Categoría: {{ product.category }}</p>
          <p class="mt-2 text-lg font-bold text-[var(--primary)]">{{ product.price }}</p>
        </div>
      </article>
    </div>

    <p v-if="!filteredProducts.length" class="rounded-2xl bg-white p-10 text-center text-neutral-500">
      No hay productos que coincidan con los filtros.
    </p>

  </div>
</template>
