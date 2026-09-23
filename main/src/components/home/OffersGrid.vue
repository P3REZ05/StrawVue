<script setup>
import { computed } from 'vue'
import { RouterLink } from 'vue-router'
import { TAMANOS } from '../../stores/offers'

/**
 * La cuadrícula de "Ofertas Especiales".
 *
 * Este componente lo usan DOS sitios: la portada y la vista previa del panel.
 * A propósito. Una vista previa que dibuja su propia versión aproximada
 * miente en cuanto alguien toca el diseño de uno de los dos, y entonces deja
 * de servir para lo único que existe: decidir si publicar o no.
 *
 * Las cuatro piezas ocupan las mismas celdas en las dos anchuras —2 columnas
 * en el celular, 4 desde tablet—, así que la composición se reordena sola en
 * vez de romperse. `grid-flow-dense` rellena el hueco que deje una pieza alta.
 *
 * LA TARJETA ES SOLO LA IMAGEN. Nada de título, subtítulo, etiqueta ni «Ver
 * más» encima: el texto va dentro del volante que se diseña aparte, donde se
 * puede componer con su tipografía y su color. Escribirlo también aquí
 * significaba dos textos que hay que mantener iguales, y ninguno quedaba bien
 * sobre la foto del otro. Lo que la tarjeta sí conserva es **a dónde lleva**.
 *
 * Consecuencia: una tarjeta sin imagen no tiene nada que enseñar, así que en
 * la tienda no se pinta. En la vista previa sí, marcada, para que se vea qué
 * falta.
 */
const props = defineProps({
  ofertas: { type: Array, default: () => [] },
  // En la vista previa no se navega y sí se marcan los borradores.
  vistaPrevia: { type: Boolean, default: false },
  // Fuerza el ancho de celular dentro del panel, sin depender de la ventana.
  compacta: { type: Boolean, default: false }
})

const CLASES = Object.fromEntries(TAMANOS.map((t) => [t.id, t.clases]))

// En modo compacto se fuerzan 2 columnas siempre; si no, 2 en el celular y 4
// desde tablet.
const clasesRejilla = computed(() =>
  props.compacta
    ? 'grid grid-cols-2 grid-flow-row-dense gap-3 auto-rows-[7rem]'
    : 'grid grid-cols-2 grid-flow-row-dense gap-3 auto-rows-[8.5rem] sm:gap-4 sm:auto-rows-[9.5rem] md:grid-cols-4 lg:auto-rows-[10.5rem]'
)

function clasesDe(oferta) {
  return CLASES[oferta.size] || CLASES.pequena
}

/** El destino, resuelto. `null` significa que la tarjeta no es un enlace. */
function destino(oferta) {
  if (props.vistaPrevia) return null
  switch (oferta.linkType) {
    case 'category': return { path: '/tienda', query: { categoria: oferta.linkCategory } }
    case 'product': return { path: `/producto/${oferta.linkProduct}` }
    case 'url': return oferta.linkUrl
    default: return null
  }
}

function esExterno(oferta) {
  return oferta.linkType === 'url' && /^https?:\/\//i.test(oferta.linkUrl || '')
}

// En la tienda, una tarjeta sin imagen no se pinta: seria un rectangulo de
// color vacio. En la vista previa se muestra igual, para poder arreglarla.
const visibles = computed(() =>
  props.vistaPrevia ? props.ofertas : props.ofertas.filter((o) => o.imageUrl)
)
</script>

<template>
  <div :class="clasesRejilla">
    <component
      :is="esExterno(oferta) ? 'a' : (destino(oferta) ? RouterLink : 'div')"
      v-for="oferta in visibles"
      :key="oferta.id"
      v-bind="esExterno(oferta)
        ? { href: oferta.linkUrl, target: '_blank', rel: 'noopener noreferrer' }
        : (destino(oferta) ? { to: destino(oferta) } : {})"
      class="group relative block overflow-hidden rounded-2xl bg-pink-50 shadow-sm ring-1 ring-black/5 transition duration-300"
      :class="[
        clasesDe(oferta),
        destino(oferta) ? 'hover:-translate-y-0.5 hover:shadow-lg' : '',
        vistaPrevia && !oferta.published ? 'opacity-70 outline-2 outline-dashed outline-offset-2 outline-amber-400' : ''
      ]"
    >
      <img
        v-if="oferta.imageUrl"
        :src="oferta.imageUrl"
        :alt="oferta.title"
        class="absolute inset-0 h-full w-full object-cover transition duration-500 group-hover:scale-105"
        loading="lazy"
      />

      <!-- Solo en el panel: sin imagen la tarjeta no existe para la clienta,
           y hay que poder verlo sin publicar para enterarse. -->
      <span
        v-else
        class="absolute inset-0 grid place-items-center px-2 text-center text-xs font-bold leading-4 text-neutral-400"
      >
        Falta la imagen<br />no se ve en la tienda
      </span>

      <span
        v-if="vistaPrevia && !oferta.published"
        class="absolute right-2 top-2 rounded-full bg-amber-400 px-2 py-0.5 text-xs font-bold text-amber-950"
      >
        Borrador
      </span>
    </component>
  </div>
</template>
