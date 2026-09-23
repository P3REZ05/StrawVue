<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { RouterLink } from 'vue-router'
import {
  MessageCircle, ShieldCheck, Palette, Truck, RefreshCw, HeartHandshake,
  Sparkles, TrendingUp, GraduationCap, PackageOpen, Store, ChevronDown,
  MapPin, Mail, Phone, Instagram, Music2, Facebook
} from 'lucide-vue-next'
import { supabase } from '../lib/supabase'
import { useSettingsStore } from '../stores/settings'

// `submit()` era literalmente `sent.value = true`. El cliente rellenaba sus
// datos, leía "¡Mensaje recibido!" y el mensaje no llegaba a ninguna parte.
// Nada fallaba de forma visible, y por eso llevaba ahí desde el principio.
const settings = useSettingsStore()
const form = reactive({ name: '', email: '', phone: '', message: '', acceptsTerms: false })
const sent = ref(false)
const enviando = ref(false)
const error = ref('')
const preguntaAbierta = ref(null)

const redes = computed(() => settings.redes)

/**
 * Enlace de WhatsApp con el mensaje ya escrito.
 *
 * El número se guarda en `store_settings` y puede venir con espacios, guiones
 * o paréntesis; `wa.me` solo acepta dígitos. Si todavía no hay número
 * configurado se devuelve cadena vacía y los botones no se pintan: es mejor
 * que no aparezca a que lleve a un enlace roto.
 */
function whatsapp(texto) {
  const numero = String(settings.whatsapp || '').replace(/\D/g, '')
  if (!numero) return ''
  return `https://wa.me/${numero}?text=${encodeURIComponent(texto)}`
}

const waGeneral = computed(() => whatsapp('¡Hola! Quiero hacer un pedido en Strawberry Makeup.'))
const waAsesoria = computed(() => whatsapp('¡Hola! Necesito ayuda para elegir mi tono.'))
const waEmprendedor = computed(() =>
  whatsapp('¡Hola! Me interesa el Plan Emprendedor de Strawberry Makeup. ¿Me cuentan cómo funciona?')
)

// Las ventajas son las que el sistema sostiene de verdad: tonos con su color
// real, seguimiento con número de guía, pago con comprobante, atención por
// WhatsApp. Nada de plazos ni porcentajes que luego haya que cumplir.
const VENTAJAS = [
  {
    icono: ShieldCheck,
    titulo: 'Productos originales',
    texto: 'Trabajamos directo con distribuidores. Lo que te llega es lo que viste.'
  },
  {
    icono: Palette,
    titulo: 'El tono que de verdad buscas',
    texto: 'Cada producto muestra sus tonos con el color real, el subtono y si hay existencias.'
  },
  {
    icono: MessageCircle,
    titulo: 'Te asesoramos antes de comprar',
    texto: '¿Dudas entre dos bases? Escríbenos y te ayudamos a elegir. Sin compromiso.'
  },
  {
    icono: Truck,
    titulo: 'Envíos a todo el país',
    texto: 'Te damos el número de guía para que sigas tu pedido hasta tu puerta.'
  },
  {
    icono: RefreshCw,
    titulo: 'Si algo sale mal, lo resolvemos',
    texto: 'Cambios y devoluciones según nuestros términos. Nos importa que vuelvas.'
  },
  {
    icono: HeartHandshake,
    titulo: 'Atención de persona a persona',
    texto: 'Detrás del WhatsApp hay alguien real que conoce los productos.'
  }
]

const BENEFICIOS_PLAN = [
  { icono: TrendingUp, titulo: 'Precio especial por volumen', texto: 'Mientras más compras, mejor precio. Tu margen crece contigo.' },
  { icono: GraduationCap, titulo: 'Te enseñamos a vender', texto: 'Qué se mueve, cómo asesorar en tonos y cómo armar tus combos.' },
  { icono: PackageOpen, titulo: 'Empiezas con poco', texto: 'No necesitas comprar un inventario enorme para arrancar.' },
  { icono: Store, titulo: 'Sin local ni vitrina', texto: 'Vende desde tu casa, por WhatsApp o por redes. Nosotros te respaldamos.' }
]

