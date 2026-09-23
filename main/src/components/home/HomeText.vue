<script setup>
import camion from '../../assets/icons/camion-envio.svg?raw'
import estrella from '../../assets/icons/estrella-premium.svg?raw'
import capas from '../../assets/icons/capas-mayoreo.svg?raw'

/**
 * La tira de garantías de la portada.
 *
 * Antes eran tres bloques con un emoji gigante, un titular en mayúsculas y un
 * párrafo de cuatro líneas cada uno. Nadie lee doce líneas entre el banner y
 * las ofertas: esto no es contenido, es una promesa que se lee de un vistazo
 * —envío, calidad, mayoreo— y se entiende antes por el icono que por el texto.
 * Dos palabras por pieza bastan.
 *
 * LOS ICONOS VAN EN LÍNEA (`?raw` + `v-html`), no como `<img>`. Un `<img>` no
 * se puede recolorear desde CSS, y estos tienen que tomar el rosa de la marca
 * del contenedor; en línea, su `stroke="currentColor"` lo hereda. Vienen de
 * `assets/icons`, limpiados de los 8 KB de metadatos C2PA que traía cada uno
 * —el dibujo ocupa 300 bytes—.
 */
const garantias = [
  { icono: camion, texto: 'Envío a\ntodo el país' },
  { icono: estrella, texto: 'Marcas\npremium' },
  { icono: capas, texto: 'Mayoreo y\nmenudeo' }
]
</script>

<template>
  <section class="mx-auto max-w-4xl px-5 py-10 sm:px-8 sm:py-14">
    <ul class="grid grid-cols-3 gap-2 sm:gap-6">
      <li v-for="g in garantias" :key="g.texto" class="flex flex-col items-center text-center">
        <!-- El círculo rosa es lo que hace legible un icono de trazo fino a
             tamaño pequeño: sin fondo se pierde contra el blanco. -->
        <!-- Aquí no hay riesgo de XSS: lo que se inyecta son tres archivos de
             este mismo repositorio, resueltos por Vite al compilar. Nunca entra
             nada que venga de la base ni de la clienta. -->
        <!-- eslint-disable vue/no-v-html -->
        <span
          class="grid size-14 place-items-center rounded-full bg-pink-100/70 text-[var(--primary)] sm:size-16"
          aria-hidden="true"
          v-html="g.icono"
        />
        <!-- eslint-enable vue/no-v-html -->
        <!-- `whitespace-pre-line` respeta el salto del texto: las tres
             etiquetas parten donde toca y quedan a la misma altura. -->
        <p class="mt-3 whitespace-pre-line text-xs font-semibold leading-5 text-neutral-600 sm:text-sm">
          {{ g.texto }}
        </p>
      </li>
    </ul>
  </section>
</template>

<style scoped>
/* El SVG llega con `width="24" height="24"` escritos dentro; se anulan para
   poder fijar el tamaño desde aquí y que acompañe al del círculo. */
span :deep(svg) {
  width: 1.75rem;
  height: 1.75rem;
}

@media (min-width: 640px) {
  span :deep(svg) {
    width: 2rem;
    height: 2rem;
  }
}
</style>
