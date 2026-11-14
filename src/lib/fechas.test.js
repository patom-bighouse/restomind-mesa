// Criterio 8a de docs/specs/2026-11-14-zona-horaria-restaurante.md (fechas.js).
// Instantes fijos: el resultado no depende de la zona del ordenador.
import { describe, it, expect } from 'vitest'
import {
  partesEnZona, hoyEnZona, horaEnZona, fechaEnZona, fechaHoraEnZona, fechaHoraCortaEnZona,
  inicioDiaEnZona, rangoDiasEnZona, fechaHoraConLocal, zonaHorariaDe, ZONA_POR_DEFECTO,
  partesMadrid, hoyMadrid, horaMadrid, fechaISOMadrid, sumarDiasISO,
} from './fechas'

const MAD = 'Europe/Madrid'
const CAN = 'Atlantic/Canary'
const MEX = 'America/Mexico_City'

describe('partesEnZona', () => {
  it('devuelve fecha, hora, día de la semana y minutos', () => {
    expect(partesEnZona('2027-01-15T12:30:00Z', MAD)).toEqual({ fecha: '2027-01-15', hora: '13:30', dia: 5, minutos: 810 })
  })

  it('criterio 4: 2027-01-15 12:30Z es 13:30 en Madrid y 12:30 en Canarias', () => {
    expect(partesEnZona('2027-01-15T12:30:00Z', MAD).hora).toBe('13:30')
    expect(partesEnZona('2027-01-15T12:30:00Z', CAN).hora).toBe('12:30')
  })

  it('criterio 4: 2027-07-15 19:30Z es 13:30 en México (sin horario de verano) y 21:30 en Madrid', () => {
    expect(partesEnZona('2027-07-15T19:30:00Z', MEX).minutos).toBe(13 * 60 + 30)
    expect(partesEnZona('2027-07-15T19:30:00Z', MAD).minutos).toBe(21 * 60 + 30)
  })

  it('cambio de hora de marzo (2027-03-28 a las 01:00 UTC) en Canarias y Madrid', () => {
    expect(partesEnZona('2027-03-28T00:59:00Z', CAN).hora).toBe('00:59')
    expect(partesEnZona('2027-03-28T00:59:00Z', MAD).hora).toBe('01:59')
    expect(partesEnZona('2027-03-28T01:00:00Z', CAN).hora).toBe('02:00')
    expect(partesEnZona('2027-03-28T01:00:00Z', MAD).hora).toBe('03:00')
  })

  it('cambio de hora de octubre (2027-10-31) en Canarias', () => {
    expect(partesEnZona('2027-10-31T00:59:00Z', CAN).hora).toBe('01:59')
    expect(partesEnZona('2027-10-31T01:00:00Z', CAN).hora).toBe('01:00')
  })

  it('México no cambia de hora (2027-04-04 y 2027-10-31 a las 12:00Z → 06:00)', () => {
    expect(partesEnZona('2027-04-04T12:00:00Z', MEX).hora).toBe('06:00')
    expect(partesEnZona('2027-10-31T12:00:00Z', MEX).hora).toBe('06:00')
  })

  it('sin zona usa la de por defecto (Madrid)', () => {
    expect(partesEnZona('2027-01-15T12:30:00Z', '')).toEqual(partesEnZona('2027-01-15T12:30:00Z', MAD))
    expect(ZONA_POR_DEFECTO).toBe(MAD)
  })
})

describe('hoyEnZona', () => {
  it('a las 23:30 UTC de invierno ya es mañana en Madrid, pero no en Canarias ni en México', () => {
    const ahora = new Date('2027-01-15T23:30:00Z')
    expect(hoyEnZona(MAD, ahora)).toBe('2027-01-16')
    expect(hoyEnZona(CAN, ahora)).toBe('2027-01-15')
    expect(hoyEnZona(MEX, ahora)).toBe('2027-01-15')
  })

  it('en México sigue siendo ayer hasta las 06:00 UTC', () => {
    expect(hoyEnZona(MEX, new Date('2027-01-16T05:59:00Z'))).toBe('2027-01-15')
    expect(hoyEnZona(MEX, new Date('2027-01-16T06:00:00Z'))).toBe('2027-01-16')
  })
})

describe('textos de fecha y hora', () => {
  it('horaEnZona, fechaEnZona, fechaHoraEnZona y fechaHoraCortaEnZona', () => {
    const t = '2027-01-15T23:30:00Z'
    expect(horaEnZona(t, CAN)).toBe('23:30')
    expect(fechaEnZona(t, MAD)).toBe('16/01/2027')
    expect(fechaHoraEnZona(t, CAN)).toBe('15/01/2027 23:30')
    expect(fechaHoraCortaEnZona(t, MEX)).toBe('15/01 17:30')
  })
})

describe('inicioDiaEnZona', () => {
  it('medianoche del restaurante en UTC', () => {
    expect(inicioDiaEnZona('2027-01-15', MAD).toISOString()).toBe('2027-01-14T23:00:00.000Z')
    expect(inicioDiaEnZona('2027-01-15', CAN).toISOString()).toBe('2027-01-15T00:00:00.000Z')
    expect(inicioDiaEnZona('2027-07-15', MEX).toISOString()).toBe('2027-07-15T06:00:00.000Z')
    expect(inicioDiaEnZona('2027-07-15', CAN).toISOString()).toBe('2027-07-14T23:00:00.000Z')
  })
})

