import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'

const roleKey = 'strawberry-admin-role'
const masterAdminRole = 'super_admin'
const allSections = ['productos', 'inventario', 'pedidos', 'historial', 'auditoria', 'configuracion']

export const useAdminStore = defineStore('admin', {
  state: () => ({
    authenticated: false,
    role: localStorage.getItem(roleKey) || masterAdminRole,
    initialized: false
  }),
  actions: {
    hasAccess(section) {
      return allSections.includes(section)
    },
    getAllowedSections() {
      return allSections
    },

    // Resuelve la sesión una sola vez por carga de página.
    // Antes el guard del router llamaba a init() en CADA navegación,
    // incluidas las públicas, disparando dos consultas de red por clic.
    async init() {
      if (this.initialized) return
      this.initialized = true

      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.user) return

      const { data: profile } = await supabase
        .from('admin_profiles')
        .select('role')
        .eq('id', session.user.id)
        .maybeSingle()

      if (profile) {
        this.authenticated = true
        this.role = profile.role || masterAdminRole
        localStorage.setItem(roleKey, this.role)
      } else {
        // Usuario de Auth válido pero sin perfil admin: no es administrador.
        await supabase.auth.signOut()
      }
    },

    async login(email = '', password = '') {
      const normalizedEmail = String(email || '').trim().toLowerCase()
      const normalizedPassword = String(password || '').trim()

      if (!normalizedEmail || !normalizedPassword) {
        throw new Error('Ingresa usuario y contraseña para continuar.')
      }

      const { data, error } = await supabase.auth.signInWithPassword({
        email: normalizedEmail,
        password: normalizedPassword
      })
      if (error || !data.user) throw new Error('Credenciales inválidas.')

      const { data: profile, error: profileError } = await supabase
        .from('admin_profiles')
        .select('role')
        .eq('id', data.user.id)
        .maybeSingle()

      if (profileError || !profile) {
        await supabase.auth.signOut()
        throw new Error('Tu usuario no tiene un perfil admin autorizado.')
      }

      this.authenticated = true
      this.initialized = true
      this.role = profile.role || masterAdminRole
      localStorage.setItem(roleKey, this.role)
    },

    async logout() {
      await supabase.auth.signOut()
      localStorage.removeItem(roleKey)
      this.authenticated = false
      this.initialized = true
      this.role = masterAdminRole
    }
  }
})
