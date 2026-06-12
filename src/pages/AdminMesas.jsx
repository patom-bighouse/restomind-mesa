import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import QRCode from 'qrcode'

const BASE_URL = 'https://restomind-mesa.vercel.app'
const ZONAS = ['interior', 'terraza', 'privado', 'barra']

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 24, maxWidth: 960, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 20 },
  addBar: { display: 'flex', gap: 12, marginBottom: 36, flexWrap: 'wrap', background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16 },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', width: 100 },
  select: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  zonaSection: { marginBottom: 36 },
  zonaHeader: { fontSize: 12, fontWeight: 500, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 14, paddingBottom: 10, borderBottom: '0.5px solid #2a2a2a', display: 'flex', alignItems: 'center', gap: 8 },
  zonaCount: { background: '#2a2a2a', color: '#8a7560', fontSize: 11, padding: '2px 8px', borderRadius: 10 },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 14 },
  card: (activa) => ({ background: activa ? '#1a1a1a' : '#141414', border: `0.5px solid ${activa ? '#3a2e20' : '#222'}`, borderRadius: 14, padding: 18, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, opacity: activa ? 1 : 0.5 }),
  mesaTitle: { fontSize: 15, fontWeight: 500, color: '#f0e8d8' },
  mesaCap: { fontSize: 12, color: '#7a6a50', marginTop: -6 },
  qrWrap: { background: '#fff', borderRadius: 10, padding: 8 },
  tokenText: { fontSize: 10, color: '#444', fontFamily: 'monospace', textAlign: 'center', wordBreak: 'break-all' },
  btnRow: { display: 'flex', gap: 8, width: '100%' },
  dlBtn: { flex: 1, background: '#e8c97a', color: '#111', border: 'none', borderRadius: 8, padding: '8px 0', fontSize: 12, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  toggleBtn: (activa) => ({ flex: 1, background: 'transparent', border: `0.5px solid ${activa ? '#c0392b' : '#27ae60'}`, borderRadius: 8, padding: '8px 0', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: activa ? '#e74c3c' : '#2ecc71', fontFamily: "'Inter', sans-serif" }),
  deleteBtn: { width: '100%', background: 'transparent', border: '0.5px solid #2a1a1a', borderRadius: 8, padding: '7px 0', fontSize: 12, color: '#6a4040', cursor: 'pointer', fontFamily: "'Inter', sans-serif' " },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  statsBar: { display: 'flex', gap: 12, marginBottom: 28, flexWrap: 'wrap' },
  statCard: (color) => ({ background: '#1a1a1a', border: `1px solid ${color}`, borderRadius: 12, padding: '14px 20px', display: 'flex', flexDirection: 'column', gap: 4, minWidth: 120 }),
  statNum: (color) => ({ fontSize: 28, fontWeight: 600, color: color, fontFamily: "'Playfair Display', serif", lineHeight: 1 }),
  statLabel: { fontSize: 12, color: '#7a6a50' },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
}

