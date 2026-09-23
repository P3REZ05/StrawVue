import { defineStore } from 'pinia'

/**
 * Favoritos de la clienta.
 *
 * Se guardan en el navegador, igual que el carrito. La tienda no tiene
 * cuentas de cliente —es una decisión tomada, no una carencia—, así que no hay
 * a quién ligar la lista en la base. Lo que se guarda es lo mínimo: una lista
 * de identificadores. El producto entero se resuelve al pintar la página, así
 * que un cambio de precio o de foto se ve al instante y un producto retirado
 * desaparece solo en vez de quedarse como un fantasma con datos viejos.
 *
 * Solo guarda `productId`, no el tono. El corazón está en la tarjeta, donde
 * todavía no se ha elegido color; obligar a elegir tono para guardar algo que
 * te gustó sería pedir la decisión justo antes de que la clienta esté lista
 * para tomarla.
 */

const CLAVE = 'strawberry-favoritos'

function leerGuardados() {
  try {
    const crudo = JSON.parse(localStorage.getItem(CLAVE) || '[]')
    if (!Array.isArray(crudo)) return []
    // Se normaliza a número y se quitan repetidos: una lista guardada por una
    // versión anterior podría traer textos, y `includes` no los encontraría.
    return [...new Set(crudo.map(Number).filter(Number.isFinite))]
  } catch {
    // Un `localStorage` corrupto no puede tumbar la tienda entera.
    return []
  }
}

export const useFavoritesStore = defineStore('favorites', {
  state: () => ({ ids: leerGuardados() }),

  getters: {
    count: (state) => state.ids.length,
    esFavorito: (state) => (productId) => state.ids.includes(Number(productId))
  },

  actions: {
    alternar(productId) {
      const id = Number(productId)
      if (!Number.isFinite(id)) return false
      const i = this.ids.indexOf(id)
      if (i === -1) this.ids.unshift(id)
      else this.ids.splice(i, 1)
      this.guardar()
      return this.ids.includes(id)
    },

    quitar(productId) {
      const id = Number(productId)
      const i = this.ids.indexOf(id)
      if (i === -1) return
      this.ids.splice(i, 1)
      this.guardar()
    },

    vaciar() {
      this.ids = []
      this.guardar()
    },

    guardar() {
      try {
        localStorage.setItem(CLAVE, JSON.stringify(this.ids))
      } catch {
        // Cuota llena o modo privado: la lista sigue viva en esta sesión.
      }
    }
  }
})
