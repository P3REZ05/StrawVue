<script setup>
import { computed, ref } from 'vue'
import { Tags, Plus, Pencil, Trash2, Eye, EyeOff } from 'lucide-vue-next'
import { useCatalogStore } from '../../stores/catalog'

/**
 * ETIQUETAS de la tarjeta de producto.
 *
 * Antes eran tres casillas fijas en el editor —Destacado, Nuevo,
 * Recomendado— y tenían dos problemas: no se podía crear una cuarta sin tocar
 * código, y **ninguna de las tres se veía en la tienda**. Se marcaban y no
 * pasaba nada. Ahora son filas de una tabla, con su color, y se pintan en la
 * tarjeta y en la ficha.
 *
 * REGLA: una etiqueta es escaparate. NO cambia el precio ni el stock. Una que
 * diga «2x1» lo anuncia; el descuento lo cobra el servidor desde
 * `promotions`. Es la misma separación que ya existe con las ofertas de
 * portada, y está ahí porque dos sitios calculando el mismo importe es como
 * se rompió el costo de envío.
 */
const catalogo = useCatalogStore()

const error = ref('')
const aviso = ref('')
const busy = ref(false)
const edicion = ref(null)
const aBorrar = ref(null)

// Colores sugeridos: los de la marca más los cuatro estados de uso común.
// Un selector de color completo invita a elegir un rosa distinto cada vez y a
// que la tienda acabe con siete rosas que no combinan.
const PALETA = [
  { nombre: 'Rosa marca', fondo: '#ff85c1', texto: '#ffffff' },
  { nombre: 'Morado', fondo: '#a855f7', texto: '#ffffff' },
  { nombre: 'Verde', fondo: '#22c55e', texto: '#ffffff' },
  { nombre: 'Azul', fondo: '#0ea5e9', texto: '#ffffff' },
  { nombre: 'Naranja', fondo: '#f97316', texto: '#ffffff' },
  { nombre: 'Negro', fondo: '#111111', texto: '#ffffff' },
  { nombre: 'Crema', fondo: '#fde68a', texto: '#111111' }
]

const etiquetas = computed(() =>
  [...catalogo.badges].sort((a, b) => a.position - b.position)
)

// Aviso, no bloqueo. El nombre repetido lo resuelve la base numerando el
// identificador interno, así que guardar funciona igual; pero dos etiquetas
// que se leen igual en la tarjeta es casi siempre un despiste, y vale la pena
// decirlo antes de guardar en vez de después.
const nombreRepetido = computed(() => {
  if (!edicion.value?.name?.trim()) return false
  const nombre = edicion.value.name.trim().toLowerCase()
  return catalogo.badges.some(
    (b) => b.id !== edicion.value.id && b.name.trim().toLowerCase() === nombre
  )
})

function nueva() {
  error.value = ''
  aviso.value = ''
  edicion.value = {
    id: null,
    name: '',
    description: '',
    colorFondo: '#a855f7',
    colorTexto: '#ffffff',
    position: (Math.max(0, ...catalogo.badges.map((b) => b.position)) + 1),
    active: true
  }
}

function editar(etiqueta) {
  error.value = ''
  aviso.value = ''
  edicion.value = { ...etiqueta }
}

async function guardar() {
  if (!edicion.value) return
  busy.value = true
  error.value = ''
  try {
    await catalogo.saveBadge(edicion.value)
    // El formulario se cierra DESPUÉS de que la base confirme.
    aviso.value = `Etiqueta «${edicion.value.name.trim()}» guardada.`
    edicion.value = null
  } catch (fallo) {
    error.value = fallo.message || 'No se pudo guardar la etiqueta.'
  } finally {
    busy.value = false
  }
}

async function alternarActiva(etiqueta) {
  busy.value = true
  error.value = ''
  try {
    await catalogo.saveBadge({ ...etiqueta, active: !etiqueta.active })
    aviso.value = etiqueta.active
      ? `«${etiqueta.name}» ya no se ve en la tienda. Sigue puesta a sus productos.`
      : `«${etiqueta.name}» vuelve a verse en la tienda.`
  } catch (fallo) {
    error.value = fallo.message || 'No se pudo cambiar la etiqueta.'
  } finally {
    busy.value = false
  }
}

