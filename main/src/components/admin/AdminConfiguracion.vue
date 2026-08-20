<script setup>
import { ref } from 'vue'
import { adminUsers } from '../../data/mockData'

const admins = ref([...adminUsers])
</script>

<template>
  <div class="space-y-6">
    <h2 class="text-2xl font-bold text-black">Configuración</h2>
    <p class="text-sm text-neutral-500">Administradores del sistema y configuración de la cuenta.</p>

    <div class="overflow-x-auto rounded-2xl bg-white shadow-sm">
      <table class="w-full min-w-150 text-sm">
        <thead>
          <tr class="border-b border-pink-100 text-left text-xs font-bold uppercase tracking-wider text-neutral-500">
            <th class="px-5 py-4">#</th>
            <th class="px-5 py-4">Nombre</th>
            <th class="px-5 py-4">Email</th>
            <th class="px-5 py-4">Rol</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="admin in admins" :key="admin.id" class="border-b border-pink-50 transition hover:bg-pink-50/50">
            <td class="px-5 py-4 font-semibold">{{ admin.id }}</td>
            <td class="px-5 py-4">{{ admin.nombre }}</td>
            <td class="px-5 py-4">{{ admin.email }}</td>
            <td class="px-5 py-4">
              <span class="inline-flex rounded-full bg-[var(--success)] px-3 py-1 text-xs font-bold text-[var(--primary)]">
                {{ admin.role }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>