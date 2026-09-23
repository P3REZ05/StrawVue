<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { Trash2, Eye, EyeOff, Upload } from 'lucide-vue-next'
import { useSettingsStore } from '../../stores/settings'
import AdminColecciones from './AdminColecciones.vue'
import { useAdminStore } from '../../stores/admin'
import { formatCurrency } from '../../utils/formatCurrency'

// Esta pantalla escribía en `localStorage` y leía de `mockData`. Cero
// Supabase. Los dos efectos que tenía eso:
//   · el costo de envío del checkout salía de una constante en un archivo,
//     mientras el servidor cobraba el de `store_settings`;
//   · los banners de la portada solo existían en el navegador que los creó,
//     con las imágenes en base64 dentro de localStorage.
const settings = useSettingsStore()
const admin = useAdminStore()

const cargando = ref(true)
const guardando = ref(false)
const error = ref('')
const aviso = ref('')

const form = reactive({
  shippingCost: '',
  freeShippingThreshold: '',
  whatsappNumber: '',
  socialFacebook: '',
  socialTiktok: '',
  socialInstagram: ''
})

const banner = reactive({
  id: null, title: '', subtitle: '', accent: '', link: '/tienda',
  image_url: '', image_path: '', active: true
})
const subiendo = ref(false)
const resumenImagen = ref('')
const porBorrar = ref(null)

const CLAVES = Object.keys(form)

const sinCambios = computed(() => CLAVES.every((k) => String(settings.valores[k] ?? '') === String(form[k])))

const ejemploEnvio = computed(() => {
  const umbral = Number(form.freeShippingThreshold) || 0
  const costo = Number(form.shippingCost) || 0
  if (!umbral) return `Todos los pedidos pagan ${formatCurrency(costo)} de envío.`
  return `Por debajo de ${formatCurrency(umbral)} el cliente paga ${formatCurrency(costo)}. Desde ${formatCurrency(umbral)}, envío gratis.`
})

function rellenar() {
  CLAVES.forEach((k) => { form[k] = String(settings.valores[k] ?? '') })
}

onMounted(async () => {
  try {
    await settings.init()
    rellenar()
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    cargando.value = false
  }
})

async function guardarAjustes() {
  error.value = ''
  aviso.value = ''
  guardando.value = true
  try {
    await settings.saveSettings({ ...form })
    rellenar()
    aviso.value = 'Ajustes guardados. La tienda ya cobra y muestra estos valores.'
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    guardando.value = false
  }
}

function limpiarBanner() {
  Object.assign(banner, {
    id: null, title: '', subtitle: '', accent: '', link: '/tienda',
    image_url: '', image_path: '', active: true
  })
  resumenImagen.value = ''
}

function editarBanner(fila) {
  Object.assign(banner, { ...fila })
  resumenImagen.value = ''
}

async function elegirImagen(evento) {
  const archivo = evento.target.files?.[0]
  if (!archivo) return
  error.value = ''
  subiendo.value = true
  try {
    const subida = await settings.subirImagenBanner(archivo)
    banner.image_url = subida.url
    banner.image_path = subida.path
    const antes = (archivo.size / 1024).toFixed(0)
    const despues = (subida.optimizada.blob.size / 1024).toFixed(0)
    resumenImagen.value = `Optimizada: ${antes} KB → ${despues} KB`
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    subiendo.value = false
    evento.target.value = ''
  }
}

async function guardarBanner() {
  error.value = ''
  aviso.value = ''
  if (!banner.image_url) {
    error.value = 'El banner necesita una imagen: es lo único que se ve en la portada.'
    return
  }
  guardando.value = true
  try {
    await settings.saveBanner({ ...banner })
    aviso.value = banner.id ? 'Banner actualizado.' : 'Banner publicado en la portada.'
    limpiarBanner()
  } catch (fallo) {
    error.value = fallo.message
  } finally {
    guardando.value = false
  }
}

async function alternar(fila) {
  error.value = ''
  try {
    await settings.toggleBanner(fila)
  } catch (fallo) {
    error.value = fallo.message
  }
}

