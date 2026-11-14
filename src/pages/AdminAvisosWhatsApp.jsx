import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useRestaurantModulos } from '../lib/modulos'
import { ZONA_POR_DEFECTO, fechaHoraEnZona } from '../lib/fechas'
import { COLUMNAS_AVISO, DIAS_ATENDIDAS, TIPOS_AVISO, desdeAtendidas, esVisibleParaRestaurante, telefonoAviso, textoAviso } from '../lib/avisosAgente'

// Sección "Avisos de WhatsApp" del panel del restaurante (entrega 1b,
// docs/specs/2026-11-13-agente-whatsapp-revision.md): pendientes arriba y,
// debajo, las atendidas de los últimos 30 días (decisión 13). Solo con el
// módulo whatsapp (decisión 10). La hora es la del restaurante: hoy España,
// pasada como parámetro (regla 7).
const ZONA = ZONA_POR_DEFECTO

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10, flexWrap: 'wrap', gap: 12 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  navTabs: { display: 'flex', gap: 8, flexWrap: 'wrap' },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  content: { padding: 24, maxWidth: 960, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 6 },
  sectionHint: { fontSize: 12, color: '#7a6a50', marginBottom: 20, lineHeight: 1.5 },
  subTitle: { fontSize: 13, color: '#c4a85a', textTransform: 'uppercase', letterSpacing: '0.06em', margin: '28px 0 10px' },
  card: (pendiente) => ({ background: pendiente ? '#2a1410' : '#1a1a1a', border: `0.5px solid ${pendiente ? '#6a2e20' : '#2a2a2a'}`, borderRadius: 12, padding: 14, marginBottom: 10, display: 'flex', gap: 12, alignItems: 'flex-start', flexWrap: 'wrap' }),
  cardBody: { flex: '1 1 320px' },
  texto: { fontSize: 14, lineHeight: 1.5, color: '#f0e8d8' },
  meta: { fontSize: 12, color: '#8a7560', marginTop: 6, display: 'flex', gap: 12, flexWrap: 'wrap' },
  tel: { color: '#e8c97a', textDecoration: 'none', fontWeight: 500 },
  veces: { fontSize: 12, color: '#e8a090', marginLeft: 6 },
  badge: { fontSize: 11, padding: '2px 8px', borderRadius: 20, border: '0.5px solid #3a2e20', color: '#c4a85a' },
  btn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 8, padding: '8px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", whiteSpace: 'nowrap' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { padding: '18px 14px', color: '#666', fontSize: 13, background: '#161616', borderRadius: 12, border: '0.5px dashed #2a2a2a' },
}

