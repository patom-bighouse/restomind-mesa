// Constantes y helpers del CRM de vendedores (sql/crm_vendedores.sql).
// Las etapas y tipos de actividad deben coincidir con los check
// constraints de la base.

export const ETAPAS = [
  { key: 'prospecto', label: 'Prospecto' },
  { key: 'contactado', label: 'Contactado' },
  { key: 'demo', label: 'Demo agendada' },
  { key: 'propuesta', label: 'Propuesta' },
  { key: 'negociacion', label: 'Negociación' },
  { key: 'ganado', label: 'Ganado' },
  { key: 'perdido', label: 'Perdido' },
]

export const ETAPAS_ABIERTAS = ['prospecto', 'contactado', 'demo', 'propuesta', 'negociacion']

export function etapaLabel(key) {
  return ETAPAS.find(e => e.key === key)?.label || key
}

export const TIPOS_ACTIVIDAD = [
  { key: 'llamada', label: 'Llamada', icono: '📞' },
  { key: 'visita', label: 'Visita', icono: '🚶' },
  { key: 'whatsapp', label: 'WhatsApp', icono: '💬' },
  { key: 'email', label: 'Email', icono: '✉️' },
  { key: 'demo', label: 'Demo', icono: '🖥' },
  { key: 'nota', label: 'Nota', icono: '📝' },
]

export function tipoActividad(key) {
  return TIPOS_ACTIVIDAD.find(t => t.key === key) || { key, label: key, icono: '•' }
}

export const FUENTES = ['Puerta fría', 'Referido', 'Web', 'Redes sociales', 'Evento', 'Llamada entrante', 'Cliente existente', 'Otro']

export const TIPOS_LOCAL = ['Restaurante', 'Bar', 'Cafetería', 'Pizzería', 'Hamburguesería', 'Comida rápida', 'Take away', 'Hotel', 'Otro']

export const MOTIVOS_PERDIDA = ['Precio', 'Ya tiene otra solución', 'No ve el valor', 'Mal momento', 'No responde', 'Cerró el local', 'Otro']

// Días sin actividad a partir de los que una cuenta abierta se marca
// como "fría" en el tablero.
export const DIAS_SIN_ACTIVIDAD = 14

// Un cliente es una cuenta ganada ya convertida (vinculada a restaurants).
export function esCliente(cuenta) {
  return !!cuenta.restaurant_id
}

export function hoyISO() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export function mesISO(fecha = new Date()) {
  return `${fecha.getFullYear()}-${String(fecha.getMonth() + 1).padStart(2, '0')}-01`
}

export function fmtFecha(iso) {
  if (!iso) return '—'
  const d = iso.length === 10 ? new Date(iso + 'T00:00:00') : new Date(iso)
  return d.toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' })
}

export function fmtFechaHora(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('es-ES', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })
}

export function fmtMes(iso) {
  if (!iso) return '—'
  return new Date(iso.slice(0, 10) + 'T00:00:00').toLocaleDateString('es-ES', { month: 'long', year: 'numeric' })
}

export function fmtEuro(n) {
  if (n == null || isNaN(n)) return '—'
  return Number(n).toLocaleString('es-ES', { minimumFractionDigits: 0, maximumFractionDigits: 2 }) + ' €'
}

export function diasDesde(iso) {
  if (!iso) return null
  return Math.floor((Date.now() - new Date(iso).getTime()) / 86400000)
}
