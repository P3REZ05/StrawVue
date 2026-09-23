<script setup>
import { computed, onMounted, ref } from 'vue'
import { Mail, Phone, Archive, Check } from 'lucide-vue-next'
import { useContactStore, ESTADOS } from '../../stores/contact'

const contacto = useContactStore()
const error = ref('')
const abierto = ref(null)
const nota = ref('')
const verArchivados = ref(false)

const lista = computed(() => (verArchivados.value ? contacto.archivados : contacto.bandeja))

onMounted(async () => {
  try {
    await contacto.init()
  } catch (fallo) {
    error.value = fallo.message
  }
})

function fecha(iso) {
  return new Date(iso).toLocaleString('es-CO', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
  })
}

async function abrir(mensaje) {
  if (abierto.value === mensaje.id) {
    abierto.value = null
    return
  }
  abierto.value = mensaje.id
  nota.value = mensaje.admin_note || ''
  error.value = ''
  try {
    await contacto.marcarLeido(mensaje)
  } catch (fallo) {
    error.value = fallo.message
  }
}

async function cambiar(mensaje, estado) {
  error.value = ''
  try {
    await contacto.setStatus(mensaje, estado, nota.value)
  } catch (fallo) {
    error.value = fallo.message
  }
}

// El enlace de WhatsApp normaliza el número: la gente lo escribe con
// espacios, guiones o sin indicativo, y `wa.me` solo acepta dígitos.
function whatsapp(mensaje) {
  const digitos = String(mensaje.phone || '').replace(/\D/g, '')
  if (!digitos) return ''
  const numero = digitos.length === 10 ? `57${digitos}` : digitos
  const texto = `Hola ${mensaje.name.split(' ')[0]}, te escribimos de Strawberry Makeup por tu mensaje.`
  return `https://wa.me/${numero}?text=${encodeURIComponent(texto)}`
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h2 class="text-2xl font-bold text-black">Mensajes</h2>
        <p class="mt-1 text-sm text-neutral-500">
          Lo que llega por el formulario de contacto de la tienda.
          <span v-if="contacto.sinLeer" class="font-bold text-[var(--primary)]">{{ contacto.sinLeer }} sin leer.</span>
        </p>
      </div>
      <button
        class="rounded-full border border-pink-200 px-4 py-2 text-sm font-bold text-neutral-700 transition hover:bg-pink-50"
        @click="verArchivados = !verArchivados"
      >
        {{ verArchivados ? 'Ver bandeja' : `Ver archivados (${contacto.archivados.length})` }}
      </button>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="contacto.loading" class="rounded-2xl bg-white p-8 text-center text-sm text-neutral-500">Cargando…</p>

    <div v-else class="space-y-3">
      <article
        v-for="m in lista"
        :key="m.id"
        class="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-pink-100"
      >
        <button class="flex w-full items-start gap-3 p-4 text-left transition hover:bg-pink-50/50" @click="abrir(m)">
          <span class="mt-1 shrink-0 rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white"
                :class="ESTADOS[m.status]?.clase">
            {{ ESTADOS[m.status]?.texto }}
          </span>
          <span class="min-w-0 flex-1">
            <span class="flex flex-wrap items-baseline gap-x-2">
              <strong class="text-black">{{ m.name }}</strong>
              <span class="text-xs text-neutral-400">{{ fecha(m.created_at) }}</span>
            </span>
            <span class="mt-0.5 block truncate text-sm text-neutral-600">{{ m.message }}</span>
          </span>
        </button>

        <div v-if="abierto === m.id" class="border-t border-pink-100 bg-pink-50/40 p-4">
          <p class="whitespace-pre-wrap text-sm leading-6 text-neutral-700">{{ m.message }}</p>

          <div class="mt-4 flex flex-wrap gap-2 text-sm">
            <a :href="`mailto:${m.email}`"
               class="inline-flex items-center gap-1.5 rounded-full border border-pink-200 bg-white px-3 py-1.5 font-semibold text-neutral-700 transition hover:border-[var(--primary)]">
              <Mail class="size-3.5" /> {{ m.email }}
            </a>
            <a v-if="m.phone" :href="whatsapp(m)" target="_blank" rel="noopener"
               class="inline-flex items-center gap-1.5 rounded-full border border-emerald-200 bg-white px-3 py-1.5 font-semibold text-emerald-700 transition hover:border-emerald-400">
              <Phone class="size-3.5" /> {{ m.phone }}
            </a>
          </div>

          <label class="mt-4 block text-sm font-semibold text-neutral-700">
            Nota interna
            <input v-model="nota" type="text" maxlength="200" placeholder="Qué se le respondió, o qué falta"
                   class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 font-normal outline-none focus:border-[var(--primary)]" />
          </label>

          <div class="mt-4 flex flex-wrap gap-2">
            <button v-if="m.status !== 'answered'"
                    class="inline-flex items-center gap-1.5 rounded-full bg-emerald-500 px-4 py-2 text-sm font-bold text-white transition hover:bg-emerald-600"
                    @click="cambiar(m, 'answered')">
              <Check class="size-4" /> Marcar respondido
            </button>
            <button v-if="m.status !== 'archived'"
                    class="inline-flex items-center gap-1.5 rounded-full border border-pink-200 px-4 py-2 text-sm font-bold text-neutral-700 transition hover:bg-white"
                    @click="cambiar(m, 'archived')">
              <Archive class="size-4" /> Archivar
            </button>
            <button v-else
                    class="rounded-full border border-pink-200 px-4 py-2 text-sm font-bold text-neutral-700 transition hover:bg-white"
                    @click="cambiar(m, 'read')">
              Devolver a la bandeja
            </button>
          </div>
          <p class="mt-3 text-xs text-neutral-400">
            Los mensajes no se borran, se archivan: llevan datos de una persona real y conviene poder rastrearlos.
          </p>
        </div>
      </article>

      <p v-if="!lista.length" class="rounded-2xl bg-white p-10 text-center text-neutral-500">
        {{ verArchivados ? 'No hay mensajes archivados.' : 'No hay mensajes por atender.' }}
      </p>
    </div>
  </div>
</template>
