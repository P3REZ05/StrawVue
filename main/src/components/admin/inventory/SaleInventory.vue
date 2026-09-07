<script setup>
import { computed, ref } from 'vue'
import { useInventoryStore } from '../../../stores/inventory'
import { formatCurrency } from '../../../utils/formatCurrency'

const inventory = useInventoryStore()
const error = ref('')
const busy = ref(false)

function productById(productId) {
  return inventory.catalog.find((product) => product.id === productId)
}

function variantById(variantId) {
  return variantId ? inventory.variants.find((variant) => variant.id === variantId) : null
}

// Las filas salen de `balances`, que es lo que dice la base. Antes se leía una
// copia local que solo conocía el producto, así que las variantes quedaban
// invisibles y sus existencias no se podían transferir nunca.
function buildRows(campo) {
  return inventory.balances
    .filter((balance) => Number(balance[campo]) > 0)
    .map((balance) => {
      const product = productById(balance.productId)
      const variant = variantById(balance.variantId)
      return {
        key: `${balance.productId}-${balance.variantId ?? 'base'}`,
        productId: balance.productId,
        variantId: balance.variantId ?? null,
        name: product?.name || 'Producto eliminado',
        variantName: variant?.name || '',
        category: product?.category || '',
        active: product?.active !== false,
        quantity: Number(balance[campo]) || 0,
        warehouseStock: Number(balance.warehouseStock) || 0,
        cost: inventory.getAverageCost(balance.productId, balance.variantId ?? null),
        price: variant?.price || product?.salePrice || product?.price || 0
      }
    })
    .sort((a, b) => a.name.localeCompare(b.name))
}

const saleRows = computed(() => buildRows('saleStock'))
const warehouseRows = computed(() => buildRows('warehouseStock'))

function profit(row) {
  return (row.price - row.cost) * row.quantity
}

async function moveToSale(row) {
  error.value = ''
  const etiqueta = row.variantName ? `${row.name} — ${row.variantName}` : row.name
  const answer = prompt(
    `¿Cuántas unidades de "${etiqueta}" quieres pasar a venta? (En bodega: ${row.warehouseStock})`,
    row.warehouseStock
  )
  if (answer === null) return

  const quantity = Number(answer)
  if (!Number.isFinite(quantity) || quantity <= 0) {
    error.value = 'La cantidad debe ser un número mayor a cero.'
    return
  }

  busy.value = true
  try {
    await inventory.moveFromWarehouseToSale(row.productId, quantity, row.variantId)
  } catch (transferError) {
    // Antes esto se ignoraba: la función es asíncrona y el componente
    // comprobaba el valor de retorno como si fuera síncrono, así que el
    // error nunca llegaba a la pantalla.
    error.value = transferError.message || 'No se pudo transferir el inventario.'
  } finally {
    busy.value = false
  }
}

async function toggleActive(row) {
  const product = productById(row.productId)
  if (product) await inventory.toggleProductActive(row.productId, !product.active)
}

async function updateSalePrice(row) {
  const answer = prompt(`Nuevo precio de venta para "${row.name}":`, row.price)
  if (answer === null) return
  const newPrice = Number(answer)
  if (!Number.isFinite(newPrice) || newPrice < 0) {
    error.value = 'El precio debe ser un número válido.'
    return
  }
  await inventory.updateSalePrice(row.productId, newPrice)
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Inventario de Venta</h2>
      <p class="mt-1 text-sm text-neutral-500">
        Existencias disponibles para vender, derivadas del historial de movimientos.
        El costo es el promedio ponderado de las compras.
      </p>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>

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
          <tr v-for="row in saleRows" :key="row.key" class="border-b border-pink-50 transition hover:bg-pink-50/50">
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
                  @click="updateSalePrice(row)"
                >
                  Precio
                </button>
                <button
                  v-if="row.warehouseStock > 0"
                  :disabled="busy"
                  class="rounded-full bg-amber-500 px-3 py-1.5 text-xs font-bold text-white transition hover:bg-amber-600 disabled:opacity-50"
                  @click="moveToSale(row)"
                >
                  Pasar de bodega
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
          <tr v-if="!saleRows.length">
            <td colspan="10" class="p-10 text-center text-neutral-500">
              Todavía no hay existencias en venta. Registra una compra y pasa unidades desde bodega.
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="warehouseRows.length" class="rounded-2xl bg-white p-6 shadow-sm">
      <h3 class="text-lg font-bold text-black">En bodega</h3>
      <p class="mt-1 text-sm text-neutral-500">
        Unidades recibidas que aún no están a la venta. El cliente no las ve hasta que las transfieras.
      </p>
      <div class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <article v-for="row in warehouseRows" :key="row.key" class="rounded-xl border border-pink-100 p-4">
          <p class="font-bold">{{ row.name }}</p>
          <p class="mt-1 text-sm text-neutral-500">{{ row.variantName || row.category }}</p>
          <div class="mt-3 flex items-center justify-between">
            <span class="text-sm font-bold text-amber-600">Bodega: {{ row.quantity }}</span>
            <button
              :disabled="busy"
              class="rounded-full bg-[var(--primary)] px-3 py-1.5 text-xs font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
              @click="moveToSale(row)"
            >
              Pasar a venta
            </button>
          </div>
        </article>
      </div>
    </div>
  </div>
</template>
