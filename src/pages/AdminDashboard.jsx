import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'
import { useRestaurantModulos } from '../lib/modulos'
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
  const { tieneModulo, loading: loadingModulos } = useRestaurantModulos(restaurantId)
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
    const { data: rest } = await supabase.from('restaurants').select('id, nombre, moneda, config').eq('id', restaurantId).single()
    if (!rest) { navigate('/admin/login'); return }
    setRestaurant(rest)
    await loadTables(rest.id)
    setLoading(false)
  }

  async function loadTables(restId) {
    const { data } = await supabase.from('tables').select('id, numero, zona, capacidad').eq('restaurant_id', restId)
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
      .select('id, table_id, estado, abierta_at, cerrada_at, total, estado_pago, metodo_pago, motivo_exencion, comensales')
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
        .select('order_id, nombre_snapshot, cantidad, precio_snapshot, costo_snapshot, notas')
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

  if (loading || loadingModulos) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  if (!tieneModulo('reportes')) {
    return (
      <div style={S.app}>
        <div style={S.loading}>Este restaurante no tiene activo el módulo de Reportes y Dashboard.</div>
      </div>
    )
  }

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

  // Rentabilidad por producto: ingreso, coste y margen en el rango.
  // Solo se computa coste/margen sobre las unidades que tienen
  // costo_snapshot cargado — las que no lo tienen (ventas anteriores a
  // esta funcionalidad, o productos sin coste trackeado) se excluyen del
  // cálculo de margen pero igual suman al ingreso, para no subestimarlo.
  const rentabilidadPorProducto = {}
  Object.values(orderItemsMap).flat().forEach(item => {
    const ordenIsValid = validOrders.find(o => orderItemsMap[o.id]?.includes(item))
    if (!ordenIsValid) return
    const key = item.nombre_snapshot
    if (!rentabilidadPorProducto[key]) {
      rentabilidadPorProducto[key] = { unidades: 0, ingreso: 0, ingresoConCosto: 0, costo: 0, tieneCosto: false }
    }
    const r = rentabilidadPorProducto[key]
    const ingresoLinea = item.cantidad * parseFloat(item.precio_snapshot || 0)
    r.unidades += item.cantidad
    r.ingreso += ingresoLinea
    if (item.costo_snapshot != null) {
      r.ingresoConCosto += ingresoLinea
      r.costo += item.cantidad * parseFloat(item.costo_snapshot)
      r.tieneCosto = true
    }
  })
  const rentabilidadData = Object.entries(rentabilidadPorProducto)
    .map(([nombre, r]) => ({
      nombre,
      unidades: r.unidades,
      ingreso: r.ingreso,
      costo: r.tieneCosto ? r.costo : null,
      margen: r.tieneCosto ? r.ingresoConCosto - r.costo : null,
      margenPct: r.tieneCosto && r.ingresoConCosto > 0 ? ((r.ingresoConCosto - r.costo) / r.ingresoConCosto) * 100 : null,
    }))
    .sort((a, b) => (b.margen ?? -Infinity) - (a.margen ?? -Infinity))
  const umbralMargenAlerta = restaurant?.config?.umbral_margen_alerta ?? 20

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

  // Comensales: promedio real vs capacidad teórica, por mesa. Solo
  // cuentan las sesiones que tienen el dato cargado (comensales no nulo);
  // las mesas abiertas antes de este feature no lo tienen y no deben
  // distorsionar el promedio.
  const sesionesConComensales = sessions.filter(s => s.comensales != null)
  const comensalesPromedioGeneral = sesionesConComensales.length
    ? sesionesConComensales.reduce((sum, s) => sum + s.comensales, 0) / sesionesConComensales.length
    : null

  const comensalesPorMesa = {}
  sesionesConComensales.forEach(s => {
    if (!comensalesPorMesa[s.table_id]) comensalesPorMesa[s.table_id] = { suma: 0, visitas: 0, maxComensales: 0 }
    comensalesPorMesa[s.table_id].suma += s.comensales
    comensalesPorMesa[s.table_id].visitas += 1
    comensalesPorMesa[s.table_id].maxComensales = Math.max(comensalesPorMesa[s.table_id].maxComensales, s.comensales)
  })
  const comensalesPorMesaData = Object.entries(comensalesPorMesa)
    .map(([tableId, d]) => ({
      tableId,
      numero: tables[tableId]?.numero ?? '?',
      capacidad: tables[tableId]?.capacidad ?? null,
      promedio: d.suma / d.visitas,
      maxComensales: d.maxComensales,
      visitas: d.visitas,
    }))
    .sort((a, b) => a.numero - b.numero)

  // Etiqueta de mesa incluyendo zona, para distinguir mesas con el mismo
  // número físico pero ubicadas en zonas distintas (ej: dos "Mesa 1",
  // una interior y otra exterior).
  function mesaLabel(tableId) {
    const t = tables[tableId]
    if (!t) return 'Mesa ?'
    if (!t.zona) return `Mesa ${t.numero}`
    const zonaCapitalizada = t.zona.charAt(0).toUpperCase() + t.zona.slice(1)
    return `Mesa ${t.numero} (${zonaCapitalizada})`
  }

  // Para un pedido de mesa, busca la sesión a la que pertenece (para
  // saber si ya está cobrado y con qué método) — un pedido de take away
  // no tiene table_session_id, queda sin esa información.
  const sessionsById = {}
  sessions.forEach(s => { sessionsById[s.id] = s })

  function csvEscape(val) {
    const s = String(val ?? '')
    if (s.includes(',') || s.includes('"') || s.includes('\n')) {
      return '"' + s.replace(/"/g, '""') + '"'
    }
    return s
  }

  function exportarCSV() {
    const headers = ['Fecha', 'Hora', 'Mesa / Tipo', 'Items', 'Total', 'Estado pedido', 'Estado pago', 'Método de pago']
    const filas = orders
      .filter(o => o.estado !== 'cancelado')
      .map(o => {
        const fecha = new Date(o.created_at)
        const session = o.table_session_id ? sessionsById[o.table_session_id] : null
        const items = (orderItemsMap[o.id] || []).map(i => `${i.cantidad}x ${i.nombre_snapshot}`).join('; ')
        return [
          fecha.toLocaleDateString('es-ES'),
          fecha.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' }),
          o.tipo === 'mesa' ? mesaLabel(o.table_id) : 'Takeaway',
          items,
          o.total,
          o.estado,
          session?.estado_pago || (o.tipo === 'takeaway' ? '—' : 'sin sesión'),
          session?.metodo_pago || '—',
        ]
      })
    const csvContent = [headers, ...filas]
      .map(fila => fila.map(csvEscape).join(','))
      .join('\n')
    // BOM para que Excel abra los acentos correctamente
    const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    const { from } = getRangeDates(range, customFrom, customTo)
    a.href = url
    a.download = `pedidos_${restaurant?.nombre?.replace(/\s+/g, '_') || 'restomind'}_${from.toISOString().slice(0, 10)}.csv`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  function imprimirCierre() {
    window.print()
  }

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <style>{`
        @media print {
          .no-print { display: none !important; }
          .print-only { display: block !important; }
        }
        .print-only { display: none; }
      `}</style>
      <div className="no-print" style={S.header}>
        <div>
          <div style={S.logo}>Restomind Admin</div>
          <div style={S.restName}>{restaurant?.nombre}</div>
        </div>
        <div style={S.navTabs}>
          <a href={`/admin/dashboard/${restaurantId}`} style={S.navTab(true)}>Dashboard</a>
          <a href={`/admin/mesas/${restaurantId}`} style={S.navTab(false)}>Mesas</a>
          <a href={`/admin/carta/${restaurantId}`} style={S.navTab(false)}>Carta</a>
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(false)}>Clientes</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div className="no-print" style={S.content}>
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
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 8 }} className="no-print">
            <button onClick={exportarCSV} style={{ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '7px 14px', fontSize: 13, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
              ⬇ Exportar CSV
            </button>
            <button onClick={imprimirCierre} style={{ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '7px 14px', fontSize: 13, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
              🖨 Imprimir cierre
            </button>
          </div>
        </div>

        {/* KPIs */}
        <div style={S.kpiGrid}>
          <div style={S.kpiCard('#e8c97a')}>
            <div style={S.kpiVal('#e8c97a')}>{formatMoney(ingresos, restaurant?.moneda)}</div>
            <div style={S.kpiLabel}>Ingresos</div>
          </div>
          <div style={S.kpiCard('#2ecc71')}>
            <div style={S.kpiVal('#2ecc71')}>{totalPedidos}</div>
            <div style={S.kpiLabel}>Pedidos</div>
          </div>
          <div style={S.kpiCard('#3498db')}>
            <div style={S.kpiVal('#3498db')}>{formatMoney(ticketMedio, restaurant?.moneda)}</div>
            <div style={S.kpiLabel}>Ticket medio</div>
          </div>
          <div style={S.kpiCard('#e74c3c')}>
            <div style={S.kpiVal('#e74c3c')}>{orders.filter(o => o.estado === 'cancelado').length}</div>
            <div style={S.kpiLabel}>Cancelados</div>
          </div>
          <div style={S.kpiCard('#9b59b6')}>
            <div style={S.kpiVal('#9b59b6')}>{comensalesPromedioGeneral != null ? comensalesPromedioGeneral.toFixed(1) : '—'}</div>
            <div style={S.kpiLabel}>Comensales promedio</div>
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
                    <div style={S.mesaNum}>{mesaLabel(tableId)}</div>
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
                      <th style={S.th}>Comensales</th>
                      <th style={S.th}>Pedidos</th>
                      <th style={S.th}>Total</th>
                      <th style={S.th}>Estado</th>
                      <th style={S.th}>Pago</th>
                    </tr>
                  </thead>
                  <tbody>
                    {sesionesConDatos.map(s => (
                      <tr key={s.id}>
                        <td style={S.td}>{mesaLabel(s.table_id)}</td>
                        <td style={S.td}>{new Date(s.abierta_at).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}</td>
                        <td style={S.td}>{s.cerrada_at ? new Date(s.cerrada_at).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—'}</td>
                        <td style={S.td}>
                          {s.comensales != null ? (
                            <span style={s.comensales > (tables[s.table_id]?.capacidad ?? Infinity) ? { color: '#e74c3c', fontWeight: 600 } : {}}>
                              {s.comensales}{tables[s.table_id]?.capacidad ? ` / ${tables[s.table_id].capacidad}` : ''}
                            </span>
                          ) : '—'}
                        </td>
                        <td style={S.td}>{s.pedidos}</td>
                        <td style={S.td}>{formatMoney(s.totalCalculado, restaurant?.moneda)}</td>
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

        {/* Comensales por mesa: promedio real vs capacidad teórica */}
        <div style={S.section}>
          <div style={S.chartCard}>
            <div style={S.cardTitle}>Comensales por mesa</div>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 14, marginTop: -6 }}>
              Promedio real de comensales por visita, comparado con la capacidad teórica de cada mesa. En rojo, las mesas que en promedio reciben más gente de la esperada.
            </div>
            {comensalesPorMesaData.length === 0 ? (
              <div style={{ fontSize: 13, color: '#555' }}>Sin datos de comensales en este rango.</div>
            ) : (
              <div style={{ overflowX: 'auto' }}>
                <table style={S.table}>
                  <thead>
                    <tr>
                      <th style={S.th}>Mesa</th>
                      <th style={S.th}>Capacidad teórica</th>
                      <th style={S.th}>Comensales promedio</th>
                      <th style={S.th}>Máximo registrado</th>
                      <th style={S.th}>Visitas</th>
                    </tr>
                  </thead>
                  <tbody>
                    {comensalesPorMesaData.map(m => {
                      const excedida = m.capacidad != null && m.promedio > m.capacidad
                      return (
                        <tr key={m.tableId}>
                          <td style={S.td}>{mesaLabel(m.tableId)}</td>
                          <td style={S.td}>{m.capacidad ?? '—'}</td>
                          <td style={{ ...S.td, ...(excedida ? { color: '#e74c3c', fontWeight: 600 } : {}) }}>
                            {m.promedio.toFixed(1)}
                            {excedida ? ' ⚠️' : ''}
                          </td>
                          <td style={S.td}>{m.maxComensales}</td>
                          <td style={S.td}>{m.visitas}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>

        {/* Rentabilidad por producto: ingreso, coste y margen */}
        <div style={S.section}>
          <div style={S.chartCard}>
            <div style={S.cardTitle}>Rentabilidad por producto</div>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 14, marginTop: -6 }}>
              Margen calculado con el precio de coste vigente en el momento de cada venta. Los productos sin coste cargado muestran el margen como "—".
            </div>
            {rentabilidadData.length === 0 ? (
              <div style={{ fontSize: 13, color: '#555' }}>Sin ventas en este rango.</div>
            ) : (
              <div style={{ overflowX: 'auto' }}>
                <table style={S.table}>
                  <thead>
                    <tr>
                      <th style={S.th}>Producto</th>
                      <th style={S.th}>Unidades</th>
                      <th style={S.th}>Ingreso</th>
                      <th style={S.th}>Coste</th>
                      <th style={S.th}>Margen</th>
                      <th style={S.th}>Margen %</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rentabilidadData.map(p => (
                      <tr key={p.nombre}>
                        <td style={S.td}>{p.nombre}</td>
                        <td style={S.td}>{p.unidades}</td>
                        <td style={S.td}>{formatMoney(p.ingreso, restaurant?.moneda)}</td>
                        <td style={S.td}>{p.costo != null ? formatMoney(p.costo, restaurant?.moneda) : '—'}</td>
                        <td style={{ ...S.td, ...(p.margen != null && p.margenPct < umbralMargenAlerta ? { color: '#e74c3c', fontWeight: 600 } : {}) }}>
                          {p.margen != null ? formatMoney(p.margen, restaurant?.moneda) : '—'}
                        </td>
                        <td style={{ ...S.td, ...(p.margenPct != null && p.margenPct < umbralMargenAlerta ? { color: '#e74c3c', fontWeight: 600 } : {}) }}>
                          {p.margenPct != null ? `${p.margenPct.toFixed(0)}%` : '—'}
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
                        <td style={S.td}>{o.tipo === 'mesa' ? mesaLabel(o.table_id) : 'Takeaway'}</td>
                        <td style={S.td}>{(orderItemsMap[o.id] || []).map(i => `${i.cantidad}× ${i.nombre_snapshot}`).join(', ') || '—'}</td>
                        <td style={S.td}>{formatMoney(o.total, restaurant?.moneda)}</td>
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

      {/* Bloque imprimible: fondo blanco, texto negro, pensado para papel.
          Oculto en pantalla, visible solo al imprimir (ver <style> arriba). */}
      <div className="print-only" style={{ background: '#fff', color: '#111', padding: 24, fontFamily: 'Arial, sans-serif' }}>
        <h1 style={{ fontSize: 20, marginBottom: 2 }}>{restaurant?.nombre}</h1>
        <div style={{ fontSize: 13, color: '#444', marginBottom: 4 }}>Cierre de caja — Restomind</div>
        <div style={{ fontSize: 12, color: '#666', marginBottom: 16 }}>
          Rango: {RANGES[range]}{range === 'custom' ? ` (${customFrom} → ${customTo})` : ''} · Impreso el {new Date().toLocaleString('es-ES')}
        </div>

        <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: 20 }}>
          <tbody>
            <tr>
              <td style={{ border: '1px solid #ccc', padding: '6px 10px', fontWeight: 'bold' }}>Ingresos</td>
              <td style={{ border: '1px solid #ccc', padding: '6px 10px' }}>{formatMoney(ingresos, restaurant?.moneda)}</td>
              <td style={{ border: '1px solid #ccc', padding: '6px 10px', fontWeight: 'bold' }}>Pedidos</td>
              <td style={{ border: '1px solid #ccc', padding: '6px 10px' }}>{validOrders.length}</td>
            </tr>
            <tr>
              <td style={{ border: '1px solid #ccc', padding: '6px 10px', fontWeight: 'bold' }}>Ticket medio</td>
              <td style={{ border: '1px solid #ccc', padding: '6px 10px' }}>{formatMoney(ticketMedio, restaurant?.moneda)}</td>
              <td style={{ border: '1px solid #ccc', padding: '6px 10px', fontWeight: 'bold' }}>Cancelados</td>
              <td style={{ border: '1px solid #ccc', padding: '6px 10px' }}>{orders.filter(o => o.estado === 'cancelado').length}</td>
            </tr>
          </tbody>
        </table>

        <h2 style={{ fontSize: 15, marginBottom: 8 }}>Detalle de pedidos</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 11 }}>
          <thead>
            <tr>
              <th style={{ border: '1px solid #ccc', padding: '5px 8px', textAlign: 'left' }}>Fecha / Hora</th>
              <th style={{ border: '1px solid #ccc', padding: '5px 8px', textAlign: 'left' }}>Mesa / Tipo</th>
              <th style={{ border: '1px solid #ccc', padding: '5px 8px', textAlign: 'left' }}>Items</th>
              <th style={{ border: '1px solid #ccc', padding: '5px 8px', textAlign: 'right' }}>Total</th>
              <th style={{ border: '1px solid #ccc', padding: '5px 8px', textAlign: 'left' }}>Estado</th>
            </tr>
          </thead>
          <tbody>
            {orders.map(o => (
              <tr key={o.id}>
                <td style={{ border: '1px solid #ccc', padding: '5px 8px' }}>{new Date(o.created_at).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}</td>
                <td style={{ border: '1px solid #ccc', padding: '5px 8px' }}>{o.tipo === 'mesa' ? mesaLabel(o.table_id) : 'Takeaway'}</td>
                <td style={{ border: '1px solid #ccc', padding: '5px 8px' }}>{(orderItemsMap[o.id] || []).map(i => `${i.cantidad}x ${i.nombre_snapshot}`).join(', ') || '—'}</td>
                <td style={{ border: '1px solid #ccc', padding: '5px 8px', textAlign: 'right' }}>{formatMoney(o.total, restaurant?.moneda)}</td>
                <td style={{ border: '1px solid #ccc', padding: '5px 8px' }}>{o.estado}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
