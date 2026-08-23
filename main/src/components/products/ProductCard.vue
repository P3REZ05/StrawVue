<script setup>
import { RouterLink } from 'vue-router'
import { useCartStore } from '../../stores/cart'
import { formatCurrency } from '../../utils/formatCurrency'

defineProps({ product: { type: Object, required: true } })
const cart = useCartStore()

function addToCart(product) {
  cart.add(product)
  cart.openDrawer()
}
</script>

<template>
  <article class="group flex h-full flex-col overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-pink-100 transition hover:-translate-y-1 hover:shadow-lg">
    <RouterLink :to="`/producto/${product.id}`" class="relative block h-64 overflow-hidden bg-pink-50"><img :src="product.image" :alt="product.name" class="h-full w-full object-contain p-3 transition duration-500 group-hover:scale-105" /><span v-if="(product.saleStock ?? product.stock ?? 0) === 0" class="absolute left-3 top-3 rounded-full bg-black px-3 py-1 text-xs font-bold text-white">Agotado</span></RouterLink>
    <div class="flex flex-1 flex-col p-5"><p class="text-xs font-bold tracking-wider text-[var(--primary)]">{{ product.category }}</p><RouterLink :to="`/producto/${product.id}`" class="mt-2 font-bold text-black hover:text-[var(--primary)]">{{ product.name }}</RouterLink><p class="mt-2 line-clamp-2 text-sm leading-6 text-neutral-500">{{ product.description }}</p><div class="mt-auto pt-5"><p class="text-lg font-bold text-[var(--primary)]">{{ formatCurrency(product.price) }}</p><button :disabled="(product.saleStock ?? product.stock ?? 0) === 0" class="mt-4 w-full rounded-full bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:cursor-not-allowed disabled:bg-neutral-300" @click="addToCart(product)">{{ (product.saleStock ?? product.stock ?? 0) === 0 ? 'Agotado' : 'Agregar al carrito' }}</button></div></div>
  </article>
</template>
