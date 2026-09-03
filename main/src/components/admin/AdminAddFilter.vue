<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useInventoryStore } from '../../stores/inventory'

const emit = defineEmits(['save'])
const inventory = useInventoryStore()

const showAddModal = ref(false)
const errorMessage = ref('')
const newProduct = reactive({
  name: '',
  description: '',
  price: '',
  category: '',
  brandId: '',
  skinTypeId: '',
  finishId: '',
  coverageId: '',
  isFeatured: false,
  isNew: true,
  isRecommended: false,
  status: 'active',
  useSkinType: false,
  useFinish: false,
  useCoverage: false,
  useNetContent: false,
  netContentMl: '',
  image: null
})

const selectedCategory = computed(() => newProduct.category.trim().toLowerCase())
const isFacialCare = computed(() => ['cuidado facial', 'skincare'].includes(selectedCategory.value))
const supportsFinish = computed(() => ['bases', 'primer y fijador', 'labios', 'labiales', 'correctores'].includes(selectedCategory.value))
const supportsCoverage = computed(() => selectedCategory.value === 'bases')
const categories = computed(() => inventory.categories.filter((item) => item.active !== false))

onMounted(() => { inventory.init().catch(() => {}) })

function handleImageChange(event) {
  const file = event.target.files[0]
  if (file && file.size > 8 * 1024 * 1024) {
    errorMessage.value = 'El archivo es demasiado grande. El tamaño máximo permitido es 8MB.'
    newProduct.image = null
  } else {
    errorMessage.value = ''
    newProduct.image = file
  }
}

function handleSubmit() {
  if (!newProduct.image) {
    errorMessage.value = 'Por favor, selecciona una imagen.'
    return
  }

  emit('save', {
    ...newProduct,
    categoryId: categories.value.find((category) => category.name === newProduct.category)?.id || '',
    skinTypeId: newProduct.useSkinType ? newProduct.skinTypeId : '',
    finishId: newProduct.useFinish ? newProduct.finishId : '',
    coverageId: newProduct.useCoverage ? newProduct.coverageId : '',
    netContentMl: newProduct.useNetContent ? Number(newProduct.netContentMl) || null : null
  })
  showAddModal.value = false
  newProduct.name = ''
  newProduct.description = ''
  newProduct.price = ''
  newProduct.category = ''
  newProduct.brandId = ''
  newProduct.skinTypeId = ''
  newProduct.finishId = ''
  newProduct.coverageId = ''
  newProduct.isFeatured = false
  newProduct.isNew = true
  newProduct.isRecommended = false
  newProduct.status = 'active'
  newProduct.useSkinType = false
  newProduct.useFinish = false
  newProduct.useCoverage = false
  newProduct.useNetContent = false
  newProduct.netContentMl = ''
  newProduct.image = null
  errorMessage.value = ''
}

function closeModal() {
  showAddModal.value = false
  errorMessage.value = ''
}
</script>

<template>
  <button
    class="inline-flex items-center gap-2 rounded-xl bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
    @click="showAddModal = true"
  >
    <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>
    Añadir
  </button>

  <Teleport to="body">
    <div v-if="showAddModal" class="fixed inset-0 z-100">
      <button class="absolute inset-0 bg-black/45" aria-label="Cerrar modal" @click="closeModal"></button>
      <div class="absolute inset-0 flex items-center justify-center p-4">
        <div class="w-full max-w-lg rounded-3xl bg-white shadow-2xl">
          <header class="flex items-center justify-between border-b border-pink-100 px-6 py-4">
            <h5 class="text-xl font-bold">Añadir Nuevo Producto</h5>
            <button class="rounded-full p-2 text-xl hover:bg-pink-50" aria-label="Cerrar" @click="closeModal">×</button>
          </header>
          <div class="px-6 py-5">
            <p v-if="errorMessage" class="mb-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{{ errorMessage }}</p>
            <form class="space-y-4" @submit.prevent="handleSubmit">
              <div>
                <label class="mb-1 block text-sm font-bold text-neutral-700" for="name">Nombre:</label>
                <input
                  id="name"
                  v-model="newProduct.name"
                  type="text"
                  required
                  class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                />
              </div>
              <div>
                <label class="mb-1 block text-sm font-bold text-neutral-700" for="description">Descripción:</label>
                <textarea
                  id="description"
                  v-model="newProduct.description"
                  required
                  rows="3"
                  class="w-full resize-y rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                ></textarea>
              </div>
              <div class="grid gap-4 sm:grid-cols-2">
                <div>
                  <label class="mb-1 block text-sm font-bold text-neutral-700" for="price">Precio:</label>
                  <input
                    id="price"
                    v-model="newProduct.price"
                    type="number"
                    required
                    min="0"
                    class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                  />
                </div>
              </div>
              <div>
                <label class="mb-1 block text-sm font-bold text-neutral-700" for="category">Categoría:</label>
                <select
                  id="category"
                  v-model="newProduct.category"
                  required
                  class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                >
                  <option value="">Seleccionar categoría</option>
                  <option v-for="category in categories" :key="category.id" :value="category.name">
                    {{ category.name }}
                  </option>
                </select>
              </div>
              <div>
                <label class="mb-1 block text-sm font-bold text-neutral-700" for="image">Imagen:</label>
                <input
                  id="image"
                  type="file"
                  accept="image/*"
                  class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)]"
                  @change="handleImageChange"
                />
              </div>
              <div class="flex justify-end gap-2 pt-2">
                <button type="button" class="rounded-xl border border-pink-200 px-5 py-2.5 text-sm font-bold" @click="closeModal">
                  Cancelar
                </button>
                <button type="submit" class="rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]">
                  Guardar Producto
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>