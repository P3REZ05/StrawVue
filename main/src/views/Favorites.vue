<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { Heart, Trash2, ShoppingBag, ArrowRight } from 'lucide-vue-next'
import { useFavoritesStore } from '../stores/favorites'
import { useInventoryStore } from '../stores/inventory'
import { useCartStore } from '../stores/cart'
import { formatCurrency } from '../utils/formatCurrency'

/**
 * Favoritos.
 *
 * La lista guardada son solo identificadores (ver `stores/favorites.js`), así
 * que el producto se resuelve aquí contra el catálogo cargado. Eso tiene una
 * consecuencia que importa: un producto que la administradora despublicó o
 * agotó no se queda en la lista con datos viejos —desaparece, o aparece
 * marcado como agotado con su precio de hoy.
 *
 * Dos acciones, las que pidió el usuario: quitar, y pasar al carrito para
 * pagar. Un favorito con tonos NO se puede pasar al carrito desde aquí: habría
 * que elegir color, y elegirlo por ella es justo el error que hace que llegue
 * el pedido equivocado. Esos llevan a la ficha.
 */
const favoritos = useFavoritesStore()
const inventario = useInventoryStore()
const cart = useCartStore()
const router = useRouter()

const cargando = ref(true)
const aviso = ref('')

onMounted(async () => {
  try {
    await inventario.init()
  } finally {
    cargando.value = false
  }
})

// El orden es el de la lista guardada —lo último marcado, primero—, no el del
// catálogo: la clienta busca lo que acaba de guardar.
const productos = computed(() =>
  favoritos.ids
    .map((id) => inventario.catalogWithStock.find((p) => p.id === id))
    .filter((p) => p && p.status === 'active')
)

// Un favorito que ya no está publicado no se pinta, pero tampoco se borra en
// silencio: se cuenta, para poder explicar el hueco.
const retirados = computed(() => favoritos.ids.length - productos.value.length)

const tonosDe = (producto) => inventario.shadesWithStock(producto.id)
const necesitaTono = (producto) => tonosDe(producto).length > 0
const disponible = (producto) => Number(producto.saleStock ?? 0)

const paraElCarrito = computed(() =>
  productos.value.filter((p) => !necesitaTono(p) && disponible(p) > 0)
)

function quitar(producto) {
  favoritos.quitar(producto.id)
  aviso.value = `«${producto.name}» ya no está en tus favoritos.`
}

function alCarrito(producto) {
  cart.add(producto)
  cart.openDrawer()
}

// «Ir a pagar» con la lista entera: mete lo que se puede meter y lo dice. No
// vacía los favoritos — que una clienta compre un labial no significa que ya
// no le guste.
function pasarTodoYPagar() {
  const metidos = paraElCarrito.value.length
  paraElCarrito.value.forEach((producto) => cart.add(producto))
  if (!metidos) {
    aviso.value = 'Ninguno de tus favoritos se puede añadir directo: elige el tono desde su ficha.'
    return
  }
  router.push('/carrito')
}
</script>

