import { defineStore } from 'pinia'

const sessionKey = 'strawberry-admin-session'

export const useAdminStore = defineStore('admin', {
  state: () => ({ authenticated: localStorage.getItem(sessionKey) === 'true' }),
  actions: {
    login() {
      localStorage.setItem(sessionKey, 'true')
      this.authenticated = true
    },
    logout() {
      localStorage.removeItem(sessionKey)
      this.authenticated = false
    }
  }
})
