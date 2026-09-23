<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ProductCard from '../components/products/ProductCard.vue'
import { useCatalogStore } from '../stores/catalog'
import { useCollectionsStore } from '../stores/collections'
import { useInventoryStore } from '../stores/inventory'

const route = useRoute()
const router = useRouter()
const inventoryStore = useInventoryStore()
const catalogo = useCatalogStore()
const colecciones = useCollectionsStore()

// Las categorías salen del catálogo real. Antes venían de `mockData`, así que
// la tienda ofrecía filtros de categorías que podían no existir en la base.
const categories = computed(() => catalogo.rootCategories)

const search = ref('')
const selectedCategory = ref(route.query.categoria || '')
// La colección viaja por la URL como SLUG, no como id: `?coleccion=alisia` se
// puede leer, copiar y mandar por WhatsApp, que es como se comparte una
// campaña. El id sería un número sin significado y cambiaría si algún día hay
// que rehacer la tabla.
const selectedCollection = ref(route.query.coleccion || '')
const selectedPrice = ref('all')
const selectedSort = ref('featured')
const inStockOnly = ref(false)
const onSaleOnly = ref(false)
// Filtros propios de maquillaje: el cliente busca "bases cálidas" o
// "labiales nude", no un rango de precio.
const selectedUndertone = ref('')
const selectedFamily = ref('')

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
  // Si falla, el desplegable de Colecciones no se pinta y la tienda sigue
  // funcionando entera: es un filtro más, no un requisito.
  colecciones.init().catch(() => {})
})

// Las publicadas, tengan foto o no: la foto solo hace falta para salir en la
// portada, y una colección sin ella igualmente tiene productos que filtrar.
// Una colección en borrador sí queda fuera, o la campaña se destaparía antes
// de tiempo. RLS ya impide que una clienta las reciba; esto cubre el caso de
// una administradora que abra la tienda con su sesión iniciada.
const coleccionesDisponibles = computed(() => colecciones.publicadas)

// Del slug de la URL al id que llevan los productos.
const coleccionElegida = computed(() =>
  selectedCollection.value ? colecciones.porSlug(selectedCollection.value) : null
)

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

    // Mientras las colecciones no hayan cargado, `coleccionElegida` es null y
    // este filtro no descarta nada. Es deliberado: enseñar toda la tienda
    // medio segundo es mejor que enseñar «no encontramos productos» y que la
    // clienta se vaya antes de que llegue la respuesta.
    const matchesCollection = !coleccionElegida.value
      || Number(product.collectionId) === coleccionElegida.value.id

    // Un producto coincide si ALGUNO de sus tonos coincide: quien busca una
    // base cálida quiere ver la base, aunque tenga también tonos fríos.
    const tonos = inventoryStore.shadesWithStock(product.id)
    const matchesUndertone = !selectedUndertone.value
      || tonos.some((t) => String(t.undertoneId) === String(selectedUndertone.value))
    const matchesFamily = !selectedFamily.value
      || tonos.some((t) => String(t.shadeFamilyId) === String(selectedFamily.value))
    const hasDiscount = !!product.salePrice && Number(product.salePrice) < Number(product.price || Infinity)
    const matchesSale = !onSaleOnly.value || hasDiscount

    return matchesCategory && matchesSearch && matchesActive && inRange && matchesStock && matchesSale
      && matchesUndertone && matchesFamily && matchesCollection
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

// Se calcula una sola vez: estaba escrita a mano en el `v-if` de la barra de
// filtros activos, y ahora la usa también el botón Limpiar.
const hayFiltros = computed(() =>
  Boolean(search.value || selectedCategory.value || selectedCollection.value
    || selectedUndertone.value || selectedFamily.value || selectedPrice.value !== 'all'
    || selectedSort.value !== 'featured' || inStockOnly.value || onSaleOnly.value)
)

function clearFilters() {
  search.value = ''
  selectedCategory.value = ''
  selectedCollection.value = ''
  selectedUndertone.value = ''
  selectedFamily.value = ''
  selectedPrice.value = 'all'
  selectedSort.value = 'featured'
  inStockOnly.value = false
  onSaleOnly.value = false
  router.replace({ query: {} })
}

