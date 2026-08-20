<script setup>
import bannerHistoria from '../assets/images/bannerhistoria.webp'

const values = [
  { title: 'Belleza para expresarte', text: 'Creemos que el maquillaje es una forma de jugar, crear y mostrar tu estilo personal.' },
  { title: 'Productos seleccionados', text: 'Elegimos opciones pensadas para acompañarte en tu rutina y en cada ocasión especial.' },
  { title: 'Atención cercana', text: 'Estamos para resolver tus dudas y ayudarte a encontrar productos que disfrutes usar.' }
]
</script>

<template>
  <main>
    <section class="overflow-hidden bg-pink-50"><div class="mx-auto grid max-w-7xl items-center gap-10 px-5 py-16 sm:px-8 md:grid-cols-2 md:py-24 lg:px-10"><div><p class="text-sm font-bold tracking-[0.2em] text-[var(--primary)]">SOBRE STRAWBERRY</p><h1 class="mt-3 text-5xl font-bold leading-tight text-black sm:text-6xl">Belleza que se siente <span class="text-[var(--primary)]">como tú.</span></h1><p class="mt-6 max-w-xl leading-8 text-neutral-600">Strawberry Makeup nació para compartir productos de belleza, tendencias y una experiencia de compra cercana. Queremos que cada producto sume color, confianza y diversión a tu día.</p><a class="mt-8 inline-flex rounded-full bg-[var(--primary)] px-6 py-3 text-sm font-bold text-white shadow-lg shadow-pink-300/50 transition hover:-translate-y-0.5 hover:bg-[var(--info)]" href="mailto:strawberrymakeupstore@gmail.com">Habla con nosotros</a></div><div class="relative mx-auto w-full max-w-md"><div class="absolute -inset-4 rounded-[2rem] bg-[var(--success)]"></div><img :src="bannerHistoria" alt="Productos de Strawberry Makeup" class="relative aspect-square w-full rounded-[1.5rem] object-cover shadow-xl" /></div></div></section>
    <section class="mx-auto max-w-7xl px-5 py-16 sm:px-8 lg:px-10"><div class="max-w-2xl"><p class="text-sm font-bold tracking-[0.2em] text-[var(--primary)]">NUESTRA ESENCIA</p><h2 class="mt-3 text-4xl font-bold text-black">Más que maquillaje, una manera de sentirte bien.</h2></div><div class="mt-10 grid gap-5 md:grid-cols-3"><article v-for="value in values" :key="value.title" class="rounded-2xl border border-pink-100 bg-white p-7 shadow-sm"><div class="mb-5 size-11 rounded-full bg-[var(--success)]"></div><h3 class="text-xl font-bold text-[var(--primary)]">{{ value.title }}</h3><p class="mt-3 leading-7 text-neutral-600">{{ value.text }}</p></article></div></section>
    <section class="bg-black px-5 py-16 text-center text-white sm:px-8"><p class="mx-auto max-w-2xl text-lg leading-8 text-white/80">¿Tienes una pregunta, necesitas una recomendación o quieres conocer nuestras promociones?</p><a class="mt-6 inline-flex rounded-full bg-[var(--primary)] px-6 py-3 text-sm font-bold transition hover:bg-[var(--info)]" href="mailto:strawberrymakeupstore@gmail.com">Contáctanos</a></section>
  </main>
</template>
