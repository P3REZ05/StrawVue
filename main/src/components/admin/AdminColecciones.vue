<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ImagePlus, ArrowUp, ArrowDown, Trash2, Eye, EyeOff, Pencil, X } from 'lucide-vue-next'
import { useCollectionsStore } from '../../stores/collections'
import { useCatalogStore } from '../../stores/catalog'
import { useSettingsStore } from '../../stores/settings'
import AyudaInfo from './AyudaInfo.vue'

/**
 * COLECCIONES, desde el panel.
 *
 * Vive en **Configuración**, junto a los banners de la portada, porque lo que
 * se decide aquí es contenido de portada: qué colecciones desfilan, con qué
 * foto y en qué orden. A qué colección pertenece cada producto se decide en el
 * editor del producto, que es donde está el producto.
 *
 * Es un componente y no código suelto dentro de la pantalla para que haya UNA
 * sola implementación. Dos copias acaban divergiendo — ya pasó en este
 * proyecto con el mapeo de estados de pedido y con el costo de envío.
 *
 * Ocupa el sitio del módulo de la pasarela de marcas, que se retiró entero.
 */
const colecciones = useCollectionsStore()
const catalogo = useCatalogStore()
const settings = useSettingsStore()

const error = ref('')
const aviso = ref('')
const subiendo = ref(null)
const porBorrar = ref(null)

// El formulario sirve para crear y para editar: `id` a null es una colección
// nueva. Un segundo formulario de edición sería el mismo código dos veces.
const form = reactive({ id: null, name: '', description: '' })

onMounted(() => {
  colecciones.init().catch((e) => { error.value = e.message })
  settings.init().catch(() => {})
  // Solo para contar cuántos productos lleva cada colección. Si falla, la
  // pantalla funciona igual y el contador dice cero.
  catalogo.init().catch(() => {})
})

const lista = computed(() => colecciones.ordenadas)
const editando = computed(() => form.id !== null)

const seccionVisible = computed(() => settings.coleccionesVisibles)

// Cuántos productos lleva cada colección. Importa en dos sitios: para saber si
// una colección está realmente montada, y para poder decir en el modal de
// borrado cuántos productos se quedan sueltos.
const cuantosProductos = (collectionId) =>
  catalogo.products.filter((p) => Number(p.collectionId) === Number(collectionId)).length

function limpiar() {
  form.id = null
  form.name = ''
  form.description = ''
}

function editar(coleccion) {
  form.id = coleccion.id
  form.name = coleccion.name
  form.description = coleccion.description
  error.value = ''
  aviso.value = ''
}

async function guardar() {
  error.value = ''
  aviso.value = ''
  try {
    const guardada = await colecciones.save({ ...form })
    aviso.value = editando.value
      ? `«${guardada.name}» actualizada.`
      : `«${guardada.name}» creada. Asígnale productos desde la ficha de cada uno para que salga en la portada.`
    limpiar()
  } catch (fallo) {
    error.value = fallo.message
  }
}

async function elegirFoto(coleccion, evento) {
  const archivo = evento.target.files?.[0]
  // Se limpia el input SIEMPRE: si no, volver a elegir el mismo archivo tras
  // un fallo no dispara `change` y parece que el botón dejó de funcionar.
  evento.target.value = ''
  if (!archivo) return

  subiendo.value = coleccion.id
  error.value = ''
  aviso.value = ''
  try {
    const guardada = await colecciones.setImagen(coleccion.id, archivo)
    aviso.value = `Cabecera de «${coleccion.name}» lista. ${guardada.optimizacion?.resumen || ''}`.trim()
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    subiendo.value = null
  }
}

async function quitarFoto(coleccion) {
  subiendo.value = coleccion.id
  error.value = ''
  aviso.value = ''
  try {
    await colecciones.setImagen(coleccion.id, null)
    aviso.value = `«${coleccion.name}» se queda sin foto de cabecera. Sus productos siguen saliendo en la portada.`
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    subiendo.value = null
  }
}

async function alternar(coleccion) {
  error.value = ''
  try {
    await colecciones.togglePublicada(coleccion)
  } catch (fallo) {
    error.value = fallo.message
  }
}

async function mover(coleccion, direccion) {
  error.value = ''
  try {
    await colecciones.mover(coleccion.id, direccion)
  } catch (fallo) {
    error.value = fallo.message
  }
}

async function confirmarBorrado() {
  const coleccion = porBorrar.value
  porBorrar.value = null
  error.value = ''
  try {
    await colecciones.remove(coleccion)
    if (form.id === coleccion.id) limpiar()
    aviso.value = `«${coleccion.name}» borrada. Sus productos siguen en el catálogo, sin colección.`
  } catch (fallo) {
    error.value = fallo.message
  }
}

