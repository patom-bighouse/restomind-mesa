import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10, flexWrap: 'wrap', gap: 12 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  navTabs: { display: 'flex', gap: 8 },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 24, maxWidth: 1100, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 20 },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },

  rangeBar: { display: 'flex', gap: 8, marginBottom: 24, flexWrap: 'wrap', alignItems: 'center' },
  rangeBtn: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '7px 16px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }),
  dateInput: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '7px 12px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },

  kpiGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 14, marginBottom: 32 },
  kpiCard: (color) => ({ background: '#1a1a1a', border: `1px solid ${color}`, borderRadius: 14, padding: '18px 20px', display: 'flex', flexDirection: 'column', gap: 6 }),
  kpiVal: (color) => ({ fontSize: 30, fontWeight: 600, color, fontFamily: "'Playfair Display', serif", lineHeight: 1 }),
  kpiLabel: { fontSize: 12, color: '#8a7560' },

  section: { marginBottom: 32 },
  twoCol: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 },

  chartCard: { background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 14, padding: 18 },
  cardTitle: { fontSize: 13, fontWeight: 500, color: '#c4a85a', marginBottom: 14, textTransform: 'uppercase', letterSpacing: '0.06em' },

  topItem: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 0', borderBottom: '0.5px solid #2a2a2a', fontSize: 13 },
  topItemName: { color: '#f0e8d8' },
  topItemBar: { height: 4, background: '#3a2e20', borderRadius: 2, marginTop: 4, overflow: 'hidden' },
  topItemFill: (pct) => ({ height: '100%', width: `${pct}%`, background: '#e8c97a' }),
  topItemCount: { color: '#e8c97a', fontWeight: 500, marginLeft: 12 },

  mesaGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(90px, 1fr))', gap: 10 },
  mesaCell: (intensity) => ({ background: `rgba(232,201,122,${intensity})`, border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 8px', textAlign: 'center' }),
  mesaNum: { fontSize: 13, fontWeight: 600, color: '#f0e8d8' },
  mesaCount: { fontSize: 11, color: '#8a7560', marginTop: 2 },

  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: '0.06em', padding: '8px 12px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '10px 12px', fontSize: 13, borderBottom: '0.5px solid #1f1f1f' },
  estadoBadge: (estado) => {
    const colors = { entregado: '#2ecc71', cancelado: '#e74c3c', pendiente: '#f1c40f', preparando: '#f39c12', listo: '#3498db' }
    const c = colors[estado] || '#888'
    return { fontSize: 11, fontWeight: 500, padding: '3px 10px', borderRadius: 20, background: `${c}22`, color: c }
  },
  sesionEstadoBadge: (abierta) => ({ fontSize: 11, fontWeight: 500, padding: '3px 10px', borderRadius: 20, background: abierta ? '#0f2a1522' : '#1a1a1a', color: abierta ? '#2ecc71' : '#888', border: `0.5px solid ${abierta ? '#27ae60' : '#333'}` }),
  pagoBadge: (estado) => {
    const c = estado === 'pagado' ? '#2ecc71' : estado === 'exento' ? '#7aa8e8' : '#e8b84a'
    return { fontSize: 11, fontWeight: 500, padding: '3px 10px', borderRadius: 20, background: `${c}22`, color: c }
  },
}

const RANGES = {
  hoy: 'Hoy',
  semana: 'Esta semana',
  mes: 'Este mes',
  custom: 'Personalizado',
}

function getRangeDates(range, customFrom, customTo) {
  const now = new Date()
  let from, to
  if (range === 'hoy') {
    from = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    to = new Date(from.getTime() + 24 * 60 * 60 * 1000)
  } else if (range === 'semana') {
    const day = now.getDay() || 7 // lunes = 1 ... domingo = 7
    from = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (day - 1))
    to = new Date(from.getTime() + 7 * 24 * 60 * 60 * 1000)
  } else if (range === 'mes') {
    from = new Date(now.getFullYear(), now.getMonth(), 1)
    to = new Date(now.getFullYear(), now.getMonth() + 1, 1)
  } else {
    from = customFrom ? new Date(customFrom) : new Date(now.getFullYear(), now.getMonth(), now.getDate())
    to = customTo ? new Date(new Date(customTo).getTime() + 24 * 60 * 60 * 1000) : new Date(from.getTime() + 24 * 60 * 60 * 1000)
  }
  return { from, to }
}

