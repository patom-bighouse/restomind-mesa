// Zonas horarias que se ofrecen al superadmin, por país (decisión 2 de
// docs/specs/2026-11-14-zona-horaria-restaurante.md): una lista corta con
// nombres claros, sin campo libre. La primera de cada país es la propuesta.
// La BD acepta cualquier zona IANA con región (trigger
// fn_restaurants_validar_zona_horaria): para abrir un país nuevo basta con
// añadir aquí su lista, sin migración.

import { partesEnZona, ZONA_POR_DEFECTO } from './fechas'

export const ZONAS_POR_PAIS = {
  ES: [
    { zona: 'Europe/Madrid', nombre: 'Península y Baleares' },
    { zona: 'Atlantic/Canary', nombre: 'Canarias' },
  ],
  MX: [
    { zona: 'America/Mexico_City', nombre: 'Ciudad de México (centro)' },
    { zona: 'America/Cancun', nombre: 'Quintana Roo (Cancún)' },
    { zona: 'America/Merida', nombre: 'Yucatán y Campeche (Mérida)' },
    { zona: 'America/Monterrey', nombre: 'Nuevo León y Tamaulipas (Monterrey)' },
    { zona: 'America/Chihuahua', nombre: 'Chihuahua' },
    { zona: 'America/Ciudad_Juarez', nombre: 'Ciudad Juárez' },
    { zona: 'America/Mazatlan', nombre: 'Pacífico (Mazatlán)' },
    { zona: 'America/Hermosillo', nombre: 'Sonora (Hermosillo)' },
    { zona: 'America/Tijuana', nombre: 'Baja California (Tijuana)' },
  ],
  US: [
    { zona: 'America/New_York', nombre: 'Este (Nueva York)' },
    { zona: 'America/Chicago', nombre: 'Centro (Chicago)' },
    { zona: 'America/Denver', nombre: 'Montaña (Denver)' },
    { zona: 'America/Phoenix', nombre: 'Arizona (Phoenix)' },
    { zona: 'America/Los_Angeles', nombre: 'Pacífico (Los Ángeles)' },
    { zona: 'America/Anchorage', nombre: 'Alaska (Anchorage)' },
    { zona: 'Pacific/Honolulu', nombre: 'Hawái (Honolulu)' },
  ],
  AR: [{ zona: 'America/Argentina/Buenos_Aires', nombre: 'Argentina' }],
  CO: [{ zona: 'America/Bogota', nombre: 'Colombia' }],
  CL: [
    { zona: 'America/Santiago', nombre: 'Chile continental (Santiago)' },
    { zona: 'America/Punta_Arenas', nombre: 'Magallanes (Punta Arenas)' },
    { zona: 'Pacific/Easter', nombre: 'Isla de Pascua' },
  ],
  PE: [{ zona: 'America/Lima', nombre: 'Perú' }],
}

// true si el navegador conoce la zona (Intl). Una zona que no conoce no se
// ofrece: no se podría mostrar su hora.
export function zonaValida(zona) {
  if (!zona || typeof zona !== 'string') return false
  try {
    new Intl.DateTimeFormat('en-GB', { timeZone: zona })
    return true
  } catch {
    return false
  }
}

// Zonas de la lista del país, solo las que el navegador conoce.
export function zonasDePais(pais) {
  return (ZONAS_POR_PAIS[pais] || []).filter(z => zonaValida(z.zona))
}

// Nombre claro de una zona ("Canarias"); si no está en ninguna lista, el
// nombre IANA tal cual.
export function nombreZona(zona) {
  for (const lista of Object.values(ZONAS_POR_PAIS)) {
    const z = lista.find(x => x.zona === zona)
    if (z) return z.nombre
  }
  return zona || ''
}

// Opciones del desplegable: las del país y, si la zona elegida o la que
// tenía guardada el restaurante no están en su lista (puesta por SQL, o de
// otro país), también esas, marcadas. La guardada sigue aunque se elija
// otra, para poder volver a ella.
export function opcionesZona(pais, zonaActual, zonaGuardada = null) {
  const opciones = zonasDePais(pais).map(z => ({ ...z, fueraDeLista: false }))
  for (const z of [zonaGuardada, zonaActual]) {
    if (z && !opciones.some(o => o.zona === z)) {
      opciones.push({ zona: z, nombre: `${nombreZona(z)} (fuera de la lista)`, fueraDeLista: true })
    }
  }
  return opciones
}

