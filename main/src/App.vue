<script setup>
import { onMounted, ref } from 'vue'
import Header from './components/layout/Header.vue'
import Footer from './components/layout/Footer.vue'
import { RouterView } from 'vue-router'
import CartDrawer from './components/cart/CartDrawer.vue'
import { useInventoryStore } from './stores/inventory'
import loadingLogo from './assets/images/strawberryLoading.png'

const appReady = ref(false)
const inventoryStore = useInventoryStore()

function preloadImage(src) {
  return new Promise((resolve) => {
    const img = new Image()
    img.onload = () => resolve()
    img.onerror = () => resolve()
    img.src = src
  })
}

onMounted(async () => {
  try {
    await Promise.all([
      inventoryStore.init(),
      preloadImage(loadingLogo)
    ])
  } catch (error) {
    console.error('No se pudo cargar la aplicación:', error)
  } finally {
    appReady.value = true
  }
})
</script>

<template>
  <template v-if="!appReady">
    <div class="loading-screen">
      <div class="loader-wrap">
        <img :src="loadingLogo" alt="Cargando Strawberry Makeup" class="loader-logo" />
        <p class="loading-text">Cargando</p>
      </div>
    </div>
  </template>

  <template v-else>
    <Header />
    <RouterView />
    <Footer />
    <CartDrawer />
  </template>
</template>

<style scoped>
.loading-screen {
  position: fixed;
  inset: 0;
  z-index: 200;
  display: grid;
  place-items: center;
  background: #ffffff;
}

.loader-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
}

.loader-logo {
  width: 110px;
  height: 110px;
  object-fit: contain;
  animation: spin 1.2s linear infinite;
  filter: drop-shadow(0 0 18px rgba(255, 122, 179, 0.35));
}

.loading-text {
  margin: 0;
  color: #111111;
  font-size: 0.85rem;
  font-weight: 700;
  letter-spacing: 0.22em;
  text-transform: uppercase;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
