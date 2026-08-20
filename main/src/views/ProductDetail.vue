<script setup>
import { computed, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { products } from '../data/mockData'
import { useCartStore } from '../stores/cart'
import { formatCurrency } from '../utils/formatCurrency'

const route = useRoute()
const cart = useCartStore()
const quantity = ref(1)
const added = ref(false)
const product = computed(() => products.find((item) => item.id === Number(route.params.id)))

function addToCart() {
  cart.add(product.value, quantity.value)
  cart.openDrawer()
  added.value = true
  window.setTimeout(() => { added.value = false }, 2200)
}
</script>

<template>
  <main class="bg-pink-50/40 py-12 sm:py-18"><section v-if="product" class="mx-auto max-w-6xl px-5 sm:px-8 lg:px-10"><nav class="mb-8 flex flex-wrap gap-2 text-sm text-neutral-500"><RouterLink class="hover:text-[var(--primary)]" to="/tienda">Tienda</RouterLink><span>/</span><RouterLink class="hover:text-[var(--primary)]" :to="{ path: '/tienda', query: { categoria: product.category } }">{{ product.category }}</RouterLink><span>/</span><span class="text-black">{{ product.name }}</span></nav><div class="grid gap-10 rounded-3xl bg-white p-5 shadow-sm sm:p-8 md:grid-cols-2"><div class="flex min-h-96 items-center justify-center rounded-2xl bg-pink-50"><img :src="product.image" :alt="product.name" class="max-h-125 w-full object-contain p-5" /></div><div class="py-2"><p class="text-sm font-bold tracking-wider text-[var(--primary)]">{{ product.category }}</p><h1 class="mt-3 text-4xl font-bold leading-tight text-black">{{ product.name }}</h1><p class="mt-5 text-3xl font-bold text-[var(--primary)]">{{ formatCurrency(product.price) }}</p><p class="mt-6 leading-8 text-neutral-600">{{ product.description }}</p><p class="mt-6 text-sm font-semibold" :class="product.stock ? 'text-emerald-600' : 'text-red-600'">{{ product.stock ? `${product.stock} unidades disponibles` : 'Producto agotado' }}</p><div v-if="product.stock" class="mt-7 flex gap-3"><div class="flex items-center rounded-full border border-pink-200"><button class="size-11 text-xl text-[var(--primary)] disabled:text-neutral-300" :disabled="quantity === 1" aria-label="Reducir cantidad" @click="quantity--">−</button><span class="w-8 text-center font-bold">{{ quantity }}</span><button class="size-11 text-xl text-[var(--primary)] disabled:text-neutral-300" :disabled="quantity === product.stock" aria-label="Aumentar cantidad" @click="quantity++">+</button></div><button class="flex-1 rounded-full bg-[var(--primary)] px-5 py-3 text-sm font-bold text-white transition hover:bg-[var(--info)]" @click="addToCart">Agregar al carrito</button></div><p v-if="added" class="mt-3 text-sm font-semibold text-emerald-600">Producto agregado al carrito.</p><RouterLink class="mt-6 inline-block text-sm font-bold text-[var(--primary)] hover:underline" to="/tienda">← Seguir comprando</RouterLink><div class="mt-8 border-t border-pink-100 pt-6 text-sm leading-7 text-neutral-600"><p><strong>Entrega estimada:</strong> 1 a 4 días hábiles máximo.</p><p class="mt-2">Envío gratis a Colombia por compras desde $200.000. Aplican términos y condiciones.</p></div></div></div></section><section v-else class="mx-auto max-w-xl px-5 py-20 text-center"><h1 class="text-3xl font-bold">Producto no encontrado</h1><p class="mt-3 text-neutral-600">El producto que buscas no existe o ya no está disponible.</p><RouterLink class="mt-7 inline-block rounded-full bg-[var(--primary)] px-6 py-3 text-sm font-bold text-white" to="/tienda">Volver a la tienda</RouterLink></section></main>
</template>
