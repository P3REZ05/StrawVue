<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useCartStore } from '../../stores/cart'
import logo from '../../assets/images/strawberrymakeup.png'

const cart = useCartStore()
const menuOpen = ref(false)

function closeMenu() {
  menuOpen.value = false
}
</script>

<template>
  <header class="sticky top-0 z-50 border-b border-pink-200 bg-[var(--success)]/95 backdrop-blur">
    <nav class="mx-auto flex min-h-20 max-w-7xl items-center justify-between px-5 sm:px-8 lg:px-10" aria-label="Navegación principal">
      <button class="rounded-lg p-2 text-black lg:hidden" type="button" aria-label="Abrir menú" :aria-expanded="menuOpen" @click="menuOpen = !menuOpen">
        <svg v-if="!menuOpen" class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6h16M4 12h16M4 18h16" /></svg>
        <svg v-else class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 6 12 12M18 6 6 18" /></svg>
      </button>

      <RouterLink class="absolute left-1/2 -translate-x-1/2 lg:static lg:translate-x-0" to="/" aria-label="Ir al inicio"><img :src="logo" alt="Strawberry Makeup" class="h-13 w-auto object-contain sm:h-16" /></RouterLink>

      <div class="hidden items-center gap-7 lg:ml-12 lg:flex">
        <RouterLink class="text-sm font-bold transition hover:text-[var(--primary)]" to="/">Home</RouterLink>
        <RouterLink class="text-sm font-bold transition hover:text-[var(--primary)]" to="/tienda">Shop</RouterLink>
        <RouterLink class="text-sm font-bold transition hover:text-[var(--primary)]" :to="{ path: '/tienda', query: { ofertas: 'true' } }">Ofertas</RouterLink>
        <RouterLink class="text-sm font-bold transition hover:text-[var(--primary)]" to="/nosotros">Nosotros</RouterLink>
        <RouterLink class="text-sm font-bold transition hover:text-[var(--primary)]" to="/contacto">Contacto</RouterLink>
      </div>

      <div class="flex items-center gap-1 sm:gap-3"><RouterLink class="hidden rounded-full p-2 transition hover:bg-white/60 sm:block" to="/admin" aria-label="Mi cuenta"><svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="3"/><path d="M5 21a7 7 0 0 1 14 0"/></svg></RouterLink><button class="relative rounded-full p-2 transition hover:bg-white/60" aria-label="Carrito" @click="cart.openDrawer"><svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 4h2l2.2 11.1a2 2 0 0 0 2 1.6h7.6a2 2 0 0 0 2-1.6L20 8H7"/><circle cx="10" cy="20" r="1"/><circle cx="17" cy="20" r="1"/></svg><span v-if="cart.count" class="absolute -right-1 -top-1 grid size-4 place-items-center rounded-full bg-[var(--primary)] text-[10px] font-bold text-white">{{ cart.count }}</span></button></div>
    </nav>

    <div v-if="menuOpen" class="border-t border-pink-200 bg-white px-5 py-4 shadow-lg lg:hidden"><div class="flex flex-col"><RouterLink class="border-b border-pink-100 py-3 font-bold" to="/" @click="closeMenu">Home</RouterLink><RouterLink class="border-b border-pink-100 py-3 font-bold" to="/tienda" @click="closeMenu">Shop</RouterLink><RouterLink class="border-b border-pink-100 py-3 font-bold" :to="{ path: '/tienda', query: { ofertas: 'true' } }" @click="closeMenu">Ofertas</RouterLink><RouterLink class="border-b border-pink-100 py-3 font-bold" to="/nosotros" @click="closeMenu">Nosotros</RouterLink><RouterLink class="border-b border-pink-100 py-3 font-bold" to="/contacto" @click="closeMenu">Contacto</RouterLink></div></div>
  </header>
</template>