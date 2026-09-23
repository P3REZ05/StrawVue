<script setup>
import { ref, onBeforeUnmount } from 'vue'
import { Info } from 'lucide-vue-next'

/**
 * El botoncito de «?» que explica para qué sirve un campo y dónde se ve.
 *
 * Por qué existe: el editor de producto tiene seis secciones y unos veinte
 * campos, y varios solo tienen sentido si ya sabes cómo funciona la tienda.
 * «Precio promocional», por ejemplo, no es lo mismo que una promoción del
 * motor de promociones, y nada lo decía. La alternativa —un párrafo de ayuda
 * debajo de cada campo— convierte el formulario en un muro de texto gris que
 * nadie lee justamente porque siempre está ahí.
 *
 * Se abre al pulsar, NO al pasar el ratón: en el celular no hay ratón, y un
 * `title` nativo tampoco se ve ahí. Se cierra con Escape, pulsando fuera o
 * volviendo a pulsar el botón.
 *
 * `donde` es el dato que más se echaba en falta: no qué es el campo, sino en
 * qué parte de la tienda acaba viéndose.
 */
defineProps({
  titulo: { type: String, default: '' },
  texto: { type: String, required: true },
  donde: { type: String, default: '' }
})

const abierto = ref(false)

function alternar() {
  abierto.value = !abierto.value
  if (abierto.value) document.addEventListener('keydown', alEscape)
  else document.removeEventListener('keydown', alEscape)
}

function cerrar() {
  abierto.value = false
  document.removeEventListener('keydown', alEscape)
}

function alEscape(evento) {
  if (evento.key === 'Escape') cerrar()
}

onBeforeUnmount(() => document.removeEventListener('keydown', alEscape))
</script>

<template>
  <span class="relative inline-flex">
    <button
      type="button"
      class="grid size-8 place-items-center rounded-full text-neutral-400 transition hover:bg-pink-50 hover:text-[var(--primary)]"
      :class="abierto ? 'bg-pink-50 text-[var(--primary)]' : ''"
      :aria-expanded="abierto"
      :aria-label="titulo ? `Qué es «${titulo}»` : 'Más información'"
      @click.stop="alternar"
    >
      <Info class="size-4" />
    </button>

    <!-- El velo transparente captura el clic de fuera sin oscurecer la
         pantalla: esto es una ayuda, no un diálogo que interrumpa. -->
    <span v-if="abierto" class="fixed inset-0 z-40" @click="cerrar" />

    <span
      v-if="abierto"
      class="absolute right-0 top-9 z-50 w-72 rounded-xl bg-white p-4 text-left shadow-xl ring-1 ring-pink-100"
      role="note"
    >
      <span v-if="titulo" class="block text-sm font-bold text-black">{{ titulo }}</span>
      <span class="mt-1 block text-xs font-normal leading-5 text-neutral-600">{{ texto }}</span>
      <span v-if="donde" class="mt-3 block rounded-lg bg-pink-50 px-3 py-2 text-xs font-normal leading-5 text-[var(--primary)]">
        <strong class="font-bold">Dónde se ve:</strong> {{ donde }}
      </span>
    </span>
  </span>
</template>