describe('rangoDiasEnZona', () => {
  it('"Hoy" va de 00:00 a 00:00 del restaurante', () => {
    const ahora = new Date('2027-01-15T23:30:00Z')
    const can = rangoDiasEnZona('hoy', null, null, CAN, ahora)
    expect(can.from.toISOString()).toBe('2027-01-15T00:00:00.000Z')
    expect(can.to.toISOString()).toBe('2027-01-16T00:00:00.000Z')
    expect(can.dias).toEqual(['2027-01-15'])
    const mad = rangoDiasEnZona('hoy', null, null, MAD, ahora)
    expect(mad.from.toISOString()).toBe('2027-01-15T23:00:00.000Z')
    expect(mad.dias).toEqual(['2027-01-16'])
    const mex = rangoDiasEnZona('hoy', null, null, MEX, new Date('2027-07-15T19:30:00Z'))
    expect(mex.from.toISOString()).toBe('2027-07-15T06:00:00.000Z')
    expect(mex.dias).toEqual(['2027-07-15'])
  })

  it('"Esta semana" empieza el lunes del restaurante', () => {
    // Domingo 2027-01-17 23:30 en Canarias = lunes 00:30 en Madrid.
    const ahora = new Date('2027-01-17T23:30:00Z')
    expect(rangoDiasEnZona('semana', null, null, CAN, ahora).desde).toBe('2027-01-11')
    expect(rangoDiasEnZona('semana', null, null, MAD, ahora).desde).toBe('2027-01-18')
    expect(rangoDiasEnZona('semana', null, null, CAN, ahora).dias).toHaveLength(7)
  })

  it('"Este mes" del restaurante', () => {
    const ahora = new Date('2027-01-31T23:30:00Z')
    const can = rangoDiasEnZona('mes', null, null, CAN, ahora)
    expect([can.desde, can.hasta, can.dias.length]).toEqual(['2027-01-01', '2027-01-31', 31])
    const mad = rangoDiasEnZona('mes', null, null, MAD, ahora)
    expect([mad.desde, mad.hasta]).toEqual(['2027-02-01', '2027-02-28'])
    expect(rangoDiasEnZona('mes', null, null, MAD, new Date('2027-12-10T12:00:00Z')).to.toISOString()).toBe('2027-12-31T23:00:00.000Z')
  })

  it('el día del cambio de hora en Canarias dura 23 horas', () => {
    const r = rangoDiasEnZona('custom', '2027-03-28', '2027-03-28', CAN)
    expect(r.from.toISOString()).toBe('2027-03-28T00:00:00.000Z')
    expect(r.to.toISOString()).toBe('2027-03-28T23:00:00.000Z')
  })

  it('personalizado: invertido → un día; más de 366 días → se recorta', () => {
    expect(rangoDiasEnZona('custom', '2027-05-10', '2027-05-01', MAD).dias).toEqual(['2027-05-10'])
    expect(rangoDiasEnZona('custom', '2020-01-01', '2027-01-01', MAD).dias).toHaveLength(366)
    expect(rangoDiasEnZona('custom', '', '', MEX, new Date('2027-07-15T03:00:00Z')).desde).toBe('2027-07-14')
  })
})

describe('fechaHoraConLocal (panel del superadmin, decisión 7)', () => {
  it('Canarias: hora de España y la del restaurante al lado', () => {
    expect(fechaHoraConLocal('2027-01-15T21:00:00Z', CAN)).toBe('15/01/2027 22:00 (21:00 en el restaurante)')
  })
  it('Madrid: solo la hora de España', () => {
    expect(fechaHoraConLocal('2027-01-15T21:00:00Z', MAD)).toBe('15/01/2027 22:00')
    expect(fechaHoraConLocal('2027-01-15T21:00:00Z', 'Africa/Ceuta')).toBe('15/01/2027 22:00')
  })
  it('si cambia el día, también se dice el día local', () => {
    expect(fechaHoraConLocal('2026-11-13T23:30:00Z', CAN)).toBe('14/11/2026 00:30 (13/11 23:30 en el restaurante)')
  })
  it('sin restaurante: solo hora de España', () => {
    expect(fechaHoraConLocal('2027-01-15T21:00:00Z', null)).toBe('15/01/2027 22:00')
  })
})

describe('zonaHorariaDe', () => {
  it('la del restaurante o la de por defecto si falta', () => {
    expect(zonaHorariaDe({ zona_horaria: CAN })).toBe(CAN)
    expect(zonaHorariaDe({ zona_horaria: null })).toBe(MAD)
    expect(zonaHorariaDe(null)).toBe(MAD)
  })
})

describe('negocio de Restomind: sigue en hora de España', () => {
  it('partesMadrid, fechaISOMadrid, horaMadrid', () => {
    expect(partesMadrid(new Date('2027-01-15T23:30:00Z'))).toEqual({ fecha: '2027-01-16', dia: 6, minutos: 30 })
    expect(fechaISOMadrid(new Date('2027-07-15T22:30:00Z'))).toBe('2027-07-16')
    expect(horaMadrid('2027-03-28T01:00:00Z')).toBe('03:00')
    expect(hoyMadrid()).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })
  it('sumarDiasISO no depende de la zona', () => {
    expect(sumarDiasISO('2027-03-27', 1)).toBe('2027-03-28')
    expect(sumarDiasISO('2027-01-01', -1)).toBe('2026-12-31')
  })
})
