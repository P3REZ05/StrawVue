<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, ArrowRight, Check, Loader2, Lock } from 'lucide-vue-next'
import { useCatalogStore } from '../../stores/catalog'
import { useCollectionsStore } from '../../stores/collections'
import { useInventoryStore } from '../../stores/inventory'
import { formatCurrency } from '../../utils/formatCurrency'
import AyudaInfo from '../../components/admin/AyudaInfo.vue'
import QuickCreate from '../../components/admin/product/QuickCreate.vue'
import ImageUploader from '../../components/admin/product/ImageUploader.vue'
import Trazabilidad from '../../components/admin/product/Trazabilidad.vue'
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
const colecciones = useCollectionsStore()
const inventario = useInventoryStore()

// Cada sección lleva su propia explicación: qué se decide ahí y dónde acaba
// viéndose. Antes había que deducirlo, y un editor de seis pestañas con
// candados no se deduce.
const SECCIONES = [
  {
    id: 'basicos', label: 'Básicos',
    ayuda: 'Cómo se llama el producto y en qué parte de la tienda se clasifica. La categoría además decide qué campos aparecen en «Atributos».',
    donde: 'El nombre y la categoría salen en la tarjeta de la tienda y en la ficha del producto.'
  },
  {
    id: 'atributos', label: 'Atributos',
    ayuda: 'Las características por las que la clienta filtra: acabado, cobertura, tipo de piel, contenido. Solo aparecen las que tienen sentido para la categoría que elegiste.',
    donde: 'En los filtros de la tienda y en la ficha del producto.'
  },
  {
    id: 'tonos', label: 'Tonos',
    ayuda: 'La gama de colores. Cada tono tiene su propio SKU, su stock y, si quieres, su propio precio; si lo dejas vacío, hereda el del producto.',
    donde: 'Los círculos de color de la tarjeta y el selector de tono de la ficha.'
  },
  {
    id: 'imagenes', label: 'Imágenes',
    ayuda: 'Las fotos. La primera queda como principal. Se comprimen solas antes de subirse, así que puedes usar la foto del celular tal cual.',
    donde: 'La principal es la de la tarjeta; el resto forman la galería de la ficha.'
  },
  {
    id: 'precio', label: 'Precio y publicación',
    ayuda: 'Cuánto cuesta, qué etiquetas lleva y si está a la venta. Publicar exige tener unidades en la vitrina: compra al proveedor, pásalo de bodega a venta, y entonces se puede publicar.',
    donde: 'El precio en la tarjeta y en la ficha; el estado decide si la clienta ve el producto o no.'
  },
  {
    id: 'trazabilidad', label: 'Trazabilidad',
    ayuda: 'El historial: de qué compra vino cada unidad, cuándo se cambió el precio y quién lo cambió. Solo se lee, no se edita.',
    donde: 'Solo aquí. La clienta no ve nada de esto.'
  }
]

// Las que no funcionan sin un producto en la base. Estaba escrito a mano dos
// veces dentro del `v-for` de las pestañas, y dos copias acaban divergiendo.
const NECESITAN_PRODUCTO = ['tonos', 'imagenes', 'trazabilidad']

const seccion = ref('basicos')
const cargando = ref(true)
const guardando = ref(false)
const error = ref('')
const guardadoEn = ref('')

const productId = computed(() => (route.params.id === 'nuevo' ? null : Number(route.params.id)))

const form = reactive({
  id: null, name: '', description: '', category: '', categoryId: '', subcategoryId: '',
  brandId: '', collectionId: '', skinTypeId: '', finishId: '', coverageId: '', netContentMl: '', barcode: '',
  price: '', salePrice: '', status: 'draft'
})

// Las etiquetas se llevan aparte del `form` porque no son columnas de
// `products`: viven en su propia tabla y se guardan con su propia llamada.
const etiquetasElegidas = ref([])

/**
 * ¿Se puede publicar este producto?
 *
 * La regla de verdad está en la base (migración 021): un producto no pasa a
 * publicado sin unidades a la venta. Aquí se repite para poder explicarla
 * ANTES de que el usuario pulse y se lleve un error. La base sigue siendo la
 * que manda — esto es cortesía, no la comprobación.
 */
const saldo = computed(() => {
  if (!form.id) return { venta: 0, bodega: 0 }
  const filas = inventario.balances.filter((b) => b.productId === form.id)
  return {
    venta: filas.reduce((t, b) => t + (b.saleStock || 0), 0),
    bodega: filas.reduce((t, b) => t + (b.warehouseStock || 0), 0)
  }
})

const puedePublicar = computed(() => saldo.value.venta > 0)

