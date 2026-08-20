<script setup>
import Header from './components/layout/Header.vue'
import Footer from './components/layout/Footer.vue'
import { RouterView } from 'vue-router'
import CartDrawer from './components/cart/CartDrawer.vue'
</script>

<template>
  <Header />
  <RouterView />
  <Footer />
  <CartDrawer />
</template>
