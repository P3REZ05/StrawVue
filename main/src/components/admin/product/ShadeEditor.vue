<script setup>
import { computed, reactive, ref } from 'vue'
import { ChevronDown, ChevronUp, Palette, Plus, Star, Trash2 } from 'lucide-vue-next'
import { useCatalogStore } from '../../../stores/catalog'
import { formatCurrency } from '../../../utils/formatCurrency'

// Editor de tonos.
//
// En maquillaje el tono ES el producto: una base son cuarenta productos
// distintos que comparten fórmula. Por eso cada tono lleva color, subtono y
// profundidad, y no solo un nombre.
//
// Tres formas de cargarlos, de menos a más volumen: uno a uno, pegando una
// lista, o dejando el orden que ya trae la lista.

const props = defineProps({ productId: { type: [Number, String], required: true } })

const catalogo = useCatalogStore()
const error = ref('')
const guardando = ref(false)
const modo = ref('lista')

const tonos = computed(() => catalogo.shadesOf(Number(props.productId)))
const producto = computed(() => catalogo.productById(Number(props.productId)))
const atributos = computed(() => catalogo.atributosAplicables(producto.value?.category))

const nuevo = reactive({
  shadeCode: '', name: '', swatchHex: '#d2a679',
  undertoneId: '', shadeFamilyId: '', depth: '', sku: '', price: ''
})

const skuSugerido = computed(() => catalogo.suggestSku(Number(props.productId), nuevo.shadeCode || nuevo.name))

// --- Pegado por lotes -------------------------------------------------
const textoLote = ref('')
const previsualizacion = ref([])
const erroresLote = ref([])

function previsualizar() {
  const { tonos: parseados, errores } = catalogo.parseShadeList(textoLote.value)
  previsualizacion.value = parseados
  erroresLote.value = errores
}

async function confirmarLote() {
  error.value = ''
  if (!previsualizacion.value.length) return
  guardando.value = true
  try {
    await catalogo.saveShadesBatch(Number(props.productId), previsualizacion.value)
    textoLote.value = ''
    previsualizacion.value = []
    erroresLote.value = []
    modo.value = 'lista'
  } catch (e) {
    error.value = e?.message || 'No se pudieron crear los tonos.'
  } finally {
    guardando.value = false
  }
}

// --- Alta individual --------------------------------------------------
async function agregar() {
  error.value = ''
  if (!nuevo.name.trim()) {
    error.value = 'El tono necesita un nombre.'
    return
  }
  guardando.value = true
  try {
    await catalogo.saveShade(Number(props.productId), {
      ...nuevo,
      sku: nuevo.sku || skuSugerido.value,
      undertoneId: nuevo.undertoneId || null,
      shadeFamilyId: nuevo.shadeFamilyId || null,
      depth: nuevo.depth === '' ? null : Number(nuevo.depth),
      price: nuevo.price === '' ? null : Number(nuevo.price)
    })
    Object.assign(nuevo, { shadeCode: '', name: '', undertoneId: '', shadeFamilyId: '', depth: '', sku: '', price: '' })
  } catch (e) {
    error.value = e?.message || 'No se pudo guardar el tono.'
  } finally {
    guardando.value = false
  }
}

async function accion(fn) {
  error.value = ''
  try {
    await fn()
  } catch (e) {
    error.value = e?.message || 'No se pudo completar la acción.'
  }
}

async function mover(tono, direccion) {
  const ids = tonos.value.map((t) => t.id)
  const i = ids.indexOf(tono.id)
  const j = i + direccion
  if (j < 0 || j >= ids.length) return
  ;[ids[i], ids[j]] = [ids[j], ids[i]]
  await accion(() => catalogo.reorderShades(Number(props.productId), ids))
}

function precioMostrado(tono) {
  return tono.price != null ? formatCurrency(tono.price) : `${formatCurrency(catalogo.precioDeTono(tono))} (hereda)`
}
</script>

