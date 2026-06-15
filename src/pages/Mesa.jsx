import { useState, useEffect, useCallback } from 'react'
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
        const { data: tableData, error: tErr } = await supabase
          .from('tables')
          .select('id, numero, zona, restaurant_id, activa')
          .eq('qr_token', token)
          .single()
        if (tErr || !tableData) throw new Error('Mesa no encontrada')
        setTable(tableData)

        const { data: rest } = await supabase
          .from('restaurants')
          .select('nombre')
          .eq('id', tableData.restaurant_id)
          .single()
        setRestaurant(rest)

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
    setOverlay('sending')
    setSendError(null)
    try {
      const cartItems = Object.entries(cart).map(([id, v]) => ({ id, ...v }))
      const { data: order, error: oErr } = await supabase
        .from('orders')
        .insert({ restaurant_id: table.restaurant_id, table_id: table.id, tipo: 'mesa', estado: 'pendiente', total: parseFloat(cartTotal.toFixed(2)), notas: orderNote.trim() || null })
        .select('id')
        .single()
      if (oErr) throw oErr

      const lines = cartItems.map(i => ({
        order_id: order.id,
        menu_item_id: i.id,
        nombre_snapshot: i.nombre,
        precio_snapshot: i.precio,
        cantidad: i.qty,
        notas: i.nota?.trim() || null,
      }))
      const { error: lErr } = await supabase.from('order_items').insert(lines)
      if (lErr) throw lErr

      setOrderId(order.id)
      setCart({})
      setOrderNote('')
      setEditingNoteFor(null)
      setOverlay('success')
    } catch (e) {
      setSendError(e.message)
      setOverlay('cart')
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

  return (
    <div style={S.app}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
          <div style={S.sub}>Bienvenido · Pide desde la mesa</div>
        </div>
        <div style={S.badge}>Mesa {table?.numero} · {table?.zona?.charAt(0).toUpperCase() + table?.zona?.slice(1)}</div>
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
