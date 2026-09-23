<script setup>
import { computed } from 'vue'
import {
  X, PackagePlus, ArrowRightLeft, Undo2, AlertTriangle, ShoppingCart, ExternalLink
} from 'lucide-vue-next'
import { useCatalogStore } from '../../../stores/catalog'
import { useInventoryStore } from '../../../stores/inventory'
import { usePurchasesStore } from '../../../stores/purchases'
import { useSuppliersStore } from '../../../stores/suppliers'
import { formatCurrency } from '../../../utils/formatCurrency'

/**
 * Ficha completa de una referencia que está en bodega.
 *
 * La tabla de bodega solo puede mostrar cinco columnas sin volverse ilegible,
 * pero al decidir cuántas unidades sacar a la vitrina hacen falta más cosas:
 * el precio al que se va a vender, de qué compra vino, a qué proveedor se le
 * compró y —sobre todo— **la nota que se escribió al registrarla**. Esa nota
 * es el único sitio donde queda escrito "vienen con el empaque golpeado" o
 * "son de la promoción de julio", y hasta ahora no se podía leer desde
 * ninguna pantalla de inventario.
 *
 * Es solo lectura salvo por el botón de transferir. Editar la ficha se hace en
 * el editor de producto, que es donde están todos los campos.
 */
const props = defineProps({
  fila: { type: Object, required: true }
})
const emit = defineEmits(['cerrar', 'transferir'])

const catalogo = useCatalogStore()
const inventario = useInventoryStore()
const compras = usePurchasesStore()
const proveedores = useSuppliersStore()

const producto = computed(() => catalogo.productById(props.fila.productId))
const tono = computed(() =>
  props.fila.variantId ? catalogo.shades.find((s) => s.id === props.fila.variantId) : null
)

const foto = computed(() =>
  catalogo.imagesOf(props.fila.productId, props.fila.variantId)[0]
  || catalogo.primaryImageOf(props.fila.productId)
  || null
)

/** El precio al que se venderá: el del tono si lo tiene, si no el del producto. */
const precioVenta = computed(() => {
  if (tono.value && tono.value.price != null) return tono.value.price
  return producto.value?.salePrice ?? producto.value?.price ?? 0
})
const heredaPrecio = computed(() => Boolean(tono.value) && tono.value.price == null)

const margen = computed(() => {
  const costo = props.fila.cost
  if (!costo || !precioVenta.value) return null
  return ((precioVenta.value - costo) / precioVenta.value) * 100
})

/** Atributos de la ficha, ya resueltos a nombres y sin los que están vacíos. */
const atributos = computed(() => {
  const p = producto.value
  if (!p) return []
  return [
    ['Marca', catalogo.optionName('brands', p.brandId)],
    ['Categoría', p.category],
    ['Tipo de piel', catalogo.optionName('skinTypes', p.skinTypeId)],
    ['Acabado', catalogo.optionName('finishes', p.finishId)],
    ['Cobertura', catalogo.optionName('coverages', p.coverageId)],
    ['Contenido', p.netContentMl ? `${p.netContentMl} ml` : ''],
    ['Código de barras', p.barcode],
    ['SKU', tono.value?.sku || ''],
    ['Código de tono', tono.value?.shadeCode || ''],
    ['Subtono', catalogo.optionName('undertones', tono.value?.undertoneId)],
    ['Familia', catalogo.optionName('shadeFamilies', tono.value?.shadeFamilyId)]
  ].filter(([, valor]) => valor)
})

/**
 * Las notas que escribe el propio sistema al registrar un movimiento.
 *
 * Se quitan del historial porque no aportan nada: el título del evento ya dice
 * lo mismo, y repetirlo entierra la nota que sí escribió una persona. En una
 * transferencia la nota real viene detrás de un « · », así que se separa.
 */
const NOTAS_AUTOMATICAS = [
  'Entrada a bodega por compra',
  'Salida de bodega a inventario de venta',
  'Entrada a inventario de venta'
]

function notaHumana(texto) {
  if (!texto) return ''
  let resto = texto
  for (const automatica of NOTAS_AUTOMATICAS) {
    if (resto.startsWith(automatica)) {
      resto = resto.slice(automatica.length)
      break
    }
  }
  return resto.replace(/^\s*·\s*/, '').trim()
}

const ESTILOS = {
  purchase: { icono: PackagePlus, titulo: 'Entrada por compra', clase: 'text-emerald-700 bg-emerald-50' },
  transfer: { icono: ArrowRightLeft, titulo: 'Transferencia', clase: 'text-amber-700 bg-amber-50' },
  return: { icono: Undo2, titulo: 'Devolución', clase: 'text-amber-700 bg-amber-50' },
  damage: { icono: AlertTriangle, titulo: 'Baja por daño', clase: 'text-red-700 bg-red-50' },
  adjustment: { icono: AlertTriangle, titulo: 'Ajuste', clase: 'text-neutral-700 bg-neutral-100' },
  sale: { icono: ShoppingCart, titulo: 'Venta de mostrador', clase: 'text-[var(--primary)] bg-pink-50' },
  online_order: { icono: ShoppingCart, titulo: 'Pedido online', clase: 'text-[var(--primary)] bg-pink-50' }
}

