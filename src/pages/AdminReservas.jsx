import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useRestaurantModulos } from '../lib/modulos'

const ZONAS = ['sin preferencia', 'interior', 'terraza', 'privado', 'barra']

const ESTADO_CFG = {
  pendiente: { label: 'Pendiente', color: '#e8b84a', bg: '#2a2010' },
  confirmada: { label: 'Confirmada', color: '#2ecc71', bg: '#0f2a15' },
  cancelada: { label: 'Cancelada', color: '#8a7560', bg: '#1a1a1a' },
  noshow: { label: 'No vino', color: '#e74c3c', bg: '#2a1410' },
}

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
  linkBox: { display: 'flex', gap: 10, alignItems: 'center', background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 14, marginBottom: 28, flexWrap: 'wrap' },
  linkText: { flex: 1, minWidth: 200, fontSize: 13, color: '#c4a85a', fontFamily: 'monospace', wordBreak: 'break-all' },
  copyBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 8, padding: '8px 16px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  addBar: { display: 'flex', gap: 12, marginBottom: 28, flexWrap: 'wrap', alignItems: 'flex-end', background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16 },
  field: { display: 'flex', flexDirection: 'column', gap: 4 },
  label: { fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em' },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  select: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  filterBar: { display: 'flex', gap: 10, marginBottom: 20, flexWrap: 'wrap', alignItems: 'center' },
  filterBtn: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 20, padding: '6px 14px', fontSize: 12, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }),
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 12px 10px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '12px', fontSize: 13, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  row: { background: '#1a1a1a' },
  badge: (estado) => ({ fontSize: 11, fontWeight: 500, padding: '4px 10px', borderRadius: 20, background: ESTADO_CFG[estado]?.bg, color: ESTADO_CFG[estado]?.color, border: `0.5px solid ${ESTADO_CFG[estado]?.color}` }),
  estadoSelect: (estado) => ({ fontSize: 12, fontWeight: 500, padding: '5px 8px', borderRadius: 8, background: ESTADO_CFG[estado]?.bg, color: ESTADO_CFG[estado]?.color, border: `0.5px solid ${ESTADO_CFG[estado]?.color}`, cursor: 'pointer', fontFamily: "'Inter', sans-serif", outline: 'none' }),
  actionBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '5px 10px', fontSize: 11, cursor: 'pointer', fontFamily: "'Inter', sans-serif", marginRight: 6 },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 60, color: '#555', fontSize: 14 },
}

const BASE_URL = window.location.origin

