import { useState, useEffect, useRef } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useRestaurantModulos } from '../lib/modulos'
import { playWaiterBell, unlockAudio } from '../lib/sound'
import { zonaHorariaDe } from '../lib/fechas'
import { COLUMNAS_AVISO, esVisibleParaRestaurante, textoAviso, telefonoAviso } from '../lib/avisosAgente'

const ALTO = 56

const S = {
  banda: { position: 'fixed', top: 0, left: 0, right: 0, zIndex: 1000, minHeight: ALTO, boxSizing: 'border-box', background: '#3a1410', borderBottom: '1px solid #e74c3c', color: '#f8e0d8', fontFamily: "'Inter', sans-serif", display: 'flex', alignItems: 'center', gap: 12, padding: '8px 16px', flexWrap: 'wrap', boxShadow: '0 2px 12px rgba(0,0,0,0.5)' },
  icono: { fontSize: 20 },
  texto: { flex: '1 1 260px', fontSize: 14, lineHeight: 1.4 },
  extra: { fontSize: 12, color: '#e8a090', marginLeft: 6 },
  tel: { color: '#ffd7a0', fontWeight: 600 },
  btn: { background: 'transparent', color: '#f8e0d8', border: '0.5px solid #e87a7a', borderRadius: 8, padding: '6px 12px', fontSize: 13, cursor: 'pointer', fontFamily: "'Inter', sans-serif", whiteSpace: 'nowrap' },
  btnPrincipal: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 8, padding: '7px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", whiteSpace: 'nowrap' },
  error: { fontSize: 12, color: '#ffb0a0', flexBasis: '100%' },
}

/**
 * Alerta al momento de los avisos del agente de WhatsApp (decisiones 3 y 11).
 * Va en todas las páginas /admin/... del restaurante y en /cocina/...
 * (lo monta GuardRestaurante); nunca en /camarero/....
 *
 * Mismo patrón que la llamada al camarero: Realtime filtrado por restaurante,
 * playWaiterBell() y unlockAudio() con la primera interacción. La RLS solo
 * deja llegar los avisos visibles para el restaurante; además se comprueba
 * aquí (visible_restaurante y restaurant_id) por si quien mira es superadmin.
 * Solo con el módulo whatsapp (regla 8).
 *
 * La hora del texto del aviso sale en la zona horaria del restaurante: la lee
 * este componente (GuardRestaurante no la necesita), o llega en zonaHoraria.
 */
export default function AlertasAgente({ restaurantId, zonaHoraria: zonaDada = null }) {
  const { tieneModulo, loading } = useRestaurantModulos(restaurantId)
  const activo = !loading && tieneModulo('whatsapp')
  const [zonaLeida, setZonaLeida] = useState(null)
  const zonaHoraria = zonaDada || zonaHorariaDe({ zona_horaria: zonaLeida })

  useEffect(() => {
    if (!activo || !restaurantId || zonaDada) return
    let cancelado = false
    supabase.from('restaurants').select('zona_horaria').eq('id', restaurantId).single()
      .then(({ data }) => { if (!cancelado) setZonaLeida(data?.zona_horaria || null) })
    return () => { cancelado = true }
  }, [activo, restaurantId, zonaDada])
  const [pendientes, setPendientes] = useState([])
  const [marcando, setMarcando] = useState(null)
  const [error, setError] = useState(null)
  const conocidos = useRef(new Set())
  const navigate = useNavigate()
  const { pathname } = useLocation()

  useEffect(() => {
    const unlock = () => { unlockAudio(); window.removeEventListener('pointerdown', unlock) }
    window.addEventListener('pointerdown', unlock)
    return () => window.removeEventListener('pointerdown', unlock)
  }, [])

  useEffect(() => {
    if (!activo || !restaurantId) { setPendientes([]); return }
    let cancelado = false

    supabase
      .from('agente_errores')
      .select(COLUMNAS_AVISO)
      .eq('restaurant_id', restaurantId)
      .eq('visible_restaurante', true)
      .eq('atendida', false)
      .order('ultima_vez_at', { ascending: false })
      .then(({ data }) => {
        if (cancelado) return
        const filas = data || []
        filas.forEach(a => conocidos.current.add(a.id))
        setPendientes(filas)
      })

    const channel = supabase
      .channel('alertas-agente-' + restaurantId)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'agente_errores',
        filter: `restaurant_id=eq.${restaurantId}`,
      }, (payload) => {
        const fila = payload.new
        if (!esVisibleParaRestaurante(fila, restaurantId)) return
        if (fila.atendida) {
          // Marcada desde otra pestaña o dispositivo.
          setPendientes(prev => prev.filter(a => a.id !== fila.id))
          return
        }
        // Aviso nuevo, o repetición (veces + 1) de uno pendiente: arriba del todo.
        const nuevo = !conocidos.current.has(fila.id)
        conocidos.current.add(fila.id)
        setPendientes(prev => [fila, ...prev.filter(a => a.id !== fila.id)])
        if (nuevo || payload.eventType === 'UPDATE') playWaiterBell()
      })
      .subscribe()

    return () => { cancelado = true; supabase.removeChannel(channel) }
  }, [activo, restaurantId])

  async function marcarAtendida(aviso) {
    setError(null)
    setMarcando(aviso.id)
    const { error: err } = await supabase.rpc('fn_agente_error_marcar_atendida', { p_error_id: aviso.id })
    setMarcando(null)
    if (err) { setError('No se ha podido marcar como atendida. Vuelve a intentarlo.'); return }
    // Regla 9: fuera al momento, sin esperar al eco de Realtime.
    setPendientes(prev => prev.filter(a => a.id !== aviso.id))
  }

  if (!activo || pendientes.length === 0) return null

  const aviso = pendientes[0]
  const tel = telefonoAviso(aviso.telefono_cliente)
  const enSeccion = pathname.startsWith('/admin/avisos-whatsapp/')

  return (
    <>
      {/* Hueco del mismo alto que la banda para que no tape el principio de la página. */}
      <div style={{ height: ALTO }} />
      <div style={S.banda} role="alert">
        <span style={S.icono}>⚠️</span>
        <div style={S.texto}>
          <strong>WhatsApp:</strong> {textoAviso(aviso, zonaHoraria)}
          {aviso.veces > 1 && <span style={S.extra}>(×{aviso.veces})</span>}
          {pendientes.length > 1 && <span style={S.extra}>y {pendientes.length - 1} aviso{pendientes.length - 1 === 1 ? '' : 's'} más</span>}
          {tel && <> · <a href={tel.href} style={S.tel}>Llamar</a></>}
        </div>
        {!enSeccion && (
          <button style={S.btn} onClick={() => navigate(`/admin/avisos-whatsapp/${restaurantId}`)}>Ver</button>
        )}
        <button style={S.btnPrincipal} disabled={marcando === aviso.id} onClick={() => marcarAtendida(aviso)}>
          {marcando === aviso.id ? 'Marcando…' : 'Marcar como atendida'}
        </button>
        {error && <div style={S.error}>{error}</div>}
      </div>
    </>
  )
}
