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

export const FUENTES = ['Puerta fría', 'Referido', 'Web', 'Redes sociales', 'Evento', 'Llamada entrante', 'Cliente existente', 'Búsqueda Google', 'Otro']

export const TIPOS_LOCAL = ['Restaurante', 'Bar', 'Cafetería', 'Pizzería', 'Hamburguesería', 'Comida rápida', 'Take away', 'Hotel', 'Otro']

// Tipos del buscador de restaurantes (Google Places). Las claves deben
// coincidir con TIPOS de supabase/functions/crm-buscar-restaurantes.
// tipoLocal: con qué "Tipo" del CRM se importa.
export const TIPOS_BUSQUEDA = [
  { key: 'restaurante', label: 'Restaurantes (todos)', tipoLocal: 'Restaurante' },
  { key: 'bar', label: 'Bares', tipoLocal: 'Bar' },
  { key: 'tapas', label: 'Bares de tapas', tipoLocal: 'Bar' },
  { key: 'cafeteria', label: 'Cafeterías', tipoLocal: 'Cafetería' },
  { key: 'pizzeria', label: 'Pizzerías', tipoLocal: 'Pizzería' },
  { key: 'hamburgueseria', label: 'Hamburgueserías', tipoLocal: 'Hamburguesería' },
  { key: 'comida_rapida', label: 'Comida rápida', tipoLocal: 'Comida rápida' },
  { key: 'espanol', label: 'Cocina española', tipoLocal: 'Restaurante' },
  { key: 'italiano', label: 'Italianos', tipoLocal: 'Restaurante' },
  { key: 'japones', label: 'Japoneses / sushi', tipoLocal: 'Restaurante' },
  { key: 'chino', label: 'Chinos', tipoLocal: 'Restaurante' },
  { key: 'mexicano', label: 'Mexicanos', tipoLocal: 'Restaurante' },
  { key: 'marisqueria', label: 'Marisquerías', tipoLocal: 'Restaurante' },
  { key: 'asador', label: 'Asadores / parrillas', tipoLocal: 'Restaurante' },
  { key: 'vegetariano', label: 'Vegetarianos', tipoLocal: 'Restaurante' },
  { key: 'brunch', label: 'Brunch', tipoLocal: 'Cafetería' },
]

export const PAISES_BUSQUEDA = [
  { key: 'ES', label: 'España' }, { key: 'PT', label: 'Portugal' }, { key: 'AR', label: 'Argentina' },
  { key: 'MX', label: 'México' }, { key: 'CO', label: 'Colombia' }, { key: 'CL', label: 'Chile' },
  { key: 'UY', label: 'Uruguay' }, { key: 'PE', label: 'Perú' },
]

// Tamaño estimado por nº de reseñas en Google (no hay dato de mesas). Es
// orientativo: las reseñas también crecen con la antigüedad y el turismo.
export const TAMANOS = [
  { key: 'pequeno', label: 'Pequeño', min: 0 },
  { key: 'mediano', label: 'Mediano', min: 150 },
  { key: 'grande', label: 'Grande', min: 600 },
  { key: 'muy_grande', label: 'Muy grande', min: 1500 },
]

export function tamanoPorResenas(n) {
  if (n == null) return null
  return [...TAMANOS].reverse().find(t => n >= t.min).key
}

export function tamanoLabel(key) {
  return TAMANOS.find(t => t.key === key)?.label || null
}

export function nivelPrecioLabel(n) {
  return n == null ? null : n === 0 ? 'Gratis' : '€'.repeat(n)
}

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

// Google Maps: el enlace exacto que haya pegado el vendedor o, si no, una
// búsqueda por nombre + dirección + ciudad. null si no hay con qué ubicarlo.
// Saca la URL de lo que se haya pegado: al compartir desde Google Maps a
// veces se copia "Nombre del local https://maps.app.goo.gl/…", o el enlace
// sin https://. Sin esquema el navegador lo trataría como ruta interna.
export function normalizarUrl(texto) {
  const t = (texto || '').trim()
  if (!t) return ''
  const m = t.match(/https?:\/\/\S+/i)
  if (m) return m[0]
  if (!/\s/.test(t) && /^[\w-]+(\.[\w-]+)+/.test(t)) return `https://${t}`
  return t
}

export function enlaceMaps(c) {
  const url = normalizarUrl(c.maps_url)
  if (/^https?:\/\//i.test(url)) return url
  if (!c.direccion && !c.ciudad) return null
  const q = [c.nombre, c.direccion, c.ciudad].filter(Boolean).join(', ')
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q)}`
}

// Ruta desde donde esté el vendedor. Con solo el enlace exacto (sin
// dirección) no se puede armar la ruta: se abre el enlace y desde ahí "Cómo llegar".
export function enlaceRuta(c) {
  if (!c.direccion && !c.ciudad) {
    const url = normalizarUrl(c.maps_url)
    return /^https?:\/\//i.test(url) ? url : null
  }
  const q = [c.nombre, c.direccion, c.ciudad].filter(Boolean).join(', ')
  return `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(q)}`
}