const porQueNoPuedePublicar = computed(() => {
  if (puedePublicar.value) return ''
  if (!form.id) return 'Guarda el producto primero.'
  if (saldo.value.bodega > 0) {
    return `Tienes ${saldo.value.bodega} unidad(es) en bodega y ninguna a la venta. Pásalas a la vitrina desde Inventario › Bodega.`
  }
  return 'Todavía no tiene existencias. Regístrale la compra al proveedor en Inventario › Compras, pásala de bodega a la vitrina y vuelve aquí.'
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
    // Para el selector de colección. No se espera: si tarda o falla, el resto
    // del editor funciona igual y el selector queda con «Sin colección».
    colecciones.init().catch(() => {})
    // Los saldos hacen falta para saber si el producto se puede publicar, y
    // aquí hacen falta COMPLETOS: para distinguir «no lo has comprado» de «lo
    // tienes en bodega» hay que ver la bodega, y `init()` solo carga lo que
    // puede ver una clienta. Esta ruta no monta `AdminPanel`, así que nadie
    // más lo pide por ella. Si falla, el editor sigue usable: la regla de
    // verdad vive en la base.
    inventario.init()
      .then(() => inventario.refreshBalances())
      .catch(() => {})
    if (productId.value) {
      const producto = catalogo.productById(productId.value)
      if (!producto) throw new Error('No se encontró el producto.')
      etiquetasElegidas.value = catalogo.badgesOf(productId.value).map((b) => b.id)
      Object.assign(form, {
        ...producto,
        categoryId: producto.categoryId || '',
        subcategoryId: producto.subcategoryId || '',
        brandId: producto.brandId || '',
        collectionId: producto.collectionId || '',
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

/**
 * Guarda y devuelve si lo consiguió.
 *
 * El booleano importa: `irASeccion` lo necesita para no abrir Imágenes cuando
 * el guardado falló. Antes esta función no devolvía nada y no había forma de
 * encadenar «guarda y luego llévame ahí».
 */
async function guardar() {
  error.value = ''
  if (!form.name.trim()) {
    error.value = 'Ponle un nombre al producto para poder guardarlo.'
    seccion.value = 'basicos'
    return false
  }
  guardando.value = true
  try {
    const guardado = await catalogo.saveProduct({
      ...form,
      categoryId: form.categoryId || null,
      subcategoryId: form.subcategoryId || null,
      brandId: form.brandId || null,
      collectionId: form.collectionId || null,
      skinTypeId: atributos.value.skinType ? form.skinTypeId || null : null,
      finishId: atributos.value.finish ? form.finishId || null : null,
      coverageId: atributos.value.coverage ? form.coverageId || null : null,
      netContentMl: atributos.value.netContent ? Number(form.netContentMl) || null : null
    })
    // Sin `id` no hay producto, aunque la base no se haya quejado. Sin esta
    // comprobación `form.id` se quedaba en `undefined`, las pestañas seguían
    // con candado y cada clic volvía a guardar: productos duplicados en
    // silencio. Es la cuarta vez que este proyecto se topa con «la pantalla
    // dice que guardó y no guardó».
    if (!guardado?.id) {
      error.value = 'El producto no se guardó. Vuelve a intentarlo; si sigue, revisa tu sesión de administrador.'
      return false
    }

    form.id = guardado.id

    // Las etiquetas van en su propia tabla, así que es una segunda escritura.
    // Si falla, el producto SÍ se guardó: hay que decirlo con precisión en vez
    // de dar por bueno el guardado entero o darlo por perdido.
    try {
      await catalogo.setProductBadges(guardado.id, etiquetasElegidas.value)
    } catch (fallo) {
      error.value = `El producto se guardó, pero las etiquetas no: ${fallo.message}`
      return false
    }

    guardadoEn.value = new Date().toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' })
    if (!productId.value) router.replace(`/admin/productos/${guardado.id}`)
    return true
  } catch (e) {
    error.value = e?.message || 'No se pudo guardar el producto.'
    return false
  } finally {
    guardando.value = false
  }
}

/**
 * Cambia de sección, guardando primero si hace falta.
 *
 * Tonos, imágenes y trazabilidad necesitan que el producto exista: una fila de
 * `product_images` apunta a un `product_id` y el archivo va a
 * `productos/{id}/…` en Storage. Sin `id` no hay dónde colgar nada.
 *
 * Antes esas tres pestañas estaban simplemente `disabled`: al tocarlas no
 * pasaba nada de nada. El aviso existía —un texto gris de 12px bajo el
 * título—, pero un botón que no responde no es un aviso, es un callejón sin
 * salida. Ahora se guarda el borrador y se entra. El producto nace como
 * `draft`, así que guardarlo no lo publica ni lo enseña a nadie.
 */
async function irASeccion(id) {
  if (!NECESITAN_PRODUCTO.includes(id) || form.id) {
    seccion.value = id
    return
  }
  if (!(await guardar())) return   // el error ya quedó a la vista
  seccion.value = id
}

// Flechas entre secciones. El editor tiene seis pestañas y el recorrido
// natural es de izquierda a derecha; obligar a volver arriba a buscar la
// siguiente convierte un formulario largo en una caza del tesoro.
const indiceSeccion = computed(() => SECCIONES.findIndex((s) => s.id === seccion.value))
const seccionAnterior = computed(() => SECCIONES[indiceSeccion.value - 1] || null)
const seccionSiguiente = computed(() => SECCIONES[indiceSeccion.value + 1] || null)

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
              <span v-else>Borrador sin guardar · nadie lo ve hasta que lo publiques</span>
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
          class="inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-xs font-bold transition disabled:opacity-60"
          :class="seccion === s.id ? 'bg-[var(--primary)] text-white shadow-sm' : 'bg-white text-neutral-600 hover:bg-pink-50'"
          :disabled="guardando"
          :title="!puedeUsarSecciones && NECESITAN_PRODUCTO.includes(s.id)
            ? 'Se guardará el borrador para poder abrir esta sección'
            : ''"
          @click="irASeccion(s.id)"
        >
          {{ s.label }}
          <!-- El candado dice que falta un paso, no que esté prohibido: al
               tocarlo se guarda el borrador y entra. -->
          <Lock
            v-if="!puedeUsarSecciones && NECESITAN_PRODUCTO.includes(s.id)"
            class="size-3 opacity-60"
            aria-hidden="true"
          />
        </button>
      </nav>

      <!-- Qué es la sección en la que estás, con su ayuda al lado. -->
      <div class="flex items-start justify-between gap-3 rounded-xl bg-white/70 px-4 py-3">
        <p class="text-xs leading-5 text-neutral-500">
          {{ SECCIONES[indiceSeccion]?.ayuda }}
        </p>
        <AyudaInfo
          :titulo="SECCIONES[indiceSeccion]?.label"
          :texto="SECCIONES[indiceSeccion]?.ayuda || ''"
          :donde="SECCIONES[indiceSeccion]?.donde || ''"
        />
      </div>

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

            <div>
              <span class="flex items-center gap-2 text-sm font-bold text-neutral-700">
                Colección
                <AyudaInfo
                  titulo="Colección"
                  texto="Agrupa productos que se venden juntos, aunque sean de categorías y marcas distintas: «Colección Alisia» puede llevar una base, dos labiales y un rubor. Un producto pertenece como mucho a una. Las colecciones se crean en Configuración; si borras una, sus productos NO se borran: se quedan sin colección."
                  donde="En la portada, en el bloque Colecciones (solo si la colección está publicada y tiene foto), y en el desplegable Colecciones de la tienda."
                />
              </span>
              <select v-model="form.collectionId" class="mt-1 w-full rounded-xl border border-pink-100 px-4 py-2.5 text-sm">
                <option value="">Sin colección</option>
                <option v-for="c in colecciones.ordenadas" :key="c.id" :value="c.id">
                  {{ c.name }}{{ c.published ? '' : ' (sin publicar)' }}
                </option>
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

          <!-- ETIQUETAS. Antes eran tres casillas fijas que, además, no se
               veían en ninguna parte de la tienda. -->
          <div class="border-t border-pink-100 pt-4">
            <div class="flex items-center justify-between">
              <p class="text-sm font-bold text-neutral-700">Etiquetas</p>
              <AyudaInfo
                titulo="Etiquetas"
                texto="Distintivos que llaman la atención sobre la foto: VIRAL, NUEVO, lo que crees tú. NO cambian el precio — para descontar de verdad usa Promociones. Se crean y se editan en la sección Etiquetas del panel."
                donde="Sobre la foto en la tarjeta de la tienda (máximo dos) y encima del nombre en la ficha del producto."
              />
            </div>

            <div v-if="catalogo.activeBadges.length" class="mt-3 flex flex-wrap gap-2">
              <button
                v-for="etiqueta in catalogo.activeBadges" :key="etiqueta.id"
                type="button"
                class="rounded-full px-4 py-2 text-xs font-bold uppercase tracking-wide transition"
                :class="etiquetasElegidas.includes(etiqueta.id)
                  ? 'ring-2 ring-black ring-offset-2'
                  : 'opacity-40 hover:opacity-70'"
                :style="{ background: etiqueta.colorFondo, color: etiqueta.colorTexto }"
                :aria-pressed="etiquetasElegidas.includes(etiqueta.id)"
                @click="etiquetasElegidas.includes(etiqueta.id)
                  ? etiquetasElegidas = etiquetasElegidas.filter((id) => id !== etiqueta.id)
                  : etiquetasElegidas.push(etiqueta.id)"
              >{{ etiqueta.name }}</button>
            </div>
            <p v-else class="mt-2 text-xs text-neutral-500">
              No hay etiquetas creadas. Se crean en <strong>Etiquetas</strong>, en el menú del panel.
            </p>
            <p v-if="etiquetasElegidas.length > 2" class="mt-2 text-xs text-amber-600">
              En la tarjeta de la tienda solo caben dos. Las demás se ven en la ficha del producto.
            </p>
          </div>

          <!-- PUBLICACIÓN -->
          <div class="border-t border-pink-100 pt-4">
            <div class="flex items-center justify-between">
              <p class="text-sm font-bold text-neutral-700">Estado de publicación</p>
              <AyudaInfo
                titulo="Estado de publicación"
                texto="Borrador y Pausado no se ven en la tienda; Activo sí. Para publicar hace falta tener unidades en la vitrina: se compra al proveedor, entra a bodega y de ahí se pasa a venta. Publicar algo sin existencias es enseñarle a la clienta un producto que no le puedes vender."
                donde="Decide si la clienta ve el producto en la tienda o no."
              />
            </div>

            <!-- El aviso va ANTES de los botones, no después de un error: la
                 regla la impone la base, pero enterarse al pulsar es peor que
                 saberlo antes. -->
            <p
              v-if="!puedePublicar"
              class="mt-3 rounded-xl bg-amber-50 px-4 py-3 text-xs leading-5 font-semibold text-amber-800"
            >
              Todavía no se puede publicar. {{ porQueNoPuedePublicar }}
            </p>
            <p v-else class="mt-3 text-xs text-neutral-500">
              Hay <strong>{{ saldo.venta }}</strong> unidad(es) a la venta: ya se puede publicar.
            </p>

            <div class="mt-3 flex flex-wrap gap-2">
              <button
                v-for="e in [
                  { v: 'draft', t: 'Borrador' }, { v: 'active', t: 'Activo' },
                  { v: 'paused', t: 'Pausado' }, { v: 'archived', t: 'Archivado' }
                ]"
                :key="e.v" type="button"
                class="rounded-full px-4 py-2 text-xs font-bold transition disabled:cursor-not-allowed disabled:opacity-40"
                :class="form.status === e.v ? 'bg-[var(--primary)] text-white' : 'bg-pink-50 text-neutral-600 hover:bg-pink-100'"
                :disabled="e.v === 'active' && !puedePublicar && form.status !== 'active'"
                :title="e.v === 'active' && !puedePublicar ? porQueNoPuedePublicar : ''"
                @click="form.status = e.v"
              >{{ e.t }}</button>
            </div>
          </div>
        </section>

        <!-- TRAZABILIDAD -->
        <Trazabilidad v-else-if="seccion === 'trazabilidad' && form.id" :product-id="form.id" />

        <!-- Red de seguridad. Con el guardado automático no debería verse
             nunca, pero si el guardado falla la sección queda sin producto y
             una pantalla en blanco no explica nada. -->
        <div v-else class="rounded-xl border border-dashed border-pink-200 p-8 text-center">
          <p class="text-sm text-neutral-600">
            Esta sección necesita que el producto esté guardado.
          </p>
          <button
            class="mt-4 inline-flex h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)]"
            :disabled="guardando"
            @click="guardar"
          >
            <Loader2 v-if="guardando" class="size-4 animate-spin" />
            <Check v-else class="size-4" />
            {{ guardando ? 'Guardando…' : 'Guardar borrador' }}
          </button>
        </div>
      </div>

      <!-- Flechas. Crear un producto es un recorrido de seis paradas y hasta
           ahora había que volver arriba a buscar la siguiente pestaña cada
           vez. «Siguiente» además guarda si la sección lo necesita, igual que
           las pestañas. -->
      <nav v-if="!cargando" class="flex items-center justify-between gap-3">
        <button
          v-if="seccionAnterior" type="button" :disabled="guardando"
          class="inline-flex min-h-11 items-center gap-2 rounded-full bg-white px-5 text-sm font-bold text-neutral-600 shadow-sm transition hover:text-[var(--primary)] disabled:opacity-50"
          @click="irASeccion(seccionAnterior.id)"
        >
          <ArrowLeft class="size-4" /> {{ seccionAnterior.label }}
        </button>
        <span v-else />

        <button
          v-if="seccionSiguiente" type="button" :disabled="guardando"
          class="inline-flex min-h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          @click="irASeccion(seccionSiguiente.id)"
        >
          {{ seccionSiguiente.label }} <ArrowRight class="size-4" />
        </button>
        <button
          v-else type="button" :disabled="guardando"
          class="inline-flex min-h-11 items-center gap-2 rounded-full bg-[var(--primary)] px-5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
          @click="router.push('/admin/dashboard')"
        >
          Terminar <Check class="size-4" />
        </button>
      </nav>
    </div>
  </main>
</template>
