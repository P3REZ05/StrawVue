<script setup>
import { socialLinks } from '../../data/mockData'
</script>

<template>
  <footer class="bg-black py-7 text-white">
    <div class="mx-auto max-w-7xl px-5 sm:px-8 lg:px-10">
      <div class="flex flex-col items-center justify-between gap-4 text-center md:flex-row md:text-left">
        <div>
          <p class="text-sm font-semibold tracking-[0.22em] text-[var(--primary)] uppercase">Strawberry Makeup</p>
          <p class="mt-1 text-sm text-white/70">© {{ new Date().getFullYear() }} Todos los derechos reservados.</p>
        </div>

        <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-1 text-sm font-medium md:justify-end">
          <a class="transition hover:text-[var(--primary)]" :href="socialLinks.facebook" aria-label="Facebook de Strawberry Makeup">Facebook</a>
          <a class="transition hover:text-[var(--primary)]" :href="socialLinks.tiktok" aria-label="TikTok de Strawberry Makeup">TikTok</a>
          <a class="transition hover:text-[var(--primary)]" :href="socialLinks.instagram" aria-label="Instagram de Strawberry Makeup">Instagram</a>
          <RouterLink class="transition hover:text-[var(--primary)]" to="/terminos">Términos</RouterLink>
        </div>
      </div>
    </div>
  </footer>
</template>
