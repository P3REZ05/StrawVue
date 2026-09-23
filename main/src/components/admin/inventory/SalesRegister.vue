<script setup>
import { computed, ref } from 'vue'
import { useInventoryStore } from '../../../stores/inventory'
import { usePosStore } from '../../../stores/pos'
import { useCatalogStore } from '../../../stores/catalog'
import { formatCurrency } from '../../../utils/formatCurrency'

const inventory = useInventoryStore()   // saldos: qué hay para vender
const pos = usePosStore()               // la venta en sí
const catalogo = useCatalogStore()

const cart = ref([])
const paymentMethod = ref('efectivo')
const customerName = ref('')
const notes = ref('')
const showModal = ref(false)
const errorMessage = ref('')
const aviso = ref('')
const guardando = ref(false)

// Lo vendible sale de `balances`, una fila por producto **y por tono**.
// Antes salía de `saleInventory`, que solo conoce el producto: con un
// catálogo de tonos, el mostrador no podía decir cuál se llevó el cliente y
// el movimiento de stock caía sobre el producto en vez del tono.
const disponibles = computed(() => {
  return inventory.balances
    .filter((b) => Number(b.saleStock) > 0)
    .map((b) => {
      const producto = catalogo.productById(b.productId)
      const tono = b.variantId ? catalogo.shades.find((t) => t.id === b.variantId) : null

      // El precio que se muestra tiene que ser el que va a cobrar el servidor.
      // `precio_efectivo()` aplica la promoción vigente, así que si aquí se
      // pintara el precio de lista, la caja diría $37.900 y el recibo saldría
      // por $30.320. Las vistas de vitrina ya traen ese cálculo hecho.
      const vitrina = tono
        ? catalogo.storefrontShades.find((f) => f.variant_id === tono.id)
        : catalogo.storefrontProducts.find((f) => f.product_id === b.productId)

      const lista = tono ? catalogo.precioDeTono(tono) : (producto?.salePrice ?? producto?.price ?? 0)
      const efectivo = vitrina ? Number(vitrina.effective_price) : lista

      return {
        key: `${b.productId}-${b.variantId ?? 'base'}`,
        productId: b.productId,
        variantId: b.variantId ?? null,
        nombre: producto?.name || 'Producto eliminado',
        tono: tono?.name || '',
        swatchHex: tono?.swatchHex || '',
        categoria: producto?.category || '',
        stock: Number(b.saleStock),
        precio: efectivo,
        precioLista: lista,
        enPromocion: efectivo < lista,
        promoLabel: vitrina?.promo_label || ''
      }
    })
    .sort((a, b) => a.nombre.localeCompare(b.nombre) || a.tono.localeCompare(b.tono))
})

const busqueda = ref('')
const filtrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  if (!q) return disponibles.value
  return disponibles.value.filter((d) => `${d.nombre} ${d.tono} ${d.categoria}`.toLowerCase().includes(q))
})

// El total que se muestra es una estimación con los precios que la interfaz
// conoce. El que manda es el que calcula el servidor, y se enseña al confirmar.
const cartTotal = computed(() => cart.value.reduce((sum, i) => sum + i.precio * i.quantity, 0))
const hayPromo = computed(() => cart.value.some((i) => i.enPromocion))

function etiqueta(item) {
  return item.tono ? `${item.nombre} — ${item.tono}` : item.nombre
}

function addToCart(fila) {
  errorMessage.value = ''
  const existente = cart.value.find((i) => i.key === fila.key)
  if (existente) {
    if (existente.quantity >= fila.stock) {
      errorMessage.value = `Solo hay ${fila.stock} de ${etiqueta(fila)}.`
      return
    }
    existente.quantity += 1
    return
  }
  cart.value.push({ ...fila, quantity: 1 })
}

function removeFromCart(index) {
  cart.value.splice(index, 1)
}

function updateCartQuantity(index, delta) {
  errorMessage.value = ''
  const item = cart.value[index]
  const nueva = item.quantity + delta
  if (nueva <= 0) {
    cart.value.splice(index, 1)
    return
  }
  const disponible = disponibles.value.find((d) => d.key === item.key)?.stock ?? 0
  if (nueva > disponible) {
    errorMessage.value = `Solo hay ${disponible} de ${etiqueta(item)}.`
    return
  }
  item.quantity = nueva
}

/**
 * Registra la venta y **espera** el resultado.
 *
 * La versión anterior no era `async` y no hacía `await`: vaciaba el carrito y
 * cerraba el modal antes de saber si la venta se había guardado. Con el store
 * tragándose los errores, una venta perdida se veía igual que una venta
 * correcta. Ahora el carrito solo se vacía si el servidor devolvió un número
 * de venta.
 */
