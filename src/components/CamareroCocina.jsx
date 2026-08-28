import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'

const ESTADO_CFG = {
  pendiente:  { label: 'Pendiente',  bg: '#2a1410', border: '#c0392b', dot: '#e74c3c', next: 'preparando',  nextLabel: 'Preparando →', prev: null },
  preparando: { label: 'Preparando', bg: '#2a2010', border: '#d4a017', dot: '#f1c40f', next: 'listo',       nextLabel: 'Listo ✓',      prev: 'pendiente' },
  listo:      { label: 'Listo',      bg: '#0f2a15', border: '#27ae60', dot: '#2ecc71', next: 'entregado',   nextLabel: 'Entregado 🍽', prev: 'preparando' },
}

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif", display: 'flex', flexDirection: 'column' },
  header: { background: '#0a0a0a', padding: '14px 20px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' },
  backBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 16, flex: 1, overflowY: 'auto', display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: 12, alignContent: 'start' },
  card: (estado) => ({ background: ESTADO_CFG[estado].bg, border: `1px solid ${ESTADO_CFG[estado].border}`, borderRadius: 12, padding: 14, display: 'flex', flexDirection: 'column', gap: 8 }),
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  mesaNum: { fontSize: 15, fontWeight: 600, color: '#f0e8d8' },
  time: { fontSize: 11, color: '#7a6a50' },
  dot: (estado) => ({ width: 8, height: 8, borderRadius: '50%', background: ESTADO_CFG[estado].dot, display: 'inline-block', marginRight: 6 }),
  itemRow: { display: 'flex', justifyContent: 'space-between', fontSize: 13 },
  nextBtn: (estado) => ({ width: '100%', padding: '9px 0', borderRadius: 8, border: 'none', background: ESTADO_CFG[estado].border, color: '#fff', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }),
  revertBtn: { background: 'transparent', border: '0.5px solid #4a443a', borderRadius: 8, padding: '9px 10px', color: '#8a7560', fontSize: 12, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  footer: { display: 'flex', gap: 8 },
  empty: { gridColumn: '1 / -1', textAlign: 'center', padding: 60, color: '#555', fontSize: 14 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
}

function timeAgo(dateStr) {
  const diff = Math.floor((Date.now() - new Date(dateStr)) / 1000)
  if (diff < 60) return `${diff}s`
  if (diff < 3600) return `${Math.floor(diff / 60)}m`
  return `${Math.floor(diff / 3600)}h`
}

// Versión acotada de Cocina.jsx para el personal con PIN: sin sectores
// ni estado de envío de delivery — solo pedidos activos y avanzar/
// revertir. Se actualiza por sondeo (cada 8s) en vez de Realtime,
// porque el rol anónimo no puede recibir esos eventos sin ampliar
// permisos de lectura sobre `orders`.
export default function CamareroCocina({ camarero, restaurantId, onVolver }) {
  const [pedidos, setPedidos] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    loadPedidos()
    const interval = setInterval(loadPedidos, 8000)
    return () => clearInterval(interval)
  }, [])

  async function loadPedidos(silencioso) {
    if (!silencioso) setLoading(true)
    const { data, error: err } = await supabase.rpc('fn_staff_listar_pedidos_cocina', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
    })
    setLoading(false)
    if (err) { setError(err.message); return }
    setPedidos(data || [])
  }

  async function cambiarEstado(pedido, nuevoEstado) {
    setPedidos(prev => nuevoEstado === 'entregado'
      ? prev.filter(p => p.id !== pedido.id)
      : prev.map(p => p.id === pedido.id ? { ...p, estado: nuevoEstado } : p))
    const { error: err } = await supabase.rpc('fn_staff_cambiar_estado_pedido', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
      p_order_id: pedido.id,
      p_nuevo_estado: nuevoEstado,
    })
    if (err) { setError(err.message); await loadPedidos(true) }
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <div style={S.app}>
      <div style={S.header}>
        <div style={S.logo}>👨‍🍳 Cocina</div>
        <button style={S.backBtn} onClick={onVolver}>← Volver</button>
      </div>

      {error && <div style={{ margin: 16, background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: 12, fontSize: 13, color: '#e87a7a' }}>{error}</div>}

      <div style={S.content}>
        {pedidos.length === 0 ? (
          <div style={S.empty}>No hay pedidos activos ahora mismo.</div>
        ) : (
          pedidos.map(p => {
            const cfg = ESTADO_CFG[p.estado]
            if (!cfg) return null
            return (
              <div key={p.id} style={S.card(p.estado)}>
                <div style={S.cardHeader}>
                  <div style={S.mesaNum}>{p.mesa_numero ? `Mesa ${p.mesa_numero}` : (p.tipo === 'takeaway' ? 'Take away' : 'Pedido')}</div>
                  <div style={S.time}>{timeAgo(p.created_at)}</div>
                </div>
                <div style={{ fontSize: 12, color: cfg.dot }}><span style={S.dot(p.estado)} />{cfg.label}</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                  {(p.items || []).map(item => (
                    <div key={item.id} style={S.itemRow}>
                      <span>{item.nombre}</span>
                      <span style={{ color: '#8a7560' }}>×{item.cantidad}</span>
                    </div>
                  ))}
                </div>
                {p.notas && <div style={{ fontSize: 12, color: '#8a7560', fontStyle: 'italic' }}>{p.notas}</div>}
                <div style={S.footer}>
                  {cfg.prev && (
                    <button style={S.revertBtn} onClick={() => cambiarEstado(p, cfg.prev)}>↩</button>
                  )}
                  <button style={{ ...S.nextBtn(p.estado), flex: 1 }} onClick={() => cambiarEstado(p, cfg.next)}>
                    {cfg.nextLabel}
                  </button>
                </div>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
