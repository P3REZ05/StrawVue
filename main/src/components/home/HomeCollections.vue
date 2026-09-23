<script setup>
import { computed, onMounted } from 'vue'
import { useCollectionsStore } from '../../stores/collections'
import { useInventoryStore } from '../../stores/inventory'
import { useSettingsStore } from '../../stores/settings'
import CollectionRow from './CollectionRow.vue'

/**
 * COLECCIONES, en la portada.
 *
 * Ocupa el sitio donde estuvieron «Encuentra lo tuyo» (una cuadrícula de
 * dieciséis categorías) y la pasarela de marcas. Las dos se retiraron por lo
 * mismo: enseñaban una lista, no producto.
 *
 * Aquí cada colección publicada es una fila con SUS productos, en las mismas
 * tarjetas de la tienda —foto, precio, promoción, etiqueta, corazón y botón—.
 * Se reutiliza `ProductCard` y no una versión reducida: dos tarjetas de
 * producto en el mismo sitio acaban divergiendo en el precio, que es
 * exactamente el dato que no puede divergir.
 *
 * QUÉ SE MUESTRA Y QUÉ NO
 *
 *  · Solo colecciones **publicadas** y **con al menos un producto a la venta**.
 *    Una fila con el título puesto y cero tarjetas se lee como una página
 *    rota, y ese es justo el estado normal mientras se monta la campaña.
 *  · La foto de cabecera es opcional: si no está, la fila empieza por el
 *    título.
 *  · Si no queda ninguna fila, la sección entera desaparece. Nada de
 *    «próximamente».
 */
const colecciones = useCollectionsStore()
const inventario = useInventoryStore()
const settings = useSettingsStore()

onMounted(() => {
  colecciones.init().catch(() => {})
  // `init()` del inventario ya trae el catálogo con precios y existencias: es
  // el mismo que usa la tienda, así que la portada no paga una segunda carga.
  inventario.init().catch(() => {})
  settings.init().catch(() => {})
})

// El interruptor de la sección entera vive en `store_settings`
// (`homeCollectionsVisible`, migración 026) y se acciona desde Configuración.
// Apagarlo esconde la sección sin despublicar ninguna colección.
const filas = computed(() => {
  if (!settings.coleccionesVisibles) return []

  return colecciones.publicadas
    .map((coleccion) => ({
      coleccion,
      productos: inventario.catalogWithStock.filter(
        (p) => Number(p.collectionId) === coleccion.id && p.status === 'active'
      )
    }))
    .filter((fila) => fila.productos.length > 0)
})
</script>

<template>
  <section v-if="filas.length" id="colecciones" class="bg-white py-14 sm:py-20">
    <div class="mx-auto max-w-7xl px-5 sm:px-8 lg:px-10">
      <CollectionRow
        v-for="fila in filas" :key="fila.coleccion.id"
        :coleccion="fila.coleccion"
        :productos="fila.productos"
      />
    </div>
  </section>
</template>
