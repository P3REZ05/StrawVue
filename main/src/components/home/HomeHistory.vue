<script setup>
import bannerHistoria from '../../assets/images/bannerhistoria.webp'
</script>

<template>
  <section id="nosotros" class="relative overflow-hidden bg-white py-16 sm:py-24">
    <div class="absolute inset-y-0 right-0 hidden w-[32%] bg-[var(--success)] md:block"></div>
    <div class="relative mx-auto grid max-w-7xl items-center gap-12 px-5 sm:px-8 md:grid-cols-2 lg:px-10">
      <div class="max-w-xl"><p class="mb-3 text-sm font-bold tracking-[0.2em] text-[var(--primary)]">SOBRE NOSOTROS</p><h2 class="text-4xl font-bold leading-tight text-[var(--success)] drop-shadow-[0_3px_2px_rgba(255,105,180,0.4)] sm:text-5xl">STRAWBERRY MAKEUP</h2><p class="mt-6 leading-8 text-neutral-600">En nuestra tienda de productos de maquillaje encontrarás una amplia variedad para que puedas descubrir lo que necesitas. ¡Disfruta de la experiencia de comprar con nosotros!</p><button class="mt-7 rounded-full bg-[var(--primary)] px-6 py-3 text-sm font-bold text-white shadow-lg shadow-pink-300/50 transition hover:-translate-y-0.5 hover:bg-[var(--info)]">¡Visita nuestros productos!</button></div>
      <div class="relative justify-self-center md:justify-self-end"><div class="absolute -inset-4 rounded-[2rem] bg-[var(--success)] md:hidden"></div><img :src="bannerHistoria" alt="Productos de Strawberry Makeup" class="relative w-full max-w-md rounded-[1.4rem] object-cover shadow-xl" /></div>
    </div>
  </section>
</template>