<template>
  <section class="mx-auto max-w-7xl px-5 py-10 sm:px-8 lg:px-10">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 class="flex items-center gap-2.5 text-3xl font-bold text-black">
          <Heart class="size-7 text-[var(--primary)]" fill="currentColor" />
          Mis favoritos
        </h1>
        <p class="mt-2 max-w-xl text-sm leading-6 text-neutral-500">
          Lo que guardaste para pensártelo. Se queda en este navegador, sin registro ni contraseña.
        </p>
      </div>

      <button
        v-if="productos.length"
        class="inline-flex min-h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-6 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="pasarTodoYPagar"
      >
        <ShoppingBag class="size-4" />
        Pasar al carrito e ir a pagar
      </button>
    </div>

    <p v-if="aviso" class="mt-5 rounded-xl bg-pink-50 px-4 py-3 text-sm font-semibold text-[var(--primary)]">
      {{ aviso }}
    </p>

    <p v-if="cargando" class="mt-10 text-sm text-neutral-500">Cargando tus favoritos…</p>

    <div v-else-if="!productos.length" class="mt-10 rounded-2xl border border-dashed border-pink-200 bg-white p-12 text-center">
      <Heart class="mx-auto size-10 text-pink-300" />
      <p class="mt-4 text-lg font-bold text-neutral-700">Todavía no has guardado nada</p>
      <p class="mx-auto mt-2 max-w-md text-sm leading-6 text-neutral-500">
        Pulsa el corazón de cualquier producto para guardarlo aquí y decidir con calma.
      </p>
      <RouterLink
        to="/tienda"
        class="mt-6 inline-flex min-h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-6 text-sm font-bold text-white transition hover:bg-[var(--info)]"
      >
        Ver la tienda <ArrowRight class="size-4" />
      </RouterLink>
    </div>

    <template v-else>
      <ul class="mt-8 space-y-4">
        <li
          v-for="producto in productos" :key="producto.id"
          class="flex flex-col gap-4 rounded-2xl bg-white p-4 shadow-sm ring-1 ring-pink-100 sm:flex-row sm:items-center"
        >
          <RouterLink :to="`/producto/${producto.id}`" class="grid size-24 shrink-0 place-items-center overflow-hidden rounded-xl bg-pink-50">
            <img v-if="producto.image" :src="producto.image" :alt="producto.name" class="h-full w-full object-contain p-2" />
            <span v-else class="text-xs text-neutral-400">Sin foto</span>
          </RouterLink>

          <div class="min-w-0 flex-1">
            <p class="text-xs font-bold tracking-wider text-[var(--primary)]">{{ producto.category }}</p>
            <RouterLink :to="`/producto/${producto.id}`" class="mt-0.5 block font-bold leading-6 text-black hover:text-[var(--primary)]">
              {{ producto.name }}
            </RouterLink>
            <p class="mt-1 flex flex-wrap items-baseline gap-2">
              <span class="text-lg font-bold text-[var(--primary)]">
                {{ formatCurrency(producto.promoPrice ?? producto.basePrice) }}
              </span>
              <span v-if="producto.enPromocion" class="text-sm text-neutral-400 line-through">
                {{ formatCurrency(producto.basePrice) }}
              </span>
            </p>
            <p v-if="disponible(producto) === 0" class="mt-1 text-xs font-bold text-neutral-500">Agotado ahora mismo</p>
            <p v-else-if="necesitaTono(producto)" class="mt-1 text-xs text-neutral-500">
              {{ tonosDe(producto).length }} tonos — elige el tuyo en la ficha
            </p>
          </div>

          <div class="flex shrink-0 items-center gap-2">
            <RouterLink
              v-if="necesitaTono(producto)"
              :to="`/producto/${producto.id}`"
              class="inline-flex min-h-11 items-center rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
            >
              Elegir tono
            </RouterLink>
            <button
              v-else
              :disabled="disponible(producto) === 0"
              class="inline-flex min-h-11 items-center rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:cursor-not-allowed disabled:bg-neutral-300"
              @click="alCarrito(producto)"
            >
              {{ disponible(producto) === 0 ? 'Agotado' : 'Al carrito' }}
            </button>

            <button
              class="grid size-11 place-items-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600"
              :aria-label="`Quitar ${producto.name} de favoritos`"
              title="Quitar de favoritos"
              @click="quitar(producto)"
            >
              <Trash2 class="size-5" />
            </button>
          </div>
        </li>
      </ul>

      <p v-if="retirados > 0" class="mt-5 text-xs leading-5 text-neutral-500">
        {{ retirados === 1 ? 'Un producto que guardaste ya no está' : `${retirados} productos que guardaste ya no están` }}
        a la venta, así que no aparece{{ retirados === 1 ? '' : 'n' }} en la lista.
      </p>
    </template>
  </section>
</template>
