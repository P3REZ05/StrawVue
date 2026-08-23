<script setup>
import { computed, onMounted, onBeforeUnmount, ref } from 'vue'
import bannerPrincipal from '../../assets/images/bannerprincipal.webp'
import { defaultPromotions } from '../../data/mockData'

const STORAGE_KEY = 'strawberry-home-promotions'
const slides = ref([])
const currentSlide = ref(0)
let autoRotate = null

function loadPromotions() {
  const stored = localStorage.getItem(STORAGE_KEY)
  if (stored) {
    try {
      const parsed = JSON.parse(stored)
      if (Array.isArray(parsed) && parsed.length) {
        slides.value = parsed.filter((slide) => slide.active !== false)
        return
      }
    } catch (error) {
      console.warn('No se pudo cargar las promociones guardadas.', error)
    }
  }

  slides.value = defaultPromotions.map((slide) => ({
    ...slide,
    image: slide.image || bannerPrincipal
  }))
}

function nextSlide() {
  if (!slides.value.length) return
  currentSlide.value = (currentSlide.value + 1) % slides.value.length
}

function prevSlide() {
  if (!slides.value.length) return
  currentSlide.value = (currentSlide.value - 1 + slides.value.length) % slides.value.length
}

onMounted(() => {
  loadPromotions()
  autoRotate = setInterval(() => {
    if (slides.value.length > 1) nextSlide()
  }, 5000)
})

onBeforeUnmount(() => {
  if (autoRotate) clearInterval(autoRotate)
})

const activeSlide = computed(() => slides.value[currentSlide.value] || slides.value[0])
</script>

<template>
  <section aria-label="Promociones de Strawberry Makeup" class="relative mx-auto max-w-7xl px-3 py-3 sm:px-5 lg:px-8">
    <div v-if="slides.length" class="relative overflow-hidden rounded-[28px] bg-neutral-100 shadow-[0_18px_40px_rgba(228,107,160,0.15)]">
      <img
        :src="activeSlide.image || bannerPrincipal"
        :alt="activeSlide.title || 'Banner principal de Strawberry Makeup'"
        class="h-[34vh] min-h-[220px] w-full object-cover object-center sm:h-[42vh] lg:h-[50vh]"
      />

      <div class="absolute inset-0 bg-gradient-to-r from-black/60 via-black/25 to-black/10" />

      <div class="absolute inset-x-0 top-1/2 max-w-xl -translate-y-1/2 px-5 text-white sm:px-8 lg:left-10 lg:px-0">
        <p v-if="activeSlide.accent" class="mb-2 text-[10px] font-bold tracking-[0.25em] text-pink-200 uppercase sm:text-[11px]">{{ activeSlide.accent }}</p>
        <h1 class="text-2xl font-black leading-tight sm:text-3xl lg:text-5xl">{{ activeSlide.title || 'Strawberry Makeup' }}</h1>
        <p v-if="activeSlide.subtitle" class="mt-2 max-w-md text-xs text-white/85 sm:text-sm">{{ activeSlide.subtitle }}</p>
        <a v-if="activeSlide.link" :href="activeSlide.link" class="mt-4 inline-flex rounded-full bg-[var(--primary)] px-4 py-2 text-xs font-bold text-white shadow-lg shadow-pink-300/40 transition hover:bg-[var(--info)] sm:px-5 sm:py-2.5 sm:text-sm">Ver colección</a>
      </div>

      <button type="button" class="absolute left-3 top-1/2 z-10 hidden h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full bg-white/85 text-lg font-bold text-neutral-700 shadow-md transition hover:bg-white sm:flex" aria-label="Anterior promocion" @click="prevSlide">‹</button>
      <button type="button" class="absolute right-3 top-1/2 z-10 hidden h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full bg-white/85 text-lg font-bold text-neutral-700 shadow-md transition hover:bg-white sm:flex" aria-label="Siguiente promocion" @click="nextSlide">›</button>

      <div class="absolute bottom-3 left-1/2 z-10 flex -translate-x-1/2 items-center gap-2">
        <button
          v-for="(slide, index) in slides"
          :key="slide.id || index"
          type="button"
          :aria-label="`Ir a la promoción ${index + 1}`"
          class="h-2 w-2 rounded-full transition"
          :class="index === currentSlide ? 'bg-white shadow-sm' : 'bg-white/50'"
          @click="currentSlide = index"
        />
      </div>
    </div>
  </section>
</template>
