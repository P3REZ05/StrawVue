<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import AdminAddFilter from './AdminAddFilter.vue'
import AdminFilter from './AdminFilter.vue'
import { useInventoryStore } from '../../stores/inventory'

const inventoryStore = useInventoryStore()
const products = computed(() => inventoryStore.catalogWithStock)
const filteredProducts = ref([])
const showModal = ref(false)
const selectedProduct = ref(null)
const selectedAction = ref(null)
const variantForm = reactive({ name: '', sku: '', price: '', stock: '' })
const variantError = ref('')

const formData = reactive({
  name: '',
  description: '',
  price: '',
  category: '',
  stock: ''
})

onMounted(async () => {
  await inventoryStore.init()
  filteredProducts.value = products.value
})

function handleFilter(criteria) {
  if (!criteria.name && !criteria.category && !criteria.minPrice && !criteria.maxPrice) {
    filteredProducts.value = products.value
    return
  }

  filteredProducts.value = products.value.filter((product) => {
    const nameMatch = !criteria.name || product.name.toLowerCase().includes(criteria.name)
    const categoryMatch = !criteria.category || product.category.toLowerCase().includes(criteria.category)
    const minPriceMatch = !criteria.minPrice || product.price >= criteria.minPrice
    const maxPriceMatch = !criteria.maxPrice || product.price <= criteria.maxPrice
    return nameMatch && categoryMatch && minPriceMatch && maxPriceMatch
  })
}

function handleReset() {
  filteredProducts.value = products.value
}

function handleProductAction(action, product) {
  if (action === 'edit') {
    selectedProduct.value = product
    formData.name = product.name
    formData.description = product.description
    formData.price = product.price
    formData.category = product.category
    formData.stock = product.stock
    showModal.value = true
  } else if (action === 'delete') {
    if (window.confirm('¿Estás seguro de que quieres eliminar este producto?')) {
      filteredProducts.value = filteredProducts.value.filter((p) => p.id !== product.id)
      inventoryStore.deleteProduct(product.id)
    }
  } else if (action === 'toggle') {
    inventoryStore.updateProduct(product.id, { active: !product.active })
  }
  selectedAction.value = null
}

function resetVariantForm() {
  variantForm.name = ''
  variantForm.sku = ''
  variantForm.price = ''
  variantForm.stock = ''
  variantError.value = ''
}

async function addVariant() {
  if (!selectedProduct.value || !variantForm.name.trim()) {
    variantError.value = 'Escribe el nombre o tono de la variante.'
    return
  }

  try {
    await inventoryStore.addVariant(selectedProduct.value.id, variantForm)
    resetVariantForm()
  } catch (error) {
    variantError.value = error.message || 'No se pudo guardar la variante.'
  }
}

async function deactivateVariant(variant) {
  await inventoryStore.deactivateVariant(variant.id)
}

async function handleSaveProduct(newProduct) {
  await inventoryStore.addProduct({
    name: newProduct.name,
    description: newProduct.description,
    price: Number(newProduct.price),
    category: newProduct.category,
    stock: Number(newProduct.stock) || 0,
    image: newProduct.image ? URL.createObjectURL(newProduct.image) : '',
    active: true
  })
  filteredProducts.value = products.value
}

async function handleEditSubmit() {
  if (!selectedProduct.value) return
  await inventoryStore.updateProduct(selectedProduct.value.id, {
    name: formData.name,
    description: formData.description,
    price: Number(formData.price),
    category: formData.category
  })
  showModal.value = false
  selectedProduct.value = null
}

