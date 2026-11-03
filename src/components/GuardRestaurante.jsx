import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import RestauranteSuspendido from './RestauranteSuspendido'
import AceptarCondiciones from './AceptarCondiciones'
import { CONDICIONES_VERSION } from '../lib/condiciones'

// Cada cuánto se vuelve a comprobar, para que una pantalla que se quedó
// abierta (cocina, camarero) se corte sola al desactivar el restaurante.
const INTERVALO_MS = 60 * 1000

/**
 * Envuelve una ruta con `:restaurantId` y la sustituye por la pantalla de
 * suspendido si el restaurante está inactivo. El candado real está en la
 * base de datos (sql/restaurante_inactivo.sql); esto solo evita que se
 * vea una página rota. El superadmin pasa siempre.
 *
 * Si la comprobación falla (red, función aún no creada) deja pasar: la
 * base de datos sigue bloqueando igualmente.
 *
 * En las rutas privadas, además, el dueño de un restaurante con
 * permanencia no pasa hasta aceptar las condiciones del servicio.
 */
export default function GuardRestaurante({ children, publico = false }) {
  const { restaurantId } = useParams()
  const [estado, setEstado] = useState('cargando') // cargando | ok | suspendido | condiciones

  useEffect(() => {
    if (!restaurantId) { setEstado('ok'); return }
    let cancelado = false

    // Devuelve false si el restaurante está suspendido.
    async function comprobar() {
      const { data, error } = await supabase.rpc('fn_restaurante_accesible', { p_restaurant_id: restaurantId })
      if (cancelado) return true
      if (!error && data === false) {
        setEstado('suspendido')
        if (!publico) await supabase.auth.signOut()
        return false
      }
      return true
    }

    // La primera vez, antes de mostrar nada: suspendido, condiciones
    // pendientes o acceso normal.
    async function inicial() {
      if (!(await comprobar()) || cancelado) return
      let pendientes = false
      if (!publico) {
        const { data } = await supabase.rpc('fn_condiciones_pendientes', { p_restaurant_id: restaurantId, p_version: CONDICIONES_VERSION })
        pendientes = data === true
      }
      if (!cancelado) setEstado(prev => (prev === 'suspendido' ? prev : pendientes ? 'condiciones' : 'ok'))
    }

    inicial()
    const intervalo = setInterval(comprobar, INTERVALO_MS)
    return () => { cancelado = true; clearInterval(intervalo) }
  }, [restaurantId, publico])

  if (estado === 'cargando') return null
  if (estado === 'suspendido') return <RestauranteSuspendido publico={publico} />
  if (estado === 'condiciones') return <AceptarCondiciones restaurantId={restaurantId} onAceptado={() => setEstado('ok')} />
  return children
}