// Hora actual en la zona, para mostrarla junto a cada opción.
export function horaActualEnZona(zona, ahora = new Date()) {
  if (!zonaValida(zona)) return '--:--'
  try {
    return partesEnZona(ahora, zona).hora
  } catch {
    return '--:--'
  }
}

function normalizar(texto) {
  return String(texto || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
}

const CANARIAS = [
  'canarias', 'las palmas', 'santa cruz de tenerife', 'tenerife', 'gran canaria', 'lanzarote',
  'fuerteventura', 'la palma', 'la gomera', 'el hierro', 'la graciosa',
]

// true si el texto de la dirección parece de Canarias: provincia, isla o
// código postal 35xxx / 38xxx. Sin distinguir mayúsculas ni tildes. Si hay
// un código postal de fuera de Canarias, manda él ("Calle La Palma, 28004
// Madrid" no es Canarias).
export function pareceCanarias(direccion) {
  const t = normalizar(direccion)
  if (!t.trim()) return false
  const cps = t.match(/(?<!\d)\d{5}(?!\d)/g) || []
  if (cps.some(cp => /^3[58]/.test(cp))) return true
  if (cps.length) return false
  return CANARIAS.some(n => new RegExp(`(^|[^a-z])${n}([^a-z]|$)`).test(t))
}

const PENINSULA = [
  'madrid', 'barcelona', 'valencia', 'sevilla', 'zaragoza', 'malaga', 'murcia', 'bilbao', 'alicante',
  'cordoba', 'valladolid', 'vigo', 'gijon', 'granada', 'a coruna', 'vitoria', 'oviedo', 'pamplona',
  'santander', 'san sebastian', 'donostia', 'salamanca', 'cadiz', 'toledo', 'palma de mallorca', 'ibiza', 'menorca',
]

// true si la dirección parece claramente de la península o Baleares:
// código postal español de fuera de Canarias (01xxx-52xxx salvo 35 y 38) o
// una ciudad conocida. Solo si no parece de Canarias.
export function parecePeninsula(direccion) {
  const t = normalizar(direccion)
  if (!t.trim() || pareceCanarias(direccion)) return false
  const cps = t.match(/(?<!\d)\d{5}(?!\d)/g) || []
  if (cps.some(cp => Number(cp.slice(0, 2)) >= 1 && Number(cp.slice(0, 2)) <= 52)) return true
  return PENINSULA.some(n => new RegExp(`(^|[^a-z])${n}([^a-z]|$)`).test(t))
}

// Zona que se propone para un país y una dirección (decisión 3): con
// España y una dirección de Canarias, Canarias; si no, la primera del país.
export function zonaPropuesta(pais, direccion) {
  if (pais === 'ES' && pareceCanarias(direccion)) return 'Atlantic/Canary'
  return zonasDePais(pais)[0]?.zona || ZONA_POR_DEFECTO
}

// Aviso junto al selector al editar un restaurante (decisión 8): la
// dirección sugiere otra zona de la lista. No cambia la zona sola.
// Avisa en los dos sentidos: dirección de Canarias con la zona de la
// península, y dirección claramente peninsular con la zona de Canarias.
export function avisoDireccion(pais, direccion, zonaActual) {
  if (pais !== 'ES' || !zonaActual) return null
  let sugerida = null
  if (zonaActual !== 'Atlantic/Canary' && pareceCanarias(direccion)) sugerida = 'Atlantic/Canary'
  else if (zonaActual === 'Atlantic/Canary' && parecePeninsula(direccion)) sugerida = 'Europe/Madrid'
  if (!sugerida) return null
  return `Esta dirección parece de ${nombreZona(sugerida)} y la zona es ${nombreZona(zonaActual)}`
}

// Reservas futuras (decisión 5): confirmadas o pendientes con fecha + hora
// ("de pared", la del restaurante) posteriores a ahora en la zona dada.
export function contarReservasFuturas(reservas, zonaHoraria = ZONA_POR_DEFECTO, ahora = new Date()) {
  const p = partesEnZona(ahora, zonaHoraria)
  const ahoraTxt = `${p.fecha} ${p.hora}`
  return (reservas || []).filter(r => {
    if (r.estado && !['confirmada', 'pendiente'].includes(r.estado)) return false
    if (!r.fecha || !r.hora) return false
    return `${String(r.fecha).slice(0, 10)} ${String(r.hora).slice(0, 5)}` > ahoraTxt
  }).length
}
