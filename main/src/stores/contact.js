import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { logAudit } from '../lib/auditLog'

/**
 * Bandeja de mensajes del formulario público.
 *
 * Antes esta tabla no existía y `Contact.vue` no guardaba nada: el cliente
 * veía "¡Mensaje recibido!" y el mensaje se perdía.
 */

export const ESTADOS = {
  new: { texto: 'Nuevo', clase: 'bg-[var(--primary)]' },
  read: { texto: 'Leído', clase: 'bg-neutral-400' },
  answered: { texto: 'Respondido', clase: 'bg-emerald-500' },
  archived: { texto: 'Archivado', clase: 'bg-neutral-600' }
}

export const useContactStore = defineStore('contact', {
  state: () => ({
    mensajes: [],
    loading: false,
    error: null,
    initialized: false
  }),

  getters: {
    sinLeer: (state) => state.mensajes.filter((m) => m.status === 'new').length,
    // Los archivados no son basura, son historia: se guardan pero no
    // estorban en la bandeja del día a día.
    bandeja: (state) => state.mensajes.filter((m) => m.status !== 'archived'),
    archivados: (state) => state.mensajes.filter((m) => m.status === 'archived')
  },

  actions: {
    async init() {
      if (this.initialized) return
      await this.load()
      this.initialized = true
    },

    async load() {
      this.loading = true
      this.error = null
      try {
        const { data, error } = await supabase
          .from('contact_messages')
          .select('*')
          .order('created_at', { ascending: false })

        if (error) throw new Error('No se pudieron cargar los mensajes de contacto.')
        this.mensajes = data || []
      } catch (fallo) {
        this.error = fallo.message
        throw fallo
      } finally {
        this.loading = false
      }
    },

    /**
     * Cambia el estado de un mensaje.
     *
     * Se comprueba que volvió una fila: con RLS activo, un UPDATE sin permiso
     * no da error, simplemente no afecta a nada y parece que guardó.
     */
    async setStatus(mensaje, status, adminNote = undefined) {
      const cambios = { status }
      if (adminNote !== undefined) cambios.admin_note = adminNote?.trim() || null

      const { data, error } = await supabase
        .from('contact_messages')
        .update(cambios)
        .eq('id', mensaje.id)
        .select()

      if (error) throw new Error(`No se pudo actualizar el mensaje: ${error.message}`)
      if (!data?.length) {
        throw new Error('No se guardó el cambio: la base lo rechazó sin dar error. Revisa tu sesión de administrador.')
      }

      const i = this.mensajes.findIndex((m) => m.id === mensaje.id)
      if (i !== -1) this.mensajes[i] = data[0]

      await logAudit({
        table: 'contact_messages',
        recordId: mensaje.id,
        action: 'CONTACT_STATUS_CHANGED',
        oldData: { status: mensaje.status },
        newData: cambios,
        note: `Mensaje de ${mensaje.name}: ${mensaje.status} → ${status}`
      })

      return data[0]
    },

    /** Marca como leído al abrirlo, sin pisar un estado más avanzado. */
    async marcarLeido(mensaje) {
      if (mensaje.status !== 'new') return mensaje
      return this.setStatus(mensaje, 'read')
    }
  }
})
