import { useState, useEffect } from 'react'
import { supabase } from './supabase'

/**
 * Devuelve el Set de module keys activos para un restaurante (ej.
 * {'nucleo', 'reportes'}), y un helper `tieneModulo(key)` para no tener
 * que repetir `activos.has(key)` en cada pantalla.
 *
 * Uso:
 *   const { tieneModulo, loading } = useRestaurantModulos(restaurantId)
 *   {tieneModulo('reportes') && <a href="...">Dashboard</a>}
 */
export function useRestaurantModulos(restaurantId) {
  const [activos, setActivos] = useState(new Set())
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!restaurantId) { setLoading(false); return }
    let cancelado = false

    supabase
      .from('restaurant_modulos')
      .select('modulo_key')
      .eq('restaurant_id', restaurantId)
      .eq('activo', true)
      .then(({ data }) => {
        if (cancelado) return
        setActivos(new Set((data || []).map(r => r.modulo_key)))
        setLoading(false)
      })

    return () => { cancelado = true }
  }, [restaurantId])

  function tieneModulo(key) {
    return activos.has(key)
  }

  return { activos, tieneModulo, loading }
}
