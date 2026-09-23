<script setup>
import { computed } from 'vue'
import { RouterLink } from 'vue-router'
import { Heart } from 'lucide-vue-next'
import { useCartStore } from '../../stores/cart'
import { useInventoryStore } from '../../stores/inventory'
import { useFavoritesStore } from '../../stores/favorites'
import { formatCurrency } from '../../utils/formatCurrency'

const props = defineProps({ product: { type: Object, required: true } })
const cart = useCartStore()
const inventario = useInventoryStore()
const favoritos = useFavoritesStore()

// Las etiquetas (VIRAL, NUEVO…) las pone la administradora desde el panel y
// son escaparate: no cambian el precio. La de promoción, en cambio, la calcula
// el servidor, así que va primero y en el sitio de siempre.
const etiquetas = computed(() => props.product.badges || [])

const tonos = computed(() => inventario.shadesWithStock(props.product.id))
const disponible = computed(() => Number(props.product.saleStock ?? props.product.stock ?? 0))
const tonosDisponibles = computed(() => tonos.value.filter((t) => t.stock > 0).length)

// Un producto con tonos no se puede añadir desde la tarjeta: habría que elegir
// cuál. La tarjeta lleva a la ficha, que es donde se ve el color.
const requiereElegirTono = computed(() => tonos.value.length > 0)

// El precio y la promoción los resuelve la base. Si el producto tiene tonos,
// se muestra el más barato disponible: es el gancho que hace clic al cliente.
const precioMostrado = computed(() => {
  if (tonos.value.length) {
    const conStock = tonos.value.filter((t) => t.stock > 0)
    const lista = conStock.length ? conStock : tonos.value
    return Math.min(...lista.map((t) => t.price))
  }
  return props.product.promoPrice ?? props.product.salePrice ?? props.product.price
})

const enPromocion = computed(() =>
  tonos.value.length ? tonos.value.some((t) => t.enPromocion) : props.product.enPromocion
)

const etiquetaPromo = computed(() =>
  tonos.value.find((t) => t.promoLabel)?.promoLabel || props.product.promoLabel || ''
)

function addToCart() {
  cart.add(props.product)
  cart.openDrawer()
}
</script>

