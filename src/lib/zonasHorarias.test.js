// Criterio 8a de docs/specs/2026-11-14-zona-horaria-restaurante.md (zonasHorarias.js).
import { describe, it, expect } from 'vitest'
import {
  ZONAS_POR_PAIS, zonasDePais, parecePeninsula, zonaValida, nombreZona, opcionesZona, zonaPropuesta, pareceCanarias,
  avisoDireccion, contarReservasFuturas, horaActualEnZona,
} from './zonasHorarias'

describe('lista por país (decisión 2)', () => {
  it('todas las zonas de la lista existen en Intl y tienen región', () => {
    for (const [pais, lista] of Object.entries(ZONAS_POR_PAIS)) {
      expect(lista.length, pais).toBeGreaterThan(0)
      for (const z of lista) {
        expect(zonaValida(z.zona), z.zona).toBe(true)
        expect(z.zona).toMatch(/^(Africa|America|Antarctica|Asia|Atlantic|Australia|Europe|Indian|Pacific)\//)
        expect(z.nombre).toBeTruthy()
      }
    }
  })

  it('España: Península y Baleares (la primera) y Canarias', () => {
    expect(zonasDePais('ES').map(z => z.nombre)).toEqual(['Península y Baleares', 'Canarias'])
    expect(nombreZona('Atlantic/Canary')).toBe('Canarias')
  })

  it('no acepta zonas inventadas ni vacías', () => {
    expect(zonaValida('Europe/Madird')).toBe(false)
    expect(zonaValida('')).toBe(false)
    expect(zonaValida(null)).toBe(false)
  })

  it('una zona guardada fuera de la lista se muestra marcada para no perderla', () => {
    const op = opcionesZona('ES', 'America/Bogota')
    expect(op.map(o => o.zona)).toEqual(['Europe/Madrid', 'Atlantic/Canary', 'America/Bogota'])
    expect(op[2].fueraDeLista).toBe(true)
    expect(op[2].nombre).toContain('fuera de la lista')
    expect(opcionesZona('ES', 'Atlantic/Canary')).toHaveLength(2)
  })

  it('la zona guardada fuera de la lista sigue aunque se elija otra', () => {
    const op = opcionesZona('ES', 'Atlantic/Canary', 'America/Bogota')
    expect(op.map(o => o.zona)).toEqual(['Europe/Madrid', 'Atlantic/Canary', 'America/Bogota'])
    expect(opcionesZona('ES', 'Europe/Madrid', 'Atlantic/Canary')).toHaveLength(2)
  })

  it('hora actual de cada zona para el desplegable', () => {
    expect(horaActualEnZona('Atlantic/Canary', new Date('2027-01-15T21:00:00Z'))).toBe('21:00')
    expect(horaActualEnZona('Zona/Mala', new Date())).toBe('--:--')
  })
})

describe('zonaPropuesta (decisión 3)', () => {
  it('criterio 8a', () => {
    expect(zonaPropuesta('ES', 'C/ Mayor 3, 35600 Puerto del Rosario')).toBe('Atlantic/Canary')
    expect(zonaPropuesta('ES', 'C/ Mayor 3, 28013 Madrid')).toBe('Europe/Madrid')
    expect(zonaPropuesta('MX', 'Av. Reforma 1, CDMX')).toBe('America/Mexico_City')
    expect(zonaPropuesta('MX', 'C/ Mayor 3, 35600 Puerto del Rosario')).toBe('America/Mexico_City')
  })

  it('Canarias por isla, provincia o código postal, sin mayúsculas ni tildes', () => {
    expect(pareceCanarias('Calle Real 1, LANZAROTE')).toBe(true)
    expect(pareceCanarias('Avenida 2, Santa Cruz de Tenerife')).toBe(true)
    expect(pareceCanarias('Plaza 4, Las Palmas de Gran Canaria')).toBe(true)
    expect(pareceCanarias('Valverde, El Hierro')).toBe(true)
    expect(pareceCanarias('Caleta de Sebo, la graciosa')).toBe(true)
    expect(pareceCanarias('Calle 5, 38001')).toBe(true)
    expect(pareceCanarias('canárias')).toBe(true)
    expect(pareceCanarias('Calle Mayor 3, Madrid')).toBe(false)
    expect(pareceCanarias('')).toBe(false)
  })

  it('un código postal de la península manda sobre un nombre de calle', () => {
    expect(pareceCanarias('Calle La Palma 4, 28004 Madrid')).toBe(false)
    expect(zonaPropuesta('ES', 'Calle Tenerife 2, 28039 Madrid')).toBe('Europe/Madrid')
  })

  it('país sin lista: la zona por defecto', () => {
    expect(zonaPropuesta('FR', 'Paris')).toBe('Europe/Madrid')
  })
})

describe('avisoDireccion (decisión 8)', () => {
  it('dirección de Canarias con la zona de la península', () => {
    expect(avisoDireccion('ES', 'C/ Mayor 3, 35600 Puerto del Rosario', 'Europe/Madrid'))
      .toBe('Esta dirección parece de Canarias y la zona es Península y Baleares')
  })
  it('dirección claramente peninsular con la zona de Canarias', () => {
    expect(avisoDireccion('ES', 'C/ Mayor 3, 28013 Madrid', 'Atlantic/Canary'))
      .toBe('Esta dirección parece de Península y Baleares y la zona es Canarias')
    expect(avisoDireccion('ES', 'Gran Vía 1, Bilbao', 'Atlantic/Canary'))
      .toBe('Esta dirección parece de Península y Baleares y la zona es Canarias')
    expect(parecePeninsula('Calle La Palma 4, 28004 Madrid')).toBe(true)
    expect(parecePeninsula('Puerto del Rosario, 35600')).toBe(false)
    expect(parecePeninsula('Calle Sin Ciudad 4')).toBe(false)
    expect(avisoDireccion('ES', 'Calle Sin Ciudad 4', 'Atlantic/Canary')).toBeNull()
  })

  it('sin aviso si ya está en Canarias o la dirección no dice nada', () => {
    expect(avisoDireccion('ES', 'Puerto del Rosario, Fuerteventura', 'Atlantic/Canary')).toBeNull()
    expect(avisoDireccion('ES', 'C/ Mayor 3, Madrid', 'Europe/Madrid')).toBeNull()
    expect(avisoDireccion('MX', 'Fuerteventura', 'America/Mexico_City')).toBeNull()
  })
})

describe('contarReservasFuturas (decisión 5)', () => {
  // 2027-01-15 21:00Z = 21:00 en Canarias y 22:00 en Madrid.
  const ahora = new Date('2027-01-15T21:00:00Z')
  const reservas = [
    { fecha: '2027-01-15', hora: '21:30:00', estado: 'confirmada' },
    { fecha: '2027-01-15', hora: '20:30:00', estado: 'pendiente' },
    { fecha: '2027-01-16', hora: '13:00:00', estado: 'pendiente' },
    { fecha: '2027-01-14', hora: '23:00:00', estado: 'confirmada' },
    { fecha: '2027-01-15', hora: '23:00:00', estado: 'cancelada' },
  ]
  it('no cuenta las ya pasadas en la zona dada', () => {
    expect(contarReservasFuturas(reservas, 'Atlantic/Canary', ahora)).toBe(2)
    expect(contarReservasFuturas(reservas, 'Europe/Madrid', ahora)).toBe(1)
    expect(contarReservasFuturas(reservas, 'America/Mexico_City', ahora)).toBe(3)
  })
  it('lista vacía', () => {
    expect(contarReservasFuturas([], 'Europe/Madrid', ahora)).toBe(0)
    expect(contarReservasFuturas(null, 'Europe/Madrid', ahora)).toBe(0)
  })
})
