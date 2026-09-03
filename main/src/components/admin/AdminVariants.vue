<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useInventoryStore } from '../../stores/inventory'

const inventory = useInventoryStore()
const form = reactive({ productId: '', name: '', sku: '', price: '' })
const errorMessage = ref('')
const saved = ref(false)

const activeVariants = computed(() => inventory.variants.filter((variant) => variant.isActive !== false))

onMounted(() => { inventory.init().catch(() => {}) })

function resetForm() {
  form.productId = ''
  form.name = ''
  form.sku = ''
  form.price = ''
}

async function addVariant() {
  errorMessage.value = ''
  saved.value = false
  if (!form.productId || !form.name.trim()) {
    errorMessage.value = 'Selecciona un producto y escribe el nombre de la variante.'
    return
  }

  try {
    await inventory.addVariant(Number(form.productId), form)
    saved.value = true
    resetForm()
  } catch (error) {
    errorMessage.value = error.message || 'No se pudo crear la variante.'
  }
}

async function deactivate(variant) {
  try {
    await inventory.deactivateVariant(variant.id)
  } catch (error) {
    errorMessage.value = error.message || 'No se pudo desactivar la variante.'
  }
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Variantes</h2>
      <p class="mt-1 text-sm text-neutral-500">Administra tonos y referencias. El stock se registra desde Compras.</p>
    </div>

    <form class="rounded-2xl bg-white p-5 shadow-sm" @submit.prevent="addVariant">
      <div class="grid gap-4 md:grid-cols-4">
        <label class="text-sm font-bold text-neutral-700">Producto<select v-model="form.productId" required class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal"><option value="">Seleccionar producto</option><option v-for="product in inventory.catalog" :key="product.id" :value="product.id">{{ product.name }}</option></select></label>
        <label class="text-sm font-bold text-neutral-700">Nombre o tono<input v-model="form.name" required class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" placeholder="Tono 01" /></label>
        <label class="text-sm font-bold text-neutral-700">SKU<input v-model="form.sku" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" placeholder="BASE-01" /></label>
        <label class="text-sm font-bold text-neutral-700">Precio<input v-model="form.price" type="number" min="0" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label>
      </div>
      <p v-if="errorMessage" class="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{{ errorMessage }}</p>
      <p v-if="saved" class="mt-4 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-700">Variante creada correctamente.</p>
      <button class="mt-5 rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white hover:bg-[var(--info)]" type="submit">Agregar variante</button>
    </form>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-150 text-sm">
        <thead><tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500"><th class="px-5 py-4">Producto</th><th class="px-5 py-4">Variante</th><th class="px-5 py-4">SKU</th><th class="px-5 py-4">Precio</th><th class="px-5 py-4">Acción</th></tr></thead>
        <tbody>
          <tr v-for="variant in activeVariants" :key="variant.id" class="border-b border-pink-50">
            <td class="px-5 py-4">{{ inventory.catalog.find((product) => product.id === variant.productId)?.name || 'Producto eliminado' }}</td>
            <td class="px-5 py-4 font-medium">{{ variant.name }}</td>
            <td class="px-5 py-4 text-neutral-500">{{ variant.sku || '—' }}</td>
            <td class="px-5 py-4 font-bold text-[var(--primary)]">{{ variant.price || '—' }}</td>
            <td class="px-5 py-4"><button class="rounded-lg border border-red-200 px-3 py-1.5 text-xs font-bold text-red-500 hover:bg-red-50" @click="deactivate(variant)">Desactivar</button></td>
          </tr>
          <tr v-if="!activeVariants.length"><td colspan="5" class="px-5 py-10 text-center text-neutral-500">No hay variantes activas.</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
