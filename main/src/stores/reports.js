import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'

// Reportes de venta y utilidad.
//
// Todo el cálculo vive en vistas de Postgres (`report_*`): el costo promedio
// ponderado, el ingreso y el margen se resuelven ahí. Este store solo trae los
// resultados y filtra por período, para que la pantalla no reimplemente
// aritmética de negocio.

const PERIODOS = {
  '7d': { label: 'Últimos 7 días', dias: 7 },
  '30d': { label: 'Últimos 30 días', dias: 30 },
  '90d': { label: 'Últimos 90 días', dias: 90 },
  'todo': { label: 'Todo', dias: null }
}

export const PERIODOS_DISPONIBLES = Object.entries(PERIODOS).map(([value, p]) => ({ value, label: p.label }))

function desde(periodo) {
  const dias = PERIODOS[periodo]?.dias
  if (!dias) return null
  const d = new Date()
  d.setDate(d.getDate() - dias)
  return d.toISOString().slice(0, 10)
}

export const useReportsStore = defineStore('reports', {
  state: () => ({
    lineas: [],
    porProducto: [],
    porTono: [],
    porDia: [],
    porCategoria: [],
    riesgo: [],
    periodo: '30d',
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    // Las líneas se filtran por período aquí; los agregados por producto y
    // tono se recalculan sobre ellas para que respeten el mismo filtro.
    lineasDelPeriodo: (state) => {
      const inicio = desde(state.periodo)
      return inicio ? state.lineas.filter((l) => l.fecha >= inicio) : state.lineas
    },

    totales() {
      const lineas = this.lineasDelPeriodo
      const ingreso = lineas.reduce((s, l) => s + Number(l.ingreso), 0)
      const costo = lineas.reduce((s, l) => s + Number(l.costo), 0)
      const unidades = lineas.reduce((s, l) => s + Number(l.quantity), 0)
      const documentos = new Set(lineas.map((l) => `${l.canal}-${l.documento_id}`)).size
      return {
        ingreso,
        costo,
        utilidad: ingreso - costo,
        margen: ingreso > 0 ? ((ingreso - costo) / ingreso) * 100 : 0,
        unidades,
        documentos,
        ticketPromedio: documentos ? ingreso / documentos : 0,
        // Si falta registrar alguna compra el costo sale 0 y el margen miente.
        costoConfiable: lineas.length > 0 && lineas.every((l) => l.costo_conocido)
      }
    },

    serieDiaria() {
      const inicio = desde(this.periodo)
      const filas = inicio ? this.porDia.filter((d) => d.fecha >= inicio) : this.porDia
      return [...filas].sort((a, b) => a.fecha.localeCompare(b.fecha))
    },

    /** Agrupa las líneas del período por una clave, con ingreso y utilidad. */
    agrupar() {
      return (clave, etiqueta) => {
        const mapa = new Map()
        for (const l of this.lineasDelPeriodo) {
          const k = l[clave] ?? 'sin'
          const actual = mapa.get(k) || {
            key: k, etiqueta: etiqueta(l), unidades: 0, ingreso: 0, costo: 0, costoConfiable: true
          }
          actual.unidades += Number(l.quantity)
          actual.ingreso += Number(l.ingreso)
          actual.costo += Number(l.costo)
          actual.costoConfiable = actual.costoConfiable && l.costo_conocido
          mapa.set(k, actual)
        }
        return [...mapa.values()]
          .map((f) => ({
            ...f,
            utilidad: f.ingreso - f.costo,
            margen: f.ingreso > 0 ? ((f.ingreso - f.costo) / f.ingreso) * 100 : 0
          }))
          .sort((a, b) => b.utilidad - a.utilidad)
      }
    },

    productosRankeados() {
      // El nombre sale del catálogo, no de partir `product_name`: esa columna
      // guarda "Producto — Tono" y el separador cambió entre versiones, así
      // que trocear la cadena mostraba el tono como si fuera el producto.
      return this.agrupar('product_id', (l) =>
        this.porProducto.find((p) => p.product_id === l.product_id)?.producto || 'Producto eliminado'
      )
    },

    tonosRankeados() {
      const filas = this.agrupar('variant_id', (l) =>
        this.porTono.find((t) => t.variant_id === l.variant_id)?.producto || 'Producto eliminado'
      )
      return filas.map((f) => {
        const ref = this.porTono.find((t) => t.variant_id === f.key)
        return { ...f, swatchHex: ref?.swatch_hex || '', tono: ref?.tono || 'Sin tono' }
      })
    },

    alertas: (state) => state.riesgo.filter((r) => r.alerta !== 'ok')
  },

  actions: {
    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null
      try {
        const [lineas, producto, tono, dia, categoria, riesgo] = await Promise.all([
          supabase.from('report_ventas_linea').select('*'),
          supabase.from('report_por_producto').select('*'),
          supabase.from('report_por_tono').select('*'),
          supabase.from('report_por_dia').select('*'),
          supabase.from('report_por_categoria').select('*'),
          supabase.from('report_riesgo_stock').select('*')
        ])
        if (lineas.error) throw lineas.error
        this.lineas = lineas.data || []
        this.porProducto = producto.data || []
        this.porTono = tono.data || []
        this.porDia = dia.data || []
        this.porCategoria = categoria.data || []
        this.riesgo = riesgo.data || []
        this.initialized = true
      } catch (error) {
        this.error = error.message || 'No se pudieron cargar los reportes.'
        throw error
      } finally {
        this.loading = false
      }
    },

    async refresh() {
      this.initialized = false
      return this.init()
    },

    setPeriodo(valor) {
      this.periodo = valor
    }
  }
})