const PREGUNTAS = [
  {
    q: '¿Cómo hago un pedido?',
    a: 'Arma tu carrito en la tienda y confirma. Se abre WhatsApp con el resumen y ahí coordinamos el pago y el envío contigo.'
  },
  {
    q: '¿Cómo puedo pagar?',
    a: 'Por transferencia. Nos envías el comprobante por WhatsApp y despachamos tu pedido.'
  },
  {
    q: '¿Hacen envíos a mi ciudad?',
    a: 'Enviamos a todo el país. El costo se calcula al confirmar el pedido y te pasamos el número de guía para que lo sigas.'
  },
  {
    q: 'No sé qué tono me queda. ¿Me ayudan?',
    a: 'Sí, y es gratis. Escríbenos por WhatsApp con una foto con luz natural y te decimos cuál pedir.'
  },
  {
    q: '¿Puedo revender sus productos?',
    a: 'Claro. Para eso está el Plan Emprendedor: escríbenos y te contamos las condiciones.'
  }
]

function alternarPregunta(i) {
  preguntaAbierta.value = preguntaAbierta.value === i ? null : i
}

onMounted(() => { settings.init().catch(() => {}) })

async function submit() {
  error.value = ''
  enviando.value = true
  try {
    const { error: fallo } = await supabase.from('contact_messages').insert({
      name: form.name.trim(),
      email: form.email.trim(),
      phone: form.phone.trim() || null,
      message: form.message.trim()
    })
    // Solo se dice "recibido" si la base lo confirmó. Un acuse de recibo
    // falso es peor que un error: el cliente se queda esperando respuesta.
    if (fallo) throw new Error(fallo.message)

    sent.value = true
    Object.assign(form, { name: '', email: '', phone: '', message: '', acceptsTerms: false })
  } catch (fallo) {
    error.value = 'No pudimos enviar tu mensaje. Vuelve a intentarlo o escríbenos por WhatsApp.'
    console.error('Error al enviar el formulario de contacto:', fallo)
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <main class="bg-white">

    <!-- ============================ PORTADA ============================ -->
    <section class="relative overflow-hidden bg-gradient-to-b from-pink-50 to-white">
      <!-- Dos manchas de color muy suaves: dan profundidad sin robarle
           protagonismo al texto ni bajarle el contraste. -->
      <div class="pointer-events-none absolute -left-24 -top-24 size-72 rounded-full bg-pink-200/40 blur-3xl"></div>
      <div class="pointer-events-none absolute -right-20 top-20 size-64 rounded-full bg-purple-200/30 blur-3xl"></div>

      <div class="relative mx-auto max-w-3xl px-5 py-14 text-center sm:px-8 sm:py-20">
        <p class="text-xs font-bold uppercase tracking-[0.22em] text-[#c2185b]">Estamos para ayudarte</p>
        <h1 class="mt-3 text-3xl font-black leading-tight tracking-tight text-black sm:text-5xl">
          Hablemos de tu maquillaje
        </h1>
        <p class="mx-auto mt-4 max-w-xl text-base leading-7 text-neutral-600">
          Resolvemos tus dudas, te ayudamos a elegir tu tono y, si quieres,
          te acompañamos a empezar tu propio negocio.
        </p>

        <div class="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a
            v-if="waGeneral"
            :href="waGeneral" target="_blank" rel="noopener noreferrer"
            class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-[var(--primary)] px-7 text-sm font-bold text-white shadow-lg shadow-pink-300/40 transition hover:bg-[var(--info)] sm:w-auto"
          >
            <MessageCircle class="size-4" /> Escríbenos por WhatsApp
          </a>
          <a
            href="#plan-emprendedor"
            class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full border-2 border-[var(--primary)] px-7 text-sm font-bold text-[#c2185b] transition hover:bg-pink-50 sm:w-auto"
          >
            <Sparkles class="size-4" /> Quiero vender con ustedes
          </a>
        </div>
      </div>
    </section>

    <!-- =========================== VENTAJAS ============================ -->
    <section class="mx-auto max-w-7xl px-5 py-14 sm:px-8 sm:py-16 lg:px-10">
      <div class="text-center">
        <p class="text-xs font-bold uppercase tracking-[0.22em] text-[#c2185b]">Por qué comprarnos</p>
        <h2 class="mt-2 text-2xl font-black tracking-tight text-black sm:text-3xl">
          Lo que te llevas además del producto
        </h2>
      </div>

      <ul class="mt-9 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <li
          v-for="v in VENTAJAS" :key="v.titulo"
          class="rounded-2xl border border-pink-100 bg-white p-5 transition hover:-translate-y-0.5 hover:border-pink-200 hover:shadow-md"
        >
          <span class="grid size-11 place-items-center rounded-full bg-pink-50">
            <component :is="v.icono" class="size-5 text-[#c2185b]" :stroke-width="1.75" />
          </span>
          <h3 class="mt-3.5 font-bold text-black">{{ v.titulo }}</h3>
          <p class="mt-1 text-sm leading-6 text-neutral-600">{{ v.texto }}</p>
        </li>
      </ul>

      <p class="mt-8 text-center text-sm text-neutral-600">
        ¿Todavía no sabes cuál es tu tono?
        <a
          v-if="waAsesoria" :href="waAsesoria" target="_blank" rel="noopener noreferrer"
          class="font-bold text-[#c2185b] underline underline-offset-4 hover:text-[var(--primary)]"
        >Te asesoramos gratis</a>
        <RouterLink v-else to="/tienda" class="font-bold text-[#c2185b] underline underline-offset-4">Mira la tienda</RouterLink>.
      </p>
    </section>

    <!-- ======================= PLAN EMPRENDEDOR ======================== -->
    <section id="plan-emprendedor" class="scroll-mt-20 bg-[#1b0a14] py-14 text-white sm:py-18">
      <div class="mx-auto max-w-7xl px-5 sm:px-8 lg:px-10">
        <div class="grid gap-10 lg:grid-cols-[1fr_1fr] lg:items-center">

          <div>
            <p class="inline-flex items-center gap-1.5 rounded-full bg-[var(--primary)] px-3 py-1.5 text-xs font-bold uppercase tracking-wide">
              <Sparkles class="size-3.5" /> Plan Emprendedor
            </p>
            <h2 class="mt-4 text-3xl font-black leading-tight tracking-tight sm:text-4xl">
              Empieza tu propio negocio de maquillaje
            </h2>
            <p class="mt-4 max-w-lg text-base leading-7 text-white/75">
              No hace falta un local, ni una inversión grande, ni experiencia previa.
              Te damos precio de mayorista, te enseñamos qué se vende y te acompañamos
              en tus primeras ventas. Tú pones las ganas.
            </p>

            <a
              v-if="waEmprendedor"
              :href="waEmprendedor" target="_blank" rel="noopener noreferrer"
              class="mt-7 inline-flex min-h-12 items-center gap-2 rounded-full bg-[var(--primary)] px-7 text-sm font-bold text-white shadow-lg shadow-pink-500/25 transition hover:bg-[var(--info)]"
            >
              <MessageCircle class="size-4" /> Cuéntenme cómo funciona
            </a>
            <p class="mt-3 text-xs text-white/50">
              Te contamos las condiciones por WhatsApp, sin compromiso.
            </p>
          </div>

          <ul class="grid gap-3 sm:grid-cols-2">
            <li
              v-for="b in BENEFICIOS_PLAN" :key="b.titulo"
              class="rounded-2xl border border-white/10 bg-white/5 p-5 transition hover:border-[var(--primary)] hover:bg-white/8"
            >
              <component :is="b.icono" class="size-6 text-[var(--info)]" :stroke-width="1.75" />
              <h3 class="mt-3 font-bold">{{ b.titulo }}</h3>
              <p class="mt-1 text-sm leading-6 text-white/70">{{ b.texto }}</p>
            </li>
          </ul>

        </div>
      </div>
    </section>

    <!-- ===================== FORMULARIO Y CONTACTO ===================== -->
    <section class="mx-auto max-w-7xl px-5 py-14 sm:px-8 sm:py-16 lg:px-10">
      <div class="grid gap-8 lg:grid-cols-[1.15fr_.85fr]">

        <div class="rounded-3xl border border-pink-100 bg-white p-6 shadow-sm sm:p-8">
          <h2 class="text-2xl font-black tracking-tight text-black">Escríbenos</h2>
          <p class="mt-2 text-sm leading-6 text-neutral-600">
            Si prefieres dejarlo por escrito, llena el formulario y te respondemos.
            Para algo urgente, WhatsApp es más rápido.
          </p>

          <form v-if="!sent" class="mt-6 space-y-3.5" @submit.prevent="submit">
            <div class="grid gap-3.5 sm:grid-cols-2">
              <label class="block text-xs font-bold text-neutral-700">
                Nombre
                <input
                  v-model="form.name" required
                  class="mt-1 h-12 w-full rounded-xl border border-pink-100 px-4 text-sm font-normal outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                  placeholder="Tu nombre"
                />
              </label>
              <label class="block text-xs font-bold text-neutral-700">
                Teléfono
                <input
                  v-model="form.phone" required type="tel"
                  class="mt-1 h-12 w-full rounded-xl border border-pink-100 px-4 text-sm font-normal outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                  placeholder="300 000 0000"
                />
              </label>
            </div>

            <label class="block text-xs font-bold text-neutral-700">
              Correo electrónico
              <input
                v-model="form.email" required type="email"
                class="mt-1 h-12 w-full rounded-xl border border-pink-100 px-4 text-sm font-normal outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                placeholder="tucorreo@ejemplo.com"
              />
            </label>

            <label class="block text-xs font-bold text-neutral-700">
              Mensaje
              <textarea
                v-model="form.message" required rows="5"
                class="mt-1 w-full resize-y rounded-xl border border-pink-100 px-4 py-3 text-sm font-normal outline-none transition focus:border-[var(--primary)] focus:ring-2 focus:ring-pink-100"
                placeholder="Cuéntanos en qué podemos ayudarte…"
              ></textarea>
            </label>

            <label class="flex gap-3 text-sm leading-6 text-neutral-600">
              <input v-model="form.acceptsTerms" required type="checkbox" class="mt-1 size-4 shrink-0 accent-[var(--primary)]" />
              <span>
                Acepto los
                <RouterLink class="font-semibold text-[#c2185b] hover:underline" to="/terminos">términos y condiciones</RouterLink>
                y el tratamiento de datos personales.
              </span>
            </label>

            <p v-if="error" class="rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-600">{{ error }}</p>

            <button
              :disabled="enviando"
              class="inline-flex min-h-12 w-full items-center justify-center rounded-full bg-[var(--primary)] px-6 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50 sm:w-auto sm:px-8"
            >
              {{ enviando ? 'Enviando…' : 'Enviar mensaje' }}
            </button>
          </form>

          <div v-else class="mt-6 rounded-2xl bg-pink-50 p-6">
            <h3 class="text-xl font-bold text-[#c2185b]">¡Mensaje recibido!</h3>
            <p class="mt-2 text-sm leading-6 text-neutral-600">
              Gracias por escribirnos. Te responderemos lo antes posible.
            </p>
            <button class="mt-4 text-sm font-bold text-[#c2185b] hover:underline" @click="sent = false">
              Enviar otro mensaje
            </button>
          </div>
        </div>

        <aside class="space-y-3">
          <a
            v-if="waGeneral" :href="waGeneral" target="_blank" rel="noopener noreferrer"
            class="flex items-center gap-4 rounded-2xl bg-[#1b0a14] p-5 text-white transition hover:-translate-y-0.5"
          >
            <span class="grid size-11 shrink-0 place-items-center rounded-full bg-[var(--primary)]">
              <MessageCircle class="size-5" />
            </span>
            <span class="min-w-0">
              <strong class="block">WhatsApp</strong>
              <span class="block text-sm text-white/70">La vía más rápida. Respondemos aquí.</span>
            </span>
          </a>

          <div class="rounded-2xl border border-pink-100 p-5">
            <div class="flex items-center gap-3">
              <MapPin class="size-5 shrink-0 text-[#c2185b]" />
              <div>
                <strong class="block text-sm text-black">Dónde estamos</strong>
                <span class="text-sm text-neutral-600">Chinchiná, Caldas</span>
              </div>
            </div>
            <div class="mt-4 flex items-center gap-3">
              <Mail class="size-5 shrink-0 text-[#c2185b]" />
              <div class="min-w-0">
                <strong class="block text-sm text-black">Correo</strong>
                <a class="block break-words text-sm text-neutral-600 hover:text-[#c2185b]" href="mailto:strawberrymakeupstore@gmail.com">
                  strawberrymakeupstore@gmail.com
                </a>
              </div>
            </div>
            <div class="mt-4 flex items-center gap-3">
              <Phone class="size-5 shrink-0 text-[#c2185b]" />
              <div>
                <strong class="block text-sm text-black">Teléfono</strong>
                <a class="text-sm text-neutral-600 hover:text-[#c2185b]" href="tel:+573235275634">+57 323 527 5634</a>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-pink-100 p-5">
            <strong class="text-sm text-black">Síguenos</strong>
            <div class="mt-3 space-y-2">
              <a
                v-for="red in [
                  { url: redes.instagram, icono: Instagram, nombre: 'Instagram', cuenta: '@strawberry_makeup05' },
                  { url: redes.tiktok, icono: Music2, nombre: 'TikTok', cuenta: '@strawberry_makeup05' },
                  { url: redes.facebook, icono: Facebook, nombre: 'Facebook', cuenta: 'Strawberry Makeup Store' }
                ]"
                :key="red.nombre"
                :href="red.url || '#'" target="_blank" rel="noopener noreferrer"
                class="flex min-h-11 items-center gap-3 rounded-xl px-2 transition hover:bg-pink-50"
              >
                <component :is="red.icono" class="size-4 shrink-0 text-[#c2185b]" />
                <span class="min-w-0">
                  <strong class="block text-sm text-black">{{ red.nombre }}</strong>
                  <span class="block truncate text-xs text-neutral-500">{{ red.cuenta }}</span>
                </span>
              </a>
            </div>
          </div>
        </aside>
      </div>
    </section>

    <!-- ========================== PREGUNTAS ============================ -->
    <section class="bg-pink-50/50 py-14 sm:py-16">
      <div class="mx-auto max-w-3xl px-5 sm:px-8">
        <h2 class="text-center text-2xl font-black tracking-tight text-black sm:text-3xl">
          Preguntas frecuentes
        </h2>

        <!-- Acordeón propio, no `<details>`: así el estado es del componente y
             se puede dejar una sola abierta a la vez. -->
        <ul class="mt-8 space-y-2.5">
          <li v-for="(p, i) in PREGUNTAS" :key="p.q" class="overflow-hidden rounded-2xl bg-white">
            <button
              class="flex w-full items-center justify-between gap-4 p-5 text-left transition hover:bg-pink-50/60"
              :aria-expanded="preguntaAbierta === i"
              @click="alternarPregunta(i)"
            >
              <span class="text-sm font-bold text-black sm:text-base">{{ p.q }}</span>
              <ChevronDown
                class="size-5 shrink-0 text-[#c2185b] transition-transform duration-200"
                :class="preguntaAbierta === i ? 'rotate-180' : ''"
              />
            </button>
            <p v-if="preguntaAbierta === i" class="px-5 pb-5 text-sm leading-7 text-neutral-600">
              {{ p.a }}
            </p>
          </li>
        </ul>
      </div>
    </section>

  </main>
</template>
