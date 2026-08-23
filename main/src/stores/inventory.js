import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { products as mockProducts } from '../data/mockData'

export const useInventoryStore = defineStore('inventory', {
  state: () => ({
    // Catálogo maestro: productos base creados en inventario de compras
    catalog: [...mockProducts],
    variants: [],
    suppliers: [],
    movements: [],
    balances: [],

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
    ],

    // Estado de carga
    loading: false,
    initialized: false
  }),

  getters: {
    // Obtener catálogo con stock de venta disponible
    catalogWithStock: (state) => {
      return state.catalog.map((product) => {
        const saleItem = state.saleInventory.find((item) => item.productId === product.id)
        const warehouseItem = state.warehouse.find((item) => item.productId === product.id)
        const productVariants = state.variants.filter((variant) => variant.productId === product.id && variant.isActive !== false)
        const baseBalance = state.balances.find((balance) => balance.productId === product.id && !balance.variantId)
        const balanceRows = state.balances.filter((balance) => balance.productId === product.id)
        const saleStock = baseBalance ? baseBalance.saleStock : saleItem?.quantity || 0
        const warehouseStock = baseBalance ? baseBalance.warehouseStock : warehouseItem?.quantity || 0
        const variantStock = productVariants.reduce((total, variant) => {
          const balance = state.balances.find((row) => row.variantId === variant.id)
          return total + (balance ? balance.saleStock : variant.stock)
        }, 0)
        return {
          ...product,
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
    getVariantAvailableStock(variantId) {
      const variant = this.variants.find((item) => item.id === variantId)
      if (!variant) return 0

      const baseStock = Number(variant.stock) || 0
      const balance = this.balances.find((row) => row.variantId === variantId)
      const reservedStock = balance ? Number(balance.saleStock) || 0 : 0

      return Math.max(baseStock - reservedStock, 0)
    },

    getProductAvailableStock(productId, variantId = null) {
      if (variantId) {
        return this.getVariantAvailableStock(variantId)
      }

      const variants = this.variants.filter((variant) => variant.productId === productId && variant.isActive !== false)
      if (variants.length) {
        return variants.reduce((total, variant) => total + this.getVariantAvailableStock(variant.id), 0)
      }

      const product = this.catalog.find((item) => item.id === productId)
      const fallbackStock = Number(product?.stock ?? 0) || 0
      const balance = this.balances.find((row) => row.productId === productId && !row.variantId)
      const reservedStock = balance ? Number(balance.saleStock) || 0 : 0

      return Math.max(fallbackStock - reservedStock, 0)
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

    async releaseOrderStock(orderId) {
      const { error } = await supabase
        .from('inventory_movements')
        .delete()
        .eq('reference_type', 'order')
        .eq('reference_id', orderId)
        .eq('movement_type', 'online_order')

      if (error) throw new Error('No se pudo liberar la reserva del stock.')
    },

    // ================================================
    // INICIALIZACIÓN / CARGA DESDE SUPABASE
    // ================================================
    async init() {
      if (this.initialized) return
      this.loading = true

      try {
        // Cargar productos
        const { data: products, error: productsError } = await supabase
          .from('products')
          .select('*')
          .order('id', { ascending: true })

        if (!productsError && products?.length) {
          this.catalog = products.map((p) => ({
            id: p.id,
            name: p.name,
            category: p.category,
            description: p.description || '',
            price: Number(p.price) || 0,
            salePrice: p.sale_price ? Number(p.sale_price) : undefined,
            originalPrice: p.original_price ? Number(p.original_price) : undefined,
            image: p.image || '',
            active: p.active !== false,
            saleStock: 0,
            warehouseStock: 0
          }))
        }

        const { data: variants, error: variantsError } = await supabase
          .from('product_variants')
          .select('*')
          .eq('is_active', true)
          .order('id', { ascending: true })

        if (!variantsError && variants?.length) {
          this.variants = variants.map((variant) => ({
            id: variant.id,
            productId: variant.product_id,
            name: variant.name,
            sku: variant.sku || '',
            variantType: variant.variant_type || 'tone',
            optionValue: variant.option_value || variant.name,
            price: Number(variant.price) || 0,
            compareAtPrice: Number(variant.compare_at_price) || 0,
            stock: Number(variant.stock) || 0,
            isActive: variant.is_active !== false
          }))
        }

        const { data: suppliers, error: suppliersError } = await supabase
          .from('suppliers')
          .select('*')
          .eq('active', true)
          .order('name')

        if (!suppliersError && suppliers?.length) {
          this.suppliers = suppliers
        }

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

          const { data: saleBalances, error: saleBalancesError } = await supabase
            .from('inventory_sale_balances')
            .select('*')

          if (!saleBalancesError && saleBalances?.length) {
            this.balances = saleBalances.map((balance) => ({
              productId: balance.product_id,
              variantId: balance.variant_id,
              warehouseStock: 0,
              saleStock: Number(balance.sale_stock) || 0
            }))
          }

          const { data: balances, error: balancesError } = await supabase.from('inventory_balances').select('*')
          if (!balancesError && balances?.length) {
            this.balances = balances.map((balance) => ({
              productId: balance.product_id,
              variantId: balance.variant_id,
              warehouseStock: Number(balance.warehouse_stock) || 0,
              saleStock: Number(balance.sale_stock) || 0
            }))
          }
        }

        if (this.balances.length) {
          this.saleInventory = this.balances
            .filter((balance) => balance.saleStock > 0)
            .map((balance, index) => ({ id: `balance-sale-${index}`, productId: balance.productId, variantId: balance.variantId, quantity: balance.saleStock, costPrice: 0 }))
          this.warehouse = this.balances
            .filter((balance) => balance.warehouseStock > 0)
            .map((balance, index) => ({ id: `balance-warehouse-${index}`, productId: balance.productId, variantId: balance.variantId, quantity: balance.warehouseStock, costPrice: 0 }))
        }

        // Cargar órdenes de compra
        const { data: orders, error: ordersError } = await supabase
          .from('purchase_orders')
          .select('*, purchase_order_items(*)')

        if (!ordersError && orders?.length) {
          this.purchaseOrders = orders.map((order) => ({
            id: order.id,
            orderNumber: order.order_number,
            supplier: order.supplier,
            date: order.date,
            notes: order.notes || '',
            items: (order.purchase_order_items || []).map((item) => ({
              productId: item.product_id,
              quantity: item.quantity,
              costPrice: Number(item.cost_price) || 0,
              toSale: item.to_sale
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
        console.error('Error inicializando inventario desde Supabase:', error)
      } finally {
        this.loading = false
      }
    },

    // ================================================
    // CATÁLOGO
    // ================================================
    async addProduct(product) {
      const id = Math.max(...this.catalog.map((p) => p.id), 0) + 1

      // Insertar en Supabase
      const { data, error } = await supabase
        .from('products')
        .insert({
          name: product.name,
          category: product.category,
          description: product.description || '',
          price: product.price || 0,
          sale_price: product.salePrice || null,
          original_price: product.originalPrice || null,
          image: product.image || '',
          active: product.active !== false
        })
        .select()
        .single()

      if (error) {
        console.error('Error al crear producto en Supabase:', error)
        // Fallback local
        this.catalog.push({ id, ...product })
        return id
      }

      const newProduct = {
        id: data.id,
        name: data.name,
        category: data.category,
        description: data.description || '',
        price: Number(data.price) || 0,
        salePrice: data.sale_price ? Number(data.sale_price) : undefined,
        originalPrice: data.original_price ? Number(data.original_price) : undefined,
        image: data.image || '',
        active: data.active !== false
      }
      this.catalog.push(newProduct)
      return newProduct.id
    },

    async updateProduct(productId, updates) {
      const idx = this.catalog.findIndex((p) => p.id === productId)
      if (idx !== -1) this.catalog[idx] = { ...this.catalog[idx], ...updates }

      // Actualizar en Supabase
      const supabaseUpdates = {}
      if (updates.name !== undefined) supabaseUpdates.name = updates.name
      if (updates.category !== undefined) supabaseUpdates.category = updates.category
      if (updates.description !== undefined) supabaseUpdates.description = updates.description
      if (updates.price !== undefined) supabaseUpdates.price = updates.price
      if (updates.salePrice !== undefined) supabaseUpdates.sale_price = updates.salePrice
      if (updates.originalPrice !== undefined) supabaseUpdates.original_price = updates.originalPrice
      if (updates.image !== undefined) supabaseUpdates.image = updates.image
      if (updates.active !== undefined) supabaseUpdates.active = updates.active

      const { error } = await supabase
        .from('products')
        .update(supabaseUpdates)
        .eq('id', productId)

      if (error) console.error('Error al actualizar producto en Supabase:', error)
    },

    async addVariant(productId, variant) {
      const localVariant = {
        id: `local-${Date.now()}`,
        productId,
        name: variant.name,
        sku: variant.sku || '',
        variantType: variant.variantType || 'tone',
        optionValue: variant.optionValue || variant.name,
        price: Number(variant.price) || 0,
        compareAtPrice: Number(variant.compareAtPrice) || 0,
        stock: Number(variant.stock) || 0,
        isActive: true
      }

      if (import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY) {
        const { data, error } = await supabase.from('product_variants').insert({
          product_id: productId,
          name: localVariant.name,
          sku: localVariant.sku || null,
          variant_type: localVariant.variantType,
          option_value: localVariant.optionValue,
          price: localVariant.price,
          compare_at_price: localVariant.compareAtPrice || null,
          stock: localVariant.stock,
          is_active: true
        }).select().single()

        if (error) throw new Error('No se pudo guardar la variante.')
        localVariant.id = data.id
      }

      this.variants.push(localVariant)
      return localVariant
    },

    async updateVariant(variantId, updates) {
      const index = this.variants.findIndex((variant) => variant.id === variantId)
      if (index === -1) return
      this.variants[index] = { ...this.variants[index], ...updates }

      if (typeof variantId === 'number') {
        const { error } = await supabase.from('product_variants').update({
          name: updates.name,
          sku: updates.sku || null,
          option_value: updates.optionValue,
          price: Number(updates.price) || 0,
          compare_at_price: Number(updates.compareAtPrice) || null,
          stock: Number(updates.stock) || 0
        }).eq('id', variantId)
        if (error) throw new Error('No se pudo actualizar la variante.')
      }
    },

    async deactivateVariant(variantId) {
      const variant = this.variants.find((item) => item.id === variantId)
      if (!variant) return
      variant.isActive = false

      if (typeof variantId === 'number') {
        const { error } = await supabase.from('product_variants').update({ is_active: false }).eq('id', variantId)
        if (error) throw new Error('No se pudo desactivar la variante.')
      }
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
        if (error) throw new Error('No se pudo actualizar el proveedor.')
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
        if (error) throw new Error('No se pudo crear el proveedor.')
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

    async deleteProduct(productId) {
      this.catalog = this.catalog.filter((p) => p.id !== productId)

      // Eliminar de Supabase
      const { error } = await supabase
        .from('products')
        .delete()
        .eq('id', productId)

      if (error) console.error('Error al eliminar producto en Supabase:', error)
    },

    // ================================================
    // COMPRAS
    // ================================================
    async addPurchaseOrder(order) {
      const total = order.items.reduce((sum, item) => sum + item.quantity * item.costPrice, 0)
      const localId = this.purchaseOrders.length ? Math.max(...this.purchaseOrders.map((item) => item.id)) + 1 : 1

      if (!(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY)) {
        const localOrder = { id: localId, orderNumber: order.orderNumber || `PO-${String(localId).padStart(3, '0')}`, ...order, total }
        this.purchaseOrders.unshift(localOrder)
        for (const item of order.items) this.addToWarehouseLocal(item.productId, item.variantId, item.quantity, item.costPrice)
        return localOrder.id
      }

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
      return data.id
    },

    addToWarehouseLocal(productId, variantId, quantity, costPrice) {
      const existing = this.warehouse.find((item) => item.productId === productId && item.variantId === variantId)
      if (existing) {
        existing.quantity += quantity
        existing.costPrice = costPrice
      } else {
        this.warehouse.push({ id: Date.now(), productId, variantId, quantity, costPrice })
      }
    },

    async addPurchaseOrderLegacy(order) {
      const id = this.purchaseOrders.length ? Math.max(...this.purchaseOrders.map((p) => p.id)) + 1 : 1
      const orderNumber = order.orderNumber || `PO-${String(id).padStart(3, '0')}`

      // Calcular total
      const total = order.items.reduce((sum, item) => sum + item.quantity * item.costPrice, 0)

      // Insertar en Supabase
      const { data, error } = await supabase
        .from('purchase_orders')
        .insert({
          order_number: orderNumber,
          supplier: order.supplier,
          date: order.date,
          notes: order.notes || '',
          total
        })
        .select()
        .single()

      if (error) {
        console.error('Error al crear orden de compra en Supabase:', error)
        this.purchaseOrders.push({ id, orderNumber, ...order })
        return id
      }

      // Insertar items de la compra
      const itemsToInsert = order.items.map((item) => ({
        purchase_order_id: data.id,
        product_id: item.productId,
        quantity: item.quantity,
        cost_price: item.costPrice,
        to_sale: item.toSale || false
      }))

      const { error: itemsError } = await supabase
        .from('purchase_order_items')
        .insert(itemsToInsert)

      if (itemsError) console.error('Error al insertar items de compra:', itemsError)

      // Actualizar inventario en Supabase
      for (const item of order.items) {
        if (item.toSale) {
          // Producto va directo a venta
          const { data: existing, error: checkError } = await supabase
            .from('sale_inventory')
            .select('*')
            .eq('product_id', item.productId)
            .single()

          if (checkError && checkError.code !== 'PGRST116') {
            console.error('Error al verificar inventario de venta:', checkError)
          } else if (existing) {
            const { error: updateError } = await supabase
              .from('sale_inventory')
              .update({ quantity: existing.quantity + item.quantity, cost_price: item.costPrice })
              .eq('id', existing.id)
            if (updateError) console.error('Error al actualizar inventario de venta:', updateError)
          } else {
            const { error: insertError } = await supabase
              .from('sale_inventory')
              .insert({ product_id: item.productId, quantity: item.quantity, cost_price: item.costPrice })
            if (insertError) console.error('Error al insertar inventario de venta:', insertError)
          }
        } else {
          // Producto va a bodega
          const { data: existing, error: checkError } = await supabase
            .from('purchase_inventory')
            .select('*')
            .eq('product_id', item.productId)
            .single()

          if (checkError && checkError.code !== 'PGRST116') {
            console.error('Error al verificar bodega:', checkError)
          } else if (existing) {
            const { error: updateError } = await supabase
              .from('purchase_inventory')
              .update({ quantity: existing.quantity + item.quantity, cost_price: item.costPrice })
              .eq('id', existing.id)
            if (updateError) console.error('Error al actualizar bodega:', updateError)
          } else {
            const { error: insertError } = await supabase
              .from('purchase_inventory')
              .insert({ product_id: item.productId, quantity: item.quantity, cost_price: item.costPrice })
            if (insertError) console.error('Error al insertar bodega:', insertError)
          }
        }
      }

      // Actualizar estado local
      this.purchaseOrders.push({ id: data.id, orderNumber: data.order_number, ...order })
      for (const item of order.items) {
        if (item.toSale) {
          this.addToSaleInventoryLocal(item.productId, item.quantity, item.costPrice)
        } else {
          const wItem = this.warehouse.find((w) => w.productId === item.productId)
          if (wItem) {
            wItem.quantity += item.quantity
            wItem.costPrice = item.costPrice
          } else {
            const wid = this.warehouse.length ? Math.max(...this.warehouse.map((w) => w.id)) + 1 : 1
            this.warehouse.push({ id: wid, productId: item.productId, quantity: item.quantity, costPrice: item.costPrice })
          }
        }
      }

      return data.id
    },

    // ================================================
    // INVENTARIO DE VENTA
    // ================================================
    addToSaleInventoryLocal(productId, quantity, costPrice, variantId = null) {
      const existing = this.saleInventory.find((item) => item.productId === productId && item.variantId === variantId)
      if (existing) {
        existing.quantity += quantity
        if (costPrice) existing.costPrice = costPrice
      } else {
        const id = this.saleInventory.length ? Math.max(...this.saleInventory.map((p) => p.id)) + 1 : 1
        this.saleInventory.push({ id, productId, variantId, quantity, costPrice })
      }
    },

    async addToSaleInventory(productId, quantity, costPrice) {
      // Actualizar en Supabase
      const { data: existing, error: checkError } = await supabase
        .from('sale_inventory')
        .select('*')
        .eq('product_id', productId)
        .single()

      if (checkError && checkError.code !== 'PGRST116') {
        console.error('Error al verificar inventario de venta:', checkError)
      } else if (existing) {
        const { error: updateError } = await supabase
          .from('sale_inventory')
          .update({ quantity: existing.quantity + quantity, cost_price: costPrice })
          .eq('id', existing.id)
        if (updateError) console.error('Error al actualizar inventario de venta:', updateError)
      } else {
        const { error: insertError } = await supabase
          .from('sale_inventory')
          .insert({ product_id: productId, quantity, cost_price: costPrice })
        if (insertError) console.error('Error al insertar inventario de venta:', insertError)
      }

      // Actualizar estado local
      this.addToSaleInventoryLocal(productId, quantity, costPrice)
    },

    async moveFromWarehouseToSale(productId, quantity, variantId = null) {
      const wItem = this.warehouse.find((item) => item.productId === productId && (variantId === null || item.variantId === variantId))
      if (!wItem || wItem.quantity < quantity) return false

      if (import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY) {
        const { error } = await supabase.from('inventory_movements').insert([
          { product_id: productId, variant_id: variantId, movement_type: 'transfer', quantity: -quantity, reference_type: 'warehouse', notes: 'Salida de bodega a inventario de venta' },
          { product_id: productId, variant_id: variantId, movement_type: 'transfer', quantity, reference_type: 'sale_inventory', notes: 'Entrada a inventario de venta' }
        ])
        if (error) throw new Error('No se pudo registrar la transferencia de inventario.')
      }

      this.addToSaleInventoryLocal(productId, quantity, wItem.costPrice, variantId)

      // Limpiar bodega si queda en 0
      if (wItem.quantity - quantity <= 0) {
        this.warehouse = this.warehouse.filter((item) => item !== wItem)
      } else {
        wItem.quantity -= quantity
      }

      return true
    },

    async updateSalePrice(productId, salePrice) {
      const item = this.saleInventory.find((i) => i.productId === productId)
      const product = this.catalog.find((p) => p.id === productId)
      const previousPrice = product?.salePrice || product?.price || 0
      if (item && product) {
        product.salePrice = salePrice
      }

      // Actualizar en Supabase
      const { error } = await supabase
        .from('products')
        .update({ price: salePrice })
        .eq('id', productId)

      if (error) console.error('Error al actualizar precio en Supabase:', error)

      if (!error && previousPrice !== salePrice) {
        await supabase.from('audit_logs').insert({
          entity_type: 'product',
          entity_id: productId,
          action: 'price_changed',
          details: { from: previousPrice, to: salePrice }
        })
      }
    },

    async toggleProductActive(productId, active) {
      const product = this.catalog.find((p) => p.id === productId)
      if (product) product.active = active

      // Actualizar en Supabase
      const { error } = await supabase
        .from('products')
        .update({ active })
        .eq('id', productId)

      if (error) console.error('Error al actualizar estado en Supabase:', error)
    },

    // ================================================
    // VENTAS (POS FÍSICO)
    // ================================================
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

      if (!import.meta.env.VITE_SUPABASE_URL || !import.meta.env.VITE_SUPABASE_ANON_KEY) {
        return id
      }

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

      await supabase.from('audit_logs').insert({
        entity_type: 'sale',
        entity_id: data.id,
        action: 'created',
        details: { total: saleData.total, items: saleData.items.length }
      })

      return data.id
    }
  }
})