<script setup>
import { computed, reactive, ref } from 'vue'
import { Plus, Pencil, Trash2, ShoppingCart } from 'lucide-vue-next'
import { usePurchasesStore } from '../../../stores/purchases'
import { useSuppliersStore } from '../../../stores/suppliers'
import { useCatalogStore } from '../../../stores/catalog'
import AyudaInfo from '../AyudaInfo.vue'
import { formatCurrency } from '../../../utils/formatCurrency'

/**
 * COMPRAS al proveedor.
 *
 * Dos cambios grandes respecto a la versión anterior:
 *
 *  1. UNA COMPRA PUEDE TENER VARIAS LÍNEAS. Antes el formulario registraba un
 *     producto y cerraba la orden: una factura del proveedor con ocho
 *     productos eran ocho órdenes distintas, y el número de orden dejaba de
 *     servir para nada. Ahora se van añadiendo líneas y se guarda una vez.
 *
 *  2. SE PUEDE CORREGIR. Registrar era un camino de ida, así que un cero de
 *     más en la cantidad quedaba para siempre — y arrastraba el costo
 *     promedio con el que se calcula el margen. Al editar, la base anula lo
 *     que esa orden había metido en bodega y vuelve a meter lo corregido, sin
 *     borrar ni una fila del historial.
 *
 * Lo que NO se puede hacer es bajar una compra por debajo de lo que ya salió
 * de bodega a la vitrina: la base lo rechaza y dice cuál es el mínimo. Tiene
 * que ser así — esas unidades ya se pueden haber vendido.
 */
const store = usePurchasesStore()
const proveedores = useSuppliersStore()
const catalogo = useCatalogStore()

const error = ref('')
const aviso = ref('')
const busy = ref(false)
const abierto = ref(false)

const HOY = () => new Date().toISOString().slice(0, 10)

const form = reactive({
  id: null,
  orderNumber: '',
  supplierId: '',
  date: HOY(),
  notes: '',
  items: []
})

// La línea que se está componiendo antes de añadirla a la orden.
const linea = reactive({ productId: '', variantId: '', quantity: 1, costPrice: 0 })

const productos = computed(() => catalogo.products)
const tonos = computed(() =>
  catalogo.shades.filter((v) => v.productId === Number(linea.productId) && v.isActive !== false)
)

const total = computed(() =>
  form.items.reduce((suma, i) => suma + Number(i.quantity) * Number(i.costPrice), 0)
)

function nombreDe(item) {
  const producto = catalogo.products.find((p) => p.id === Number(item.productId))
  const tono = catalogo.shades.find((v) => v.id === Number(item.variantId))
  if (!producto) return `Producto ${item.productId}`
  return tono ? `${producto.name} — ${tono.name}` : producto.name
}

function nuevaOrden() {
  error.value = ''
  aviso.value = ''
  Object.assign(form, { id: null, orderNumber: '', supplierId: '', date: HOY(), notes: '', items: [] })
  Object.assign(linea, { productId: '', variantId: '', quantity: 1, costPrice: 0 })
  abierto.value = true
}

function editar(orden) {
  error.value = ''
  aviso.value = ''
  Object.assign(form, {
    id: orden.id,
    orderNumber: orden.orderNumber,
    supplierId: orden.supplierId || '',
    date: orden.date || HOY(),
    notes: orden.notes || '',
    // Copia propia: editar la orden de la lista mutaría el estado del store
    // antes de que la base confirme nada.
    items: orden.items.map((i) => ({ ...i }))
  })
  Object.assign(linea, { productId: '', variantId: '', quantity: 1, costPrice: 0 })
  abierto.value = true
}

const lineaInvalida = computed(() => {
  if (!linea.productId) return 'Elige un producto.'

  // LA TRAMPA DEL «PRODUCTO BASE».
  //
  // Si el producto tiene tonos, las unidades pertenecen a un tono concreto:
  // eso es lo que la clienta elige y lo que hay que sacar de la caja al
  // empacar. Unas unidades registradas contra el producto base no pertenecen a
  // ninguno, así que la tienda no las cuenta —suma tono a tono— y el producto
  // aparece «Agotado» teniendo mercancía en la vitrina.
  //
  // Se bloquea aquí, en la puerta por donde entra la mercancía, porque el
  // error solo se nota días después y en la otra punta: en la tienda.
  if (tonos.value.length && !linea.variantId) {
    return 'Este producto tiene tonos: elige de cuál es la compra. Unas unidades sin tono no se las puede llevar nadie.'
  }

  const n = Number(linea.quantity)
  if (!Number.isFinite(n) || n <= 0) return 'La cantidad debe ser mayor a cero.'
  if (!Number.isInteger(n)) return 'No se compran fracciones de unidad.'
  return ''
})

