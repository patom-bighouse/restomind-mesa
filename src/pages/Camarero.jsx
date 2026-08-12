import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif", display: 'flex', flexDirection: 'column' },
  header: { background: '#0a0a0a', padding: '14px 20px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 18, fontWeight: 600, color: '#e8c97a' },
  sub: { fontSize: 12, color: '#8a7560', marginTop: 2 },
  badge: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 20, padding: '5px 14px', fontSize: 12, color: '#c4a85a' },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 12, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },

  center: { display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, padding: 24, textAlign: 'center', gap: 18 },
  pinDots: { display: 'flex', gap: 14, margin: '8px 0' },
  pinDot: (filled) => ({ width: 16, height: 16, borderRadius: '50%', background: filled ? '#e8c97a' : 'transparent', border: `1.5px solid ${filled ? '#e8c97a' : '#3a2e20'}` }),
  pinPad: { display: 'grid', gridTemplateColumns: 'repeat(3, 64px)', gap: 12 },
  pinKey: { width: 64, height: 64, borderRadius: '50%', background: '#1a1a1a', border: '0.5px solid #3a2e20', color: '#f0e8d8', fontSize: 22, fontFamily: "'Inter', sans-serif", cursor: 'pointer' },
  pinKeyGhost: { width: 64, height: 64 },
  error: { fontSize: 13, color: '#e87a7a' },

  mesasGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))', gap: 12, padding: 20 },
  mesaCard: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '16px 14px', cursor: 'pointer', textAlign: 'center' },
  mesaNum: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a' },
  mesaZona: { fontSize: 11, color: '#8a7560', marginTop: 2 },
  mesaComensales: { fontSize: 11, color: '#7a6a50', marginTop: 6 },
  emptyMsg: { padding: 40, textAlign: 'center', fontSize: 14, color: '#666' },

  catsBar: { display: 'flex', gap: 8, padding: '10px 16px', overflowX: 'auto', borderBottom: '0.5px solid #2a2a2a' },
  cat: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 20, padding: '6px 14px', fontSize: 12, fontWeight: 500, cursor: 'pointer', whiteSpace: 'nowrap', fontFamily: "'Inter', sans-serif" }),
  scroll: { flex: 1, overflowY: 'auto', padding: '4px 16px 100px' },
  secTitle: { fontSize: 13, fontWeight: 600, color: '#c4a85a', margin: '16px 0 8px', textTransform: 'uppercase', letterSpacing: 0.5 },
  item: { display: 'flex', gap: 12, padding: '10px 0', borderBottom: '0.5px solid #222' },
  emoji: { width: 44, height: 44, borderRadius: 10, background: '#1a1a1a', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, flexShrink: 0, overflow: 'hidden' },
  info: { flex: 1, minWidth: 0 },
  name: { fontSize: 14, fontWeight: 500, color: '#f0e8d8' },
  desc: { fontSize: 11, color: '#7a6a50', marginTop: 2 },
  price: { fontSize: 13, color: '#c4a85a', marginTop: 4 },
  qty: { display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 },
  btn: { width: 28, height: 28, borderRadius: '50%', background: '#1a1a1a', border: '0.5px solid #3a2e20', color: '#e8c97a', fontSize: 16, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: "'Inter', sans-serif" },
  qnum: { fontSize: 14, minWidth: 18, textAlign: 'center' },

  cartBar: (visible) => ({ position: 'fixed', bottom: 16, left: '50%', transform: 'translateX(-50%)', width: 'calc(100% - 40px)', maxWidth: 480, background: '#e8c97a', borderRadius: 12, padding: '14px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer', opacity: visible ? 1 : 0, pointerEvents: visible ? 'all' : 'none', transition: 'opacity 0.2s', zIndex: 20 }),
  cartBadge: { background: '#1a1410', color: '#e8c97a', fontSize: 12, fontWeight: 500, width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' },

  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'flex-end', zIndex: 30 },
  sheet: { background: '#141414', width: '100%', maxHeight: '80vh', overflowY: 'auto', borderRadius: '20px 20px 0 0', padding: 20 },
  sheetTitle: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 14 },
  cartLine: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 0', borderBottom: '0.5px solid #2a2a2a' },
  confirmBtn: (busy) => ({ width: '100%', background: busy ? '#5a4a2a' : '#e8c97a', color: busy ? '#8a7560' : '#111', border: 'none', borderRadius: 10, padding: '14px', fontSize: 15, fontWeight: 500, cursor: busy ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif", marginTop: 16 }),
  backLink: { fontSize: 13, color: '#8a7560', cursor: 'pointer', marginBottom: 10 },
}

export default function Camarero() {
  const { restaurantId } = useParams()
  const [restaurant, setRestaurant] = useState(null)
  const [camarero, setCamarero] = useState(null) // { id, nombre }
  const [pinInput, setPinInput] = useState('')
  const [pinError, setPinError] = useState(null)
  const [verificando, setVerificando] = useState(false)

  const [tables, setTables] = useState([])
  const [sessions, setSessions] = useState({}) // table_id -> session row
  const [selectedTable, setSelectedTable] = useState(null)
  const [modoHabilitado, setModoHabilitado] = useState(true)
  const [abriendoMesa, setAbriendoMesa] = useState(null)

  const [categories, setCategories] = useState([])
  const [items, setItems] = useState([])
  const [activeCat, setActiveCat] = useState('todos')
  const [cart, setCart] = useState({})
  const [showCart, setShowCart] = useState(false)
  const [sending, setSending] = useState(false)
  const [sendError, setSendError] = useState(null)
  const [sendSuccess, setSendSuccess] = useState(false)

  useEffect(() => {
    loadRestaurant()
  }, [restaurantId])

  async function loadRestaurant() {
    const { data } = await supabase.from('restaurants').select('nombre, moneda, config').eq('id', restaurantId).single()
    setRestaurant(data)
    setModoHabilitado((data?.config?.modo_pedidos || 'cliente') === 'camarero')
  }

  // ---------- Login por PIN ----------
  function pressDigit(d) {
    if (pinInput.length >= 4) return
    const next = pinInput + d
    setPinInput(next)
    setPinError(null)
    if (next.length === 4) verificarPin(next)
  }

  function borrarDigito() {
    setPinInput(prev => prev.slice(0, -1))
    setPinError(null)
  }

  async function verificarPin(pin) {
    setVerificando(true)
    const { data, error: err } = await supabase.rpc('fn_verificar_camarero_pin', {
      p_restaurant_id: restaurantId,
      p_pin: pin,
    })
    setVerificando(false)
    if (err || !data || data.length === 0) {
      setPinError('PIN incorrecto.')
      setPinInput('')
      return
    }
    setCamarero(data[0])
    setPinInput('')
    await loadTablas()
  }

  function cambiarCamarero() {
    setCamarero(null)
    setSelectedTable(null)
    setPinInput('')
  }

  // ---------- Selección de mesa ----------
  async function loadTablas() {
    const { data: tabs } = await supabase
      .from('tables')
      .select('id, numero, zona, capacidad, activa')
      .eq('restaurant_id', restaurantId)
      .eq('activa', true)
      .order('numero')
    setTables(tabs || [])

    const { data: sess } = await supabase
      .from('table_sessions')
      .select('id, table_id, comensales, camarero_id')
      .eq('restaurant_id', restaurantId)
      .eq('estado', 'abierta')
    const map = {}
    ;(sess || []).forEach(s => { map[s.table_id] = s })
    setSessions(map)
  }

  // Realtime: refresca la lista de mesas cuando cambian sesiones (otra
  // mesa se abre/cierra, o se la toma otro camarero) sin necesitar F5.
  useEffect(() => {
    if (!camarero || !restaurantId) return
    const channel = supabase
      .channel(`camarero-mesas-${restaurantId}`)
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'table_sessions',
        filter: `restaurant_id=eq.${restaurantId}`,
      }, () => { loadTablas() })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [camarero, restaurantId])

  async function abrirMesa(table) {
    setAbriendoMesa(table.id)
    const session = sessions[table.id]
    try {
      if (!session) {
        // Mesa sin sesión: el camarero la abre él mismo, asignándosela.
        const { data, error: err } = await supabase
          .from('table_sessions')
          .insert({ table_id: table.id, restaurant_id: restaurantId, comensales: table.capacidad, camarero_id: camarero.id })
          .select('id, table_id, comensales, camarero_id')
          .single()
        if (err) throw err
        setSelectedTable({ ...table, session: data })
      } else if (!session.camarero_id) {
        // Mesa abierta desde el Dashboard, sin dueño: la toma este camarero.
        const { error: err } = await supabase
          .from('table_sessions')
          .update({ camarero_id: camarero.id })
          .eq('id', session.id)
        if (err) throw err
        setSelectedTable({ ...table, session: { ...session, camarero_id: camarero.id } })
      } else if (session.camarero_id === camarero.id) {
        setSelectedTable({ ...table, session })
      } else {
        // Ya la tomó otro camarero justo antes (carrera poco probable
        // gracias al realtime, pero se cubre igual).
        await loadTablas()
        return
      }
      setCart({})
      setSendSuccess(false)
      setSendError(null)
      await loadMenu()
    } catch (e) {
      setSendError(e.message)
    } finally {
      setAbriendoMesa(null)
    }
  }

  function volverAMesas() {
    setSelectedTable(null)
    setCart({})
    loadTablas()
  }

  // ---------- Carta ----------
  async function loadMenu() {
    const { data: cats } = await supabase
      .from('categories')
      .select('id, nombre, orden')
      .eq('restaurant_id', restaurantId)
      .order('orden')
    setCategories(cats || [])
    const { data: menuItems } = await supabase
      .from('menu_items')
      .select('id, nombre, descripcion, precio, emoji, foto_url, category_id, disponible')
      .eq('restaurant_id', restaurantId)
      .eq('disponible', true)
      .order('orden')
    setItems(menuItems || [])
  }

  function change(item, delta) {
    setCart(prev => {
      const current = prev[item.id]?.qty || 0
      const next = Math.max(0, current + delta)
      if (next === 0) {
        const { [item.id]: _, ...rest } = prev
        return rest
      }
      return { ...prev, [item.id]: { qty: next, precio: item.precio, nombre: item.nombre } }
    })
  }

  const cartCount = Object.values(cart).reduce((a, b) => a + b.qty, 0)
  const cartTotal = Object.values(cart).reduce((s, i) => s + i.precio * i.qty, 0)
  const filteredCats = activeCat === 'todos' ? categories : categories.filter(c => c.id === activeCat)

  async function confirmarPedido() {
    setSending(true)
    setSendError(null)
    try {
      const itemsPayload = Object.entries(cart).map(([id, v]) => ({
        menu_item_id: id,
        cantidad: v.qty,
        notas: null,
      }))
      const { error: err } = await supabase.rpc('fn_registrar_pedido', {
        p_table_session_id: selectedTable.session.id,
        p_items: itemsPayload,
        p_camarero_id: camarero.id,
      })
      if (err) throw err
      setCart({})
      setShowCart(false)
      setSendSuccess(true)
      setTimeout(() => setSendSuccess(false), 2000)
    } catch (e) {
      setSendError(e.message)
    } finally {
      setSending(false)
    }
  }

  // ---------- Render: login ----------
  if (!camarero) {
    return (
      <div style={S.app}>
        <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
        <div style={S.header}>
          <div>
            <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
            <div style={S.sub}>Pantalla de camarero</div>
          </div>
        </div>
        <div style={S.center}>
          <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' }}>Ingresá tu PIN</div>
          <div style={S.pinDots}>
            {[0, 1, 2, 3].map(i => <div key={i} style={S.pinDot(i < pinInput.length)} />)}
          </div>
          {pinError && <div style={S.error}>{pinError}</div>}
          {verificando && <div style={{ fontSize: 13, color: '#8a7560' }}>Verificando...</div>}
          <div style={S.pinPad}>
            {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => (
              <button key={n} style={S.pinKey} onClick={() => pressDigit(String(n))}>{n}</button>
            ))}
            <div style={S.pinKeyGhost} />
            <button style={S.pinKey} onClick={() => pressDigit('0')}>0</button>
            <button style={S.pinKey} onClick={borrarDigito}>⌫</button>
          </div>
        </div>
      </div>
    )
  }

  // ---------- Render: selector de mesas ----------
  if (!selectedTable) {
    if (!modoHabilitado) {
      return (
        <div style={S.app}>
          <div style={S.header}>
            <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
            <button style={S.logoutBtn} onClick={cambiarCamarero}>Salir</button>
          </div>
          <div style={S.center}>
            <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a' }}>Modo camarero no habilitado</div>
            <div style={{ fontSize: 13, color: '#8a7560' }}>Este restaurante no tiene activado el modo de pedidos por camarero. Pedile al dueño que lo active desde Configuración.</div>
          </div>
        </div>
      )
    }
    // Mesas que este camarero puede ver: sin sesión (para abrir) o con
    // sesión sin dueño / suya (para tomar o seguir atendiendo). Las que
    // ya tiene otro camarero quedan ocultas.
    const mesasVisibles = tables.filter(t => {
      const s = sessions[t.id]
      return !s || !s.camarero_id || s.camarero_id === camarero.id
    })
    const mesasPropias = mesasVisibles.filter(t => sessions[t.id])
    const mesasParaAbrir = mesasVisibles.filter(t => !sessions[t.id])
    return (
      <div style={S.app}>
        <div style={S.header}>
          <div>
            <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
            <div style={S.sub}>Hola, {camarero.nombre}</div>
          </div>
          <button style={S.logoutBtn} onClick={cambiarCamarero}>Cambiar de camarero</button>
        </div>
        {sendError && <div style={{ ...S.error, padding: '10px 16px' }}>{sendError}</div>}

        {mesasPropias.length > 0 && (
          <>
            <div style={{ ...S.secTitle, padding: '0 20px' }}>Tus mesas</div>
            <div style={S.mesasGrid}>
              {mesasPropias.map(t => (
                <div key={t.id} style={S.mesaCard} onClick={() => abrirMesa(t)}>
                  <div style={S.mesaNum}>Mesa {t.numero}</div>
                  {t.zona && <div style={S.mesaZona}>{t.zona.charAt(0).toUpperCase() + t.zona.slice(1)}</div>}
                  <div style={S.mesaComensales}>{sessions[t.id]?.comensales ?? t.capacidad} comensales</div>
                </div>
              ))}
            </div>
          </>
        )}

        <div style={{ ...S.secTitle, padding: '0 20px' }}>Mesas para abrir</div>
        {mesasParaAbrir.length === 0 ? (
          <div style={S.emptyMsg}>No hay mesas libres en este momento.</div>
        ) : (
          <div style={S.mesasGrid}>
            {mesasParaAbrir.map(t => (
              <div key={t.id} style={{ ...S.mesaCard, opacity: abriendoMesa === t.id ? 0.5 : 1 }} onClick={() => abrirMesa(t)}>
                <div style={S.mesaNum}>Mesa {t.numero}</div>
                {t.zona && <div style={S.mesaZona}>{t.zona.charAt(0).toUpperCase() + t.zona.slice(1)}</div>}
                <div style={S.mesaComensales}>Capacidad: {t.capacidad}</div>
              </div>
            ))}
          </div>
        )}
      </div>
    )
  }

  // ---------- Render: carta para cargar pedido ----------
  return (
    <div style={S.app}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
          <div style={S.sub}>{camarero.nombre} · Mesa {selectedTable.numero}</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {sendSuccess && <span style={{ fontSize: 12, color: '#7ae8a0' }}>✓ Pedido enviado</span>}
          <button style={S.logoutBtn} onClick={volverAMesas}>Cambiar de mesa</button>
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
              {catItems.map(item => (
                <div key={item.id} style={S.item}>
                  <div style={S.emoji}>
                    {item.foto_url
                      ? <img src={item.foto_url} alt={item.nombre} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      : (item.emoji || '🍽')}
                  </div>
                  <div style={S.info}>
                    <div style={S.name}>{item.nombre}</div>
                    {item.descripcion && <div style={S.desc}>{item.descripcion}</div>}
                    <div style={S.price}>{formatMoney(item.precio, restaurant?.moneda)}</div>
                  </div>
                  <div style={S.qty}>
                    <button style={S.btn} onClick={() => change(item, -1)}>−</button>
                    <span style={S.qnum}>{cart[item.id]?.qty || 0}</span>
                    <button style={S.btn} onClick={() => change(item, 1)}>+</button>
                  </div>
                </div>
              ))}
            </div>
          )
        })}
      </div>

      <div style={S.cartBar(cartCount > 0)} onClick={() => setShowCart(true)}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={S.cartBadge}>{cartCount}</div>
          <span style={{ fontSize: 14, fontWeight: 500, color: '#1a1410' }}>Enviar a cocina</span>
        </div>
        <span style={{ fontSize: 15, fontWeight: 500, color: '#1a1410' }}>{formatMoney(cartTotal, restaurant?.moneda)}</span>
      </div>

      {showCart && (
        <div style={S.overlay} onClick={() => setShowCart(false)}>
          <div style={S.sheet} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>Pedido — Mesa {selectedTable.numero}</div>
            {Object.entries(cart).map(([id, v]) => (
              <div key={id} style={S.cartLine}>
                <span style={{ fontSize: 14 }}>{v.qty}× {v.nombre}</span>
                <span style={{ fontSize: 14, color: '#c4a85a' }}>{formatMoney(v.precio * v.qty, restaurant?.moneda)}</span>
              </div>
            ))}
            <div style={{ ...S.cartLine, borderBottom: 'none', marginTop: 6 }}>
              <span style={{ fontSize: 15, fontWeight: 500 }}>Total</span>
              <span style={{ fontSize: 17, fontWeight: 500, color: '#e8c97a' }}>{formatMoney(cartTotal, restaurant?.moneda)}</span>
            </div>
            {sendError && <div style={{ fontSize: 13, color: '#e87a7a', marginTop: 8 }}>{sendError}</div>}
            <button style={S.confirmBtn(sending)} onClick={confirmarPedido} disabled={sending}>
              {sending ? 'Enviando...' : 'Confirmar y enviar a cocina'}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