export default function AdminDashboard() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const [restaurant, setRestaurant] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const [range, setRange] = useState('hoy')
  const [customFrom, setCustomFrom] = useState('')
  const [customTo, setCustomTo] = useState('')

  const [orders, setOrders] = useState([])
  const [orderItemsMap, setOrderItemsMap] = useState({})
  const [tables, setTables] = useState({})
  const [sessions, setSessions] = useState([])

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('id, nombre').eq('id', restaurantId).single()
    if (!rest) { navigate('/admin/login'); return }
    setRestaurant(rest)
    await loadTables(rest.id)
    setLoading(false)
  }

  async function loadTables(restId) {
    const { data } = await supabase.from('tables').select('id, numero, zona').eq('restaurant_id', restId)
    const map = {}
    ;(data || []).forEach(t => { map[t.id] = t })
    setTables(map)
  }

  useEffect(() => {
    if (!restaurant) return
    loadOrders()
    loadSessions()
  }, [restaurant, range, customFrom, customTo])

  async function loadSessions() {
    const { from, to } = getRangeDates(range, customFrom, customTo)
    const { data, error: err } = await supabase
      .from('table_sessions')
      .select('id, table_id, estado, abierta_at, cerrada_at, total, estado_pago, motivo_exencion')
      .eq('restaurant_id', restaurantId)
      .gte('abierta_at', from.toISOString())
      .lt('abierta_at', to.toISOString())
      .order('abierta_at', { ascending: false })
    if (err) { setError(err.message); return }
    setSessions(data || [])
  }

  // Realtime: refresca cuando cambian pedidos del restaurante
  useEffect(() => {
    if (!restaurant) return
    const channel = supabase
      .channel('dashboard-orders-' + restaurant.id)
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'orders',
        filter: `restaurant_id=eq.${restaurant.id}`
      }, () => loadOrders())
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'order_items',
      }, () => loadOrders())
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'table_sessions',
        filter: `restaurant_id=eq.${restaurant.id}`
      }, () => loadSessions())
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [restaurant])

  async function loadOrders() {
    const { from, to } = getRangeDates(range, customFrom, customTo)
    const { data, error: err } = await supabase
      .from('orders')
      .select('id, table_id, table_session_id, estado, total, tipo, created_at, notas')
      .eq('restaurant_id', restaurantId)
      .gte('created_at', from.toISOString())
      .lt('created_at', to.toISOString())
      .order('created_at', { ascending: false })
    if (err) { setError(err.message); return }
    setOrders(data || [])

    const ids = (data || []).map(o => o.id)
    if (ids.length) {
      const { data: items } = await supabase
        .from('order_items')
        .select('order_id, nombre_snapshot, cantidad, precio_snapshot, notas')
        .in('order_id', ids)
      const map = {}
      ;(items || []).forEach(i => {
        if (!map[i.order_id]) map[i.order_id] = []
        map[i.order_id].push(i)
      })
      setOrderItemsMap(map)
    } else {
      setOrderItemsMap({})
    }
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  // ---------- Cálculos ----------
  const validOrders = orders.filter(o => o.estado !== 'cancelado')
  const ingresos = validOrders.reduce((s, o) => s + parseFloat(o.total || 0), 0)
  const totalPedidos = validOrders.length
  const ticketMedio = totalPedidos ? ingresos / totalPedidos : 0

  // Top platos
  const platoCounts = {}
  Object.values(orderItemsMap).flat().forEach(item => {
    const ordenIsValid = validOrders.find(o => orderItemsMap[o.id]?.includes(item))
    if (!ordenIsValid) return
    platoCounts[item.nombre_snapshot] = (platoCounts[item.nombre_snapshot] || 0) + item.cantidad
  })
  const topPlatos = Object.entries(platoCounts).sort((a, b) => b[1] - a[1]).slice(0, 8)
  const maxPlatoCount = topPlatos.length ? topPlatos[0][1] : 1

  // Ocupación de mesas
  const mesaCounts = {}
  validOrders.forEach(o => {
    if (!o.table_id) return
    mesaCounts[o.table_id] = (mesaCounts[o.table_id] || 0) + 1
  })
  const maxMesaCount = Math.max(1, ...Object.values(mesaCounts))

  // Horas pico
  const horaCounts = {}
  for (let h = 0; h < 24; h++) horaCounts[h] = 0
  validOrders.forEach(o => {
    const h = new Date(o.created_at).getHours()
    horaCounts[h]++
  })
  const horaData = Object.entries(horaCounts).map(([h, count]) => ({ hora: `${h}h`, pedidos: count }))

  // Sesiones de mesa (agrupa los pedidos por visita de cliente, no solo por mesa física)
  const pedidosPorSesion = {}
  validOrders.forEach(o => {
    if (!o.table_session_id) return
    if (!pedidosPorSesion[o.table_session_id]) pedidosPorSesion[o.table_session_id] = { count: 0, total: 0 }
    pedidosPorSesion[o.table_session_id].count += 1
    pedidosPorSesion[o.table_session_id].total += parseFloat(o.total || 0)
  })
  const sesionesConDatos = sessions.map(s => ({
    ...s,
    pedidos: pedidosPorSesion[s.id]?.count || 0,
    totalCalculado: pedidosPorSesion[s.id]?.total ?? parseFloat(s.total || 0),
  })).sort((a, b) => new Date(b.abierta_at) - new Date(a.abierta_at))

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.header}>
        <div>
          <div style={S.logo}>Restomind Admin</div>
          <div style={S.restName}>{restaurant?.nombre}</div>
        </div>
        <div style={S.navTabs}>
          <a href={`/admin/dashboard/${restaurantId}`} style={S.navTab(true)}>Dashboard</a>
          <a href={`/admin/mesas/${restaurantId}`} style={S.navTab(false)}>Mesas</a>
          <a href={`/admin/carta/${restaurantId}`} style={S.navTab(false)}>Carta</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Dashboard</div>
        {error && <div style={S.error}>{error}</div>}

        {/* Selector de rango */}
        <div style={S.rangeBar}>
          {Object.entries(RANGES).map(([key, label]) => (
            <button key={key} style={S.rangeBtn(range === key)} onClick={() => setRange(key)}>{label}</button>
          ))}
          {range === 'custom' && (
            <>
              <input type="date" style={S.dateInput} value={customFrom} onChange={e => setCustomFrom(e.target.value)} />
              <span style={{ color: '#555' }}>→</span>
              <input type="date" style={S.dateInput} value={customTo} onChange={e => setCustomTo(e.target.value)} />
            </>
          )}
        </div>

        {/* KPIs */}
        <div style={S.kpiGrid}>
          <div style={S.kpiCard('#e8c97a')}>
            <div style={S.kpiVal('#e8c97a')}>{ingresos.toFixed(2).replace('.', ',')} €</div>
            <div style={S.kpiLabel}>Ingresos</div>
          </div>
          <div style={S.kpiCard('#2ecc71')}>
            <div style={S.kpiVal('#2ecc71')}>{totalPedidos}</div>
            <div style={S.kpiLabel}>Pedidos</div>
          </div>
          <div style={S.kpiCard('#3498db')}>
            <div style={S.kpiVal('#3498db')}>{ticketMedio.toFixed(2).replace('.', ',')} €</div>
            <div style={S.kpiLabel}>Ticket medio</div>
          </div>
          <div style={S.kpiCard('#e74c3c')}>
            <div style={S.kpiVal('#e74c3c')}>{orders.filter(o => o.estado === 'cancelado').length}</div>
            <div style={S.kpiLabel}>Cancelados</div>
          </div>
        </div>

        {/* Horas pico */}
        <div style={S.section}>
          <div style={S.chartCard}>
            <div style={S.cardTitle}>Pedidos por hora</div>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={horaData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a2a" vertical={false} />
                <XAxis dataKey="hora" stroke="#7a6a50" fontSize={11} interval={1} />
                <YAxis stroke="#7a6a50" fontSize={11} allowDecimals={false} />
                <Tooltip contentStyle={{ background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 8, fontSize: 12 }} labelStyle={{ color: '#e8c97a' }} />
                <Bar dataKey="pedidos" fill="#e8c97a" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Top platos + Ocupación mesas */}
        <div style={{ ...S.section, ...S.twoCol }}>
          <div style={S.chartCard}>
            <div style={S.cardTitle}>Platos más vendidos</div>
            {topPlatos.length === 0 ? (
              <div style={{ fontSize: 13, color: '#555' }}>Sin datos en este rango.</div>
            ) : topPlatos.map(([nombre, count]) => (
              <div key={nombre} style={S.topItem}>
                <div style={{ flex: 1 }}>
                  <div style={S.topItemName}>{nombre}</div>
                  <div style={S.topItemBar}><div style={S.topItemFill((count / maxPlatoCount) * 100)}></div></div>
                </div>
                <div style={S.topItemCount}>{count}</div>
              </div>
            ))}
          </div>

          <div style={S.chartCard}>
            <div style={S.cardTitle}>Ocupación de mesas</div>
            {Object.keys(mesaCounts).length === 0 ? (
              <div style={{ fontSize: 13, color: '#555' }}>Sin pedidos de mesa en este rango.</div>
            ) : (
              <div style={S.mesaGrid}>
                {Object.entries(mesaCounts)
                  .sort((a, b) => (tables[a[0]]?.numero || 0) - (tables[b[0]]?.numero || 0))
                  .map(([tableId, count]) => (
                  <div key={tableId} style={S.mesaCell(0.15 + (count / maxMesaCount) * 0.7)}>
                    <div style={S.mesaNum}>Mesa {tables[tableId]?.numero ?? '?'}</div>
                    <div style={S.mesaCount}>{count} {count === 1 ? 'pedido' : 'pedidos'}</div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Sesiones de mesa (visitas de clientes) */}
        <div style={S.section}>
          <div style={S.chartCard}>
            <div style={S.cardTitle}>Sesiones de mesa ({sesionesConDatos.length})</div>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 14, marginTop: -6 }}>
              Cada fila es una visita: agrupa todos los pedidos hechos por el mismo cliente/grupo mientras la mesa estuvo abierta.
            </div>
            {sesionesConDatos.length === 0 ? (
              <div style={{ fontSize: 13, color: '#555' }}>Sin sesiones de mesa en este rango.</div>
            ) : (
              <div style={{ overflowX: 'auto' }}>
                <table style={S.table}>
                  <thead>
                    <tr>
                      <th style={S.th}>Mesa</th>
                      <th style={S.th}>Abierta</th>
                      <th style={S.th}>Cerrada</th>
                      <th style={S.th}>Pedidos</th>
                      <th style={S.th}>Total</th>
                      <th style={S.th}>Estado</th>
                      <th style={S.th}>Pago</th>
                    </tr>
                  </thead>
                  <tbody>
                    {sesionesConDatos.map(s => (
                      <tr key={s.id}>
                        <td style={S.td}>Mesa {tables[s.table_id]?.numero ?? '?'}</td>
                        <td style={S.td}>{new Date(s.abierta_at).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}</td>
                        <td style={S.td}>{s.cerrada_at ? new Date(s.cerrada_at).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—'}</td>
                        <td style={S.td}>{s.pedidos}</td>
                        <td style={S.td}>{s.totalCalculado.toFixed(2).replace('.', ',')} €</td>
                        <td style={S.td}><span style={S.sesionEstadoBadge(s.estado === 'abierta')}>{s.estado === 'abierta' ? 'En curso' : 'Cerrada'}</span></td>
                        <td style={S.td}>
                          <span
                            style={S.pagoBadge(s.estado_pago)}
                            title={s.estado_pago === 'exento' ? (s.motivo_exencion || 'Invitación de la casa') : ''}
                          >
                            {s.estado_pago === 'pagado' ? 'Pagado' : s.estado_pago === 'exento' ? '🏠 Invitación' : 'Pendiente'}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>

        {/* Historial de pedidos */}
        <div style={S.section}>
          <div style={S.chartCard}>
            <div style={S.cardTitle}>Historial de pedidos ({orders.length})</div>
            {orders.length === 0 ? (
              <div style={{ fontSize: 13, color: '#555' }}>Sin pedidos en este rango.</div>
            ) : (
              <div style={{ overflowX: 'auto' }}>
                <table style={S.table}>
                  <thead>
                    <tr>
                      <th style={S.th}>Hora</th>
                      <th style={S.th}>Mesa / Tipo</th>
                      <th style={S.th}>Items</th>
                      <th style={S.th}>Total</th>
                      <th style={S.th}>Estado</th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map(o => (
                      <tr key={o.id}>
                        <td style={S.td}>{new Date(o.created_at).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}</td>
                        <td style={S.td}>{o.tipo === 'mesa' ? `Mesa ${tables[o.table_id]?.numero ?? '?'}` : 'Takeaway'}</td>
                        <td style={S.td}>{(orderItemsMap[o.id] || []).map(i => `${i.cantidad}× ${i.nombre_snapshot}`).join(', ') || '—'}</td>
                        <td style={S.td}>{parseFloat(o.total).toFixed(2).replace('.', ',')} €</td>
                        <td style={S.td}><span style={S.estadoBadge(o.estado)}>{o.estado}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
