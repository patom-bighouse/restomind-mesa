import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'
import { useRestaurantModulos } from '../lib/modulos'

function generarCodigo() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' // sin caracteres fáciles de confundir (0/O, 1/I)
  let codigo = ''
  for (let i = 0; i < 8; i++) codigo += chars[Math.floor(Math.random() * chars.length)]
  return codigo
}

function fechaEnUnAnio() {
  const d = new Date()
  d.setFullYear(d.getFullYear() + 1)
  return d.toISOString().slice(0, 10)
}

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  navTabs: { display: 'flex', gap: 8, flexWrap: 'wrap' },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  content: { padding: 24, maxWidth: 900, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 6 },
  sectionHint: { fontSize: 12, color: '#7a6a50', marginBottom: 20, lineHeight: 1.5 },
  addBar: { display: 'flex', gap: 12, marginBottom: 28, flexWrap: 'wrap', alignItems: 'flex-end', background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16 },
  field: { display: 'flex', flexDirection: 'column', gap: 4 },
  label: { fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em' },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', minWidth: 120 },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 14px 10px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '14px', fontSize: 14, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  row: { background: '#1a1a1a' },
  codigo: { fontFamily: 'monospace', fontSize: 15, color: '#e8c97a', letterSpacing: '0.05em' },
  chip: (color) => ({ fontSize: 11, color, background: '#111', border: `0.5px solid ${color}`, borderRadius: 20, padding: '3px 10px' }),
  toggleBtn: (activo) => ({ background: 'transparent', border: `0.5px solid ${activo ? '#27ae60' : '#3a2e20'}`, borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: activo ? '#2ecc71' : '#666', fontFamily: "'Inter', sans-serif" }),
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 60, color: '#555', fontSize: 14 },
}

