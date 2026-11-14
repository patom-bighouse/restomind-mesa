// Fechas y horas "de calendario" independientes de la zona del navegador.
// No usar new Date().toISOString().slice(0, 10) para "hoy" (da la fecha UTC)
// ni toLocale…String() sin timeZone (da la hora del móvil o del ordenador).
//
// Regla 7 de CLAUDE.md:
//   - Operativa del restaurante (reservas, recogidas, menús, vales, cierre de
//     caja, pantallas del dueño, del camarero y de la cocina): la zona horaria
//     del restaurante (restaurants.zona_horaria) → funciones "EnZona", con la
//     zona como parámetro. Misma hora que fn_ahora_restaurante() /
//     fn_hoy_restaurante() en la base de datos.
//   - Negocio de Restomind (pruebas gratuitas, permanencia, CRM, facturación,
//     panel del superadmin): hora de España → partesMadrid, hoyMadrid,
//     fechaISOMadrid y horaMadrid (fn_hoy_madrid() en la base de datos).

const ZONA_ESPANA = 'Europe/Madrid'
const DIAS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

// Zona de un restaurante que no la trae (dato vacío) y la de España para lo
// de negocio.
export const ZONA_POR_DEFECTO = ZONA_ESPANA

// Zona horaria de un restaurante leído de la BD ({ zona_horaria }).
export function zonaHorariaDe(restaurante) {
  return (restaurante && restaurante.zona_horaria) || ZONA_POR_DEFECTO
}

// { fecha: 'YYYY-MM-DD', hora: 'HH:MM', dia: 0-6 (0 = domingo), minutos: desde
// la medianoche } de un instante en una zona.
// Un formateador por zona (crearlo es caro y el panel lo usa por cada pedido).
const formateadores = new Map()
function formateador(zona) {
  let f = formateadores.get(zona)
  if (!f) {
    f = new Intl.DateTimeFormat('en-GB', {
      timeZone: zona, year: 'numeric', month: '2-digit', day: '2-digit',
      weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    })
    formateadores.set(zona, f)
  }
  return f
}

export function partesEnZona(instante = new Date(), zona = ZONA_POR_DEFECTO) {
  const p = {}
  formateador(zona || ZONA_POR_DEFECTO).formatToParts(new Date(instante)).forEach(x => { p[x.type] = x.value })
  return {
    fecha: `${p.year}-${p.month}-${p.day}`,
    hora: `${p.hour}:${p.minute}`,
    dia: DIAS.indexOf(p.weekday),
    minutos: Number(p.hour) * 60 + Number(p.minute),
  }
}

// 'YYYY-MM-DD' de hoy en la zona dada.
export function hoyEnZona(zona = ZONA_POR_DEFECTO, ahora = new Date()) {
  return partesEnZona(ahora, zona).fecha
}

// 'HH:MM' de un instante en la zona dada.
export function horaEnZona(instante, zona = ZONA_POR_DEFECTO) {
  return partesEnZona(instante, zona).hora
}

// 'DD/MM/AAAA' de un instante en la zona dada.
export function fechaEnZona(instante, zona = ZONA_POR_DEFECTO) {
  return fechaISOaTexto(partesEnZona(instante, zona).fecha)
}

// 'DD/MM/AAAA HH:MM' de un instante en la zona dada.
export function fechaHoraEnZona(instante, zona = ZONA_POR_DEFECTO) {
  const { fecha, hora } = partesEnZona(instante, zona)
  return `${fechaISOaTexto(fecha)} ${hora}`
}

// 'DD/MM HH:MM' de un instante en la zona dada.
export function fechaHoraCortaEnZona(instante, zona = ZONA_POR_DEFECTO) {
  const { fecha, hora } = partesEnZona(instante, zona)
  return `${fechaISOaTexto(fecha).slice(0, 5)} ${hora}`
}

// Texto largo ("sábado, 14 de noviembre") de un instante en la zona dada.
export function fechaLargaEnZona(instante = new Date(), zona = ZONA_POR_DEFECTO) {
  return new Date(instante).toLocaleDateString('es-ES', { timeZone: zona || ZONA_POR_DEFECTO, weekday: 'long', day: 'numeric', month: 'long' })
}

// 'YYYY-MM-DD' → 'DD/MM/AAAA', sin pasar por ninguna zona horaria.
export function fechaISOaTexto(fechaISO) {
  const [a, m, d] = String(fechaISO || '').slice(0, 10).split('-')
  return a && m && d ? `${d}/${m}/${a}` : ''
}

// Instante (Date) en que empieza el día 'YYYY-MM-DD' en la zona dada. Sirve
// para filtrar por días del restaurante en la base de datos (created_at >= …).
export function inicioDiaEnZona(fechaISO, zona = ZONA_POR_DEFECTO) {
  const [a, m, d] = fechaISO.split('-').map(Number)
  const objetivo = Date.UTC(a, m - 1, d, 0, 0)
  let t = objetivo
  // Dos pasadas bastan para cuadrar el desfase (también con cambio de hora).
  for (let i = 0; i < 2; i++) {
    const p = partesEnZona(new Date(t), zona)
    const [pa, pm, pd] = p.fecha.split('-').map(Number)
    const [hh, mm] = p.hora.split(':').map(Number)
    const visto = Date.UTC(pa, pm - 1, pd, hh, mm)
    t += objetivo - visto
  }
  return new Date(t)
}