function closeModal() {
  showModal.value = false
  selectedProduct.value = null
  resetVariantForm()
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h2 class="text-2xl font-bold text-black">Productos</h2>
      <AdminAddFilter @save="handleSaveProduct" />
    </div>

    <AdminFilter @filter="handleFilter" @reset="handleReset" />

    <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      <article
        v-for="product in filteredProducts"
        :key="product.id"
        class="group relative overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-pink-100"
      >
        <div class="relative h-56 overflow-hidden bg-pink-50">
          <img
            :src="product.image"
            :alt="product.name"
            class="h-full w-full object-contain p-3"
          />
          <div class="absolute right-3 top-3">
            <div class="relative">
              <button
                class="grid size-9 place-items-center rounded-full bg-white shadow-md transition hover:bg-pink-50"
                aria-label="Acciones del producto"
                @click="selectedAction = selectedAction === product.id ? null : product.id"
              >
                <svg class="size-4" viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/></svg>
              </button>
              <div
                v-if="selectedAction === product.id"
                class="absolute right-0 top-10 z-10 w-40 overflow-hidden rounded-xl bg-white py-1 shadow-xl"
              >
                <button
                  class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                  @click="handleProductAction('edit', product)"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 3a2.8 2.8 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                  Editar
                </button>
                <button
                  class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-red-500"
                  @click="handleProductAction('delete', product)"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m3 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
                  Eliminar
                </button>
                <button
                  class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-neutral-700 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                  @click="handleProductAction('toggle', product)"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path v-if="product.active" d="M10 9l5 3-5 3V9z"/><path v-else d="M10 9l5 3-5 3V9z"/></svg>
                  {{ product.active ? 'Pausar' : 'Activar' }}
                </button>
              </div>
            </div>
          </div>
          <span
            v-if="!product.active"
            class="absolute left-3 top-3 rounded-full bg-amber-400 px-3 py-1 text-xs font-bold text-white"
          >
            Pausado
          </span>
        </div>
        <div class="p-4">
          <h3 class="font-bold text-black">{{ product.name }}</h3>
          <p class="mt-1 line-clamp-2 text-sm text-neutral-500">{{ product.description }}</p>
          <p class="mt-2 text-xs font-semibold text-neutral-500">Categoría: {{ product.category }}</p>
          <p class="mt-1 text-sm font-semibold text-neutral-500">Stock: {{ product.stock }}</p>
          <p class="mt-2 text-lg font-bold text-[var(--primary)]">{{ product.price }}</p>
        </div>
      </article>
    </div>

    <p v-if="!filteredProducts.length" class="rounded-2xl bg-white p-10 text-center text-neutral-500">
      No hay productos que coincidan con los filtros.
    </p>

    <Teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-100">
        <button class="absolute inset-0 bg-black/45" aria-label="Cerrar modal" @click="closeModal"></button>
        <div class="absolute inset-0 flex items-center justify-center p-4">
          <div class="w-full max-w-lg rounded-3xl bg-white shadow-2xl">
            <header class="flex items-center justify-between border-b border-pink-100 px-6 py-4">
              <h5 class="text-xl font-bold">Editar Producto</h5>
              <button class="rounded-full p-2 text-xl hover:bg-pink-50" aria-label="Cerrar" @click="closeModal">×</button>
            </header>
            <div class="px-6 py-5">
              <form class="space-y-4" @submit.prevent="handleEditSubmit">
                <div>
                  <label class="mb-1 block text-sm font-bold text-neutral-700" for="edit-name">Nombre:</label>
                  <input
                    id="edit-name"
                    v-model="formData.name"
                    type="text"
                    required
                    class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                  />
                </div>
                <div>
                  <label class="mb-1 block text-sm font-bold text-neutral-700" for="edit-description">Descripción:</label>
                  <textarea
                    id="edit-description"
                    v-model="formData.description"
                    required
                    rows="3"
                    class="w-full resize-y rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                  ></textarea>
                </div>
                <div class="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label class="mb-1 block text-sm font-bold text-neutral-700" for="edit-price">Precio:</label>
                    <input
                      id="edit-price"
                      v-model="formData.price"
                      type="number"
                      required
                      min="0"
                      class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                    />
                  </div>
                  <div>
                    <label class="mb-1 block text-sm font-bold text-neutral-700" for="edit-stock">Stock:</label>
                    <input
                      id="edit-stock"
                      v-model="formData.stock"
                      type="number"
                      required
                      min="0"
                      class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                    />
                  </div>
                </div>
                <div>
                  <label class="mb-1 block text-sm font-bold text-neutral-700" for="edit-category">Categoría:</label>
                  <input
                    id="edit-category"
                    v-model="formData.category"
                    type="text"
                    required
                    class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                  />
                </div>
                <div class="border-t border-pink-100 pt-4">
                  <div class="flex items-center justify-between gap-3">
                    <div>
                      <h6 class="font-bold text-[var(--primary)]">Variantes</h6>
                      <p class="text-xs text-neutral-500">Tonos o referencias con stock independiente.</p>
                    </div>
                  </div>
                  <div v-if="selectedProduct.variants?.length" class="mt-3 space-y-2">
                    <div v-for="variant in selectedProduct.variants" :key="variant.id" class="flex items-center justify-between rounded-xl bg-pink-50 px-3 py-2 text-sm">
                      <span><strong>{{ variant.name }}</strong><span v-if="variant.sku" class="ml-2 text-xs text-neutral-500">{{ variant.sku }}</span></span>
                      <span class="flex items-center gap-3"><span>{{ variant.stock }} und.</span><button type="button" class="text-xs font-bold text-red-500 hover:underline" @click="deactivateVariant(variant)">Desactivar</button></span>
                    </div>
                  </div>
                  <p v-else class="mt-3 text-sm text-neutral-500">Este producto aún no tiene variantes.</p>
                  <p v-if="variantError" class="mt-3 rounded-xl bg-red-50 p-2 text-xs text-red-600">{{ variantError }}</p>
                  <div class="mt-3 grid gap-2 sm:grid-cols-4">
                    <input v-model="variantForm.name" class="rounded-xl border border-pink-100 px-3 py-2 text-sm" placeholder="Tono / nombre" />
                    <input v-model="variantForm.sku" class="rounded-xl border border-pink-100 px-3 py-2 text-sm" placeholder="SKU" />
                    <input v-model="variantForm.price" type="number" min="0" class="rounded-xl border border-pink-100 px-3 py-2 text-sm" placeholder="Precio" />
                    <input v-model="variantForm.stock" type="number" min="0" class="rounded-xl border border-pink-100 px-3 py-2 text-sm" placeholder="Stock" />
                  </div>
                  <button type="button" class="mt-2 rounded-xl border border-pink-200 px-4 py-2 text-sm font-bold text-[var(--primary)] hover:bg-pink-50" @click="addVariant">Añadir variante</button>
                </div>
                <div class="flex justify-end gap-2 pt-2">
                  <button type="button" class="rounded-xl border border-pink-200 px-5 py-2.5 text-sm font-bold" @click="closeModal">
                    Cancelar
                  </button>
                  <button type="submit" class="rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]">
                    Guardar cambios
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
