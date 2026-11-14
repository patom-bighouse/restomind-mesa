// Criterio 8a de docs/specs/2026-11-14-zona-horaria-restaurante.md
// (horarioReservas.js): mismas reglas que el criterio 5 en la BD (15 min de
// antelación con la hora del restaurante).
import { describe, it, expect } from 'vitest'
import { horasReserva } from './horarioReservas'
import { partesEnZona } from './fechas'

// Abierto todos los días de 13:00 a 16:00 y de 20:00 a 23:30; última reserva 0 min antes del cierre.
const dia = { abierto: true, apertura: '13:00', cierre: '16:00', apertura2: '20:00', cierre2: '23:30' }
const config = {
  reservas_minutos_antes_cierre: 0,
  horario: Object.fromEntries(['domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado'].map(d => [d, dia])),
}

describe('horasReserva con la hora del restaurante', () => {
  // 2027-01-15 13:30Z: 13:30 en Canarias, 14:30 en Madrid, 07:30 en México.
  const instante = new Date('2027-01-15T13:30:00Z')

  it('Canarias: hoy, la primera hora es la de Canarias + 15 min', () => {
    const r = horasReserva(config, '2027-01-15', partesEnZona(instante, 'Atlantic/Canary'))
    expect(r.horas[0]).toBe('13:45')
    expect(r.horas).not.toContain('13:30')
  })

  it('Madrid: el mismo instante da una hora más tarde', () => {
    const r = horasReserva(config, '2027-01-15', partesEnZona(instante, 'Europe/Madrid'))
    expect(r.horas[0]).toBe('14:45')
  })

  it('México: a las 07:30 aún se puede todo el día', () => {
    const r = horasReserva(config, '2027-01-15', partesEnZona(instante, 'America/Mexico_City'))
    expect(r.horas[0]).toBe('13:00')
  })

  it('otro día no limita por la hora actual', () => {
    const r = horasReserva(config, '2027-01-16', partesEnZona(instante, 'Atlantic/Canary'))
    expect(r.horas[0]).toBe('13:00')
    expect(r.horas.at(-1)).toBe('23:15')
  })

  it('cerca de medianoche: en Canarias todavía es el día 15', () => {
    const tarde = new Date('2027-01-15T22:50:00Z') // 22:50 en Canarias, 23:50 en Madrid
    const ahora = partesEnZona(tarde, 'Atlantic/Canary')
    expect(ahora.fecha).toBe('2027-01-15')
    // 22:50 + 15 = 23:05 → 23:15 (con margen 0 la última es 23:29, sin la exacta).
    expect(horasReserva(config, '2027-01-15', ahora).horas).toEqual(['23:15'])
    expect(horasReserva(config, '2027-01-15', partesEnZona(tarde, 'Europe/Madrid')).horas).toEqual([])
    expect(horasReserva(config, '2027-01-16', partesEnZona(tarde, 'Europe/Madrid')).horas[0]).toBe('13:00')
  })

  it('día del cambio de hora en Canarias (2027-03-28 01:00Z = 02:00)', () => {
    const r = horasReserva(config, '2027-03-28', partesEnZona(new Date('2027-03-28T12:50:00Z'), 'Atlantic/Canary'))
    // 12:50Z = 13:50 (ya en verano) → 14:05 como pronto → 14:15
    expect(r.horas[0]).toBe('14:15')
  })

  it('sin horario configurado no limita (null)', () => {
    expect(horasReserva({}, '2027-01-15', partesEnZona(instante, 'Atlantic/Canary'))).toBeNull()
  })
})
