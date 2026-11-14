// Resuelve qué menú (de los configurados por el dueño) aplica ahora
// mismo para una mesa, según la zona del salón y la hora actual del
// restaurante (su zona horaria) — y aplica sus
// excepciones de precio/exclusión sobre la carta base. Sin ningún
// menú configurado (o si ninguno encaja), se usa la carta normal.

import { partesEnZona, ZONA_POR_DEFECTO } from './fechas'

function horaAMinutos(horaStr) {
  const [h, m] = horaStr.split(':').map(Number)
  return h * 60 + m
}

function enFranjaHoraria(menu, minutosActuales) {
  if (!menu.hora_inicio || !menu.hora_fin) return true
  const inicio = horaAMinutos(menu.hora_inicio)
  const fin = horaAMinutos(menu.hora_fin)
  if (inicio <= fin) return minutosActuales >= inicio && minutosActuales < fin
  // Franja que cruza medianoche (ej. 22:00–02:00).
  return minutosActuales >= inicio || minutosActuales < fin
}

function enDiaSemana(menu, diaActual) {
  if (!menu.dias_semana || menu.dias_semana.length === 0) return true
  return menu.dias_semana.includes(diaActual)
}

// Más específico gana: cuantos más criterios (zona, horario, días) usa
// el menú, antes se prueba.
function especificidad(menu) {
  return (menu.zona ? 1 : 0) + (menu.hora_inicio ? 1 : 0) + (menu.dias_semana?.length ? 1 : 0)
}

// zonaSalon: la zona de la mesa (interior, terraza…), no la horaria.
// Hora y día de la semana en la zona horaria del restaurante (no los del
// móvil del cliente), igual que comprueba fn_registrar_pedido con
// fn_menu_activo al guardar el pedido.
export function resolverMenuActivo(menus, zonaSalon, ahora = new Date(), zonaHoraria = ZONA_POR_DEFECTO) {
  const { minutos: minutosActuales, dia } = partesEnZona(ahora, zonaHoraria)
  const candidatos = (menus || [])
    .filter(m => m.activo)
    .filter(m => (!m.zona || m.zona === zonaSalon) && enFranjaHoraria(m, minutosActuales) && enDiaSemana(m, dia))
  if (!candidatos.length) return null
  candidatos.sort((a, b) => especificidad(b) - especificidad(a) || (a.orden - b.orden))
  return candidatos[0]
}

// Aplica las excepciones del menú resuelto sobre la lista de platos ya
// cargada — sin menú activo, devuelve los platos tal cual.
export function aplicarPreciosMenu(items, menu, precios) {
  if (!menu) return items
  const porItem = {}
  ;(precios || []).forEach(p => { if (p.menu_id === menu.id) porItem[p.menu_item_id] = p })
  return items
    .filter(i => !porItem[i.id]?.excluido)
    .map(i => {
      const override = porItem[i.id]
      return override?.precio != null ? { ...i, precio: override.precio } : i
    })
}
