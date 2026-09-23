<script setup>
import { computed, onMounted } from 'vue'
import OffersGrid from './OffersGrid.vue'
import { useOffersStore } from '../../stores/offers'

// Esta sección tenía las cuatro tarjetas escritas dentro del archivo: tres
// degradados y una imagen importada, con "Skincare" y "Bases mate" en el
// HTML. Cambiar una oferta era editar código y volver a desplegar, así que
// en la práctica no se cambiaba nunca. Ahora vienen de `home_offers` y se
// editan desde el panel, con vista previa antes de publicar.
const ofertas = useOffersStore()

const visibles = computed(() => ofertas.publicadas)

onMounted(() => {
  // Si falla, la sección simplemente no aparece: una portada a la que le
  // falta el escaparate sigue vendiendo, una que revienta no.
  ofertas.init().catch(() => {})
})
</script>

<template>
  <section v-if="visibles.length" class="mx-auto max-w-7xl px-4 py-12 sm:px-8 sm:py-14 lg:px-10">
    <div class="mb-6 text-center sm:mb-8">
      <p class="text-xs font-bold uppercase tracking-[0.22em] text-[#c2185b]">Esta semana</p>
      <h2 class="mt-2 text-2xl font-black tracking-tight text-black sm:text-3xl lg:text-4xl">
        Ofertas especiales
      </h2>
    </div>

    <OffersGrid :ofertas="visibles" />
  </section>
</template>
