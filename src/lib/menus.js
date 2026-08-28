// Resuelve qué menú (de los configurados por el dueño) aplica ahora
// mismo para una mesa, según su zona y la hora actual — y aplica sus
// excepciones de precio/exclusión sobre la carta base. Sin ningún
// menú configurado (o si ninguno encaja), se usa la carta normal.

function minutosDesdeMedianoche(date) {
  return date.getHours() * 60 + date.getMinutes()
}

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

// Más específico gana: zona+hora > solo hora > solo zona > genérico.
function especificidad(menu) {
  return (menu.zona ? 1 : 0) + (menu.hora_inicio ? 1 : 0)
}

export function resolverMenuActivo(menus, zona, ahora = new Date()) {
  const minutosActuales = minutosDesdeMedianoche(ahora)
  const candidatos = (menus || [])
    .filter(m => m.activo)
    .filter(m => (!m.zona || m.zona === zona) && enFranjaHoraria(m, minutosActuales))
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
