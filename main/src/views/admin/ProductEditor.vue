<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Check, Loader2 } from 'lucide-vue-next'
import { useCatalogStore } from '../../stores/catalog'
import { formatCurrency } from '../../utils/formatCurrency'
import QuickCreate from '../../components/admin/product/QuickCreate.vue'
import ImageUploader from '../../components/admin/product/ImageUploader.vue'
import ShadeEditor from '../../components/admin/product/ShadeEditor.vue'

// Editor de producto a página completa.
//
// Sustituye al modal que mezclaba alta, edición y filtros. El modal se quedaba
// corto en cuanto un producto tenía cuarenta tonos, y obligaba a salir del
// formulario para crear una marca que faltaba.
//
// El producto se guarda como borrador en cuanto tiene nombre: así las secciones
// de tonos e imágenes, que necesitan un id, están disponibles enseguida y nada
// se pierde si se cierra la pestaña a medias.

const route = useRoute()
const router = useRouter()
const catalogo = useCatalogStore()

const SECCIONES = [
  { id: 'basicos', label: 'Básicos' },
  { id: 'atributos', label: 'Atributos' },
  { id: 'tonos', label: 'Tonos' },
  { id: 'imagenes', label: 'Imágenes' },
  { id: 'precio', label: 'Precio y publicación' },
  { id: 'trazabilidad', label: 'Trazabilidad' }
]

const seccion = ref('basicos')
const cargando = ref(true)
const guardando = ref(false)
const error = ref('')
const guardadoEn = ref('')

const productId = computed(() => (route.params.id === 'nuevo' ? null : Number(route.params.id)))

const form = reactive({
  id: null, name: '', description: '', category: '', categoryId: '', subcategoryId: '',
  brandId: '', skinTypeId: '', finishId: '', coverageId: '', netContentMl: '', barcode: '',
  price: '', salePrice: '', isFeatured: false, isNew: true, isRecommended: false, status: 'draft'
})

// La categoría decide qué atributos tienen sentido: cobertura solo en bases,
// tipo de piel solo en cuidado facial. Mostrar todo siempre es lo que hacía
// que esos campos se guardaran vacíos.
const atributos = computed(() => catalogo.atributosAplicables(form.category))
const subcategorias = computed(() => (form.categoryId ? catalogo.subcategoriesOf(Number(form.categoryId)) : []))
const puedeUsarSecciones = computed(() => Boolean(form.id))

watch(() => form.categoryId, (id) => {
  const cat = catalogo.categories.find((c) => c.id === Number(id))
  form.category = cat?.name || ''
  if (form.subcategoryId && !subcategorias.value.some((s) => s.id === Number(form.subcategoryId))) {
    form.subcategoryId = ''
  }
})

onMounted(async () => {
  try {
    await catalogo.init()
    if (productId.value) {
      const producto = catalogo.productById(productId.value)
      if (!producto) throw new Error('No se encontró el producto.')
      Object.assign(form, {
        ...producto,
        categoryId: producto.categoryId || '',
        subcategoryId: producto.subcategoryId || '',
        brandId: producto.brandId || '',
        skinTypeId: producto.skinTypeId || '',
        finishId: producto.finishId || '',
        coverageId: producto.coverageId || '',
        netContentMl: producto.netContentMl || '',
        salePrice: producto.salePrice || ''
      })
    }
  } catch (e) {
    error.value = e?.message || 'No se pudo cargar el producto.'
  } finally {
    cargando.value = false
  }
})

async function guardar() {
  error.value = ''
  if (!form.name.trim()) {
    error.value = 'El producto necesita un nombre.'
    seccion.value = 'basicos'
    return
  }
  guardando.value = true
  try {
    const guardado = await catalogo.saveProduct({
      ...form,
      categoryId: form.categoryId || null,
      subcategoryId: form.subcategoryId || null,
      brandId: form.brandId || null,
      skinTypeId: atributos.value.skinType ? form.skinTypeId || null : null,
      finishId: atributos.value.finish ? form.finishId || null : null,
      coverageId: atributos.value.coverage ? form.coverageId || null : null,
      netContentMl: atributos.value.netContent ? Number(form.netContentMl) || null : null
    })
    form.id = guardado.id
    guardadoEn.value = new Date().toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' })
    if (!productId.value) router.replace(`/admin/productos/${guardado.id}`)
  } catch (e) {
    error.value = e?.message || 'No se pudo guardar el producto.'
  } finally {
    guardando.value = false
  }
}

async function crearCategoria({ nombre }) {
  const creada = await catalogo.saveCategory({ name: nombre })
  form.categoryId = creada.id
}
async function crearOpcion(tipo, { nombre, extra }) {
  const creada = await catalogo.saveOption(tipo, { name: nombre, code: extra, swatchHex: extra })
  const campo = { brands: 'brandId', skinTypes: 'skinTypeId', finishes: 'finishId', coverages: 'coverageId' }[tipo]
  if (campo) form[campo] = creada.id
}
</script>

