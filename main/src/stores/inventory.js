import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { useCatalogStore } from './catalog'
import { useSuppliersStore } from './suppliers'
import { usePurchasesStore } from './purchases'
import { usePosStore } from './pos'

// EXISTENCIAS. Nada más.
//
// Este store responde a una sola pregunta: **cuántas unidades hay y dónde**.
// La respuesta se deriva siempre de `inventory_movements`; no hay ninguna
// columna `stock` en la base y no debe haber ninguna cuenta local que compita
// con la vista `inventory_balances`.
//
// Lo que ANTES estaba aquí y ya no:
//   · catálogo y tonos        → `catalog.js`
//   · proveedores             → `suppliers.js`
//   · órdenes de compra       → `purchases.js`
//   · venta de mostrador      → `pos.js`
//
// También desapareció la capa de "delegaciones" que reexportaba media API de
// `catalog.js` para no romper pantallas durante aquella migración. Sobrevivió
// meses, que es lo que suelen hacer las capas de compatibilidad: las pantallas
// llaman ahora a `useCatalogStore()` directamente.
//
// Hay dos arranques a propósito, `init()` y `initPanel()`. La tienda pública
// solo necesita catálogo y saldos; el panel necesita además el historial de
// movimientos, los proveedores, las compras y las ventas de mostrador. Antes
// había un solo `init()` que lo pedía todo, así que una clienta mirando un
// labial disparaba cuatro consultas a tablas que RLS no le deja leer — y que
// devuelven cero filas sin error, así que nadie lo notaba nunca.

