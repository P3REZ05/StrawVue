import { defineStore } from 'pinia'

const getSavedItems = () => JSON.parse(localStorage.getItem('strawberry-cart') || '[]')

export const useCartStore = defineStore('cart', {
  state: () => ({ items: getSavedItems(), drawerOpen: false }),
  getters: {
    count: (state) => state.items.reduce((total, item) => total + (item.quantity || 0), 0),
    subtotal: (state) => state.items.reduce((total, item) => total + item.price * item.quantity, 0)
  },
  actions: {
    add(product, quantity = 1) {
      const itemKey = product.variantId ? `${product.id}-${product.variantId}` : product.id
      const existingItem = this.items.find((item) => (item.variantId ? `${item.id}-${item.variantId}` : item.id) === itemKey)
      const available = Number(product.saleStock ?? product.stock ?? Infinity)

      if (!Number.isFinite(available) || available <= 0) {
        return
      }

      if (existingItem) {
        existingItem.quantity = Math.min(existingItem.quantity + quantity, available)
      } else {
        this.items.push({ ...product, quantity: Math.min(quantity, available) })
      }

      this.save()
    },
    clear() {
      this.items = []
      this.save()
    },
    openDrawer() {
      this.drawerOpen = true
    },
    closeDrawer() {
      this.drawerOpen = false
    },
    updateQuantity(id, quantity) {
      const item = this.items.find((product) => product.id === id)
      if (!item) return

      const available = Number(item.saleStock ?? item.stock ?? Infinity)

      if (quantity <= 0) {
        this.remove(id)
        return
      }

      item.quantity = Math.min(quantity, Number.isFinite(available) ? available : quantity)
      this.save()
    },
    remove(id) {
      this.items = this.items.filter((item) => item.id !== id)
      this.save()
    },
    save() {
      localStorage.setItem('strawberry-cart', JSON.stringify(this.items))
    }
  }
})
