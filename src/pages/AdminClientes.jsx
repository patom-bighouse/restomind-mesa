import { useState, useEffect, Fragment } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'
import { useRestaurantModulos } from '../lib/modulos'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  navTabs: { display: 'flex', gap: 8, flexWrap: 'wrap' },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  content: { padding: 24, maxWidth: 800, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 20 },
  searchBar: { display: 'flex', gap: 12, marginBottom: 24 },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', flex: 1 },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 14px 10px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '14px', fontSize: 14, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  row: { background: '#1a1a1a' },
  puntos: { color: '#e8c97a', fontWeight: 600 },
  redeemBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 12px', fontSize: 12, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  success: { background: '#142a1a', border: '0.5px solid #2a5a3a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#7ae8a0', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 60, color: '#555', fontSize: 14 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 30 },
  modal: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 14, padding: 24, width: 340, maxWidth: '90vw' },
  modalTitle: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 4 },
  modalSub: { fontSize: 13, color: '#8a7560', marginBottom: 16 },
  cancelBtn: { flex: 1, background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px', fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  confirmBtn: (disabled) => ({ flex: 1, background: disabled ? '#5a4a2a' : '#e8c97a', color: disabled ? '#8a7560' : '#111', border: 'none', borderRadius: 10, padding: '10px', fontSize: 14, fontWeight: 500, cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
}

