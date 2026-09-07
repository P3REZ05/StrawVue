<script setup>
import { reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useOrdersStore } from '../../stores/orders'
import { formatCurrency } from '../../utils/formatCurrency'

const ordersStore = useOrdersStore()
const { activeOrders } = storeToRefs(ordersStore)

const selectedOrder = ref(null)
const selectedAction = ref(null)
const error = ref('')
const guardando = ref(false)
const subiendo = ref(false)

// Transportadoras habituales en Colombia. Es un datalist, no un select
// cerrado: si aparece una nueva, se escribe y ya.
const TRANSPORTADORAS = ['Servientrega', 'Interrapidisimo', 'Coordinadora', 'Envia', 'TCC', 'Deprisa', 'Entrega propia']

const envio = reactive({ carrier: '', tracking: '', estimated: '' })

watch(selectedOrder, (pedido) => {
  error.value = ''
  envio.carrier = pedido?.shipment?.carrier || ''
  envio.tracking = pedido?.shipment?.tracking || ''
  envio.estimated = pedido?.shipment?.estimated || ''
})

async function guardarEnvio() {
  error.value = ''
  guardando.value = true
  try {
    await ordersStore.saveShipment(selectedOrder.value.id, { ...envio })
  } catch (e) {
    error.value = e?.message || 'No se pudo guardar el envío.'
  } finally {
    guardando.value = false
  }
}

async function subirComprobantePago(evento) {
  const archivo = evento.target.files?.[0]
  if (!archivo) return
  error.value = ''
  subiendo.value = true
  try {
    await ordersStore.uploadPaymentProof(selectedOrder.value.id, archivo)
  } catch (e) {
    error.value = e?.message || 'No se pudo subir el comprobante.'
  } finally {
    subiendo.value = false
    evento.target.value = ''
  }
}

async function abrirComprobante() {
  error.value = ''
  try {
    const url = await ordersStore.getProofUrl(selectedOrder.value.id)
    if (url) window.open(url, '_blank', 'noopener')
  } catch (e) {
    error.value = e?.message || 'No se pudo abrir el comprobante.'
  }
}

function getStatusBadgeClass(status) {
  switch (status?.toLowerCase()) {
    case 'pendiente': return 'bg-amber-400'
    case 'pagado': return 'bg-emerald-500'
    case 'enviado': return 'bg-blue-500'
    case 'entregado': return 'bg-emerald-600'
    case 'devuelto': return 'bg-red-500'
    default: return 'bg-neutral-400'
  }
}

function getStatusText(status) {
  switch (status?.toLowerCase()) {
    case 'pendiente': return 'Pendiente'
    case 'pagado': return 'Pagado'
    case 'enviado': return 'Enviado'
    case 'entregado': return 'Entregado'
    case 'devuelto': return 'Devuelto'
    default: return status || 'Desconocido'
  }
}

function getAvailableStatusActions(currentStatus) {
  switch (currentStatus?.toLowerCase()) {
    case 'pendiente':
      return [
        { status: 'pagado', text: 'Confirmar pago', icon: 'check-circle', isSuccess: true },
        { status: 'devuelto', text: 'Devolver pedido', icon: 'x-circle', isDanger: true }
      ]
    case 'pagado':
      return [
        { status: 'enviado', text: 'Marcar como Enviado', icon: 'truck' },
        { status: 'devuelto', text: 'Devolver pedido', icon: 'x-circle', isDanger: true }
      ]
    case 'enviado':
      return [
        // Cerrar el pedido es la accion principal: antes no existia y los
        // envios se quedaban en "enviado" para siempre.
        { status: 'entregado', text: 'Marcar como Entregado', icon: 'check-circle', isSuccess: true },
        { status: 'devuelto', text: 'Marcar como Devuelto', icon: 'x-circle', isDanger: true }
      ]
    case 'entregado':
      return [
        { status: 'devuelto', text: 'Registrar devolución', icon: 'x-circle', isDanger: true }
      ]
    case 'devuelto':
      return []
    default:
      return []
  }
}

