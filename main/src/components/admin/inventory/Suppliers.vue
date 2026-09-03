<script setup>
import { computed, reactive, ref } from 'vue'
import { useInventoryStore } from '../../../stores/inventory'

const store = useInventoryStore()
const showForm = ref(false)
const editingId = ref(null)
const selectedSupplier = ref(null)
const error = ref('')
const form = reactive({ name: '', documentNumber: '', contactName: '', phone: '', email: '', city: '', address: '', paymentTerms: '', notes: '' })
const suppliers = computed(() => store.suppliers.filter((supplier) => supplier.active !== false))

function resetForm() {
  Object.assign(form, { name: '', documentNumber: '', contactName: '', phone: '', email: '', city: '', address: '', paymentTerms: '', notes: '' })
  editingId.value = null
  error.value = ''
}

function openAdd() {
  resetForm()
  showForm.value = true
}

function openEdit(supplier) {
  Object.assign(form, {
    name: supplier.name || '', documentNumber: supplier.document_number || supplier.documentNumber || '', contactName: supplier.contact_name || supplier.contactName || '', phone: supplier.phone || '', email: supplier.email || '', city: supplier.city || '', address: supplier.address || '', paymentTerms: supplier.payment_terms || supplier.paymentTerms || '', notes: supplier.notes || ''
  })
  editingId.value = supplier.id
  error.value = ''
  showForm.value = true
}

function openDetails(supplier) {
  selectedSupplier.value = supplier
}

function closeDetails() {
  selectedSupplier.value = null
}

async function submit() {
  error.value = ''
  try {
    await store.saveSupplier({ ...form, id: editingId.value })
    showForm.value = false
    resetForm()
  } catch (submitError) {
    error.value = submitError.message || 'No se pudo guardar el proveedor.'
  }
}

