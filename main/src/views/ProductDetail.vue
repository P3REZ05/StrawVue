<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { useCartStore } from '../stores/cart'
import { useCatalogStore } from '../stores/catalog'
import { useInventoryStore } from '../stores/inventory'
import { formatCurrency } from '../utils/formatCurrency'

const route = useRoute()
const cart = useCartStore()
const catalogo = useCatalogStore()
const inventario = useInventoryStore()

const quantity = ref(1)
const added = ref(false)
const tonoElegido = ref(null)

onMounted(() => {
  inventario.init().catch(() => {})
})

const product = computed(() => inventario.catalogWithStock.find((item) => item.id === Number(route.params.id)))
const tonos = computed(() => inventario.shadesWithStock(Number(route.params.id)))
const galeria = computed(() => catalogo.imagesOf(Number(route.params.id)))

// Al abrir la ficha se preselecciona el tono marcado por defecto, o el primero
// que tenga existencias: obligar a elegir antes de ver el precio es fricción.
watch(tonos, (lista) => {
  if (tonoElegido.value || !lista.length) return
  tonoElegido.value = lista.find((t) => t.isDefault && t.stock > 0)
    || lista.find((t) => t.stock > 0)
    || lista[0]
}, { immediate: true })

const precio = computed(() => tonoElegido.value?.price ?? product.value?.promoPrice ?? product.value?.salePrice ?? product.value?.price ?? 0)
const precioBase = computed(() => tonoElegido.value?.basePrice ?? product.value?.basePrice ?? precio.value)
const enPromocion = computed(() => precioBase.value > precio.value)
const etiquetaPromo = computed(() => tonoElegido.value?.promoLabel || product.value?.promoLabel || '')
const tituloPromo = computed(() => tonoElegido.value?.promoTitle || '')
const disponible = computed(() =>
  tonos.value.length ? Number(tonoElegido.value?.stock || 0) : Number(product.value?.saleStock || 0)
)
// Si el tono tiene foto propia se muestra esa: es lo que hace que el cliente
// vea el labial en el color que va a comprar.
const imagenPrincipal = computed(() =>
  tonoElegido.value?.image || galeria.value[0]?.url || product.value?.image || ''
)
const hayAlgoDisponible = computed(() =>
  tonos.value.length ? tonos.value.some((t) => t.stock > 0) : disponible.value > 0
)

watch(tonoElegido, () => { quantity.value = 1 })

function subtonoDe(tono) {
  return catalogo.optionName('undertones', tono.undertoneId)
}

function addToCart() {
  if (!product.value || disponible.value <= 0) return
  if (tonos.value.length && !tonoElegido.value) return

  cart.add({
    ...product.value,
    image: imagenPrincipal.value,
    variantId: tonoElegido.value?.id || null,
    variantName: tonoElegido.value ? `${tonoElegido.value.shadeCode} ${tonoElegido.value.name}`.trim() : '',
    swatchHex: tonoElegido.value?.swatchHex || '',
    sku: tonoElegido.value?.sku || '',
    price: precio.value,
    stock: disponible.value,
    saleStock: disponible.value
  }, quantity.value)

  cart.openDrawer()
  added.value = true
  window.setTimeout(() => { added.value = false }, 2200)
}
</script>