async function confirmarBorrado() {
  const fila = porBorrar.value
  porBorrar.value = null
  if (!fila) return
  error.value = ''
  try {
    await settings.deleteBanner(fila)
    if (banner.id === fila.id) limpiarBanner()
    aviso.value = 'Banner eliminado.'
  } catch (fallo) {
    error.value = fallo.message
  }
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-2xl font-bold text-black">Configuración</h2>
      <p class="text-sm text-neutral-500">
        Envío, contacto y banners de la portada. Todo se guarda en la base: lo que pongas aquí
        es lo que ve y paga el cliente.
      </p>
    </div>

    <p v-if="error" class="rounded-xl bg-red-50 p-3 text-sm font-semibold text-red-600">{{ error }}</p>
    <p v-if="aviso" class="rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">{{ aviso }}</p>
    <p v-if="cargando" class="rounded-2xl bg-white p-8 text-center text-sm text-neutral-500">Cargando ajustes…</p>

    <template v-if="!cargando">
      <!-- Envío -->
      <form class="rounded-2xl bg-white p-5 shadow-sm" @submit.prevent="guardarAjustes">
        <h3 class="text-lg font-bold text-black">Envío</h3>
        <p class="mt-1 text-sm text-neutral-500">
          El servidor calcula el envío de cada pedido con estos dos números. No hay una segunda copia en ningún lado.
        </p>

        <div class="mt-4 grid gap-4 md:grid-cols-2">
          <label class="text-sm font-bold text-neutral-700">
            Costo de envío
            <input v-model="form.shippingCost" type="number" min="0" step="500"
                   class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal outline-none focus:border-[var(--primary)]" />
          </label>
          <label class="text-sm font-bold text-neutral-700">
            Envío gratis desde
            <input v-model="form.freeShippingThreshold" type="number" min="0" step="1000"
                   class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal outline-none focus:border-[var(--primary)]" />
            <span class="mt-1 block text-xs font-normal text-neutral-400">0 = nunca hay envío gratis por monto.</span>
          </label>
        </div>

        <p class="mt-3 rounded-xl bg-pink-50 px-4 py-3 text-sm text-neutral-700">{{ ejemploEnvio }}</p>

        <h3 class="mt-7 text-lg font-bold text-black">Contacto y redes</h3>
        <p class="mt-1 text-sm text-neutral-500">El número de WhatsApp es al que llegan los pedidos de la tienda.</p>

        <div class="mt-4 grid gap-4 md:grid-cols-2">
          <label class="text-sm font-bold text-neutral-700">
            WhatsApp <span class="font-normal text-neutral-400">(con indicativo, sin +)</span>
            <input v-model="form.whatsappNumber" type="text" inputmode="numeric" placeholder="573114088065"
                   class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal outline-none focus:border-[var(--primary)]" />
          </label>
          <label class="text-sm font-bold text-neutral-700">
            Instagram
            <input v-model="form.socialInstagram" type="url"
                   class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal outline-none focus:border-[var(--primary)]" />
          </label>
          <label class="text-sm font-bold text-neutral-700">
            Facebook
            <input v-model="form.socialFacebook" type="url"
                   class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal outline-none focus:border-[var(--primary)]" />
          </label>
          <label class="text-sm font-bold text-neutral-700">
            TikTok
            <input v-model="form.socialTiktok" type="url"
                   class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal outline-none focus:border-[var(--primary)]" />
          </label>
        </div>

        <div class="mt-5 flex items-center gap-3">
          <button type="submit" :disabled="guardando || sinCambios"
                  class="rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50">
            {{ guardando ? 'Guardando…' : 'Guardar cambios' }}
          </button>
          <button type="button" :disabled="sinCambios"
                  class="rounded-xl border border-pink-200 px-5 py-2.5 text-sm font-bold text-neutral-700 transition hover:bg-pink-50 disabled:opacity-40"
                  @click="rellenar">
            Descartar
          </button>
          <span v-if="sinCambios" class="text-xs text-neutral-400">Sin cambios por guardar.</span>
        </div>
      </form>

      <!-- Banners -->
      <div class="rounded-2xl bg-white p-5 shadow-sm">
        <h3 class="text-lg font-bold text-black">Banners de la portada</h3>
        <p class="mt-1 text-sm text-neutral-500">
          El carrusel del inicio. Cada banner es <strong>una imagen y a dónde lleva</strong>, nada más.
          <strong>No cambian ningún precio</strong> — para descuentos está la sección Promociones.
        </p>

        <div class="mt-4 grid gap-5 lg:grid-cols-[320px_1fr]">
          <!-- Formulario -->
          <form class="space-y-3 rounded-xl border border-pink-100 p-4" @submit.prevent="guardarBanner">
            <p class="text-sm font-bold text-[var(--primary)]">{{ banner.id ? 'Editando banner' : 'Nuevo banner' }}</p>

            <label class="block text-sm font-bold text-neutral-700">
              Nombre * <span class="font-normal text-neutral-400">(solo para ti)</span>
              <input v-model="banner.title" required maxlength="60"
                     class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 font-normal outline-none focus:border-[var(--primary)]" />
            </label>
            <p class="text-xs leading-5 text-neutral-500">
              No se ve en la portada: el banner enseña <strong>solo la imagen</strong>. El texto va
              dentro del volante que diseñes. Este nombre sirve para reconocerlo en la lista.
            </p>
            <label class="block text-sm font-bold text-neutral-700">
              Al tocarlo, lleva a
              <input v-model="banner.link" placeholder="/tienda"
                     class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 font-normal outline-none focus:border-[var(--primary)]" />
            </label>

            <div>
              <p class="text-sm font-bold text-neutral-700">Imagen *</p>
              <div v-if="banner.image_url" class="mt-1 overflow-hidden rounded-xl border border-pink-100">
                <img :src="banner.image_url" alt="Vista previa del banner" class="h-28 w-full object-cover" />
              </div>
              <label class="mt-2 inline-flex cursor-pointer items-center gap-2 rounded-xl border border-pink-200 px-3 py-2 text-sm font-bold text-[var(--primary)] transition hover:bg-pink-50">
                <Upload class="size-4" />
                {{ subiendo ? 'Subiendo…' : (banner.image_url ? 'Cambiar imagen' : 'Subir imagen') }}
                <input type="file" accept="image/*" class="hidden" :disabled="subiendo" @change="elegirImagen" />
              </label>
              <p v-if="resumenImagen" class="mt-1 text-xs text-emerald-600">{{ resumenImagen }}</p>
              <p class="mt-1.5 text-xs leading-5 text-neutral-500">
                Tamaño recomendado: <strong>1920 × 800 px</strong> (apaisada, 12:5). Mínimo 1440 × 600.
                Se recorta por los lados en el móvil — deja la cara, el producto y cualquier texto
                dentro del tercio central. JPG o PNG.
              </p>
            </div>

            <label class="flex items-center gap-2 text-sm text-neutral-700">
              <input v-model="banner.active" type="checkbox" class="size-4 accent-[var(--primary)]" />
              Visible en la portada
            </label>

            <div class="flex gap-2 pt-1">
              <button type="submit" :disabled="guardando || subiendo"
                      class="flex-1 rounded-xl bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50">
                {{ banner.id ? 'Guardar' : 'Publicar' }}
              </button>
              <button v-if="banner.id || banner.title" type="button"
                      class="rounded-xl border border-pink-200 px-4 py-2.5 text-sm font-bold text-neutral-700 transition hover:bg-pink-50"
                      @click="limpiarBanner">
                Cancelar
              </button>
            </div>
          </form>

          <!-- Listado -->
          <div class="space-y-3">
            <article v-for="fila in settings.banners" :key="fila.id"
                     class="flex gap-3 rounded-xl border border-pink-100 p-3"
                     :class="{ 'opacity-55': !fila.active }">
              <img v-if="fila.image_url" :src="fila.image_url" :alt="fila.title" class="h-20 w-32 shrink-0 rounded-lg object-cover" />
              <div v-else class="grid h-20 w-32 shrink-0 place-items-center rounded-lg bg-pink-50 text-xs text-neutral-400">Sin imagen</div>

              <div class="min-w-0 flex-1">
                <p class="truncate font-bold text-black">{{ fila.title }}</p>
                <p class="truncate text-sm text-neutral-500">{{ fila.subtitle || '—' }}</p>
                <p class="mt-1 text-xs text-neutral-400">
                  <span v-if="fila.accent" class="font-bold text-[var(--primary)]">{{ fila.accent }} · </span>{{ fila.link }}
                </p>
              </div>

              <div class="flex shrink-0 flex-col gap-1.5">
                <button class="rounded-lg border border-pink-200 px-3 py-1.5 text-xs font-bold text-[var(--primary)] transition hover:bg-pink-50"
                        @click="editarBanner(fila)">Editar</button>
                <button class="inline-flex items-center justify-center gap-1 rounded-lg border border-pink-200 px-3 py-1.5 text-xs font-bold text-neutral-600 transition hover:bg-pink-50"
                        @click="alternar(fila)">
                  <component :is="fila.active ? EyeOff : Eye" class="size-3.5" />
                  {{ fila.active ? 'Ocultar' : 'Mostrar' }}
                </button>
                <button class="inline-flex items-center justify-center gap-1 rounded-lg border border-red-200 px-3 py-1.5 text-xs font-bold text-red-500 transition hover:bg-red-50"
                        @click="porBorrar = fila">
                  <Trash2 class="size-3.5" /> Borrar
                </button>
              </div>
            </article>

            <p v-if="!settings.banners.length" class="rounded-xl border border-dashed border-pink-200 p-8 text-center text-sm text-neutral-500">
              Todavía no hay banners. La portada muestra el de por defecto.
            </p>
          </div>
        </div>
      </div>

      <!-- Colecciones. Va justo después de los banners porque las dos cosas
           son lo mismo: contenido de la portada. Ocupa el sitio del módulo de
           la pasarela de marcas, que se retiró entero. -->
      <AdminColecciones />

      <!-- Cuenta -->
      <div class="rounded-2xl bg-white p-5 shadow-sm">
        <h3 class="text-lg font-bold text-black">Tu cuenta</h3>
        <p class="mt-1 text-sm text-neutral-500">
          La sesión sale de Supabase Auth. Para cambiar la contraseña o dar de alta a otra
          persona, usa el panel de Authentication en Supabase.
        </p>
        <dl class="mt-4 grid gap-3 sm:grid-cols-2">
          <div class="rounded-xl bg-pink-50 px-4 py-3">
            <dt class="text-xs font-bold uppercase tracking-wide text-neutral-500">Correo</dt>
            <dd class="mt-0.5 font-semibold text-black">{{ admin.email || '—' }}</dd>
          </div>
          <div class="rounded-xl bg-pink-50 px-4 py-3">
            <dt class="text-xs font-bold uppercase tracking-wide text-neutral-500">Rol</dt>
            <dd class="mt-0.5 font-semibold text-black">{{ admin.role || '—' }}</dd>
          </div>
        </dl>
      </div>
    </template>

    <div v-if="porBorrar" class="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" @click.self="porBorrar = null">
      <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
        <h3 class="text-lg font-bold text-black">¿Borrar "{{ porBorrar.title }}"?</h3>
        <p class="mt-2 text-sm text-neutral-600">
          Desaparece de la portada y su imagen se elimina del almacenamiento. Un banner no aparece
          en pedidos ni movimientos, así que no se pierde historial.
        </p>
        <div class="mt-6 flex justify-end gap-3">
          <button class="rounded-full bg-neutral-200 px-5 py-2.5 text-sm font-bold text-neutral-700 transition hover:bg-neutral-300" @click="porBorrar = null">Cancelar</button>
          <button class="rounded-full bg-red-500 px-5 py-2.5 text-sm font-bold text-white transition hover:bg-red-600" @click="confirmarBorrado">Borrar</button>
        </div>
      </div>
    </div>
  </div>
</template>
