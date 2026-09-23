<script setup>
import { computed, ref } from 'vue'
import { PackageCheck, ArrowRightLeft, Eye } from 'lucide-vue-next'
import ProductoEnBodega from './ProductoEnBodega.vue'
import { useInventoryStore } from '../../../stores/inventory'
import { useInventoryRows } from '../../../composables/useInventoryRows'
import { formatCurrency } from '../../../utils/formatCurrency'

/**
 * BODEGA. Lo que ya llegó y todavía no está a la venta.
 *
 * Antes esto no tenía pantalla: vivía como una rejilla de tarjetas al final de
 * «Inventario de Venta», debajo de una tabla larga. La bodega es un paso del
 * flujo —lo que compras entra aquí y de aquí sale a la vitrina—, así que
 * esconderla dentro de la pantalla del paso siguiente obligaba a adivinar
 * dónde estaba la mercancía recién comprada.
 *
 * Aquí solo se transfiere. El precio se edita en «Listo para vender», que es
 * donde tiene sentido mirarlo junto al margen.
 */
const inventory = useInventoryStore()
const { filasEnBodega, etiquetaDe } = useInventoryRows()

const huerfanas = computed(() => filasEnBodega.value.filter((fila) => fila.huerfano))

const error = ref('')
const aviso = ref('')
const busy = ref(false)
const transferencia = ref(null)
const detalle = ref(null)

function abrirDetalle(fila) {
  error.value = ''
  aviso.value = ''
  detalle.value = fila
}

// Desde la ficha se puede transferir directamente: se cierra una y se abre la
// otra, para no apilar dos modales uno encima del otro.
function transferirDesdeDetalle(fila) {
  detalle.value = null
  abrirTransferencia(fila)
}

const totalUnidades = computed(() =>
  filasEnBodega.value.reduce((suma, fila) => suma + fila.quantity, 0)
)

const valorEnBodega = computed(() =>
  filasEnBodega.value.reduce((suma, fila) => suma + fila.quantity * fila.cost, 0)
)

function abrirTransferencia(fila) {
  error.value = ''
  aviso.value = ''
  transferencia.value = {
    fila,
    etiqueta: etiquetaDe(fila),
    disponible: fila.quantity,
    cantidad: fila.quantity,
    nota: ''
  }
}

const transferenciaInvalida = computed(() => {
  const t = transferencia.value
  if (!t) return ''
  const n = Number(t.cantidad)
  if (!Number.isFinite(n) || n <= 0) return 'La cantidad debe ser mayor a cero.'
  if (!Number.isInteger(n)) return 'No se pueden transferir fracciones de unidad.'
  if (n > t.disponible) return `Solo hay ${t.disponible} en bodega.`
  return ''
})

