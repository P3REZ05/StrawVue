import two from '../assets/images/two.png'
import three from '../assets/images/three.png'
import four from '../assets/images/four.png'
import five from '../assets/images/five.png'
import six from '../assets/images/six.png'
import seven from '../assets/images/seven.png'
import eight from '../assets/images/eight.png'
import nine from '../assets/images/nine.png'
import ten from '../assets/images/ten.png'
import eleven from '../assets/images/eleven.png'
import twelve from '../assets/images/twelve.png'
import thirteen from '../assets/images/thirteen.png'
import fourteen from '../assets/images/fourteen.png'
import fifteen from '../assets/images/fifteen.png'
import sixteen from '../assets/images/sixteen.png'

export const categories = [
  { id: 'skincare', name: 'Skincare', image: sixteen },
  { id: 'sombras', name: 'Sombras', image: two },
  { id: 'delineadores', name: 'Delineadores', image: three },
  { id: 'pestaninas', name: 'Pestañinas', image: four },
  { id: 'bases', name: 'Bases', image: five },
  { id: 'polvos', name: 'Polvos', image: six },
  { id: 'correctores', name: 'Correctores', image: seven },
  { id: 'rubores', name: 'Rubores', image: eight },
  { id: 'iluminadores', name: 'Iluminadores', image: fourteen },
  { id: 'brochas', name: 'Brochas', image: nine },
  { id: 'pestanas', name: 'Pestañas', image: ten },
  { id: 'cejas', name: 'Cejas', image: eleven },
  { id: 'labios', name: 'Labios', image: twelve },
  { id: 'primer-fijador', name: 'Primer y Fijador', image: thirteen },
  { id: 'accesorios', name: 'Accesorios', image: fifteen }
]

export const products = [
  { id: 1, name: 'Base líquida Velvet Skin', category: 'Bases', price: 38900, stock: 12, image: five, description: 'Base de acabado natural y cobertura modulable.', active: true },
  { id: 2, name: 'Paleta Rose Gold', category: 'Sombras', price: 45900, stock: 8, image: two, description: 'Tonos cálidos para looks diarios y de noche.', active: true },
  { id: 3, name: 'Labial Cherry Pop', category: 'Labios', price: 24900, stock: 20, image: twelve, description: 'Color intenso y textura cómoda de larga duración.', active: true },
  { id: 4, name: 'Rubor Soft Pink', category: 'Rubores', price: 29900, stock: 0, image: eight, description: 'Rubor de acabado suave y fácil de difuminar.', active: true },
  { id: 5, name: 'Delineador Líquido Precision', category: 'Delineadores', price: 19900, stock: 15, image: three, description: 'Punta fina para trazos precisos y definidos.', active: true },
  { id: 6, name: 'Pestañina Voluminizadora', category: 'Pestañinas', price: 22900, stock: 10, image: four, description: 'Aporta volumen y longitud sin grumos.', active: true },
  { id: 7, name: 'Polvo Compacto Matte', category: 'Polvos', price: 27900, stock: 6, image: six, description: 'Fija el maquillaje con acabado mate.', active: true },
  { id: 8, name: 'Corrector Full Coverage', category: 'Correctores', price: 25900, stock: 9, image: seven, description: 'Alta cobertura para imperfecciones y ojeras.', active: true },
  { id: 9, name: 'Iluminador Glow', category: 'Iluminadores', price: 31900, stock: 7, image: fourteen, description: 'Brillo sutil y efecto piel luminosa.', active: true },
  { id: 10, name: 'Set de Brochas Profesional', category: 'Brochas', price: 59900, stock: 4, image: nine, description: 'Set completo de brochas para maquillaje profesional.', active: true },
  { id: 11, name: 'Pestañas Postizas Naturales', category: 'Pestañas', price: 15900, stock: 18, image: ten, description: 'Pestañas postizas de aspecto natural.', active: true },
  { id: 12, name: 'Lápiz de Cejas', category: 'Cejas', price: 18900, stock: 14, image: eleven, description: 'Define y rellena tus cejas con precisión.', active: true },
  { id: 13, name: 'Primer de Maquillaje', category: 'Primer y Fijador', price: 32900, stock: 11, image: thirteen, description: 'Prepara la piel y prolonga la duración del maquillaje.', active: true },
  { id: 14, name: 'Kit de Accesorios Belleza', category: 'Accesorios', price: 12900, stock: 25, image: fifteen, description: 'Accesorios esenciales para tu rutina de belleza.', active: true },
  { id: 15, name: 'Serum Facial Vitamina C', category: 'Skincare', price: 42900, stock: 5, image: sixteen, description: 'Ilumina y revitaliza la piel con vitamina C.', active: true }
]

