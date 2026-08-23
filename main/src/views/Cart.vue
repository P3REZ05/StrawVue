<script setup>
import { computed, reactive, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useCartStore } from '../stores/cart'
import { useOrdersStore } from '../stores/orders'
import { storeSettings } from '../data/mockData'
import { formatCurrency } from '../utils/formatCurrency'

const cart = useCartStore()
const ordersStore = useOrdersStore()
const step = ref(1)
const submitted = ref(false)
const submitting = ref(false)
const error = ref('')
const customer = reactive({ name: '', document: '', phone: '', city: '', address: '', notes: '' })
const shipping = computed(() => cart.subtotal >= storeSettings.freeShippingThreshold ? 0 : storeSettings.shippingCost)
const total = computed(() => cart.subtotal + shipping.value)

function goToSummary() {
  step.value = 3
}

async function confirmOrder() {
  error.value = ''
  submitting.value = true

  try {
    const order = await ordersStore.addOrder({
      customer,
      items: cart.items,
      subtotal: cart.subtotal,
      shipping: shipping.value,
      total: total.value,
      paymentMethod: 'transfer'
    })

    if (!order) throw new Error('No se pudo registrar el pedido.')

  const lines = cart.items.map((item) => `• ${item.name} x${item.quantity} — ${formatCurrency(item.price * item.quantity)}`).join('\n')
    const message = `🛍️ *Nuevo Pedido ${order.orderNumber}*\n\n*Información del cliente*\nNombre: ${customer.name}\nDocumento: ${customer.document}\nTeléfono: ${customer.phone}\nCiudad: ${customer.city}\nDirección: ${customer.address}${customer.notes ? `\nNotas: ${customer.notes}` : ''}\n\n*Productos*\n${lines}\n\n*Resumen*\nSubtotal: ${formatCurrency(cart.subtotal)}\nEnvío: ${shipping.value ? formatCurrency(shipping.value) : 'GRATIS 🎉'}\n*Total: ${formatCurrency(total.value)}*`
    window.open(`https://wa.me/${storeSettings.whatsappNumber}?text=${encodeURIComponent(message)}`, '_blank', 'noopener')
    submitted.value = true
  } catch (orderError) {
    error.value = orderError.message || 'No se pudo registrar el pedido.'
  } finally {
    submitting.value = false
  }
}

function finish() {
  cart.clear()
  submitted.value = false
  step.value = 1
}
</script>

