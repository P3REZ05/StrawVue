<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { useCartStore } from '../stores/cart'
import { useInventoryStore } from '../stores/inventory'
import { formatCurrency } from '../utils/formatCurrency'

const route = useRoute()
const cart = useCartStore()
const inventoryStore = useInventoryStore()
const quantity = ref(1)
const added = ref(false)
const selectedVariant = ref(null)

onMounted(() => {
  inventoryStore.init().catch(() => {})
})

const product = computed(() => inventoryStore.catalogWithStock.find((item) => item.id === Number(route.params.id)))
const selectedPrice = computed(() => selectedVariant.value?.price || product.value?.price || 0)

const productVariants = computed(() => product.value?.variants || [])
const availableStock = computed(() => Number(selectedVariant.value?.stock ?? product.value?.saleStock ?? product.value?.stock ?? 0))

function addToCart() {
  if (!product.value || availableStock.value <= 0 || (productVariants.value.length && !selectedVariant.value)) return

  cart.add({ ...product.value, variantId: selectedVariant.value?.id, variantName: selectedVariant.value?.name, price: selectedPrice.value, stock: selectedVariant.value?.stock ?? availableStock.value, saleStock: selectedVariant.value?.stock ?? availableStock.value }, quantity.value)
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
        <div class="flex min-h-96 items-center justify-center rounded-2xl bg-pink-50">
          <img :src="product.image" :alt="product.name" class="max-h-125 w-full object-contain p-5" />
        </div>

        <div class="py-2">
          <p class="text-sm font-bold tracking-wider text-[var(--primary)]">{{ product.category }}</p>
          <h1 class="mt-3 text-4xl font-bold leading-tight text-black">{{ product.name }}</h1>
          <p class="mt-5 text-3xl font-bold text-[var(--primary)]">{{ formatCurrency(selectedPrice) }}</p>
          <p class="mt-6 leading-8 text-neutral-600">{{ product.description }}</p>

          <div v-if="productVariants.length" class="mt-6">
            <label class="mb-2 block text-sm font-bold text-neutral-700" for="product-variant">Selecciona una variante</label>
            <select id="product-variant" v-model="selectedVariant" class="w-full rounded-xl border border-pink-200 bg-white px-4 py-3 outline-none focus:border-[var(--primary)]">
              <option :value="null" disabled>Elige un tono o referencia</option>
              <option v-for="variant in productVariants" :key="variant.id" :value="variant" :disabled="variant.stock <= 0">{{ variant.name }}{{ variant.stock <= 0 ? ' - Agotado' : ` - ${variant.stock} disponibles` }}</option>
            </select>
          </div>

          <p class="mt-6 text-sm font-semibold" :class="availableStock ? 'text-emerald-600' : 'text-red-600'">
            {{ availableStock ? `${availableStock} unidades disponibles` : 'Producto agotado' }}
          </p>

          <div v-if="availableStock && (!productVariants.length || selectedVariant)" class="mt-7 flex gap-3">
            <div class="flex items-center rounded-full border border-pink-200">
              <button class="size-11 text-xl text-[var(--primary)] disabled:text-neutral-300" :disabled="quantity === 1" aria-label="Reducir cantidad" @click="quantity--">−</button>
              <span class="w-8 text-center font-bold">{{ quantity }}</span>
              <button class="size-11 text-xl text-[var(--primary)] disabled:text-neutral-300" :disabled="quantity === availableStock" aria-label="Aumentar cantidad" @click="quantity++">+</button>
            </div>
            <button class="flex-1 rounded-full bg-[var(--primary)] px-5 py-3 text-sm font-bold text-white transition hover:bg-[var(--info)]" @click="addToCart">Agregar al carrito</button>
          </div>

          <p v-else class="mt-6 rounded-2xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-600">
            Este producto está agotado por el momento.
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