export default function AdminVales() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [vales, setVales] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const [importe, setImporte] = useState('')
  const [codigo, setCodigo] = useState(generarCodigo())
  const [destinatarioNombre, setDestinatarioNombre] = useState('')
  const [destinatarioTelefono, setDestinatarioTelefono] = useState('')
  const [vencimiento, setVencimiento] = useState(fechaEnUnAnio())
  const [adding, setAdding] = useState(false)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('nombre, moneda').eq('id', restaurantId).single()
    setRestaurant(rest)
    await loadVales()
    setLoading(false)
  }

  async function loadVales() {
    const { data, error: err } = await supabase
      .from('vales_regalo')
      .select('id, codigo, importe_inicial, saldo_actual, destinatario_nombre, destinatario_telefono, fecha_vencimiento, activo')
      .eq('restaurant_id', restaurantId)
      .order('created_at', { ascending: false })
    if (err) { setError(err.message); return }
    setVales(data || [])
  }

  async function addVale() {
    if (!importe || parseFloat(importe) <= 0) { setError('Indica un importe válido.'); return }
    if (!codigo.trim()) { setError('Indica un código.'); return }
    if (!vencimiento) { setError('Indica una fecha de vencimiento.'); return }
    setError(null)
    setAdding(true)
    const { error: err } = await supabase
      .from('vales_regalo')
      .insert({
        restaurant_id: restaurantId,
        codigo: codigo.trim().toUpperCase(),
        importe_inicial: parseFloat(importe),
        saldo_actual: parseFloat(importe),
        destinatario_nombre: destinatarioNombre.trim() || null,
        destinatario_telefono: destinatarioTelefono.trim() || null,
        fecha_vencimiento: vencimiento,
      })
    setAdding(false)
    if (err) {
      setError(err.code === '23505' ? 'Ya existe un vale con ese código. Elige otro.' : err.message)
      return
    }
    setImporte(''); setCodigo(generarCodigo()); setDestinatarioNombre(''); setDestinatarioTelefono(''); setVencimiento(fechaEnUnAnio())
    await loadVales()
  }

  async function toggleVale(vale) {
    const { error: err } = await supabase.from('vales_regalo').update({ activo: !vale.activo }).eq('id', vale.id)
    if (err) { setError(err.message); return }
    setVales(prev => prev.map(v => v.id === vale.id ? { ...v, activo: !v.activo } : v))
  }

  function estadoVale(vale) {
    if (!vale.activo) return { label: 'Desactivado', color: '#666' }
    if (vale.fecha_vencimiento < new Date().toISOString().slice(0, 10)) return { label: 'Caducado', color: '#e87a7a' }
    if (vale.saldo_actual <= 0) return { label: 'Agotado', color: '#e8a03a' }
    return { label: 'Activo', color: '#2ecc71' }
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
          <a href={`/admin/vales/${restaurantId}`} style={S.navTab(true)}>Vales</a>
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>
          <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(false)}>Reservas</a>
          <a href={`/admin/limpieza/${restaurantId}`} style={S.navTab(false)}>Limpieza</a>
          <a href={`/admin/fidelizacion/${restaurantId}`} style={S.navTab(false)}>Fidelización</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Vales regalo</div>
        <div style={S.sectionHint}>
          Emite un vale y entrégalo al cliente (papel o WhatsApp, a mano). Se canjea en mesa por el
          código, con soporte de canje parcial — si no se gasta todo, el saldo queda para la próxima
          visita, hasta la fecha de vencimiento.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.addBar}>
          <div style={S.field}>
            <span style={S.label}>Importe ({restaurant?.moneda || 'EUR'})</span>
            <input style={{ ...S.input, width: 110 }} type="number" step="0.01" min="0" value={importe} onChange={e => setImporte(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Código</span>
            <input style={{ ...S.input, width: 140, fontFamily: 'monospace' }} value={codigo} onChange={e => setCodigo(e.target.value.toUpperCase())} />
          </div>
          <div style={S.field}>
            <span style={S.label}>A nombre de (opcional)</span>
            <input style={{ ...S.input, width: 160 }} value={destinatarioNombre} onChange={e => setDestinatarioNombre(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Teléfono (opcional)</span>
            <input style={{ ...S.input, width: 140 }} value={destinatarioTelefono} onChange={e => setDestinatarioTelefono(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Vencimiento</span>
            <input style={S.input} type="date" value={vencimiento} onChange={e => setVencimiento(e.target.value)} />
          </div>
          <button style={S.addBtn} onClick={addVale} disabled={adding}>
            {adding ? 'Emitiendo...' : '+ Emitir vale'}
          </button>
        </div>

        {vales.length === 0 ? (
          <div style={S.empty}>Todavía no emitiste ningún vale.</div>
        ) : (
          <table style={S.table}>
            <thead>
              <tr>
                <th style={S.th}>Código</th>
                <th style={S.th}>Saldo</th>
                <th style={S.th}>A nombre de</th>
                <th style={S.th}>Vencimiento</th>
                <th style={S.th}>Estado</th>
                <th style={S.th}></th>
              </tr>
            </thead>
            <tbody>
              {vales.map(v => {
                const estado = estadoVale(v)
                return (
                  <tr key={v.id} style={{ ...S.row, opacity: v.activo ? 1 : 0.5 }}>
                    <td style={S.td}><span style={S.codigo}>{v.codigo}</span></td>
                    <td style={S.td}>{formatMoney(v.saldo_actual, restaurant?.moneda)} <span style={{ color: '#7a6a50', fontSize: 12 }}>/ {formatMoney(v.importe_inicial, restaurant?.moneda)}</span></td>
                    <td style={S.td}>
                      {v.destinatario_nombre || '—'}
                      {v.destinatario_telefono && <div style={{ fontSize: 11, color: '#7a6a50' }}>{v.destinatario_telefono}</div>}
                    </td>
                    <td style={S.td}>{new Date(v.fecha_vencimiento + 'T00:00:00').toLocaleDateString('es-ES')}</td>
                    <td style={S.td}><span style={S.chip(estado.color)}>{estado.label}</span></td>
                    <td style={{ ...S.td, textAlign: 'right' }}>
                      <button style={S.toggleBtn(v.activo)} onClick={() => toggleVale(v)}>
                        {v.activo ? 'Desactivar' : 'Reactivar'}
                      </button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
