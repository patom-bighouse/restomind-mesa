import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useRestaurantModulos } from '../lib/modulos'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  navTabs: { display: 'flex', gap: 8, flexWrap: 'wrap' },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  content: { padding: 24, maxWidth: 640, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 6 },
  sectionHint: { fontSize: 12, color: '#7a6a50', marginBottom: 20, lineHeight: 1.5 },
  addBar: { display: 'flex', gap: 12, marginBottom: 24, background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16 },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', flex: 1 },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  pasoRow: { display: 'flex', alignItems: 'center', gap: 10, background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: '10px 14px', marginBottom: 8, opacity: 1 },
  pasoTexto: { flex: 1, fontSize: 14 },
  orderBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 6, width: 26, height: 26, color: '#c4a85a', cursor: 'pointer', fontSize: 13, fontFamily: "'Inter', sans-serif" },
  toggleBtn: (activo) => ({ background: 'transparent', border: `0.5px solid ${activo ? '#27ae60' : '#3a2e20'}`, borderRadius: 8, padding: '5px 10px', fontSize: 11, fontWeight: 500, cursor: 'pointer', color: activo ? '#2ecc71' : '#666', fontFamily: "'Inter', sans-serif" }),
  deleteBtn: { background: 'transparent', border: 'none', color: '#8a5050', fontSize: 12, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'underline' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 40, color: '#555', fontSize: 14 },
}

export default function AdminLimpieza() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [pasos, setPasos] = useState([])
  const [nuevoTexto, setNuevoTexto] = useState('')
  const [adding, setAdding] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('nombre').eq('id', restaurantId).single()
    setRestaurant(rest)
    await loadPasos()
    setLoading(false)
  }

  async function loadPasos() {
    const { data, error: err } = await supabase
      .from('limpieza_pasos')
      .select('id, texto, orden, activo')
      .eq('restaurant_id', restaurantId)
      .order('orden')
    if (err) { setError(err.message); return }
    setPasos(data || [])
  }

  async function addPaso() {
    if (!nuevoTexto.trim()) return
    setError(null)
    setAdding(true)
    const orden = pasos.length > 0 ? Math.max(...pasos.map(p => p.orden)) + 1 : 0
    const { data, error: err } = await supabase
      .from('limpieza_pasos')
      .insert({ restaurant_id: restaurantId, texto: nuevoTexto.trim(), orden })
      .select().single()
    setAdding(false)
    if (err) { setError(err.message); return }
    setPasos(prev => [...prev, data])
    setNuevoTexto('')
  }

  async function toggleActivo(paso) {
    const { error: err } = await supabase.from('limpieza_pasos').update({ activo: !paso.activo }).eq('id', paso.id)
    if (err) { setError(err.message); return }
    setPasos(prev => prev.map(p => p.id === paso.id ? { ...p, activo: !p.activo } : p))
  }

  async function eliminarPaso(paso) {
    if (!window.confirm(`¿Eliminar el paso "${paso.texto}"?`)) return
    const { error: err } = await supabase.from('limpieza_pasos').delete().eq('id', paso.id)
    if (err) { setError(err.message); return }
    setPasos(prev => prev.filter(p => p.id !== paso.id))
  }

  async function moverPaso(paso, direccion) {
    const ordenados = [...pasos].sort((a, b) => a.orden - b.orden)
    const idx = ordenados.findIndex(p => p.id === paso.id)
    const otroIdx = idx + direccion
    if (otroIdx < 0 || otroIdx >= ordenados.length) return
    const otro = ordenados[otroIdx]
    const ordenA = paso.orden, ordenB = otro.orden
    setPasos(prev => prev.map(p => {
      if (p.id === paso.id) return { ...p, orden: ordenB }
      if (p.id === otro.id) return { ...p, orden: ordenA }
      return p
    }))
    await supabase.from('limpieza_pasos').update({ orden: ordenB }).eq('id', paso.id)
    await supabase.from('limpieza_pasos').update({ orden: ordenA }).eq('id', otro.id)
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  const pasosOrdenados = [...pasos].sort((a, b) => a.orden - b.orden)

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.header}>
        <div>
          <div style={S.logo}>Restomind Admin</div>
          <div style={S.restName}>{restaurant?.nombre}</div>
        </div>
        <div style={S.navTabs}>
          {tieneModulo('reportes') && <a href={`/admin/dashboard/${restaurantId}`} style={S.navTab(false)}>Dashboard</a>}
          <a href={`/admin/mesas/${restaurantId}`} style={S.navTab(false)}>Mesas</a>
          <a href={`/admin/carta/${restaurantId}`} style={S.navTab(false)}>Carta</a>
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(false)}>Clientes</a>
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>
          <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(false)}>Reservas</a>
          <a href={`/admin/limpieza/${restaurantId}`} style={S.navTab(true)}>Limpieza</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Checklist de limpieza</div>
        <div style={S.sectionHint}>
          Estos pasos aparecen cuando se cierra una mesa con consumo real — queda marcada "necesita limpieza"
          hasta que se tildan todos, en la Grilla, el Plano, y la pantalla del camarero.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.addBar}>
          <input
            style={S.input}
            placeholder="Ej. Limpiar mesa y sillas"
            value={nuevoTexto}
            onChange={e => setNuevoTexto(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && addPaso()}
          />
          <button style={S.addBtn} onClick={addPaso} disabled={adding}>
            {adding ? 'Añadiendo...' : '+ Añadir paso'}
          </button>
        </div>

        {pasosOrdenados.length === 0 ? (
          <div style={S.empty}>Todavía no configuraste ningún paso.</div>
        ) : (
          pasosOrdenados.map((paso, idx) => (
            <div key={paso.id} style={{ ...S.pasoRow, opacity: paso.activo ? 1 : 0.5 }}>
              <button style={S.orderBtn} onClick={() => moverPaso(paso, -1)} disabled={idx === 0}>↑</button>
              <button style={S.orderBtn} onClick={() => moverPaso(paso, 1)} disabled={idx === pasosOrdenados.length - 1}>↓</button>
              <span style={S.pasoTexto}>{paso.texto}</span>
              <button style={S.toggleBtn(paso.activo)} onClick={() => toggleActivo(paso)}>
                {paso.activo ? 'Activo' : 'Inactivo'}
              </button>
              <button style={S.deleteBtn} onClick={() => eliminarPaso(paso)}>Eliminar</button>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
