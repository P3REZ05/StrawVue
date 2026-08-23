import { createRouter, createWebHistory } from 'vue-router'
import { useAdminStore } from '../stores/admin'
import Home from '../views/Home.vue'
import Terms from '../views/Terms.vue'
import About from '../views/About.vue'
import Contact from '../views/Contact.vue'
import Shop from '../views/Shop.vue'
import ProductDetail from '../views/ProductDetail.vue'
import Cart from '../views/Cart.vue'
import AdminLogin from '../views/admin/AdminLogin.vue'
import AdminPanel from '../components/admin/AdminPanel.vue'

const router = createRouter({
  history: createWebHistory(),
  scrollBehavior: () => ({ top: 0 }),
  routes: [
    { path: '/', name: 'home', component: Home },
    { path: '/nosotros', name: 'about', component: About },
    { path: '/contacto', name: 'contact', component: Contact },
    { path: '/tienda', name: 'shop', component: Shop },
    { path: '/producto/:id', name: 'product-detail', component: ProductDetail },
    { path: '/carrito', name: 'cart', component: Cart },
    { path: '/terminos', name: 'terms', component: Terms },
    { path: '/admin', name: 'admin-login', component: AdminLogin },
    { path: '/admin/dashboard', name: 'admin-dashboard', component: AdminPanel }
  ]
})

router.beforeEach(async (to, from, next) => {
  const adminStore = useAdminStore()
  await adminStore.init()
  const isAdminRoute = to.path.startsWith('/admin') && to.path !== '/admin'

  if (to.path === '/admin' && adminStore.authenticated) {
    next('/admin/dashboard')
    return
  }

  if (isAdminRoute && !adminStore.authenticated) {
    next('/admin')
    return
  }

  if (to.path === '/admin/dashboard' && !adminStore.authenticated) {
    next('/admin')
    return
  }

  next()
})

export default router