export default function AdminMesas() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const [restaurant, setRestaurant] = useState(null)
  const [tables, setTables] = useState([])
  const [qrUrls, setQrUrls] = useState({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [newNumero, setNewNumero] = useState('')
  const [newZona, setNewZona] = useState('interior')
  const [newCapacidad, setNewCapacidad] = useState('4')
  const [adding, setAdding] = useState(false)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    loadData()
  }

  async function loadData() {
    const { data: rest } = await supabase.from('restaurants').select('nombre').eq('id', restaurantId).single()
    setRestaurant(rest)
    const { data: tabs, error: err } = await supabase
      .from('tables').select('id, numero, zona, capacidad, qr_token, activa')
      .eq('restaurant_id', restaurantId).order('numero')
    if (err) { setError(err.message); setLoading(false); return }
    setTables(tabs || [])
    generateQRs(tabs || [])
    setLoading(false)
  }

  async function generateQRs(tabs) {
    const urls = {}
    for (const t of tabs) {
      const url = `${BASE_URL}/mesa/${t.qr_token}`
      urls[t.id] = await QRCode.toDataURL(url, { width: 150, margin: 1, color: { dark: '#000', light: '#fff' } })
    }
    setQrUrls(urls)
  }

  async function addTable() {
    if (!newNumero) return
    const duplicate = tables.find(t => t.numero === parseInt(newNumero) && t.zona === newZona)
    if (duplicate) { setError(`Ya existe la Mesa ${newNumero} en ${newZona}.`); return }
    setError(null)
    setAdding(true)
    const { data, error: err } = await supabase
      .from('tables')
      .insert({ restaurant_id: restaurantId, numero: parseInt(newNumero), zona: newZona, capacidad: parseInt(newCapacidad) })
      .select().single()
    if (err) { setError(err.message); setAdding(false); return }
    const url = `${BASE_URL}/mesa/${data.qr_token}`
    const qr = await QRCode.toDataURL(url, { width: 150, margin: 1, color: { dark: '#000', light: '#fff' } })
    setTables(prev => [...prev, data].sort((a, b) => a.numero - b.numero))
    setQrUrls(prev => ({ ...prev, [data.id]: qr }))
    setNewNumero('')
    setAdding(false)
  }

  async function toggleTable(table) {
    const newActiva = !table.activa
    const { error: err } = await supabase
      .from('tables')
      .update({ activa: newActiva })
      .eq('id', table.id)
    if (err) { setError(err.message); return }
    setTables(prev => prev.map(t => t.id === table.id ? { ...t, activa: newActiva } : t))
  }

  async function deleteTable(table) {
    const { data: activeOrders } = await supabase
      .from('orders').select('id').eq('table_id', table.id).in('estado', ['pendiente', 'preparando', 'listo'])
    if (activeOrders && activeOrders.length > 0) {
      setError(`La Mesa ${table.numero} tiene pedidos activos. Espera a que se completen antes de eliminarla.`)
      return
    }
    if (!window.confirm(`¿Eliminar Mesa ${table.numero} · ${table.zona}? Esta acción no se puede deshacer.`)) return
    const { error: err } = await supabase.from('tables').delete().eq('id', table.id)
    if (err) { setError(err.message); return }
    setTables(prev => prev.filter(t => t.id !== table.id))
    setQrUrls(prev => { const next = { ...prev }; delete next[table.id]; return next })
  }

  function downloadQR(table) {
    const url = qrUrls[table.id]
    if (!url) return
    const a = document.createElement('a')
    a.href = url
    a.download = `qr-mesa-${table.numero}-${table.zona}.png`
    a.click()
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
        <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Gestión de mesas</div>
        {error && <div style={S.error}>{error}</div>}

        {/* Añadir mesa */}
        <div style={S.addBar}>
          <input style={S.input} type="number" placeholder="Nº mesa" value={newNumero} onChange={e => setNewNumero(e.target.value)} min="1" />
          <select style={S.select} value={newZona} onChange={e => setNewZona(e.target.value)}>
            {ZONAS.map(z => <option key={z} value={z}>{z.charAt(0).toUpperCase() + z.slice(1)}</option>)}
          </select>
          <input style={{ ...S.input, width: 80 }} type="number" placeholder="Cap." value={newCapacidad} onChange={e => setNewCapacidad(e.target.value)} min="1" max="20" />
          <button style={S.addBtn} onClick={addTable} disabled={adding}>
            {adding ? 'Añadiendo...' : '+ Añadir mesa'}
          </button>
        </div>

        {/* Stats bar */}
        <div style={S.statsBar}>
          <div style={S.statCard('#e8c97a')}>
            <div style={S.statNum('#e8c97a')}>{tables.length}</div>
            <div style={S.statLabel}>Total mesas</div>
          </div>
          <div style={S.statCard('#2ecc71')}>
            <div style={S.statNum('#2ecc71')}>{tables.filter(t => t.activa).length}</div>
            <div style={S.statLabel}>Activas</div>
          </div>
          <div style={S.statCard('#e74c3c')}>
            <div style={S.statNum('#e74c3c')}>{tables.filter(t => !t.activa).length}</div>
            <div style={S.statLabel}>Desactivadas</div>
          </div>
          {ZONAS.filter(z => tables.some(t => t.zona === z)).map(zona => (
            <div key={zona} style={S.statCard('#3a2e20')}>
              <div style={S.statNum('#c4a85a')}>{tables.filter(t => t.zona === zona).length}</div>
              <div style={S.statLabel}>{zona.charAt(0).toUpperCase() + zona.slice(1)}</div>
            </div>
          ))}
        </div>

        {/* Mesas agrupadas por zona */}
        {ZONAS.map(zona => {
          const zonaTablas = tables.filter(t => t.zona === zona).sort((a, b) => a.numero - b.numero)
          if (!zonaTablas.length) return null
          return (
            <div key={zona} style={S.zonaSection}>
              <div style={S.zonaHeader}>
                {zona.charAt(0).toUpperCase() + zona.slice(1)}
                <span style={S.zonaCount}>{zonaTablas.length} {zonaTablas.length === 1 ? 'mesa' : 'mesas'}</span>
              </div>
              <div style={S.grid}>
                {zonaTablas.map(table => (
                  <div key={table.id} style={S.card(table.activa)}>
                    <div style={S.mesaTitle}>Mesa {table.numero}</div>
                    <div style={S.mesaCap}>{table.capacidad} personas</div>
                    {qrUrls[table.id] && (
                      <div style={S.qrWrap}>
                        <img src={qrUrls[table.id]} alt={`QR Mesa ${table.numero}`} width={130} height={130} />
                      </div>
                    )}
                    <div style={S.tokenText}>{`/mesa/${table.qr_token.slice(0, 16)}...`}</div>
                    <div style={S.btnRow}>
                      <button style={S.dlBtn} onClick={() => downloadQR(table)}>⬇ QR</button>
                      <button style={S.toggleBtn(table.activa)} onClick={() => toggleTable(table)}>
                        {table.activa ? 'Desactivar' : 'Activar'}
                      </button>
                    </div>
                    <button style={S.deleteBtn} onClick={() => deleteTable(table)}>Eliminar mesa</button>
                  </div>
                ))}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
