import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

// Supabase es obligatorio. Antes existía un "modo demo" que, si faltaba el
// .env, servía datos falsos y autenticaba el panel admin contra localStorage.
// Eso escondía fallos de red y dejaba el panel abierto en cualquier build sin
// configurar, así que se eliminó: es mejor fallar aquí, fuerte y temprano.
if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Faltan VITE_SUPABASE_URL y/o VITE_SUPABASE_ANON_KEY. ' +
    'Copia main/.env.example a main/.env y completa las credenciales de tu proyecto Supabase.'
  )
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