function anadirLinea() {
  if (lineaInvalida.value) return
  const productId = Number(linea.productId)
  const variantId = linea.variantId ? Number(linea.variantId) : null

  // Si ya está esa combinación, se suma en vez de duplicar la fila: la base
  // las agruparía igual, y ver dos líneas iguales confunde al revisar.
  const existente = form.items.find(
    (i) => Number(i.productId) === productId && (i.variantId ?? null) === variantId
  )
  if (existente) {
    existente.quantity = Number(existente.quantity) + Number(linea.quantity)
    existente.costPrice = Number(linea.costPrice) || existente.costPrice
  } else {
    form.items.push({
      productId, variantId,
      quantity: Number(linea.quantity),
      costPrice: Number(linea.costPrice) || 0
    })
  }
  Object.assign(linea, { productId: '', variantId: '', quantity: 1, costPrice: 0 })
}

async function guardar() {
  error.value = ''
  if (!form.items.length) {
    error.value = 'Añade al menos un producto a la compra.'
    return
  }
  busy.value = true
  try {
    await store.savePurchaseOrder({ ...form, supplierId: form.supplierId || null })
    // El formulario se cierra DESPUÉS de que la base confirme.
    aviso.value = form.id
      ? `Compra ${form.orderNumber} corregida. La bodega ya refleja el cambio.`
      : 'Compra registrada y enviada a bodega.'
    abierto.value = false
  } catch (fallo) {
    error.value = fallo.message || 'No se pudo guardar la compra.'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h2 class="flex items-center gap-2 text-xl font-bold text-black">
          Compras al proveedor
          <AyudaInfo
            titulo="Compras"
            texto="Registras lo que le compraste al proveedor: producto, cantidad y lo que te costó. Todo entra a bodega, nunca directo a la vitrina. Si te equivocas, la compra se puede corregir después."
            donde="En ninguna parte de la tienda. De aquí sale el costo promedio con el que Reportes calcula tu margen."
          />
        </h2>
        <p class="mt-1 max-w-2xl text-sm leading-6 text-neutral-500">
          Una compra puede llevar varios productos. Todo lo que registres aquí
          <strong>entra a bodega</strong>; sacarlo a la vitrina es el paso siguiente.
        </p>
      </div>
      <button
        class="inline-flex min-h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="nuevaOrden"
      >
        <Plus class="size-4" /> Registrar compra
      </button>
    </div>

    <p v-if="error && !abierto" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="aviso" class="rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">{{ aviso }}</p>

    <div v-if="store.purchaseOrders.length" class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-150 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Orden</th>
            <th class="px-5 py-4">Fecha</th>
            <th class="px-5 py-4">Proveedor</th>
            <th class="px-5 py-4">Productos</th>
            <th class="px-5 py-4">Total</th>
            <th class="px-5 py-4"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="orden in store.purchaseOrders" :key="orden.id" class="border-b border-pink-50">
            <td class="px-5 py-4 font-semibold">{{ orden.orderNumber }}</td>
            <td class="px-5 py-4 text-neutral-500">{{ orden.date }}</td>
            <td class="px-5 py-4 text-neutral-500">{{ proveedores.porId(orden.supplierId)?.name || 'Sin proveedor' }}</td>
            <td class="px-5 py-4 text-neutral-500">
              {{ orden.items.length }} línea(s) ·
              {{ orden.items.reduce((s, i) => s + i.quantity, 0) }} unidades
            </td>
            <td class="px-5 py-4 font-bold text-[var(--primary)]">{{ formatCurrency(orden.total) }}</td>
            <td class="px-5 py-4">
              <div class="flex justify-end">
                <button
                  class="inline-flex h-10 items-center gap-1.5 rounded-full px-4 text-xs font-bold text-neutral-500 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                  @click="editar(orden)"
                >
                  <Pencil class="size-3.5" /> Corregir
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="rounded-2xl border border-dashed border-pink-200 bg-white p-10 text-center">
      <ShoppingCart class="mx-auto size-8 text-pink-300" />
      <p class="mt-3 font-bold text-neutral-700">Todavía no has registrado ninguna compra</p>
      <p class="mx-auto mt-1 max-w-md text-sm leading-6 text-neutral-500">
        Hasta que no compres mercancía no hay nada que vender: un producto no se puede publicar
        sin unidades en la vitrina.
      </p>
    </div>

    <!-- ================= Formulario ================= -->
    <div v-if="abierto" class="fixed inset-0 z-50 grid place-items-center overflow-y-auto bg-black/40 p-4" @click.self="abierto = false">
      <form class="my-8 w-full max-w-2xl rounded-2xl bg-white p-6 shadow-xl" @submit.prevent="guardar">
        <h3 class="text-lg font-bold text-black">
          {{ form.id ? `Corregir compra ${form.orderNumber}` : 'Registrar compra' }}
        </h3>

        <p v-if="form.id" class="mt-3 rounded-xl bg-amber-50 px-4 py-3 text-xs leading-5 font-semibold text-amber-800">
          Al guardar, la bodega se ajusta a lo que digas aquí. El historial de movimientos
          <strong>no se borra</strong>: queda la entrada original y la corrección, para que se
          pueda ver qué pasó. Si ya pasaste parte de esta mercancía a la vitrina, no podrás
          bajar la cantidad por debajo de lo que sacaste.
        </p>

        <div class="mt-4 grid gap-4 md:grid-cols-3">
          <label class="text-sm font-bold text-neutral-700">Proveedor
            <select v-model="form.supplierId" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal">
              <option value="">Sin proveedor</option>
              <option v-for="p in proveedores.activos" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
          </label>
          <label class="text-sm font-bold text-neutral-700">Fecha
            <input v-model="form.date" type="date" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal" />
          </label>
          <label class="text-sm font-bold text-neutral-700">N.º de factura
            <input v-model="form.orderNumber" placeholder="Opcional" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal" />
          </label>
        </div>

        <!-- Añadir línea -->
        <div class="mt-5 rounded-xl bg-pink-50/60 p-4">
          <p class="text-xs font-bold uppercase tracking-wider text-neutral-500">Añadir producto</p>
          <div class="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <label class="text-xs font-bold text-neutral-700">Producto
              <select v-model="linea.productId" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal">
                <option value="">Seleccionar</option>
                <option v-for="p in productos" :key="p.id" :value="p.id">{{ p.name }}</option>
              </select>
            </label>
            <label class="text-xs font-bold text-neutral-700">Tono
              <select v-model="linea.variantId" :disabled="!tonos.length" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal">
                <option value="">{{ tonos.length ? 'Elige el tono' : 'Sin tonos' }}</option>
                <option v-for="t in tonos" :key="t.id" :value="t.id">{{ t.name }}</option>
              </select>
            </label>
            <label class="text-xs font-bold text-neutral-700">Cantidad
              <input v-model="linea.quantity" type="number" min="1" step="1" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal" />
            </label>
            <label class="text-xs font-bold text-neutral-700">Costo unitario
              <input v-model="linea.costPrice" type="number" min="0" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal" />
            </label>
          </div>
          <div class="mt-3 flex items-center gap-3">
            <button
              type="button" :disabled="Boolean(lineaInvalida)"
              class="inline-flex h-10 items-center gap-1.5 rounded-full bg-white px-4 text-xs font-bold text-[var(--primary)] shadow-sm transition disabled:opacity-40"
              @click="anadirLinea"
            >
              <Plus class="size-3.5" /> Añadir a la compra
            </button>
            <span v-if="lineaInvalida && linea.productId" class="text-xs font-semibold text-amber-700">{{ lineaInvalida }}</span>
          </div>
        </div>

        <!-- Líneas de la orden -->
        <table v-if="form.items.length" class="mt-5 w-full text-sm">
          <thead>
            <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
              <th class="py-2">Producto</th>
              <th class="py-2 w-24">Cantidad</th>
              <th class="py-2 w-32">Costo</th>
              <th class="py-2 w-28">Subtotal</th>
              <th class="py-2 w-10"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, i) in form.items" :key="`${item.productId}-${item.variantId}`" class="border-b border-pink-50">
              <td class="py-2 font-medium">{{ nombreDe(item) }}</td>
              <td class="py-2">
                <input v-model="item.quantity" type="number" min="1" step="1" class="h-9 w-20 rounded-lg border border-pink-100 px-2 text-sm" />
              </td>
              <td class="py-2">
                <input v-model="item.costPrice" type="number" min="0" class="h-9 w-28 rounded-lg border border-pink-100 px-2 text-sm" />
              </td>
              <td class="py-2 font-bold text-[var(--primary)]">{{ formatCurrency(item.quantity * item.costPrice) }}</td>
              <td class="py-2">
                <button
                  type="button" aria-label="Quitar línea" title="Quitar de la compra"
                  class="grid size-9 place-items-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600"
                  @click="form.items.splice(i, 1)"
                >
                  <Trash2 class="size-4" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <p v-else class="mt-5 rounded-xl border border-dashed border-pink-200 p-5 text-center text-sm text-neutral-500">
          La compra todavía no tiene productos.
        </p>

        <label class="mt-5 block text-sm font-bold text-neutral-700">Notas
          <textarea
            v-model="form.notes" rows="2"
            class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 text-sm font-normal"
            placeholder="Lo que quieras recordar de esta compra. Se ve en la ficha del producto en bodega."
          />
        </label>

        <p class="mt-4 text-right text-sm font-bold text-neutral-700">
          Total de la compra: <span class="text-lg text-[var(--primary)]">{{ formatCurrency(total) }}</span>
        </p>

        <p v-if="error" class="mt-4 rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>

        <div class="mt-6 flex gap-2">
          <button
            type="submit" :disabled="busy || !form.items.length"
            class="h-11 flex-1 rounded-full bg-[var(--primary)] text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          >
            {{ busy ? 'Guardando…' : (form.id ? 'Guardar la corrección' : 'Registrar compra') }}
          </button>
          <button type="button" class="h-11 rounded-full border border-pink-200 px-5 text-sm font-bold text-neutral-600" @click="abierto = false">
            Cancelar
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