async function registerSale() {
  if (!cart.value.length) {
    errorMessage.value = 'Agrega productos a la venta.'
    return
  }

  guardando.value = true
  errorMessage.value = ''
  try {
    const venta = await pos.registerSale({
      items: cart.value.map((i) => ({ productId: i.productId, variantId: i.variantId, quantity: i.quantity })),
      paymentMethod: paymentMethod.value,
      customerName: customerName.value,
      notes: notes.value
    })

    aviso.value = `Venta ${venta.sale_number} registrada por ${formatCurrency(venta.total)} (${venta.unidades} unidad(es)).`
    cart.value = []
    customerName.value = ''
    notes.value = ''
    paymentMethod.value = 'efectivo'
    showModal.value = false
  } catch (fallo) {
    // El carrito se queda como estaba: si faltó stock, se corrige la cantidad
    // y se reintenta sin volver a teclear la venta entera.
    errorMessage.value = fallo.message || 'No se pudo registrar la venta.'
  } finally {
    guardando.value = false
  }
}

// El historial guarda producto y tono por id; el nombre sale del catálogo
// actual para que un renombrado no deje líneas ilegibles.
function nombreDeLinea(item) {
  const producto = catalogo.productById(item.productId)
  const tono = item.variantId ? catalogo.shades.find((t) => t.id === item.variantId) : null
  if (!producto) return 'Producto eliminado'
  return tono ? `${producto.name} — ${tono.name}` : producto.name
}

function openModal() {
  errorMessage.value = ''
  aviso.value = ''
  busqueda.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  errorMessage.value = ''
}
</script>

