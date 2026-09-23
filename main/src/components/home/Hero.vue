<script setup>
import { onMounted, onBeforeUnmount, ref } from 'vue'
import bannerPrincipal from '../../assets/images/bannerprincipal.webp'
import { useSettingsStore } from '../../stores/settings'

// Los banners salían de `localStorage`, con las imágenes en base64 dentro.
// Eso significaba que la administradora configuraba la portada, la veía en
// su propio navegador, y ningún cliente la veía jamás. Ahora vienen de
// `home_banners` y sus imágenes de Storage, como el resto del catálogo.
//
// EL BANNER ES SOLO LA IMAGEN. Nada de título, texto destacado ni «Ver
// colección» escritos encima: eso va dentro del volante que se diseña aparte,
// con su tipografía y su color. Superponer texto web a una imagen que ya lleva
// el suyo tapaba justo la parte que importaba de la foto. El banner entero es
// el enlace; el título se conserva como nombre interno y como texto
// alternativo para el lector de pantalla.
const settings = useSettingsStore()
const slides = ref([])
const currentSlide = ref(0)
let autoRotate = null

// Si no hay banners configurados, el carrusel muestra el banner de la marca
// en vez de quedarse en blanco.
const SLIDE_POR_DEFECTO = {
  id: 'default',
  title: 'Strawberry Makeup',
  subtitle: 'Belleza que se siente como tú',
  accent: '',
  link: '/tienda',
  image: bannerPrincipal
}

async function loadPromotions() {
  try {
    await settings.init()
  } catch {
    // La portada no puede quedarse en blanco porque falle la red.
  }

  const activos = settings.bannersActivos
  slides.value = activos.length
    ? activos.map((b) => ({
        id: b.id,
        title: b.title,
        subtitle: b.subtitle || '',
        accent: b.accent || '',
        link: b.link || '/tienda',
        image: b.image_url || bannerPrincipal
      }))
    : [SLIDE_POR_DEFECTO]

  // Si se borró un banner mientras rotaba, el índice puede quedar fuera.
  if (currentSlide.value >= slides.value.length) currentSlide.value = 0
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
</script>

<template>
  <section aria-label="Promociones de Strawberry Makeup" class="relative mx-auto max-w-7xl px-3 py-3 sm:px-5 lg:px-8">
    <div v-if="slides.length" class="relative overflow-hidden rounded-[28px] bg-neutral-100 shadow-[0_18px_40px_rgba(228,107,160,0.15)]">
      <!--
        La tira. Están TODOS los banners uno al lado del otro y lo que se mueve
        es la tira entera con `translateX`: así el cambio se ve como un
        desplazamiento y no como un parpadeo. Antes se cambiaba el `src` de una
        sola imagen, y en una foto grande eso es un fogonazo blanco mientras
        carga la siguiente.

        `transform` es además lo único que el navegador puede animar sin
        recalcular el diseño de la página, así que va suave también en un
        celular de gama baja.
      -->
      <div
        class="tira flex"
        :style="{ transform: `translateX(-${currentSlide * 100}%)` }"
      >
        <a
          v-for="(slide, index) in slides"
          :key="slide.id || index"
          :href="slide.link || '/tienda'"
          class="w-full shrink-0"
          :aria-label="slide.title || 'Ver la promoción'"
          :aria-hidden="index !== currentSlide"
          :tabindex="index === currentSlide ? 0 : -1"
        >
          <img
            :src="slide.image || bannerPrincipal"
            :alt="slide.title || 'Banner principal de Strawberry Makeup'"
            class="h-[34vh] min-h-[220px] w-full object-cover object-center sm:h-[42vh] lg:h-[50vh]"
            :loading="index === 0 ? 'eager' : 'lazy'"
            draggable="false"
          />
        </a>
      </div>

      <template v-if="slides.length > 1">
        <button type="button" class="absolute left-3 top-1/2 z-10 hidden size-10 -translate-y-1/2 items-center justify-center rounded-full bg-white/85 text-lg font-bold text-neutral-700 shadow-md transition hover:bg-white sm:flex" aria-label="Anterior promocion" @click="prevSlide">‹</button>
        <button type="button" class="absolute right-3 top-1/2 z-10 hidden size-10 -translate-y-1/2 items-center justify-center rounded-full bg-white/85 text-lg font-bold text-neutral-700 shadow-md transition hover:bg-white sm:flex" aria-label="Siguiente promocion" @click="nextSlide">›</button>

        <div class="absolute bottom-0 left-1/2 z-10 flex -translate-x-1/2 items-center">
          <button
            v-for="(slide, index) in slides"
            :key="slide.id || index"
            type="button"
            :aria-label="`Ir a la promoción ${index + 1}`"
            :aria-current="index === currentSlide"
            class="grid size-10 place-items-center"
            @click="currentSlide = index"
          >
            <span
              class="block h-2 rounded-full transition-all"
              :class="index === currentSlide ? 'w-6 bg-white shadow-sm' : 'w-2 bg-white/60'"
            />
          </button>
        </div>
      </template>
    </div>
  </section>
</template>

<style scoped>
.tira {
  transition: transform 600ms cubic-bezier(0.4, 0, 0.2, 1);
}

/* Quien tiene desactivado el movimiento en su sistema no quiere que la
   portada se deslice sola cada cinco segundos: el banner cambia, pero de
   golpe, sin recorrido. */
@media (prefers-reduced-motion: reduce) {
  .tira {
    transition: none;
  }
}
</style>