export const promotions = [
  { id: 1, title: 'Colección semanal', label: 'Nuevo', active: true },
  { id: 2, title: 'Skincare', label: 'Oferta', detail: 'Hasta 30% OFF', active: true },
  { id: 3, title: 'Bases mate', label: 'Trending', detail: 'Nueva colección', active: true }
]

export const defaultPromotions = [
  {
    id: 'hero-default-1',
    title: 'Nueva colección',
    subtitle: 'Looks para cada momento',
    image: '',
    link: '/tienda',
    active: true,
    accent: 'Rosado glam'
  }
]

export const socialLinks = {
  facebook: 'https://www.facebook.com/strawberry_makeup05',
  tiktok: 'https://www.tiktok.com/@strawberry_makeup05',
  instagram: 'https://www.instagram.com/strawberry_makeup05'
}

export const storeSettings = {
  freeShippingThreshold: 200000,
  shippingCost: 10000,
  whatsappNumber: '573114088065'
}

export const adminOrders = [
  { id: 1001, orderNumber: 'ORD-1001', customer: { name: 'Valentina Gómez', document: '1002456789', phone: '300 123 4567', city: 'Manizales', address: 'Carrera 23 # 55-18', notes: '' }, items: [{ productName: 'Base líquida Velvet Skin', quantity: 1, price: 38900 }, { productName: 'Labial Cherry Pop', quantity: 2, price: 24900 }], shipping: 10000, status: 'pendiente', createdAt: '2026-08-16' },
  { id: 1002, orderNumber: 'ORD-1002', customer: { name: 'Mariana López', document: '1003123456', phone: '312 555 9080', city: 'Pereira', address: 'Calle 14 # 8-20', notes: 'Entregar en portería.' }, items: [{ productName: 'Paleta Rose Gold', quantity: 1, price: 45900 }], shipping: 10000, status: 'enviado', createdAt: '2026-08-15' },
  { id: 1003, orderNumber: 'ORD-1003', customer: { name: 'Sofía Ramírez', document: '1004567890', phone: '315 222 3344', city: 'Armenia', address: 'Av. Bolívar # 12-45', notes: '' }, items: [{ productName: 'Rubor Soft Pink', quantity: 2, price: 29900 }, { productName: 'Delineador Líquido Precision', quantity: 1, price: 19900 }], shipping: 0, status: 'cancelado', createdAt: '2026-08-14' },
  { id: 1004, orderNumber: 'ORD-1004', customer: { name: 'Camila Torres', document: '1005678901', phone: '310 888 9900', city: 'Manizales', address: 'Cra 12 # 34-56', notes: 'Llamar antes de entregar.' }, items: [{ productName: 'Set de Brochas Profesional', quantity: 1, price: 59900 }], shipping: 10000, status: 'pendiente', createdAt: '2026-08-17' },
  { id: 1005, orderNumber: 'ORD-1005', customer: { name: 'Laura Cardona', document: '1006789012', phone: '313 777 1122', city: 'Chinchiná', address: 'Cra 5 # 23-12', notes: '' }, items: [{ productName: 'Serum Facial Vitamina C', quantity: 1, price: 42900 }, { productName: 'Lápiz de Cejas', quantity: 2, price: 18900 }], shipping: 0, status: 'entregado', createdAt: '2026-08-13' },
  { id: 1006, orderNumber: 'ORD-1006', customer: { name: 'Daniela Osorio', document: '1007890123', phone: '314 222 5566', city: 'Manizales', address: 'Cra 12 # 34-56', notes: 'Entregar después de las 5pm.' }, items: [{ productName: 'Paleta Rose Gold', quantity: 1, price: 45900 }], shipping: 10000, status: 'entregado', createdAt: '2026-08-12' }
]

export const adminUsers = [
  { id: 1, nombre: 'Admin Principal', email: 'admin@strawberrymakeup.com', role: 'Super Admin' }
]