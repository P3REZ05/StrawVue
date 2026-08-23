<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAdminStore } from '../../stores/admin'
import { isSupabaseConfigured } from '../../lib/supabase'
import logo from '../../assets/images/strawberrymakeup.png'

const router = useRouter()
const admin = useAdminStore()
const form = reactive({ user: '', password: '' })
const error = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  if (!form.user.trim() || !form.password.trim()) {
    error.value = 'Ingresa usuario y contraseña para continuar.'
    return
  }

  loading.value = true
  try {
    await admin.login(form.user, form.password)
    router.push('/admin/dashboard')
  } catch (loginError) {
    error.value = loginError.message || 'No se pudo iniciar sesión.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="grid min-h-screen bg-pink-50/60 md:grid-cols-2"><section class="hidden items-center justify-center bg-[var(--success)] p-12 md:flex"><img :src="logo" alt="Strawberry Makeup" class="w-full max-w-md object-contain" /></section><section class="flex items-center justify-center p-5"><form class="w-full max-w-md rounded-3xl bg-white p-8 shadow-xl sm:p-10" @submit.prevent="submit"><p class="text-sm font-bold tracking-[0.2em] text-[var(--primary)]">ADMINISTRACIÓN</p><h1 class="mt-3 text-4xl font-bold">Iniciar sesión</h1><p class="mt-3 text-sm leading-6 text-neutral-500">Accede para gestionar productos y pedidos.</p><p class="mt-5 rounded-xl bg-pink-50 p-3 text-xs leading-5 text-neutral-600">{{ isSupabaseConfigured ? 'Usa las credenciales de tu usuario Supabase.' : 'Modo demo: admin@strawberrymakeup.com / strawberry2026' }}</p><p v-if="error" class="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-600">{{ error }}</p><div class="mt-6 space-y-4"><input v-model="form.user" class="w-full rounded-xl border border-pink-100 px-4 py-3 outline-none focus:border-[var(--primary)]" placeholder="Usuario" /><input v-model="form.password" type="password" class="w-full rounded-xl border border-pink-100 px-4 py-3 outline-none focus:border-[var(--primary)]" placeholder="Contraseña" /></div><button :disabled="loading" class="mt-6 w-full rounded-full bg-[var(--primary)] py-3 text-sm font-bold text-white transition hover:bg-[var(--info)] disabled:cursor-wait disabled:opacity-60">{{ loading ? 'Validando...' : 'Ingresar' }}</button></form></section></main>
</template>
