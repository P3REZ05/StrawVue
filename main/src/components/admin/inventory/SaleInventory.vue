<script setup>
import { computed, ref } from 'vue'
import { useCatalogStore } from '../../../stores/catalog'
import { useInventoryRows } from '../../../composables/useInventoryRows'
import { formatCurrency } from '../../../utils/formatCurrency'

// La bodega se mudó a `Warehouse.vue`. Esta pantalla responde a una sola
// pregunta —qué se está vendiendo y con cuánto margen— y por eso ya no lleva
// dentro la rejilla de bodega ni el diálogo de transferencia.

const emit = defineEmits(['ir-a-bodega'])

const catalogo = useCatalogStore()
const { filasEnVenta, etiquetaDe } = useInventoryRows()

const huerfanas = computed(() => filasEnVenta.value.filter((fila) => fila.huerfano))
const error = ref('')
const aviso = ref('')
const busy = ref(false)

// El diálogo de precio se hacía con `prompt()` del navegador: bloquea la
// pestaña, no se lee bien en el móvil y no valida hasta después de aceptar.
const edicionPrecio = ref(null)

function productById(productId) {
  return catalogo.productById(productId)
}

function profit(row) {
  return (row.price - row.cost) * row.quantity
}

async function toggleActive(row) {
  const product = productById(row.productId)
  if (product) await catalogo.setProductStatus(row.productId, product.active ? 'paused' : 'active')
}

function abrirPrecio(row) {
  error.value = ''
  aviso.value = ''
  const tono = row.variantId ? catalogo.shades.find((s) => s.id === row.variantId) : null
  const producto = productById(row.productId)
  edicionPrecio.value = {
    row,
    etiqueta: etiquetaDe(row),
    esTono: Boolean(tono),
    // `null` en un tono significa heredar. Distinguirlo de 0 es la diferencia
    // entre "sigue el precio del producto" y "es gratis".
    hereda: Boolean(tono) && tono.price == null,
    precioProducto: producto?.salePrice ?? producto?.price ?? 0,
    valor: tono ? (tono.price ?? '') : (producto?.price ?? 0),
    tonosQueHeredan: tono
      ? 0
      : catalogo.shadesOf(row.productId).filter((t) => t.price == null).length
  }
}

const precioInvalido = computed(() => {
  const e = edicionPrecio.value
  if (!e) return ''
  if (e.esTono && e.hereda) return ''
  const n = Number(e.valor)
  if (e.valor === '' || !Number.isFinite(n) || n < 0) return 'Escribe un precio válido.'
  return ''
})