<template>
  <article class="group relative flex h-full flex-col overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-pink-100 transition hover:-translate-y-1 hover:shadow-lg">
    <RouterLink :to="`/producto/${product.id}`" class="relative block h-64 overflow-hidden bg-pink-50">
      <img
        v-if="product.image" :src="product.image" :alt="product.name"
        class="h-full w-full object-contain p-3 transition duration-500 group-hover:scale-105"
        loading="lazy"
      />
      <span v-else class="grid h-full place-items-center text-sm text-neutral-400">Sin imagen</span>
      <!-- «Agotado» y la etiqueta de promoción bajan al pie de la foto: arriba
           a la izquierda vive ahora el corazón, y arriba a la derecha las
           etiquetas. Tres cosas peleando por la misma esquina era lo que
           pasaba antes de separarlas. -->
      <span v-if="disponible === 0" class="absolute bottom-3 left-3 rounded-full bg-black px-3 py-1 text-xs font-bold text-white">Agotado</span>
      <span v-else-if="etiquetaPromo" class="absolute bottom-3 left-3 rounded-full bg-[var(--primary)] px-3 py-1 text-xs font-bold text-white shadow">{{ etiquetaPromo }}</span>

      <!-- Como máximo dos etiquetas: tres chips encima de la foto dejan de
           leerse y pasan a ser ruido. -->
      <span
        v-for="(etiqueta, i) in etiquetas.slice(0, 2)" :key="etiqueta.id"
        class="absolute right-3 rounded-full px-3 py-1 text-xs font-bold uppercase tracking-wide shadow"
        :style="{ background: etiqueta.colorFondo, color: etiqueta.colorTexto, top: `${12 + i * 32}px` }"
      >{{ etiqueta.name }}</span>
    </RouterLink>

    <!--
      El corazón va FUERA del RouterLink de la foto. Dentro, cada pulsación
      sería también una navegación: la clienta guardaría el producto y la
      página cambiaría debajo. `.prevent` y `.stop` no bastan cuando el
      elemento es hijo de un enlace en el móvil, donde el gesto se resuelve
      distinto; sacarlo del enlace sí.
    -->
    <button
      class="absolute left-3 top-3 grid size-11 place-items-center rounded-full bg-white/80 backdrop-blur transition hover:bg-white hover:text-[var(--primary)]"
      :class="favoritos.esFavorito(product.id) ? 'text-[var(--primary)]' : 'text-neutral-400'"
      :aria-pressed="favoritos.esFavorito(product.id)"
      :aria-label="favoritos.esFavorito(product.id) ? `Quitar ${product.name} de favoritos` : `Guardar ${product.name} en favoritos`"
      :title="favoritos.esFavorito(product.id) ? 'Quitar de favoritos' : 'Guardar en favoritos'"
      type="button"
      @click="favoritos.alternar(product.id)"
    >
      <Heart class="size-5" :fill="favoritos.esFavorito(product.id) ? 'currentColor' : 'none'" />
    </button>

    <div class="flex flex-1 flex-col p-5">
      <p class="text-xs font-bold tracking-wider text-[var(--primary)]">{{ product.category }}</p>
      <RouterLink :to="`/producto/${product.id}`" class="mt-2 block py-1 font-bold leading-6 text-black hover:text-[var(--primary)]">{{ product.name }}</RouterLink>

      <!-- Adelanto de tonos: el color es el argumento de venta, no el nombre. -->
      <RouterLink v-if="tonos.length" :to="`/producto/${product.id}`" class="mt-2 flex min-h-11 items-center gap-1.5" aria-label="Ver todos los tonos">
        <span
          v-for="tono in tonos.slice(0, 6)" :key="tono.id"
          class="size-5 rounded-full border border-black/10"
          :class="tono.stock <= 0 ? 'opacity-30' : ''"
          :style="tono.image ? { backgroundImage: `url(${tono.image})`, backgroundSize: 'cover' } : { background: tono.swatchHex || '#e5e5e5' }"
          :title="`${tono.shadeCode} ${tono.name}`"
        />
        <span v-if="tonos.length > 6" class="text-xs font-semibold text-neutral-400">+{{ tonos.length - 6 }}</span>
      </RouterLink>

      <p v-else class="mt-2 line-clamp-2 text-sm leading-6 text-neutral-500">{{ product.description }}</p>

      <div class="mt-auto pt-5">
        <div class="flex flex-wrap items-baseline gap-2">
          <p class="text-lg font-bold text-[var(--primary)]">{{ formatCurrency(precioMostrado) }}</p>
          <p v-if="enPromocion" class="text-sm text-neutral-400 line-through">{{ formatCurrency(product.basePrice) }}</p>
        </div>
        <p v-if="tonos.length" class="mt-1 text-xs text-neutral-500">
          {{ tonosDisponibles }} de {{ tonos.length }} tonos disponibles
        </p>

        <RouterLink
          v-if="requiereElegirTono"
          :to="`/producto/${product.id}`"
          class="mt-4 block w-full rounded-full bg-[var(--primary)] px-4 py-2.5 text-center text-sm font-bold text-white transition hover:bg-[var(--info)]"
          :class="tonosDisponibles === 0 ? 'pointer-events-none bg-neutral-300' : ''"
        >
          {{ tonosDisponibles === 0 ? 'Agotado' : 'Elegir tono' }}
        </RouterLink>

        <button
          v-else
          :disabled="disponible === 0"
          class="mt-4 w-full rounded-full bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:cursor-not-allowed disabled:bg-neutral-300"
          @click="addToCart"
        >
          {{ disponible === 0 ? 'Agotado' : 'Agregar al carrito' }}
        </button>
      </div>
    </div>
  </article>
</template>
