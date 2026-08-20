import { defineStore } from 'pinia'
import { products as mockProducts } from '../data/mockData'

export const useInventoryStore = defineStore('inventory', {
  state: () => ({
    // Catálogo maestro: productos base creados en inventario de compras
    catalog: [...mockProducts],

    // Órdenes de compra: entradas al almacén
    purchaseOrders: [
      { id: 1, orderNumber: 'PC-001', supplier: 'Distribuidora Maquillaje SAS', date: '2026-08-10', notes: '', items: [
        { productId: 1, quantity: 10, toSale: 5 },
        { productId: 3, quantity: 10, toSale: 2 }
      ] },
      { id: 2, orderNumber: 'PC-002', supplier: 'CosmeticImport', date: '2026-08-12', notes: 'Segunda compra', items: [
        { productId: 2, quantity: 5, toSale: 5 }
      ] }
    ],

    // Inventario de venta: productos con stock listo para vender
    saleInventory: [
      { id: 1, productId: 1, quantity: 5, costPrice: 18000 },
      { id: 2, productId: 2, quantity: 3, costPrice: 22000 },
      { id: 3, productId: 3, quantity: 8, costPrice: 12000 }
    ],

    // Almacén / bodega: productos comprados que aún no están a la venta
    warehouse: [
      { id: 1, productId: 1, quantity: 2, costPrice: 15000 }
    ],

    // Ventas físicas realizadas
    sales: [
      { id: 1, date: '2026-08-15', items: [{ productId: 1, quantity: 3, price: 38900 }], total: 116700, paymentMethod: 'efectivo' }
    ]
  }),

  getters: {
    // Obtener catálogo con stock de venta disponible
    catalogWithStock: (state) => {
      return state.catalog.map((product) => {
        const saleItem = state.saleInventory.find((item) => item.productId === product.id)
        const warehouseItem = state.warehouse.find((item) => item.productId === product.id)
        return {
          ...product,
          saleStock: saleItem?.quantity || 0,
          warehouseStock: warehouseItem?.quantity || 0
        }
      })
    },

    // Productos disponibles para la venta física (POS)
    saleProducts: (state) => {
      return state.saleInventory
        .filter((item) => item.quantity > 0)
        .map((item) => {
          const product = state.catalog.find((p) => p.id === item.productId)
          return { ...item, ...product }
        })
    }
  },

  actions: {
    // --- Catálogo ---
    addProduct(product) {
      const id = Math.max(...this.catalog.map((p) => p.id), 0) + 1
      this.catalog.push({ id, ...product })
      return id
    },

    updateProduct(productId, updates) {
      const idx = this.catalog.findIndex((p) => p.id === productId)
      if (idx !== -1) this.catalog[idx] = { ...this.catalog[idx], ...updates }
    },

    deleteProduct(productId) {
      this.catalog = this.catalog.filter((p) => p.id !== productId)
    },

    // ---- Compras ----
    addPurchaseOrder(order) {
      const id = this.purchaseOrders.length ? Math.max(...this.purchaseOrders.map((p) => p.id)) + 1 : 1
      const orderNumber = `PO-${String(id).padStart(3, '0')}`
      this.purchaseOrders.push({ id, orderNumber, ...order })
      return id
    },

    // ---- Inventario de venta ----
    addToSaleInventory(productId, quantity, costPrice) {
      const existing = this.saleInventory.find((item) => item.productId === productId)
      if (existing) {
        existing.quantity += quantity
        if (costPrice) existing.costPrice = costPrice
      } else {
        const id = this.saleInventory.length ? Math.max(...this.saleInventory.map((p) => p.id)) + 1 : 1
        this.saleInventory.push({ id, productId, quantity, costPrice })
      }
    },

    moveFromWarehouseToSale(productId, quantity) {
      const wItem = this.warehouse.find((item) => item.productId === productId)
      if (!wItem || wItem.quantity < quantity) return false

      wItem.quantity -= quantity
      this.addToSaleInventory(productId, quantity, wItem.costPrice)

      // Limpiar bodega si queda en 0
      this.warehouse = this.warehouse.filter((item) => item.quantity > 0)
      return true
    },

    updateSalePrice(productId, salePrice) {
      const item = this.saleInventory.find((i) => i.productId === productId)
      const product = this.catalog.find((p) => p.id === productId)
      if (item && product) {
        product.salePrice = salePrice
      }
    },

    toggleProductActive(productId, active) {
      const product = this.catalog.find((p) => p.id === productId)
      if (product) product.active = active
    },

    // ---- Ventas (POS físico) ----
    registerSale(saleData) {
      // Reducir stock de venta
      saleData.items.forEach((saleItem) => {
        const invItem = this.saleInventory.find((i) => i.productId === saleItem.productId)
        if (invItem) {
          invItem.quantity = Math.max(0, invItem.quantity - saleItem.quantity)
        }
      })

      const id = this.sales.length ? Math.max(...this.sales.map((s) => s.id)) + 1 : 1
      this.sales.push({ id, ...saleData })
    }
  }
})