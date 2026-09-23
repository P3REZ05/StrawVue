<script setup>
import Hero from '../components/home/Hero.vue'
import HomeAds from '../components/home/HomeAds.vue'
import HomeHistory from '../components/home/HomeHistory.vue'
import HomeText from '../components/home/HomeText.vue'
import HomeCollections from '../components/home/HomeCollections.vue'
</script>

<template>
  <main id="inicio">
    <Hero />
    <HomeAds />
    <HomeHistory />
    <HomeText />
    <!--
      Este sitio de la portada ya ha tenido tres inquilinos: «Encuentra lo
      tuyo» (una cuadrícula de dieciséis categorías) y la pasarela de marcas.
      Ahora, las colecciones. Se retira lo anterior en vez de acumularlo: una
      portada es una decisión sobre qué NO enseñar.
    -->
    <HomeCollections />
  </main>
</template>