export default function AdminReservas() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [reservas, setReservas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [filtro, setFiltro] = useState('proximas') // 'proximas' | 'todas' | estado key
  const [copiado, setCopiado] = useState(false)
  const [adding, setAdding] = useState(false)

  const [nombre, setNombre] = useState('')
  const [telefono, setTelefono] = useState('')
  const [fecha, setFecha] = useState('')
  const [hora, setHora] = useState('')
  const [personas, setPersonas] = useState('2')
  const [zona, setZona] = useState('sin preferencia')
  const [notas, setNotas] = useState('')

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('nombre').eq('id', restaurantId).single()
    setRestaurant(rest)
    await loadReservas()
    setLoading(false)
  }

  async function loadReservas() {
    const { data, error: err } = await supabase
      .from('reservations')
      .select('id, nombre, telefono, fecha, hora, personas, zona, notas, estado, origen, created_at')
      .eq('restaurant_id', restaurantId)
      .order('fecha', { ascending: true })
      .order('hora', { ascending: true })
    if (err) { setError(err.message); return }
    setReservas(data || [])
  }

  // Realtime: refresca la lista cuando llega una reserva nueva desde
  // el widget público, o cuando cambia el estado de alguna (incluso
  // si se editó desde otra pestaña/dispositivo).
  useEffect(() => {
    if (!restaurantId) return
    const channel = supabase
      .channel('admin-reservas-' + restaurantId)
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'reservations',
        filter: `restaurant_id=eq.${restaurantId}`
      }, () => loadReservas())
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [restaurantId])

  const hoy = new Date().toISOString().slice(0, 10)
  const reservasFiltradas = reservas.filter(r => {
    if (filtro === 'proximas') return r.fecha >= hoy && r.estado !== 'cancelada'
    if (filtro === 'todas') return true
    return r.estado === filtro
  })

  function copiarLink() {
    const url = `${BASE_URL}/reservar/${restaurantId}`
    navigator.clipboard.writeText(url)
    setCopiado(true)
    setTimeout(() => setCopiado(false), 2000)
  }

  async function cambiarEstado(reserva, nuevoEstado) {
    const { error: err } = await supabase.from('reservations').update({ estado: nuevoEstado }).eq('id', reserva.id)
    if (err) { setError(err.message); return }
    setReservas(prev => prev.map(r => r.id === reserva.id ? { ...r, estado: nuevoEstado } : r))
  }

  async function eliminarReserva(reserva) {
    if (!window.confirm(`¿Eliminar la reserva de ${reserva.nombre}?`)) return
    const { error: err } = await supabase.from('reservations').delete().eq('id', reserva.id)
    if (err) { setError(err.message); return }
    setReservas(prev => prev.filter(r => r.id !== reserva.id))
  }

  async function addReservaManual() {
    if (!nombre.trim() || !telefono.trim() || !fecha || !hora || !personas) return
    setError(null)
    setAdding(true)
    const { data, error: err } = await supabase
      .from('reservations')
      .insert({
        restaurant_id: restaurantId,
        nombre: nombre.trim(),
        telefono: telefono.trim(),
        fecha,
        hora,
        personas: parseInt(personas, 10),
        zona,
        notas: notas.trim() || null,
        estado: 'confirmada',
        origen: 'manual',
      })
      .select('id, nombre, telefono, fecha, hora, personas, zona, notas, estado, origen, created_at')
      .single()
    setAdding(false)
    if (err) { setError(err.message); return }
    setReservas(prev => [...prev, data].sort((a, b) => (a.fecha + a.hora).localeCompare(b.fecha + b.hora)))
    setNombre(''); setTelefono(''); setFecha(''); setHora(''); setPersonas('2'); setZona('sin preferencia'); setNotas('')
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

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
          <a href={`/admin/menus/${restaurantId}`} style={S.navTab(false)}>Menús</a>
          {tieneModulo('control_stock') && <a href={`/admin/stock/${restaurantId}`} style={S.navTab(false)}>Stock</a>}
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(false)}>Clientes</a>
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>
          <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(true)}>Reservas</a>
          <a href={`/admin/limpieza/${restaurantId}`} style={S.navTab(false)}>Limpieza</a>
          <a href={`/admin/fidelizacion/${restaurantId}`} style={S.navTab(false)}>Fidelización</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Reservas</div>
        <div style={S.sectionHint}>
          Comparte este link para que tus clientes reserven mesa por su cuenta — en tu Instagram, Google Maps,
          WhatsApp, o embebido en tu propia web. Las que llegan por acá quedan "Pendiente" hasta que las confirmes.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.linkBox}>
          <span style={S.linkText}>{BASE_URL}/reservar/{restaurantId}</span>
          <button style={S.copyBtn} onClick={copiarLink}>{copiado ? '✓ Copiado' : 'Copiar link'}</button>
        </div>

        <div style={S.addBar}>
          <div style={S.field}>
            <span style={S.label}>Nombre</span>
            <input style={S.input} value={nombre} onChange={e => setNombre(e.target.value)} placeholder="Cliente" />
          </div>
          <div style={S.field}>
            <span style={S.label}>Teléfono</span>
            <input style={S.input} value={telefono} onChange={e => setTelefono(e.target.value)} placeholder="+34 6..." />
          </div>
          <div style={S.field}>
            <span style={S.label}>Fecha</span>
            <input style={S.input} type="date" value={fecha} min={hoy} onChange={e => setFecha(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Hora</span>
            <input style={S.input} type="time" value={hora} onChange={e => setHora(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Personas</span>
            <input style={{ ...S.input, width: 70 }} type="number" min="1" value={personas} onChange={e => setPersonas(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Zona</span>
            <select style={S.select} value={zona} onChange={e => setZona(e.target.value)}>
              {ZONAS.map(z => <option key={z} value={z}>{z.charAt(0).toUpperCase() + z.slice(1)}</option>)}
            </select>
          </div>
          <div style={{ ...S.field, flex: 1 }}>
            <span style={S.label}>Nota (opcional)</span>
            <input style={S.input} value={notas} onChange={e => setNotas(e.target.value)} placeholder="Ej. cumpleaños" />
          </div>
          <button style={S.addBtn} onClick={addReservaManual} disabled={adding}>
            {adding ? 'Añadiendo...' : '+ Cargar reserva'}
          </button>
        </div>

        <div style={S.filterBar}>
          <button style={S.filterBtn(filtro === 'proximas')} onClick={() => setFiltro('proximas')}>Próximas</button>
          <button style={S.filterBtn(filtro === 'todas')} onClick={() => setFiltro('todas')}>Todas</button>
          {Object.entries(ESTADO_CFG).map(([key, cfg]) => (
            <button key={key} style={S.filterBtn(filtro === key)} onClick={() => setFiltro(key)}>{cfg.label}</button>
          ))}
        </div>

        {reservasFiltradas.length === 0 ? (
          <div style={S.empty}>No hay reservas para este filtro.</div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={S.table}>
              <thead>
                <tr>
                  <th style={S.th}>Fecha</th>
                  <th style={S.th}>Hora</th>
                  <th style={S.th}>Cliente</th>
                  <th style={S.th}>Personas</th>
                  <th style={S.th}>Zona</th>
                  <th style={S.th}>Origen</th>
                  <th style={S.th}>Estado</th>
                  <th style={S.th}></th>
                </tr>
              </thead>
              <tbody>
                {reservasFiltradas.map(r => (
                  <tr key={r.id} style={S.row}>
                    <td style={S.td}>{new Date(r.fecha + 'T00:00:00').toLocaleDateString('es-ES')}</td>
                    <td style={S.td}>{r.hora?.slice(0, 5)}</td>
                    <td style={S.td}>
                      {r.nombre}
                      <div style={{ fontSize: 11, color: '#7a6a50' }}>{r.telefono}</div>
                      {r.notas && <div style={{ fontSize: 11, color: '#7a6a50', fontStyle: 'italic' }}>{r.notas}</div>}
                    </td>
                    <td style={S.td}>{r.personas}</td>
                    <td style={S.td}>{r.zona}</td>
                    <td style={S.td}>{r.origen}</td>
                    <td style={S.td}>
                      <select style={S.estadoSelect(r.estado)} value={r.estado} onChange={e => cambiarEstado(r, e.target.value)}>
                        {Object.entries(ESTADO_CFG).map(([key, cfg]) => (
                          <option key={key} value={key}>{cfg.label}</option>
                        ))}
                      </select>
                    </td>
                    <td style={S.td}>
                      <button style={{ ...S.actionBtn, color: '#8a5050', marginRight: 0 }} onClick={() => eliminarReserva(r)}>Eliminar</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
