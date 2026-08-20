<script setup>
import { storeToRefs } from 'pinia'
import { useInventoryStore } from '../../../stores/inventory'
import { formatCurrency } from '../../../utils/formatCurrency'

const inventory = useInventoryStore()
const { catalog } = storeToRefs(inventory)

function getSaleItem(productId) {
  return inventory.saleInventory.find((item) => item.productId === productId)
}

function getWarehouseItem(productId) {
  return inventory.warehouse.find((item) => item.productId === productId)
}

function productById(productId) {
  return catalog.value.find((p) => p.id === productId)
}

function moveToSale(productId) {
  const wItem = getWarehouseItem(productId)
  if (!wItem || wItem.quantity <= 0) return
  const quantity = Number(prompt(`¿Cuántas unidades de "${productById(productId)?.name}" quieres pasar a venta? (Disponibles en bodega: ${wItem.quantity})`, wItem.quantity))
  if (!quantity || quantity <= 0 || quantity > wItem.quantity) return
  const success = inventory.moveFromWarehouseToSale(productId, quantity)
  if (!success) alert('No hay suficiente stock en bodega.')
}

function toggleActive(productId) {
  const product = productById(productId)
  if (product) inventory.toggleProductActive(productId, !product.active)
}

function updateSalePrice(productId) {
  const product = productById(productId)
  const current = product?.salePrice || product?.price || 0
  const newPrice = prompt(`Nuevo precio de venta para "${product?.name}":`, current)
  if (newPrice && Number(newPrice) >= 0) {
    inventory.updateSalePrice(productId, Number(newPrice))
  }
}

function getProfit(saleItem, product) {
  const costPrice = saleItem.costPrice || 0
  const salePrice = product?.salePrice || product?.price || 0
  return (salePrice - costPrice) * saleItem.quantity
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Inventario de Venta</h2>
      <p class="mt-1 text-sm text-neutral-500">Productos disponibles para vender. Establece precios, descuentos, gana y administra el stock.</p>
    </div>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-250 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Producto</th>
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
          <tr
            v-for="saleItem in inventory.saleInventory"
            :key="saleItem.id"
            class="border-b border-pink-50 transition hover:bg-pink-50/50"
          >
            <td class="px-5 py-4 font-medium">
              {{ productById(saleItem.productId)?.name || 'Producto eliminado' }}
            </td>
            <td class="px-5 py-4">
              <span class="inline-flex rounded-full bg-pink-100 px-3 py-1 text-xs font-bold text-[var(--primary)]">
                {{ productById(saleItem.productId)?.category }}
              </span>
            </td>
            <td class="px-5 py-4 font-bold" :class="saleItem.quantity ? 'text-emerald-600' : 'text-red-500'">
              {{ saleItem.quantity }}
            </td>
            <td class="px-5 py-4">{{ formatCurrency(saleItem.costPrice || 0) }}</td>
            <td class="px-5 py-4 font-bold text-[var(--primary)]">
              {{ formatCurrency(productById(saleItem.productId)?.salePrice || productById(saleItem.productId)?.price || 0) }}
            </td>
            <td class="px-5 py-4 font-bold text-emerald-600">
              {{ formatCurrency(getProfit(saleItem, productById(saleItem.productId))) }}
            </td>
            <td class="px-5 py-4 font-bold text-amber-600">
              {{ getWarehouseItem(saleItem.productId)?.quantity || 0 }}
            </td>
            <td class="px-5 py-4">
              <span
                class="inline-flex rounded-full px-3 py-1 text-xs font-bold text-white"
                :class="productById(saleItem.productId)?.active === false ? 'bg-neutral-400' : 'bg-emerald-500'"
              >
                {{ productById(saleItem.productId)?.active === false ? 'Pausado' : 'Activo' }}
              </span>
            </td>
            <td class="px-5 py-4">
              <div class="flex flex-wrap gap-1.5">
                <button
                  class="rounded-full bg-[var(--primary)] px-3 py-1.5 text-xs font-bold text-white transition hover:bg-[var(--info)]"
                  @click="updateSalePrice(saleItem.productId)"
                >
                  Precio
                </button>
                <button
                  v-if="getWarehouseItem(saleItem.productId)?.quantity > 0"
                  class="rounded-full bg-amber-500 px-3 py-1.5 text-xs font-bold text-white transition hover:bg-amber-600"
                  @click="moveToSale(saleItem.productId)"
                >
                  Pasar de bodega
                </button>
                <button
                  class="rounded-full px-3 py-1.5 text-xs font-bold text-white transition"
                  :class="productById(saleItem.productId)?.active === false ? 'bg-emerald-500 hover:bg-emerald-600' : 'bg-neutral-400 hover:bg-neutral-500'"
                  @click="toggleActive(saleItem.productId)"
                >
                  {{ productById(saleItem.productId)?.active === false ? 'Activar' : 'Pausar' }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Productos en bodega sin inventario de venta -->
    <div v-if="inventory.warehouse.length" class="rounded-2xl bg-white p-6 shadow-sm">
      <h3 class="text-lg font-bold text-black">Productos en bodega (sin precio asignado)</h3>
      <p class="mt-1 text-sm text-neutral-500">Pásalos al inventario de venta para asignar precio y venderlos.</p>
      <div class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <article v-for="item in inventory.warehouse" :key="item.id" class="rounded-xl border border-pink-100 p-4">
          <p class="font-bold">{{ productById(item.productId)?.name }}</p>
          <p class="mt-1 text-sm text-neutral-500">{{ productById(item.productId)?.category }}</p>
          <div class="mt-3 flex items-center justify-between">
            <span class="text-sm font-bold text-amber-600">Stock: {{ item.quantity }}</span>
            <button
              class="rounded-full bg-[var(--primary)] px-3 py-1.5 text-xs font-bold text-white transition hover:bg-[var(--info)]"
              @click="moveToSale(item.productId)"
            >
              Pasar a venta
            </button>
          </div>
        </article>
      </div>
    </div>
  </div>
</template>