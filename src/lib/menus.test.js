// Criterio 8a de docs/specs/2026-11-14-zona-horaria-restaurante.md (menus.js):
// mismos casos que el criterio 4 en la BD (fn_menu_activo).
import { describe, it, expect } from 'vitest'
import { resolverMenuActivo } from './menus'

const mediodia = { id: 'm1', nombre: 'Mediodía', activo: true, zona: null, hora_inicio: '13:00', hora_fin: '14:00', dias_semana: null, orden: 0 }
const madrugada = { id: 'm2', nombre: 'Madrugada', activo: true, zona: null, hora_inicio: '02:00', hora_fin: '03:00', dias_semana: null, orden: 0 }
const domingo = { id: 'm3', nombre: 'Domingo', activo: true, zona: null, hora_inicio: null, hora_fin: null, dias_semana: [0], orden: 0 }
const terraza = { id: 'm4', nombre: 'Terraza', activo: true, zona: 'terraza', hora_inicio: '13:00', hora_fin: '14:00', dias_semana: null, orden: 0 }
const menus = [mediodia, madrugada]
const nombre = (m) => m?.nombre ?? null

describe('resolverMenuActivo con la zona horaria del restaurante', () => {
  it('2027-01-15 12:30Z: Madrid (13:30) sí, Canarias (12:30) no', () => {
    const t = new Date('2027-01-15T12:30:00Z')
    expect(nombre(resolverMenuActivo(menus, null, t, 'Europe/Madrid'))).toBe('Mediodía')
    expect(nombre(resolverMenuActivo(menus, null, t, 'Atlantic/Canary'))).toBeNull()
  })

  it('2027-07-15 19:30Z: México (13:30) sí, Madrid (21:30) no', () => {
    const t = new Date('2027-07-15T19:30:00Z')
    expect(nombre(resolverMenuActivo(menus, null, t, 'America/Mexico_City'))).toBe('Mediodía')
    expect(nombre(resolverMenuActivo(menus, null, t, 'Europe/Madrid'))).toBeNull()
  })

  it('cambio de hora en Canarias (2027-03-28): 00:59Z no, 01:00Z (02:00) sí; Madrid a las 01:00Z (03:00) no', () => {
    expect(nombre(resolverMenuActivo(menus, null, new Date('2027-03-28T00:59:00Z'), 'Atlantic/Canary'))).toBeNull()
    expect(nombre(resolverMenuActivo(menus, null, new Date('2027-03-28T01:00:00Z'), 'Atlantic/Canary'))).toBe('Madrugada')
    expect(nombre(resolverMenuActivo(menus, null, new Date('2027-03-28T01:00:00Z'), 'Europe/Madrid'))).toBeNull()
  })

  it('el día de la semana también es el del restaurante', () => {
    // 2027-01-17 23:30Z: domingo 17:30 en México, lunes 00:30 en Madrid.
    const t = new Date('2027-01-17T23:30:00Z')
    expect(nombre(resolverMenuActivo([domingo], null, t, 'America/Mexico_City'))).toBe('Domingo')
    expect(nombre(resolverMenuActivo([domingo], null, t, 'Europe/Madrid'))).toBeNull()
  })

  it('la zona del salón sigue siendo otra cosa', () => {
    const t = new Date('2027-01-15T12:30:00Z')
    expect(nombre(resolverMenuActivo([terraza], 'terraza', t, 'Europe/Madrid'))).toBe('Terraza')
    expect(nombre(resolverMenuActivo([terraza], 'interior', t, 'Europe/Madrid'))).toBeNull()
  })

  it('sin zona horaria usa la de por defecto (Madrid)', () => {
    expect(nombre(resolverMenuActivo(menus, null, new Date('2027-01-15T12:30:00Z')))).toBe('Mediodía')
  })
})