<template>
  <section class="space-y-5">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h3 class="text-lg font-bold text-black">Tonos</h3>
        <p class="mt-1 text-sm text-neutral-500">
          Cada tono lleva su color, su SKU y su stock propio. El precio se deja vacío para heredar el del producto.
        </p>
      </div>
      <div class="flex gap-2">
        <button
          type="button" class="rounded-full px-3 py-1.5 text-xs font-bold transition"
          :class="modo === 'lista' ? 'bg-[var(--primary)] text-white' : 'bg-pink-50 text-neutral-600'"
          @click="modo = 'lista'"
        >Uno a uno</button>
        <button
          type="button" class="rounded-full px-3 py-1.5 text-xs font-bold transition"
          :class="modo === 'lote' ? 'bg-[var(--primary)] text-white' : 'bg-pink-50 text-neutral-600'"
          @click="modo = 'lote'"
        >Pegar lista</button>
      </div>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 px-3 py-2 text-sm font-semibold text-red-600">{{ error }}</p>

    <!-- Alta individual -->
    <div v-if="modo === 'lista'" class="rounded-2xl border border-pink-100 bg-white p-4">
      <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        <label class="text-xs font-bold text-neutral-700">Código
          <input v-model="nuevo.shadeCode" placeholder="01 · NC42" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" />
        </label>
        <label class="text-xs font-bold text-neutral-700">Nombre del tono *
          <input v-model="nuevo.name" placeholder="Marfil" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" />
        </label>
        <label class="text-xs font-bold text-neutral-700">Color
          <span class="mt-1 flex items-center gap-2">
            <input v-model="nuevo.swatchHex" type="color" class="h-9 w-14 cursor-pointer rounded border border-pink-100" />
            <input v-model="nuevo.swatchHex" class="w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" />
          </span>
        </label>
        <label class="text-xs font-bold text-neutral-700">SKU
          <input v-model="nuevo.sku" :placeholder="skuSugerido" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" />
        </label>

        <label v-if="atributos.undertone" class="text-xs font-bold text-neutral-700">Subtono
          <select v-model="nuevo.undertoneId" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal">
            <option value="">Sin definir</option>
            <option v-for="u in catalogo.undertones" :key="u.id" :value="u.id">{{ u.code }} · {{ u.name }}</option>
          </select>
        </label>
        <label v-if="atributos.undertone" class="text-xs font-bold text-neutral-700">Profundidad (1 clara – 100 profunda)
          <input v-model="nuevo.depth" type="number" min="1" max="100" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" />
        </label>
        <label v-if="atributos.shadeFamily" class="text-xs font-bold text-neutral-700">Familia
          <select v-model="nuevo.shadeFamilyId" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal">
            <option value="">Sin definir</option>
            <option v-for="f in catalogo.shadeFamilies" :key="f.id" :value="f.id">{{ f.name }}</option>
          </select>
        </label>
        <label class="text-xs font-bold text-neutral-700">Precio propio (opcional)
          <input v-model="nuevo.price" type="number" min="0" placeholder="Hereda del producto" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" />
        </label>
      </div>

      <button
        type="button" :disabled="guardando"
        class="mt-4 inline-flex items-center gap-2 rounded-full bg-[var(--primary)] px-5 py-2 text-xs font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
        @click="agregar"
      >
        <Plus class="size-4" /> Añadir tono
      </button>
    </div>

    <!-- Pegado por lotes -->
    <div v-else class="rounded-2xl border border-pink-100 bg-white p-4">
      <p class="text-sm text-neutral-600">
        Pega la lista de tonos, una por línea. Separa con tabulaciones o comas:
        <span class="font-mono text-xs text-[var(--primary)]">código · nombre · color · subtono · profundidad</span>.
        Solo el nombre es obligatorio.
      </p>
      <textarea
        v-model="textoLote" rows="7"
        class="mt-3 w-full rounded-xl border border-pink-100 px-3 py-2 font-mono text-xs outline-none focus:border-[var(--primary)]"
        placeholder="01	Marfil	#F5DCC4	C	10&#10;02	Arena	#E8C39E	N	25&#10;03	Miel	#D2A679	W	40"
        @input="previsualizar"
      />

      <p v-for="(e, i) in erroresLote" :key="i" class="mt-1 text-xs font-semibold text-red-600">{{ e }}</p>

      <div v-if="previsualizacion.length" class="mt-4">
        <p class="text-xs font-bold uppercase tracking-wider text-neutral-500">
          Vista previa — {{ previsualizacion.length }} tono(s)
        </p>
        <div class="mt-2 flex flex-wrap gap-2">
          <span
            v-for="(t, i) in previsualizacion" :key="i"
            class="inline-flex items-center gap-2 rounded-full border border-pink-100 py-1 pl-1 pr-3 text-xs"
          >
            <span class="size-6 rounded-full border border-black/10" :style="{ background: t.swatchHex || '#e5e5e5' }" />
            <span class="font-semibold">{{ t.shadeCode }} {{ t.name }}</span>
          </span>
        </div>
        <button
          type="button" :disabled="guardando"
          class="mt-4 rounded-full bg-[var(--primary)] px-5 py-2 text-xs font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          @click="confirmarLote"
        >
          {{ guardando ? 'Creando…' : `Crear ${previsualizacion.length} tonos` }}
        </button>
      </div>
    </div>

    <!-- Tonos existentes -->
    <div v-if="tonos.length" class="overflow-x-auto rounded-2xl border border-pink-100 bg-white">
      <table class="w-full min-w-200 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-4 py-3">Orden</th>
            <th class="px-4 py-3">Color</th>
            <th class="px-4 py-3">Tono</th>
            <th class="px-4 py-3">SKU</th>
            <th class="px-4 py-3">Subtono</th>
            <th class="px-4 py-3">Prof.</th>
            <th class="px-4 py-3">Precio</th>
            <th class="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(tono, i) in tonos" :key="tono.id" class="border-b border-pink-50 hover:bg-pink-50/40">
            <td class="px-4 py-3">
              <span class="flex gap-1">
                <button type="button" class="rounded p-1 text-neutral-400 hover:text-[var(--primary)] disabled:opacity-30" :disabled="i === 0" @click="mover(tono, -1)"><ChevronUp class="size-4" /></button>
                <button type="button" class="rounded p-1 text-neutral-400 hover:text-[var(--primary)] disabled:opacity-30" :disabled="i === tonos.length - 1" @click="mover(tono, 1)"><ChevronDown class="size-4" /></button>
              </span>
            </td>
            <td class="px-4 py-3">
              <span v-if="tono.swatchImageUrl" class="block size-8 overflow-hidden rounded-full border border-black/10">
                <img :src="tono.swatchImageUrl" alt="" class="size-full object-cover" />
              </span>
              <span v-else-if="tono.swatchHex" class="block size-8 rounded-full border border-black/10" :style="{ background: tono.swatchHex }" />
              <Palette v-else class="size-5 text-neutral-300" />
            </td>
            <td class="px-4 py-3">
              <span class="font-semibold">{{ tono.shadeCode }} {{ tono.name }}</span>
              <span v-if="tono.isDefault" class="ml-2 rounded-full bg-pink-100 px-2 py-0.5 text-[10px] font-bold text-[var(--primary)]">Por defecto</span>
            </td>
            <td class="px-4 py-3 font-mono text-xs text-neutral-500">{{ tono.sku || '—' }}</td>
            <td class="px-4 py-3">{{ catalogo.optionName('undertones', tono.undertoneId) || '—' }}</td>
            <td class="px-4 py-3">{{ tono.depth ?? '—' }}</td>
            <td class="px-4 py-3 text-xs">{{ precioMostrado(tono) }}</td>
            <td class="px-4 py-3">
              <span class="flex justify-end gap-1">
                <button
                  v-if="!tono.isDefault" type="button" title="Marcar por defecto"
                  class="rounded-full p-1.5 text-neutral-400 hover:text-[var(--primary)]"
                  @click="accion(() => catalogo.setDefaultShade(Number(productId), tono.id))"
                ><Star class="size-4" /></button>
                <button
                  type="button" title="Desactivar tono"
                  class="rounded-full p-1.5 text-neutral-400 hover:text-red-600"
                  @click="accion(() => catalogo.deactivateShade(tono.id))"
                ><Trash2 class="size-4" /></button>
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <p v-else class="rounded-2xl border border-dashed border-pink-200 p-8 text-center text-sm text-neutral-500">
      Este producto todavía no tiene tonos. Si se vende en un solo color, puedes dejarlo así.
    </p>
  </section>
</template>