async function confirmarTransferencia() {
  const t = transferencia.value
  if (!t || transferenciaInvalida.value) return

  busy.value = true
  error.value = ''
  try {
    await inventory.moveFromWarehouseToSale(
      t.fila.productId, Number(t.cantidad), t.fila.variantId, t.nota.trim()
    )
    // El modal se cierra DESPUÉS de que la base confirme.
    aviso.value = `${t.cantidad} unidad(es) de «${t.etiqueta}» ya están a la venta.`
    transferencia.value = null
  } catch (fallo) {
    error.value = fallo.message || 'No se pudo transferir el inventario.'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="space-y-5">
    <div>
      <h2 class="text-xl font-bold text-black">Bodega</h2>
      <p class="mt-1 max-w-2xl text-sm leading-6 text-neutral-500">
        Mercancía recibida que todavía no está a la venta. <strong>El cliente no la ve</strong>
        hasta que la pases a la vitrina. Puedes pasar solo una parte: compras cien y sacas veinte.
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


    <div v-if="filasEnBodega.length" class="grid gap-3 sm:grid-cols-3">
      <div class="rounded-xl bg-amber-50 px-4 py-3">
        <p class="text-xl font-bold text-amber-700">{{ totalUnidades }}</p>
        <p class="text-xs font-semibold text-amber-700/70">
          {{ totalUnidades === 1 ? 'unidad guardada' : 'unidades guardadas' }}
        </p>
      </div>
      <div class="rounded-xl bg-neutral-100 px-4 py-3">
        <p class="text-xl font-bold text-neutral-700">{{ filasEnBodega.length }}</p>
        <p class="text-xs font-semibold text-neutral-500">
          {{ filasEnBodega.length === 1 ? 'referencia distinta' : 'referencias distintas' }}
        </p>
      </div>
      <div class="rounded-xl bg-pink-50 px-4 py-3">
        <p class="text-xl font-bold text-[var(--primary)]">{{ formatCurrency(valorEnBodega) }}</p>
        <p class="text-xs font-semibold text-[var(--primary)]/70">invertido, al costo</p>
      </div>
    </div>

    <div v-if="filasEnBodega.length" class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-150 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Producto</th>
            <th class="px-5 py-4">Tono</th>
            <th class="px-5 py-4">En bodega</th>
            <th class="px-5 py-4">Ya en venta</th>
            <th class="px-5 py-4">Costo unitario</th>
            <th class="px-5 py-4"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="fila in filasEnBodega"
            :key="fila.key"
            class="cursor-pointer border-b border-pink-50 transition hover:bg-pink-50/50"
            @click="abrirDetalle(fila)"
          >
            <td class="px-5 py-4 font-medium">
              {{ fila.name }}
              <span class="mt-0.5 block text-xs font-normal text-neutral-400">Ver ficha</span>
            </td>
            <td class="px-5 py-4 text-neutral-500">{{ fila.variantName || '—' }}</td>
            <td class="px-5 py-4 font-bold text-amber-600">{{ fila.quantity }}</td>
            <td class="px-5 py-4 text-neutral-500">{{ fila.saleStock }}</td>
            <td class="px-5 py-4">{{ fila.cost ? formatCurrency(fila.cost) : '—' }}</td>
            <!-- `@click.stop` para que abrir la ficha y transferir no se
                 disparen a la vez: la fila entera también es pulsable. -->
            <td class="px-5 py-4">
              <div class="flex justify-end gap-1.5">
                <button
                  class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                  aria-label="Ver ficha completa"
                  title="Ver ficha completa"
                  @click.stop="abrirDetalle(fila)"
                >
                  <Eye class="size-4" />
                </button>
                <button
                  :disabled="busy"
                  class="inline-flex h-10 items-center gap-1.5 rounded-full bg-[var(--primary)] px-4 text-xs font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
                  @click.stop="abrirTransferencia(fila)"
                >
                  <ArrowRightLeft class="size-3.5" /> Pasar a venta
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="rounded-2xl border border-dashed border-pink-200 bg-white p-10 text-center">
      <PackageCheck class="mx-auto size-8 text-pink-300" />
      <p class="mt-3 font-bold text-neutral-700">La bodega está vacía</p>
      <p class="mx-auto mt-1 max-w-md text-sm leading-6 text-neutral-500">
        Todo lo que compraste ya está a la venta, o todavía no has registrado ninguna compra.
        La mercancía entra aquí desde la pestaña <strong>Compras</strong>.
      </p>
    </div>

    <ProductoEnBodega
      v-if="detalle"
      :fila="detalle"
      @cerrar="detalle = null"
      @transferir="transferirDesdeDetalle"
    />

    <!-- Modal propio, no `prompt()`: el del navegador bloquea la pestaña, no
         valida hasta después de aceptar y no deja explicar qué implica la
         acción, que aquí es justo lo que decide qué ve el cliente. -->
    <div
      v-if="transferencia"
      class="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4"
      @click.self="transferencia = null"
    >
      <form class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" @submit.prevent="confirmarTransferencia">
        <h3 class="text-lg font-bold text-black">Pasar a venta</h3>
        <p class="mt-1 text-sm text-neutral-500">{{ transferencia.etiqueta }}</p>
        <p class="mt-3 rounded-xl bg-amber-50 px-3 py-2 text-sm font-semibold text-amber-700">
          En bodega: {{ transferencia.disponible }} unidad(es).
          Lo que pases aquí es lo que el cliente podrá comprar.
        </p>

        <label class="mt-4 block text-sm font-semibold text-neutral-700">
          Cantidad
          <div class="mt-1 flex gap-2">
            <input
              v-model="transferencia.cantidad"
              type="number" min="1" step="1" :max="transferencia.disponible"
              class="h-11 w-full rounded-xl border border-pink-100 px-4 text-sm font-normal outline-none focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
            />
            <button
              type="button"
              class="h-11 shrink-0 rounded-xl bg-neutral-100 px-4 text-sm font-bold text-neutral-700 transition hover:bg-neutral-200"
              @click="transferencia.cantidad = transferencia.disponible"
            >
              Todo
            </button>
          </div>
        </label>

        <label class="mt-4 block text-sm font-semibold text-neutral-700">
          Nota <span class="font-normal text-neutral-400">(opcional, queda en el historial)</span>
          <input
            v-model="transferencia.nota"
            class="mt-1 h-11 w-full rounded-xl border border-pink-100 px-4 text-sm font-normal outline-none focus:border-[var(--primary)]"
            placeholder="Reposición de vitrina"
          />
        </label>

        <p v-if="transferenciaInvalida" class="mt-3 text-sm font-semibold text-red-600">
          {{ transferenciaInvalida }}
        </p>

        <div class="mt-6 flex gap-2">
          <button
            type="submit"
            :disabled="busy || Boolean(transferenciaInvalida)"
            class="h-11 flex-1 rounded-full bg-[var(--primary)] text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          >
            {{ busy ? 'Transfiriendo…' : 'Pasar a venta' }}
          </button>
          <button
            type="button"
            class="h-11 rounded-full border border-pink-200 px-5 text-sm font-bold text-neutral-600"
            @click="transferencia = null"
          >
            Cancelar
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
