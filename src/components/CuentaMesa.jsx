import { useState, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { supabase } from '../lib/supabase'

const S = {
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 },
  modal: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 16, width: '100%', maxWidth: 440, maxHeight: '90vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' },
  header: { padding: '20px 24px 12px', borderBottom: '0.5px solid #2a2a2a' },
  restName: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' },
  mesaInfo: { fontSize: 13, color: '#8a7560', marginTop: 4 },
  body: { padding: '16px 24px', overflowY: 'auto', flex: 1 },
  pedidoBlock: { marginBottom: 18 },
  pedidoHora: { fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 8, paddingBottom: 6, borderBottom: '0.5px solid #2a2a2a' },
  itemRow: { display: 'flex', justifyContent: 'space-between', fontSize: 14, color: '#f0e8d8', padding: '4px 0', gap: 12 },
  itemNombre: { flex: 1 },
  itemNota: { fontSize: 12, color: '#7a6a50', fontStyle: 'italic', marginTop: 2 },
  itemPrecio: { color: '#c4a85a', whiteSpace: 'nowrap' },
  pedidoSubtotal: { display: 'flex', justifyContent: 'flex-end', fontSize: 13, color: '#8a7560', marginTop: 6, paddingTop: 6, borderTop: '0.5px dashed #2a2a2a' },
  totalRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', padding: '16px 24px', borderTop: '0.5px solid #3a2e20', background: '#141414' },
  totalLabel: { fontSize: 15, color: '#f0e8d8', fontWeight: 500 },
  totalValue: { fontFamily: "'Playfair Display', serif", fontSize: 26, color: '#e8c97a' },
  actions: { display: 'flex', gap: 10, padding: '16px 24px', borderTop: '0.5px solid #2a2a2a' },
  btnGhost: { flex: 1, background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: 12, fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  btnPrimary: { flex: 1, background: '#e8c97a', border: 'none', borderRadius: 10, padding: 12, fontSize: 14, fontWeight: 500, color: '#111', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  btnDanger: { flex: 1, background: 'transparent', border: '0.5px solid #6a2e20', borderRadius: 10, padding: 12, fontSize: 14, fontWeight: 500, color: '#e87a7a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  loading: { padding: 40, textAlign: 'center', color: '#555', fontSize: 13 },
  empty: { padding: '20px 0', textAlign: 'center', color: '#555', fontSize: 13 },
  cobroSection: { padding: '16px 24px', borderTop: '0.5px solid #2a2a2a' },
  cobroTitle: { fontSize: 13, fontWeight: 500, color: '#c4a85a', marginBottom: 10 },
  cobroProgress: (cubierto) => ({ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', background: cubierto ? '#0f2a15' : '#2a1f10', border: `0.5px solid ${cubierto ? '#27ae60' : '#8a6a20'}`, borderRadius: 10, padding: '10px 14px', marginBottom: 12 }),
  cobroProgressLabel: { fontSize: 12, color: '#8a7560' },
  cobroProgressValue: (cubierto) => ({ fontSize: 15, fontWeight: 600, color: cubierto ? '#2ecc71' : '#e8b84a' }),
  pagoRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 13, color: '#f0e8d8', padding: '6px 0', borderBottom: '0.5px solid #222' },
  pagoMeta: { fontSize: 11, color: '#7a6a50' },
  pagoAnularBtn: { background: 'transparent', border: 'none', color: '#8a5050', fontSize: 11, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'underline' },
  addPagoRow: { display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' },
  addPagoInput: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '9px 10px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', width: 90 },
  addPagoSelect: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '9px 10px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', flex: 1, minWidth: 100 },
  addPagoBtn: { background: '#c4a85a', border: 'none', borderRadius: 8, padding: '9px 16px', fontSize: 13, fontWeight: 500, color: '#111', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  cierreBloqueado: { fontSize: 11, color: '#e8b84a', textAlign: 'center', width: '100%', marginTop: -4, marginBottom: 4 },
  exencionToggle: { fontSize: 11, color: '#6a5a45', textDecoration: 'underline', cursor: 'pointer', textAlign: 'center', width: '100%', marginTop: 2, background: 'none', border: 'none', fontFamily: "'Inter', sans-serif" },
  exencionBox: { padding: '0 24px 16px' },
  exencionInput: { width: '100%', background: '#111', border: '0.5px solid #5a4020', borderRadius: 8, padding: '9px 12px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box', marginBottom: 8 },
  exencionBtn: (disabled) => ({ width: '100%', background: 'transparent', border: '0.5px solid #6a5020', borderRadius: 8, padding: 10, fontSize: 12, fontWeight: 500, color: disabled ? '#555' : '#c99a4a', cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
}

const METODOS = [
  { value: 'tarjeta', label: '💳 Tarjeta' },
  { value: 'efectivo', label: '💶 Efectivo' },
  { value: 'bizum', label: '📱 Bizum' },
  { value: 'otro', label: '🔹 Otro' },
]

/**
 * Modal con el detalle de consumo de una sesión de mesa (todos los
 * pedidos hechos mientras estuvo abierta), pensado para que el
 * camarero lo consulte durante el servicio ("ver cuenta") o lo use
 * como resumen final antes de cerrar la mesa ("cerrar mesa").
 *
 * Props:
 * - session: { id, abierta_at }
 * - table: { numero, zona }
 * - restaurantName: string
 * - restaurantId: string (necesario para registrar cobros)
 * - onClose: () => void   (cerrar el modal sin hacer nada más)
 * - onConfirmCerrar: () => void | null   (si se pasa, muestra el
 *   botón "Confirmar cierre de mesa"; si no, es solo lectura)
 * - onConfirmExencion: (motivo: string) => void | null   (si se pasa,
 *   habilita la opción "Invitación de la casa" para cerrar sin
 *   cobro completo, dejando un motivo registrado)
 * - closing: boolean (estado de carga mientras se confirma el cierre)
 */
export default function CuentaMesa({ session, table, restaurantName, restaurantId, onClose, onConfirmCerrar, onConfirmExencion, closing }) {
  const [loading, setLoading] = useState(true)
  const [pedidos, setPedidos] = useState([]) // [{ id, created_at, items: [...] }]
  const [pagos, setPagos] = useState([])
  const [error, setError] = useState(null)
  const [montoInput, setMontoInput] = useState('')
  const [metodoInput, setMetodoInput] = useState('tarjeta')
  const [addingPago, setAddingPago] = useState(false)
  const [showExencion, setShowExencion] = useState(false)
  const [motivoExencion, setMotivoExencion] = useState('')

  useEffect(() => { loadCuenta() }, [session?.id])

  useEffect(() => {
    if (!session?.id) return
    const channel = supabase
      .channel(`cuenta-mesa-pagos-${session.id}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'table_session_payments',
        filter: `table_session_id=eq.${session.id}`
      }, () => loadPagos())
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [session?.id])

  async function loadPagos() {
    const { data } = await supabase
      .from('table_session_payments')
      .select('id, monto, metodo_pago, estado, created_at')
      .eq('table_session_id', session.id)
      .eq('estado', 'registrado')
      .order('created_at', { ascending: true })
    setPagos(data || [])
  }

  async function loadCuenta() {
    if (!session?.id) return
    setLoading(true)
    setError(null)
    try {
      const { data: orders, error: oErr } = await supabase
        .from('orders')
        .select('id, created_at, total, notas')
        .eq('table_session_id', session.id)
        .neq('estado', 'cancelado')
        .order('created_at', { ascending: true })
      if (oErr) throw oErr

      const orderIds = (orders || []).map(o => o.id)
      let items = []
      if (orderIds.length > 0) {
        const { data: itemsData, error: iErr } = await supabase
          .from('order_items')
          .select('id, order_id, nombre_snapshot, precio_snapshot, cantidad, notas')
          .in('order_id', orderIds)
        if (iErr) throw iErr
        items = itemsData || []
      }

      const armados = (orders || []).map(o => ({
        ...o,
        items: items.filter(i => i.order_id === o.id),
      }))
      setPedidos(armados)
      await loadPagos()
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }

  const total = pedidos.reduce((sum, p) => sum + parseFloat(p.total || 0), 0)
  const totalPagado = pagos.reduce((sum, p) => sum + parseFloat(p.monto || 0), 0)
  const falta = Math.max(0, total - totalPagado)
  const cubierto = falta <= 0.01

  async function addPago() {
    const monto = parseFloat(montoInput.replace(',', '.'))
    if (!monto || monto <= 0) return
    setAddingPago(true)
    setError(null)
    const { error: err } = await supabase
      .from('table_session_payments')
      .insert({ table_session_id: session.id, restaurant_id: restaurantId, monto, metodo_pago: metodoInput })
    setAddingPago(false)
    if (err) { setError(err.message); return }
    setMontoInput('')
    await loadPagos()
  }

  async function voidPago(id) {
    if (!window.confirm('¿Anular este cobro? Volverá a contar como pendiente.')) return
    const { error: err } = await supabase
      .from('table_session_payments')
      .update({ estado: 'anulado' })
      .eq('id', id)
    if (err) { setError(err.message); return }
    await loadPagos()
  }

  function handlePrint() {
    window.print()
  }

  const ticket = (
    <div id="ticket-imprimible" style={{ display: 'none' }}>
      <div style={{ fontFamily: "'Courier New', monospace", width: 320, color: '#000', fontSize: 13, lineHeight: 1.5, textAlign: 'left' }}>
        <div style={{ fontWeight: 'bold', fontSize: 16, marginBottom: 4 }}>{restaurantName}</div>
        <div style={{ marginBottom: 10 }}>
          Mesa {table?.numero} · {table?.zona}<br />
          {session?.abierta_at && new Date(session.abierta_at).toLocaleString('es-ES')}
        </div>
        <div style={{ borderTop: '1px dashed #000', margin: '8px 0' }} />
        {pedidos.map(pedido => (
          <div key={pedido.id} style={{ marginBottom: 10 }}>
            <div style={{ fontSize: 11, marginBottom: 4 }}>
              — Pedido {new Date(pedido.created_at).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })} —
            </div>
            {pedido.items.map(item => (
              <div key={item.id} style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>{item.cantidad}× {item.nombre_snapshot}</span>
                <span>{(parseFloat(item.precio_snapshot) * item.cantidad).toFixed(2).replace('.', ',')}€</span>
              </div>
            ))}
            {pedido.notas && <div style={{ fontSize: 11 }}>Nota: {pedido.notas}</div>}
          </div>
        ))}
        <div style={{ borderTop: '1px dashed #000', margin: '8px 0' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 'bold', fontSize: 15 }}>
          <span>TOTAL</span>
          <span>{total.toFixed(2).replace('.', ',')}€</span>
        </div>
        {pagos.length > 0 && (
          <>
            <div style={{ borderTop: '1px dashed #000', margin: '8px 0' }} />
            <div style={{ fontSize: 11, marginBottom: 4 }}>— Cobros registrados —</div>
            {pagos.map(p => (
              <div key={p.id} style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>{METODOS.find(m => m.value === p.metodo_pago)?.label || p.metodo_pago}</span>
                <span>{parseFloat(p.monto).toFixed(2).replace('.', ',')}€</span>
              </div>
            ))}
          </>
        )}
      </div>
    </div>
  )

  return (
    <>
      <style>{`
        @media print {
          #root { display: none !important; }
          #ticket-imprimible { display: block !important; }
        }
      `}</style>

      <div style={S.overlay} onClick={e => { if (e.target === e.currentTarget) onClose() }}>
        <div style={S.modal}>
          <div style={S.header}>
            <div style={S.restName}>{restaurantName}</div>
            <div style={S.mesaInfo}>
              Mesa {table?.numero} · {table?.zona}
              {session?.abierta_at && (
                <> · desde {new Date(session.abierta_at).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}</>
              )}
            </div>
          </div>

          <div style={S.body}>
            {loading && <div style={S.loading}>Cargando cuenta...</div>}
            {error && <div style={{ ...S.loading, color: '#e87a7a' }}>{error}</div>}
            {!loading && !error && pedidos.length === 0 && (
              <div style={S.empty}>Todavía no hay pedidos en esta sesión.</div>
            )}
            {!loading && !error && pedidos.map(pedido => (
              <div key={pedido.id} style={S.pedidoBlock}>
                <div style={S.pedidoHora}>
                  Pedido de las {new Date(pedido.created_at).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}
                </div>
                {pedido.items.map(item => (
                  <div key={item.id} style={S.itemRow}>
                    <div style={S.itemNombre}>
                      {item.cantidad}× {item.nombre_snapshot}
                      {item.notas && <div style={S.itemNota}>{item.notas}</div>}
                    </div>
                    <div style={S.itemPrecio}>
                      {(parseFloat(item.precio_snapshot) * item.cantidad).toFixed(2).replace('.', ',')}€
                    </div>
                  </div>
                ))}
                {pedido.notas && <div style={S.itemNota}>Nota del pedido: {pedido.notas}</div>}
                <div style={S.pedidoSubtotal}>Subtotal: {parseFloat(pedido.total || 0).toFixed(2).replace('.', ',')}€</div>
              </div>
            ))}
          </div>

          <div style={S.totalRow}>
            <span style={S.totalLabel}>Total</span>
            <span style={S.totalValue}>{total.toFixed(2).replace('.', ',')}€</span>
          </div>

          <div style={S.cobroSection}>
            <div style={S.cobroTitle}>Cobro</div>

            <div style={S.cobroProgress(cubierto)}>
              <span style={S.cobroProgressLabel}>
                {cubierto ? '✅ Cobrado en su totalidad' : `Cobrado ${totalPagado.toFixed(2).replace('.', ',')}€ de ${total.toFixed(2).replace('.', ',')}€`}
              </span>
              {!cubierto && <span style={S.cobroProgressValue(false)}>Faltan {falta.toFixed(2).replace('.', ',')}€</span>}
            </div>

            {pagos.map(p => (
              <div key={p.id} style={S.pagoRow}>
                <div>
                  <span>{p.monto.toFixed ? p.monto.toFixed(2).replace('.', ',') : parseFloat(p.monto).toFixed(2).replace('.', ',')}€</span>
                  {' · '}
                  <span>{METODOS.find(m => m.value === p.metodo_pago)?.label || p.metodo_pago}</span>
                  <div style={S.pagoMeta}>{new Date(p.created_at).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}</div>
                </div>
                <button style={S.pagoAnularBtn} onClick={() => voidPago(p.id)}>Anular</button>
              </div>
            ))}

            {!cubierto && (
              <div style={S.addPagoRow}>
                <input
                  style={S.addPagoInput}
                  type="number"
                  step="0.01"
                  placeholder={falta.toFixed(2)}
                  value={montoInput}
                  onChange={e => setMontoInput(e.target.value)}
                />
                <select style={S.addPagoSelect} value={metodoInput} onChange={e => setMetodoInput(e.target.value)}>
                  {METODOS.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
                </select>
                <button style={S.addPagoBtn} onClick={addPago} disabled={addingPago}>
                  {addingPago ? '...' : '+ Registrar'}
                </button>
              </div>
            )}
          </div>

          <div style={S.actions}>
            <button style={S.btnGhost} onClick={onClose}>Cerrar</button>
            <button style={S.btnGhost} onClick={handlePrint}>🖨 Imprimir</button>
            {onConfirmCerrar && (
              <button style={S.btnDanger} onClick={onConfirmCerrar} disabled={closing || !cubierto} title={!cubierto ? `Faltan ${falta.toFixed(2).replace('.', ',')}€ por cobrar` : ''}>
                {closing ? 'Cerrando...' : 'Confirmar cierre'}
              </button>
            )}
          </div>
          {onConfirmCerrar && !cubierto && (
            <div style={S.cierreBloqueado}>Registrá el cobro completo para poder cerrar la mesa</div>
          )}

          {onConfirmExencion && !cubierto && (
            <div style={S.exencionBox}>
              {!showExencion ? (
                <button style={S.exencionToggle} onClick={() => setShowExencion(true)}>
                  ¿Es una invitación de la casa? Cerrar sin cobro completo
                </button>
              ) : (
                <>
                  <input
                    style={S.exencionInput}
                    placeholder="Motivo (obligatorio, ej. cumpleaños del cliente)"
                    value={motivoExencion}
                    onChange={e => setMotivoExencion(e.target.value)}
                  />
                  <button
                    style={S.exencionBtn(closing || !motivoExencion.trim())}
                    disabled={closing || !motivoExencion.trim()}
                    onClick={() => onConfirmExencion(motivoExencion.trim())}
                  >
                    {closing ? 'Cerrando...' : `🏠 Cerrar como invitación de la casa (faltaban ${falta.toFixed(2).replace('.', ',')}€)`}
                  </button>
                </>
              )}
            </div>
          )}
        </div>
      </div>

      {/* El ticket se monta como hijo directo de <body> (fuera de #root)
          para poder ocultar TODA la app al imprimir sin ambigüedad,
          y para que el ticket quede en flujo normal de documento
          (sin heredar el position:fixed del overlay), así el
          navegador lo pagina en una sola hoja. */}
      {createPortal(ticket, document.body)}
    </>
  )
}
