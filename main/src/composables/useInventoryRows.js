import { computed } from 'vue'
import { useInventoryStore } from '../stores/inventory'
import { useCatalogStore } from '../stores/catalog'

/**
 * Las filas de existencias, con el nombre del producto y del tono resueltos.
 *
 * Vive aquí porque la usan DOS pantallas —Bodega y Listo para vender— y antes
 * era una función dentro de un componente. En cuanto la bodega se separó, esa
 * función habría tenido que copiarse, y dos copias acaban divergiendo: pasó ya
 * con el mapeo de estados de pedido y con el costo de envío.
 *
 * Las filas salen SIEMPRE de `balances`, que es lo que dice la base. Leer una
 * copia local fue lo que dejó las variantes invisibles: solo se conocía el
 * producto, así que las existencias por tono no se podían transferir nunca.
 */
export function useInventoryRows() {
  const inventory = useInventoryStore()
  const catalogo = useCatalogStore()

  function construir(campo) {
    return inventory.balances
      .filter((balance) => Number(balance[campo]) > 0)
      .map((balance) => {
        const producto = catalogo.productById(balance.productId)
        const tono = balance.variantId
          ? catalogo.shades.find((s) => s.id === balance.variantId)
          : null

        // EXISTENCIAS HUÉRFANAS. Unidades registradas contra el producto base
        // cuando ese producto tiene tonos.
        //
        // La clienta nunca las ve: con tonos, la tarjeta y la ficha suman el
        // stock TONO A TONO, porque lo que compra es un color concreto. Unas
        // unidades sin tono no pertenecen a ninguno, así que no aparecen por
        // ningún lado — y el producto sale «Agotado» teniéndolas en la
        // vitrina. Se marcan para poder avisar en vez de dejar el hueco.
        const tieneTonos = catalogo.shadesOf(balance.productId).length > 0
        const huerfano = tieneTonos && !balance.variantId

        return {
          key: `${balance.productId}-${balance.variantId ?? 'base'}`,
          productId: balance.productId,
          variantId: balance.variantId ?? null,
          name: producto?.name || 'Producto eliminado',
          variantName: tono?.name || '',
          huerfano,
          category: producto?.category || '',
          active: producto?.active !== false,
          quantity: Number(balance[campo]) || 0,
          saleStock: Number(balance.saleStock) || 0,
          warehouseStock: Number(balance.warehouseStock) || 0,
          cost: inventory.getAverageCost(balance.productId, balance.variantId ?? null),
          price: tono?.price || producto?.salePrice || producto?.price || 0
        }
      })
      .sort((a, b) => a.name.localeCompare(b.name))
  }

  /** Un producto con tonos se nombra "Producto — Tono"; sin tonos, solo el nombre. */
  function etiquetaDe(fila) {
    return fila.variantName ? `${fila.name} — ${fila.variantName}` : fila.name
  }

  return {
    filasEnVenta: computed(() => construir('saleStock')),
    filasEnBodega: computed(() => construir('warehouseStock')),
    etiquetaDe
  }
}