export const useInventoryStore = defineStore('inventory', {
  state: () => ({
    // Historial completo. Es la fuente de verdad del stock.
    movements: [],

    // Saldos ya agregados por la vista `inventory_balances`.
    balances: [],

    // Proyecciones de `balances` para las pantallas que piden una lista.
    saleInventory: [],
    warehouse: [],

    // ¿`balances` incluye la bodega? La tienda pública solo puede ver lo que
    // está a la venta, así que ahí es `false` y `warehouseStock` vale 0 para
    // todo. No es un saldo de cero: es un dato que no se pidió.
    balancesCompletos: false,

    loading: false,
    error: null,
    initialized: false,
    panelInitialized: false
  }),

  getters: {
    // El punto donde se cruzan catálogo y existencias: la ficha comercial más
    // el saldo derivado de movimientos.
    catalogWithStock: (state) => {
      const catalogo = useCatalogStore()
      return catalogo.products.map((product) => {
        const productVariants = catalogo.shades.filter(
          (variant) => variant.productId === product.id && variant.isActive !== false
        )
        const baseBalance = state.balances.find((b) => b.productId === product.id && !b.variantId)
        const balanceRows = state.balances.filter((b) => b.productId === product.id)

        const saldoDeTono = (variantId, campo) =>
          state.balances.find((row) => row.variantId === variantId)?.[campo] || 0

        const saleStock = productVariants.length
          ? productVariants.reduce((t, v) => t + saldoDeTono(v.id, 'saleStock'), 0)
          : baseBalance?.saleStock || 0

        const warehouseStock = productVariants.length
          ? productVariants.reduce((t, v) => t + saldoDeTono(v.id, 'warehouseStock'), 0)
          : baseBalance?.warehouseStock || 0

        // La foto sale solo de `product_images`. La columna `products.image`
        // se soltó en la migración 018: lo único que guardaba era una URL
        // `blob:` muerta, que solo existía en la pestaña que la creó.
        const imagenPrincipal = catalogo.primaryImageOf(product.id)
        const vitrina = catalogo.storefrontProducts.find((f) => f.product_id === product.id)

        return {
          ...product,
          image: imagenPrincipal?.url || '',
          basePrice: vitrina ? Number(vitrina.base_price) : (product.salePrice ?? product.price),
          promoPrice: vitrina ? Number(vitrina.effective_price) : null,
          enPromocion: vitrina ? Number(vitrina.effective_price) < Number(vitrina.base_price) : false,
          promoLabel: vitrina?.promo_label || '',
          // Etiquetas de escaparate (VIRAL, NUEVO…). Van aquí y no en el
          // mapeo del catálogo porque es este objeto enriquecido el que
          // pintan la tarjeta y la ficha.
          badges: catalogo.badgesOf(product.id),
          variants: productVariants,
          stock: saleStock,
          saleStock,
          warehouseStock,
          hasMovementBalance: Boolean(baseBalance || balanceRows.length)
        }
      })
    },

    // Tonos listos para la vitrina: precio heredado ya resuelto, existencias
    // reales del tono e imagen propia si la tiene.
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
    }
  },

  actions: {
    // ================================================
    // ARRANQUE
    // ================================================

    // Lo mínimo para que la tienda funcione: qué se vende y cuánto queda.
    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null
      try {
        await useCatalogStore().init()
        await this.refreshSaleBalances()
        this.initialized = true
      } catch (fallo) {
        this.error = fallo.message || 'No se pudo cargar el inventario.'
        throw fallo
      } finally {
        this.loading = false
      }
    },

    // Lo que además necesita el panel. Los cuatro bloques son independientes
    // entre sí, así que van en paralelo; si uno falla, `Promise.all` propaga el
    // error y la pantalla lo muestra en vez de quedarse a medias en silencio.
    async initPanel() {
      await this.init()
      if (this.panelInitialized) return
      this.loading = true
      try {
        // El panel SÍ puede ver la bodega, así que cambia a los saldos
        // completos. La tienda pública se queda con los de venta.
        await this.refreshBalances()
        await Promise.all([
          this.loadMovements(),
          useSuppliersStore().init(),
          usePurchasesStore().init(),
          usePosStore().init()
        ])
        this.panelInitialized = true
      } catch (fallo) {
        this.error = fallo.message || 'No se pudo cargar el inventario del panel.'
        throw fallo
      } finally {
        this.loading = false
      }
    },

    // ================================================
    // MOVIMIENTOS Y SALDOS
    // ================================================

    async loadMovements() {
      const { data, error } = await supabase
        .from('inventory_movements')
        .select('*')
        .order('created_at', { ascending: false })

      if (error) throw new Error('No se pudo cargar el historial de movimientos.')

      this.movements = (data || []).map((movimiento) => ({
        id: movimiento.id,
        productId: movimiento.product_id,
        variantId: movimiento.variant_id,
        type: movimiento.movement_type,
        quantity: Number(movimiento.quantity) || 0,
        unitCost: Number(movimiento.unit_cost) || 0,
        referenceType: movimiento.reference_type || '',
        referenceId: movimiento.reference_id,
        notes: movimiento.notes || '',
        createdAt: movimiento.created_at
      }))

      // Los saldos se releen SIEMPRE, no solo cuando ya hay movimientos: antes
      // esta llamada vivía dentro de un `if (movements?.length)`, así que en
      // una base recién migrada `balances` quedaba vacío.
      await this.refreshBalances()
      return this.movements
    },

    /**
     * Saldos para la TIENDA PÚBLICA.
     *
     * Lee `inventory_sale_balances`, que es una tabla con lectura pública, y
     * NO la vista `inventory_balances`.
     *
     * Por qué importa: `inventory_balances` se declara con
     * `security_invoker = true`, así que al consultarla se leen por debajo los
     * `inventory_movements` **con los permisos de quien pregunta**. La única
     * política de esa tabla es `TO authenticated USING (is_admin())`. Una
     * clienta anónima no cumple ninguna de las dos cosas, así que recibe
     * **cero filas y ningún error** — la trampa de RLS que este proyecto ya
     * tiene documentada.
     *
     * Consecuencia real, y el fallo que esto corrige: la tienda calculaba
     * `saleStock = 0` para TODO el catálogo y pintaba «Agotado» en cada
     * tarjeta, aunque la mercancía estuviera puesta a la venta. Sin un solo
     * error en consola, porque no había ninguno.
     *
     * `inventory_sale_balances` la mantiene un trigger a partir de los mismos
     * movimientos, así que no es una segunda fuente de verdad: es la misma
     * cuenta, publicada. Lo que no trae —y no debe— es la bodega: cuánta
     * mercancía guardas no es asunto de la clienta.
     */
    async refreshSaleBalances() {
      const { data, error } = await supabase.from('inventory_sale_balances').select('*')
      if (error) {
        console.error('No se pudieron cargar las existencias a la venta:', error.message)
        return false
      }

      this.balances = (data || []).map((balance) => ({
        productId: balance.product_id,
        variantId: balance.variant_id,
        warehouseStock: 0,
        saleStock: Number(balance.sale_stock) || 0
      }))
      this.balancesCompletos = false
      this.syncDerivedInventory()
      return true
    },

    /**
     * Saldos completos, con bodega. Solo funciona para un admin: la vista
     * `inventory_balances` está detrás de RLS (ver `refreshSaleBalances`).
     */
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
      this.balancesCompletos = true
      this.syncDerivedInventory()
      return true
    },

    // Proyecta `balances` sobre las listas que consumen los componentes.
    syncDerivedInventory() {
      const proyectar = (campo, prefijo) =>
        this.balances
          .filter((balance) => balance[campo] > 0)
          .map((balance, index) => ({
            id: `balance-${prefijo}-${index}`,
            productId: balance.productId,
            variantId: balance.variantId,
            quantity: balance[campo],
            costPrice: 0
          }))

      this.saleInventory = proyectar('saleStock', 'sale')
      this.warehouse = proyectar('warehouseStock', 'warehouse')
    },

    // ================================================
    // DISPONIBILIDAD
    // ================================================

    // `balances` viene de la vista inventory_balances: `saleStock` YA ES el
    // stock disponible para vender (entradas a venta menos salidas), no una
    // reserva. La versión anterior hacía `variant.stock - balance.saleStock`,
    // restando el disponible de una columna legacy que casi siempre valía 0.
    // El resultado era 0 para todo, así que validateOrderItems rechazaba
    // cualquier pedido antes de llegar a Supabase.
    getVariantAvailableStock(variantId) {
      const balance = this.balances.find((row) => row.variantId === variantId)
      return Math.max(Number(balance?.saleStock) || 0, 0)
    },

    getProductAvailableStock(productId, variantId = null) {
      if (variantId) return this.getVariantAvailableStock(variantId)

      // Si el producto tiene tonos, el disponible es la suma de ellos.
      const tonos = useCatalogStore().shades.filter(
        (tono) => tono.productId === productId && tono.isActive !== false
      )
      if (tonos.length) {
        return tonos.reduce((total, tono) => total + this.getVariantAvailableStock(tono.id), 0)
      }

      const balance = this.balances.find((row) => row.productId === productId && !row.variantId)
      return Math.max(Number(balance?.saleStock) || 0, 0)
    },

    // Costo promedio ponderado de las entradas por compra. La tabla de saldos
    // no guarda costo (el stock se deriva de movimientos), así que sin esto las
    // columnas de Costo y Ganancia mostrarían cero siempre.
    getAverageCost(productId, variantId = null) {
      const compras = this.movements.filter(
        (movimiento) =>
          movimiento.type === 'purchase' &&
          movimiento.productId === productId &&
          (movimiento.variantId ?? null) === (variantId ?? null) &&
          movimiento.quantity > 0
      )
      if (!compras.length) return 0

      const unidades = compras.reduce((total, m) => total + m.quantity, 0)
      if (!unidades) return 0

      const costo = compras.reduce((total, m) => total + m.quantity * (m.unitCost || 0), 0)
      return costo / unidades
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

    // ================================================
    // MOVER MERCANCÍA
    // ================================================

    // Transfiere unidades de bodega al inventario de venta.
    //
    // La validación se hace contra `balances`, que viene de la base, no contra
    // la copia local. Y respeta el tono: antes el componente llamaba sin
    // variantId, así que una compra registrada contra un tono se transfería
    // como si fuera del producto base y los saldos nunca cuadraban.
    async moveFromWarehouseToSale(productId, quantity, variantId = null, nota = '') {
      const solicitadas = Number(quantity)
      if (!Number.isFinite(solicitadas) || solicitadas <= 0) {
        throw new Error('La cantidad a transferir debe ser mayor a cero.')
      }

      const balance = this.balances.find(
        (row) => row.productId === productId && (row.variantId ?? null) === (variantId ?? null)
      )
      const disponibles = Number(balance?.warehouseStock) || 0

      if (solicitadas > disponibles) {
        throw new Error(`No hay suficiente stock en bodega. Disponibles: ${disponibles}.`)
      }

      const nota_ = (texto) => [texto, nota].filter(Boolean).join(' · ')
      const { error } = await supabase.from('inventory_movements').insert([
        { product_id: productId, variant_id: variantId, movement_type: 'transfer', quantity: -solicitadas, reference_type: 'warehouse', notes: nota_('Salida de bodega a inventario de venta') },
        { product_id: productId, variant_id: variantId, movement_type: 'transfer', quantity: solicitadas, reference_type: 'sale_inventory', notes: nota_('Entrada a inventario de venta') }
      ])
      if (error) throw new Error('No se pudo registrar la transferencia de inventario.')

      await this.refreshBalances()
      return true
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
      await this.loadMovements()
    }
  }
})
