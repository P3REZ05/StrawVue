<script setup>
import { computed, onMounted, ref } from 'vue'
import {
  Plus, Pencil, Trash2, Eye, EyeOff, ArrowUp, ArrowDown,
  Monitor, Smartphone, ImageUp, X, Loader2
} from 'lucide-vue-next'
import OffersGrid from '../home/OffersGrid.vue'
import { useOffersStore, TAMANOS, TIPOS_DESTINO, huecosDeLaRejilla } from '../../stores/offers'
import { useCatalogStore } from '../../stores/catalog'

/**
 * Editor de "Ofertas Especiales".
 *
 * La vista previa NO es un dibujo aproximado: monta el mismo `OffersGrid.vue`
 * que usa la portada, con los mismos datos. Una vista previa que reimplementa
 * el diseño miente en cuanto alguien toca uno de los dos, y entonces deja de
 * servir para lo único que existe: decidir si publicar o no.
 *
 * Mientras se edita una tarjeta, la previa muestra el borrador EN VIVO —lo
 * que se está escribiendo, no lo guardado— para poder probar un color o un
 * velo sin escribir en la base.
 */
const store = useOffersStore()
const catalogo = useCatalogStore()

const cargando = ref(true)
const error = ref('')
const aviso = ref('')
const guardando = ref(false)
const subiendo = ref(false)
const anchoPrevia = ref('escritorio')

const editando = ref(null)      // el borrador que se está editando, o null
const porBorrar = ref(null)     // la tarjeta pendiente de confirmar borrado

// `subtitle`, `badge`, `overlay`, `textColor` y los colores siguen en la base
// pero ya no se editan ni se pintan: la tarjeta enseña solo la imagen. Se
// dejan con su valor por defecto para no tocar el esquema por un cambio de
// diseño — si dentro de un tiempo siguen sin usarse, se sueltan en una
// migración, no antes.
const VACIA = {
  id: null, title: '', subtitle: '', badge: '', size: 'pequena',
  imageUrl: '', imagePath: '', colorDesde: '#ff85c1', colorHasta: '#d291bc',
  overlay: 0, textColor: 'light',
  linkType: 'category', linkCategory: '', linkProduct: null, linkUrl: '',
  position: 0, published: false
}

/**
 * Lo que se pinta en la previa: todas las guardadas, pero con la que se está
 * editando sustituida por el borrador en vivo. Una tarjeta nueva se añade al
 * final para poder verla antes de guardarla por primera vez.
 */
const previa = computed(() => {
  const lista = store.todas
  if (!editando.value) return lista
  if (!editando.value.id) return [...lista, { ...editando.value, id: 'nueva' }]
  return lista.map((o) => (o.id === editando.value.id ? { ...editando.value } : o))
})

const categorias = computed(() => catalogo.rootCategories)
const productos = computed(() =>
  [...catalogo.products].filter((p) => p.active !== false).sort((a, b) => a.name.localeCompare(b.name))
)

const publicadas = computed(() => store.todas.filter((o) => o.published).length)

/**
 * Cuántas celdas quedan sueltas al final. Es el defecto de composición que
 * más se cuela: dos tarjetas pequeñas cerrando una fila de cuatro dejan la
 * mitad derecha en blanco, y desde la lista no se ve. La previa lo enseña;
 * esto lo pone en palabras y dice cuánto falta.
 */
const huecos = computed(() =>
  huecosDeLaRejilla(previa.value, anchoPrevia.value === 'celular' ? 2 : 4)
)

// Qué pieza cerraría la fila. Dar el consejo concreto vale más que avisar.
const sugerencia = computed(() => {
  if (huecos.value === 1) return 'Añade una tarjeta Pequeña o cambia una a Ancha.'
  if (huecos.value === 2) return 'Añade una Ancha, una Alta, o dos Pequeñas.'
  if (huecos.value === 3) return 'Añade una Ancha y una Pequeña, o tres Pequeñas.'
  return ''
})