<template>
  <p v-if="error" class="fixed bottom-5 left-1/2 z-50 -translate-x-1/2 rounded-xl bg-red-50 px-5 py-3 text-sm font-semibold text-red-600 shadow-lg">{{ error }}</p>
  <main class="bg-pink-50/40 py-12 sm:py-18"><section v-if="!cart.items.length && !submitted" class="mx-auto max-w-xl px-5 py-20 text-center"><span class="text-6xl">🛍</span><h1 class="mt-6 text-3xl font-bold">Tu carrito está vacío</h1><p class="mt-3 text-neutral-600">Explora nuestros productos y encuentra tus favoritos.</p><RouterLink class="mt-7 inline-block rounded-full bg-[var(--primary)] px-6 py-3 text-sm font-bold text-white" to="/tienda">Ir a la tienda</RouterLink></section><section v-else-if="submitted" class="mx-auto max-w-xl px-5 py-20 text-center"><span class="text-6xl">🍓</span><p class="mt-6 text-sm font-bold tracking-[0.2em] text-[var(--primary)]">PEDIDO GENERADO</p><h1 class="mt-3 text-4xl font-bold">¡Gracias por tu compra!</h1><p class="mt-4 leading-7 text-neutral-600">Abrimos WhatsApp con el resumen de tu pedido para que puedas finalizar la coordinación con nosotros.</p><RouterLink class="mt-7 inline-block rounded-full bg-[var(--primary)] px-6 py-3 text-sm font-bold text-white" to="/tienda" @click="finish">Seguir comprando</RouterLink></section><section v-else class="mx-auto max-w-6xl px-5 sm:px-8 lg:px-10"><div class="mb-10 flex items-center justify-center gap-2 text-xs font-bold sm:gap-5 sm:text-sm"><span :class="step >= 1 ? 'bg-[var(--primary)] text-white' : 'bg-white text-neutral-400'" class="grid size-9 place-items-center rounded-full">1</span><span class="h-px w-8 bg-pink-200 sm:w-20"></span><span :class="step >= 2 ? 'bg-[var(--primary)] text-white' : 'bg-white text-neutral-400'" class="grid size-9 place-items-center rounded-full">2</span><span class="h-px w-8 bg-pink-200 sm:w-20"></span><span :class="step >= 3 ? 'bg-[var(--primary)] text-white' : 'bg-white text-neutral-400'" class="grid size-9 place-items-center rounded-full">3</span></div><p class="text-center text-xs font-bold tracking-widest text-[var(--primary)]">{{ ['CARRITO', 'ENVÍO', 'CONFIRMAR'][step - 1] }}</p><div v-if="step === 1" class="mt-8 grid gap-8 lg:grid-cols-[1fr_350px]"><div><h1 class="text-3xl font-bold">Tu belleza no tiene precio</h1><div class="mt-6 space-y-4"><article v-for="item in cart.items" :key="item.id" class="flex gap-4 rounded-2xl bg-white p-4 shadow-sm"><img :src="item.image" :alt="item.name" class="size-24 rounded-xl bg-pink-50 object-contain p-1" /><div class="min-w-0 flex-1"><p class="text-xs font-bold text-[var(--primary)]">{{ item.category }}</p><h2 class="mt-1 font-bold">{{ item.name }}</h2><p class="mt-2 font-semibold">{{ formatCurrency(item.price) }}</p><div class="mt-3 flex items-center justify-between"><div class="inline-flex items-center rounded-full border border-pink-200"><button class="size-8 text-[var(--primary)]" @click="cart.updateQuantity(item.id, item.quantity - 1)">−</button><span class="w-7 text-center text-sm font-bold">{{ item.quantity }}</span><button class="size-8 text-[var(--primary)]" :disabled="item.quantity === item.stock" @click="cart.updateQuantity(item.id, item.quantity + 1)">+</button></div><button class="text-sm font-bold text-neutral-500 hover:text-red-500" @click="cart.remove(item.id)">Eliminar</button></div></div></article></div></div><aside class="h-fit rounded-2xl bg-white p-6 shadow-sm"><h2 class="text-xl font-bold">Totales del carrito</h2><div class="mt-5 space-y-3 text-sm"><div class="flex justify-between"><span>Subtotal</span><strong>{{ formatCurrency(cart.subtotal) }}</strong></div><div class="flex justify-between"><span>Envío</span><strong>{{ shipping ? formatCurrency(shipping) : 'GRATIS' }}</strong></div><div class="border-t border-pink-100 pt-3 text-lg"><div class="flex justify-between"><span>Total</span><strong>{{ formatCurrency(total) }}</strong></div></div></div><p class="mt-5 rounded-xl bg-pink-50 p-3 text-sm text-neutral-600">Envío gratis desde {{ formatCurrency(storeSettings.freeShippingThreshold) }}.</p><button class="mt-6 w-full rounded-full bg-[var(--primary)] py-3 text-sm font-bold text-white" @click="step = 2">Continuar</button></aside></div><form v-else-if="step === 2" class="mx-auto mt-8 max-w-2xl rounded-3xl bg-white p-6 shadow-sm sm:p-9" @submit.prevent="goToSummary"><h1 class="text-3xl font-bold">Información de envío</h1><div class="mt-7 grid gap-4 sm:grid-cols-2"><input v-model="customer.name" required class="rounded-xl border border-pink-100 px-4 py-3 outline-none focus:border-[var(--primary)]" placeholder="Nombre completo" /><input v-model="customer.document" required class="rounded-xl border border-pink-100 px-4 py-3 outline-none focus:border-[var(--primary)]" placeholder="Número de documento" /><input v-model="customer.phone" required type="tel" class="rounded-xl border border-pink-100 px-4 py-3 outline-none focus:border-[var(--primary)]" placeholder="Teléfono" /><input v-model="customer.city" required class="rounded-xl border border-pink-100 px-4 py-3 outline-none focus:border-[var(--primary)]" placeholder="Ciudad" /><input v-model="customer.address" required class="sm:col-span-2 rounded-xl border border-pink-100 px-4 py-3 outline-none focus:border-[var(--primary)]" placeholder="Dirección de envío" /><textarea v-model="customer.notes" class="sm:col-span-2 rounded-xl border border-pink-100 px-4 py-3 outline-none focus:border-[var(--primary)]" rows="3" placeholder="Notas adicionales (opcional)"></textarea></div><div class="mt-7 flex justify-between"><button type="button" class="rounded-full border border-pink-200 px-5 py-3 text-sm font-bold" @click="step = 1">Volver</button><button class="rounded-full bg-[var(--primary)] px-6 py-3 text-sm font-bold text-white">Continuar</button></div></form><section v-else class="mx-auto mt-8 max-w-3xl rounded-3xl bg-white p-6 shadow-sm sm:p-9"><h1 class="text-center text-3xl font-bold">Resumen del pedido</h1><div class="mt-8 grid gap-6 sm:grid-cols-2"><div><h2 class="font-bold text-[var(--primary)]">Información de envío</h2><div class="mt-3 space-y-1 text-sm leading-6 text-neutral-600"><p><strong>Nombre:</strong> {{ customer.name }}</p><p><strong>Documento:</strong> {{ customer.document }}</p><p><strong>Teléfono:</strong> {{ customer.phone }}</p><p><strong>Ciudad:</strong> {{ customer.city }}</p><p><strong>Dirección:</strong> {{ customer.address }}</p><p v-if="customer.notes"><strong>Notas:</strong> {{ customer.notes }}</p></div></div><div class="rounded-2xl bg-pink-50 p-5"><h2 class="font-bold text-[var(--primary)]">Resumen de costos</h2><div class="mt-4 space-y-2 text-sm"><div class="flex justify-between"><span>Subtotal</span><span>{{ formatCurrency(cart.subtotal) }}</span></div><div class="flex justify-between"><span>Envío</span><span>{{ shipping ? formatCurrency(shipping) : 'GRATIS' }}</span></div><div class="flex justify-between border-t border-pink-200 pt-3 text-base font-bold"><span>Total</span><span>{{ formatCurrency(total) }}</span></div></div></div></div><div class="mt-8 border-t border-pink-100 pt-6"><h2 class="font-bold">Productos</h2><div v-for="item in cart.items" :key="item.id" class="mt-3 flex justify-between text-sm"><span>{{ item.name }} × {{ item.quantity }}</span><strong>{{ formatCurrency(item.price * item.quantity) }}</strong></div></div><div class="mt-8 flex justify-between"><button class="rounded-full border border-pink-200 px-5 py-3 text-sm font-bold" @click="step = 2">Volver</button><button class="rounded-full bg-[var(--primary)] px-6 py-3 text-sm font-bold text-white" @click="confirmOrder">Confirmar por WhatsApp</button></div></section></section></main>
</template>
