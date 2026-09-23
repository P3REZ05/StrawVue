import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  build: {
    rollupOptions: {
      output: {
        // Las dependencias se separan del código propio a propósito: cambian
        // mucho menos, así que el navegador se las queda en caché aunque
        // publiquemos la tienda tres veces al día.
        //
        // `supabase` va aparte de `vue` porque es la más pesada con diferencia
        // y su versión se mueve por su cuenta.
        manualChunks(id) {
          if (!id.includes('node_modules')) return
          if (id.includes('@supabase')) return 'vendor-supabase'
          // `@vue/runtime-core`, `@vue/shared` y `@vue/reactivity` viven en
          // carpetas propias: sin el `@vue/` acababan en el saco genérico y
          // `vendor` era una caja negra de 77 KB.
          if (id.includes('/@vue/') || id.includes('/vue/') || id.includes('vue-router') || id.includes('/pinia/')) {
            return 'vendor-vue'
          }
          if (id.includes('lucide-vue-next')) return 'vendor-iconos'
          return 'vendor'
        }
      }
    }
  }
})
