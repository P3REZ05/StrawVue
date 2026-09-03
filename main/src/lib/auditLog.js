import { supabase } from './supabase'

// Escribe un evento de negocio en audit_logs.
//
// La tabla tiene UNA sola forma en toda la aplicación:
//   table_name / record_id / action / old_data / new_data / note
// `changed_by` y `changed_at` los rellena la base de datos.
//
// Los cambios técnicos (INSERT/UPDATE/DELETE fila a fila) ya los captura el
// trigger `audit_trigger` en Postgres. Esta función es para los eventos que
// el trigger no puede nombrar, como "el admin confirmó el pago".
export async function logAudit({ table, recordId, action, oldData = null, newData = null, note = null }) {
  const { error } = await supabase.from('audit_logs').insert({
    table_name: table,
    record_id: recordId,
    action,
    old_data: oldData,
    new_data: newData,
    note
  })

  // La auditoría nunca debe tumbar la operación que la originó.
  if (error) console.error('No se pudo registrar la auditoría:', error.message)
  return !error
}