export default function AdminClientes() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [clientes, setClientes] = useState([])
  const [busqueda, setBusqueda] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [redeemCliente, setRedeemCliente] = useState(null) // cliente | null
  const [redeemCantidad, setRedeemCantidad] = useState('')
  const [redeemMotivo, setRedeemMotivo] = useState('')
  const [historialAbierto, setHistorialAbierto] = useState(null) // cliente_id | null
  const [movimientos, setMovimientos] = useState({}) // cliente_id -> [movimientos]
  const [redeeming, setRedeeming] = useState(false)
  const [niveles, setNiveles] = useState([])
  const [premios, setPremios] = useState([])
  const [redeemPremioId, setRedeemPremioId] = useState('')

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('nombre, moneda').eq('id', restaurantId).single()
    setRestaurant(rest)
    await loadClientes()
    await loadNiveles()
    await loadPremios()
    setLoading(false)
  }

  async function loadClientes() {
    const { data, error: err } = await supabase
      .from('clientes')
      .select('id, telefono, nombre, puntos, gasto_acumulado, ultima_visita, updated_at')
      .eq('restaurant_id', restaurantId)
      .order('puntos', { ascending: false })
    if (err) { setError(err.message); return }
    setClientes(data || [])
  }

  async function loadNiveles() {
    const { data } = await supabase
      .from('niveles_fidelizacion')
      .select('id, nombre, umbral_gasto')
      .eq('restaurant_id', restaurantId)
      .order('umbral_gasto')
    setNiveles(data || [])
  }

  async function loadPremios() {
    const { data } = await supabase
      .from('premios_fidelizacion')
      .select('id, nombre, costo_puntos, nivel_minimo_id')
      .eq('restaurant_id', restaurantId)
      .eq('activo', true)
      .order('costo_puntos')
    setPremios(data || [])
  }

  // El nivel más alto cuyo umbral de gasto ya se alcanzó — el mismo
  // criterio que usa fn_estado_fidelizacion del lado del cliente.
  function nivelDeCliente(gastoAcumulado) {
    const gasto = parseFloat(gastoAcumulado) || 0
    const elegibles = niveles.filter(n => n.umbral_gasto <= gasto)
    return elegibles.length > 0 ? elegibles[elegibles.length - 1] : null
  }

  async function toggleHistorial(clienteId) {
    if (historialAbierto === clienteId) { setHistorialAbierto(null); return }
    setHistorialAbierto(clienteId)
    if (!movimientos[clienteId]) {
      const { data } = await supabase
        .from('clientes_movimientos')
        .select('id, tipo, puntos, motivo, created_at')
        .eq('cliente_id', clienteId)
        .order('created_at', { ascending: false })
      setMovimientos(prev => ({ ...prev, [clienteId]: data || [] }))
    }
  }

  const clientesFiltrados = clientes.filter(c => {
    const q = busqueda.trim().toLowerCase()
    if (!q) return true
    return c.telefono?.toLowerCase().includes(q) || c.nombre?.toLowerCase().includes(q)
  })

  function openRedeem(cliente) {
    setRedeemCliente(cliente)
    setRedeemCantidad('')
    setRedeemMotivo('')
    setRedeemPremioId('')
    setError(null)
  }

  // Premios que este cliente puede canjear ahora: activos, con puntos
  // suficientes, y si tienen nivel mínimo, que ya lo haya alcanzado.
  function premiosDisponiblesPara(cliente) {
    if (!cliente) return []
    const nivel = nivelDeCliente(cliente.gasto_acumulado)
    return premios.filter(p =>
      p.costo_puntos <= cliente.puntos &&
      (!p.nivel_minimo_id || (nivel && niveles.find(n => n.id === p.nivel_minimo_id)?.umbral_gasto <= nivel.umbral_gasto))
    )
  }

  function seleccionarPremio(premioId) {
    setRedeemPremioId(premioId)
    const premio = premios.find(p => p.id === premioId)
    if (premio) {
      setRedeemCantidad(String(premio.costo_puntos))
      setRedeemMotivo(premio.nombre)
    }
  }

  async function confirmarCanje() {
    const cantidad = parseInt(redeemCantidad, 10)
    if (!Number.isInteger(cantidad) || cantidad <= 0) {
      setError('Introduce una cantidad de puntos válida.')
      return
    }
    if (cantidad > redeemCliente.puntos) {
      setError('Ese cliente no tiene suficientes puntos.')
      return
    }
    setRedeeming(true)
    const { error: err } = await supabase
      .from('clientes')
      .update({ puntos: redeemCliente.puntos - cantidad, updated_at: new Date().toISOString() })
      .eq('id', redeemCliente.id)
    if (err) { setRedeeming(false); setError(err.message); return }

    await supabase.from('clientes_movimientos').insert({
      cliente_id: redeemCliente.id,
      tipo: 'resta',
      puntos: cantidad,
      motivo: redeemMotivo.trim() || 'Canje en el local',
    })

    setRedeeming(false)
    setSuccess(`Canjeados ${cantidad} puntos de ${redeemCliente.nombre || redeemCliente.telefono}.`)
    setTimeout(() => setSuccess(null), 4000)
    setMovimientos(prev => {
      const { [redeemCliente.id]: _, ...rest } = prev
      return rest
    })
    setRedeemCliente(null)
    await loadClientes()
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
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(true)}>Clientes</a>
          <a href={`/admin/vales/${restaurantId}`} style={S.navTab(false)}>Vales</a>
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>
          <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(false)}>Reservas</a>
          <a href={`/admin/limpieza/${restaurantId}`} style={S.navTab(false)}>Limpieza</a>
          <a href={`/admin/fidelizacion/${restaurantId}`} style={S.navTab(false)}>Fidelización</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Clientes ({clientes.length})</div>
        <div style={{ fontSize: 12, color: '#7a6a50', marginTop: -14, marginBottom: 20 }}>
          Se cargan automáticamente al entregar un pedido de take away con teléfono. Por ahora no incluye pedidos de mesa.
        </div>

        {error && !redeemCliente && <div style={S.error}>{error}</div>}
        {success && <div style={S.success}>{success}</div>}

        <div style={S.searchBar}>
          <input
            style={S.input}
            placeholder="Buscar por teléfono o nombre..."
            value={busqueda}
            onChange={e => setBusqueda(e.target.value)}
          />
        </div>

        {clientesFiltrados.length === 0 ? (
          <div style={S.empty}>
            {clientes.length === 0 ? 'Todavía no hay clientes registrados.' : 'Sin resultados para esa búsqueda.'}
          </div>
        ) : (
          <table style={S.table}>
            <thead>
              <tr>
                <th style={S.th}>Cliente</th>
                <th style={S.th}>Teléfono</th>
                <th style={S.th}>Nivel</th>
                <th style={S.th}>Puntos</th>
                <th style={S.th}>Gasto acumulado</th>
                <th style={S.th}>Última visita</th>
                <th style={S.th}></th>
              </tr>
            </thead>
            <tbody>
              {clientesFiltrados.map(c => (
                <Fragment key={c.id}>
                  <tr style={S.row}>
                    <td style={S.td}>{c.nombre || '—'}</td>
                    <td style={S.td}>{c.telefono}</td>
                    <td style={S.td}>{nivelDeCliente(c.gasto_acumulado)?.nombre || '—'}</td>
                    <td style={{ ...S.td, ...S.puntos }}>{c.puntos}</td>
                    <td style={S.td}>{formatMoney(c.gasto_acumulado, restaurant?.moneda)}</td>
                    <td style={S.td}>{c.ultima_visita ? new Date(c.ultima_visita).toLocaleDateString('es-ES') : '—'}</td>
                    <td style={{ ...S.td, display: 'flex', gap: 8 }}>
                      <button style={S.redeemBtn} onClick={() => toggleHistorial(c.id)}>
                        {historialAbierto === c.id ? 'Ocultar' : 'Historial'}
                      </button>
                      <button style={S.redeemBtn} onClick={() => openRedeem(c)} disabled={c.puntos <= 0}>
                        Canjear
                      </button>
                    </td>
                  </tr>
                  {historialAbierto === c.id && (
                    <tr style={S.row}>
                      <td colSpan={7} style={{ ...S.td, paddingTop: 0 }}>
                        {!movimientos[c.id] ? (
                          <div style={{ fontSize: 12, color: '#555' }}>Cargando...</div>
                        ) : movimientos[c.id].length === 0 ? (
                          <div style={{ fontSize: 12, color: '#555' }}>Sin movimientos todavía.</div>
                        ) : (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                            {movimientos[c.id].map(m => (
                              <div key={m.id} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: '#8a7560' }}>
                                <span>{new Date(m.created_at).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })} — {m.motivo}</span>
                                <span style={{ color: m.tipo === 'suma' ? '#7ae8a0' : '#e87a7a', fontWeight: 500 }}>
                                  {m.tipo === 'suma' ? '+' : '−'}{m.puntos}
                                </span>
                              </div>
                            ))}
                          </div>
                        )}
                      </td>
                    </tr>
                  )}
                </Fragment>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {redeemCliente && (
        <div style={S.overlay} onClick={() => setRedeemCliente(null)}>
          <div style={S.modal} onClick={e => e.stopPropagation()}>
            <div style={S.modalTitle}>Canjear puntos</div>
            <div style={S.modalSub}>{redeemCliente.nombre || redeemCliente.telefono} · tiene {redeemCliente.puntos} puntos</div>
            {error && <div style={S.error}>{error}</div>}
            {premiosDisponiblesPara(redeemCliente).length > 0 && (
              <select
                style={{ ...S.input, width: '100%', boxSizing: 'border-box', marginBottom: 16 }}
                value={redeemPremioId}
                onChange={e => seleccionarPremio(e.target.value)}
              >
                <option value="">Elige un premio del catálogo (opcional)</option>
                {premiosDisponiblesPara(redeemCliente).map(p => (
                  <option key={p.id} value={p.id}>{p.nombre} — {p.costo_puntos} puntos</option>
                ))}
              </select>
            )}
            <input
              style={{ ...S.input, width: '100%', boxSizing: 'border-box', marginBottom: 16 }}
              type="number"
              min="1"
              max={redeemCliente.puntos}
              placeholder="Cantidad de puntos a canjear"
              value={redeemCantidad}
              onChange={e => setRedeemCantidad(e.target.value)}
              autoFocus
            />
            <input
              style={{ ...S.input, width: '100%', boxSizing: 'border-box', marginBottom: 16 }}
              type="text"
              placeholder="Motivo (opcional, ej: Cerveza gratis)"
              value={redeemMotivo}
              onChange={e => setRedeemMotivo(e.target.value)}
            />
            <div style={{ display: 'flex', gap: 10 }}>
              <button style={S.cancelBtn} onClick={() => setRedeemCliente(null)}>Cancelar</button>
              <button style={S.confirmBtn(redeeming)} onClick={confirmarCanje} disabled={redeeming}>
                {redeeming ? 'Canjeando...' : 'Confirmar canje'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
