<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ProductCard from '../components/products/ProductCard.vue'
import { categories } from '../data/mockData'
import { useInventoryStore } from '../stores/inventory'

const route = useRoute()
const router = useRouter()
const inventoryStore = useInventoryStore()

const search = ref('')
const selectedCategory = ref(route.query.categoria || '')
const selectedPrice = ref('all')
const selectedSort = ref('featured')
const inStockOnly = ref(false)
const onSaleOnly = ref(false)

// Initialize onSaleOnly from query param 'ofertas'
onSaleOnly.value = route.query.ofertas === 'true'

// Keep URL in sync when toggling the onSaleOnly checkbox
watch(onSaleOnly, (val) => {
  const q = { ...route.query }
  if (val) {
    q.ofertas = 'true'
  } else {
    delete q.ofertas
  }
  router.replace({ query: q })
})

// Update onSaleOnly when route changes (e.g., from header link)
watch(() => route.query.ofertas, (val) => {
  onSaleOnly.value = val === 'true'
})

const priceOptions = [
  { value: 'all', label: 'Todos los precios' },
  { value: '0-25000', label: 'Hasta $25.000' },
  { value: '25000-50000', label: '$25.000 - $50.000' },
  { value: '50000-100000', label: '$50.000 - $100.000' },
  { value: '100000-200000', label: '$100.000 - $200.000' },
  { value: '200000-plus', label: 'Más de $200.000' }
]

const sortOptions = [
  { value: 'featured', label: 'Destacados' },
  { value: 'price-asc', label: 'Precio: menor a mayor' },
  { value: 'price-desc', label: 'Precio: mayor a menor' },
  { value: 'name-asc', label: 'Nombre: A - Z' },
  { value: 'name-desc', label: 'Nombre: Z - A' },
  { value: 'stock-desc', label: 'Stock disponible' }
]

onMounted(() => {
  inventoryStore.init().catch(() => {})
})

const visibleProducts = computed(() => {
  const normalizedSearch = search.value.trim().toLowerCase()

  const filtered = inventoryStore.catalogWithStock.filter((product) => {
    const matchesCategory = !selectedCategory.value || product.category.toLowerCase() === selectedCategory.value.toLowerCase()
    const text = `${product.name} ${product.description ?? ''} ${product.category ?? ''}`.toLowerCase()
    const matchesSearch = !normalizedSearch || text.includes(normalizedSearch)
    const matchesActive = product.active !== false

    const priceValue = Number(product.salePrice ?? product.price ?? 0)
    const inRange = (() => {
      switch (selectedPrice.value) {
        case '0-25000': return priceValue <= 25000
        case '25000-50000': return priceValue > 25000 && priceValue <= 50000
        case '50000-100000': return priceValue > 50000 && priceValue <= 100000
        case '100000-200000': return priceValue > 100000 && priceValue <= 200000
        case '200000-plus': return priceValue > 200000
        default: return true
      }
    })()

    const matchesStock = !inStockOnly.value || Number(product.stock ?? 0) > 0
    const hasDiscount = !!product.salePrice && Number(product.salePrice) < Number(product.price || Infinity)
    const matchesSale = !onSaleOnly.value || hasDiscount

    return matchesCategory && matchesSearch && matchesActive && inRange && matchesStock && matchesSale
  })

  return filtered.sort((a, b) => {
    const priceA = Number(a.salePrice ?? a.price ?? 0)
    const priceB = Number(b.salePrice ?? b.price ?? 0)

    switch (selectedSort.value) {
      case 'price-asc':
        return priceA - priceB
      case 'price-desc':
        return priceB - priceA
      case 'name-asc':
        return (a.name || '').localeCompare(b.name || '')
      case 'name-desc':
        return (b.name || '').localeCompare(a.name || '')
      case 'stock-desc':
        return Number(b.stock ?? 0) - Number(a.stock ?? 0)
      default:
        return priceB - priceA
    }
  })
})

function clearFilters() {
  search.value = ''
  selectedCategory.value = ''
  selectedPrice.value = 'all'
  selectedSort.value = 'featured'
  inStockOnly.value = false
  onSaleOnly.value = false
  router.replace({ query: {} })
}

function updateCategory() {
  router.replace({ query: selectedCategory.value ? { categoria: selectedCategory.value } : {} })
}

watch(() => route.query.categoria, (category) => {
  selectedCategory.value = category || ''
})
</script>

