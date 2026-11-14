// Horas a las que se puede reservar un día, según config.horario del
// restaurante. Mismo criterio que fn_reserva_fuera_de_horario (base de
// datos, la que decide; sql/reserva_web_horario.sql) y que el agente de
// WhatsApp (horarioReserva en n8n):
//   - franjas del día; las horas de madrugada (00:15) salen de la franja del
//     día anterior que cruza la medianoche;
//   - última reserva: config.reservas_minutos_antes_cierre minutos antes del
//     cierre de cada franja (60 por defecto; 0 = hasta el cierre);
//   - hoy (en la zona horaria del restaurante), al menos 15 minutos de
//     antelación, como fn_crear_reserva_web con fn_ahora_restaurante();
//   - sin horario configurado no se limita (devuelve null).

import { partesEnZona, ZONA_POR_DEFECTO } from './fechas'

const DIAS = ['domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado']
const ANTELACION_MIN = 15
const PASO_MIN = 15

function aMin(hhmm) {
  const m = String(hhmm || '').match(/^(\d{1,2}):(\d{2})/)
  return m ? Number(m[1]) * 60 + Number(m[2]) : null
}

function aHHMM(min) {
  const m = ((min % 1440) + 1440) % 1440
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`
}

// Día de la semana (0 = domingo) de 'YYYY-MM-DD', sin zonas horarias.
function diaDeFecha(fecha) {
  const d = new Date(fecha + 'T12:00:00Z')
  return d.getUTCDay()
}

function minutosAntesCierre(config) {
  const v = Number(config?.reservas_minutos_antes_cierre)
  return Number.isFinite(v) && v >= 0 ? Math.floor(v) : 60
}

// [{ inicio, ultima, exacta }] en minutos desde la medianoche del día; las
// que cruzan la medianoche acaban por encima de 1440. exacta: la última
// reserva también se ofrece aunque no caiga en el paso de 15 min (22:50);
// con margen 0 no (sería "23:29").
function franjasDeDia(config, dia) {
  const h = config?.horario?.[DIAS[dia]]
  if (!h || !h.abierto) return []
  const antes = minutosAntesCierre(config)
  const margen = Math.max(antes, 1)
  const out = []
  ;[[h.apertura, h.cierre], [h.apertura2, h.cierre2]].forEach(([a, c]) => {
    const inicio = aMin(a)
    let fin = aMin(c)
    if (inicio === null || fin === null) return
    if (fin <= inicio) fin += 1440
    out.push({ inicio, ultima: fin - margen, exacta: antes > 0 })
  })
  return out
}

// { cerrado: true si el restaurante no abre ese día, horas: ['13:00', ...] }
// o null si el restaurante no tiene horario configurado.
// ahora: { fecha, minutos } en la zona del restaurante, de
// partesEnZona(new Date(), zonaHoraria). Sin él, la zona por defecto.
export function horasReserva(config, fecha, ahora = partesEnZona(new Date(), ZONA_POR_DEFECTO)) {
  if (!config?.horario || !/^\d{4}-\d{2}-\d{2}$/.test(fecha || '')) return null
  const dia = diaDeFecha(fecha)
  const hoy = franjasDeDia(config, dia)
  const ayer = franjasDeDia(config, (dia + 6) % 7)
  const minimo = fecha === ahora.fecha ? ahora.minutos + ANTELACION_MIN : -1
  const horas = new Set()
  // Madrugada, de la franja de ayer que cruza la medianoche.
  ayer.forEach(f => {
    for (let t = f.inicio; t <= f.ultima; t += PASO_MIN) {
      if (t >= 1440 && t - 1440 >= minimo) horas.add(t - 1440)
    }
    if (f.exacta && f.ultima >= 1440 && f.ultima >= f.inicio && f.ultima - 1440 >= minimo) horas.add(f.ultima - 1440)
  })
  // Franjas del día (lo que pase de la medianoche es del día siguiente).
  hoy.forEach(f => {
    for (let t = f.inicio; t <= f.ultima && t < 1440; t += PASO_MIN) {
      if (t >= minimo) horas.add(t)
    }
    if (f.exacta && f.ultima < 1440 && f.ultima >= f.inicio && f.ultima >= minimo) horas.add(f.ultima)
  })
  return {
    cerrado: hoy.length === 0 && horas.size === 0,
    horas: [...horas].sort((a, b) => a - b).map(aHHMM),
  }
}
