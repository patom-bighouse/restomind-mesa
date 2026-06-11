import { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import QRCode from 'qrcode'

const BASE_URL = 'https://restomind-mesa.vercel.app'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 24, maxWidth: 900, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 16 },
  addBar: { display: 'flex', gap: 12, marginBottom: 28, flexWrap: 'wrap' },
  input: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', width: 100 },
  select: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 16 },
  card: (activa) => ({ background: activa ? '#1a1a1a' : '#141414', border: `0.5px solid ${activa ? '#3a2e20' : '#2a2a2a'}`, borderRadius: 14, padding: 20, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12, opacity: activa ? 1 : 0.5 }),
  mesaTitle: { fontSize: 15, fontWeight: 500, color: '#f0e8d8' },
  mesaZona: { fontSize: 12, color: '#7a6a50', marginTop: -8 },
  qrWrap: { background: '#fff', borderRadius: 10, padding: 10 },
  tokenText: { fontSize: 10, color: '#555', fontFamily: 'monospace', textAlign: 'center', wordBreak: 'break-all' },
  btnRow: { display: 'flex', gap: 8, width: '100%' },
  dlBtn: { flex: 1, background: '#e8c97a', color: '#111', border: 'none', borderRadius: 8, padding: '8px 0', fontSize: 12, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  toggleBtn: (activa) => ({ flex: 1, background: 'transparent', border: `0.5px solid ${activa ? '#c0392b' : '#27ae60'}`, borderRadius: 8, padding: '8px 0', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: activa ? '#e74c3c' : '#2ecc71', fontFamily: "'Inter', sans-serif" }),
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
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

  useEffect(() => {
    checkAuth()
  }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    loadData()
  }

  async function loadData() {
    const { data: rest } = await supabase.from('restaurants').select('nombre').eq('id', restaurantId).single()
    setRestaurant(rest)
    const { data: tabs, error: err } = await supabase
      .from('tables')
      .select('id, numero, zona, capacidad, qr_token, activa')
      .eq('restaurant_id', restaurantId)
      .order('numero')
    if (err) { setError(err.message); setLoading(false); return }
    setTables(tabs || [])
    generateQRs(tabs || [])
    setLoading(false)
  }

  async function generateQRs(tabs) {
    const urls = {}
    for (const t of tabs) {
      const url = `${BASE_URL}/mesa/${t.qr_token}`
      urls[t.id] = await QRCode.toDataURL(url, { width: 160, margin: 1, color: { dark: '#000', light: '#fff' } })
    }
    setQrUrls(urls)
  }

  async function addTable() {
    if (!newNumero) return
    // Validar que no existe ya esa mesa en esa zona
    const duplicate = tables.find(t => t.numero === parseInt(newNumero) && t.zona === newZona)
    if (duplicate) { setError(`Ya existe la Mesa ${newNumero} en ${newZona}.`); return }
    setError(null)
    setAdding(true)
    const { data, error: err } = await supabase
      .from('tables')
      .insert({ restaurant_id: restaurantId, numero: parseInt(newNumero), zona: newZona, capacidad: parseInt(newCapacidad) })
      .select()
      .single()
    if (err) { setError(err.message); setAdding(false); return }
    const url = `${BASE_URL}/mesa/${data.qr_token}`
    const qr = await QRCode.toDataURL(url, { width: 160, margin: 1, color: { dark: '#000', light: '#fff' } })
    setTables(prev => [...prev, data].sort((a, b) => a.numero - b.numero))
    setQrUrls(prev => ({ ...prev, [data.id]: qr }))
    setNewNumero('')
    setAdding(false)
  }

  async function toggleTable(table) {
    const { error: err } = await supabase.from('tables').update({ activa: !table.activa }).eq('id', table.id)
    if (err) { setError(err.message); return }
    setTables(prev => prev.map(t => t.id === table.id ? { ...t, activa: !t.activa } : t))
  }

  async function deleteTable(table) {
    // Check no active orders
    const { data: activeOrders } = await supabase
      .from('orders')
      .select('id')
      .eq('table_id', table.id)
      .in('estado', ['pendiente', 'preparando', 'listo'])
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

        <div style={S.addBar}>
          <input
            style={S.input}
            type="number"
            placeholder="Nº mesa"
            value={newNumero}
            onChange={e => setNewNumero(e.target.value)}
            min="1"
          />
          <select style={S.select} value={newZona} onChange={e => setNewZona(e.target.value)}>
            <option value="interior">Interior</option>
            <option value="terraza">Terraza</option>
            <option value="privado">Privado</option>
            <option value="barra">Barra</option>
          </select>
          <input
            style={{ ...S.input, width: 80 }}
            type="number"
            placeholder="Cap."
            value={newCapacidad}
            onChange={e => setNewCapacidad(e.target.value)}
            min="1"
            max="20"
          />
          <button style={S.addBtn} onClick={addTable} disabled={adding}>
            {adding ? 'Añadiendo...' : '+ Añadir mesa'}
          </button>
        </div>

        <div style={S.grid}>
          {tables.map(table => (
            <div key={table.id} style={S.card(table.activa)}>
              <div style={S.mesaTitle}>Mesa {table.numero} · {table.capacidad} personas</div>
              <div style={S.mesaZona}>{table.zona.charAt(0).toUpperCase() + table.zona.slice(1)}</div>
              {qrUrls[table.id] && (
                <div style={S.qrWrap}>
                  <img src={qrUrls[table.id]} alt={`QR Mesa ${table.numero}`} width={140} height={140} />
                </div>
              )}
              <div style={S.tokenText}>{`/mesa/${table.qr_token.slice(0, 18)}...`}</div>
              <div style={S.btnRow}>
                <button style={S.dlBtn} onClick={() => downloadQR(table)}>⬇ Descargar QR</button>
                <button style={S.toggleBtn(table.activa)} onClick={() => toggleTable(table)}>
                  {table.activa ? 'Desactivar' : 'Activar'}
                </button>
              </div>
              <button onClick={() => deleteTable(table)} style={{ width: '100%', background: 'transparent', border: '0.5px solid #3a2020', borderRadius: 8, padding: '7px 0', fontSize: 12, color: '#8a5050', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
                Eliminar mesa
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