/**
 * Cómo llegó esta referencia hasta aquí.
 *
 * Se juntan dos fuentes: el movimiento (que lleva su propia nota y el costo) y,
 * cuando vino de una compra, la orden (que lleva el proveedor y **la nota que
 * escribiste al registrarla**). Sin unir las dos, la nota de la compra no se ve
 * en ninguna parte del panel.
 */
const historial = computed(() => {
  return inventario.movements
    .filter((m) =>
      m.productId === props.fila.productId
      && (m.variantId ?? null) === (props.fila.variantId ?? null)
    )
    .map((m) => {
      const orden = m.referenceType === 'purchase_order'
        ? compras.purchaseOrders.find((o) => o.id === m.referenceId)
        : null
      const estilo = ESTILOS[m.type] || ESTILOS.adjustment
      return {
        id: m.id,
        ...estilo,
        // Una transferencia son dos movimientos; se distingue cuál es cuál.
        titulo: m.type === 'transfer'
          ? (m.quantity < 0 ? 'Salió de bodega a la venta' : 'Entró al inventario de venta')
          : estilo.titulo,
        unidades: m.quantity,
        costo: m.unitCost || 0,
        fecha: m.createdAt,
        notaMovimiento: notaHumana(m.notes),
        orden,
        proveedor: orden?.supplierId ? proveedores.porId(orden.supplierId)?.name || '' : ''
      }
    })
    .sort((a, b) => new Date(b.fecha) - new Date(a.fecha))
})

const compraMasReciente = computed(() => historial.value.find((h) => h.orden))

function fechaLarga(iso) {
  return new Date(iso).toLocaleString('es-CO', {
    day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit'
  })
}
</script>