// Día de la semana (0 = domingo) de 'YYYY-MM-DD', sin zonas horarias.
export function diaSemanaISO(fechaISO) {
  return new Date(fechaISO + 'T12:00:00Z').getUTCDay()
}

// Rango de días del restaurante para el panel: 'hoy', 'semana' (de lunes a
// domingo), 'mes' o 'custom' (desde/hasta 'YYYY-MM-DD', ambos incluidos;
// máximo 366 días). Devuelve { from, to } (instantes, to excluido) para
// filtrar en la BD, y { desde, hasta, dias } en fechas del restaurante.
export const MAX_DIAS_RANGO = 366
export function rangoDiasEnZona(rango, desde, hasta, zona = ZONA_POR_DEFECTO, ahora = new Date()) {
  const hoy = hoyEnZona(zona, ahora)
  const esFecha = f => /^\d{4}-\d{2}-\d{2}$/.test(f || '')
  let ini, finExcl
  if (rango === 'hoy') {
    ini = hoy
    finExcl = sumarDiasISO(hoy, 1)
  } else if (rango === 'semana') {
    ini = sumarDiasISO(hoy, -((diaSemanaISO(hoy) + 6) % 7))
    finExcl = sumarDiasISO(ini, 7)
  } else if (rango === 'mes') {
    ini = hoy.slice(0, 8) + '01'
    const [a, m] = ini.split('-').map(Number)
    finExcl = m === 12 ? `${a + 1}-01-01` : `${a}-${String(m + 1).padStart(2, '0')}-01`
  } else {
    ini = esFecha(desde) ? desde : hoy
    finExcl = esFecha(hasta) ? sumarDiasISO(hasta, 1) : sumarDiasISO(ini, 1)
    // Fechas invertidas o un valor corrupto: mejor un día que un rango roto.
    if (!(finExcl > ini)) finExcl = sumarDiasISO(ini, 1)
    // Límite de seguridad: no cargar años de pedidos ni miles de barras.
    const maximo = sumarDiasISO(ini, MAX_DIAS_RANGO)
    if (finExcl > maximo) finExcl = maximo
  }
  const dias = []
  for (let d = ini; d < finExcl && dias.length <= MAX_DIAS_RANGO; d = sumarDiasISO(d, 1)) dias.push(d)
  return {
    from: inicioDiaEnZona(ini, zona),
    to: inicioDiaEnZona(finExcl, zona),
    desde: ini,
    hasta: sumarDiasISO(finExcl, -1),
    dias,
  }
}

// Panel del superadmin (decisión 7): hora de España y, si en el restaurante
// es otra, su hora local al lado.
//   '15/01/2027 22:00 (21:00 en el restaurante)'
//   '14/11/2026 00:30 (13/11 23:30 en el restaurante)'  (cambia el día)
//   '15/01/2027 22:00'                                  (misma hora)
export function fechaHoraConLocal(instante, zonaRestaurante) {
  const es = partesEnZona(instante, ZONA_ESPANA)
  const texto = `${fechaISOaTexto(es.fecha)} ${es.hora}`
  if (!zonaRestaurante) return texto
  const loc = partesEnZona(instante, zonaRestaurante)
  if (loc.fecha === es.fecha && loc.hora === es.hora) return texto
  const local = loc.fecha === es.fecha ? loc.hora : `${fechaISOaTexto(loc.fecha).slice(0, 5)} ${loc.hora}`
  return `${texto} (${local} en el restaurante)`
}

// Suma días (o años con sumarAnios) a una fecha 'YYYY-MM-DD' sin pasar por
// ninguna zona horaria.
export function sumarDiasISO(fechaISO, dias) {
  const d = new Date(fechaISO + 'T12:00:00Z')
  d.setUTCDate(d.getUTCDate() + dias)
  return d.toISOString().slice(0, 10)
}

export function sumarAniosISO(fechaISO, anios) {
  const d = new Date(fechaISO + 'T12:00:00Z')
  d.setUTCFullYear(d.getUTCFullYear() + anios)
  return d.toISOString().slice(0, 10)
}

// --- Solo para lo de negocio de Restomind (hora de España) --------------------
// No usar para la operativa del restaurante: ahí van las de arriba con su zona.

// { fecha, dia, minutos } en España.
export function partesMadrid(instante = new Date()) {
  const { fecha, dia, minutos } = partesEnZona(instante, ZONA_ESPANA)
  return { fecha, dia, minutos }
}

// 'YYYY-MM-DD' del día en España de un instante (por defecto, ahora).
export function fechaISOMadrid(instante = new Date()) {
  return partesMadrid(instante).fecha
}

export function hoyMadrid() {
  return fechaISOMadrid()
}

// 'HH:MM' en España de un instante (Date o texto ISO de la base de datos).
export function horaMadrid(instante) {
  return partesEnZona(new Date(instante), ZONA_ESPANA).hora
}