export default function AdminAvisosWhatsApp() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo, loading: modulosLoading } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [usuarioId, setUsuarioId] = useState(null)
  const [avisos, setAvisos] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [marcando, setMarcando] = useState(null)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    setUsuarioId(session.user.id)
    const { data: rest } = await supabase.from('restaurants').select('nombre, user_id').eq('id', restaurantId).single()
    setRestaurant(rest)
    setLoading(false)
  }

  // Los avisos solo se leen si el restaurante tiene el módulo whatsapp.
  useEffect(() => {
    if (!restaurantId || modulosLoading || !tieneModulo('whatsapp')) return
    loadAvisos()
  }, [restaurantId, modulosLoading])

  // Pendientes (todas) + atendidas de los últimos 30 días. Solo las visibles
  // para el restaurante (la RLS ya lo limita; el filtro sirve si entra el superadmin).
  async function loadAvisos() {
    const [pend, aten] = await Promise.all([
      supabase.from('agente_errores').select(COLUMNAS_AVISO)
        .eq('restaurant_id', restaurantId).eq('visible_restaurante', true).eq('atendida', false)
        .order('ultima_vez_at', { ascending: false }),
      supabase.from('agente_errores').select(COLUMNAS_AVISO)
        .eq('restaurant_id', restaurantId).eq('visible_restaurante', true).eq('atendida', true)
        .gte('atendida_at', desdeAtendidas())
        .order('atendida_at', { ascending: false }),
    ])
    const err = pend.error || aten.error
    if (err) { setError(err.message); return }
    setAvisos([...(pend.data || []), ...(aten.data || [])])
  }

  // Realtime: avisos nuevos, repeticiones y los marcados desde otra pantalla.
  useEffect(() => {
    if (!restaurantId || modulosLoading || !tieneModulo('whatsapp')) return
    const channel = supabase
      .channel('admin-avisos-whatsapp-' + restaurantId)
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'agente_errores',
        filter: `restaurant_id=eq.${restaurantId}`,
      }, (payload) => {
        const fila = payload.new
        if (!esVisibleParaRestaurante(fila, restaurantId)) return
        setAvisos(prev => [fila, ...prev.filter(a => a.id !== fila.id)])
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [restaurantId, modulosLoading])

  async function marcarAtendida(aviso) {
    setError(null)
    setMarcando(aviso.id)
    const { data, error: err } = await supabase.rpc('fn_agente_error_marcar_atendida', { p_error_id: aviso.id })
    setMarcando(null)
    if (err) { setError('No se ha podido marcar como atendida: ' + err.message); return }
    // Regla 9: estado local al momento con la fila que devuelve la función.
    const fila = data && data.id ? data : { ...aviso, atendida: true, atendida_por: usuarioId, atendida_at: new Date().toISOString() }
    setAvisos(prev => prev.map(a => a.id === aviso.id ? { ...a, ...fila } : a))
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  function quienMarco(aviso) {
    if (!aviso.atendida_por) return 'alguien'
    if (aviso.atendida_por === usuarioId) return 'ti'
    if (restaurant?.user_id && aviso.atendida_por === restaurant.user_id) return 'el dueño'
    return 'el equipo de Restomind'
  }

  const header = (activa) => (
    <div style={S.header}>
      <div>
        <div style={S.logo}><img src="/logos/opcion-2-monograma/icon-dark.svg" alt="" style={{ height: 22, verticalAlign: 'middle', marginRight: 8 }} />Restomind Admin</div>
        <div style={S.restName}>{restaurant?.nombre}</div>
      </div>
      {activa ? (
        <div style={S.navTabs}>
          {tieneModulo('reportes') && <a href={`/admin/dashboard/${restaurantId}`} style={S.navTab(false)}>Dashboard</a>}
          <a href={`/admin/mesas/${restaurantId}`} style={S.navTab(false)}>Mesas</a>
          {tieneModulo('reservas') && <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(false)}>Reservas</a>}
          <a href={`/admin/carta/${restaurantId}`} style={S.navTab(false)}>Carta</a>
          {tieneModulo('multi_menu') && <a href={`/admin/menus/${restaurantId}`} style={S.navTab(false)}>Menús</a>}
          {tieneModulo('marketing_fidelizacion') && <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>}
          {tieneModulo('control_stock') && <a href={`/admin/stock/${restaurantId}`} style={S.navTab(false)}>Stock</a>}
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(false)}>Clientes</a>
          {tieneModulo('marketing_fidelizacion') && <a href={`/admin/fidelizacion/${restaurantId}`} style={S.navTab(false)}>Fidelización</a>}
          {tieneModulo('marketing_fidelizacion') && <a href={`/admin/vales/${restaurantId}`} style={S.navTab(false)}>Vales</a>}
          <a href={`/admin/limpieza/${restaurantId}`} style={S.navTab(false)}>Limpieza</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          {tieneModulo('webhooks') && <a href={`/admin/webhooks/${restaurantId}`} style={S.navTab(false)}>Webhooks</a>}
          <a href={`/admin/avisos-whatsapp/${restaurantId}`} style={S.navTab(true)}>Avisos WhatsApp</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      ) : (
        <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
      )}
    </div>
  )

  if (loading || modulosLoading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  if (!tieneModulo('whatsapp')) {
    return (
      <div style={S.app}>
        {header(false)}
        <div style={S.content}>
          <div style={S.sectionTitle}>Avisos de WhatsApp</div>
          <div style={S.sectionHint}>Este restaurante no tiene activo el módulo del agente de WhatsApp.</div>
        </div>
      </div>
    )
  }

  const ms = (t) => (t ? new Date(t).getTime() : 0)
  const pendientes = avisos.filter(a => !a.atendida)
    .sort((a, b) => ms(b.ultima_vez_at) - ms(a.ultima_vez_at))
  const limite = ms(desdeAtendidas())
  const atendidas = avisos.filter(a => a.atendida && ms(a.atendida_at) >= limite)
    .sort((a, b) => ms(b.atendida_at) - ms(a.atendida_at))

  const tarjeta = (a) => {
    const tel = telefonoAviso(a.telefono_cliente)
    return (
      <div key={a.id} style={S.card(!a.atendida)}>
        <div style={S.cardBody}>
          <div style={S.texto}>
            {textoAviso(a, ZONA)}
            {a.veces > 1 && <span style={S.veces}>(×{a.veces})</span>}
          </div>
          <div style={S.meta}>
            <span style={S.badge}>{TIPOS_AVISO[a.tipo]?.etiqueta || a.tipo}</span>
            <span>{fechaHoraEnZona(a.created_at, ZONA)}{a.veces > 1 ? ` · última vez ${fechaHoraEnZona(a.ultima_vez_at, ZONA)}` : ''}</span>
            {tel ? <a href={tel.href} style={S.tel}>📞 {tel.texto}</a> : <span>Sin teléfono</span>}
            {a.atendida && <span>Atendida por {quienMarco(a)} el {fechaHoraEnZona(a.atendida_at, ZONA)}</span>}
          </div>
        </div>
        {!a.atendida && (
          <button style={S.btn} disabled={marcando === a.id} onClick={() => marcarAtendida(a)}>
            {marcando === a.id ? 'Marcando…' : 'Marcar como atendida'}
          </button>
        )}
      </div>
    )
  }

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      {header(true)}
      <div style={S.content}>
        <div style={S.sectionTitle}>Avisos de WhatsApp</div>
        <div style={S.sectionHint}>
          Aquí aparecen los clientes a los que el agente de WhatsApp no ha podido atender: llámales y marca el aviso como
          atendido. Las horas son las del restaurante. Los avisos atendidos se ven durante {DIAS_ATENDIDAS} días.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.subTitle}>Pendientes ({pendientes.length})</div>
        {pendientes.length === 0
          ? <div style={S.empty}>No hay avisos pendientes.</div>
          : pendientes.map(tarjeta)}

        <div style={S.subTitle}>Atendidos en los últimos {DIAS_ATENDIDAS} días ({atendidas.length})</div>
        {atendidas.length === 0
          ? <div style={S.empty}>No hay avisos atendidos en los últimos {DIAS_ATENDIDAS} días.</div>
          : atendidas.map(tarjeta)}
      </div>
    </div>
  )
}
