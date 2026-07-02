import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { playNewOrderChime, playWaiterBell, unlockAudio } from '../lib/sound'

const ESTADOS = ['pendiente', 'preparando', 'listo', 'entregado']

const ESTADO_CFG = {
  pendiente:  { label: 'Pendiente',  bg: '#2a1410', border: '#c0392b', dot: '#e74c3c', next: 'preparando',  nextLabel: 'Preparando →' },
  preparando: { label: 'Preparando', bg: '#2a2010', border: '#d4a017', dot: '#f1c40f', next: 'listo',       nextLabel: 'Listo ✓' },
  listo:      { label: 'Listo',      bg: '#0f2a15', border: '#27ae60', dot: '#2ecc71', next: 'entregado',   nextLabel: 'Entregado 🍽' },
  entregado:  { label: 'Entregado',  bg: '#1a1a1a', border: '#3a3a3a', dot: '#555',    next: null,          nextLabel: null },
}

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  headerLeft: { display: 'flex', alignItems: 'center', gap: 12 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  liveTag: (live) => ({ fontSize: 11, fontWeight: 500, padding: '3px 10px', borderRadius: 20, background: live ? '#0f2a15' : '#2a1a1a', color: live ? '#2ecc71' : '#e74c3c', border: `0.5px solid ${live ? '#27ae60' : '#c0392b'}` }),
  headerRight: { fontSize: 13, color: '#555' },
  tabs: { display: 'flex', gap: 0, borderBottom: '0.5px solid #2a2a2a', background: '#0a0a0a' },
  tab: (active) => ({ flex: 1, padding: '12px 8px', fontSize: 13, fontWeight: 500, textAlign: 'center', cursor: 'pointer', background: 'transparent', border: 'none', borderBottom: active ? '2px solid #e8c97a' : '2px solid transparent', color: active ? '#e8c97a' : '#555', transition: 'all 0.15s', fontFamily: "'Inter', sans-serif" }),
  tabCount: (n) => ({ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 18, height: 18, borderRadius: '50%', background: n > 0 ? '#e8c97a' : '#2a2a2a', color: n > 0 ? '#111' : '#555', fontSize: 10, fontWeight: 600, marginLeft: 6 }),
  grid: { padding: 16, display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: 12 },
  card: (estado) => ({ background: ESTADO_CFG[estado].bg, border: `1px solid ${ESTADO_CFG[estado].border}`, borderRadius: 14, padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }),
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' },
  mesaInfo: { display: 'flex', flexDirection: 'column', gap: 3 },
  mesaNum: { fontSize: 16, fontWeight: 600, color: '#f0e8d8' },
  mesaZona: { fontSize: 12, color: '#8a7560' },
  timeTag: { fontSize: 12, color: '#8a7560', textAlign: 'right' },
  dot: (estado) => ({ width: 8, height: 8, borderRadius: '50%', background: ESTADO_CFG[estado].dot, display: 'inline-block', marginRight: 6 }),
  estadoTag: (estado) => ({ fontSize: 11, fontWeight: 500, color: ESTADO_CFG[estado].dot, display: 'flex', alignItems: 'center' }),
  divider: { height: '0.5px', background: '#2a2a2a' },
  itemsList: { display: 'flex', flexDirection: 'column', gap: 6 },
  itemRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 13 },
  itemName: { color: '#f0e8d8' },
  itemQty: { fontSize: 12, color: '#8a7560', background: '#1a1a1a', padding: '2px 8px', borderRadius: 10, fontWeight: 500 },
  nextBtn: (estado) => ({ width: '100%', padding: '10px 0', borderRadius: 10, border: 'none', background: ESTADO_CFG[estado].border, color: '#fff', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", transition: 'opacity 0.15s' }),
  empty: { gridColumn: '1 / -1', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '80px 20px', gap: 12, color: '#444' },
  emptyIcon: { fontSize: 40 },
  emptyText: { fontSize: 14 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  error: { margin: 20, background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 12, padding: 16, fontSize: 13, color: '#e87a7a' },
  notifBanner: (show) => ({ position: 'fixed', top: 70, right: 16, background: '#e8c97a', color: '#111', padding: '10px 16px', borderRadius: 10, fontSize: 13, fontWeight: 500, zIndex: 50, transition: 'all 0.3s', opacity: show ? 1 : 0, transform: show ? 'translateY(0)' : 'translateY(-10px)', pointerEvents: 'none' }),
}

function timeAgo(dateStr) {
  const diff = Math.floor((Date.now() - new Date(dateStr)) / 1000)
  if (diff < 60) return `${diff}s`
  if (diff < 3600) return `${Math.floor(diff / 60)}m`
  return `${Math.floor(diff / 3600)}h`
}

function formatHora(dateStr) {
  return new Date(dateStr).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })
}

