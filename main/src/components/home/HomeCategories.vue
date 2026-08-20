<script setup>
import { computed, ref } from 'vue'
import two from '../../assets/images/two.png'
import three from '../../assets/images/three.png'
import four from '../../assets/images/four.png'
import five from '../../assets/images/five.png'
import six from '../../assets/images/six.png'
import seven from '../../assets/images/seven.png'
import eight from '../../assets/images/eight.png'
import nine from '../../assets/images/nine.png'
import ten from '../../assets/images/ten.png'
import eleven from '../../assets/images/eleven.png'
import twelve from '../../assets/images/twelve.png'
import thirteen from '../../assets/images/thirteen.png'
import fourteen from '../../assets/images/fourteen.png'
import fifteen from '../../assets/images/fifteen.png'
import sixteen from '../../assets/images/sixteen.png'

const categories = [
  { name: 'SKINCARE', image: sixteen }, { name: 'SOMBRAS', image: two }, { name: 'DELINEADORES', image: three },
  { name: 'PESTAÑINAS', image: four }, { name: 'BASES', image: five }, { name: 'POLVOS', image: six },
  { name: 'CORRECTORES', image: seven }, { name: 'RUBORES', image: eight }, { name: 'ILUMINADORES', image: fourteen },
  { name: 'BROCHAS', image: nine }, { name: 'PESTAÑAS', image: ten }, { name: 'CEJAS', image: eleven },
  { name: 'LABIOS', image: twelve }, { name: 'PRIMER Y FIJADOR', image: thirteen }, { name: 'ACCESORIOS', image: fifteen }
]
const page = ref(0)
const pages = computed(() => Array.from({ length: Math.ceil(categories.length / 3) }, (_, index) => categories.slice(index * 3, index * 3 + 3)))
const current = computed(() => pages.value[page.value])
function previous() { page.value = page.value === 0 ? pages.value.length - 1 : page.value - 1 }
function next() { page.value = page.value === pages.value.length - 1 ? 0 : page.value + 1 }
</script>

<template>
  <section id="categorias" class="mx-auto max-w-7xl px-5 py-14 sm:px-8 lg:px-10">
    <h2 class="mb-10 text-center text-3xl font-bold text-[var(--success)] sm:text-4xl">NUESTRAS CATEGORÍAS DE PRODUCTOS</h2>
    <div class="relative px-0 sm:px-12">
      <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <article v-for="category in current" :key="category.name" class="group relative h-80 overflow-hidden rounded-2xl bg-black shadow-md">
          <img :src="category.image" :alt="`Categoría ${category.name}`" class="h-full w-full object-cover transition duration-500 group-hover:scale-110" />
          <div class="absolute inset-0 flex flex-col items-center justify-center bg-black/45 p-5 text-center transition group-hover:bg-black/60"><h3 class="text-2xl font-bold text-white">{{ category.name }}</h3><button class="mt-4 rounded-full border-2 border-white px-5 py-2 text-sm font-bold text-white transition hover:border-[var(--primary)] hover:bg-[var(--primary)]">Comprar ahora</button></div>
        </article>
      </div>
      <button class="absolute -left-3 top-1/2 hidden size-10 -translate-y-1/2 rounded-full bg-white text-xl text-[var(--light)] shadow-md transition hover:bg-[var(--primary)] hover:text-white sm:block" aria-label="Categorías anteriores" @click="previous">‹</button>
      <button class="absolute -right-3 top-1/2 hidden size-10 -translate-y-1/2 rounded-full bg-white text-xl text-[var(--light)] shadow-md transition hover:bg-[var(--primary)] hover:text-white sm:block" aria-label="Siguientes categorías" @click="next">›</button>
    </div>
    <div class="mt-7 flex justify-center gap-2"><button v-for="(_, index) in pages" :key="index" :aria-label="`Ver página ${index + 1}`" class="h-2 rounded-full transition" :class="page === index ? 'w-7 bg-[var(--primary)]' : 'w-2 bg-[var(--grey)]'" @click="page = index"></button></div>
  </section>
</template>
