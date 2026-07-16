import { useState, useEffect, useCallback, useRef } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'

const S = {
  app: { minHeight: '100vh', background: '#1a1410', color: '#f0e8d8', display: 'flex', flexDirection: 'column', maxWidth: 480, margin: '0 auto' },
  header: { background: '#0f0c09', padding: '16px 20px 12px', borderBottom: '0.5px solid #3a2e20', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  sub: { fontSize: 11, color: '#8a7560', marginTop: 2 },
  badge: { fontSize: 11, color: '#8a7560', background: '#1a1410', border: '0.5px solid #3a2e20', padding: '4px 10px', borderRadius: 20 },
  catsBar: { display: 'flex', gap: 8, padding: '14px 20px 0', overflowX: 'auto', scrollbarWidth: 'none', flexShrink: 0 },
  cat: (active) => ({ fontSize: 13, fontWeight: 500, padding: '6px 14px', borderRadius: 20, border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, background: active ? '#e8c97a' : 'transparent', color: active ? '#1a1410' : '#8a7560', cursor: 'pointer', whiteSpace: 'nowrap', transition: 'all 0.15s' }),
  scroll: { flex: 1, overflowY: 'auto', paddingBottom: 100 },
  secTitle: { fontFamily: "'Playfair Display', serif", fontSize: 15, color: '#c4a85a', padding: '18px 20px 10px', letterSpacing: '0.03em' },
  itemsWrap: { padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 10 },
  item: { background: '#221c14', border: '0.5px solid #3a2e20', borderRadius: 12, padding: 14, display: 'flex', alignItems: 'center', gap: 12 },
  emoji: { fontSize: 26, width: 44, height: 44, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#1a1410', borderRadius: 10, flexShrink: 0 },
  info: { flex: 1, minWidth: 0 },
  name: { fontSize: 14, fontWeight: 500, color: '#f0e8d8', marginBottom: 3 },
  desc: { fontSize: 12, color: '#7a6a50', lineHeight: 1.4 },
  price: { fontSize: 15, fontWeight: 500, color: '#e8c97a', marginTop: 4 },
  qty: { display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 },
  btn: { width: 28, height: 28, borderRadius: '50%', border: '0.5px solid #4a3c25', background: '#1a1410', color: '#e8c97a', fontSize: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', lineHeight: 1 },
  qnum: { fontSize: 14, fontWeight: 500, color: '#f0e8d8', minWidth: 16, textAlign: 'center' },
  callBtn: { margin: '16px 20px 4px', background: '#221c14', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' },
  callTitle: { fontSize: 14, fontWeight: 500, color: '#f0e8d8', marginBottom: 2 },
  callSub: { fontSize: 12, color: '#7a6a50' },
  cartBar: (visible) => ({ position: 'fixed', bottom: 16, left: '50%', transform: 'translateX(-50%)', width: 'calc(100% - 40px)', maxWidth: 440, background: '#e8c97a', borderRadius: 12, padding: '14px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer', opacity: visible ? 1 : 0, pointerEvents: visible ? 'all' : 'none', transition: 'opacity 0.2s', zIndex: 20 }),
  cartBadge: { background: '#1a1410', color: '#e8c97a', fontSize: 12, fontWeight: 500, width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' },
  overlay: (open) => ({ position: 'fixed', inset: 0, background: 'rgba(10,8,5,0.85)', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', opacity: open ? 1 : 0, pointerEvents: open ? 'all' : 'none', transition: 'opacity 0.2s', zIndex: 30 }),
  sheet: { background: '#1a1410', borderRadius: '16px 16px 0 0', borderTop: '0.5px solid #3a2e20', padding: 20, position: 'relative', maxHeight: '80vh', overflowY: 'auto' },
  sheetTitle: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 16 },
  oItem: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 0', borderBottom: '0.5px solid #2a2018' },
  oName: { fontSize: 14, color: '#f0e8d8' },
  oQty: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  oPrice: { fontSize: 14, fontWeight: 500, color: '#e8c97a' },
  totalRow: { display: 'flex', justifyContent: 'space-between', padding: '14px 0 0' },
  confirmBtn: (disabled) => ({ width: '100%', background: disabled ? '#5a4a2a' : '#e8c97a', color: disabled ? '#8a7560' : '#1a1410', border: 'none', borderRadius: 10, padding: 14, fontSize: 15, fontWeight: 500, fontFamily: "'Inter', sans-serif", cursor: disabled ? 'not-allowed' : 'pointer', marginTop: 14 }),
  closeBtn: { position: 'absolute', top: 16, right: 16, background: '#2a2018', border: 'none', color: '#8a7560', width: 28, height: 28, borderRadius: '50%', cursor: 'pointer', fontSize: 18, display: 'flex', alignItems: 'center', justifyContent: 'center' },
  center: { textAlign: 'center', padding: '20px 0 10px' },
  big: { fontSize: 36, marginBottom: 10 },
  ctitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 8 },
  csub: { fontSize: 13, color: '#7a6a50', lineHeight: 1.5 },
  loading: { display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '60vh', gap: 12 },
  loadingText: { fontSize: 14, color: '#7a6a50' },
  error: { margin: 20, background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 12, padding: 16, fontSize: 13, color: '#e87a7a' },
  ref: { color: '#e8c97a', fontSize: 12, marginTop: 8 },
  noteInput: { width: '100%', background: '#221c14', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 10px', fontSize: 12, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', marginTop: 4, boxSizing: 'border-box' },
  noteLabel: { fontSize: 11, color: '#7a6a50', marginTop: 2, cursor: 'pointer' },
  notesTextarea: { width: '100%', background: '#221c14', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 12px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', resize: 'vertical', minHeight: 50, boxSizing: 'border-box', marginTop: 6 },
}

export default function Mesa() {
  const { token } = useParams()
  const [restaurant, setRestaurant] = useState(null)
  const [table, setTable] = useState(null)
  const [session, setSession] = useState(null)
  const [categories, setCategories] = useState([])
  const [items, setItems] = useState([])
  const [cart, setCart] = useState({})
  const [activeCat, setActiveCat] = useState('todos')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [overlay, setOverlay] = useState(null) // 'cart' | 'success' | 'waiter' | 'sending'
  const [orderId, setOrderId] = useState(null)
  const [sendError, setSendError] = useState(null)
  const [orderNote, setOrderNote] = useState('')
  const [editingNoteFor, setEditingNoteFor] = useState(null)
  const [misPedidos, setMisPedidos] = useState([])
  const [loadingPedidos, setLoadingPedidos] = useState(false)
  const prevSessionIdRef = useRef(undefined)

  // Cada vez que la sesión de la mesa cambia (se cierra, se reabre,
  // o pasa a ser una sesión distinta), vaciamos cualquier carrito sin
  // enviar. Sin esto, un pedido armado durante una sesión podía
  // quedar "flotando" en el navegador del cliente y reaparecer como
  // si fuera un pedido válido cuando la mesa se reabre para otro
  // grupo de comensales.
  useEffect(() => {
    const currentId = session?.id ?? null
    if (prevSessionIdRef.current !== undefined && prevSessionIdRef.current !== currentId) {
      setCart({})
      setOrderNote('')
      setEditingNoteFor(null)
      setSendError(null)
    }
    prevSessionIdRef.current = currentId
  }, [session?.id])

  async function loadMenu(restaurantId) {
    const { data: cats } = await supabase
      .from('categories')
      .select('id, nombre, orden')
      .eq('restaurant_id', restaurantId)
      .eq('activa', true)
      .order('orden')
    setCategories(cats || [])

    const { data: menuItems } = await supabase
      .from('menu_items')
      .select('id, nombre, descripcion, precio, emoji, foto_url, category_id, orden')
      .eq('restaurant_id', restaurantId)
      .eq('disponible', true)
      .order('orden')
    setItems(menuItems || [])
  }

  useEffect(() => {
    async function load() {
      try {
        const { data: tableRows, error: tErr } = await supabase
          .rpc('get_table_by_qr', { p_token: token })
        if (tErr || !tableRows || tableRows.length === 0) throw new Error('Mesa no encontrada')
        const tableData = tableRows[0]
        setTable(tableData)

        const { data: rest } = await supabase
          .from('restaurants')
          .select('nombre')
          .eq('id', tableData.restaurant_id)
          .single()
        setRestaurant(rest)

        const { data: sessionData } = await supabase
          .from('table_sessions')
          .select('id, estado, abierta_at')
          .eq('table_id', tableData.id)
          .eq('estado', 'abierta')
          .maybeSingle()
        setSession(sessionData || null)

        await loadMenu(tableData.restaurant_id)
      } catch (e) {
        setError(e.message)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [token])

  // Realtime: refresca la carta cuando cambian categorías o platos
  useEffect(() => {
    if (!table?.restaurant_id) return
    const channel = supabase
      .channel('mesa-menu-' + table.id)
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'menu_items',
        filter: `restaurant_id=eq.${table.restaurant_id}`
      }, () => loadMenu(table.restaurant_id))
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'categories',
        filter: `restaurant_id=eq.${table.restaurant_id}`
      }, () => loadMenu(table.restaurant_id))
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'tables',
        filter: `id=eq.${table.id}`
      }, (payload) => setTable(prev => ({ ...prev, ...payload.new })))
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'table_sessions',
        filter: `table_id=eq.${table.id}`
      }, (payload) => {
        if (payload.eventType === 'DELETE') { setSession(null); return }
        const row = payload.new
        if (row.estado === 'abierta') setSession(row)
        else setSession(prev => (prev && prev.id === row.id) ? null : prev)
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [table?.restaurant_id, table?.id])

  const change = useCallback((item, delta) => {
    setCart(prev => {
      const curr = prev[item.id]?.qty || 0
      const next = Math.max(0, curr + delta)
      if (next === 0) {
        const { [item.id]: _, ...rest } = prev
        return rest
      }
      return { ...prev, [item.id]: { qty: next, nombre: item.nombre, precio: parseFloat(item.precio), nota: prev[item.id]?.nota || '' } }
    })
  }, [])

  const updateNote = useCallback((itemId, nota) => {
    setCart(prev => prev[itemId] ? { ...prev, [itemId]: { ...prev[itemId], nota } } : prev)
  }, [])

  const cartCount = Object.values(cart).reduce((a, b) => a + b.qty, 0)
  const cartTotal = Object.values(cart).reduce((s, i) => s + i.precio * i.qty, 0)

  const filteredCats = activeCat === 'todos' ? categories : categories.filter(c => c.id === activeCat)

  async function confirmOrder() {
    if (!session) {
      setSendError('La mesa ya no tiene una sesión activa. Avisa al camarero.')
      setOverlay('cart')
      return
    }
    setOverlay('sending')
    setSendError(null)
    try {
      const cartItems = Object.entries(cart).map(([id, v]) => ({ id, ...v }))
      const itemsPayload = cartItems.map(i => ({
        menu_item_id: i.id,
        cantidad: i.qty,
        notas: i.nota?.trim() || null,
      }))

      // fn_registrar_pedido decide, según el modo de Cocina del restaurante,
      // si este envío se suma a un pedido "pendiente" ya abierto de esta
      // misma mesa/sesión (modo agrupado) o si crea uno nuevo (modo orden
      // de llegada). El mismo criterio se usa desde el flujo de WhatsApp,
      // así que no se decide nada de esto acá en el cliente.
      const { data: newOrderId, error: rpcErr } = await supabase.rpc('fn_registrar_pedido', {
        p_table_session_id: session.id,
        p_items: itemsPayload,
        p_notas: orderNote.trim() || null,
      })
      if (rpcErr) throw rpcErr

      setOrderId(newOrderId)
      setCart({})
      setOrderNote('')
      setEditingNoteFor(null)
      setOverlay('success')
    } catch (e) {
      // Si la sesión se cerró mientras el cliente tenía el carrito
      // abierto (ej. se le bloqueó el teléfono y perdió la conexión
      // en tiempo real), fn_registrar_pedido rechaza el pedido con una
      // excepción propia (ya no es un error de RLS, porque la función
      // corre como security definer). En vez de mostrar ese mensaje
      // técnico, confirmamos el estado real de la mesa y mandamos al
      // cliente a la pantalla de espera correspondiente.
      const esMesaCerrada = /no existe o ya está cerrada/i.test(e.message || '')
      if (esMesaCerrada) {
        const { data: sessionActual } = await supabase
          .from('table_sessions')
          .select('id, estado, abierta_at')
          .eq('table_id', table.id)
          .eq('estado', 'abierta')
          .maybeSingle()
        setSession(sessionActual || null)
        setSendError(null)
        setOverlay(null)
      } else {
        setSendError(e.message)
        setOverlay('cart')
      }
    }
  }

  async function callWaiter() {
    setOverlay('waiter')
    await supabase.from('waiter_calls').insert({
      restaurant_id: table.restaurant_id,
      table_id: table.id,
      estado: 'pendiente'
    })
    setTimeout(() => setOverlay(null), 2500)
  }

  async function loadMisPedidos() {
    if (!session?.id) return
    setLoadingPedidos(true)
    const { data, error: e } = await supabase.rpc('get_session_orders', {
      p_session_id: session.id,
      p_qr_token: token,
    })
    setLoadingPedidos(false)
    if (e || !data) { setMisPedidos([]); return }

    const porPedido = {}
    data.forEach(row => {
      if (!porPedido[row.order_id]) {
        porPedido[row.order_id] = {
          id: row.order_id,
          created_at: row.order_created_at,
          estado: row.order_estado,
          total: row.order_total,
          notas: row.order_notas,
          items: [],
        }
      }
      if (row.item_id) {
        porPedido[row.order_id].items.push({
          id: row.item_id,
          nombre: row.item_nombre,
          precio: row.item_precio,
          cantidad: row.item_cantidad,
          notas: row.item_notas,
        })
      }
    })
    setMisPedidos(Object.values(porPedido))
  }

  function abrirMisPedidos() {
    setOverlay('misPedidos')
    loadMisPedidos()
  }

  useEffect(() => {
    if (overlay !== 'misPedidos') return
    const interval = setInterval(loadMisPedidos, 15000)
    return () => clearInterval(interval)
  }, [overlay, session?.id])

  const ESTADO_LABEL = {
    pendiente: '🕒 Recibido',
    preparando: '👨‍🍳 En preparación',
    listo: '✅ Listo para servir',
    entregado: '🍽 Entregado',
  }

  if (loading) return (
    <div style={S.app}>
      <div style={S.loading}>
        <div style={{ fontSize: 28, color: '#e8c97a' }}>⏳</div>
        <div style={S.loadingText}>Cargando carta...</div>
      </div>
    </div>
  )

  if (error) return (
    <div style={S.app}>
      <div style={S.error}>{error}</div>
    </div>
  )

  if (table && !table.activa) return (
    <div style={S.app}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
        </div>
        <div style={S.badge}>Mesa {table?.numero}</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, padding: 40, textAlign: 'center', gap: 16 }}>
        <div style={{ fontSize: 40 }}>🚫</div>
        <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' }}>Mesa no disponible</div>
        <div style={{ fontSize: 14, color: '#7a6a50', lineHeight: 1.6 }}>Esta mesa está temporalmente desactivada.<br />Por favor, consulta con el personal del restaurante.</div>
      </div>
    </div>
  )

  if (table && table.activa && !session) return (
    <div style={S.app}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
        </div>
        <div style={S.badge}>Mesa {table?.numero}</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, padding: 40, textAlign: 'center', gap: 16 }}>
        <div style={{ fontSize: 40 }}>🕒</div>
        <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' }}>Espera a que te atiendan</div>
        <div style={{ fontSize: 14, color: '#7a6a50', lineHeight: 1.6 }}>El camarero abrirá tu mesa en breve.<br />En cuanto lo haga, podrás ver la carta y pedir aquí mismo.</div>
        {overlay === 'waiter' ? (
          <div style={{ fontSize: 13, color: '#e8c97a', marginTop: 8 }}>🛎 Camarero avisado, ¡ya vamos!</div>
        ) : (
          <div style={{ ...S.callBtn, margin: '8px 0 0', width: '100%', boxSizing: 'border-box', justifyContent: 'center' }} onClick={callWaiter}>
            <span style={{ fontSize: 20 }}>🛎</span>
            <div>
              <div style={S.callTitle}>Avisar que ya llegué</div>
              <div style={S.callSub}>Toca aquí para llamar al camarero</div>
            </div>
          </div>
        )}
      </div>
    </div>
  )

  return (
    <div style={S.app}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
          <div style={S.sub}>Bienvenido · Pide desde la mesa</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
          <div style={S.badge}>Mesa {table?.numero} · {table?.zona?.charAt(0).toUpperCase() + table?.zona?.slice(1)}</div>
          <button onClick={abrirMisPedidos} style={{ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 20, padding: '4px 12px', fontSize: 11, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
            🧾 Mis pedidos
          </button>
        </div>
      </div>

      <div style={S.catsBar}>
        <button style={S.cat(activeCat === 'todos')} onClick={() => setActiveCat('todos')}>Todos</button>
        {categories.map(c => (
          <button key={c.id} style={S.cat(activeCat === c.id)} onClick={() => setActiveCat(c.id)}>{c.nombre}</button>
        ))}
      </div>

      <div style={S.scroll}>
        {filteredCats.map(cat => {
          const catItems = items.filter(i => i.category_id === cat.id)
          if (!catItems.length) return null
          return (
            <div key={cat.id}>
              <div style={S.secTitle}>{cat.nombre}</div>
              <div style={S.itemsWrap}>
                {catItems.map(item => (
                  <div key={item.id} style={S.item}>
                    <div style={S.emoji}>
                      {item.foto_url
                        ? <img src={item.foto_url} alt={item.nombre} style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 10 }} />
                        : (item.emoji || '🍽')}
                    </div>
                    <div style={S.info}>
                      <div style={S.name}>{item.nombre}</div>
                      {item.descripcion && <div style={S.desc}>{item.descripcion}</div>}
                      <div style={S.price}>{parseFloat(item.precio).toFixed(2).replace('.', ',')} €</div>
                    </div>
                    <div style={S.qty}>
                      <button style={S.btn} onClick={() => change(item, -1)}>−</button>
                      <span style={S.qnum}>{cart[item.id]?.qty || 0}</span>
                      <button style={S.btn} onClick={() => change(item, 1)}>+</button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )
        })}

        <div style={S.callBtn} onClick={callWaiter}>
          <span style={{ fontSize: 20 }}>🛎</span>
          <div>
            <div style={S.callTitle}>Llamar al camarero</div>
            <div style={S.callSub}>Te atendemos en un momento</div>
          </div>
        </div>
      </div>

      <div style={S.cartBar(cartCount > 0)} onClick={() => setOverlay('cart')}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={S.cartBadge}>{cartCount}</div>
          <span style={{ fontSize: 14, fontWeight: 500, color: '#1a1410' }}>Ver pedido</span>
        </div>
        <span style={{ fontSize: 15, fontWeight: 500, color: '#1a1410' }}>{cartTotal.toFixed(2).replace('.', ',')} €</span>
      </div>

      <div style={S.overlay(overlay !== null)} onClick={e => { if (e.target === e.currentTarget) setOverlay(null) }}>
        <div style={S.sheet}>
          {overlay === 'cart' && (
            <>
              <button style={S.closeBtn} onClick={() => setOverlay(null)}>×</button>
              <div style={S.sheetTitle}>Tu pedido</div>
              {Object.entries(cart).map(([id, v]) => (
                <div key={id} style={{ ...S.oItem, flexDirection: 'column', alignItems: 'stretch', gap: 4 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <div style={S.oName}>{v.nombre}</div>
                      <div style={S.oQty}>× {v.qty}</div>
                    </div>
                    <div style={S.oPrice}>{(v.precio * v.qty).toFixed(2).replace('.', ',')} €</div>
                  </div>
                  {editingNoteFor === id ? (
                    <input
                      style={S.noteInput}
                      autoFocus
                      placeholder="Ej. sin cebolla, poco hecho..."
                      value={v.nota || ''}
                      onChange={e => updateNote(id, e.target.value)}
                      onBlur={() => setEditingNoteFor(null)}
                      onKeyDown={e => e.key === 'Enter' && setEditingNoteFor(null)}
                    />
                  ) : (
                    <div style={S.noteLabel} onClick={() => setEditingNoteFor(id)}>
                      {v.nota ? `📝 ${v.nota}` : '+ Añadir nota a este plato'}
                    </div>
                  )}
                </div>
              ))}

              <div style={{ marginTop: 12 }}>
                <div style={{ fontSize: 12, color: '#8a7560' }}>Nota general del pedido</div>
                <textarea
                  style={S.notesTextarea}
                  placeholder="Ej. para compartir, es un cumpleaños..."
                  value={orderNote}
                  onChange={e => setOrderNote(e.target.value)}
                />
              </div>

              <div style={S.totalRow}>
                <span style={{ fontSize: 15, color: '#8a7560' }}>Total</span>
                <span style={{ fontSize: 17, fontWeight: 500, color: '#e8c97a' }}>{cartTotal.toFixed(2).replace('.', ',')} €</span>
              </div>
              {sendError && <div style={{ ...S.error, margin: '12px 0 0' }}>{sendError}</div>}
              <button style={S.confirmBtn(false)} onClick={confirmOrder}>Enviar pedido a cocina</button>
            </>
          )}

          {overlay === 'misPedidos' && (
            <>
              <button style={S.closeBtn} onClick={() => setOverlay(null)}>×</button>
              <div style={S.sheetTitle}>Mis pedidos</div>
              {loadingPedidos && misPedidos.length === 0 && (
                <div style={{ textAlign: 'center', color: '#7a6a50', fontSize: 13, padding: '20px 0' }}>Cargando...</div>
              )}
              {!loadingPedidos && misPedidos.length === 0 && (
                <div style={{ textAlign: 'center', color: '#7a6a50', fontSize: 13, padding: '20px 0' }}>Todavía no has hecho ningún pedido en esta visita.</div>
              )}
              {misPedidos.map(pedido => (
                <div key={pedido.id} style={{ marginBottom: 16, paddingBottom: 12, borderBottom: '0.5px solid #2a2018' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                    <span style={{ fontSize: 11, color: '#7a6a50' }}>
                      {new Date(pedido.created_at).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}
                    </span>
                    <span style={{ fontSize: 11, color: '#c4a85a', fontWeight: 500 }}>
                      {ESTADO_LABEL[pedido.estado] || pedido.estado}
                    </span>
                  </div>
                  {pedido.items.map(item => (
                    <div key={item.id} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, color: '#f0e8d8', padding: '2px 0' }}>
                      <span>{item.cantidad}× {item.nombre}</span>
                      <span style={{ color: '#c4a85a' }}>{(item.precio * item.cantidad).toFixed(2).replace('.', ',')}€</span>
                    </div>
                  ))}
                  <div style={{ textAlign: 'right', fontSize: 12, color: '#7a6a50', marginTop: 4 }}>
                    Subtotal: {parseFloat(pedido.total || 0).toFixed(2).replace('.', ',')}€
                  </div>
                </div>
              ))}
              {misPedidos.length > 0 && (
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 16, fontWeight: 600, color: '#e8c97a', paddingTop: 8 }}>
                  <span>Total pedido hasta ahora</span>
                  <span>{misPedidos.reduce((s, p) => s + parseFloat(p.total || 0), 0).toFixed(2).replace('.', ',')}€</span>
                </div>
              )}
            </>
          )}

          {overlay === 'sending' && (
            <div style={S.center}>
              <div style={S.big}>⏳</div>
              <div style={S.ctitle}>Enviando pedido...</div>
            </div>
          )}

          {overlay === 'success' && (
            <div style={S.center}>
              <div style={S.big}>✓</div>
              <div style={S.ctitle}>Pedido enviado</div>
              <div style={S.csub}>Tu pedido está en cocina.<br />El camarero te lo traerá en breve.</div>
              {orderId && <div style={S.ref}>Ref: {orderId.slice(0, 8).toUpperCase()}</div>}
              <button style={{ ...S.confirmBtn(false), marginTop: 20 }} onClick={() => setOverlay(null)}>Cerrar</button>
            </div>
          )}

          {overlay === 'waiter' && (
            <div style={S.center}>
              <div style={S.big}>🛎</div>
              <div style={S.ctitle}>Camarero avisado</div>
              <div style={S.csub}>Enseguida estamos contigo<br />en la mesa {table?.numero}.</div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
