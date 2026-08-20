<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ProductCard from '../components/products/ProductCard.vue'
import { categories, products } from '../data/mockData'

const route = useRoute()
const router = useRouter()
const search = ref('')
const selectedCategory = ref(route.query.categoria || '')

const visibleProducts = computed(() => products.filter((product) => {
  const matchesCategory = !selectedCategory.value || product.category.toLowerCase() === selectedCategory.value.toLowerCase()
  const text = `${product.name} ${product.description} ${product.category}`.toLowerCase()
  return matchesCategory && text.includes(search.value.toLowerCase()) && product.active !== false
}))

function updateCategory() {
  router.replace({ query: selectedCategory.value ? { categoria: selectedCategory.value } : {} })
}

watch(() => route.query.categoria, (category) => { selectedCategory.value = category || '' })
</script>

<template>
  <main class="bg-pink-50/40 py-12 sm:py-18"><section class="mx-auto max-w-7xl px-5 sm:px-8 lg:px-10"><p class="text-center text-sm font-bold tracking-[0.2em] text-[var(--primary)]">STRAWBERRY MAKEUP</p><h1 class="mt-3 text-center text-4xl font-bold text-black sm:text-5xl">Nuestros productos</h1><p class="mx-auto mt-4 max-w-2xl text-center leading-7 text-neutral-600">Encuentra tus favoritos y crea looks que se sienten como tú.</p><div class="mt-10 grid gap-3 rounded-2xl bg-white p-4 shadow-sm md:grid-cols-[1fr_250px]"><input v-model="search" class="rounded-xl border border-pink-100 px-4 py-3 outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100" type="search" placeholder="Buscar productos" /><select v-model="selectedCategory" class="rounded-xl border border-pink-100 bg-white px-4 py-3 outline-none focus:border-[var(--primary)]" @change="updateCategory"><option value="">Todas las categorías</option><option v-for="category in categories" :key="category.id" :value="category.name">{{ category.name }}</option></select></div><div v-if="selectedCategory" class="mt-6 flex items-center justify-between"><p class="text-sm text-neutral-600">Categoría: <strong>{{ selectedCategory }}</strong></p><button class="text-sm font-bold text-[var(--primary)] hover:underline" @click="selectedCategory = ''; updateCategory()">Ver todo</button></div><p class="mt-8 text-sm text-neutral-500">{{ visibleProducts.length }} producto(s) encontrado(s)</p><div v-if="visibleProducts.length" class="mt-5 grid gap-5 sm:grid-cols-2 lg:grid-cols-4"><ProductCard v-for="product in visibleProducts" :key="product.id" :product="product" /></div><div v-else class="mt-5 rounded-2xl bg-white p-10 text-center shadow-sm"><h2 class="text-2xl font-bold">No encontramos productos</h2><p class="mt-2 text-neutral-600">Prueba con otra categoría o término de búsqueda.</p></div></section></main>
</template>
