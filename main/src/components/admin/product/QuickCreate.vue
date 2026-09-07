<script setup>
import { nextTick, ref, watch } from 'vue'
import { Plus, X } from 'lucide-vue-next'

// Creación al vuelo de una opción maestra (marca, categoría, acabado…).
//
// Existe porque el flujo anterior obligaba a salir del formulario, ir a
// "Categorías y atributos", crear la opción y volver a empezar — perdiendo lo
// que ya se había escrito.

const props = defineProps({
  etiqueta: { type: String, required: true },
  // Campo extra opcional: 'code' para subtonos, 'hex' para familias de tono.
  campoExtra: { type: String, default: '' }
})
const emit = defineEmits(['crear'])

const abierto = ref(false)
const nombre = ref('')
const extra = ref('')
const error = ref('')
const guardando = ref(false)
const campoNombre = ref(null)

watch(abierto, async (valor) => {
  if (valor) {
    await nextTick()
    campoNombre.value?.focus()
  }
})

function cerrar() {
  abierto.value = false
  nombre.value = ''
  extra.value = ''
  error.value = ''
}

async function guardar() {
  error.value = ''
  if (!nombre.value.trim()) {
    error.value = 'Escribe un nombre.'
    return
  }
  guardando.value = true
  try {
    await emit('crear', { nombre: nombre.value.trim(), extra: extra.value.trim() })
    cerrar()
  } catch (e) {
    error.value = e?.message || 'No se pudo crear.'
  } finally {
    guardando.value = false
  }
}

defineExpose({ cerrar, fallar: (mensaje) => { error.value = mensaje; guardando.value = false } })
</script>

<template>
  <span class="relative inline-flex">
    <button
      type="button"
      class="inline-flex items-center gap-1 rounded-full border border-pink-200 px-2.5 py-1 text-xs font-bold text-[var(--primary)] transition hover:bg-pink-50"
      :title="`Crear ${etiqueta.toLowerCase()} sin salir del formulario`"
      @click="abierto = !abierto"
    >
      <Plus class="size-3.5" /> Crear
    </button>

    <div
      v-if="abierto"
      class="absolute right-0 top-9 z-30 w-72 rounded-2xl border border-pink-100 bg-white p-4 shadow-xl"
    >
      <div class="flex items-center justify-between">
        <p class="text-sm font-bold text-black">Nueva {{ etiqueta.toLowerCase() }}</p>
        <button type="button" class="text-neutral-400 hover:text-neutral-600" @click="cerrar">
          <X class="size-4" />
        </button>
      </div>

      <input
        ref="campoNombre"
        v-model="nombre"
        class="mt-3 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm outline-none focus:border-[var(--primary)]"
        :placeholder="`Nombre de la ${etiqueta.toLowerCase()}`"
        @keydown.enter.prevent="guardar"
        @keydown.esc="cerrar"
      />

      <input
        v-if="campoExtra === 'code'"
        v-model="extra"
        maxlength="2"
        class="mt-2 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm uppercase outline-none focus:border-[var(--primary)]"
        placeholder="Código (C, N, W, O…)"
        @keydown.enter.prevent="guardar"
      />
      <label v-else-if="campoExtra === 'hex'" class="mt-2 flex items-center gap-2 text-xs text-neutral-500">
        Color
        <input v-model="extra" type="color" class="h-8 w-14 cursor-pointer rounded border border-pink-100" />
      </label>

      <p v-if="error" class="mt-2 text-xs font-semibold text-red-600">{{ error }}</p>

      <button
        type="button"
        :disabled="guardando"
        class="mt-3 w-full rounded-full bg-[var(--primary)] py-2 text-xs font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
        @click="guardar"
      >
        {{ guardando ? 'Guardando…' : 'Crear y seleccionar' }}
      </button>
    </div>
  </span>
</template>
