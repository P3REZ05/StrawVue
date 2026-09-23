import { createRouter, createWebHistory } from 'vue-router'
import { useAdminStore } from '../stores/admin'
import Home from '../views/Home.vue'

// La portada se importa de forma estática: es lo primero que ve casi todo el
// mundo y hacerla esperar a una segunda petición solo añade parpadeo.
//
// Todo lo demás va con `import()`. El panel de administración pesa más que la
// tienda entera —productos, tonos, reportes con sus gráficos, auditoría,
// proveedores— y antes viajaba en el mismo archivo que descargaba cualquier
// clienta que entrara a ver un labial desde el móvil. Vite corta un fragmento
// por cada `import()` y el navegador solo pide el que hace falta.
const About = () => import('../views/About.vue')
const Contact = () => import('../views/Contact.vue')
const Shop = () => import('../views/Shop.vue')
const ProductDetail = () => import('../views/ProductDetail.vue')
const Cart = () => import('../views/Cart.vue')
const Favorites = () => import('../views/Favorites.vue')
const Terms = () => import('../views/Terms.vue')

const AdminLogin = () => import('../views/admin/AdminLogin.vue')
const AdminPanel = () => import('../components/admin/AdminPanel.vue')
const ProductEditor = () => import('../views/admin/ProductEditor.vue')

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
    { path: '/favoritos', name: 'favorites', component: Favorites },
    { path: '/terminos', name: 'terms', component: Terms },
    { path: '/admin', name: 'admin-login', component: AdminLogin },
    { path: '/admin/dashboard', name: 'admin-dashboard', component: AdminPanel },
    // El editor vive en su propia ruta para que un producto se pueda enlazar
    // y para que la matriz de tonos tenga sitio. `nuevo` crea uno en blanco.
    { path: '/admin/productos/:id', name: 'admin-product-editor', component: ProductEditor },
    // Sin esto, cualquier URL que no exista dejaba la página en blanco sin
    // decir nada: ni 404, ni redirección, ni error en consola.
    { path: '/:pathMatch(.*)*', name: 'not-found', redirect: '/' }
  ]
})

router.beforeEach(async (to, from, next) => {
  const adminStore = useAdminStore()
  await adminStore.init()

  // Todo `/admin/*` menos el propio login. La comprobación de
  // `/admin/dashboard` que había aparte era redundante: esta ya la cubre.
  const isAdminRoute = to.path.startsWith('/admin') && to.path !== '/admin'

  if (to.path === '/admin' && adminStore.authenticated) {
    next('/admin/dashboard')
    return
  }

  if (isAdminRoute && !adminStore.authenticated) {
    next('/admin')
    return
  }

  next()
})

export default router
