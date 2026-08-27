import { useState, useEffect, Fragment } from 'react'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif", display: 'flex', flexDirection: 'column' },
  header: { background: '#0a0a0a', padding: '14px 20px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' },
  backBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 16, flex: 1, overflowY: 'auto' },
  searchBar: { marginBottom: 16 },
  input: { width: '100%', background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 8px 8px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '10px 8px', fontSize: 13, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  row: { background: '#1a1a1a' },
  puntos: { color: '#e8c97a', fontWeight: 600 },
  redeemBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 10px', fontSize: 11, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  success: { background: '#142a1a', border: '0.5px solid #2a5a3a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#7ae8a0', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 40, color: '#555', fontSize: 14 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 30, padding: 20 },
  modal: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 14, padding: 24, width: 340, maxWidth: '100%' },
  modalTitle: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 4 },
  modalSub: { fontSize: 13, color: '#8a7560', marginBottom: 16 },
  cancelBtn: { flex: 1, background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px', fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  confirmBtn: (disabled) => ({ flex: 1, background: disabled ? '#5a4a2a' : '#e8c97a', color: disabled ? '#8a7560' : '#111', border: 'none', borderRadius: 10, padding: '10px', fontSize: 14, fontWeight: 500, cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
}

// Nunca lee `clientes`/`clientes_movimientos` directo — todo pasa por
// las funciones fn_staff_* (ver sql/permisos_staff.sql), que verifican
// en cada llamada que este camarero siga activo y tenga el permiso
// 'clientes' antes de devolver o cambiar nada.
export default function CamareroClientes({ camarero, restaurantId, restaurant, onVolver }) {
  const [clientes, setClientes] = useState([])
  const [busqueda, setBusqueda] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [redeemCliente, setRedeemCliente] = useState(null)
  const [redeemCantidad, setRedeemCantidad] = useState('')
  const [redeemMotivo, setRedeemMotivo] = useState('')
  const [redeeming, setRedeeming] = useState(false)
  const [historialAbierto, setHistorialAbierto] = useState(null)
  const [movimientos, setMovimientos] = useState({})

  useEffect(() => { loadClientes() }, [])

  async function loadClientes() {
    setLoading(true)
    const { data, error: err } = await supabase.rpc('fn_staff_listar_clientes', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
    })
    setLoading(false)
    if (err) { setError(err.message); return }
    setClientes(data || [])
  }

  async function toggleHistorial(clienteId) {
    if (historialAbierto === clienteId) { setHistorialAbierto(null); return }
    setHistorialAbierto(clienteId)
    if (!movimientos[clienteId]) {
      const { data } = await supabase.rpc('fn_staff_historial_cliente', {
        p_restaurant_id: restaurantId,
        p_camarero_id: camarero.id,
        p_cliente_id: clienteId,
      })
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
    setError(null)
  }

  async function confirmarCanje() {
    const cantidad = parseInt(redeemCantidad, 10)
    if (!Number.isInteger(cantidad) || cantidad <= 0) {
      setError('Introduce una cantidad de puntos válida.')
      return
    }
    setRedeeming(true)
    const { error: err } = await supabase.rpc('fn_staff_canjear_puntos', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
      p_cliente_id: redeemCliente.id,
      p_cantidad: cantidad,
      p_motivo: redeemMotivo.trim() || null,
    })
    setRedeeming(false)
    if (err) { setError(err.message); return }
    setSuccess(`Canjeados ${cantidad} puntos de ${redeemCliente.nombre || redeemCliente.telefono}.`)
    setTimeout(() => setSuccess(null), 4000)
    setMovimientos(prev => {
      const { [redeemCliente.id]: _, ...rest } = prev
      return rest
    })
    setRedeemCliente(null)
    await loadClientes()
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <div style={S.app}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>Clientes</div>
        </div>
        <button style={S.backBtn} onClick={onVolver}>← Volver</button>
      </div>

      <div style={S.content}>
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
                <th style={S.th}>Puntos</th>
                <th style={S.th}></th>
              </tr>
            </thead>
            <tbody>
              {clientesFiltrados.map(c => (
                <Fragment key={c.id}>
                  <tr style={S.row}>
                    <td style={S.td}>
                      {c.nombre || '—'}
                      <div style={{ fontSize: 11, color: '#7a6a50' }}>{c.telefono}</div>
                    </td>
                    <td style={{ ...S.td, ...S.puntos }}>{c.puntos}</td>
                    <td style={{ ...S.td, display: 'flex', gap: 6 }}>
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
                      <td colSpan={3} style={{ ...S.td, paddingTop: 0 }}>
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
            <input
              style={{ ...S.input, marginBottom: 12 }}
              type="number"
              min="1"
              max={redeemCliente.puntos}
              placeholder="Cantidad de puntos a canjear"
              value={redeemCantidad}
              onChange={e => setRedeemCantidad(e.target.value)}
              autoFocus
            />
            <input
              style={{ ...S.input, marginBottom: 16 }}
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
