import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { logAudit } from '../lib/auditLog'
import { useCatalogStore } from './catalog'

// Store de inventario: existencias, compras, proveedores y ventas físicas.
//
// El catálogo (productos, tonos y tablas maestras) se movió a `catalog.js`.
// Aquí quedan solo las existencias, que se derivan de `inventory_movements`.
// Los accesos al catálogo se mantienen como getters delegados para no romper
// las pantallas que ya los usaban; el código nuevo debe usar `useCatalogStore`
// directamente.

export const useInventoryStore = defineStore('inventory', {
  state: () => ({
    suppliers: [],
    movements: [],
    balances: [],

    // Órdenes de compra: entradas al almacén
    purchaseOrders: [],

    // Inventario de venta (derivado de inventory_movements)
    saleInventory: [],

    // Bodega (derivada de inventory_movements)
    warehouse: [],

    // Ventas físicas realizadas
    sales: [],

    // Estado de carga
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    // --- Delegaciones al store de catálogo -------------------------------
    // Existen para que las pantallas anteriores sigan funcionando durante la
    // migración. Son de solo lectura: escribir catálogo va por catalog.js.
    catalog: () => useCatalogStore().products,
    variants: () => useCatalogStore().shades,
    categories: () => useCatalogStore().categories,
    brands: () => useCatalogStore().brands,
    skinTypes: () => useCatalogStore().skinTypes,
    finishes: () => useCatalogStore().finishes,
    coverages: () => useCatalogStore().coverages,
    undertones: () => useCatalogStore().undertones,
    shadeFamilies: () => useCatalogStore().shadeFamilies,

    // Catálogo con las existencias ya resueltas. Es el punto donde se cruzan
    // los dos stores: la ficha comercial y el saldo derivado de movimientos.
    catalogWithStock: (state) => {
      const catalogo = useCatalogStore()
      return catalogo.products.map((product) => {
        const saleItem = state.saleInventory.find((item) => item.productId === product.id)
        const warehouseItem = state.warehouse.find((item) => item.productId === product.id)
        const productVariants = catalogo.shades.filter((variant) => variant.productId === product.id && variant.isActive !== false)
        const baseBalance = state.balances.find((balance) => balance.productId === product.id && !balance.variantId)
        const balanceRows = state.balances.filter((balance) => balance.productId === product.id)
        const saleStock = baseBalance ? baseBalance.saleStock : saleItem?.quantity || 0
        const warehouseStock = baseBalance ? baseBalance.warehouseStock : warehouseItem?.quantity || 0
        const variantStock = productVariants.reduce((total, variant) => {
          const balance = state.balances.find((row) => row.variantId === variant.id)
          return total + (balance ? balance.saleStock : 0)
        }, 0)
        // La imagen sale de `product_images`; `product.image` es la columna
        // legacy y puede contener una URL `blob:` muerta de antes de Storage.
        const imagenPrincipal = catalogo.primaryImageOf(product.id)
        const imagenLegacy = product.image?.startsWith('blob:') ? '' : product.image

        const vitrina = catalogo.storefrontProducts.find((f) => f.product_id === product.id)

        return {
          ...product,
          image: imagenPrincipal?.url || imagenLegacy || '',
          basePrice: vitrina ? Number(vitrina.base_price) : (product.salePrice ?? product.price),
          promoPrice: vitrina ? Number(vitrina.effective_price) : null,
          enPromocion: vitrina ? Number(vitrina.effective_price) < Number(vitrina.base_price) : false,
          promoLabel: vitrina?.promo_label || '',
          variants: productVariants,
          stock: productVariants.length ? variantStock : saleStock,
          saleStock: productVariants.length ? variantStock : saleStock,
          warehouseStock: productVariants.length
            ? productVariants.reduce((total, variant) => total + (state.balances.find((row) => row.variantId === variant.id)?.warehouseStock || 0), 0)
            : warehouseStock,
          hasMovementBalance: Boolean(baseBalance || balanceRows.length)
        }
      })
    },

    // Tonos listos para la vitrina: precio heredado ya resuelto, existencias
    // reales del tono e imagen propia si la tiene.
    //
    // Antes la ficha leía `variant.stock`, una columna legacy que ya no se
    // carga: salía "undefined disponibles" y los tonos agotados nunca se
    // deshabilitaban.
    shadesWithStock: (state) => (productId) => {
      const catalogo = useCatalogStore()
      return catalogo.shadesOf(Number(productId)).map((tono) => {
        const saldo = state.balances.find((b) => b.variantId === tono.id)
        const propia = catalogo.imagesOf(Number(productId), tono.id)[0]
        // El precio con promoción lo calcula la base (vista storefront_shades).
        // Aquí solo se usa como respaldo el precio heredado, por si la vista
        // todavía no cargó.
        const vitrina = catalogo.storefrontShades.find((f) => f.variant_id === tono.id)
        const base = vitrina ? Number(vitrina.base_price) : catalogo.precioDeTono(tono)
        const efectivo = vitrina ? Number(vitrina.effective_price) : base
        return {
          ...tono,
          basePrice: base,
          price: efectivo,
          enPromocion: efectivo < base,
          promoLabel: vitrina?.promo_label || '',
          promoTitle: vitrina?.promo_title || '',
          heredaPrecio: tono.price == null,
          stock: Math.max(Number(saldo?.saleStock) || 0, 0),
          image: propia?.url || tono.swatchImageUrl || ''
        }
      })
    },

    // Productos disponibles para la venta física (POS)
    saleProducts: (state) => {
      return state.saleInventory
        .filter((item) => item.quantity > 0)
        .map((item) => {
          const product = useCatalogStore().products.find((p) => p.id === item.productId)
          return { ...item, ...product }
        })
    }
  },

  actions: {
    // `balances` viene de la vista inventory_balances: `saleStock` YA ES el
    // stock disponible para vender (entradas a venta menos salidas), no una
    // reserva. La versión anterior hacía `variant.stock - balance.saleStock`,
    // restando el disponible de una columna legacy que casi siempre vale 0.
    // El resultado era 0 para todo, así que validateOrderItems rechazaba
    // cualquier pedido antes de llegar a Supabase.
    getVariantAvailableStock(variantId) {
      const balance = this.balances.find((row) => row.variantId === variantId)
      return Math.max(Number(balance?.saleStock) || 0, 0)
    },

    // Costo promedio ponderado de las entradas por compra. La tabla de saldos
    // no guarda costo (el stock se deriva de movimientos), así que sin esto las
    // columnas de Costo y Ganancia mostrarían cero siempre.
    getAverageCost(productId, variantId = null) {
      const purchases = this.movements.filter(
        (movement) =>
          movement.type === 'purchase' &&
          movement.productId === productId &&
          (movement.variantId ?? null) === (variantId ?? null) &&
          movement.quantity > 0
      )
      if (!purchases.length) return 0

      const units = purchases.reduce((total, movement) => total + movement.quantity, 0)
      if (!units) return 0

      const cost = purchases.reduce((total, movement) => total + movement.quantity * (movement.unitCost || 0), 0)
      return cost / units
    },

    getProductAvailableStock(productId, variantId = null) {
      if (variantId) {
        return this.getVariantAvailableStock(variantId)
      }

      // Si el producto tiene variantes, el disponible es la suma de ellas.
      const variants = this.variants.filter((variant) => variant.productId === productId && variant.isActive !== false)
      if (variants.length) {
        return variants.reduce((total, variant) => total + this.getVariantAvailableStock(variant.id), 0)
      }

      const balance = this.balances.find((row) => row.productId === productId && !row.variantId)
      return Math.max(Number(balance?.saleStock) || 0, 0)
    },

    validateOrderItems(items) {
      const issues = []

      for (const item of items) {
        const productId = Number(item.productId ?? item.id)
        const variantId = item.variantId ? Number(item.variantId) : null
        const quantity = Number(item.quantity) || 0

        if (!productId || quantity <= 0) {
          issues.push({ productId, variantId, quantity, available: 0, message: 'La cantidad solicitada debe ser mayor a cero.' })
          continue
        }

        const available = this.getProductAvailableStock(productId, variantId)

        if (quantity > available) {
          issues.push({
            productId,
            variantId,
            quantity,
            available,
            message: `No hay suficiente stock para ${item.name || item.productName || 'este producto'}. Disponibles: ${available}.`
          })
        }
      }

      return { valid: issues.length === 0, issues }
    },

    // Reingresa el stock de un pedido devuelto.
    //
    // Antes esto hacía DELETE sobre inventory_movements, borrando la salida
    // original. Eso rompía el principio central del proyecto: el stock se
    // deriva del historial, y un historial que se puede borrar no sirve como
    // fuente de verdad ni como auditoría.
    //
    // Ahora la base inserta un movimiento 'return' compensatorio y el
    // historial queda completo: se ve que salió y que volvió.
    async releaseOrderStock(orderId) {
      const { error } = await supabase.rpc('return_order_stock', { p_order_id: orderId })
      if (error) throw new Error('No se pudo reingresar el stock de la devolución.')
      await this.refreshBalances()
    },

    // Relee los saldos derivados de inventory_movements.
    async refreshBalances() {
      const { data, error } = await supabase.from('inventory_balances').select('*')
      if (error) {
        console.error('No se pudieron refrescar los saldos de inventario:', error.message)
        return false
      }

      this.balances = (data || []).map((balance) => ({
        productId: balance.product_id,
        variantId: balance.variant_id,
        warehouseStock: Number(balance.warehouse_stock) || 0,
        saleStock: Number(balance.sale_stock) || 0
      }))
      this.syncDerivedInventory()
      return true
    },

    // Proyecta `balances` sobre las listas que consumen los componentes.
    syncDerivedInventory() {
      this.saleInventory = this.balances
        .filter((balance) => balance.saleStock > 0)
        .map((balance, index) => ({
          id: `balance-sale-${index}`,
          productId: balance.productId,
          variantId: balance.variantId,
          quantity: balance.saleStock,
          costPrice: 0
        }))
      this.warehouse = this.balances
        .filter((balance) => balance.warehouseStock > 0)
        .map((balance, index) => ({
          id: `balance-warehouse-${index}`,
          productId: balance.productId,
          variantId: balance.variantId,
          quantity: balance.warehouseStock,
          costPrice: 0
        }))
    },

    // ================================================
    // INICIALIZACIÓN / CARGA DESDE SUPABASE
    // ================================================
    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null

      try {
        // El catálogo lo carga su propio store. Antes esto duplicaba las
        // consultas de productos, tonos y tablas maestras.
        await useCatalogStore().init()

        const { data: suppliers, error: suppliersError } = await supabase
          .from('suppliers')
          .select('*')
          .eq('active', true)
          .order('name')

        if (suppliersError) throw suppliersError
        this.suppliers = suppliers || []

        const { data: movements, error: movementsError } = await supabase
          .from('inventory_movements')
          .select('*')
          .order('created_at', { ascending: false })

        if (!movementsError && movements?.length) {
          this.movements = movements.map((movement) => ({
            id: movement.id,
            productId: movement.product_id,
            variantId: movement.variant_id,
            type: movement.movement_type,
            quantity: Number(movement.quantity) || 0,
            unitCost: Number(movement.unit_cost) || 0,
            referenceType: movement.reference_type || '',
            referenceId: movement.reference_id,
            notes: movement.notes || '',
            createdAt: movement.created_at
          }))

        }

        // Los saldos se cargan SIEMPRE, no solo cuando ya hay movimientos:
        // antes esta consulta vivía dentro del `if (movements?.length)`, así
        // que en una base recién migrada `balances` quedaba vacío.
        await this.refreshBalances()

        // Cargar órdenes de compra
        const { data: orders, error: ordersError } = await supabase
          .from('purchase_orders')
          .select('*, purchase_order_items(*)')

        if (!ordersError && orders?.length) {
          this.purchaseOrders = orders.map((order) => ({
            id: order.id,
            orderNumber: order.order_number,
            supplierId: order.supplier_id,
            date: order.order_date,
            notes: order.notes || '',
            status: order.status,
            total: Number(order.total) || 0,
            items: (order.purchase_order_items || []).map((item) => ({
              productId: item.product_id,
              variantId: item.variant_id,
              quantity: item.quantity,
              costPrice: Number(item.unit_cost) || 0,
              destination: item.destination || 'warehouse'
            }))
          }))
        }

        // Cargar ventas
        const { data: sales, error: salesError } = await supabase
          .from('sales')
          .select('*, sale_items(*)')

        if (!salesError && sales?.length) {
          this.sales = sales.map((sale) => ({
            id: sale.id,
            date: sale.date,
            total: Number(sale.total) || 0,
            paymentMethod: sale.payment_method,
            items: (sale.sale_items || []).map((item) => ({
              productId: item.product_id,
              quantity: item.quantity,
              price: Number(item.price) || 0
            }))
          }))
        }

        this.initialized = true
      } catch (error) {
        this.error = error.message || 'No se pudo cargar el inventario.'
        console.error('Error inicializando inventario desde Supabase:', error)
        throw error
      } finally {
        this.loading = false
      }
    },

    // ================================================
    // CATÁLOGO
    // ================================================







    // --- Delegaciones al store de catálogo -------------------------------
    // El catálogo se administra en `catalog.js`. Estos envoltorios existen
    // para que las pantallas anteriores no se rompan mientras se migran.

    async addProduct(product) {
      const guardado = await useCatalogStore().saveProduct(product)
      return guardado.id
    },

    async updateProduct(productId, updates) {
      const catalogo = useCatalogStore()
      const actual = catalogo.productById(productId)
      return catalogo.saveProduct({ ...actual, ...updates, id: productId })
    },

    async deleteProduct(productId) {
      // Archivar, no borrar: el producto aparece en pedidos y movimientos.
      return useCatalogStore().archiveProduct(productId)
    },

    async toggleProductActive(productId, active) {
      return useCatalogStore().setProductStatus(productId, active ? 'active' : 'paused')
    },

    async saveCategory(category) {
      return useCatalogStore().saveCategory(category)
    },

    async saveCatalogOption(type, option) {
      return useCatalogStore().saveOption(type, option)
    },

    async addVariant(productId, variant) {
      return useCatalogStore().saveShade(productId, variant)
    },

    async updateVariant(variantId, updates) {
      const catalogo = useCatalogStore()
      const tono = catalogo.shades.find((s) => s.id === variantId)
      if (!tono) return
      return catalogo.saveShade(tono.productId, { ...tono, ...updates, id: variantId })
    },

    async deactivateVariant(variantId) {
      return useCatalogStore().deactivateShade(variantId)
    },

    async saveSupplier(supplier) {
      const payload = {
        name: supplier.name.trim(),
        document_number: supplier.documentNumber?.trim() || null,
        contact_name: supplier.contactName?.trim() || null,
        phone: supplier.phone?.trim() || null,
        email: supplier.email?.trim() || null,
        address: supplier.address?.trim() || null,
        city: supplier.city?.trim() || null,
        payment_terms: supplier.paymentTerms?.trim() || null,
        notes: supplier.notes?.trim() || null,
        active: true
      }

      if (!payload.name) throw new Error('El nombre del proveedor es obligatorio.')

      if (supplier.id && typeof supplier.id === 'number' && import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY) {
        const { data, error } = await supabase.from('suppliers').update(payload).eq('id', supplier.id).select().single()
        if (error) {
          if (error.code === '42501' || error.status === 403) throw new Error('Supabase rechazó la operación. Verifica tu sesión y que tu usuario exista en admin_profiles.')
          throw new Error('No se pudo actualizar el proveedor.')
        }
        const index = this.suppliers.findIndex((item) => item.id === supplier.id)
        if (index !== -1) this.suppliers[index] = data
        return data
      }

      if (supplier.id) {
        const index = this.suppliers.findIndex((item) => item.id === supplier.id)
        if (index !== -1) this.suppliers[index] = { ...this.suppliers[index], ...payload }
        return this.suppliers[index]
      }

      if (import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY) {
        const { data, error } = await supabase.from('suppliers').insert(payload).select().single()
        if (error) {
            console.error('Error al crear proveedor en Supabase:', error)
          if (error.code === '42501' || error.status === 403) throw new Error('Supabase rechazó la operación. Verifica tu sesión y que tu usuario exista en admin_profiles.')
          throw new Error('No se pudo crear el proveedor.')
        }
        this.suppliers.push(data)
        return data
      }

      const localSupplier = { id: `local-${Date.now()}`, ...payload }
      this.suppliers.push(localSupplier)
      return localSupplier
    },

    async deactivateSupplier(supplierId) {
      const supplier = this.suppliers.find((item) => item.id === supplierId)
      if (!supplier) return
      supplier.active = false

      if (typeof supplierId === 'number' && import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY) {
        const { error } = await supabase.from('suppliers').update({ active: false }).eq('id', supplierId)
        if (error) throw new Error('No se pudo desactivar el proveedor.')
      }
    },


    // ================================================
    // COMPRAS
    // ================================================
    async addPurchaseOrder(order) {
      const total = order.items.reduce((sum, item) => sum + item.quantity * item.costPrice, 0)
      const localId = this.purchaseOrders.length ? Math.max(...this.purchaseOrders.map((item) => item.id)) + 1 : 1

      const { data, error } = await supabase.from('purchase_orders').insert({
        supplier_id: order.supplierId || null,
        order_number: order.orderNumber || null,
        order_date: order.date || new Date().toISOString().slice(0, 10),
        notes: order.notes || null,
        status: 'received',
        total
      }).select().single()

      if (error) throw new Error('No se pudo registrar la orden de compra.')

      const { error: itemsError } = await supabase.from('purchase_order_items').insert(order.items.map((item) => ({
        purchase_order_id: data.id,
        product_id: item.productId || null,
        variant_id: item.variantId || null,
        quantity: item.quantity,
        unit_cost: item.costPrice,
        destination: 'warehouse'
      })))

      if (itemsError) throw new Error('No se pudieron registrar los productos comprados.')

      const { error: movementError } = await supabase.from('inventory_movements').insert(order.items.map((item) => ({
        product_id: item.productId || null,
        variant_id: item.variantId || null,
        movement_type: 'purchase',
        quantity: item.quantity,
        unit_cost: item.costPrice,
        reference_type: 'purchase_order',
        reference_id: data.id,
        notes: 'Entrada a bodega por compra'
      })))

      if (movementError) throw new Error('No se pudo registrar el movimiento de inventario.')

      this.purchaseOrders.unshift({ id: data.id, orderNumber: data.order_number || `PO-${data.id}`, ...order, total })

      // Los saldos los calcula la base a partir de los movimientos. Antes se
      // mutaba una copia local a mano, así que la pantalla y la base podían
      // mostrar cosas distintas: dos fuentes de verdad para el mismo número.
      await this.refreshBalances()
      return data.id
    },



    // ================================================
    // INVENTARIO DE VENTA
    // ================================================


    // Transfiere unidades de bodega al inventario de venta.
    //
    // La validación se hace contra `balances`, que viene de la base, no contra
    // la copia local. Y respeta la variante: antes el componente llamaba sin
    // variantId, así que una compra registrada contra un tono se transfería
    // como si fuera del producto base y los saldos nunca cuadraban.
    async moveFromWarehouseToSale(productId, quantity, variantId = null) {
      const requested = Number(quantity)
      if (!Number.isFinite(requested) || requested <= 0) {
        throw new Error('La cantidad a transferir debe ser mayor a cero.')
      }

      const balance = this.balances.find(
        (row) => row.productId === productId && (row.variantId ?? null) === (variantId ?? null)
      )
      const available = Number(balance?.warehouseStock) || 0

      if (requested > available) {
        throw new Error(`No hay suficiente stock en bodega. Disponibles: ${available}.`)
      }

      const { error } = await supabase.from('inventory_movements').insert([
        { product_id: productId, variant_id: variantId, movement_type: 'transfer', quantity: -requested, reference_type: 'warehouse', notes: 'Salida de bodega a inventario de venta' },
        { product_id: productId, variant_id: variantId, movement_type: 'transfer', quantity: requested, reference_type: 'sale_inventory', notes: 'Entrada a inventario de venta' }
      ])
      if (error) throw new Error('No se pudo registrar la transferencia de inventario.')

      await this.refreshBalances()
      return true
    },

    /**
     * Cambia el precio de venta del producto.
     *
     * La versión anterior actualizaba la columna `price` en la base pero
     * escribía `salePrice` en el objeto local: justo después de editar se veía
     * un precio y, al recargar, otro. Ahora hay un solo camino y lo lleva el
     * store de catálogo.
     */
    async updateSalePrice(productId, salePrice) {
      const catalogo = useCatalogStore()
      const producto = catalogo.productById(productId)
      if (!producto) throw new Error('No se encontró el producto.')

      const precioAnterior = producto.price
      const nuevoPrecio = Number(salePrice)
      if (!Number.isFinite(nuevoPrecio) || nuevoPrecio < 0) {
        throw new Error('El precio debe ser un número mayor o igual a cero.')
      }
      if (precioAnterior === nuevoPrecio) return producto

      const actualizado = await catalogo.saveProduct({ ...producto, price: nuevoPrecio })

      await logAudit({
        table: 'products',
        recordId: productId,
        action: 'PRICE_CHANGED',
        oldData: { price: precioAnterior },
        newData: { price: nuevoPrecio },
        note: 'Precio de venta actualizado desde el panel'
      })

      return actualizado
    },

    async registerSale(saleData) {
      // Reducir stock de venta local
      saleData.items.forEach((saleItem) => {
        const invItem = this.saleInventory.find((i) => i.productId === saleItem.productId && i.variantId === (saleItem.variantId || null))
        if (invItem) {
          invItem.quantity = Math.max(0, invItem.quantity - saleItem.quantity)
        }
      })

      const id = this.sales.length ? Math.max(...this.sales.map((s) => s.id)) + 1 : 1
      this.sales.push({ id, ...saleData })

      const { data, error } = await supabase
        .from('sales')
        .insert({
          sale_date: saleData.date,
          customer_name: saleData.customerName || null,
          total: saleData.total,
          payment_method: saleData.paymentMethod
        })
        .select()
        .single()

      if (error) {
        console.error('Error al registrar venta en Supabase:', error)
        return id
      }

      // Insertar items de la venta
      const itemsToInsert = saleData.items.map((item) => ({
        sale_id: data.id,
        product_id: item.productId,
        variant_id: item.variantId || null,
        quantity: item.quantity,
        unit_price: item.price
      }))

      const { error: itemsError } = await supabase
        .from('sale_items')
        .insert(itemsToInsert)

      if (itemsError) console.error('Error al insertar items de venta:', itemsError)

      await supabase.from('inventory_movements').insert(saleData.items.map((item) => ({
        product_id: item.productId,
        variant_id: item.variantId || null,
        movement_type: 'sale',
        quantity: -item.quantity,
        reference_type: 'sale',
        reference_id: data.id,
        unit_cost: item.costPrice || null,
        notes: 'Salida por venta física'
      })))

      await logAudit({
        table: 'sales',
        recordId: data.id,
        action: 'POS_SALE_CREATED',
        newData: { total: saleData.total, items: saleData.items.length },
        note: 'Venta física registrada desde el panel'
      })

      return data.id
    }
  }
})