async function confirmarBorrado() {
  if (!aBorrar.value) return
  busy.value = true
  error.value = ''
  try {
    await catalogo.deleteBadge(aBorrar.value.id)
    aviso.value = `Etiqueta «${aBorrar.value.name}» borrada.`
    aBorrar.value = null
  } catch (fallo) {
    error.value = fallo.message || 'No se pudo borrar la etiqueta.'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h2 class="flex items-center gap-2 text-2xl font-bold text-black">
          <Tags class="size-6 text-[var(--primary)]" /> Etiquetas
        </h2>
        <p class="mt-1 max-w-2xl text-sm leading-6 text-neutral-500">
          Los distintivos que salen sobre la foto del producto: <strong>VIRAL</strong>, <strong>NUEVO</strong>,
          lo que quieras. Son escaparate: llaman la atención, pero <strong>no cambian el precio</strong>
          — los descuentos se crean en <strong>Promociones</strong>.
        </p>
      </div>
      <button
        class="inline-flex min-h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="nueva"
      >
        <Plus class="size-4" /> Nueva etiqueta
      </button>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="aviso" class="rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">{{ aviso }}</p>

    <div v-if="etiquetas.length" class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-150 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Se ve así</th>
            <th class="px-5 py-4">Para qué la usas</th>
            <th class="px-5 py-4">Productos</th>
            <th class="px-5 py-4">En la tienda</th>
            <th class="px-5 py-4"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="etiqueta in etiquetas" :key="etiqueta.id" class="border-b border-pink-50">
            <td class="px-5 py-4">
              <span
                class="inline-block rounded-full px-3 py-1 text-xs font-bold uppercase tracking-wide shadow-sm"
                :class="etiqueta.active ? '' : 'opacity-40'"
                :style="{ background: etiqueta.colorFondo, color: etiqueta.colorTexto }"
              >{{ etiqueta.name }}</span>
            </td>
            <td class="px-5 py-4 text-neutral-500">{{ etiqueta.description || '—' }}</td>
            <td class="px-5 py-4 font-bold text-neutral-700">{{ catalogo.badgeUsage(etiqueta.id) }}</td>
            <td class="px-5 py-4">
              <span v-if="etiqueta.active" class="rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-bold text-emerald-700">Se ve</span>
              <span v-else class="rounded-full bg-neutral-100 px-2.5 py-1 text-xs font-bold text-neutral-500">Oculta</span>
            </td>
            <td class="px-5 py-4">
              <div class="flex justify-end gap-1.5">
                <button
                  :disabled="busy"
                  class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                  :title="etiqueta.active ? 'Ocultar de la tienda' : 'Volver a mostrar'"
                  :aria-label="etiqueta.active ? 'Ocultar de la tienda' : 'Volver a mostrar'"
                  @click="alternarActiva(etiqueta)"
                >
                  <EyeOff v-if="etiqueta.active" class="size-4" />
                  <Eye v-else class="size-4" />
                </button>
                <button
                  class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                  title="Editar" aria-label="Editar etiqueta"
                  @click="editar(etiqueta)"
                >
                  <Pencil class="size-4" />
                </button>
                <button
                  class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600"
                  title="Borrar" aria-label="Borrar etiqueta"
                  @click="aBorrar = etiqueta"
                >
                  <Trash2 class="size-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="rounded-2xl border border-dashed border-pink-200 bg-white p-10 text-center">
      <Tags class="mx-auto size-8 text-pink-300" />
      <p class="mt-3 font-bold text-neutral-700">Todavía no hay etiquetas</p>
      <p class="mx-auto mt-1 max-w-md text-sm leading-6 text-neutral-500">
        Crea la primera y podrás ponérsela a cualquier producto desde su ficha.
      </p>
    </div>

    <!-- ================= Formulario ================= -->
    <div v-if="edicion" class="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" @click.self="edicion = null">
      <form class="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl" @submit.prevent="guardar">
        <h3 class="text-lg font-bold text-black">{{ edicion.id ? 'Editar etiqueta' : 'Nueva etiqueta' }}</h3>

        <label class="mt-4 block text-sm font-semibold text-neutral-700">
          Texto <span class="font-normal text-neutral-400">(máximo 24 caracteres)</span>
          <input
            v-model="edicion.name" maxlength="24" required
            class="mt-1 h-11 w-full rounded-xl border border-pink-100 px-4 text-sm font-normal outline-none focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
            placeholder="VIRAL"
          />
        </label>

        <p v-if="nombreRepetido" class="mt-2 rounded-xl bg-amber-50 px-3 py-2 text-xs leading-5 font-semibold text-amber-800">
          Ya tienes una etiqueta con ese texto. Puedes guardarla igual —se distinguen por dentro—,
          pero en la tarjeta se van a leer iguales.
        </p>

        <label class="mt-4 block text-sm font-semibold text-neutral-700">
          Para qué la usas <span class="font-normal text-neutral-400">(solo lo ves tú)</span>
          <input
            v-model="edicion.description"
            class="mt-1 h-11 w-full rounded-xl border border-pink-100 px-4 text-sm font-normal outline-none focus:border-[var(--primary)]"
            placeholder="Lo que está sonando en redes"
          />
        </label>

        <p class="mt-5 text-sm font-semibold text-neutral-700">Color</p>
        <div class="mt-2 flex flex-wrap gap-2">
          <button
            v-for="color in PALETA" :key="color.fondo"
            type="button"
            class="rounded-full px-4 py-2 text-xs font-bold uppercase tracking-wide transition"
            :class="edicion.colorFondo === color.fondo ? 'ring-2 ring-black ring-offset-2' : ''"
            :style="{ background: color.fondo, color: color.texto }"
            :title="color.nombre"
            @click="edicion.colorFondo = color.fondo; edicion.colorTexto = color.texto"
          >
            {{ edicion.name || 'Etiqueta' }}
          </button>
        </div>

        <div class="mt-5 rounded-xl bg-pink-50/60 p-4">
          <p class="text-xs font-bold uppercase tracking-wider text-neutral-500">Así se verá en la tarjeta</p>
          <div class="mt-3 grid h-28 w-40 place-items-center rounded-xl bg-white shadow-sm ring-1 ring-pink-100">
            <span
              class="rounded-full px-3 py-1 text-xs font-bold uppercase tracking-wide shadow"
              :style="{ background: edicion.colorFondo, color: edicion.colorTexto }"
            >{{ edicion.name || 'ETIQUETA' }}</span>
          </div>
        </div>

        <label class="mt-5 flex items-center gap-2 text-sm font-semibold text-neutral-700">
          <input v-model="edicion.active" type="checkbox" class="size-4 accent-[var(--primary)]" />
          Se ve en la tienda
        </label>

        <div class="mt-6 flex gap-2">
          <button
            type="submit" :disabled="busy || !edicion.name.trim()"
            class="h-11 flex-1 rounded-full bg-[var(--primary)] text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          >
            {{ busy ? 'Guardando…' : 'Guardar' }}
          </button>
          <button type="button" class="h-11 rounded-full border border-pink-200 px-5 text-sm font-bold text-neutral-600" @click="edicion = null">
            Cancelar
          </button>
        </div>
      </form>
    </div>

    <!-- ================= Borrado =================
         Modal propio, no `confirm()`: hay que decir a cuántos productos
         afecta ANTES de preguntar, y el diálogo del navegador no deja. -->
    <div v-if="aBorrar" class="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" @click.self="aBorrar = null">
      <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
        <h3 class="text-lg font-bold text-black">Borrar «{{ aBorrar.name }}»</h3>
        <p class="mt-3 text-sm leading-6 text-neutral-600">
          <template v-if="catalogo.badgeUsage(aBorrar.id)">
            Se quitará de <strong>{{ catalogo.badgeUsage(aBorrar.id) }}</strong> producto(s) y no se puede deshacer.
            Si solo quieres dejar de mostrarla, <strong>ocúltala</strong>: se retira de la tienda y conserva a qué
            productos estaba puesta.
          </template>
          <template v-else>
            No está puesta a ningún producto, así que no se pierde nada.
          </template>
        </p>
        <div class="mt-6 flex gap-2">
          <button
            :disabled="busy"
            class="h-11 flex-1 rounded-full bg-red-600 text-sm font-bold text-white transition hover:bg-red-700 disabled:opacity-50"
            @click="confirmarBorrado"
          >
            {{ busy ? 'Borrando…' : 'Borrar para siempre' }}
          </button>
          <button class="h-11 rounded-full border border-pink-200 px-5 text-sm font-bold text-neutral-600" @click="aBorrar = null">
            Cancelar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