export default function Cocina() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const [orders, setOrders] = useState([])
  const [orderItems, setOrderItems] = useState({})
  const [tables, setTables] = useState({})
  const [tableSessions, setTableSessions] = useState({}) // table_id -> sesión activa
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [activeTab, setActiveTab] = useState('pendiente')
  const [isLive, setIsLive] = useState(false)
  const [notif, setNotif] = useState(null)
  const [waiterCalls, setWaiterCalls] = useState([])

  function showNotif(msg) {
    setNotif(msg)
    setTimeout(() => setNotif(null), 3000)
  }

  async function loadOrderItems(orderIds) {
    if (!orderIds.length) return
    const { data } = await supabase
      .from('order_items')
      .select('order_id, nombre_snapshot, cantidad, notas')
      .in('order_id', orderIds)
    if (data) {
      setOrderItems(prev => {
        const next = { ...prev }
        data.forEach(item => {
          if (!next[item.order_id]) next[item.order_id] = []
          if (!next[item.order_id].find(i => i.nombre_snapshot === item.nombre_snapshot)) {
            next[item.order_id] = [...(next[item.order_id] || []), item]
          }
        })
        return next
      })
    }
  }

  async function loadTables() {
    const { data } = await supabase
      .from('tables')
      .select('id, numero, zona')
      .eq('restaurant_id', restaurantId)
    if (data) {
      const map = {}
      data.forEach(t => { map[t.id] = t })
      setTables(map)
    }
  }

  async function loadTableSessions() {
    const { data } = await supabase
      .from('table_sessions')
      .select('id, table_id, abierta_at')
      .eq('restaurant_id', restaurantId)
      .eq('estado', 'abierta')
    if (data) {
      const map = {}
      data.forEach(s => { map[s.table_id] = s })
      setTableSessions(map)
    }
  }

  async function loadWaiterCalls() {
    const { data } = await supabase
      .from('waiter_calls')
      .select('id, table_id, estado, created_at')
      .eq('restaurant_id', restaurantId)
      .eq('estado', 'pendiente')
      .order('created_at', { ascending: true })
    setWaiterCalls(data || [])
  }

  async function loadOrders() {
    const { data, error: err } = await supabase
      .from('orders')
      .select('id, table_id, estado, total, created_at, tipo, notas')
      .eq('restaurant_id', restaurantId)
      .in('estado', ['pendiente', 'preparando', 'listo'])
      .order('created_at', { ascending: true })
    if (err) { setError(err.message); return }
    setOrders(data || [])
    await loadOrderItems((data || []).map(o => o.id))
  }

  useEffect(() => {
    // Desbloquea el audio con la primera interacción real del usuario,
    // así los avisos que lleguen después por Realtime sí pueden sonar.
    const unlock = () => { unlockAudio(); window.removeEventListener('pointerdown', unlock) }
    window.addEventListener('pointerdown', unlock)
    return () => window.removeEventListener('pointerdown', unlock)
  }, [])

  useEffect(() => {
    async function init() {
      try {
        const { data: { session } } = await supabase.auth.getSession()
        if (!session) { navigate('/admin/login'); return }
        await loadTables()
        await loadTableSessions()
        await loadOrders()
        await loadWaiterCalls()
      } catch (e) {
        setError(e.message)
      } finally {
        setLoading(false)
      }
    }
    init()

    // Supabase Realtime — escucha nuevos pedidos y cambios de estado
    const channel = supabase
      .channel('cocina-orders')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'orders',
        filter: `restaurant_id=eq.${restaurantId}`
      }, async (payload) => {
        const newOrder = payload.new
        setOrders(prev => [...prev, newOrder])
        await loadOrderItems([newOrder.id])
        setActiveTab('pendiente')
        showNotif('🍽 Nuevo pedido recibido')
        playNewOrderChime()
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'orders',
        filter: `restaurant_id=eq.${restaurantId}`
      }, (payload) => {
        setOrders(prev => prev.map(o => o.id === payload.new.id ? { ...o, ...payload.new } : o)
          .filter(o => ['pendiente', 'preparando', 'listo'].includes(o.estado)))
      })
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'table_sessions',
        filter: `restaurant_id=eq.${restaurantId}`
      }, (payload) => {
        setTableSessions(prev => {
          const next = { ...prev }
          const row = payload.eventType === 'DELETE' ? payload.old : payload.new
          if (payload.eventType === 'DELETE' || row.estado !== 'abierta') {
            if (next[row.table_id]?.id === row.id) delete next[row.table_id]
          } else {
            next[row.table_id] = row
          }
          return next
        })
      })
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'waiter_calls',
        filter: `restaurant_id=eq.${restaurantId}`
      }, (payload) => {
        setWaiterCalls(prev => [...prev, payload.new])
        showNotif('🛎 Mesa llama al camarero')
        playWaiterBell()
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'waiter_calls',
        filter: `restaurant_id=eq.${restaurantId}`
      }, (payload) => {
        // Si la marcaron como atendida desde OTRA pantalla (ej. Mesas),
        // que también desaparezca acá para no duplicar el aviso.
        if (payload.new.estado !== 'pendiente') {
          setWaiterCalls(prev => prev.filter(c => c.id !== payload.new.id))
        }
      })
      .subscribe((status) => {
        setIsLive(status === 'SUBSCRIBED')
      })

    return () => { supabase.removeChannel(channel) }
  }, [restaurantId])

  async function advanceEstado(order) {
    const cfg = ESTADO_CFG[order.estado]
    if (!cfg.next) return
    const { error: err } = await supabase
      .from('orders')
      .update({ estado: cfg.next })
      .eq('id', order.id)
    if (err) console.error(err)
  }

  async function dismissWaiterCall(id) {
    await supabase.from('waiter_calls').update({ estado: 'atendido' }).eq('id', id)
    setWaiterCalls(prev => prev.filter(c => c.id !== id))
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  const byTab = orders.filter(o => o.estado === activeTab)
  const counts = { pendiente: 0, preparando: 0, listo: 0 }
  orders.forEach(o => { if (counts[o.estado] !== undefined) counts[o.estado]++ })

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando pedidos...</div></div>
  if (error) return <div style={S.app}><div style={S.error}>{error}</div></div>

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />

      <div style={S.header}>
        <div style={S.headerLeft}>
          <div style={S.logo}>Cocina</div>
          <div style={S.liveTag(isLive)}>{isLive ? '● En vivo' : '○ Conectando...'}</div>
        </div>
        <div style={S.headerRight}>{new Date().toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long' })}</div>
      </div>

      <div style={{ padding: '8px 16px 0', display: 'flex', justifyContent: 'flex-end' }}>
        <button onClick={handleLogout} style={{ background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 14px', fontSize: 12, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>Cerrar sesión</button>
      </div>

      <div style={S.tabs}>
        {['pendiente', 'preparando', 'listo'].map(tab => (
          <button key={tab} style={S.tab(activeTab === tab)} onClick={() => setActiveTab(tab)}>
            {ESTADO_CFG[tab].label}
            <span style={S.tabCount(counts[tab])}>{counts[tab]}</span>
          </button>
        ))}
      </div>

      {waiterCalls.length > 0 && (
        <div style={{ padding: '10px 16px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {waiterCalls.map(call => {
            const t = tables[call.table_id]
            return (
              <div key={call.id} style={{ background: '#2a1a00', border: '1px solid #d4a017', borderRadius: 12, padding: '10px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{ fontSize: 18 }}>🛎</span>
                  <div>
                    <div style={{ fontSize: 14, fontWeight: 500, color: '#f0e8d8' }}>
                      {t ? `Mesa ${t.numero} · ${t.zona.charAt(0).toUpperCase() + t.zona.slice(1)}` : 'Mesa'} llama al camarero
                    </div>
                    <div style={{ fontSize: 12, color: '#8a7560' }}>{timeAgo(call.created_at)} ago</div>
                  </div>
                </div>
                <button onClick={() => dismissWaiterCall(call.id)} style={{ background: '#d4a017', border: 'none', borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, color: '#111', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
                  Atendido
                </button>
              </div>
            )
          })}
        </div>
      )}

      <div style={S.grid}>
        {byTab.length === 0 ? (
          <div style={S.empty}>
            <div style={S.emptyIcon}>{activeTab === 'pendiente' ? '✓' : activeTab === 'preparando' ? '⏳' : '🍽'}</div>
            <div style={S.emptyText}>
              {activeTab === 'pendiente' ? 'Sin pedidos pendientes' : activeTab === 'preparando' ? 'Nada en preparación' : 'Nada listo aún'}
            </div>
          </div>
        ) : byTab.map(order => {
          const table = tables[order.table_id]
          const items = orderItems[order.id] || []
          const cfg = ESTADO_CFG[order.estado]
          return (
            <div key={order.id} style={S.card(order.estado)}>
              <div style={S.cardHeader}>
                <div style={S.mesaInfo}>
                  <div style={S.mesaNum}>
                    {table ? `Mesa ${table.numero}` : order.tipo === 'takeaway' ? 'Takeaway' : 'Mesa ?'}
                  </div>
                  <div style={S.mesaZona}>{table ? table.zona.charAt(0).toUpperCase() + table.zona.slice(1) : ''}</div>
                  {order.tipo === 'mesa' && tableSessions[order.table_id] && (
                    <div style={{ fontSize: 11, color: '#5a9c7a' }}>
                      🟢 Sesión desde {formatHora(tableSessions[order.table_id].abierta_at)}
                    </div>
                  )}
                </div>
                <div style={S.timeTag}>
                  <div style={{ marginBottom: 2 }}>{formatHora(order.created_at)}</div>
                  <div style={S.estadoTag(order.estado)}>
                    <span style={S.dot(order.estado)}></span>
                    {timeAgo(order.created_at)} ago
                  </div>
                </div>
              </div>

              <div style={S.divider} />

              <div style={S.itemsList}>
                {items.length > 0 ? items.map((item, i) => (
                  <div key={i}>
                    <div style={S.itemRow}>
                      <span style={S.itemName}>{item.nombre_snapshot}</span>
                      <span style={S.itemQty}>× {item.cantidad}</span>
                    </div>
                    {item.notas && (
                      <div style={{ fontSize: 12, color: '#f1c40f', background: '#2a2010', borderRadius: 6, padding: '4px 8px', marginTop: 4, marginBottom: 2 }}>
                        📝 {item.notas}
                      </div>
                    )}
                  </div>
                )) : (
                  <div style={{ fontSize: 12, color: '#555' }}>Cargando items...</div>
                )}
              </div>

              {order.notas && (
                <div style={{ fontSize: 12, color: '#f1c40f', background: '#2a2010', border: '0.5px solid #4a3a10', borderRadius: 8, padding: '6px 10px' }}>
                  📋 {order.notas}
                </div>
              )}

              {order.tipo === 'mesa' && (
                <div style={{ fontSize: 12, color: '#8a7560', display: 'flex', justifyContent: 'space-between' }}>
                  <span>Ref: {order.id.slice(0, 8).toUpperCase()}</span>
                  <span style={{ color: '#e8c97a', fontWeight: 500 }}>{parseFloat(order.total).toFixed(2).replace('.', ',')} €</span>
                </div>
              )}

              {cfg.next && (
                <button style={S.nextBtn(order.estado)} onClick={() => advanceEstado(order)}>
                  {cfg.nextLabel}
                </button>
              )}
            </div>
          )
        })}
      </div>

      <div style={S.notifBanner(!!notif)}>{notif}</div>
    </div>
  )
}