function nuevo() {
  editando.value = { ...VACIA, linkCategory: categorias.value[0]?.name || '' }
  aviso.value = ''
  error.value = ''
}

function editar(oferta) {
  editando.value = { ...oferta }
  aviso.value = ''
  error.value = ''
}

function cerrar() {
  editando.value = null
}

async function guardar() {
  if (!editando.value) return
  guardando.value = true
  error.value = ''
  try {
    const guardada = await store.save(editando.value)
    // El editor se cierra DESPUÉS de que la base confirme. Si falla, el
    // formulario se queda con lo escrito para poder reintentar.
    editando.value = null
    aviso.value = guardada.published
      ? `"${guardada.title}" guardada y visible en la tienda.`
      : `"${guardada.title}" guardada como borrador. Publícala cuando esté lista.`
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    guardando.value = false
  }
}

async function cambiarPublicacion(oferta) {
  error.value = ''
  try {
    const nueva = await store.setPublished(oferta, !oferta.published)
    aviso.value = nueva.published
      ? `"${nueva.title}" ya se ve en la tienda.`
      : `"${nueva.title}" se quitó de la tienda. Sigue guardada como borrador.`
  } catch (fallo) {
    error.value = fallo.message
  }
}

async function mover(oferta, direccion) {
  error.value = ''
  try {
    await store.mover(oferta, direccion)
  } catch (fallo) {
    error.value = fallo.message
  }
}

async function confirmarBorrado() {
  const oferta = porBorrar.value
  if (!oferta) return
  error.value = ''
  try {
    await store.remove(oferta)
    porBorrar.value = null
    if (editando.value?.id === oferta.id) editando.value = null
    aviso.value = `"${oferta.title}" se borró.`
  } catch (fallo) {
    error.value = fallo.message
    porBorrar.value = null
  }
}

async function elegirImagen(evento) {
  const archivo = evento.target.files?.[0]
  evento.target.value = ''
  if (!archivo || !editando.value) return

  subiendo.value = true
  error.value = ''
  try {
    const { url, path, optimizada } = await store.subirImagen(archivo)
    editando.value.imageUrl = url
    editando.value.imagePath = path
    aviso.value = `Imagen lista: ${Math.round(optimizada.bytes / 1024)} KB, ${optimizada.ancho}×${optimizada.alto}.`
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    subiendo.value = false
  }
}

function quitarImagenLocal() {
  if (!editando.value) return
  editando.value.imageUrl = ''
  editando.value.imagePath = ''
}

// Tamaño recomendado por pieza: el doble de lo que ocupa en pantalla (la
// rejilla usa filas de 10.5rem y cuatro columnas en un contenedor de 1280 px),
// para que se vea nítida en pantallas de densidad doble. Sin este dato se
// suben capturas verticales y la tarjeta las recorta por el centro.
const PIXELES = {
  destacada: '1200 × 700 px',
  ancha: '1200 × 340 px',
  alta: '600 × 700 px',
  pequena: '600 × 340 px'
}

function nombreTamano(id) {
  return TAMANOS.find((t) => t.id === id)?.etiqueta || id
}

onMounted(async () => {
  try {
    await Promise.all([store.load(), catalogo.init()])
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    cargando.value = false
  }
})
</script>

