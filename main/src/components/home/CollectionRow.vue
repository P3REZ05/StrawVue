<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { ChevronLeft, ChevronRight, ArrowRight } from 'lucide-vue-next'
import ProductCard from '../products/ProductCard.vue'

/**
 * Una colección en la portada: título, subtítulo y un carrusel con SUS
 * productos, las mismas tarjetas de la tienda.
 *
 * Es un componente por fila y no un `v-for` dentro de `HomeCollections`
 * porque cada carrusel necesita su propio `scrollLeft`, su propio ancho y sus
 * propias flechas. Con un solo componente eso serían tres arrays indexados por
 * posición — el patrón que se rompe en cuanto una colección se despublica.
 *
 * El carrusel es scroll nativo con `scroll-snap`, no una librería ni un
 * `transform` calculado a mano: el dedo ya sabe arrastrar, el trackpad ya sabe
 * desplazar, el teclado ya tabula tarjeta a tarjeta y el lector de pantalla ya
 * lee una lista. Las flechas solo llaman a `scrollBy`, que es lo único que
 * faltaba para el ratón.
 */
const props = defineProps({
  coleccion: { type: Object, required: true },
  productos: { type: Array, required: true }
})

const pista = ref(null)
const alPrincipio = ref(true)
const alFinal = ref(false)

// Si todo cabe en pantalla no hay nada que recorrer y las flechas sobran:
// dos botones muertos al lado de un título es peor que ningún botón.
const desborda = ref(false)

function medir() {
  const el = pista.value
  if (!el) return
  const margen = 8 // el scroll nativo no siempre llega al píxel exacto
  desborda.value = el.scrollWidth > el.clientWidth + margen
  alPrincipio.value = el.scrollLeft <= margen
  alFinal.value = el.scrollLeft + el.clientWidth >= el.scrollWidth - margen
}

onMounted(medir)

function desplazar(direccion) {
  const el = pista.value
  if (!el) return
  // Un poco menos de una pantalla: deja una tarjeta a la vista como ancla, que
  // es lo que evita la sensación de haberse saltado algo.
  el.scrollBy({ left: direccion * el.clientWidth * 0.8, behavior: 'smooth' })
}

const enlace = computed(() => ({ path: '/tienda', query: { coleccion: props.coleccion.slug } }))
</script>

<template>
  <section class="mt-14 first:mt-0 sm:mt-20">
    <!-- Cabecera opcional. Sin foto, la fila empieza directamente por el
         título: una colección se explica con sus productos. -->
    <RouterLink
      v-if="coleccion.imageUrl"
      :to="enlace"
      class="group mb-6 block overflow-hidden rounded-3xl bg-pink-50"
    >
      <img
        :src="coleccion.imageUrl" :alt="`Colección ${coleccion.name}`"
        class="h-36 w-full object-cover transition duration-500 group-hover:scale-105 sm:h-48 lg:h-56"
        loading="lazy"
      />
    </RouterLink>

    <div class="flex flex-wrap items-end justify-between gap-4">
      <div class="min-w-0">
        <!-- Peso 300 y no el 900 de antes. En un titular grande el trazo fino
             se lee como boutique; el peso máximo, como cartel de rebajas. El
             espaciado vuelve a neutro: `tracking-tight` aprieta unas letras que
             ya de por sí son delgadas y las emborrona. -->
        <h3 class="text-2xl font-light text-black sm:text-3xl">
          {{ coleccion.name }}
        </h3>
        <p v-if="coleccion.description" class="mt-2 max-w-xl text-sm font-semibold leading-6 text-[var(--primary)]">
          {{ coleccion.description }}
        </p>
      </div>

      <div class="flex items-center gap-2">
        <RouterLink
          :to="enlace"
          class="inline-flex min-h-11 items-center gap-1.5 rounded-full px-4 text-sm font-bold text-[var(--primary)] transition hover:bg-pink-50"
        >
          Ver todo <ArrowRight class="size-4" />
        </RouterLink>

        <!-- Las flechas son una comodidad de ratón: en el móvil se arrastra,
             y el enlace «Ver todo» lleva a la misma lista completa. Por eso
             van ocultas al lector de pantalla en vez de duplicar la lista. -->
        <div v-if="desborda" data-flechas class="hidden items-center gap-1.5 sm:flex" aria-hidden="true">
          <button
            :disabled="alPrincipio"
            class="grid size-11 place-items-center rounded-full bg-white text-neutral-600 shadow-sm ring-1 ring-pink-100 transition hover:text-[var(--primary)] disabled:opacity-30"
            tabindex="-1"
            @click="desplazar(-1)"
          ><ChevronLeft class="size-5" /></button>
          <button
            :disabled="alFinal"
            class="grid size-11 place-items-center rounded-full bg-white text-neutral-600 shadow-sm ring-1 ring-pink-100 transition hover:text-[var(--primary)] disabled:opacity-30"
            tabindex="-1"
            @click="desplazar(1)"
          ><ChevronRight class="size-5" /></button>
        </div>
      </div>
    </div>

    <!--
      `snap-x` para que ninguna tarjeta quede cortada al soltar el dedo, y
      `pb-2` para que la sombra de la tarjeta no se recorte contra el borde del
      scroll. Los anchos fijos son a propósito: en una fila que se desplaza, la
      siguiente tarjeta tiene que asomar, y eso solo pasa si su ancho no depende
      de cuántas haya.
    -->
    <ul
      ref="pista"
      class="pista mt-6 flex snap-x snap-mandatory gap-3 overflow-x-auto pb-2 sm:gap-5"
      @scroll.passive="medir"
    >
      <li
        v-for="producto in productos" :key="producto.id"
        class="w-[62vw] max-w-[280px] shrink-0 snap-start min-[480px]:w-[45vw] sm:w-[280px]"
      >
        <ProductCard :product="producto" />
      </li>
    </ul>
  </section>
</template>

<style scoped>
/* Sin barra de scroll: las flechas y el propio desplazamiento ya dicen que
   hay más. Una barra bajo cada fila llena la portada de rayas grises. */
.pista {
  scrollbar-width: none;
}

.pista::-webkit-scrollbar {
  display: none;
}
</style>
