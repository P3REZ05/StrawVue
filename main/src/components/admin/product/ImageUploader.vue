<script setup>
import { computed, ref } from 'vue'
import { ImagePlus, Star, Trash2 } from 'lucide-vue-next'
import { useCatalogStore } from '../../../stores/catalog'

// Subida real de imágenes. Sustituye a `URL.createObjectURL`, que guardaba una
// URL `blob:` viva solo en la pestaña que la creaba: al recargar quedaba rota
// y ningún cliente la veía jamás.

const props = defineProps({
  productId: { type: [Number, String], required: true },
  variantId: { type: [Number, String], default: null },
  perfil: { type: String, default: 'producto' },
  titulo: { type: String, default: 'Imágenes' },
  descripcion: { type: String, default: '' }
})

const catalogo = useCatalogStore()
const subiendo = ref(false)
const error = ref('')
const ultimoResumen = ref('')
const arrastrando = ref(false)

const imagenes = computed(() =>
  catalogo.imagesOf(Number(props.productId), props.variantId ? Number(props.variantId) : null)
)

async function procesar(archivos) {
  error.value = ''
  const lista = [...archivos].filter((a) => a.type.startsWith('image/'))
  if (!lista.length) return

  subiendo.value = true
  try {
    for (const archivo of lista) {
      const esPrimera = !catalogo.imagesOf(Number(props.productId)).length
      const imagen = await catalogo.uploadImage(archivo, {
        productId: Number(props.productId),
        variantId: props.variantId ? Number(props.variantId) : null,
        perfil: props.perfil,
        esPrincipal: esPrimera && !props.variantId
      })
      ultimoResumen.value = imagen.optimizacion?.resumen || ''
    }
  } catch (e) {
    error.value = e?.message || 'No se pudo subir la imagen.'
  } finally {
    subiendo.value = false
  }
}

function alSoltar(evento) {
  arrastrando.value = false
  procesar(evento.dataTransfer.files)
}

async function eliminar(imagen) {
  error.value = ''
  try {
    await catalogo.removeImage(imagen)
  } catch (e) {
    error.value = e?.message || 'No se pudo eliminar la imagen.'
  }
}

async function principal(imagen) {
  error.value = ''
  try {
    await catalogo.setPrimaryImage(imagen)
  } catch (e) {
    error.value = e?.message || 'No se pudo marcar como principal.'
  }
}
</script>

<template>
  <section class="space-y-4">
    <div>
      <h3 class="text-lg font-bold text-black">{{ titulo }}</h3>
      <p v-if="descripcion" class="mt-1 text-sm text-neutral-500">{{ descripcion }}</p>
    </div>

    <label
      class="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-2xl border-2 border-dashed px-6 py-10 text-center transition"
      :class="arrastrando ? 'border-[var(--primary)] bg-pink-50' : 'border-pink-200 hover:bg-pink-50/50'"
      @dragover.prevent="arrastrando = true"
      @dragleave.prevent="arrastrando = false"
      @drop.prevent="alSoltar"
    >
      <ImagePlus class="size-7 text-[var(--primary)]" />
      <span class="text-sm font-bold text-neutral-700">
        {{ subiendo ? 'Optimizando y subiendo…' : 'Arrastra imágenes o haz clic para elegirlas' }}
      </span>
      <span class="text-xs text-neutral-500">
        Se comprimen automáticamente antes de subirlas para no gastar el plan de almacenamiento.
      </span>
      <input type="file" accept="image/*" multiple class="hidden" :disabled="subiendo" @change="procesar($event.target.files)" />
    </label>

    <p v-if="ultimoResumen" class="rounded-xl bg-emerald-50 px-3 py-2 text-xs font-semibold text-emerald-700">
      {{ ultimoResumen }}
    </p>
    <p v-if="error" class="rounded-xl bg-red-50 px-3 py-2 text-sm font-semibold text-red-600">{{ error }}</p>

    <div v-if="imagenes.length" class="grid gap-3 sm:grid-cols-3 lg:grid-cols-4">
      <figure v-for="imagen in imagenes" :key="imagen.id" class="group relative overflow-hidden rounded-xl border border-pink-100">
        <img :src="imagen.url" :alt="imagen.alt || ''" class="aspect-square w-full object-cover" loading="lazy" />
        <span
          v-if="imagen.is_primary"
          class="absolute left-2 top-2 rounded-full bg-[var(--primary)] px-2 py-0.5 text-[10px] font-bold text-white"
        >
          Principal
        </span>
        <div class="absolute inset-x-0 bottom-0 flex justify-end gap-1 bg-black/50 p-1.5 opacity-0 transition group-hover:opacity-100">
          <button
            v-if="!imagen.is_primary && !variantId"
            type="button"
            class="rounded-full bg-white/90 p-1.5 text-neutral-700 hover:text-[var(--primary)]"
            title="Marcar como principal"
            @click="principal(imagen)"
          >
            <Star class="size-3.5" />
          </button>
          <button
            type="button"
            class="rounded-full bg-white/90 p-1.5 text-neutral-700 hover:text-red-600"
            title="Eliminar"
            @click="eliminar(imagen)"
          >
            <Trash2 class="size-3.5" />
          </button>
        </div>
      </figure>
    </div>
  </section>
</template>
