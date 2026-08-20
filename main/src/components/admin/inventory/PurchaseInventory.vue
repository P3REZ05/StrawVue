<script setup>
import { ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useInventoryStore } from '../../../stores/inventory'
import { formatCurrency } from '../../../utils/formatCurrency'

const inventory = useInventoryStore()
const { catalog } = storeToRefs(inventory)

const showModal = ref(false)
const editMode = ref(false)
const editingId = ref(null)
const errorMessage = ref('')
const form = ref({ name: '', category: '', description: '' })

function openAdd() {
  editMode.value = false
  editingId.value = null
  form.value = { name: '', category: '', description: '' }
  errorMessage.value = ''
  showModal.value = true
}

function openEdit(product) {
  editMode.value = true
  editingId.value = product.id
  form.value = { name: product.name, category: product.category, description: product.description }
  errorMessage.value = ''
  showModal.value = true
}

function handleSubmit() {
  if (!form.value.name.trim() || !form.value.category.trim()) {
    errorMessage.value = 'Completa el nombre y la categoría del producto.'
    return
  }

  if (editMode.value) {
    inventory.updateProduct(editingId.value, {
      name: form.value.name,
      category: form.value.category,
      description: form.value.description
    })
  } else {
    inventory.addProduct({
      name: form.value.name,
      category: form.value.category,
      description: form.value.description,
      price: 0,
      stock: 0,
      image: '',
      active: true
    })
  }

  showModal.value = false
}

function closeModal() {
  showModal.value = false
  errorMessage.value = ''
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h2 class="text-2xl font-bold text-black">Inventario de Compras</h2>
        <p class="mt-1 text-sm text-neutral-500">Catálogo maestro de productos base. Aquí se crean los productos antes de ser comprados.</p>
      </div>
      <button
        class="inline-flex items-center gap-2 rounded-xl bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="openAdd"
      >
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>
        Nuevo Producto
      </button>
    </div>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-150 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">ID</th>
            <th class="px-5 py-4">Nombre</th>
            <th class="px-5 py-4">Categoría</th>
            <th class="px-5 py-4">Descripción</th>
            <th class="px-5 py-4">Stock Venta</th>
            <th class="px-5 py-4">Stock Bodega</th>
            <th class="px-5 py-4">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="product in inventory.catalogWithStock" :key="product.id" class="border-b border-pink-50 transition hover:bg-pink-50/50">
            <td class="px-5 py-4 font-semibold">{{ product.id }}</td>
            <td class="px-5 py-4 font-medium">{{ product.name }}</td>
            <td class="px-5 py-4">
              <span class="inline-flex rounded-full bg-pink-100 px-3 py-1 text-xs font-bold text-[var(--primary)]">{{ product.category }}</span>
            </td>
            <td class="max-w-60 px-5 py-4 text-neutral-500">{{ product.description || '—' }}</td>
            <td class="px-5 py-4 font-bold text-emerald-600">{{ product.saleStock }}</td>
            <td class="px-5 py-4 font-bold text-amber-600">{{ product.warehouseStock }}</td>
            <td class="px-5 py-4">
              <div class="flex gap-2">
                <button
                  class="grid size-8 place-items-center rounded-full border border-pink-200 text-[var(--primary)] transition hover:bg-pink-50"
                  title="Editar"
                  @click="openEdit(product)"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 3a2.8 2.8 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                </button>
                <button
                  class="grid size-8 place-items-center rounded-full border border-pink-200 text-red-500 transition hover:bg-red-50"
                  title="Eliminar"
                  @click="inventory.deleteProduct(product.id)"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m3 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal Crear/Editar Producto -->
    <Teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-100">
        <button class="absolute inset-0 bg-black/45" aria-label="Cerrar modal" @click="closeModal"></button>
        <div class="absolute inset-0 flex items-center justify-center p-4">
          <div class="w-full max-w-md rounded-3xl bg-white shadow-2xl">
            <header class="flex items-center justify-between border-b border-pink-100 px-6 py-4">
              <h5 class="text-xl font-bold">{{ editMode ? 'Editar Producto' : 'Nuevo Producto' }}</h5>
              <button class="rounded-full p-2 text-xl hover:bg-pink-50" aria-label="Cerrar" @click="closeModal">×</button>
            </header>
            <div class="px-6 py-5">
              <p v-if="errorMessage" class="mb-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{{ errorMessage }}</p>
              <form class="space-y-4" @submit.prevent="handleSubmit">
                <div>
                  <label class="mb-1 block text-sm font-bold text-neutral-700" for="p-name">Nombre del producto:</label>
                  <input
                    id="p-name"
                    v-model="form.name"
                    type="text"
                    class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                    placeholder="Ej: Base líquida Velvet Skin"
                  />
                </div>
                <div>
                  <label class="mb-1 block text-sm font-bold text-neutral-700" for="p-category">Categoría:</label>
                  <input
                    id="p-category"
                    v-model="form.category"
                    type="text"
                    class="w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                    placeholder="Ej: Bases, Labios, Sombras..."
                  />
                </div>
                <div>
                  <label class="mb-1 block text-sm font-bold text-neutral-700" for="p-description">Descripción:</label>
                  <textarea
                    id="p-description"
                    v-model="form.description"
                    rows="3"
                    class="w-full resize-y rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                    placeholder="Descripción del producto..."
                  ></textarea>
                </div>
                <div class="flex justify-end gap-2 pt-2">
                  <button type="button" class="rounded-xl border border-pink-200 px-5 py-2.5 text-sm font-bold" @click="closeModal">Cancelar</button>
                  <button type="submit" class="rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]">
                    {{ editMode ? 'Guardar cambios' : 'Crear producto' }}
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