<template>
  <main class="bg-pink-50/40 py-8 sm:py-12">
    <section class="mx-auto max-w-7xl px-5 sm:px-8 lg:px-10">
      <p class="text-center text-xs font-bold tracking-[0.22em] text-[var(--primary)] sm:text-sm">STRAWBERRY MAKEUP</p>
      <h1 class="mt-2 text-center text-3xl font-bold leading-tight text-black sm:text-4xl lg:text-[3rem]">Nuestros productos</h1>
      <p class="mx-auto mt-3 max-w-2xl text-center text-sm leading-6 text-neutral-600 sm:text-base">Encuentra tus favoritos y crea looks que se sienten como tú.</p>

      <div class="mt-7 flex flex-col gap-2 rounded-2xl bg-white p-3 shadow-sm md:flex-row md:flex-nowrap md:items-center">
        <input v-model="search" class="w-full min-w-0 flex-1 rounded-xl border border-pink-100 px-3 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100 md:max-w-[240px]" type="search" placeholder="Buscar productos" aria-label="Buscar productos" />

        <select v-model="selectedCategory" class="w-full min-w-0 flex-1 rounded-xl border border-pink-100 bg-white px-3 py-2.5 text-sm outline-none focus:border-[var(--primary)] md:max-w-[180px]" @change="updateCategory">
          <option value="">Todas las categorías</option>
          <option v-for="category in categories" :key="category.id" :value="category.name">{{ category.name }}</option>
        </select>

        <select v-model="selectedPrice" class="w-full min-w-0 flex-1 rounded-xl border border-pink-100 bg-white px-3 py-2.5 text-sm outline-none focus:border-[var(--primary)] md:max-w-[180px]">
          <option v-for="option in priceOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
        </select>

        <select v-model="selectedSort" class="w-full min-w-0 flex-1 rounded-xl border border-pink-100 bg-white px-3 py-2.5 text-sm outline-none focus:border-[var(--primary)] md:max-w-[200px]">
          <option v-for="option in sortOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
        </select>

        <label class="flex cursor-pointer items-center justify-center gap-1.5 rounded-full border border-pink-100 bg-pink-50/60 px-2.5 py-2 text-xs font-medium text-neutral-700 md:min-w-[90px]">
          <input v-model="inStockOnly" type="checkbox" class="h-3.5 w-3.5 accent-[var(--primary)]" />
          En stock
        </label>

        <label class="flex cursor-pointer items-center justify-center gap-1.5 rounded-full border border-pink-100 bg-pink-50/60 px-2.5 py-2 text-xs font-medium text-neutral-700 md:min-w-[90px]">
          <input v-model="onSaleOnly" type="checkbox" class="h-3.5 w-3.5 accent-[var(--primary)]" />
          Ofertas
        </label>

        <button class="whitespace-nowrap rounded-full border border-neutral-200 px-3 py-2 text-xs font-semibold text-neutral-700 transition hover:border-[var(--primary)] hover:text-[var(--primary)] md:min-w-[80px]" @click="clearFilters">
          Limpiar
        </button>
      </div>

      <div v-if="selectedCategory || selectedPrice !== 'all' || inStockOnly || onSaleOnly" class="mt-5 flex items-center justify-between gap-3">
        <p class="text-sm text-neutral-600">
          Filtros activos: <strong>{{ selectedCategory || 'Todas las categorías' }}</strong>
          <span class="mx-2 text-neutral-300">•</span>
          <span>{{ selectedPrice === 'all' ? 'Todos los precios' : priceOptions.find((option) => option.value === selectedPrice)?.label }}</span>
        </p>
        <button class="text-sm font-bold text-[var(--primary)] hover:underline" @click="clearFilters">Ver todo</button>
      </div>

      <p class="mt-6 text-sm text-neutral-500">{{ visibleProducts.length }} producto(s) encontrado(s)</p>

      <div v-if="visibleProducts.length" class="mt-5 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <ProductCard v-for="product in visibleProducts" :key="product.id" :product="product" />
      </div>

      <div v-else class="mt-5 rounded-2xl bg-white p-10 text-center shadow-sm">
        <h2 class="text-2xl font-bold">No encontramos productos</h2>
        <p class="mt-2 text-neutral-600">Prueba con otra categoría, otro rango de precio o cambia los criterios de búsqueda.</p>
      </div>
    </section>
  </main>
</template>