<template>
  <section class="space-y-5">
    <header class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h2 class="text-2xl font-bold text-black">Ofertas de la portada</h2>
        <p class="mt-1 max-w-2xl text-sm leading-6 text-neutral-500">
          Las tarjetas del bloque «Ofertas especiales». Son escaparate:
          <strong>no cambian precios</strong> — los descuentos de verdad se
          configuran en Promociones. Aquí se anuncia, allí se cobra.
        </p>
      </div>
      <button
        class="inline-flex h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
        @click="nuevo"
      >
        <Plus class="size-4" /> Nueva tarjeta
      </button>
    </header>

    <p v-if="error" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="aviso" class="rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">{{ aviso }}</p>

    <p v-if="cargando" class="rounded-xl border border-dashed border-pink-200 p-10 text-center text-sm text-neutral-500">
      Cargando las ofertas…
    </p>

    <template v-else>
      <div class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_400px]">
        <!-- ======================= VISTA PREVIA ======================= -->
        <div class="rounded-2xl border border-pink-100 bg-white p-4 sm:p-5">
          <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h3 class="text-sm font-bold text-black">Así se verá</h3>
              <p class="mt-0.5 text-xs text-neutral-500">
                Es el mismo bloque de la portada, no una imitación.
                Los borradores salen marcados y no se ven en la tienda.
              </p>
            </div>
            <div class="inline-flex rounded-full bg-pink-50 p-1">
              <button
                v-for="modo in [
                  { id: 'escritorio', icono: Monitor, texto: 'Escritorio' },
                  { id: 'celular', icono: Smartphone, texto: 'Celular' }
                ]"
                :key="modo.id"
                class="inline-flex items-center gap-1.5 rounded-full px-3 py-2 text-xs font-bold transition"
                :class="anchoPrevia === modo.id ? 'bg-white text-[var(--primary)] shadow-sm' : 'text-neutral-500'"
                @click="anchoPrevia = modo.id"
              >
                <component :is="modo.icono" class="size-4" /> {{ modo.texto }}
              </button>
            </div>
          </div>

          <div class="rounded-2xl bg-pink-50/50 p-3 sm:p-5">
            <div :class="anchoPrevia === 'celular' ? 'mx-auto w-[380px] max-w-full rounded-2xl bg-white p-3 shadow-sm' : ''">
              <div class="mb-4 text-center">
                <p class="text-xs font-bold uppercase tracking-[0.22em] text-[#c2185b]">Esta semana</p>
                <h4 class="mt-1 font-black tracking-tight text-black" :class="anchoPrevia === 'celular' ? 'text-xl' : 'text-2xl'">
                  Ofertas especiales
                </h4>
              </div>

              <OffersGrid
                v-if="previa.length"
                :ofertas="previa"
                vista-previa
                :compacta="anchoPrevia === 'celular'"
              />
              <p v-else class="py-10 text-center text-sm text-neutral-500">
                Todavía no hay tarjetas. Crea la primera y aparecerá aquí.
              </p>
            </div>
          </div>

          <p v-if="!publicadas && store.todas.length" class="mt-3 rounded-xl bg-amber-50 p-3 text-xs font-semibold text-amber-800">
            Ninguna tarjeta está publicada, así que la sección no aparece en la tienda.
          </p>

          <p v-if="huecos" class="mt-3 rounded-xl bg-sky-50 p-3 text-xs text-sky-900">
            <strong>Queda un hueco de {{ huecos }} celda(s)</strong> al final, en
            {{ anchoPrevia === 'celular' ? 'celular' : 'escritorio' }}.
            {{ sugerencia }}
            <span class="block text-sky-700/80">
              No es un error —la tienda se ve bien igual—, pero una fila cerrada luce mejor.
              Cambia de vista para comprobar la otra anchura.
            </span>
          </p>
        </div>

        <!-- ==================== LISTA / FORMULARIO ==================== -->
        <div class="space-y-3">
          <!-- --------- Formulario --------- -->
          <div v-if="editando" class="rounded-2xl border border-pink-200 bg-white p-4 shadow-sm">
            <div class="mb-4 flex items-center justify-between">
              <h3 class="text-sm font-bold text-black">
                {{ editando.id ? 'Editar tarjeta' : 'Nueva tarjeta' }}
              </h3>
              <button class="grid size-9 place-items-center rounded-full text-neutral-400 hover:bg-pink-50" aria-label="Cerrar" @click="cerrar">
                <X class="size-4" />
              </button>
            </div>

            <div class="space-y-4">
              <label class="block text-xs font-bold text-neutral-700">
                Nombre <span class="font-normal text-neutral-400">(solo para ti)</span>
                <input
                  v-model="editando.title"
                  class="mt-1 h-11 w-full rounded-xl border border-pink-100 px-3 text-sm font-normal outline-none focus:border-[var(--primary)]"
                  placeholder="Colección semanal"
                  maxlength="60"
                />
              </label>
              <p class="-mt-2 text-xs leading-5 text-neutral-500">
                No se ve en la tienda: la tarjeta enseña <strong>solo la imagen</strong>.
                El texto va dentro del volante que diseñes, donde puedes componerlo a tu gusto.
                Este nombre es para reconocerla en esta lista.
              </p>

              <!-- ----- Tamaño ----- -->
              <div>
                <p class="text-xs font-bold text-neutral-700">Tamaño</p>
                <div class="mt-2 grid grid-cols-2 gap-2">
                  <button
                    v-for="t in TAMANOS"
                    :key="t.id"
                    class="rounded-xl border p-2.5 text-left transition"
                    :class="editando.size === t.id
                      ? 'border-[var(--primary)] bg-pink-50 ring-1 ring-[var(--primary)]'
                      : 'border-pink-100 hover:border-pink-200'"
                    @click="editando.size = t.id"
                  >
                    <span class="flex items-center gap-2">
                      <!-- Miniatura de la pieza: se entiende antes de leerla. -->
                      <span class="grid size-6 shrink-0 grid-cols-2 grid-rows-2 gap-px rounded bg-pink-100 p-px">
                        <span
                          class="rounded-[2px] bg-[var(--primary)]"
                          :class="{
                            'col-span-2 row-span-2': t.id === 'destacada',
                            'col-span-2': t.id === 'ancha',
                            'row-span-2': t.id === 'alta'
                          }"
                        />
                      </span>
                      <span class="text-xs font-bold text-neutral-800">{{ t.etiqueta }}</span>
                    </span>
                    <span class="mt-1 block text-xs leading-tight text-neutral-500">{{ t.descripcion }}</span>
                  </button>
                </div>
              </div>

              <!-- ----- Imagen ----- -->
              <div>
                <p class="text-xs font-bold text-neutral-700">Imagen *</p>
                <div v-if="editando.imageUrl" class="mt-2 flex items-center gap-3">
                  <img :src="editando.imageUrl" alt="" class="size-16 rounded-xl object-cover ring-1 ring-pink-100" />
                  <button
                    class="inline-flex h-10 items-center gap-1.5 rounded-full border border-pink-200 px-3 text-xs font-bold text-neutral-600 transition hover:border-red-300 hover:text-red-500"
                    @click="quitarImagenLocal"
                  >
                    <Trash2 class="size-3.5" /> Quitar imagen
                  </button>
                </div>
                <label
                  v-else
                  class="mt-2 flex h-24 cursor-pointer items-center justify-center gap-2 rounded-xl border-2 border-dashed border-pink-200 text-xs font-bold text-neutral-500 transition hover:border-[var(--primary)] hover:bg-pink-50"
                >
                  <Loader2 v-if="subiendo" class="size-4 animate-spin" />
                  <ImageUp v-else class="size-4" />
                  {{ subiendo ? 'Subiendo…' : 'Subir una foto' }}
                  <input type="file" accept="image/*" class="hidden" :disabled="subiendo" @change="elegirImagen" />
                </label>
                <p class="mt-1.5 text-xs leading-5 text-neutral-500">
                  Tamaño recomendado para «{{ nombreTamano(editando.size) }}»:
                  <strong>{{ PIXELES[editando.size] }}</strong>.
                  La foto se recorta para llenar la tarjeta, así que deja lo importante en el centro.
                </p>
                <p class="mt-1 text-xs text-neutral-400">
                  Sin foto la tarjeta no se muestra en la tienda: la imagen es lo único que enseña.
                  Se optimiza sola al subirla.
                </p>
              </div>

              <!-- ----- Destino ----- -->
              <div>
                <label class="block text-xs font-bold text-neutral-700">
                  Al tocarla, lleva a…
                  <select
                    v-model="editando.linkType"
                    class="mt-1 h-11 w-full rounded-xl border border-pink-100 bg-white px-3 text-sm font-normal outline-none focus:border-[var(--primary)]"
                  >
                    <option v-for="t in TIPOS_DESTINO" :key="t.id" :value="t.id">{{ t.etiqueta }}</option>
                  </select>
                </label>

                <select
                  v-if="editando.linkType === 'category'"
                  v-model="editando.linkCategory"
                  class="mt-2 h-11 w-full rounded-xl border border-pink-100 bg-white px-3 text-sm outline-none focus:border-[var(--primary)]"
                  aria-label="Categoría de destino"
                >
                  <option value="">Elige una categoría</option>
                  <option v-for="c in categorias" :key="c.id" :value="c.name">{{ c.name }}</option>
                </select>

                <select
                  v-else-if="editando.linkType === 'product'"
                  v-model.number="editando.linkProduct"
                  class="mt-2 h-11 w-full rounded-xl border border-pink-100 bg-white px-3 text-sm outline-none focus:border-[var(--primary)]"
                  aria-label="Producto de destino"
                >
                  <option :value="null">Elige un producto</option>
                  <option v-for="p in productos" :key="p.id" :value="p.id">{{ p.name }}</option>
                </select>

                <input
                  v-else-if="editando.linkType === 'url'"
                  v-model="editando.linkUrl"
                  class="mt-2 h-11 w-full rounded-xl border border-pink-100 px-3 text-sm outline-none focus:border-[var(--primary)]"
                  placeholder="https://instagram.com/strawberrymakeup"
                />

                <p v-else class="mt-2 rounded-xl bg-amber-50 p-2.5 text-xs text-amber-800">
                  Una tarjeta grande que no lleva a ninguna parte frustra, sobre todo en el
                  celular, donde todo invita a tocarse. Conviene darle un destino.
                </p>
              </div>

              <div class="flex gap-2 border-t border-pink-100 pt-4">
                <button
                  :disabled="guardando"
                  class="h-11 flex-1 rounded-full bg-[var(--primary)] text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
                  @click="guardar"
                >
                  {{ guardando ? 'Guardando…' : 'Guardar' }}
                </button>
                <button class="h-11 rounded-full border border-pink-200 px-5 text-sm font-bold text-neutral-600" @click="cerrar">
                  Cancelar
                </button>
              </div>
              <p class="text-xs text-neutral-400">
                Guardar no publica. Una tarjeta nueva nace como borrador; se publica desde la lista.
              </p>
            </div>
          </div>

          <!-- --------- Lista --------- -->
          <div class="rounded-2xl border border-pink-100 bg-white p-4">
            <div class="mb-3 flex items-baseline justify-between">
              <h3 class="text-sm font-bold text-black">Tarjetas</h3>
              <p class="text-xs text-neutral-500">
                {{ publicadas }} publicada(s) · {{ store.borradores }} borrador(es)
              </p>
            </div>

            <p v-if="!store.todas.length" class="rounded-xl border border-dashed border-pink-200 p-6 text-center text-sm text-neutral-500">
              Todavía no hay tarjetas.
            </p>

            <ul v-else class="space-y-2">
              <li
                v-for="(oferta, i) in store.todas"
                :key="oferta.id"
                class="flex items-center gap-2 rounded-xl border p-2.5"
                :class="editando && editando.id === oferta.id ? 'border-[var(--primary)] bg-pink-50/60' : 'border-pink-100'"
              >
                <span
                  class="size-10 shrink-0 overflow-hidden rounded-lg ring-1 ring-black/5"
                  :class="oferta.imageUrl ? '' : 'bg-neutral-100'"
                >
                  <img v-if="oferta.imageUrl" :src="oferta.imageUrl" alt="" class="h-full w-full object-cover" />
                </span>

                <span class="min-w-0 flex-1">
                  <span class="flex items-center gap-1.5">
                    <strong class="truncate text-sm text-black">{{ oferta.title }}</strong>
                    <span
                      class="shrink-0 rounded-full px-1.5 py-0.5 text-xs font-bold"
                      :class="oferta.published ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-800'"
                    >{{ oferta.published ? 'En la tienda' : 'Borrador' }}</span>
                  </span>
                  <span class="mt-0.5 block truncate text-xs text-neutral-500">{{ nombreTamano(oferta.size) }}</span>
                </span>

                <span class="flex shrink-0 items-center">
                  <button
                    class="grid size-9 place-items-center rounded-lg text-neutral-400 transition hover:bg-pink-50 hover:text-neutral-700 disabled:opacity-25"
                    :disabled="i === 0" aria-label="Subir" @click="mover(oferta, 'arriba')"
                  ><ArrowUp class="size-4" /></button>
                  <button
                    class="grid size-9 place-items-center rounded-lg text-neutral-400 transition hover:bg-pink-50 hover:text-neutral-700 disabled:opacity-25"
                    :disabled="i === store.todas.length - 1" aria-label="Bajar" @click="mover(oferta, 'abajo')"
                  ><ArrowDown class="size-4" /></button>
                  <button
                    class="grid size-9 place-items-center rounded-lg transition hover:bg-pink-50"
                    :class="oferta.published ? 'text-emerald-600' : 'text-neutral-400'"
                    :aria-label="oferta.published ? 'Quitar de la tienda' : 'Publicar'"
                    :title="oferta.published ? 'Quitar de la tienda' : 'Publicar'"
                    @click="cambiarPublicacion(oferta)"
                  >
                    <Eye v-if="oferta.published" class="size-4" />
                    <EyeOff v-else class="size-4" />
                  </button>
                  <button
                    class="grid size-9 place-items-center rounded-lg text-neutral-400 transition hover:bg-pink-50 hover:text-[var(--primary)]"
                    aria-label="Editar" @click="editar(oferta)"
                  ><Pencil class="size-4" /></button>
                  <button
                    class="grid size-9 place-items-center rounded-lg text-neutral-400 transition hover:bg-red-50 hover:text-red-500"
                    aria-label="Borrar" @click="porBorrar = oferta"
                  ><Trash2 class="size-4" /></button>
                </span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </template>

    <!-- Modal propio, no `confirm()`: el del navegador bloquea la pestaña y no
         deja explicar qué implica la acción (CLAUDE.md §4). -->
    <Teleport to="body">
      <div v-if="porBorrar" class="fixed inset-0 z-100 grid place-items-center p-5">
        <button class="absolute inset-0 bg-black/40" aria-label="Cancelar" @click="porBorrar = null"></button>
        <div class="relative w-full max-w-sm rounded-2xl bg-white p-6 shadow-2xl">
          <h3 class="text-lg font-bold text-black">¿Borrar «{{ porBorrar.title }}»?</h3>
          <p class="mt-2 text-sm leading-6 text-neutral-600">
            Se borra la tarjeta y su imagen. No afecta a ningún producto ni a ninguna
            promoción. Si solo quieres dejar de mostrarla, quítala de la tienda en vez
            de borrarla.
          </p>
          <div class="mt-6 flex gap-2">
            <button class="h-11 flex-1 rounded-full bg-red-500 text-sm font-bold text-white transition hover:bg-red-600" @click="confirmarBorrado">
              Sí, borrar
            </button>
            <button class="h-11 flex-1 rounded-full border border-neutral-200 text-sm font-bold text-neutral-700" @click="porBorrar = null">
              Cancelar
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </section>
</template>
