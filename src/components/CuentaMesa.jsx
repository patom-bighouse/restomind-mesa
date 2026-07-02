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
}

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
 * - onClose: () => void   (cerrar el modal sin hacer nada más)
 * - onConfirmCerrar: () => void | null   (si se pasa, muestra el
 *   botón "Confirmar cierre de mesa"; si no, es solo lectura)
 * - closing: boolean (estado de carga mientras se confirma el cierre)
 */
export default function CuentaMesa({ session, table, restaurantName, onClose, onConfirmCerrar, closing }) {
  const [loading, setLoading] = useState(true)
  const [pedidos, setPedidos] = useState([]) // [{ id, created_at, items: [...] }]
  const [error, setError] = useState(null)

  useEffect(() => { loadCuenta() }, [session?.id])

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
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }

  const total = pedidos.reduce((sum, p) => sum + parseFloat(p.total || 0), 0)

  function handlePrint() {
    window.print()
  }

  const ticket = (
    <div id="ticket-imprimible" style={{ display: 'none' }}>
      <div style={{ fontFamily: "'Courier New', monospace", width: 320, margin: '0 auto', color: '#000', fontSize: 13, lineHeight: 1.5 }}>
        <div style={{ textAlign: 'center', fontWeight: 'bold', fontSize: 16, marginBottom: 4 }}>{restaurantName}</div>
        <div style={{ textAlign: 'center', marginBottom: 10 }}>
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

          <div style={S.actions}>
            <button style={S.btnGhost} onClick={onClose}>Cerrar</button>
            <button style={S.btnGhost} onClick={handlePrint}>🖨 Imprimir</button>
            {onConfirmCerrar && (
              <button style={S.btnDanger} onClick={onConfirmCerrar} disabled={closing}>
                {closing ? 'Cerrando...' : 'Confirmar cierre'}
              </button>
            )}
          </div>
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