/**
 * Vuelca los filtros que viajan por la URL, conservando el resto.
 *
 * Antes cada control escribía `{ query: { categoria } }` y con eso borraba lo
 * que hubiera puesto otro: elegir una categoría te sacaba de «Ofertas». Con
 * dos filtros en la URL el fallo era tolerable; con tres ya no.
 */
function sincronizarUrl() {
  const q = { ...route.query }
  const poner = (clave, valor) => {
    if (valor) q[clave] = valor
    else delete q[clave]
  }
  poner('categoria', selectedCategory.value)
  poner('coleccion', selectedCollection.value)
  router.replace({ query: q })
}

watch(() => route.query.categoria, (category) => {
  selectedCategory.value = category || ''
})

watch(() => route.query.coleccion, (slug) => {
  selectedCollection.value = slug || ''
})
</script>

<template>
  <main class="bg-pink-50/40 py-8 sm:py-12">
    <section class="mx-auto max-w-7xl px-5 sm:px-8 lg:px-10">
      <p class="text-center text-xs font-bold tracking-[0.22em] text-[var(--primary)] sm:text-sm">STRAWBERRY MAKEUP</p>
      <h1 class="mt-2 text-center text-3xl font-bold leading-tight text-black sm:text-4xl lg:text-[3rem]">Nuestros productos</h1>
      <p class="mx-auto mt-3 max-w-2xl text-center text-sm leading-6 text-neutral-600 sm:text-base">Encuentra tus favoritos y crea looks que se sienten como tú.</p>

      <!--
        Los filtros en el celular.

        Antes cada control ocupaba una fila entera y ancha: siete bloques
        apilados que empujaban los productos fuera de la primera pantalla. La
        clienta llegaba a la tienda y lo primero que veía era un formulario.

        Ahora van en cuadrícula de dos columnas —el buscador ocupa las dos,
        porque escribir en medio campo es incómodo— y los interruptores de
        "En stock" y "Ofertas" comparten fila. En escritorio se estiran en una
        sola línea, como estaban.
      -->
      <div class="mt-6 rounded-2xl bg-white p-2.5 shadow-sm sm:p-3">
        <div class="grid grid-cols-2 gap-2 md:flex md:flex-nowrap md:items-center">
          <input
            v-model="search"
            class="col-span-2 h-11 min-w-0 rounded-xl border border-pink-100 px-3 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100 md:max-w-[240px] md:flex-1"
            type="search"
            placeholder="Buscar productos"
            aria-label="Buscar productos"
          />

          <select
            v-model="selectedCategory"
            class="h-11 min-w-0 rounded-xl border border-pink-100 bg-white px-2.5 text-xs outline-none focus:border-[var(--primary)] sm:text-sm md:max-w-[170px] md:flex-1"
            aria-label="Filtrar por categoría"
            @change="sincronizarUrl"
          >
            <option value="">Categorías</option>
            <option v-for="category in categories" :key="category.id" :value="category.name">{{ category.name }}</option>
          </select>

          <!-- Colecciones. Va pegado a Categorías porque es el mismo gesto —
               «enséñame solo esto»— y porque desde la portada se llega aquí
               con `?coleccion=` ya puesto: el desplegable tiene que mostrar
               cuál, no dejar a la clienta sin saber por qué ve doce productos
               en vez de cuarenta. Si no hay ninguna publicada no se pinta. -->
          <select
            v-if="coleccionesDisponibles.length"
            v-model="selectedCollection"
            class="h-11 min-w-0 rounded-xl border border-pink-100 bg-white px-2.5 text-xs outline-none focus:border-[var(--primary)] sm:text-sm md:max-w-[170px] md:flex-1"
            aria-label="Filtrar por colección"
            @change="sincronizarUrl"
          >
            <option value="">Colecciones</option>
            <option v-for="c in coleccionesDisponibles" :key="c.id" :value="c.slug">{{ c.name }}</option>
          </select>

          <select
            v-model="selectedPrice"
            class="h-11 min-w-0 rounded-xl border border-pink-100 bg-white px-2.5 text-xs outline-none focus:border-[var(--primary)] sm:text-sm md:max-w-[170px] md:flex-1"
            aria-label="Filtrar por precio"
          >
            <option v-for="option in priceOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
          </select>

          <select
            v-if="catalogo.undertones.length"
            v-model="selectedUndertone"
            class="h-11 min-w-0 rounded-xl border border-pink-100 bg-white px-2.5 text-xs outline-none focus:border-[var(--primary)] sm:text-sm md:max-w-[150px] md:flex-1"
            aria-label="Filtrar por subtono"
          >
            <option value="">Subtono</option>
            <option v-for="u in catalogo.undertones" :key="u.id" :value="u.id">{{ u.name }}</option>
          </select>

          <select
            v-if="catalogo.shadeFamilies.length"
            v-model="selectedFamily"
            class="h-11 min-w-0 rounded-xl border border-pink-100 bg-white px-2.5 text-xs outline-none focus:border-[var(--primary)] sm:text-sm md:max-w-[150px] md:flex-1"
            aria-label="Filtrar por familia de tono"
          >
            <option value="">Familia</option>
            <option v-for="f in catalogo.shadeFamilies" :key="f.id" :value="f.id">{{ f.name }}</option>
          </select>

          <select
            v-model="selectedSort"
            class="col-span-2 h-11 min-w-0 rounded-xl border border-pink-100 bg-white px-2.5 text-xs outline-none focus:border-[var(--primary)] sm:text-sm md:col-span-1 md:max-w-[190px] md:flex-1"
            aria-label="Ordenar"
          >
            <option v-for="option in sortOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
          </select>

          <!--
            Interruptores, no casillas. Una casilla de 14px se falla con el
            pulgar; el botón entero de 44px de alto no.
          -->
          <div class="col-span-2 flex gap-2 md:contents">
            <button
              type="button"
              class="h-11 flex-1 rounded-xl border text-xs font-bold transition md:h-11 md:flex-none md:rounded-full md:px-4"
              :class="inStockOnly
                ? 'border-[var(--primary)] bg-[var(--primary)] text-white'
                : 'border-pink-100 bg-pink-50/60 text-neutral-700 hover:border-pink-200'"
              :aria-pressed="inStockOnly"
              @click="inStockOnly = !inStockOnly"
            >
              En stock
            </button>

            <button
              type="button"
              class="h-11 flex-1 rounded-xl border text-xs font-bold transition md:h-11 md:flex-none md:rounded-full md:px-4"
              :class="onSaleOnly
                ? 'border-[var(--primary)] bg-[var(--primary)] text-white'
                : 'border-pink-100 bg-pink-50/60 text-neutral-700 hover:border-pink-200'"
              :aria-pressed="onSaleOnly"
              @click="onSaleOnly = !onSaleOnly"
            >
              Ofertas
            </button>

            <button
              v-if="hayFiltros"
              type="button"
              class="h-11 flex-1 whitespace-nowrap rounded-xl border border-neutral-200 text-xs font-bold text-neutral-700 transition hover:border-[var(--primary)] hover:text-[var(--primary)] md:flex-none md:rounded-full md:px-4"
              @click="clearFilters"
            >
              Limpiar
            </button>
          </div>
        </div>
      </div>

      <div v-if="hayFiltros" class="mt-5 flex flex-wrap items-center justify-between gap-2">
        <p class="text-sm text-neutral-600">
          Filtros activos: <strong>{{ selectedCategory || 'Todas las categorías' }}</strong>
          <template v-if="coleccionElegida">
            <span class="mx-2 text-neutral-300">•</span>
            <strong>Colección {{ coleccionElegida.name }}</strong>
          </template>
          <span class="mx-2 text-neutral-300">•</span>
          <span>{{ selectedPrice === 'all' ? 'Todos los precios' : priceOptions.find((option) => option.value === selectedPrice)?.label }}</span>
        </p>
        <button class="text-sm font-bold text-[var(--primary)] hover:underline" @click="clearFilters">Ver todo</button>
      </div>

      <p class="mt-6 text-sm text-neutral-500">{{ visibleProducts.length }} producto(s) encontrado(s)</p>

      <div v-if="visibleProducts.length" class="mt-5 grid gap-3 min-[480px]:grid-cols-2 sm:gap-5 lg:grid-cols-3 xl:grid-cols-4">
        <ProductCard v-for="product in visibleProducts" :key="product.id" :product="product" />
      </div>

      <div v-else class="mt-5 rounded-2xl bg-white p-10 text-center shadow-sm">
        <h2 class="text-2xl font-bold">No encontramos productos</h2>
        <p class="mt-2 text-neutral-600">Prueba con otra categoría, otro rango de precio o cambia los criterios de búsqueda.</p>
      </div>
    </section>
  </main>
</template>