<template>
  <main class="bg-pink-50/40 py-12 sm:py-18">
    <section v-if="product" class="mx-auto max-w-6xl px-5 sm:px-8 lg:px-10">
      <nav class="mb-8 flex flex-wrap gap-2 text-sm text-neutral-500">
        <RouterLink class="hover:text-[var(--primary)]" to="/tienda">Tienda</RouterLink>
        <span>/</span>
        <RouterLink class="hover:text-[var(--primary)]" :to="{ path: '/tienda', query: { categoria: product.category } }">{{ product.category }}</RouterLink>
        <span>/</span>
        <span class="text-black">{{ product.name }}</span>
      </nav>

      <div class="grid gap-10 rounded-3xl bg-white p-5 shadow-sm sm:p-8 md:grid-cols-2">
        <div>
          <div class="flex min-h-96 items-center justify-center rounded-2xl bg-pink-50">
            <img v-if="imagenPrincipal" :src="imagenPrincipal" :alt="product.name" class="max-h-125 w-full object-contain p-5" />
            <span v-else class="text-sm text-neutral-400">Sin imagen</span>
          </div>
          <div v-if="galeria.length > 1" class="mt-3 flex gap-2 overflow-x-auto">
            <img v-for="img in galeria" :key="img.id" :src="img.url" :alt="img.alt || ''" class="size-16 shrink-0 rounded-xl border border-pink-100 object-cover" />
          </div>
        </div>

        <div class="py-2">
          <p class="text-sm font-bold tracking-wider text-[var(--primary)]">{{ product.category }}</p>
          <h1 class="mt-3 text-4xl font-bold leading-tight text-black">{{ product.name }}</h1>
          <div class="mt-5 flex flex-wrap items-center gap-3">
            <p class="text-3xl font-bold text-[var(--primary)]">{{ formatCurrency(precio) }}</p>
            <p v-if="enPromocion" class="text-xl text-neutral-400 line-through">{{ formatCurrency(precioBase) }}</p>
            <span v-if="etiquetaPromo" class="rounded-full bg-[var(--primary)] px-3 py-1 text-xs font-bold text-white">{{ etiquetaPromo }}</span>
          </div>
          <p v-if="tituloPromo" class="mt-1 text-sm font-semibold text-emerald-600">{{ tituloPromo }}</p>
          <p class="mt-6 leading-8 text-neutral-600">{{ product.description }}</p>

          <!-- Selector de tonos -->
          <div v-if="tonos.length" class="mt-7">
            <div class="flex items-baseline justify-between">
              <p class="text-sm font-bold text-neutral-700">
                Tono:
                <span class="text-[var(--primary)]">{{ tonoElegido ? `${tonoElegido.shadeCode} ${tonoElegido.name}` : 'elige uno' }}</span>
              </p>
              <span class="text-xs text-neutral-400">{{ tonos.length }} tonos</span>
            </div>

            <div class="mt-3 flex flex-wrap gap-2.5">
              <button
                v-for="tono in tonos" :key="tono.id" type="button"
                class="relative size-11 rounded-full border-2 transition"
                :class="[
                  tonoElegido?.id === tono.id ? 'border-[var(--primary)] scale-110 shadow-md' : 'border-black/10 hover:border-black/25',
                  tono.stock <= 0 ? 'cursor-not-allowed opacity-40' : ''
                ]"
                :style="tono.image ? {} : { background: tono.swatchHex || '#e5e5e5' }"
                :disabled="tono.stock <= 0"
                :title="`${tono.shadeCode} ${tono.name}${tono.stock <= 0 ? ' · agotado' : ''}`"
                :aria-label="`${tono.shadeCode} ${tono.name}`"
                :aria-pressed="tonoElegido?.id === tono.id"
                @click="tonoElegido = tono"
              >
                <img v-if="tono.image" :src="tono.image" alt="" class="size-full rounded-full object-cover" />
                <!-- Una diagonal marca el agotado sin depender solo del color,
                     que sería invisible para quien no distingue matices. -->
                <span v-if="tono.stock <= 0" class="pointer-events-none absolute inset-0 grid place-items-center">
                  <span class="h-0.5 w-9 rotate-45 rounded bg-neutral-700"></span>
                </span>
              </button>
            </div>

            <p v-if="tonoElegido" class="mt-3 text-xs text-neutral-500">
              <span v-if="subtonoDe(tonoElegido)">Subtono {{ subtonoDe(tonoElegido) }}</span>
              <span v-if="subtonoDe(tonoElegido) && tonoElegido.depth"> · </span>
              <span v-if="tonoElegido.depth">Profundidad {{ tonoElegido.depth }}/100</span>
              <span v-if="tonoElegido.sku"> · SKU {{ tonoElegido.sku }}</span>
            </p>
          </div>

          <p class="mt-6 text-sm font-semibold" :class="disponible ? 'text-emerald-600' : 'text-red-600'">
            <template v-if="disponible">{{ disponible }} unidades disponibles</template>
            <template v-else-if="tonos.length && hayAlgoDisponible">Este tono está agotado — prueba otro</template>
            <template v-else>Producto agotado</template>
          </p>

          <div v-if="disponible > 0" class="mt-7 flex gap-3">
            <div class="flex items-center rounded-full border border-pink-200">
              <button class="size-11 text-xl text-[var(--primary)] disabled:text-neutral-300" :disabled="quantity === 1" aria-label="Reducir cantidad" @click="quantity--">−</button>
              <span class="w-8 text-center font-bold">{{ quantity }}</span>
              <button class="size-11 text-xl text-[var(--primary)] disabled:text-neutral-300" :disabled="quantity >= disponible" aria-label="Aumentar cantidad" @click="quantity++">+</button>
            </div>
            <button class="flex-1 rounded-full bg-[var(--primary)] px-5 py-3 text-sm font-bold text-white transition hover:bg-[var(--info)]" @click="addToCart">Agregar al carrito</button>
          </div>

          <p v-else class="mt-6 rounded-2xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-600">
            {{ tonos.length && hayAlgoDisponible ? 'Elige un tono disponible para continuar.' : 'Este producto está agotado por el momento.' }}
          </p>

          <div v-if="added" class="mt-6 rounded-2xl bg-emerald-50 px-4 py-3 text-sm font-semibold text-emerald-700">
            ¡Producto agregado al carrito!
          </div>
        </div>
      </div>
    </section>

    <section v-else class="mx-auto max-w-4xl px-5 py-12 text-center">
      <h1 class="text-3xl font-bold text-black">Producto no encontrado</h1>
      <RouterLink class="mt-6 inline-block rounded-full bg-[var(--primary)] px-5 py-3 text-sm font-bold text-white" to="/tienda">Volver a la tienda</RouterLink>
    </section>
  </main>
</template>