async function confirmarPrecio() {
  const e = edicionPrecio.value
  if (!e || precioInvalido.value) return

  busy.value = true
  error.value = ''
  try {
    if (e.esTono) {
      await catalogo.setShadePrice(e.row.variantId, e.hereda ? null : Number(e.valor))
      aviso.value = e.hereda
        ? `"${e.etiqueta}" vuelve a heredar el precio del producto.`
        : `Precio de "${e.etiqueta}" actualizado.`
    } else {
      await catalogo.setProductPrice(e.row.productId, Number(e.valor))
      aviso.value = `Precio de "${e.row.name}" actualizado.`
    }
    edicionPrecio.value = null
  } catch (fallo) {
    error.value = fallo.message || 'No se pudo actualizar el precio.'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-xl font-bold text-black">Listo para vender</h2>
      <p class="mt-1 max-w-2xl text-sm leading-6 text-neutral-500">
        Lo que el cliente puede comprar ahora mismo, con su margen. Las existencias
        salen del historial de movimientos y el costo es el promedio ponderado de
        las compras. Para sacar más unidades a la vitrina, ve a <strong>Bodega</strong>.
      </p>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="aviso" class="rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">{{ aviso }}</p>

    <!--
      Existencias que la clienta NO ve: unidades registradas contra el producto
      base en un producto que tiene tonos. La tienda suma tono a tono, así que
      estas no cuentan para nadie y el producto puede salir «Agotado» con
      mercancía en la vitrina. Se avisa aquí porque es donde se mira el stock,
      y se explica cómo arreglarlo — el error se comete en Compras.
    -->
    <div v-if="huerfanas.length" class="rounded-xl border border-amber-200 bg-amber-50 p-4">
      <p class="text-sm font-bold text-amber-900">
        {{ huerfanas.length === 1 ? 'Hay 1 partida que la clienta no ve' : `Hay ${huerfanas.length} partidas que la clienta no ve` }}
      </p>
      <p class="mt-1 text-xs leading-5 text-amber-800">
        Estas unidades se registraron <strong>sin tono</strong> en productos que sí tienen tonos.
        La tienda cuenta el stock tono a tono, porque es lo que la clienta elige, así que estas
        no las suma: el producto puede aparecer <strong>«Agotado»</strong> aunque estén aquí.
        Corrige la compra en el paso <strong>Compras</strong> eligiendo el tono al que pertenecen.
      </p>
      <ul class="mt-2 list-disc pl-5 text-xs text-amber-800">
        <li v-for="fila in huerfanas" :key="fila.key">
          <strong>{{ fila.name }}</strong> — {{ fila.quantity }} unidad(es) sin tono
        </li>
      </ul>
    </div>


    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-250 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Producto</th>
            <th class="px-5 py-4">Variante</th>
            <th class="px-5 py-4">Categoría</th>
            <th class="px-5 py-4">Stock</th>
            <th class="px-5 py-4">Costo</th>
            <th class="px-5 py-4">Precio Venta</th>
            <th class="px-5 py-4">Ganancia</th>
            <th class="px-5 py-4">En Bodega</th>
            <th class="px-5 py-4">Estado</th>
            <th class="px-5 py-4">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in filasEnVenta" :key="row.key" class="border-b border-pink-50 transition hover:bg-pink-50/50">
            <td class="px-5 py-4 font-medium">{{ row.name }}</td>
            <td class="px-5 py-4 text-neutral-500">{{ row.variantName || '—' }}</td>
            <td class="px-5 py-4">
              <span class="inline-flex rounded-full bg-pink-100 px-3 py-1 text-xs font-bold text-[var(--primary)]">{{ row.category }}</span>
            </td>
            <td class="px-5 py-4 font-bold" :class="row.quantity ? 'text-emerald-600' : 'text-red-500'">{{ row.quantity }}</td>
            <td class="px-5 py-4">{{ formatCurrency(row.cost) }}</td>
            <td class="px-5 py-4 font-bold text-[var(--primary)]">{{ formatCurrency(row.price) }}</td>
            <td class="px-5 py-4 font-bold text-emerald-600">{{ formatCurrency(profit(row)) }}</td>
            <td class="px-5 py-4 font-bold text-amber-600">{{ row.warehouseStock }}</td>
            <td class="px-5 py-4">
              <span
                class="inline-flex rounded-full px-3 py-1 text-xs font-bold text-white"
                :class="row.active ? 'bg-emerald-500' : 'bg-neutral-400'"
              >
                {{ row.active ? 'Activo' : 'Pausado' }}
              </span>
            </td>
            <td class="px-5 py-4">
              <div class="flex flex-wrap gap-1.5">
                <button
                  class="rounded-full bg-[var(--primary)] px-3 py-1.5 text-xs font-bold text-white transition hover:bg-[var(--info)]"
                  @click="abrirPrecio(row)"
                >
                  Precio
                </button>
<button
                  v-if="row.warehouseStock > 0"
                  class="rounded-full bg-amber-500 px-3 py-1.5 text-xs font-bold text-white transition hover:bg-amber-600"
                  title="Ir a Bodega para pasar unidades a la venta"
                  @click="emit('ir-a-bodega')"
                >
                  Hay {{ row.warehouseStock }} en bodega
                </button>
                <button
                  class="rounded-full px-3 py-1.5 text-xs font-bold text-white transition"
                  :class="row.active ? 'bg-neutral-400 hover:bg-neutral-500' : 'bg-emerald-500 hover:bg-emerald-600'"
                  @click="toggleActive(row)"
                >
                  {{ row.active ? 'Pausar' : 'Activar' }}
                </button>
              </div>
            </td>
          </tr>
          <tr v-if="!filasEnVenta.length">
            <td colspan="10" class="p-10 text-center text-neutral-500">
              Todavía no hay nada a la venta. Registra una compra en <strong>Compras</strong>
              y luego pasa unidades a la venta desde <strong>Bodega</strong>.
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Precio de venta -->
    <div
      v-if="edicionPrecio"
      class="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4"
      @click.self="edicionPrecio = null"
    >
      <form class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" @submit.prevent="confirmarPrecio">
        <h3 class="text-lg font-bold text-black">Precio de venta</h3>
        <p class="mt-1 text-sm text-neutral-500">{{ edicionPrecio.etiqueta }}</p>

        <p
          v-if="!edicionPrecio.esTono && edicionPrecio.tonosQueHeredan"
          class="mt-3 rounded-xl bg-amber-50 px-3 py-2 text-sm font-semibold text-amber-700"
        >
          {{ edicionPrecio.tonosQueHeredan }} tono(s) heredan este precio y cambiarán con él.
        </p>

        <label v-if="edicionPrecio.esTono" class="mt-4 flex items-start gap-2 text-sm text-neutral-700">
          <input v-model="edicionPrecio.hereda" type="checkbox" class="mt-0.5 size-4 accent-[var(--primary)]" />
          <span>
            Heredar el precio del producto
            <span class="block text-xs text-neutral-400">Hoy son {{ formatCurrency(edicionPrecio.precioProducto) }}</span>
          </span>
        </label>

        <label v-if="!edicionPrecio.esTono || !edicionPrecio.hereda" class="mt-4 block text-sm font-semibold text-neutral-700">
          Precio
          <input
            v-model="edicionPrecio.valor"
            type="number" min="0" step="100"
            class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
          />
          <span class="mt-1 block text-xs font-normal text-neutral-400">
            Costo promedio: {{ formatCurrency(edicionPrecio.row.cost) }}
          </span>
        </label>

        <p v-if="precioInvalido" class="mt-3 text-sm font-semibold text-red-600">{{ precioInvalido }}</p>

        <div class="mt-6 flex justify-end gap-3">
          <button type="button" class="rounded-full bg-neutral-200 px-5 py-2.5 text-sm font-bold text-neutral-700 transition hover:bg-neutral-300" @click="edicionPrecio = null">
            Cancelar
          </button>
          <button
            type="submit" :disabled="busy || Boolean(precioInvalido)"
            class="rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          >
            Guardar
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
