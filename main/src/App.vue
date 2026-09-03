<script setup>
import { computed, onMounted, ref } from 'vue'
import Header from './components/layout/Header.vue'
import Footer from './components/layout/Footer.vue'
import { RouterView, useRoute } from 'vue-router'
import CartDrawer from './components/cart/CartDrawer.vue'
import { useInventoryStore } from './stores/inventory'
import loadingLogo from './assets/images/strawberryLoading.png'

const appReady = ref(false)
const loadError = ref('')
const inventoryStore = useInventoryStore()
const route = useRoute()
const isAdminRoute = computed(() => route.path.startsWith('/admin'))

function reload() {
  window.location.reload()
}

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
    // Antes este error solo se imprimía en consola y la tienda se mostraba
    // vacía, como si no hubiera productos. Ahora se dice lo que pasó.
    loadError.value = error?.message || 'No se pudo conectar con el servidor.'
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

  <template v-else-if="loadError">
    <div class="loading-screen">
      <div class="loader-wrap">
        <img :src="loadingLogo" alt="Strawberry Makeup" class="loader-logo error-logo" />
        <p class="loading-text">No se pudo cargar la tienda</p>
        <p class="error-detail">{{ loadError }}</p>
        <button class="retry-button" @click="reload">Reintentar</button>
      </div>
    </div>
  </template>

  <template v-else>
    <Header />
    <RouterView />
    <Footer v-if="!isAdminRoute" />
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

.error-logo {
  animation: none;
  opacity: 0.6;
}

.error-detail {
  margin: 0;
  max-width: 32rem;
  text-align: center;
  color: #6b7280;
  font-size: 0.85rem;
  line-height: 1.5;
}

.retry-button {
  margin-top: 0.5rem;
  border-radius: 9999px;
  background: var(--primary, #ff7ab3);
  padding: 0.6rem 1.6rem;
  font-size: 0.8rem;
  font-weight: 700;
  color: #ffffff;
  cursor: pointer;
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
