// Fechas y horas "de calendario" en hora de España, independientes de la
// zona del navegador. No usar new Date().toISOString().slice(0, 10) para
// "hoy": da la fecha UTC y de 00:00 a 01:00 (02:00 en verano) sale ayer.
// Mismo criterio que fn_hoy_madrid()/fn_hora_madrid() en la base de datos.

const ZONA = 'Europe/Madrid'
const DIAS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

// { fecha: 'YYYY-MM-DD', dia: 0-6 (0 = domingo), minutos: desde medianoche }
export function partesMadrid(instante = new Date()) {
  const p = {}
  new Intl.DateTimeFormat('en-GB', {
    timeZone: ZONA, year: 'numeric', month: '2-digit', day: '2-digit',
    weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(instante).forEach(x => { p[x.type] = x.value })
  return {
    fecha: `${p.year}-${p.month}-${p.day}`,
    dia: DIAS.indexOf(p.weekday),
    minutos: Number(p.hour) * 60 + Number(p.minute),
  }
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
  const m = partesMadrid(new Date(instante)).minutos
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`
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
