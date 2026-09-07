<script setup>
import { computed, ref } from 'vue'
import { formatCurrency } from '../../../utils/formatCurrency'

// Serie temporal de ingreso y utilidad. Dos series en UN solo eje: ambas son
// pesos, así que comparten escala. Nunca dos ejes Y.

const props = defineProps({
  datos: { type: Array, required: true },
  alto: { type: Number, default: 240 }
})

const ANCHO = 720
const M = { top: 24, right: 110, bottom: 34, left: 8 }
const activo = ref(null)

const puntos = computed(() => {
  if (!props.datos.length) return null
  const maxY = Math.max(...props.datos.map((d) => Math.max(Number(d.ingreso), Number(d.utilidad))), 1)
  const paso = Math.pow(10, Math.floor(Math.log10(maxY))) / 2
  const techo = Math.max(Math.ceil(maxY / paso) * paso, paso)
  const w = ANCHO - M.left - M.right
  const h = props.alto - M.top - M.bottom
  const n = props.datos.length
  const x = (i) => M.left + (n === 1 ? w / 2 : (i / (n - 1)) * w)
  const y = (v) => M.top + h - (Number(v) / techo) * h
  return {
    ticks: [0, techo / 2, techo].map((v) => ({ v, y: y(v) })),
    ingreso: props.datos.map((d, i) => ({ x: x(i), y: y(d.ingreso) })),
    utilidad: props.datos.map((d, i) => ({ x: x(i), y: y(d.utilidad) }))
  }
})

function ruta(serie) {
  return serie.map((p, i) => `${i ? 'L' : 'M'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ')
}

// Un solo dia dibuja un `moveto` y nada mas: el trazo queda vacio y el panel
// parecia roto justo cuando hay una unica venta, que es el caso normal al
// arrancar. Con pocos dias se marcan los puntos, y con uno solo ademas se
// etiqueta el valor, porque no hay linea que leer ni hover en movil.
const marcadores = computed(() => props.datos.length > 0 && props.datos.length <= 14)
const puntoUnico = computed(() => props.datos.length === 1)

function alMover(evento) {
  if (!puntos.value) return
  const caja = evento.currentTarget.getBoundingClientRect()
  const px = ((evento.clientX - caja.left) / caja.width) * ANCHO
  let cerca = 0, mejor = Infinity
  puntos.value.ingreso.forEach((p, i) => {
    const d = Math.abs(p.x - px)
    if (d < mejor) { mejor = d; cerca = i }
  })
  activo.value = cerca
}

function fechaCorta(f) {
  const [, m, d] = String(f).split('-')
  return `${d}/${m}`
}
</script>

<template>
  <figure class="m-0">
    <figcaption class="text-sm font-bold text-[var(--viz-ink)]">Ingreso y utilidad por día</figcaption>
    <p class="mt-1 text-xs text-[var(--viz-muted)]">
      Cuenta pedidos pagados, enviados o entregados, más las ventas del punto físico.
    </p>

    <div class="mt-3 flex flex-wrap gap-4 text-xs">
      <span class="inline-flex items-center gap-1.5 text-[var(--viz-ink-2)]">
        <span class="inline-block size-2.5 rounded-full" style="background: var(--viz-s1)"></span> Ingreso
      </span>
      <span class="inline-flex items-center gap-1.5 text-[var(--viz-ink-2)]">
        <span class="inline-block size-2.5 rounded-full" style="background: var(--viz-s2)"></span> Utilidad
      </span>
    </div>

    <svg
      v-if="puntos" :viewBox="`0 0 ${ANCHO} ${alto}`" class="mt-2 w-full" role="img"
      aria-label="Evolución diaria de ingreso y utilidad"
      @mousemove="alMover" @mouseleave="activo = null"
    >
      <line v-for="t in puntos.ticks" :key="t.v" :x1="M.left" :x2="ANCHO - M.right" :y1="t.y" :y2="t.y"
            stroke="var(--viz-grid)" stroke-width="1" />
      <text v-for="t in puntos.ticks" :key="`t${t.v}`" :x="ANCHO - M.right + 10" :y="t.y + 4"
            font-size="11" fill="var(--viz-muted)">{{ formatCurrency(t.v) }}</text>

      <line v-if="activo !== null" :x1="puntos.ingreso[activo].x" :x2="puntos.ingreso[activo].x"
            :y1="M.top" :y2="alto - M.bottom" stroke="var(--viz-grid)" stroke-width="1" />

      <path :d="ruta(puntos.utilidad)" fill="none" stroke="var(--viz-s2)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
      <path :d="ruta(puntos.ingreso)" fill="none" stroke="var(--viz-s1)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />

      <template v-if="marcadores">
        <circle v-for="(p, i) in puntos.utilidad" :key="`mu${i}`" :cx="p.x" :cy="p.y" r="4"
                fill="var(--viz-s2)" stroke="var(--viz-surface)" stroke-width="2" />
        <circle v-for="(p, i) in puntos.ingreso" :key="`mi${i}`" :cx="p.x" :cy="p.y" r="4"
                fill="var(--viz-s1)" stroke="var(--viz-surface)" stroke-width="2" />
      </template>

      <template v-if="puntoUnico">
        <text :x="puntos.ingreso[0].x + 10" :y="puntos.ingreso[0].y - 8"
              font-size="11" font-weight="600" fill="var(--viz-ink)">
          Ingreso {{ formatCurrency(datos[0].ingreso) }}
        </text>
        <text :x="puntos.utilidad[0].x + 10" :y="puntos.utilidad[0].y + 16"
              font-size="11" font-weight="600" fill="var(--viz-ink)">
          Utilidad {{ formatCurrency(datos[0].utilidad) }}
        </text>
      </template>

      <template v-if="activo !== null">
        <circle :cx="puntos.utilidad[activo].x" :cy="puntos.utilidad[activo].y" r="5"
                fill="var(--viz-s2)" stroke="var(--viz-surface)" stroke-width="2" />
        <circle :cx="puntos.ingreso[activo].x" :cy="puntos.ingreso[activo].y" r="5"
                fill="var(--viz-s1)" stroke="var(--viz-surface)" stroke-width="2" />
      </template>

      <g font-size="11" fill="var(--viz-muted)">
        <text :x="puntos.ingreso[0].x" :y="alto - 10" :text-anchor="puntoUnico ? 'middle' : 'start'">{{ fechaCorta(datos[0].fecha) }}</text>
        <text v-if="datos.length > 1" :x="puntos.ingreso.at(-1).x" :y="alto - 10" text-anchor="end">
          {{ fechaCorta(datos.at(-1).fecha) }}
        </text>
      </g>
    </svg>

    <p v-else class="mt-3 rounded-xl border border-dashed border-pink-200 p-8 text-center text-sm text-neutral-500">
      Todavía no hay ventas en este período.
    </p>

    <div v-if="activo !== null && puntos" class="mt-2 rounded-xl bg-pink-50 px-3 py-2 text-xs">
      <strong class="text-[var(--viz-ink)]">{{ datos[activo].fecha }}</strong>
      <span class="ml-3 text-[var(--viz-ink-2)]">Ingreso {{ formatCurrency(datos[activo].ingreso) }}</span>
      <span class="ml-3 text-[var(--viz-ink-2)]">Utilidad {{ formatCurrency(datos[activo].utilidad) }}</span>
    </div>
  </figure>
</template>