async function deactivate(supplier) {
  if (!window.confirm(`¿Desactivar a ${supplier.name}?`)) return
  try {
    await store.deactivateSupplier(supplier.id)
  } catch (submitError) {
    error.value = submitError.message || 'No se pudo desactivar el proveedor.'
  }
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3"><div><h2 class="text-2xl font-bold text-black">Proveedores</h2><p class="mt-1 text-sm text-neutral-500">Administra los contactos que abastecen tu inventario.</p></div><button class="inline-flex items-center gap-2 rounded-xl bg-[var(--primary)] px-4 py-2.5 text-sm font-bold text-white hover:bg-[var(--info)]" @click="openAdd"><span class="text-lg">+</span> Nuevo proveedor</button></div>

    <form v-if="showForm" class="rounded-2xl bg-white p-5 shadow-sm" @submit.prevent="submit"><div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3"><label class="text-sm font-bold text-neutral-700">Nombre<input v-model="form.name" required class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label><label class="text-sm font-bold text-neutral-700">NIT / documento<input v-model="form.documentNumber" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label><label class="text-sm font-bold text-neutral-700">Contacto<input v-model="form.contactName" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label><label class="text-sm font-bold text-neutral-700">Teléfono<input v-model="form.phone" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label><label class="text-sm font-bold text-neutral-700">Correo<input v-model="form.email" type="email" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label><label class="text-sm font-bold text-neutral-700">Ciudad<input v-model="form.city" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label><label class="text-sm font-bold text-neutral-700">Dirección<input v-model="form.address" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label><label class="text-sm font-bold text-neutral-700">Condiciones de pago<input v-model="form.paymentTerms" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal" /></label><label class="text-sm font-bold text-neutral-700 lg:col-span-3">Notas<textarea v-model="form.notes" rows="2" class="mt-1 w-full rounded-xl border border-pink-100 px-3 py-2.5 font-normal"></textarea></label></div><p v-if="error" class="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{{ error }}</p><div class="mt-5 flex gap-2"><button type="submit" class="rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-bold text-white">{{ editingId ? 'Guardar cambios' : 'Crear proveedor' }}</button><button type="button" class="rounded-xl border border-pink-200 px-5 py-2.5 text-sm font-bold" @click="showForm = false; resetForm()">Cancelar</button></div></form>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm"><table class="w-full min-w-200 text-sm"><thead><tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500"><th class="px-5 py-4">Proveedor</th><th class="px-5 py-4">Documento</th><th class="px-5 py-4">Contacto</th><th class="px-5 py-4">Teléfono</th><th class="px-5 py-4">Ciudad</th><th class="px-5 py-4">Acciones</th></tr></thead><tbody><tr v-for="supplier in suppliers" :key="supplier.id" class="cursor-pointer border-b border-pink-50 transition hover:bg-pink-50/60" tabindex="0" @click="openDetails(supplier)" @keydown.enter="openDetails(supplier)"><td class="px-5 py-4 font-bold">{{ supplier.name }}</td><td class="px-5 py-4">{{ supplier.document_number || '—' }}</td><td class="px-5 py-4">{{ supplier.contact_name || '—' }}</td><td class="px-5 py-4">{{ supplier.phone || '—' }}</td><td class="px-5 py-4">{{ supplier.city || '—' }}</td><td class="px-5 py-4"><div class="flex gap-2"><button class="rounded-lg border border-pink-200 px-3 py-1.5 text-xs font-bold text-[var(--primary)]" @click.stop="openEdit(supplier)">Editar</button><button class="rounded-lg border border-red-200 px-3 py-1.5 text-xs font-bold text-red-500" @click.stop="deactivate(supplier)">Desactivar</button></div></td></tr></tbody></table><p v-if="!suppliers.length" class="p-10 text-center text-neutral-500">No hay proveedores activos registrados.</p></div>

    <Teleport to="body">
      <div v-if="selectedSupplier" class="fixed inset-0 z-100">
        <button class="absolute inset-0 bg-black/45" aria-label="Cerrar detalle del proveedor" @click="closeDetails"></button>
        <div class="absolute inset-0 flex items-center justify-center overflow-y-auto p-4">
          <section class="relative max-h-[90vh] w-full max-w-md overflow-y-auto rounded-3xl bg-white p-6 shadow-2xl sm:p-8">
            <header class="flex items-start justify-between gap-4 border-b border-pink-100 pb-5">
              <div><p class="text-xs font-bold uppercase tracking-widest text-[var(--primary)]">Detalle del proveedor</p><h3 class="mt-2 text-2xl font-bold text-black">{{ selectedSupplier.name }}</h3></div>
              <button class="rounded-full p-2 text-xl hover:bg-pink-50" aria-label="Cerrar" @click="closeDetails">×</button>
            </header>
            <dl class="mt-6 grid gap-5 text-sm">
              <div><dt class="font-bold text-neutral-500">NIT / documento</dt><dd class="mt-1 text-neutral-800">{{ selectedSupplier.document_number || selectedSupplier.documentNumber || 'No registrado' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Contacto principal</dt><dd class="mt-1 text-neutral-800">{{ selectedSupplier.contact_name || selectedSupplier.contactName || 'No registrado' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Teléfono</dt><dd class="mt-1 text-neutral-800">{{ selectedSupplier.phone || 'No registrado' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Correo electrónico</dt><dd class="mt-1 break-words text-neutral-800">{{ selectedSupplier.email || 'No registrado' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Ciudad</dt><dd class="mt-1 text-neutral-800">{{ selectedSupplier.city || 'No registrada' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Dirección</dt><dd class="mt-1 text-neutral-800">{{ selectedSupplier.address || 'No registrada' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Condiciones de pago</dt><dd class="mt-1 text-neutral-800">{{ selectedSupplier.payment_terms || selectedSupplier.paymentTerms || 'No registradas' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Notas</dt><dd class="mt-1 whitespace-pre-wrap text-neutral-800">{{ selectedSupplier.notes || 'Sin notas' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Estado</dt><dd class="mt-1 font-bold text-emerald-600">{{ selectedSupplier.active === false ? 'Inactivo' : 'Activo' }}</dd></div>
              <div><dt class="font-bold text-neutral-500">Fecha de registro</dt><dd class="mt-1 text-neutral-800">{{ selectedSupplier.created_at || selectedSupplier.createdAt || 'No disponible' }}</dd></div>
            </dl>
          </section>
        </div>
      </div>
    </Teleport>
  </div>
</template>
