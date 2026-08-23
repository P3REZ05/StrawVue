import { defineStore } from 'pinia'
import { isSupabaseConfigured, supabase } from '../lib/supabase'

const sessionKey = 'strawberry-admin-session'
const roleKey = 'strawberry-admin-role'

const demoEmail = 'admin@strawberrymakeup.com'
const demoPassword = 'strawberry2026'

const masterAdminRole = 'super_admin'
const allSections = ['productos', 'inventario', 'pedidos', 'historial', 'auditoria', 'configuracion']

export const useAdminStore = defineStore('admin', {
  state: () => ({
    authenticated: !isSupabaseConfigured && localStorage.getItem(sessionKey) === 'true',
    role: localStorage.getItem(roleKey) || masterAdminRole
  }),
  actions: {
    hasAccess(section) {
      return allSections.includes(section)
    },
    getAllowedSections() {
      return allSections
    },
    async init() {
      if (!isSupabaseConfigured || this.authenticated) return

      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.user) return

      const { data: profile } = await supabase
        .from('admin_profiles')
        .select('role')
        .eq('id', session.user.id)
        .maybeSingle()

      if (profile) {
        this.authenticated = true
        this.role = masterAdminRole
        localStorage.setItem(roleKey, this.role)
      }
    },
    async login(email = '', password = '') {
      const normalizedEmail = (email || '').trim().toLowerCase()
      const normalizedPassword = (password || '').trim()

      if (!normalizedEmail || !normalizedPassword) {
        throw new Error('Ingresa usuario y contraseña para continuar.')
      }

      if (isSupabaseConfigured) {
        const { data, error } = await supabase.auth.signInWithPassword({ email: normalizedEmail, password: normalizedPassword })
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
        this.role = masterAdminRole
        localStorage.setItem(roleKey, this.role)
        return
      }

      if (normalizedEmail !== demoEmail || normalizedPassword !== demoPassword) {
        throw new Error('Credenciales inválidas para el modo demo.')
      }

      localStorage.setItem(sessionKey, 'true')
      localStorage.setItem(roleKey, masterAdminRole)
      this.authenticated = true
      this.role = masterAdminRole
    },
    async logout() {
      if (isSupabaseConfigured) await supabase.auth.signOut()
      localStorage.removeItem(sessionKey)
      localStorage.removeItem(roleKey)
      this.authenticated = false
      this.role = masterAdminRole
    }
  }
})