<template>
  <div class="w-full space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h2 class="text-2xl font-bold text-black">Ventas (POS Físico)</h2>
        <p class="mt-1 text-sm text-neutral-500">Registra ventas en tienda física. El stock del inventario de venta se descuenta automáticamente.</p>
      </div>
      <button
        class="inline-flex items-center gap-2 rounded-xl bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="openModal"
      >
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 4h2l2.2 11.1a2 2 0 0 0 2 1.6h7.6a2 2 0 0 0 2-1.6L20 8H7"/><circle cx="10" cy="20" r="1"/><circle cx="17" cy="20" r="1"/></svg>
        Nueva Venta
      </button>
    </div>

    <p v-if="aviso" class="rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">{{ aviso }}</p>

    <!-- Historial de ventas -->
    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-200 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Venta</th>
            <th class="px-5 py-4">Fecha</th>
            <th class="px-5 py-4">Productos</th>
            <th class="px-5 py-4">Total</th>
            <th class="px-5 py-4">Método de Pago</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="sale in pos.sales" :key="sale.id" class="border-b border-pink-50 transition hover:bg-pink-50/50">
            <td class="px-5 py-4 font-semibold">{{ sale.number }}</td>
            <td class="px-5 py-4">{{ sale.date || '—' }}</td>
            <td class="px-5 py-4">
              <div class="space-y-1">
                <p v-for="(item, i) in sale.items" :key="`${sale.id}-${i}`" class="text-xs">
                  <strong>{{ nombreDeLinea(item) }}</strong> × {{ item.quantity }} — {{ formatCurrency(item.price) }}
                </p>
              </div>
            </td>
            <td class="px-5 py-4 font-bold text-[var(--primary)]">{{ formatCurrency(sale.total) }}</td>
            <td class="px-5 py-4">
              <span class="inline-flex rounded-full bg-pink-100 px-3 py-1 text-xs font-bold capitalize text-[var(--primary)]">
                {{ sale.paymentMethod }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!pos.sales.length" class="p-10 text-center text-neutral-500">No hay ventas registradas.</p>
    </div>

    <!-- Modal Nueva Venta -->
    <Teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-100">
        <button class="absolute inset-0 bg-black/45" aria-label="Cerrar modal" @click="closeModal"></button>
        <div class="absolute inset-0 flex items-center justify-center p-4">
          <div class="flex h-full max-h-150 w-full max-w-4xl flex-col rounded-3xl bg-white shadow-2xl">
            <header class="flex items-center justify-between border-b border-pink-100 px-6 py-4">
              <h5 class="text-xl font-bold">Nueva Venta</h5>
              <button class="rounded-full p-2 text-xl hover:bg-pink-50" aria-label="Cerrar" @click="closeModal">×</button>
            </header>

            <div class="flex flex-1 flex-col gap-4 overflow-hidden p-6 sm:flex-row">
              <!-- Productos disponibles -->
              <div class="flex-1 overflow-y-auto pr-2">
                <h6 class="mb-3 font-bold text-[var(--primary)]">Productos disponibles</h6>
                <input
                  v-model="busqueda"
                  type="search"
                  placeholder="Buscar producto o tono"
                  class="mb-3 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]"
                />
                <div class="grid gap-2 sm:grid-cols-2">
                  <button
                    v-for="fila in filtrados"
                    :key="fila.key"
                    class="flex items-center justify-between gap-2 rounded-xl border border-pink-100 px-4 py-3 text-left transition hover:border-[var(--primary)] hover:bg-pink-50"
                    @click="addToCart(fila)"
                  >
                    <div class="flex min-w-0 items-center gap-2">
                      <span
                        v-if="fila.swatchHex"
                        class="size-6 shrink-0 rounded-full ring-1 ring-black/10"
                        :style="{ background: fila.swatchHex }"
                      ></span>
                      <div class="min-w-0">
                        <p class="truncate text-sm font-bold">{{ fila.nombre }}</p>
                        <p class="truncate text-xs text-neutral-500">
                          <span v-if="fila.tono" class="font-semibold text-neutral-600">{{ fila.tono }} · </span>Stock: {{ fila.stock }}
                        </p>
                      </div>
                    </div>
                    <span class="shrink-0 text-right">
                      <span class="block text-sm font-bold text-[var(--primary)]">{{ formatCurrency(fila.precio) }}</span>
                      <span v-if="fila.enPromocion" class="block text-xs text-neutral-400 line-through">{{ formatCurrency(fila.precioLista) }}</span>
                    </span>
                  </button>
                </div>
                <p v-if="!filtrados.length" class="mt-4 text-center text-sm text-neutral-500">
                  {{ busqueda ? 'Nada coincide con la búsqueda.' : 'No hay existencias en el inventario de venta.' }}
                </p>
              </div>

              <!-- Carrito -->
              <div class="flex w-full flex-col sm:w-80">
                <h6 class="mb-3 font-bold text-[var(--primary)]">Carrito</h6>
                <div class="flex-1 space-y-2 overflow-y-auto">
                  <div v-for="(item, index) in cart" :key="item.key" class="rounded-xl bg-pink-50 p-3">
                    <div class="flex items-center justify-between gap-2">
                      <p class="text-sm font-bold">{{ etiqueta(item) }}</p>
                      <button class="text-red-500 hover:text-red-700" @click="removeFromCart(index)">×</button>
                    </div>
                    <div class="mt-2 flex items-center justify-between">
                      <div class="flex items-center gap-2">
                        <button class="grid size-6 place-items-center rounded-full border border-pink-200 text-[var(--primary)]" @click="updateCartQuantity(index, -1)">−</button>
                        <span class="w-6 text-center text-sm font-bold">{{ item.quantity }}</span>
                        <button class="grid size-6 place-items-center rounded-full border border-pink-200 text-[var(--primary)]" @click="updateCartQuantity(index, 1)">+</button>
                      </div>
                      <span class="text-sm font-bold">{{ formatCurrency(item.precio * item.quantity) }}</span>
                    </div>
                  </div>
                  <p v-if="!cart.length" class="pt-6 text-center text-sm text-neutral-400">Agrega productos al carrito</p>
                </div>

                <div class="mt-4 border-t border-pink-100 pt-4">
                  <div class="flex justify-between text-lg font-bold">
                    <span>Total:</span>
                    <span class="text-[var(--primary)]">{{ formatCurrency(cartTotal) }}</span>
                  </div>
                  <p v-if="hayPromo" class="mt-1 text-xs font-semibold text-emerald-600">
                    Incluye promoción vigente. Se cobra el mismo precio que en la tienda.
                  </p>
                  <p class="mt-1 text-xs text-neutral-400">El importe final lo confirma el servidor al registrar.</p>
                  <div class="mt-3 grid gap-2">
                    <input v-model="customerName" type="text" maxlength="80" placeholder="Cliente (opcional)"
                           class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]" />
                    <input v-model="notes" type="text" maxlength="120" placeholder="Nota (opcional)"
                           class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]" />
                  </div>
                  <div class="mt-3">
                    <label class="mb-1 block text-sm font-bold text-neutral-700" for="payment-method">Método de pago:</label>
                    <select
                      id="payment-method"
                      v-model="paymentMethod"
                      class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]"
                    >
                      <option value="efectivo">Efectivo</option>
                      <option value="tarjeta">Tarjeta</option>
                      <option value="transferencia">Transferencia</option>
                      <option value="nequi">Nequi</option>
                      <option value="daviplata">Daviplata</option>
                    </select>
                  </div>
                  <p v-if="errorMessage" class="mt-3 rounded-xl bg-red-50 p-3 text-sm text-red-600">{{ errorMessage }}</p>
                  <button
                    class="mt-4 w-full rounded-xl bg-[var(--primary)] py-3 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
                    :disabled="!cart.length || guardando"
                    @click="registerSale"
                  >
                    {{ guardando ? 'Registrando…' : 'Registrar Venta' }}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>