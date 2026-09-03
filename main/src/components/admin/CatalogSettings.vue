<script setup>
import { computed, onMounted, ref } from 'vue'
import { useInventoryStore } from '../../stores/inventory'

const inventory = useInventoryStore()
const activeTab = ref('categories')
const formName = ref('')
const parentId = ref('')
const errorMessage = ref('')
const tabs = [
  { id: 'categories', label: 'Categorías' },
  { id: 'brands', label: 'Marcas' },
  { id: 'skinTypes', label: 'Tipos de piel' },
  { id: 'finishes', label: 'Acabados' },
  { id: 'coverages', label: 'Coberturas' }
]

const currentOptions = computed(() => inventory[activeTab.value] || [])
const categoryOptions = computed(() => inventory.categories.filter((item) => !item.parentId))

onMounted(() => { inventory.init().catch(() => {}) })

function resetForm() {
  formName.value = ''
  parentId.value = ''
  errorMessage.value = ''
}

function selectTab(tab) {
  activeTab.value = tab
  resetForm()
}

async function save() {
  errorMessage.value = ''
  try {
    if (activeTab.value === 'categories') {
      await inventory.saveCategory({ name: formName.value, parentId: parentId.value ? Number(parentId.value) : null })
    } else {
      await inventory.saveCatalogOption(activeTab.value, { name: formName.value })
    }
    resetForm()
  } catch (error) {
    errorMessage.value = error.message || 'No se pudo guardar la opción.'
  }
}

async function toggleOption(option) {
  try {
    if (activeTab.value === 'categories') {
      await inventory.saveCategory({ ...option, active: option.active === false })
    } else {
      await inventory.saveCatalogOption(activeTab.value, { ...option, active: option.active === false })
    }
  } catch (error) {
    errorMessage.value = error.message || 'No se pudo actualizar la opción.'
  }
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Categorías y atributos</h2>
      <p class="mt-1 text-sm text-neutral-500">Administra las opciones que aparecerán en el formulario de productos.</p>
    </div>

    <div class="flex flex-wrap gap-2">
      <button
        v-for="tab in tabs"
        :key="tab.id"
        class="rounded-xl px-4 py-2.5 text-sm font-bold transition"
        :class="activeTab === tab.id ? 'bg-[var(--primary)] text-white' : 'bg-white text-neutral-600 hover:bg-pink-50 hover:text-[var(--primary)]'"
        @click="selectTab(tab.id)"
      >
        {{ tab.label }}
      </button>
    </div>

    <form class="rounded-2xl bg-white p-5 shadow-sm" @submit.prevent="save">
      <div class="flex flex-col gap-3 sm:flex-row">
        <input
          v-model="formName"
          required
          class="min-w-0 flex-1 rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
          :placeholder="activeTab === 'categories' ? 'Nombre de la categoría o subcategoría' : `Nueva opción de ${tabs.find((tab) => tab.id === activeTab)?.label.toLowerCase()}`"
        />
        <select
          v-if="activeTab === 'categories'"
          v-model="parentId"
          class="rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]"
        >
          <option value="">Categoría principal</option>
          <option v-for="category in categoryOptions" :key="category.id" :value="category.id">Subcategoría de {{ category.name }}</option>
        </select>
        <button class="rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white hover:bg-[var(--info)]" type="submit">Agregar</button>
      </div>
      <p v-if="errorMessage" class="mt-3 rounded-xl bg-red-50 p-3 text-sm text-red-600">{{ errorMessage }}</p>
    </form>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-120 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Nombre</th>
            <th v-if="activeTab === 'categories'" class="px-5 py-4">Tipo</th>
            <th class="px-5 py-4">Estado</th>
            <th class="px-5 py-4">Acción</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="option in currentOptions" :key="option.id" class="border-b border-pink-50">
            <td class="px-5 py-4 font-medium">{{ option.name }}</td>
            <td v-if="activeTab === 'categories'" class="px-5 py-4 text-neutral-500">{{ option.parentId ? 'Subcategoría' : 'Principal' }}</td>
            <td class="px-5 py-4">
              <span class="rounded-full px-3 py-1 text-xs font-bold" :class="option.active === false ? 'bg-neutral-100 text-neutral-500' : 'bg-emerald-100 text-emerald-700'">
                {{ option.active === false ? 'Inactivo' : 'Activo' }}
              </span>
            </td>
            <td class="px-5 py-4">
              <button class="rounded-lg border border-pink-200 px-3 py-1.5 text-xs font-bold text-[var(--primary)] hover:bg-pink-50" @click="toggleOption(option)">
                {{ option.active === false ? 'Activar' : 'Pausar' }}
              </button>
            </td>
          </tr>
          <tr v-if="!currentOptions.length">
            <td :colspan="activeTab === 'categories' ? 4 : 3" class="px-5 py-10 text-center text-neutral-500">No hay opciones registradas.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