/**
 * El interruptor de la sección entera.
 *
 * Apagarlo esconde el bloque de la portada SIN despublicar ninguna colección:
 * al volver a encenderlo todo está como estaba. Es la diferencia con
 * despublicarlas una a una, que además obliga a acordarse de cuáles estaban
 * publicadas.
 */
async function alternarSeccion() {
  error.value = ''
  const nuevo = seccionVisible.value ? 'false' : 'true'
  try {
    await settings.saveSettings({ homeCollectionsVisible: nuevo })
    aviso.value = nuevo === 'true'
      ? 'La sección Colecciones vuelve a verse en la portada.'
      : 'La sección Colecciones queda oculta en la portada. Las colecciones no se han tocado.'
  } catch (fallo) {
    error.value = fallo.message
  }
}
</script>

<template>
  <div class="rounded-2xl bg-white p-5 shadow-sm">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h3 class="flex items-center gap-2 text-lg font-bold text-black">
          Colecciones
          <AyudaInfo
            titulo="Colecciones"
            texto="Una colección agrupa productos que se venden juntos aunque sean de categorías y marcas distintas: «Colección Alisia» puede llevar una base, dos labiales y un rubor. En la portada, cada colección publicada es una fila con su título y un carrusel de SUS productos, con foto y precio. A qué colección pertenece cada producto se elige en la ficha del producto, en Básicos."
            donde="En la portada, debajo de la historia de la tienda, y en el desplegable Colecciones de la tienda."
          />
        </h3>
        <p class="mt-1 max-w-2xl text-sm leading-6 text-neutral-500">
          Sale en la portada si está <strong>publicada</strong> y tiene
          <strong>al menos un producto a la venta</strong>. La foto de cabecera es opcional.
        </p>
      </div>

      <button
        class="inline-flex min-h-10 items-center gap-2 rounded-full px-4 text-xs font-bold transition"
        :class="seccionVisible
          ? 'bg-pink-50 text-[var(--primary)] hover:bg-pink-100'
          : 'bg-neutral-200 text-neutral-600 hover:bg-neutral-300'"
        :aria-pressed="seccionVisible"
        @click="alternarSeccion"
      >
        <component :is="seccionVisible ? Eye : EyeOff" class="size-4" />
        {{ seccionVisible ? 'Sección visible' : 'Sección oculta' }}
      </button>
    </div>

    <p v-if="!seccionVisible" class="mt-4 rounded-xl bg-amber-50 p-3 text-sm leading-6 text-amber-800">
      La sección está apagada: nada de lo que hay aquí se ve en la portada.
      Las colecciones siguen guardadas y el filtro de la tienda sigue funcionando.
    </p>

    <p v-if="error" class="mt-4 rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="aviso" class="mt-4 rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">{{ aviso }}</p>

    <!-- Alta y edición, el mismo formulario. -->
    <form class="mt-4 rounded-2xl bg-pink-50/60 p-4" @submit.prevent="guardar">
      <div class="flex flex-col gap-3 sm:flex-row">
        <input
          v-model="form.name"
          required
          maxlength="60"
          class="min-w-0 flex-1 rounded-xl border border-pink-100 bg-white px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]"
          placeholder="Nombre de la colección — por ejemplo, Alisia"
        />
        <input
          v-model="form.description"
          class="min-w-0 flex-1 rounded-xl border border-pink-100 bg-white px-4 py-2.5 text-sm outline-none focus:border-[var(--primary)]"
          placeholder="Subtítulo (opcional) — «Todo lo que usa Alisia»"
        />
        <div class="flex gap-2">
          <button
            type="submit"
            class="min-h-11 whitespace-nowrap rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          >
            {{ editando ? 'Guardar cambios' : 'Crear colección' }}
          </button>
          <button
            v-if="editando"
            type="button"
            class="grid size-11 place-items-center rounded-full bg-white text-neutral-500 transition hover:text-black"
            title="Cancelar la edición"
            @click="limpiar"
          ><X class="size-4" /></button>
        </div>
      </div>
      <p class="mt-2 text-xs leading-5 text-neutral-500">
        El nombre es el título grande de la fila y el subtítulo va debajo, en gris.
        Los dos se ven en la portada.
      </p>
    </form>

    <!-- El tamaño recomendado, donde se sube la foto. Sin este dato la gente
         sube capturas de pantalla verticales y la cabecera sale recortada por
         el centro, que es el motivo por el que la portada se ve mal. -->
    <p class="mt-3 rounded-xl bg-pink-50/70 px-4 py-3 text-xs leading-5 text-neutral-600">
      <strong>Foto de cabecera:</strong> 1600 × 500 px (apaisada, 16:5). Mínimo 1200 × 375.
      Se recorta por arriba y por abajo en el móvil, así que deja lo importante en el centro.
      JPG o PNG; se optimiza sola al subirla.
    </p>

    <ul class="mt-4 space-y-2">
      <li
        v-for="coleccion in lista" :key="coleccion.id"
        class="flex flex-wrap items-center gap-3 rounded-xl border border-pink-100 p-3"
      >
        <div class="grid size-16 shrink-0 place-items-center overflow-hidden rounded-lg bg-neutral-100">
          <img v-if="coleccion.imageUrl" :src="coleccion.imageUrl" :alt="coleccion.name" class="h-full w-full object-cover" />
          <span v-else class="px-1 text-center text-[11px] leading-4 text-neutral-400">Sin foto</span>
        </div>

        <div class="min-w-0 flex-1">
          <p class="truncate font-bold text-neutral-800">{{ coleccion.name }}</p>
          <p class="text-xs leading-5 text-neutral-500">
            {{ cuantosProductos(coleccion.id) }} producto(s)
            <span class="mx-1.5 text-neutral-300">•</span>
            <span v-if="!coleccion.published">Sin publicar — no sale en la tienda</span>
            <span v-else-if="!cuantosProductos(coleccion.id)">Publicada, pero sin productos todavía no sale en la portada</span>
            <span v-else>En la portada, en la posición {{ coleccion.position || 1 }}</span>
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-1.5">
          <button
            class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-pink-50 hover:text-[var(--primary)]"
            title="Subirla en la portada" aria-label="Subirla en la portada"
            @click="mover(coleccion, 'arriba')"
          ><ArrowUp class="size-4" /></button>
          <button
            class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-pink-50 hover:text-[var(--primary)]"
            title="Bajarla en la portada" aria-label="Bajarla en la portada"
            @click="mover(coleccion, 'abajo')"
          ><ArrowDown class="size-4" /></button>

          <button
            class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-pink-50 hover:text-[var(--primary)]"
            title="Cambiarle el nombre o la nota" aria-label="Cambiarle el nombre o la nota"
            @click="editar(coleccion)"
          ><Pencil class="size-4" /></button>

          <button
            class="inline-flex min-h-10 items-center gap-1.5 rounded-full px-3 text-xs font-bold transition"
            :class="coleccion.published
              ? 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
              : 'bg-neutral-100 text-neutral-600 hover:bg-neutral-200'"
            @click="alternar(coleccion)"
          >
            <component :is="coleccion.published ? Eye : EyeOff" class="size-3.5" />
            {{ coleccion.published ? 'Publicada' : 'Sin publicar' }}
          </button>

          <label
            class="inline-flex min-h-10 cursor-pointer items-center gap-1.5 rounded-full bg-pink-50 px-4 text-xs font-bold text-[var(--primary)] transition hover:bg-pink-100"
            :class="subiendo === coleccion.id ? 'pointer-events-none opacity-50' : ''"
          >
            <ImagePlus class="size-3.5" />
            {{ subiendo === coleccion.id ? 'Subiendo…' : (coleccion.imageUrl ? 'Cambiar cabecera' : 'Subir cabecera') }}
            <input type="file" accept="image/*" class="sr-only" @change="elegirFoto(coleccion, $event)" />
          </label>

          <button
            v-if="coleccion.imageUrl"
            :disabled="subiendo === coleccion.id"
            class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-neutral-100 hover:text-neutral-700 disabled:opacity-40"
            title="Quitarle la foto" aria-label="Quitarle la foto"
            @click="quitarFoto(coleccion)"
          ><X class="size-4" /></button>

          <button
            class="grid size-10 place-items-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600"
            title="Borrar la colección" aria-label="Borrar la colección"
            @click="porBorrar = coleccion"
          ><Trash2 class="size-4" /></button>
        </div>
      </li>

      <li v-if="!lista.length" class="rounded-xl border border-dashed border-pink-200 p-8 text-center text-sm leading-6 text-neutral-500">
        Todavía no hay ninguna colección, así que esa parte de la portada no se muestra.
        Crea la primera arriba y asígnale productos desde la ficha de cada uno.
      </li>
    </ul>

    <div v-if="porBorrar" class="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" @click.self="porBorrar = null">
      <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
        <h3 class="text-lg font-bold text-black">¿Borrar «{{ porBorrar.name }}»?</h3>
        <p class="mt-2 text-sm leading-6 text-neutral-600">
          Desaparece de la portada y de la tienda, y su foto de cabecera se elimina del almacenamiento.
        </p>
        <p class="mt-2 rounded-xl bg-pink-50 p-3 text-sm leading-6 text-neutral-700">
          <strong>{{ cuantosProductos(porBorrar.id) }} producto(s)</strong> quedan sin colección.
          No se borra ninguno: siguen publicados y a la venta como están.
        </p>
        <div class="mt-6 flex justify-end gap-3">
          <button class="rounded-full bg-neutral-200 px-5 py-2.5 text-sm font-bold text-neutral-700 transition hover:bg-neutral-300" @click="porBorrar = null">
            Cancelar
          </button>
          <button class="rounded-full bg-red-500 px-5 py-2.5 text-sm font-bold text-white transition hover:bg-red-600" @click="confirmarBorrado">
            Borrar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
