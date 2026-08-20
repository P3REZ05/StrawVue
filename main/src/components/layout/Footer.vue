<script setup>
import { socialLinks } from '../../data/mockData'
</script>

<template>
  <footer class="bg-black py-12 text-center text-white">
    <div class="mx-auto max-w-7xl px-5 sm:px-8 lg:px-10"><p class="text-sm text-white/80">© {{ new Date().getFullYear() }} Strawberry Makeup. Todos los derechos reservados.</p><div class="mt-6 flex flex-wrap justify-center gap-x-7 gap-y-3"><a class="text-sm font-semibold transition hover:text-[var(--primary)]" :href="socialLinks.facebook" aria-label="Facebook de Strawberry Makeup">Facebook</a><a class="text-sm font-semibold transition hover:text-[var(--primary)]" :href="socialLinks.tiktok" aria-label="TikTok de Strawberry Makeup">TikTok</a><a class="text-sm font-semibold transition hover:text-[var(--primary)]" :href="socialLinks.instagram" aria-label="Instagram de Strawberry Makeup">Instagram</a><RouterLink class="text-sm font-semibold transition hover:text-[var(--primary)]" to="/terminos">Términos y condiciones</RouterLink></div></div>
  </footer>
</template>