<template>
  <main class="min-h-screen bg-pink-50/40 p-5 sm:p-8">
    <div class="mx-auto max-w-5xl space-y-5">
      <!-- Cabecera -->
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex items-center gap-3">
          <button
            class="rounded-full bg-white p-2 text-neutral-600 shadow-sm transition hover:text-[var(--primary)]"
            @click="router.push('/admin/dashboard')"
          >
            <ArrowLeft class="size-5" />
          </button>
          <div>
            <h1 class="text-2xl font-bold text-black">{{ form.id ? form.name || 'Producto' : 'Nuevo producto' }}</h1>
            <p class="text-xs text-neutral-500">
              <span v-if="guardadoEn" class="text-emerald-600">Guardado a las {{ guardadoEn }}</span>
              <span v-else-if="form.id">Editando · borrador guardado</span>
              <span v-else>Escribe el nombre y guarda para habilitar tonos e imágenes</span>
            </p>
          </div>
        </div>
        <button
          :disabled="guardando"
          class="inline-flex items-center gap-2 rounded-full bg-[var(--primary)] px-6 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          @click="guardar"
        >
          <Loader2 v-if="guardando" class="size-4 animate-spin" />
          <Check v-else class="size-4" />
          {{ guardando ? 'Guardando…' : 'Guardar' }}
        </button>
      </div>

      <p v-if="error" class="rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-600">{{ error }}</p>

      <!-- Secciones -->
      <nav class="flex flex-wrap gap-2">
        <button
          v-for="s in SECCIONES" :key="s.id"
          class="rounded-full px-4 py-2 text-xs font-bold transition"
          :class="[
            seccion === s.id ? 'bg-[var(--primary)] text-white shadow-sm' : 'bg-white text-neutral-600 hover:bg-pink-50',
            !puedeUsarSecciones && ['tonos', 'imagenes', 'trazabilidad'].includes(s.id) ? 'cursor-not-allowed opacity-40' : ''
          ]"
          :disabled="!puedeUsarSecciones && ['tonos', 'imagenes', 'trazabilidad'].includes(s.id)"
          @click="seccion = s.id"
        >
          {{ s.label }}
        </button>
      </nav>

      <div v-if="cargando" class="rounded-2xl bg-white p-10 text-center text-neutral-500">Cargando…</div>

      <div v-else class="rounded-2xl bg-white p-5 shadow-sm sm:p-6">
        <!-- BÁSICOS -->
        <section v-if="seccion === 'basicos'" class="space-y-4">
          <label class="block text-sm font-bold text-neutral-700">Nombre del producto *
            <input v-model="form.name" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 font-normal outline-none focus:border-[var(--primary)]" placeholder="Base Velvet Skin" />
          </label>

          <div class="grid gap-4 md:grid-cols-2">
            <div>
              <span class="flex items-center justify-between text-sm font-bold text-neutral-700">
                Categoría *
                <QuickCreate etiqueta="Categoría" @crear="crearCategoria" />
              </span>
              <select v-model="form.categoryId" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm">
                <option value="">Seleccionar categoría</option>
                <option v-for="c in catalogo.rootCategories" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
            </div>

            <div>
              <span class="flex items-center justify-between text-sm font-bold text-neutral-700">
                Marca
                <QuickCreate etiqueta="Marca" @crear="(d) => crearOpcion('brands', d)" />
              </span>
              <select v-model="form.brandId" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm">
                <option value="">Sin marca</option>
                <option v-for="b in catalogo.brands" :key="b.id" :value="b.id">{{ b.name }}</option>
              </select>
            </div>

            <label v-if="subcategorias.length" class="text-sm font-bold text-neutral-700">Subcategoría
              <select v-model="form.subcategoryId" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm font-normal">
                <option value="">Sin subcategoría</option>
                <option v-for="s in subcategorias" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
            </label>

            <label class="text-sm font-bold text-neutral-700">Código de barras
              <input v-model="form.barcode" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 font-normal" />
            </label>
          </div>

          <label class="block text-sm font-bold text-neutral-700">Descripción
            <textarea v-model="form.description" rows="4" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 font-normal outline-none focus:border-[var(--primary)]" />
          </label>
        </section>

        <!-- ATRIBUTOS -->
        <section v-else-if="seccion === 'atributos'" class="space-y-4">
          <p class="text-sm text-neutral-500">
            Solo se muestran los atributos que aplican a
            <strong>{{ form.category || 'la categoría elegida' }}</strong>.
            Cambia la categoría en Básicos si esperabas ver otros.
          </p>

          <div class="grid gap-4 md:grid-cols-2">
            <div v-if="atributos.skinType">
              <span class="flex items-center justify-between text-sm font-bold text-neutral-700">
                Tipo de piel <QuickCreate etiqueta="Tipo de piel" @crear="(d) => crearOpcion('skinTypes', d)" />
              </span>
              <select v-model="form.skinTypeId" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm">
                <option value="">Sin definir</option>
                <option v-for="o in catalogo.skinTypes" :key="o.id" :value="o.id">{{ o.name }}</option>
              </select>
            </div>

            <div v-if="atributos.finish">
              <span class="flex items-center justify-between text-sm font-bold text-neutral-700">
                Acabado <QuickCreate etiqueta="Acabado" @crear="(d) => crearOpcion('finishes', d)" />
              </span>
              <select v-model="form.finishId" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm">
                <option value="">Sin definir</option>
                <option v-for="o in catalogo.finishes" :key="o.id" :value="o.id">{{ o.name }}</option>
              </select>
            </div>

            <div v-if="atributos.coverage">
              <span class="flex items-center justify-between text-sm font-bold text-neutral-700">
                Cobertura <QuickCreate etiqueta="Cobertura" @crear="(d) => crearOpcion('coverages', d)" />
              </span>
              <select v-model="form.coverageId" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm">
                <option value="">Sin definir</option>
                <option v-for="o in catalogo.coverages" :key="o.id" :value="o.id">{{ o.name }}</option>
              </select>
            </div>

            <label v-if="atributos.netContent" class="text-sm font-bold text-neutral-700">Contenido neto (ml)
              <input v-model="form.netContentMl" type="number" min="0" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 font-normal" />
            </label>
          </div>

          <p v-if="!Object.values(atributos).some(Boolean)" class="rounded-xl border border-dashed border-pink-200 p-6 text-center text-sm text-neutral-500">
            Esta categoría no usa atributos específicos de maquillaje.
          </p>
        </section>

        <!-- TONOS -->
        <ShadeEditor v-else-if="seccion === 'tonos' && form.id" :product-id="form.id" />

        <!-- IMÁGENES -->
        <ImageUploader
          v-else-if="seccion === 'imagenes' && form.id"
          :product-id="form.id"
          titulo="Imágenes del producto"
          descripcion="La primera que subas queda como principal. Se optimizan solas antes de subirse."
        />

        <!-- PRECIO Y PUBLICACIÓN -->
        <section v-else-if="seccion === 'precio'" class="space-y-5">
          <div class="grid gap-4 md:grid-cols-2">
            <label class="text-sm font-bold text-neutral-700">Precio base *
              <input v-model="form.price" type="number" min="0" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 font-normal" />
            </label>
            <label class="text-sm font-bold text-neutral-700">Precio promocional
              <input v-model="form.salePrice" type="number" min="0" placeholder="Sin promoción" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 font-normal" />
            </label>
          </div>
          <p class="text-xs text-neutral-500">
            Los tonos heredan este precio salvo que se les ponga uno propio.
            El cliente vería <strong>{{ formatCurrency(Number(form.salePrice) || Number(form.price) || 0) }}</strong>.
          </p>

          <div class="flex flex-wrap gap-4 border-t border-pink-100 pt-4">
            <label class="inline-flex items-center gap-2 text-sm font-semibold text-neutral-700">
              <input v-model="form.isFeatured" type="checkbox" class="size-4 accent-[var(--primary)]" /> Destacado
            </label>
            <label class="inline-flex items-center gap-2 text-sm font-semibold text-neutral-700">
              <input v-model="form.isNew" type="checkbox" class="size-4 accent-[var(--primary)]" /> Nuevo
            </label>
            <label class="inline-flex items-center gap-2 text-sm font-semibold text-neutral-700">
              <input v-model="form.isRecommended" type="checkbox" class="size-4 accent-[var(--primary)]" /> Recomendado
            </label>
          </div>

          <div class="border-t border-pink-100 pt-4">
            <p class="text-sm font-bold text-neutral-700">Estado de publicación</p>
            <p class="mt-1 text-xs text-neutral-500">Solo los productos <strong>activos</strong> se muestran en la tienda.</p>
            <div class="mt-3 flex flex-wrap gap-2">
              <button
                v-for="e in [
                  { v: 'draft', t: 'Borrador' }, { v: 'active', t: 'Activo' },
                  { v: 'paused', t: 'Pausado' }, { v: 'archived', t: 'Archivado' }
                ]"
                :key="e.v" type="button"
                class="rounded-full px-4 py-2 text-xs font-bold transition"
                :class="form.status === e.v ? 'bg-[var(--primary)] text-white' : 'bg-pink-50 text-neutral-600 hover:bg-pink-100'"
                @click="form.status = e.v"
              >{{ e.t }}</button>
            </div>
          </div>
        </section>

        <!-- TRAZABILIDAD -->
        <section v-else-if="seccion === 'trazabilidad'" class="rounded-xl border border-dashed border-pink-200 p-8 text-center">
          <p class="text-sm font-bold text-neutral-700">Línea de tiempo del producto</p>
          <p class="mx-auto mt-2 max-w-md text-sm text-neutral-500">
            Aquí se mostrará quién creó el producto, cada cambio de precio, las compras al proveedor,
            las transferencias a venta y las unidades vendidas. Los datos ya se están registrando en
            <code>audit_logs</code> e <code>inventory_movements</code>.
          </p>
        </section>

        <div v-else class="rounded-xl border border-dashed border-pink-200 p-8 text-center text-sm text-neutral-500">
          Guarda el producto para habilitar esta sección.
        </div>
      </div>
    </div>
  </main>
</template>
