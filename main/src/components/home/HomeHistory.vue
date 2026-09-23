<script setup>
import { RouterLink } from 'vue-router'
import { ArrowRight } from 'lucide-vue-next'
import bannerHistoria from '../../assets/images/bannerhistoria.webp'

/**
 * «Sobre nosotros».
 *
 * DOS COSAS QUE ESTABAN MAL Y POR QUÉ IMPORTAN
 *
 *  1. El panel rosa era `absolute inset-y-0 right-0 w-[32%]`: se colocaba
 *     contra el borde de la VENTANA, mientras la foto vivía dentro de un
 *     contenedor centrado de 1280 px. En una pantalla ancha los dos dejaban
 *     de tocarse y el bloque rosa quedaba flotando a la derecha, separado de
 *     todo, como si la sección se hubiera descuadrado. Ahora el fondo rosa es
 *     un hermano de la foto dentro de la misma rejilla, así que se mueven
 *     juntos midan lo que midan la pantalla y el contenedor.
 *
 *  2. El botón era un `<button>` sin `@click`. Decía «¡Visita nuestros
 *     productos!» y no llevaba a ninguna parte. Es un `RouterLink` a la
 *     tienda.
 *
 * El titular llevaba además una `drop-shadow` rosa desenfocada que, sobre
 * texto, se lee como un error de impresión. Se retira: la jerarquía la dan el
 * tamaño y el color.
 */
</script>

<template>
  <section id="nosotros" class="overflow-hidden bg-white py-16 sm:py-24">
    <div class="mx-auto grid max-w-7xl items-center gap-10 px-5 sm:px-8 md:grid-cols-2 md:gap-14 lg:px-10">
      <div class="max-w-xl">
        <p class="text-xs font-bold uppercase tracking-[0.28em] text-[var(--primary)]">Sobre nosotros</p>

        <h2 class="mt-4 text-3xl font-bold leading-[1.15] text-neutral-900 sm:text-4xl lg:text-5xl">
          Maquillaje que se siente
          <span class="font-bold text-[var(--primary)]">como tú</span>
        </h2>

        <p class="mt-6 max-w-md leading-8 text-neutral-600">
          Somos una tienda colombiana de maquillaje y cuidado facial. Elegimos marca por marca,
          producto por producto, para que encuentres lo que de verdad necesitas — y te lo llevamos
          a donde estés.
        </p>

        <!-- Las tres cifras no son decoración: son las preguntas que la clienta
             se hace antes de escribir por WhatsApp. Originalidad, cobertura de
             envío y si le van a responder. -->
        <dl class="mt-8 flex flex-wrap gap-x-10 gap-y-5">
          <div v-for="dato in [
            { valor: '100%', texto: 'Productos originales' },
            { valor: '24 h', texto: 'Respuesta por WhatsApp' },
            { valor: 'Todo el país', texto: 'Envíos con contraentrega' }
          ]" :key="dato.texto">
            <dt class="text-xl font-bold text-[var(--primary)] sm:text-2xl">{{ dato.valor }}</dt>
            <dd class="mt-0.5 text-xs leading-5 text-neutral-500">{{ dato.texto }}</dd>
          </div>
        </dl>

        <RouterLink
          to="/tienda"
          class="mt-9 inline-flex min-h-12 items-center gap-2 rounded-full bg-[var(--primary)] px-7 text-sm font-bold text-white shadow-lg shadow-pink-300/50 transition hover:-translate-y-0.5 hover:bg-[var(--info)]"
        >
          Ver todos los productos
          <ArrowRight class="size-4" />
        </RouterLink>
      </div>

      <!--
        La foto y su fondo, juntos.

        El rosa es un bloque desplazado que asoma por detrás, no un panel
        pegado al borde de la pantalla: así el conjunto se lee como una pieza y
        no depende de cuánto mida la ventana. En el celular se apaga
        (`hidden md:block`), donde no hay sitio para que asome nada.

        La foto se recorta a una altura fija en vez de caer a su proporción
        natural: el original es vertical y muy alto, y dejarlo suelto estiraba
        la sección hasta los novecientos píxeles — una pantalla entera para un
        párrafo de tres líneas.
      -->
      <div class="relative mx-auto w-full max-w-md md:mx-0 md:justify-self-end">
        <div
          class="absolute -right-4 -top-4 bottom-8 left-10 hidden rounded-[2.5rem] bg-pink-100 md:block"
          aria-hidden="true"
        />
        <div
          class="absolute -bottom-5 -left-5 size-24 rounded-full bg-[var(--primary)]/10 md:size-32"
          aria-hidden="true"
        />
        <img
          :src="bannerHistoria"
          alt="Clienta de Strawberry Makeup con un maquillaje de tonos rosados"
          class="relative h-[420px] w-full rounded-[1.75rem] object-cover object-top shadow-[0_20px_50px_rgba(228,107,160,0.25)] sm:h-[520px]"
          loading="lazy"
        />
      </div>
    </div>
  </section>
</template>
