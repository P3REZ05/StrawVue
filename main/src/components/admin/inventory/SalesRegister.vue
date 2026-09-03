<script setup>
import { computed, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useInventoryStore } from '../../../stores/inventory'
import { formatCurrency } from '../../../utils/formatCurrency'

const inventory = useInventoryStore()
const { catalog } = storeToRefs(inventory)

const cart = ref([])
const paymentMethod = ref('efectivo')
const showModal = ref(false)
const errorMessage = ref('')

const saleProducts = computed(() => {
  return inventory.saleInventory
    .filter((item) => item.quantity > 0)
    .map((item) => {
      const product = catalog.value.find((p) => p.id === item.productId)
      return { ...item, ...product }
    })
    .filter((item) => item.active !== false)
})

const cartTotal = computed(() => {
  return cart.value.reduce((sum, item) => sum + item.price * item.quantity, 0)
})

function productById(productId) {
  return catalog.value.find((p) => p.id === productId)
}

function addToCart(product) {
  const existing = cart.value.find((item) => item.productId === product.productId)
  const saleItem = inventory.saleInventory.find((item) => item.productId === product.productId)
  const maxStock = saleItem?.quantity || 0

  if (existing) {
    if (existing.quantity >= maxStock) {
      errorMessage.value = 'No hay suficiente stock.'
      return
    }
    existing.quantity++
  } else {
    cart.value.push({
      productId: product.productId,
      name: product.name,
      price: product.salePrice || product.price || 0,
      quantity: 1
    })
  }
  errorMessage.value = ''
}

function removeFromCart(index) {
  cart.value.splice(index, 1)
}

function updateCartQuantity(index, delta) {
  const item = cart.value[index]
  const saleItem = inventory.saleInventory.find((s) => s.productId === item.productId)
  const maxStock = saleItem?.quantity || 0

  const newQty = item.quantity + delta
  if (newQty <= 0) {
    cart.value.splice(index, 1)
  } else if (newQty <= maxStock) {
    item.quantity = newQty
  } else {
    errorMessage.value = 'No hay suficiente stock.'
  }
}

function registerSale() {
  if (!cart.value.length) {
    errorMessage.value = 'Agrega productos a la venta.'
    return
  }

  inventory.registerSale({
    date: new Date().toISOString().slice(0, 10),
    items: cart.value.map((item) => ({
      productId: item.productId,
      quantity: item.quantity,
      price: item.price
    })),
    total: cartTotal.value,
    paymentMethod: paymentMethod.value
  })

  cart.value = []
  paymentMethod.value = 'efectivo'
  showModal.value = false
  errorMessage.value = ''
}

function openModal() {
  errorMessage.value = ''
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

    <!-- Historial de ventas -->
    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-200 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">ID</th>
            <th class="px-5 py-4">Fecha</th>
            <th class="px-5 py-4">Productos</th>
            <th class="px-5 py-4">Total</th>
            <th class="px-5 py-4">Método de Pago</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="sale in inventory.sales" :key="sale.id" class="border-b border-pink-50 transition hover:bg-pink-50/50">
            <td class="px-5 py-4 font-semibold">{{ sale.id }}</td>
            <td class="px-5 py-4">{{ sale.date }}</td>
            <td class="px-5 py-4">
              <div class="space-y-1">
                <p v-for="item in sale.items" :key="item.productId" class="text-xs">
                  <strong>{{ productById(item.productId)?.name || 'Producto eliminado' }}</strong> × {{ item.quantity }} — {{ formatCurrency(item.price) }}
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
      <p v-if="!inventory.sales.length" class="p-10 text-center text-neutral-500">No hay ventas registradas.</p>
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
                <div class="grid gap-2 sm:grid-cols-2">
                  <button
                    v-for="product in saleProducts"
                    :key="product.productId"
                    class="flex items-center justify-between rounded-xl border border-pink-100 px-4 py-3 text-left transition hover:border-[var(--primary)] hover:bg-pink-50"
                    @click="addToCart(product)"
                  >
                    <div>
                      <p class="text-sm font-bold">{{ product.name }}</p>
                      <p class="text-xs text-neutral-500">{{ product.category }} · Stock: {{ product.quantity }}</p>
                    </div>
                    <span class="text-sm font-bold text-[var(--primary)]">{{ formatCurrency(product.salePrice || product.price || 0) }}</span>
                  </button>
                </div>
                <p v-if="!saleProducts.length" class="mt-4 text-center text-sm text-neutral-500">No hay productos disponibles para vender.</p>
              </div>

              <!-- Carrito -->
              <div class="flex w-full flex-col sm:w-80">
                <h6 class="mb-3 font-bold text-[var(--primary)]">Carrito</h6>
                <div class="flex-1 space-y-2 overflow-y-auto">
                  <div v-for="(item, index) in cart" :key="item.productId" class="rounded-xl bg-pink-50 p-3">
                    <div class="flex items-center justify-between gap-2">
                      <p class="text-sm font-bold">{{ item.name }}</p>
                      <button class="text-red-500 hover:text-red-700" @click="removeFromCart(index)">×</button>
                    </div>
                    <div class="mt-2 flex items-center justify-between">
                      <div class="flex items-center gap-2">
                        <button class="grid size-6 place-items-center rounded-full border border-pink-200 text-[var(--primary)]" @click="updateCartQuantity(index, -1)">−</button>
                        <span class="w-6 text-center text-sm font-bold">{{ item.quantity }}</span>
                        <button class="grid size-6 place-items-center rounded-full border border-pink-200 text-[var(--primary)]" @click="updateCartQuantity(index, 1)">+</button>
                      </div>
                      <span class="text-sm font-bold">{{ formatCurrency(item.price * item.quantity) }}</span>
                    </div>
                  </div>
                  <p v-if="!cart.length" class="pt-6 text-center text-sm text-neutral-400">Agrega productos al carrito</p>
                </div>

                <div class="mt-4 border-t border-pink-100 pt-4">
                  <div class="flex justify-between text-lg font-bold">
                    <span>Total:</span>
                    <span class="text-[var(--primary)]">{{ formatCurrency(cartTotal) }}</span>
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
                    class="mt-4 w-full rounded-xl bg-[var(--primary)] py-3 text-sm font-bold text-white transition hover:bg-[var(--info)]"
                    :disabled="!cart.length"
                    @click="registerSale"
                  >
                    Registrar Venta
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