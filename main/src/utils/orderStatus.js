// Fuente única del mapeo de estados de pedido.
//
// La base de datos trabaja en inglés y la interfaz en español. Antes este
// diccionario estaba escrito dos veces dentro de orders.js, con listas
// distintas en cada copia, lo que garantizaba que tarde o temprano
// divergieran.

export const ORDER_STATUSES = ['pending', 'paid', 'shipped', 'delivered', 'returned']

const DB_TO_UI = {
  pending: 'pendiente',
  paid: 'pagado',
  shipped: 'enviado',
  delivered: 'entregado',
  returned: 'devuelto'
}

const UI_TO_DB = Object.fromEntries(Object.entries(DB_TO_UI).map(([db, ui]) => [ui, db]))

/** Normaliza cualquier variante (español o inglés) al valor que guarda la base. */
export function toDbStatus(status) {
  const normalized = String(status || '').trim().toLowerCase()
  return UI_TO_DB[normalized] || (DB_TO_UI[normalized] ? normalized : normalized)
}

/** Normaliza cualquier variante al texto que muestra la interfaz. */
export function toUiStatus(status) {
  const normalized = String(status || '').trim().toLowerCase()
  return DB_TO_UI[normalized] || (UI_TO_DB[normalized] ? normalized : normalized)
}

/** True si el estado corresponde a una devolución. */
export function isReturned(status) {
  return toDbStatus(status) === 'returned'
}

/** True si el pedido ya termino su ciclo: entregado, devuelto o cancelado. */
export function isClosed(status) {
  return ['delivered', 'returned', 'cancelled'].includes(toDbStatus(status))
}

/**
 * True si el pedido sigue requiriendo atencion.
 *
 * Un pedido entregado ya no es "activo": antes se quedaba en enviado para
 * siempre y la bandeja de pendientes se llenaba de cosas terminadas.
 */
export function isActive(status) {
  return !isClosed(status)
}

/** True si el pedido se completo con exito. */
export function isDelivered(status) {
  return toDbStatus(status) === 'delivered'
}
