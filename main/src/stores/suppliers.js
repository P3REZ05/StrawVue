import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'

// Proveedores.
//
// Vivía dentro de `inventory.js`, mezclado con saldos, compras y mostrador.
// No tiene nada que ver con las existencias: un proveedor es una ficha de
// contacto. Se separa porque la única razón por la que estaba ahí era que
// las compras lo necesitan, y eso se resuelve importando el store.
//
// Un proveedor no se borra: se desactiva. Sus órdenes de compra siguen
// existiendo y apuntando a él, igual que un producto archivado sigue
// apareciendo en pedidos viejos.

function aPayload(proveedor) {
  const nombre = proveedor.name?.trim()
  if (!nombre) throw new Error('El nombre del proveedor es obligatorio.')

  return {
    name: nombre,
    document_number: proveedor.documentNumber?.trim() || null,
    contact_name: proveedor.contactName?.trim() || null,
    phone: proveedor.phone?.trim() || null,
    email: proveedor.email?.trim() || null,
    address: proveedor.address?.trim() || null,
    city: proveedor.city?.trim() || null,
    payment_terms: proveedor.paymentTerms?.trim() || null,
    notes: proveedor.notes?.trim() || null,
    active: true
  }
}

// Supabase devuelve 42501 cuando RLS rechaza la escritura. El mensaje crudo
// ("new row violates row-level security policy") no le dice nada a quien está
// frente al panel; este sí.
function traducirError(error, quePasaba) {
  if (error.code === '42501' || error.status === 403) {
    return new Error('Supabase rechazó la operación. Verifica tu sesión y que tu usuario exista en admin_profiles.')
  }
  return new Error(quePasaba)
}

export const useSuppliersStore = defineStore('suppliers', {
  state: () => ({
    suppliers: [],
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    activos: (state) => state.suppliers.filter((p) => p.active !== false),
    porId: (state) => (id) => state.suppliers.find((p) => p.id === Number(id)) || null
  },

  actions: {
    async init() {
      if (this.initialized) return
      this.loading = true
      this.error = null
      try {
        const { data, error } = await supabase
          .from('suppliers')
          .select('*')
          .eq('active', true)
          .order('name')

        if (error) throw error
        this.suppliers = data || []
        this.initialized = true
      } catch (fallo) {
        this.error = fallo.message || 'No se pudieron cargar los proveedores.'
        throw fallo
      } finally {
        this.loading = false
      }
    },

    async saveSupplier(proveedor) {
      const payload = aPayload(proveedor)

      if (proveedor.id) {
        const { data, error } = await supabase
          .from('suppliers')
          .update(payload)
          .eq('id', proveedor.id)
          .select()
          .single()

        if (error) throw traducirError(error, 'No se pudo actualizar el proveedor.')

        const i = this.suppliers.findIndex((p) => p.id === proveedor.id)
        if (i !== -1) this.suppliers[i] = data
        else this.suppliers.push(data)
        return data
      }

      const { data, error } = await supabase.from('suppliers').insert(payload).select().single()
      if (error) throw traducirError(error, 'No se pudo crear el proveedor.')

      this.suppliers.push(data)
      return data
    },

    // Desactivar, no borrar. El estado local se actualiza DESPUÉS de que la
    // base confirme: la versión anterior lo ponía en `false` antes de escribir,
    // así que si la escritura fallaba, la pantalla mostraba un proveedor
    // desactivado que en la base seguía activo.
    async deactivateSupplier(supplierId) {
      const { data, error } = await supabase
        .from('suppliers')
        .update({ active: false })
        .eq('id', supplierId)
        .select('id')

      if (error) throw traducirError(error, 'No se pudo desactivar el proveedor.')
      if (!data?.length) {
        throw new Error('No se desactivó ningún proveedor. Puede que ya no exista o que no tengas permiso.')
      }

      const proveedor = this.suppliers.find((p) => p.id === supplierId)
      if (proveedor) proveedor.active = false
      return true
    }
  }
})
