import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import RestauranteSuspendido from './RestauranteSuspendido'

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
 */
export default function GuardRestaurante({ children, publico = false }) {
  const { restaurantId } = useParams()
  const [estado, setEstado] = useState('cargando') // cargando | ok | suspendido

  useEffect(() => {
    if (!restaurantId) { setEstado('ok'); return }
    let cancelado = false

    async function comprobar() {
      const { data, error } = await supabase.rpc('fn_restaurante_accesible', { p_restaurant_id: restaurantId })
      if (cancelado) return
      if (!error && data === false) {
        setEstado('suspendido')
        if (!publico) await supabase.auth.signOut()
      } else {
        setEstado(prev => (prev === 'suspendido' ? prev : 'ok'))
      }
    }

    comprobar()
    const intervalo = setInterval(comprobar, INTERVALO_MS)
    return () => { cancelado = true; clearInterval(intervalo) }
  }, [restaurantId, publico])

  if (estado === 'cargando') return null
  if (estado === 'suspendido') return <RestauranteSuspendido publico={publico} />
  return children
}
