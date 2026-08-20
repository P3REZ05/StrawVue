<script setup>
const benefits = [
  {
    icon: '🚚',
    title: 'ENVÍOS 100% SEGUROS',
    text: 'Realizamos envíos a todo el país de manera segura y confiable. Ofrecemos diferentes métodos de pago incluyendo contraentrega para tu comodidad y tranquilidad.',
  },
  {
    icon: '★',
    title: 'PRODUCTOS PREMIUM',
    text: 'Trabajamos con las mejores marcas del mercado para garantizar productos de alta calidad. Cada artículo es cuidadosamente seleccionado.',
  },
  {
    icon: '🏷',
    title: 'VENTA MAYORISTA Y MINORISTA',
    text: 'Precios especiales para compras al por mayor. Descubre paquetes y promociones exclusivas para distribuidores y profesionales.',
  },
]
</script>

<template>
  <section class="mx-auto max-w-7xl px-5 py-18 sm:px-8 lg:px-10">
    <div class="grid gap-8 md:grid-cols-3">
      <article
        v-for="benefit in benefits"
        :key="benefit.title"
        class="group rounded-2xl px-6 py-8 text-center transition hover:-translate-y-1 hover:bg-pink-50"
      >
        <span class="text-4xl text-[var(--primary)]">{{ benefit.icon }}</span>
        <h2 class="mt-5 text-xl font-bold text-[var(--success)]">
          {{ benefit.title }}
        </h2>
        <p class="mx-auto mt-4 max-w-xs leading-7 text-neutral-600">
          {{ benefit.text }}
        </p>
        <div class="mx-auto mt-6 h-0.75 w-12 bg-[var(--primary)]"></div>
      </article>
    </div>
  </section>
</template>
