<script setup>
import { onMounted, ref } from 'vue'
import { adminUsers } from '../../data/mockData'

const STORAGE_KEY = 'strawberry-home-promotions'
const admins = ref([...adminUsers])
const promotions = ref([])
const promotionForm = ref({
  title: '',
  subtitle: '',
  accent: '',
  link: '/tienda',
  image: '',
  active: true
})

function loadPromotions() {
  const raw = localStorage.getItem(STORAGE_KEY)
  if (!raw) {
    promotions.value = []
    return
  }

  try {
    const parsed = JSON.parse(raw)
    promotions.value = Array.isArray(parsed) ? parsed : []
  } catch (error) {
    console.warn('No se pudieron cargar las promociones.', error)
    promotions.value = []
  }
}

function savePromotions() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(promotions.value))
}

function resetForm() {
  promotionForm.value = {
    title: '',
    subtitle: '',
    accent: '',
    link: '/tienda',
    image: '',
    active: true
  }
}

function handleImageUpload(event) {
  const file = event.target.files?.[0]
  if (!file) return

  const reader = new FileReader()
  reader.onload = () => {
    promotionForm.value.image = String(reader.result)
  }
  reader.readAsDataURL(file)
}

function addPromotion() {
  if (!promotionForm.value.title || !promotionForm.value.image) return

  promotions.value = [{
    id: `promo-${Date.now()}`,
    title: promotionForm.value.title,
    subtitle: promotionForm.value.subtitle,
    accent: promotionForm.value.accent,
    link: promotionForm.value.link || '/tienda',
    image: promotionForm.value.image,
    active: promotionForm.value.active
  }, ...promotions.value]

  savePromotions()
  resetForm()
}

function togglePromotion(id) {
  promotions.value = promotions.value.map((item) =>
    item.id === id ? { ...item, active: !item.active } : item
  )
  savePromotions()
}

function removePromotion(id) {
  promotions.value = promotions.value.filter((item) => item.id !== id)
  savePromotions()
}

onMounted(() => {
  loadPromotions()
})
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Configuración</h2>
      <p class="text-sm text-neutral-500">Administradores del sistema, configuración de la cuenta y promociones del home.</p>
    </div>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-150 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">#</th>
            <th class="px-5 py-4">Nombre</th>
            <th class="px-5 py-4">Email</th>
            <th class="px-5 py-4">Rol</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="admin in admins" :key="admin.id" class="border-b border-pink-50 transition hover:bg-pink-50/50">
            <td class="px-5 py-4 font-semibold">{{ admin.id }}</td>
            <td class="px-5 py-4">{{ admin.nombre }}</td>
            <td class="px-5 py-4">{{ admin.email }}</td>
            <td class="px-5 py-4">
              <span class="inline-flex rounded-full bg-[var(--success)] px-3 py-1 text-xs font-bold text-[var(--primary)]">
                {{ admin.role }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="rounded-2xl bg-white p-5 shadow-sm">
      <div class="mb-4 flex items-center justify-between gap-3">
        <div>
          <h3 class="text-xl font-bold text-black">Promociones del home</h3>
          <p class="text-sm text-neutral-500">Sube imágenes que se mostrarán en el carrusel superior.</p>
        </div>
      </div>

      <div class="grid gap-5 lg:grid-cols-[1.1fr_0.9fr]">
        <form class="space-y-4" @submit.prevent="addPromotion">
          <div class="grid gap-4 sm:grid-cols-2">
            <label class="space-y-2 text-sm font-medium text-neutral-700 sm:col-span-2">
              <span>Título</span>
              <input v-model="promotionForm.title" class="w-full rounded-xl border border-pink-100 px-3 py-2.5 outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100" type="text" placeholder="Nueva colección" />
            </label>

            <label class="space-y-2 text-sm font-medium text-neutral-700 sm:col-span-2">
              <span>Subtítulo</span>
              <input v-model="promotionForm.subtitle" class="w-full rounded-xl border border-pink-100 px-3 py-2.5 outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100" type="text" placeholder="Looks para cada momento" />
            </label>

            <label class="space-y-2 text-sm font-medium text-neutral-700">
              <span>Etiqueta</span>
              <input v-model="promotionForm.accent" class="w-full rounded-xl border border-pink-100 px-3 py-2.5 outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100" type="text" placeholder="Rosado glam" />
            </label>

            <label class="space-y-2 text-sm font-medium text-neutral-700">
              <span>Link</span>
              <input v-model="promotionForm.link" class="w-full rounded-xl border border-pink-100 px-3 py-2.5 outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100" type="text" placeholder="/tienda" />
            </label>
          </div>

          <label class="block space-y-2 text-sm font-medium text-neutral-700">
            <span>Imagen de promoción</span>
            <input class="block w-full text-sm text-neutral-600 file:mr-3 file:rounded-full file:border-0 file:bg-[var(--primary)] file:px-4 file:py-2 file:text-sm file:font-semibold file:text-white" type="file" accept="image/*" @change="handleImageUpload" />
          </label>

          <div v-if="promotionForm.image" class="overflow-hidden rounded-2xl border border-pink-100 bg-pink-50/30">
            <img :src="promotionForm.image" alt="Vista previa de promoción" class="h-36 w-full object-cover object-center" />
          </div>

          <div class="flex items-center justify-between gap-3">
            <label class="flex cursor-pointer items-center gap-2 text-sm text-neutral-700">
              <input v-model="promotionForm.active" type="checkbox" class="h-4 w-4 accent-[var(--primary)]" />
              Activar promoción
            </label>

            <button type="submit" class="rounded-full bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)]">
              Guardar promoción
            </button>
          </div>
        </form>

        <div class="space-y-3">
          <div v-if="!promotions.length" class="rounded-2xl border border-dashed border-pink-200 bg-pink-50/40 p-5 text-sm text-neutral-500">
            Aún no hay promociones creadas.
          </div>

          <div v-for="promo in promotions" :key="promo.id" class="overflow-hidden rounded-2xl border border-pink-100 bg-white">
            <img :src="promo.image" :alt="promo.title" class="h-28 w-full object-cover object-center" />
            <div class="space-y-3 p-3">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-sm font-bold text-black">{{ promo.title }}</p>
                  <p v-if="promo.subtitle" class="text-xs text-neutral-500">{{ promo.subtitle }}</p>
                </div>
                <button
                  type="button"
                  class="rounded-full px-2.5 py-1 text-[11px] font-bold"
                  :class="promo.active ? 'bg-[var(--success)] text-[var(--primary)]' : 'bg-neutral-200 text-neutral-600'"
                  @click="togglePromotion(promo.id)"
                >
                  {{ promo.active ? 'Activa' : 'Inactiva' }}
                </button>
              </div>
              <div class="flex items-center justify-end gap-2">
                <button type="button" class="rounded-full border border-neutral-200 px-3 py-1.5 text-xs font-semibold text-neutral-600" @click="removePromotion(promo.id)">
                  Eliminar
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>