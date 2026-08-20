<script setup>
import { reactive } from 'vue'

const emit = defineEmits(['filter', 'reset'])

const filterCriteria = reactive({
  name: '',
  category: '',
  minPrice: '',
  maxPrice: ''
})

function handleSubmit() {
  emit('filter', {
    name: filterCriteria.name.toLowerCase().trim(),
    category: filterCriteria.category.toLowerCase().trim(),
    minPrice: filterCriteria.minPrice ? Number(filterCriteria.minPrice) : null,
    maxPrice: filterCriteria.maxPrice ? Number(filterCriteria.maxPrice) : null
  })
}

function handleReset() {
  filterCriteria.name = ''
  filterCriteria.category = ''
  filterCriteria.minPrice = ''
  filterCriteria.maxPrice = ''
  emit('reset')
}
</script>

<template>
  <div class="rounded-2xl bg-white p-4 shadow-sm">
    <form class="grid gap-3 md:grid-cols-[1fr_1fr_1fr_1fr_auto]" @submit.prevent="handleSubmit">
      <input
        v-model="filterCriteria.name"
        type="text"
        class="rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
        placeholder="Nombre del producto"
      />
      <input
        v-model="filterCriteria.category"
        type="text"
        class="rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
        placeholder="Categoría"
      />
      <input
        v-model="filterCriteria.minPrice"
        type="number"
        min="0"
        class="rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
        placeholder="Precio mínimo"
      />
      <input
        v-model="filterCriteria.maxPrice"
        type="number"
        min="0"
        class="rounded-xl border border-pink-100 px-4 py-2.5 text-sm outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
        placeholder="Precio máximo"
      />
      <div class="flex gap-2">
        <button
          type="submit"
          class="flex-1 rounded-xl bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)] md:flex-none"
        >
          Filtrar
        </button>
        <button
          type="button"
          class="flex-1 rounded-xl bg-neutral-200 px-4 py-2.5 text-sm font-bold text-neutral-700 transition hover:bg-neutral-300 md:flex-none"
          @click="handleReset"
        >
          Limpiar
        </button>
      </div>
    </form>
  </div>
</template>