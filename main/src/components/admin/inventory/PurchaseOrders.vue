<script setup>
import { computed, reactive, ref } from 'vue'
import { useInventoryStore } from '../../../stores/inventory'
import { formatCurrency } from '../../../utils/formatCurrency'

const store = useInventoryStore()
const error = ref('')
const saved = ref(false)
const form = reactive({ supplierId: '', date: new Date().toISOString().slice(0, 10), notes: '', productId: '', variantId: '', quantity: 1, costPrice: 0 })

const products = computed(() => store.catalog)
const variants = computed(() => store.variants.filter((variant) => variant.productId === Number(form.productId) && variant.isActive !== false))
const selectedProduct = computed(() => products.value.find((product) => product.id === Number(form.productId)))

function resetForm() {
  form.supplierId = ''
  form.date = new Date().toISOString().slice(0, 10)
  form.notes = ''
  form.productId = ''
  form.variantId = ''
  form.quantity = 1
  form.costPrice = 0
}

async function submit() {
  error.value = ''
  saved.value = false
  if (!form.productId || !form.quantity || Number(form.quantity) <= 0) {
    error.value = 'Selecciona un producto y una cantidad válida.'
    return
  }

  try {
    await store.addPurchaseOrder({
      supplierId: form.supplierId ? Number(form.supplierId) : null,
      date: form.date,
      notes: form.notes,
      items: [{ productId: Number(form.productId), variantId: form.variantId ? Number(form.variantId) : null, quantity: Number(form.quantity), costPrice: Number(form.costPrice) || 0 }]
    })
    saved.value = true
    resetForm()
  } catch (submitError) {
    error.value = submitError.message || 'No se pudo registrar la compra.'
  }
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Órdenes de compra</h2>
      <p class="mt-1 text-sm text-neutral-500">Registra compras y recibe los productos en bodega.</p>
    </div>

    <form class="rounded-2xl bg-white p-5 shadow-sm" @submit.prevent="submit">
      <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <label class="text-sm font-bold text-neutral-700">Proveedor<select v-model="form.supplierId" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal"><option value="">Sin proveedor</option><option v-for="supplier in store.suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</option></select></label>
        <label class="text-sm font-bold text-neutral-700">Fecha<input v-model="form.date" type="date" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label>
        <label class="text-sm font-bold text-neutral-700">Producto<select v-model="form.productId" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal"><option value="">Seleccionar producto</option><option v-for="product in products" :key="product.id" :value="product.id">{{ product.name }}</option></select></label>
        <label class="text-sm font-bold text-neutral-700">Variante<select v-model="form.variantId" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" :disabled="!variants.length"><option value="">{{ variants.length ? 'Producto base' : 'Sin variantes' }}</option><option v-for="variant in variants" :key="variant.id" :value="variant.id">{{ variant.name }}</option></select></label>
        <label class="text-sm font-bold text-neutral-700">Cantidad<input v-model="form.quantity" type="number" min="1" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label>
        <label class="text-sm font-bold text-neutral-700">Costo unitario<input v-model="form.costPrice" type="number" min="0" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label>
        <label class="text-sm font-bold text-neutral-700 md:col-span-2">Notas<textarea v-model="form.notes" rows="1" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal"></textarea></label>
      </div>
      <p v-if="selectedProduct" class="mt-3 text-xs text-neutral-500">Producto seleccionado: {{ selectedProduct.name }}</p>
      <p v-if="error" class="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{{ error }}</p>
      <p v-if="saved" class="mt-4 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-700">Compra registrada y enviada a bodega.</p>
      <button class="mt-5 rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white hover:bg-[var(--info)]" type="submit">Registrar compra</button>
    </form>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-150 text-sm"><thead><tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500"><th class="px-5 py-4">Orden</th><th class="px-5 py-4">Fecha</th><th class="px-5 py-4">Proveedor</th><th class="px-5 py-4">Total</th></tr></thead><tbody><tr v-for="order in store.purchaseOrders" :key="order.id" class="border-b border-pink-50"><td class="px-5 py-4 font-semibold">{{ order.orderNumber }}</td><td class="px-5 py-4">{{ order.date || order.orderDate }}</td><td class="px-5 py-4">{{ store.suppliers.find((supplier) => supplier.id === order.supplierId)?.name || order.supplier || 'Sin proveedor' }}</td><td class="px-5 py-4 font-bold text-[var(--primary)]">{{ formatCurrency(order.total || order.items?.reduce((sum, item) => sum + item.quantity * item.costPrice, 0) || 0) }}</td></tr></tbody></table>
    </div>
  </div>
</template>
