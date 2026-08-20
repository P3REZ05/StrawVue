<script setup>
import postPublicidadSemana from '../../assets/images/postpublicidadsemana.webp'
</script>

<template>
  <section class="mx-auto max-w-7xl px-5 py-14 sm:px-8 lg:px-10">
    <h2
      class="mb-10 text-center text-3xl font-bold tracking-wide text-[var(--primary)] drop-shadow-[0_3px_2px_rgba(255,105,180,0.4)] sm:text-4xl"
    >
      OFERTAS ESPECIALES
    </h2>

    <div class="grid gap-5 lg:grid-cols-2">
      <article
        class="group relative min-h-90 overflow-hidden rounded-2xl bg-[var(--grey)] shadow-sm sm:min-h-125"
      >
        <img
          :src="postPublicidadSemana"
          alt="Colección semanal de maquillaje"
          class="h-full w-full object-cover transition duration-500 group-hover:scale-105"
        />
        <div
          class="absolute inset-0 bg-linear-to-t from-black/75 via-black/10 to-transparent"
        ></div>
        <div class="absolute inset-x-0 bottom-0 p-7 text-white">
          <span
            class="inline-flex rounded-full bg-[var(--primary)] px-4 py-1.5 text-xs font-bold tracking-wider"
            >NUEVO</span
          >
          <h3 class="mt-3 text-3xl font-bold sm:text-4xl">Colección semanal</h3>
        </div>
      </article>

      <div class="grid gap-5 sm:grid-cols-2 lg:grid-rows-[1fr_1fr]">
        <article
          class="group relative min-h-60 overflow-hidden rounded-2xl bg-[linear-gradient(135deg,#d291bc,#ffc1cc)] p-6 text-white shadow-sm"
        >
          <div
            class="absolute inset-0 bg-black/15 transition group-hover:bg-black/25"
          ></div>
          <div class="relative flex h-full flex-col justify-end">
            <span
              class="mb-3 w-fit rounded-full bg-white/90 px-3 py-1 text-xs font-bold text-[var(--primary)]"
              >OFERTA</span
            >
            <h3 class="text-3xl font-bold">Skincare</h3>
            <p class="mt-1 text-lg">Hasta 30% OFF</p>
          </div>
        </article>
        <article
          class="group relative min-h-60 overflow-hidden rounded-2xl bg-[linear-gradient(135deg,#ff85c1,#d291bc)] p-6 text-white shadow-sm"
        >
          <div
            class="absolute inset-0 bg-black/15 transition group-hover:bg-black/25"
          ></div>
          <div class="relative flex h-full flex-col justify-end">
            <span
              class="mb-3 w-fit rounded-full bg-white/90 px-3 py-1 text-xs font-bold text-[var(--primary)]"
              >TRENDING</span
            >
            <h3 class="text-3xl font-bold">Bases mate</h3>
            <p class="mt-1 text-lg">Nueva colección</p>
          </div>
        </article>
        <article
          class="group relative min-h-60 overflow-hidden rounded-2xl bg-[linear-gradient(115deg,#000,#4a173e)] p-7 text-white shadow-sm sm:col-span-2"
        >
          <div class="flex h-full flex-col justify-end">
            <span
              class="mb-3 w-fit rounded-full bg-[var(--primary)] px-3 py-1 text-xs font-bold"
              >EDICIÓN LIMITADA</span
            >
            <h3 class="text-3xl font-bold">Paleta de sombras</h3>
            <p class="mt-1 text-lg text-white/85">
              Descubre los nuevos tonos metálicos
            </p>
            <button
              class="mt-5 w-fit rounded-full bg-white px-5 py-2.5 text-sm font-bold text-black transition hover:bg-[var(--primary)] hover:text-white"
            >
              Ver más
            </button>
          </div>
        </article>
      </div>
    </div>
  </section>
</template>
