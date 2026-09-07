<script setup>
import { computed, ref } from 'vue'
import { formatCurrency } from '../../../utils/formatCurrency'

// Ranking horizontal por utilidad. Una sola serie: sin leyenda, con etiqueta
// directa en la punta de cada barra.
//
// Cuando la fila trae `swatchHex` la barra se pinta con el color real del tono
// — en maquillaje el color ES el dato. Como un tono claro sería invisible sobre
// fondo blanco, cada barra lleva un filete de un pixel y su nombre al lado, así
// que la identidad nunca depende solo del color.

const props = defineProps({
  filas: { type: Array, required: true },
  titulo: { type: String, required: true },
  descripcion: { type: String, default: '' },
  limite: { type: Number, default: 8 },
  usarSwatch: { type: Boolean, default: false }
})

const activo = ref(null)
const visibles = computed(() => props.filas.slice(0, props.limite))
const maximo = computed(() => Math.max(...visibles.value.map((f) => Math.abs(f.utilidad)), 1))

function ancho(fila) {
  return `${Math.max((Math.abs(fila.utilidad) / maximo.value) * 100, 1.5)}%`
}
</script>

<template>
  <figure class="m-0">
    <figcaption class="text-sm font-bold text-[var(--viz-ink)]">{{ titulo }}</figcaption>
    <p v-if="descripcion" class="mt-1 text-xs text-[var(--viz-muted)]">{{ descripcion }}</p>

    <div v-if="visibles.length" class="mt-4 space-y-3">
      <div
        v-for="fila in visibles" :key="fila.key"
        class="group"
        @mouseenter="activo = fila.key" @mouseleave="activo = null"
      >
        <div class="flex items-baseline justify-between gap-3 text-xs">
          <span class="flex min-w-0 items-center gap-2">
            <span
              v-if="usarSwatch"
              class="inline-block size-3 shrink-0 rounded-full"
              :style="{ background: fila.swatchHex || '#e5e5e5', border: '1px solid var(--viz-baseline)' }"
            />
            <span class="truncate font-semibold text-[var(--viz-ink)]">{{ fila.etiqueta }}</span>
            <span v-if="fila.tono && fila.tono !== 'Sin tono'" class="shrink-0 text-[var(--viz-muted)]">{{ fila.tono }}</span>
          </span>
          <span class="shrink-0 font-bold text-[var(--viz-ink-2)]">{{ formatCurrency(fila.utilidad) }}</span>
        </div>

        <div class="mt-1 h-3 w-full">
          <div
            class="h-3 rounded-r"
            :style="{
              width: ancho(fila),
              background: usarSwatch ? (fila.swatchHex || 'var(--viz-s2)') : 'var(--viz-s2)',
              border: usarSwatch ? '1px solid var(--viz-baseline)' : 'none',
              opacity: activo && activo !== fila.key ? 0.55 : 1
            }"
          />
        </div>

        <p class="mt-1 text-[11px] text-[var(--viz-muted)]">
          {{ fila.unidades }} {{ fila.unidades === 1 ? 'unidad' : 'unidades' }} · {{ formatCurrency(fila.ingreso) }} facturado ·
          margen {{ fila.margen.toFixed(1) }}%
          <span v-if="!fila.costoConfiable" class="font-semibold text-amber-600">
            · margen no confiable, falta registrar la compra
          </span>
        </p>
      </div>
    </div>

    <p v-else class="mt-3 rounded-xl border border-dashed border-pink-200 p-8 text-center text-sm text-neutral-500">
      Sin datos en este período.
    </p>
  </figure>
</template>