async function handleStatusChange(orderId, newStatus) {
  error.value = ''
  selectedAction.value = null
  try {
    await ordersStore.updateStatus(orderId, newStatus)
  } catch (e) {
    // Antes esto se ignoraba y la fila mostraba un estado que nunca persistio.
    error.value = e?.message || 'No se pudo cambiar el estado del pedido.'
  }
}

function orderSubtotal(order) {
  return order.items.reduce((sum, item) => sum + item.price * item.quantity, 0)
}

function orderTotal(order) {
  return orderSubtotal(order) + order.shipping
}
</script>

<template>
  <div class="space-y-6">
    <h2 class="text-2xl font-bold text-black">Gestión de Pedidos</h2>
    <p class="text-sm text-neutral-500">Los pedidos marcados como <strong class="text-emerald-600">devuelto</strong> quedan en historial y reingresan el stock disponible.</p>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-200 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">Orden ID</th>
            <th class="px-5 py-4">Orden #</th>
            <th class="px-5 py-4">Cliente</th>
            <th class="px-5 py-4">Total</th>
            <th class="px-5 py-4">Estado</th>
            <th class="px-5 py-4">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="order in activeOrders" :key="order.id" class="border-b border-pink-50 transition hover:bg-pink-50/50">
            <td class="px-5 py-4 font-semibold">{{ order.id }}</td>
            <td class="px-5 py-4">{{ order.orderNumber }}</td>
            <td class="px-5 py-4">{{ order.customer?.name || 'N/A' }}</td>
            <td class="px-5 py-4 font-bold text-[var(--primary)]">{{ formatCurrency(orderTotal(order)) }}</td>
            <td class="px-5 py-4">
              <span class="inline-flex rounded-full px-3 py-1 text-xs font-bold text-white" :class="getStatusBadgeClass(order.status)">
                {{ getStatusText(order.status) }}
              </span>
            </td>
            <td class="relative px-5 py-4">
              <div class="flex gap-2">
                <button
                  class="grid size-8 place-items-center rounded-full border border-pink-200 text-[var(--primary)] transition hover:bg-pink-50"
                  title="Ver detalles"
                  @click="selectedOrder = order"
                >
                  <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/></svg>
                </button>
                <div class="relative">
                  <button
                    class="grid size-8 place-items-center rounded-full border border-pink-200 text-neutral-500 transition hover:bg-pink-50"
                    title="Más acciones"
                    :disabled="getAvailableStatusActions(order.status).length === 0"
                    @click="selectedAction = selectedAction === order.id ? null : order.id"
                  >
                    <svg class="size-4" viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/></svg>
                  </button>
                  <div
                    v-if="selectedAction === order.id"
                    class="absolute right-0 top-10 z-10 w-48 overflow-hidden rounded-xl bg-white py-1 shadow-xl"
                  >
                    <button
                      v-for="action in getAvailableStatusActions(order.status)"
                      :key="action.status"
                      class="flex w-full items-center gap-2 px-4 py-2.5 text-sm transition hover:bg-pink-50"
                      :class="action.isDanger ? 'text-red-500' : action.isWarning ? 'text-amber-500' : action.isSuccess ? 'text-emerald-600' : 'text-neutral-700 hover:text-[var(--primary)]'"
                      @click="handleStatusChange(order.id, action.status)"
                    >
                      <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path v-if="action.icon === 'truck'" d="M1 3h15v13H1zM16 8h4l3 3v5h-7zM5.5 21a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM18.5 21a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"/>
                        <path v-else-if="action.icon === 'x-circle'" d="M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM15 9l-6 6M9 9l6 6"/>
                        <path v-else-if="action.icon === 'check-circle'" d="M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM8 12l3 3 5-6"/>
                        <path v-else d="M21 8l-9-5-9 5v8l9 5 9-5V8zM3 8l9 5 9-5M12 13v8"/>
                      </svg>
                      {{ action.text }}
                    </button>
                  </div>
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!activeOrders.length" class="p-10 text-center text-neutral-500">
        No hay pedidos activos.
      </p>
    </div>

    <p v-if="error && !selectedOrder" class="rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-600">{{ error }}</p>

    <!-- Order Details Modal -->
    <Teleport to="body">
      <div v-if="selectedOrder" class="fixed inset-0 z-100">
        <button class="absolute inset-0 bg-black/45" aria-label="Cerrar modal" @click="selectedOrder = null"></button>
        <div class="absolute inset-0 flex items-center justify-center p-4">
          <div class="w-full max-w-2xl rounded-3xl bg-white shadow-2xl">
            <header class="flex items-center justify-between border-b border-pink-100 px-6 py-4">
              <h5 class="text-xl font-bold">Detalles del Pedido #{{ selectedOrder.orderNumber }}</h5>
              <button class="rounded-full p-2 text-xl hover:bg-pink-50" aria-label="Cerrar" @click="selectedOrder = null">×</button>
            </header>
            <div class="max-h-125 overflow-y-auto px-6 py-5">
              <div class="mb-5">
              <h6 class="border-b border-pink-100 pb-2 font-bold text-[var(--primary)]">Información del Cliente</h6>
                <div class="mt-3 grid gap-2 text-sm sm:grid-cols-2">
                  <p><strong>Nombre:</strong> {{ selectedOrder.customer?.name || 'N/A' }}</p>
                  <p><strong>Documento:</strong> {{ selectedOrder.customer?.document || 'N/A' }}</p>
                  <p><strong>Teléfono:</strong> {{ selectedOrder.customer?.phone || 'N/A' }}</p>
                  <p><strong>Ciudad:</strong> {{ selectedOrder.customer?.city || 'N/A' }}</p>
                  <p><strong>Dirección:</strong> {{ selectedOrder.customer?.address || 'N/A' }}</p>
                  <p><strong>Notas:</strong> {{ selectedOrder.customer?.notes || 'N/A' }}</p>
                </div>
              </div>

              <!-- Pago -->
              <div class="mb-5">
                <h6 class="border-b border-pink-100 pb-2 font-bold text-[var(--primary)]">Pago</h6>
                <div class="mt-3 grid gap-3 sm:grid-cols-2">
                  <p class="text-sm"><strong>Método:</strong> {{ selectedOrder.payment?.method || 'transferencia' }}</p>
                  <p class="text-sm"><strong>Estado:</strong> {{ selectedOrder.payment?.status || 'pendiente' }}</p>
                </div>
                <div class="mt-3 flex flex-wrap items-center gap-2">
                  <button
                    v-if="selectedOrder.payment?.proofPath"
                    class="rounded-full bg-[var(--primary)] px-4 py-2 text-xs font-bold text-white transition hover:bg-[var(--info)]"
                    @click="abrirComprobante"
                  >
                    Ver comprobante
                  </button>
                  <label class="cursor-pointer rounded-full border border-pink-200 px-4 py-2 text-xs font-bold text-neutral-700 transition hover:bg-pink-50">
                    {{ subiendo ? 'Subiendo…' : (selectedOrder.payment?.proofPath ? 'Reemplazar comprobante' : 'Adjuntar comprobante') }}
                    <input type="file" accept="image/*,application/pdf" class="hidden" :disabled="subiendo" @change="subirComprobantePago" />
                  </label>
                  <span v-if="selectedOrder.payment?.proofName" class="text-xs text-neutral-500">{{ selectedOrder.payment.proofName }}</span>
                </div>
                <p class="mt-2 text-xs text-neutral-400">
                  El comprobante se guarda en un almacenamiento privado: lleva datos bancarios del cliente y solo lo ve un administrador.
                </p>
              </div>

              <!-- Envío -->
              <div class="mb-5">
                <h6 class="border-b border-pink-100 pb-2 font-bold text-[var(--primary)]">Envío</h6>
                <div class="mt-3 grid gap-3 sm:grid-cols-3">
                  <label class="text-xs font-bold text-neutral-700">Transportadora
                    <input v-model="envio.carrier" list="transportadoras" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" placeholder="Servientrega" />
                    <datalist id="transportadoras">
                      <option v-for="t in TRANSPORTADORAS" :key="t" :value="t" />
                    </datalist>
                  </label>
                  <label class="text-xs font-bold text-neutral-700">Número de guía
                    <input v-model="envio.tracking" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" placeholder="Para que el cliente rastree" />
                  </label>
                  <label class="text-xs font-bold text-neutral-700">Entrega estimada
                    <input v-model="envio.estimated" type="date" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2 text-sm font-normal" />
                  </label>
                </div>
                <div class="mt-3 flex flex-wrap items-center gap-3">
                  <button
                    :disabled="guardando"
                    class="rounded-full bg-[var(--primary)] px-4 py-2 text-xs font-bold text-white transition hover:bg-[var(--info)] disabled:opacity-50"
                    @click="guardarEnvio"
                  >
                    {{ guardando ? 'Guardando…' : 'Guardar envío' }}
                  </button>
                  <span v-if="selectedOrder.shipment?.shippedAt" class="text-xs text-neutral-500">
                    Despachado el {{ new Date(selectedOrder.shipment.shippedAt).toLocaleDateString('es-CO') }}
                  </span>
                  <span v-if="selectedOrder.shipment?.deliveredAt" class="text-xs font-semibold text-emerald-600">
                    Entregado el {{ new Date(selectedOrder.shipment.deliveredAt).toLocaleDateString('es-CO') }}
                  </span>
                </div>
              </div>

              <p v-if="error" class="mb-4 rounded-xl bg-red-50 px-3 py-2 text-sm font-semibold text-red-600">{{ error }}</p>

              <h6 class="border-b border-pink-100 pb-2 font-bold text-[var(--primary)]">Productos</h6>
              <div class="mt-3 overflow-x-auto">
                <table class="w-full text-sm">
                  <thead>
                    <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
                      <th class="py-2 pr-3">Producto</th>
                      <th class="py-2 pr-3">Cantidad</th>
                      <th class="py-2 pr-3">Precio</th>
                      <th class="py-2">Subtotal</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(item, index) in selectedOrder.items" :key="index" class="border-b border-pink-50">
                      <td class="py-2 pr-3">{{ item.productName }}</td>
                      <td class="py-2 pr-3">{{ item.quantity }}</td>
                      <td class="py-2 pr-3">{{ formatCurrency(item.price) }}</td>
                      <td class="py-2 font-semibold">{{ formatCurrency(item.price * item.quantity) }}</td>
                    </tr>
                  </tbody>
                  <tfoot>
                    <tr>
                      <td colspan="3" class="py-2 text-right font-semibold">Subtotal:</td>
                      <td class="py-2 font-semibold">{{ formatCurrency(orderSubtotal(selectedOrder)) }}</td>
                    </tr>
                    <tr>
                      <td colspan="3" class="py-2 text-right font-semibold">Envío:</td>
                      <td class="py-2 font-semibold">{{ selectedOrder.shipping ? formatCurrency(selectedOrder.shipping) : 'GRATIS' }}</td>
                    </tr>
                    <tr>
                      <td colspan="3" class="py-2 text-right font-bold">Total:</td>
                      <td class="py-2 font-bold text-[var(--primary)]">{{ formatCurrency(orderTotal(selectedOrder)) }}</td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>
            <footer class="flex justify-end border-t border-pink-100 px-6 py-4">
              <button class="rounded-xl border border-pink-200 px-5 py-2.5 text-sm font-bold" @click="selectedOrder = null">
                Cerrar
              </button>
            </footer>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>