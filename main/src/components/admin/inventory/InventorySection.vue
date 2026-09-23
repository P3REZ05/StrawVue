<script setup>
import { computed, ref } from 'vue'
import { ArrowLeft, ArrowRight, Package, ShoppingCart, PackageCheck, Store } from 'lucide-vue-next'
import AdminProductos from '../AdminProductos.vue'
import PurchaseOrders from './PurchaseOrders.vue'
import Warehouse from './Warehouse.vue'
import SaleInventory from './SaleInventory.vue'
import AyudaInfo from '../AyudaInfo.vue'

/**
 * Inventario: el recorrido completo de la mercancía, en orden.
 *
 * Historia de esta pantalla, porque explica por qué está así:
 *
 *   1. Al principio eran tres pestañas en otro orden y una sobraba:
 *      «Inventario de Compras» no era un inventario, era el catálogo otra vez
 *      con un creador recortado que paría productos sin precio ni fotos. Se
 *      eliminó.
 *   2. La bodega no tenía pantalla: vivía como una rejilla al final de
 *      «Inventario de Venta», que es el paso siguiente. Se le dio la suya.
 *   3. Y quedaba el salto que seguía sin explicarse: **Productos era una
 *      sección aparte del menú**, así que crear un producto y meterlo en
 *      inventario parecían dos tareas distintas cuando son la misma, en
 *      orden. Ahora Productos es la parada 1 y el recorrido se lee entero:
 *
 *        1 Productos → 2 Compras → 3 Bodega → 4 Listo para vender
 *
 * Las flechas de abajo existen por lo mismo: el recorrido es de izquierda a
 * derecha y hasta ahora había que volver arriba a buscar la siguiente pestaña.
 */
const PASOS = [
  {
    id: 'productos',
    label: 'Productos',
    icono: Package,
    pie: 'La ficha: nombre, precio, tonos y fotos. Todavía no hay unidades.',
    ayuda: 'Aquí se crea la ficha del producto. Crear un producto NO crea existencias: nace en borrador, con stock cero, y la clienta no lo ve. Las unidades entran en el paso 2.',
    donde: 'Nada de este paso llega a la tienda hasta que el producto se publica, y publicar exige haber llegado al paso 4.'
  },
  {
    id: 'compras',
    label: 'Compras',
    icono: ShoppingCart,
    pie: 'Lo que le compras al proveedor. Entra a bodega.',
    ayuda: 'Registras lo que compraste: producto, cantidad y lo que te costó. Es la única puerta por la que entra mercancía nueva, y de aquí sale el costo promedio con el que se calcula tu margen en Reportes.',
    donde: 'En ninguna parte de la tienda. La clienta nunca ve lo que pagaste.'
  },
  {
    id: 'bodega',
    label: 'Bodega',
    icono: PackageCheck,
    pie: 'Lo que tienes guardado. El cliente todavía no lo ve.',
    ayuda: 'Lo recibido y todavía no puesto a la venta. Puedes sacar solo una parte: compras cien y pones veinte en la vitrina, y las otras ochenta esperan aquí.',
    donde: 'En ninguna parte de la tienda. La bodega es tuya.'
  },
  {
    id: 'venta',
    label: 'Listo para vender',
    icono: Store,
    pie: 'Lo que el cliente puede comprar ahora.',
    ayuda: 'La vitrina. Estas son las unidades que la clienta puede comprar y el precio al que las compra. Un producto solo se puede publicar cuando tiene unidades aquí.',
    donde: 'El stock de la ficha del producto y el botón «Agregar al carrito» de la tienda.'
  }
]

const activo = ref('productos')

const indice = computed(() => PASOS.findIndex((p) => p.id === activo.value))
const pasoActual = computed(() => PASOS[indice.value])
const anterior = computed(() => PASOS[indice.value - 1] || null)
const siguiente = computed(() => PASOS[indice.value + 1] || null)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h2 class="text-2xl font-bold text-black">Inventario</h2>
      <p class="mt-1 max-w-3xl text-sm leading-6 text-neutral-500">
        Todo el recorrido, en orden: se crea la ficha, se le compra al proveedor, entra a bodega
        y de ahí sale a la vitrina. El stock nunca se escribe a mano — sale del historial de
        movimientos.
      </p>
    </div>

    <!-- Las pestañas llevan número y una línea de qué es cada parada: el
         recorrido se lee sin tener que recordarlo. -->
    <div class="flex flex-wrap gap-2">
      <button
        v-for="(paso, i) in PASOS"
        :key="paso.id"
        class="inline-flex min-h-11 items-center gap-2.5 rounded-xl px-4 py-2.5 text-sm font-bold transition"
        :class="activo === paso.id
          ? 'bg-[var(--primary)] text-white shadow-md'
          : 'bg-white text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
        @click="activo = paso.id"
      >
        <span
          class="grid size-5 shrink-0 place-items-center rounded-full text-xs"
          :class="activo === paso.id ? 'bg-white/25 text-white' : 'bg-pink-100 text-[var(--primary)]'"
        >{{ i + 1 }}</span>
        <component :is="paso.icono" class="size-4" />
        {{ paso.label }}
      </button>
    </div>

    <div class="-mt-1 flex items-start justify-between gap-3">
      <p class="text-xs leading-5 text-neutral-500">{{ pasoActual.pie }}</p>
      <AyudaInfo
        :titulo="`Paso ${indice + 1}: ${pasoActual.label}`"
        :texto="pasoActual.ayuda"
        :donde="pasoActual.donde"
      />
    </div>

    <AdminProductos v-if="activo === 'productos'" />
    <PurchaseOrders v-else-if="activo === 'compras'" />
    <Warehouse v-else-if="activo === 'bodega'" />
    <SaleInventory v-else @ir-a-bodega="activo = 'bodega'" />

    <nav class="flex items-center justify-between gap-3 border-t border-pink-100 pt-5">
      <button
        v-if="anterior"
        class="inline-flex min-h-11 items-center gap-2 rounded-full bg-white px-5 text-sm font-bold text-neutral-600 shadow-sm transition hover:text-[var(--primary)]"
        @click="activo = anterior.id"
      >
        <ArrowLeft class="size-4" /> {{ anterior.label }}
      </button>
      <span v-else />

      <button
        v-if="siguiente"
        class="inline-flex min-h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="activo = siguiente.id"
      >
        {{ siguiente.label }} <ArrowRight class="size-4" />
      </button>
      <span v-else class="text-xs text-neutral-500">Fin del recorrido. Lo que está aquí, la clienta lo puede comprar.</span>
    </nav>
  </div>
</template>