<template>
  <div class="fixed inset-0 z-50 grid place-items-center p-3 sm:p-5">
    <button class="absolute inset-0 bg-black/45" aria-label="Cerrar" @click="emit('cerrar')"></button>

    <div class="relative flex max-h-[92vh] w-full max-w-3xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
      <!-- Cabecera -->
      <header class="flex items-start gap-4 border-b border-pink-100 p-5">
        <span class="size-16 shrink-0 overflow-hidden rounded-xl bg-pink-50 ring-1 ring-pink-100">
          <img v-if="foto" :src="foto.url" :alt="producto?.name || ''" class="h-full w-full object-cover" />
          <span v-else class="grid h-full place-items-center text-xs text-neutral-400">Sin foto</span>
        </span>

        <div class="min-w-0 flex-1">
          <h3 class="text-lg font-bold leading-tight text-black">{{ producto?.name || 'Producto eliminado' }}</h3>
          <p v-if="tono" class="mt-0.5 flex items-center gap-1.5 text-sm text-neutral-500">
            <span
              v-if="tono.swatchHex"
              class="inline-block size-3.5 shrink-0 rounded-full border border-black/10"
              :style="{ background: tono.swatchHex }"
            />
            Tono {{ tono.name }}
          </p>
          <p class="mt-1.5 flex flex-wrap items-center gap-1.5">
            <span class="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-800">
              {{ fila.quantity }} en bodega
            </span>
            <span
              class="rounded-full px-2 py-0.5 text-xs font-bold"
              :class="producto?.active ? 'bg-emerald-100 text-emerald-700' : 'bg-neutral-200 text-neutral-600'"
            >{{ producto?.active ? 'Publicado' : 'No publicado' }}</span>
          </p>
        </div>

        <button
          class="grid size-10 shrink-0 place-items-center rounded-full text-neutral-400 transition hover:bg-pink-50 hover:text-neutral-700"
          aria-label="Cerrar" @click="emit('cerrar')"
        >
          <X class="size-5" />
        </button>
      </header>

      <div class="min-h-0 flex-1 space-y-5 overflow-y-auto p-5">
        <!-- Números -->
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div class="rounded-xl bg-amber-50 px-3 py-2.5">
            <p class="text-lg font-bold text-amber-700">{{ fila.quantity }}</p>
            <p class="text-xs font-semibold text-amber-700/70">en bodega</p>
          </div>
          <div class="rounded-xl bg-emerald-50 px-3 py-2.5">
            <p class="text-lg font-bold text-emerald-700">{{ fila.saleStock }}</p>
            <p class="text-xs font-semibold text-emerald-700/70">ya en venta</p>
          </div>
          <div class="rounded-xl bg-neutral-100 px-3 py-2.5">
            <p class="text-lg font-bold text-neutral-700">{{ fila.cost ? formatCurrency(fila.cost) : '—' }}</p>
            <p class="text-xs font-semibold text-neutral-500">costo promedio</p>
          </div>
          <div class="rounded-xl bg-pink-50 px-3 py-2.5">
            <p class="text-lg font-bold text-[var(--primary)]">{{ formatCurrency(precioVenta) }}</p>
            <p class="text-xs font-semibold text-[var(--primary)]/70">
              precio de venta<span v-if="heredaPrecio"> (heredado)</span>
            </p>
          </div>
        </div>

        <p v-if="margen !== null" class="rounded-xl bg-white px-3 py-2 text-sm ring-1 ring-pink-100">
          Margen por unidad:
          <strong :class="margen > 0 ? 'text-emerald-700' : 'text-red-600'">
            {{ formatCurrency(precioVenta - fila.cost) }} ({{ margen.toFixed(0) }}%)
          </strong>
          <span class="text-neutral-500">
            · las {{ fila.quantity }} de bodega valen {{ formatCurrency(fila.quantity * fila.cost) }} al costo
          </span>
        </p>

        <!-- La nota, arriba y visible: es lo que se viene a buscar aquí. -->
        <div v-if="compraMasReciente?.orden?.notes" class="rounded-xl bg-sky-50 p-3.5">
          <p class="text-xs font-bold uppercase tracking-wide text-sky-900/60">
            Nota de la compra {{ compraMasReciente.orden.orderNumber }}
          </p>
          <p class="mt-1 text-sm leading-6 text-sky-950">{{ compraMasReciente.orden.notes }}</p>
        </div>

        <!-- Ficha -->
        <section v-if="atributos.length || producto?.description">
          <h4 class="text-sm font-bold text-black">Ficha</h4>
          <dl class="mt-2 grid gap-x-6 gap-y-1.5 sm:grid-cols-2">
            <div v-for="[etiqueta, valor] in atributos" :key="etiqueta" class="flex justify-between gap-3 border-b border-pink-50 py-1.5">
              <dt class="text-sm text-neutral-500">{{ etiqueta }}</dt>
              <dd class="text-right text-sm font-semibold text-neutral-800">{{ valor }}</dd>
            </div>
          </dl>
          <p v-if="producto?.description" class="mt-3 text-sm leading-6 text-neutral-600">
            {{ producto.description }}
          </p>
        </section>

        <!-- Historial -->
        <section>
          <h4 class="text-sm font-bold text-black">Cómo llegó hasta aquí</h4>
          <p class="mt-0.5 text-xs text-neutral-500">
            Cada movimiento de esta referencia, del más reciente al más antiguo.
          </p>

          <ul v-if="historial.length" class="mt-3 space-y-2">
            <li v-for="evento in historial" :key="evento.id" class="flex gap-3 rounded-xl border border-pink-100 p-3">
              <span class="grid size-8 shrink-0 place-items-center rounded-full" :class="evento.clase">
                <component :is="evento.icono" class="size-4" />
              </span>
              <div class="min-w-0 flex-1">
                <div class="flex flex-wrap items-baseline justify-between gap-x-3">
                  <strong class="text-sm text-black">{{ evento.titulo }}</strong>
                  <span
                    class="text-sm font-bold tabular-nums"
                    :class="evento.unidades > 0 ? 'text-emerald-600' : 'text-[var(--primary)]'"
                  >{{ evento.unidades > 0 ? '+' : '' }}{{ evento.unidades }}</span>
                </div>
                <p class="mt-0.5 text-xs text-neutral-400">{{ fechaLarga(evento.fecha) }}</p>

                <p v-if="evento.orden" class="mt-1.5 text-sm text-neutral-600">
                  Orden <strong>{{ evento.orden.orderNumber }}</strong>
                  <template v-if="evento.proveedor"> · {{ evento.proveedor }}</template>
                  <template v-if="evento.costo"> · {{ formatCurrency(evento.costo) }} por unidad</template>
                </p>

                <p
                  v-if="evento.orden?.notes && evento.id !== compraMasReciente?.id"
                  class="mt-1.5 rounded-lg bg-sky-50 px-2.5 py-1.5 text-sm leading-6 text-sky-950"
                >
                  <span class="font-semibold">Nota de la compra:</span> {{ evento.orden.notes }}
                </p>
                <p v-if="evento.notaMovimiento" class="mt-1 text-sm italic leading-6 text-neutral-500">
                  {{ evento.notaMovimiento }}
                </p>
              </div>
            </li>
          </ul>

          <p v-else class="mt-3 rounded-xl border border-dashed border-pink-200 p-5 text-center text-sm text-neutral-500">
            No hay movimientos registrados para esta referencia.
          </p>
        </section>
      </div>

      <!-- Pie -->
      <footer class="flex flex-wrap items-center justify-between gap-2 border-t border-pink-100 bg-pink-50/40 p-4">
        <RouterLink
          v-if="producto"
          :to="`/admin/productos/${producto.id}`"
          class="inline-flex h-11 items-center gap-1.5 rounded-full border border-pink-200 bg-white px-4 text-sm font-bold text-neutral-700 transition hover:border-[var(--primary)] hover:text-[var(--primary)]"
        >
          <ExternalLink class="size-4" /> Editar ficha completa
        </RouterLink>
        <button
          class="inline-flex h-11 items-center gap-1.5 rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
          @click="emit('transferir', fila)"
        >
          <ArrowRightLeft class="size-4" /> Pasar a venta
        </button>
      </footer>
    </div>
  </div>
</template>
