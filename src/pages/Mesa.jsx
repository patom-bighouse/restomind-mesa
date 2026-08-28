import { useState, useEffect, useCallback, useRef } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'
import { resolverMenuActivo, aplicarPreciosMenu } from '../lib/menus'

// Mismo catálogo fijo que AdminCarta.jsx (Reglamento UE 1169/2011).
const ALERGENOS = [
  { key: 'gluten', label: 'Gluten', emoji: '🌾' },
  { key: 'crustaceos', label: 'Crustáceos', emoji: '🦐' },
  { key: 'huevos', label: 'Huevos', emoji: '🥚' },
  { key: 'pescado', label: 'Pescado', emoji: '🐟' },
  { key: 'cacahuetes', label: 'Cacahuetes', emoji: '🥜' },
  { key: 'soja', label: 'Soja', emoji: '🫘' },
  { key: 'lacteos', label: 'Lácteos', emoji: '🥛' },
  { key: 'frutos_cascara', label: 'Frutos de cáscara', emoji: '🌰' },
  { key: 'apio', label: 'Apio', emoji: '🥬' },
  { key: 'mostaza', label: 'Mostaza', emoji: '🟡' },
  { key: 'sesamo', label: 'Sésamo', emoji: '◯' },
  { key: 'sulfitos', label: 'Sulfitos', emoji: '🍷' },
  { key: 'altramuces', label: 'Altramuces', emoji: '🫛' },
  { key: 'moluscos', label: 'Moluscos', emoji: '🐚' },
]

const S = {
  app: { minHeight: '100vh', background: '#1a1410', color: '#f0e8d8', display: 'flex', flexDirection: 'column', maxWidth: 480, margin: '0 auto' },
  header: { background: '#0f0c09', padding: '16px 20px 12px', borderBottom: '0.5px solid #3a2e20', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  stickyTop: { position: 'sticky', top: 0, zIndex: 15, background: '#1a1410' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  sub: { fontSize: 11, color: '#8a7560', marginTop: 2 },
  badge: { fontSize: 11, color: '#8a7560', background: '#1a1410', border: '0.5px solid #3a2e20', padding: '4px 10px', borderRadius: 20 },
  catsBar: { display: 'flex', gap: 8, padding: '14px 20px 0', overflowX: 'auto', scrollbarWidth: 'none', flexShrink: 0 },
  cat: (active) => ({ fontSize: 13, fontWeight: 500, padding: '6px 14px', borderRadius: 20, border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, background: active ? '#e8c97a' : 'transparent', color: active ? '#1a1410' : '#8a7560', cursor: 'pointer', whiteSpace: 'nowrap', transition: 'all 0.15s' }),
  comensalBar: { display: 'flex', alignItems: 'center', gap: 8, padding: '10px 20px 0', overflowX: 'auto', scrollbarWidth: 'none', flexShrink: 0 },
  comensalLabel: { fontSize: 11, color: '#7a6a50', whiteSpace: 'nowrap' },
  comensalChip: (active) => ({ fontSize: 12, fontWeight: 500, padding: '5px 12px', borderRadius: 20, border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, background: active ? '#e8c97a' : '#221c14', color: active ? '#1a1410' : '#c4a85a', cursor: 'pointer', whiteSpace: 'nowrap' }),
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
  upsellCard: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, background: '#221c14', border: '0.5px dashed #4a3c25', borderRadius: 10, padding: '10px 12px', marginBottom: 8 },
  upsellMsg: { fontSize: 13, color: '#f0e8d8' },
  upsellBtn: { flexShrink: 0, background: 'transparent', border: '0.5px solid #e8c97a', borderRadius: 8, padding: '7px 12px', fontSize: 12, fontWeight: 500, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  starsRow: { display: 'flex', gap: 6, margin: '4px 0 8px' },
  star: (activa) => ({ fontSize: 34, cursor: 'pointer', color: activa ? '#e8c97a' : '#3a2e20', lineHeight: 1 }),
  resenaTextarea: { width: '100%', maxWidth: 320, background: '#221c14', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 12px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', resize: 'vertical', minHeight: 60, boxSizing: 'border-box' },
  resenaSkip: { fontSize: 12, color: '#7a6a50', textDecoration: 'underline', cursor: 'pointer', marginTop: 4, background: 'none', border: 'none', fontFamily: "'Inter', sans-serif" },
}

export default function Mesa() {
  const { token } = useParams()
  const [restaurant, setRestaurant] = useState(null)
  const [table, setTable] = useState(null)
  const [session, setSession] = useState(null)
  const [categories, setCategories] = useState([])
  const [items, setItems] = useState([])
  const [itemModifiers, setItemModifiers] = useState({}) // menu_item_id -> [{grupo_id, grupo_nombre, obligatorio, tipo_seleccion, opciones}]
  const [upsellRules, setUpsellRules] = useState([]) // [{id, trigger_item_id, sugerida_categoria_id, mensaje}]
  const [modSelectorItem, setModSelectorItem] = useState(null) // el plato que se está configurando, o null
  const [modSelectorChoices, setModSelectorChoices] = useState({}) // { [grupo_id]: opcion_id | [opcion_id, ...] }
  const [cart, setCart] = useState({})
  const [activeCat, setActiveCat] = useState('todos')
  const [selectedComensal, setSelectedComensal] = useState(1) // número de comensal | null ("Compartido")
  const [alergenosExcluidos, setAlergenosExcluidos] = useState([])
  const [showAlergenosPanel, setShowAlergenosPanel] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [overlay, setOverlay] = useState(null) // 'cart' | 'success' | 'waiter' | 'sending' | 'misPedidos' | 'fidelizacion'
  const [orderId, setOrderId] = useState(null)
  const [sendError, setSendError] = useState(null)
  const [orderNote, setOrderNote] = useState('')
  const [editingNoteFor, setEditingNoteFor] = useState(null)
  const [misPedidos, setMisPedidos] = useState([])
  const [loadingPedidos, setLoadingPedidos] = useState(false)
  const [telefonoInput, setTelefonoInput] = useState('')
  const [nombreInput, setNombreInput] = useState('')
  const [guardandoCliente, setGuardandoCliente] = useState(false)
  const [clienteError, setClienteError] = useState(null)
  const [fidelizacionEstado, setFidelizacionEstado] = useState(null) // resultado de fn_estado_fidelizacion
  const [premiosEnCarrito, setPremiosEnCarrito] = useState([]) // [{ key, premioId, nombre, tipo, costoPuntos, comensal }]
  const [cargandoEstadoFidelizacion, setCargandoEstadoFidelizacion] = useState(false)
  const [editandoTelefono, setEditandoTelefono] = useState(false)
  const [lastClosedSessionId, setLastClosedSessionId] = useState(null)
  const [resenaEstado, setResenaEstado] = useState('pendiente') // 'pendiente' | 'enviada' | 'omitida'
  const [resenaPuntuacion, setResenaPuntuacion] = useState(0)
  const [resenaComentario, setResenaComentario] = useState('')
  const [enviandoResena, setEnviandoResena] = useState(false)
  const [resenaError, setResenaError] = useState(null)
  const prevSessionIdRef = useRef(undefined)
  // Se marca en true justo antes de vaciar `session` cuando la fila de
  // table_sessions se borró directamente (mesa cerrada sin ningún
  // pedido — ver AdminMesas.jsx), en vez de haberse actualizado a
  // 'cerrada'. En ese caso no hay nada que calificar, así que el
  // efecto de abajo no debe disparar la pantalla de reseña.
  const sesionBorradaSinResenaRef = useRef(false)

  // Cada vez que la sesión de la mesa cambia (se cierra, se reabre,
  // o pasa a ser una sesión distinta), vaciamos cualquier carrito sin
  // enviar. Sin esto, un pedido armado durante una sesión podía
  // quedar "flotando" en el navegador del cliente y reaparecer como
  // si fuera un pedido válido cuando la mesa se reabre para otro
  // grupo de comensales.
  useEffect(() => {
    const currentId = session?.id ?? null
    const previousId = prevSessionIdRef.current
    if (previousId !== undefined && previousId !== currentId) {
      setCart({})
      setOrderNote('')
      setEditingNoteFor(null)
      setSendError(null)
      // Si había una sesión y ahora no hay ninguna (no es que se abrió
      // otra para el siguiente grupo), es que la mesa se acaba de
      // cerrar — ahí pedimos la reseña antes de volver a la pantalla
      // de espera, salvo que se haya cerrado sin ningún pedido.
      if (previousId && !currentId) {
        if (sesionBorradaSinResenaRef.current) {
          sesionBorradaSinResenaRef.current = false
        } else {
          setLastClosedSessionId(previousId)
          setResenaEstado('pendiente')
          setResenaPuntuacion(0)
          setResenaComentario('')
          setResenaError(null)
        }
      }
    }
    prevSessionIdRef.current = currentId
  }, [session?.id])

  async function enviarResena() {
    if (!resenaPuntuacion || !lastClosedSessionId) return
    setEnviandoResena(true)
    setResenaError(null)
    const { error: err } = await supabase.rpc('fn_registrar_resena', {
      p_session_id: lastClosedSessionId,
      p_qr_token: token,
      p_puntuacion: resenaPuntuacion,
      p_comentario: resenaComentario.trim() || null,
    })
    setEnviandoResena(false)
    if (err) { setResenaError(err.message); return }
    setResenaEstado('enviada')
  }

  async function loadMenu(restaurantId, zona) {
    const { data: cats } = await supabase
      .from('categories')
      .select('id, nombre, orden')
      .eq('restaurant_id', restaurantId)
      .eq('activa', true)
      .order('orden')
    setCategories(cats || [])

    const { data: menuItems } = await supabase
      .from('menu_items')
      .select('id, nombre, descripcion, precio, emoji, foto_url, category_id, orden, alergenos')
      .eq('restaurant_id', restaurantId)
      .eq('disponible', true)
      .order('orden')

    // Multi-menú: si hay un menú activo (bar/terraza/mediodía...) para
    // la zona y hora actuales, sus excepciones de precio/exclusión se
    // aplican sobre la carta base — sin ninguno configurado, sigue
    // igual que siempre.
    const { data: menusData } = await supabase
      .from('menus')
      .select('id, nombre, zona, hora_inicio, hora_fin, dias_semana, activo, orden')
      .eq('restaurant_id', restaurantId)
    const menuActivo = resolverMenuActivo(menusData, zona)
    let itemsFinal = menuItems || []
    if (menuActivo) {
      const { data: precios } = await supabase
        .from('menu_item_precios_menu')
        .select('menu_id, menu_item_id, precio, excluido')
        .eq('menu_id', menuActivo.id)
      itemsFinal = aplicarPreciosMenu(itemsFinal, menuActivo, precios)
    }
    setItems(itemsFinal)
    await loadModificadores(itemsFinal.map(i => i.id))

    const { data: reglas } = await supabase
      .from('upsell_rules')
      .select('id, trigger_item_id, sugerida_categoria_id, mensaje')
      .eq('restaurant_id', restaurantId)
      .eq('activa', true)
    setUpsellRules(reglas || [])
  }

  // Trae los modificadores de TODOS los platos de una sola vez (4
  // consultas simples), en vez de cargarlos plato por plato al abrir
  // cada uno — la carta se muestra completa de entrada, así que
  // conviene tenerlo todo listo desde el principio.
  async function loadModificadores(itemIds) {
    if (!itemIds.length) { setItemModifiers({}); return }
    const { data: asignados } = await supabase
      .from('menu_item_modificador_grupos')
      .select('menu_item_id, grupo_id, obligatorio, tipo_seleccion')
      .in('menu_item_id', itemIds)
    if (!asignados || !asignados.length) { setItemModifiers({}); return }

    const grupoIds = [...new Set(asignados.map(a => a.grupo_id))]
    const { data: grupos } = await supabase
      .from('modificador_grupos').select('id, nombre').in('id', grupoIds)
    const { data: opciones } = await supabase
      .from('modificador_opciones').select('id, grupo_id, nombre, orden').in('grupo_id', grupoIds).order('orden')
    const { data: precios } = await supabase
      .from('menu_item_modificador_precios').select('menu_item_id, opcion_id, precio_extra').in('menu_item_id', itemIds)

    const nombreGrupo = {}
    ;(grupos || []).forEach(g => { nombreGrupo[g.id] = g.nombre })
    const opcionesPorGrupo = {}
    ;(opciones || []).forEach(o => {
      if (!opcionesPorGrupo[o.grupo_id]) opcionesPorGrupo[o.grupo_id] = []
      opcionesPorGrupo[o.grupo_id].push(o)
    })
    const precioPorItemOpcion = {}
    ;(precios || []).forEach(p => { precioPorItemOpcion[`${p.menu_item_id}::${p.opcion_id}`] = parseFloat(p.precio_extra) || 0 })

    const map = {}
    asignados.forEach(a => {
      if (!map[a.menu_item_id]) map[a.menu_item_id] = []
      map[a.menu_item_id].push({
        grupo_id: a.grupo_id,
        grupo_nombre: nombreGrupo[a.grupo_id] || '',
        obligatorio: a.obligatorio,
        tipo_seleccion: a.tipo_seleccion,
        opciones: (opcionesPorGrupo[a.grupo_id] || []).map(o => ({
          id: o.id,
          nombre: o.nombre,
          precio_extra: precioPorItemOpcion[`${a.menu_item_id}::${o.id}`] ?? 0,
        })),
      })
    })
    setItemModifiers(map)
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
          .select('nombre, moneda, config')
          .eq('id', tableData.restaurant_id)
          .single()
        setRestaurant(rest)

        // Antes usábamos .maybeSingle(), que lanza error si llegara a haber
        // más de una fila 'abierta' para la misma mesa (p. ej. si quedó una
        // sesión duplicada de una prueba anterior). Ese error no se estaba
        // capturando, así que la mesa se veía como "sin sesión" aunque sí
        // hubiera una abierta. Con order+limit(1) nos quedamos siempre con
        // la más reciente y no rompemos la carga si hay filas duplicadas.
        const { data: sessionRows, error: sessErr } = await supabase
          .from('table_sessions')
          .select('id, estado, abierta_at, cliente_telefono, cliente_nombre, comensales')
          .eq('table_id', tableData.id)
          .eq('estado', 'abierta')
          .order('abierta_at', { ascending: false })
          .limit(1)
        if (sessErr) throw sessErr
        setSession(sessionRows && sessionRows.length > 0 ? sessionRows[0] : null)

        await loadMenu(tableData.restaurant_id, tableData.zona)
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
      }, () => loadMenu(table.restaurant_id, table.zona))
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'categories',
        filter: `restaurant_id=eq.${table.restaurant_id}`
      }, () => loadMenu(table.restaurant_id, table.zona))
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'tables',
        filter: `id=eq.${table.id}`
      }, (payload) => setTable(prev => ({ ...prev, ...payload.new })))
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'table_sessions',
        filter: `table_id=eq.${table.id}`
      }, (payload) => {
        // Una sesión borrada (no actualizada a 'cerrada') significa
        // que se cerró sin ningún pedido — no hay nada que calificar.
        if (payload.eventType === 'DELETE') { sesionBorradaSinResenaRef.current = true; setSession(null); return }
        const row = payload.new
        if (row.estado === 'abierta') setSession(row)
        else setSession(prev => (prev && prev.id === row.id) ? null : prev)
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [table?.restaurant_id, table?.id])

  // Respaldo del cierre de mesa: el cliente anónimo no puede leer
  // table_sessions una vez cerrada (la política RLS de anon solo
  // permite estado = 'abierta'), así que ni el Realtime de arriba ni
  // un select directo le avisan cuando eso pasa. Mientras haya una
  // sesión que creemos abierta, la re-chequeamos cada 15s vía RPC
  // (que sí puede ver el estado real, validando el qr_token).
  useEffect(() => {
    if (!session?.id) return
    const interval = setInterval(async () => {
      const { data: estado } = await supabase.rpc('fn_estado_sesion_mesa', {
        p_session_id: session.id,
        p_qr_token: token,
      })
      if (!estado) {
        // La fila ya no existe: se cerró sin pedidos y se borró.
        sesionBorradaSinResenaRef.current = true
        setSession(prev => (prev && prev.id === session.id) ? null : prev)
      } else if (estado !== 'abierta') {
        setSession(prev => (prev && prev.id === session.id) ? null : prev)
      }
    }, 15000)
    return () => clearInterval(interval)
  }, [session?.id, token])

  // Cada línea del carrito queda atada a un comensal — dos unidades
  // del mismo plato para personas distintas son líneas separadas, no
  // se suman entre sí. "x" identifica lo compartido (sin comensal).
  const comensalTag = (c) => (c == null ? 'x' : `c${c}`)

  const change = useCallback((item, delta) => {
    // Si el plato tiene modificadores, no se suma directo — hay que
    // elegir las opciones primero (abre el selector).
    if (delta > 0 && itemModifiers[item.id]?.length > 0) {
      setModSelectorItem(item)
      setModSelectorChoices({})
      return
    }
    const cartKey = `${item.id}::${comensalTag(selectedComensal)}`
    setCart(prev => {
      const curr = prev[cartKey]?.qty || 0
      const next = Math.max(0, curr + delta)
      if (next === 0) {
        const { [cartKey]: _, ...rest } = prev
        return rest
      }
      return { ...prev, [cartKey]: { qty: next, nombre: item.nombre, precio: parseFloat(item.precio), nota: prev[cartKey]?.nota || '', menuItemId: item.id, comensal: selectedComensal } }
    })
  }, [itemModifiers, selectedComensal])

  // Ajusta cantidad directamente por la key del carrito (sirve tanto
  // para platos simples como para combinaciones con modificadores,
  // desde el resumen "Tu pedido").
  const changeQtyByKey = useCallback((key, delta) => {
    setCart(prev => {
      const line = prev[key]
      if (!line) return prev
      const next = Math.max(0, line.qty + delta)
      if (next === 0) {
        const { [key]: _, ...rest } = prev
        return rest
      }
      return { ...prev, [key]: { ...line, qty: next } }
    })
  }, [])

  function toggleModChoice(grupo, opcionId) {
    setModSelectorChoices(prev => {
      if (grupo.tipo_seleccion === 'multiple') {
        const actuales = prev[grupo.grupo_id] || []
        const next = actuales.includes(opcionId) ? actuales.filter(id => id !== opcionId) : [...actuales, opcionId]
        return { ...prev, [grupo.grupo_id]: next }
      }
      return { ...prev, [grupo.grupo_id]: opcionId }
    })
  }

  function confirmarModSelector() {
    const item = modSelectorItem
    const grupos = itemModifiers[item.id] || []
    // Validar que los grupos obligatorios tengan al menos una elección
    const faltante = grupos.find(g => g.obligatorio && (
      g.tipo_seleccion === 'multiple'
        ? !(modSelectorChoices[g.grupo_id]?.length > 0)
        : !modSelectorChoices[g.grupo_id]
    ))
    if (faltante) return // el botón "Agregar" queda deshabilitado en ese caso, esto es un respaldo

    const detalle = []
    let extra = 0
    grupos.forEach(g => {
      const elegido = modSelectorChoices[g.grupo_id]
      const opcionIds = g.tipo_seleccion === 'multiple' ? (elegido || []) : (elegido ? [elegido] : [])
      opcionIds.forEach(opId => {
        const op = g.opciones.find(o => o.id === opId)
        if (!op) return
        detalle.push({ grupo_id: g.grupo_id, grupo_nombre: g.grupo_nombre, opcion_id: op.id, opcion_nombre: op.nombre, precio_extra: op.precio_extra })
        extra += op.precio_extra
      })
    })

    // La key agrupa por plato + combinación exacta elegida (ordenada,
    // para que el mismo combo siempre caiga en la misma línea sin
    // importar en qué orden se tocaron los checkboxes).
    const comboKey = detalle
      .slice()
      .sort((a, b) => (a.grupo_id + a.opcion_id).localeCompare(b.grupo_id + b.opcion_id))
      .map(d => `${d.grupo_id}:${d.opcion_id}`)
      .join('|')
    const cartKey = `${item.id}::${comboKey}::${comensalTag(selectedComensal)}`

    setCart(prev => {
      const curr = prev[cartKey]?.qty || 0
      return {
        ...prev,
        [cartKey]: {
          qty: curr + 1,
          nombre: item.nombre,
          precio: parseFloat(item.precio) + extra,
          nota: prev[cartKey]?.nota || '',
          menuItemId: item.id,
          modificadoresDetalle: detalle,
          comensal: selectedComensal,
        },
      }
    })
    setModSelectorItem(null)
    setModSelectorChoices({})
  }

  const updateNote = useCallback((itemId, nota) => {
    setCart(prev => prev[itemId] ? { ...prev, [itemId]: { ...prev[itemId], nota } } : prev)
  }, [])

  const cartCount = Object.values(cart).reduce((a, b) => a + b.qty, 0)
  const descuentoPremios = premiosEnCarrito.reduce((s, p) => s + (p.tipo === 'descuento' ? p.descuentoImporte : 0), 0)
  const cartTotal = Math.max(0, Object.values(cart).reduce((s, i) => s + i.precio * i.qty, 0) - descuentoPremios)

  // Sugerencias de upsell: reglas cuyo plato disparador está en el
  // carrito, sugiriendo explorar otra categoría — salvo que el
  // cliente ya haya agregado algo de esa categoría sugerida.
  const itemIdsEnCarrito = new Set(Object.values(cart).map(v => v.menuItemId))
  const categoriasEnCarrito = new Set(
    Object.values(cart).map(v => items.find(i => i.id === v.menuItemId)?.category_id).filter(Boolean)
  )
  const categoriasSugeridas = new Map() // categoria_id -> regla (primera que matchea)
  upsellRules.forEach(r => {
    if (!itemIdsEnCarrito.has(r.trigger_item_id)) return
    if (categoriasEnCarrito.has(r.sugerida_categoria_id)) return
    if (!categoriasSugeridas.has(r.sugerida_categoria_id)) categoriasSugeridas.set(r.sugerida_categoria_id, r)
  })
  const sugerencias = [...categoriasSugeridas.values()]
    .map(r => ({ ...r, categoria: categories.find(c => c.id === r.sugerida_categoria_id) }))
    .filter(r => r.categoria)

  // Si el restaurante eligió modo 'camarero', el cliente sigue viendo la
  // carta, "Mis pedidos" y puede llamar al camarero, pero no puede agregar
  // ítems él mismo — eso lo hace el camarero desde su propia pantalla.
  const esModoCamarero = restaurant?.config?.modo_pedidos === 'camarero'

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
        menu_item_id: i.menuItemId || i.id,
        cantidad: i.qty,
        notas: i.nota?.trim() || null,
        comensal: i.comensal ?? null,
        modificadores: (i.modificadoresDetalle || []).map(m => ({ grupo_id: m.grupo_id, opcion_id: m.opcion_id })),
      }))

      // fn_registrar_pedido decide, según el modo de Cocina del restaurante,
      // si este envío se suma a un pedido "pendiente" ya abierto de esta
      // misma mesa/sesión (modo agrupado) o si crea uno nuevo (modo orden
      // de llegada). El mismo criterio se usa desde el flujo de WhatsApp,
      // así que no se decide nada de esto acá en el cliente.
      const premiosPayload = premiosEnCarrito.map(p => ({ premio_id: p.premioId, comensal: p.comensal ?? null }))
      const { data: newOrderId, error: rpcErr } = await supabase.rpc('fn_registrar_pedido', {
        p_table_session_id: session.id,
        p_items: itemsPayload,
        p_notas: orderNote.trim() || null,
        p_premios_canjeados: premiosPayload,
      })
      if (rpcErr) throw rpcErr

      setOrderId(newOrderId)
      setCart({})
      setOrderNote('')
      setEditingNoteFor(null)
      setPremiosEnCarrito([])
      // Los puntos ya se descontaron del lado del servidor — si el
      // panel de fidelización llegara a reabrirse, que muestre el
      // saldo real y no el de antes de canjear.
      if (session?.cliente_telefono) await cargarEstadoFidelizacion(session.cliente_telefono)
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
        const { data: sessionActualRows } = await supabase
          .from('table_sessions')
          .select('id, estado, abierta_at, cliente_telefono, cliente_nombre, comensales')
          .eq('table_id', table.id)
          .eq('estado', 'abierta')
          .order('abierta_at', { ascending: false })
          .limit(1)
        setSession(sessionActualRows && sessionActualRows.length > 0 ? sessionActualRows[0] : null)
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

  // Abre el formulario de fidelización precargado con lo que ya tenga
  // guardado la sesión (si el camarero ya lo cargó desde su pantalla,
  // o si el cliente ya lo había dejado antes en esta misma visita).
  function abrirFidelizacion() {
    setTelefonoInput(session?.cliente_telefono || '')
    setNombreInput(session?.cliente_nombre || '')
    setClienteError(null)
    setOverlay('fidelizacion')
    if (session?.cliente_telefono) {
      setEditandoTelefono(false)
      cargarEstadoFidelizacion(session.cliente_telefono)
    } else {
      setEditandoTelefono(true)
      setFidelizacionEstado(null)
    }
  }

  // Trae puntos, nivel y premios disponibles para el teléfono ya
  // guardado — fn_estado_fidelizacion es pública mediante RPC porque
  // clientes no se puede leer directo desde el cliente anónimo (dejaría
  // consultar el saldo de cualquier teléfono ajeno).
  async function cargarEstadoFidelizacion(telefono) {
    setCargandoEstadoFidelizacion(true)
    const { data } = await supabase.rpc('fn_estado_fidelizacion', {
      p_restaurant_id: table.restaurant_id,
      p_telefono: telefono,
    })
    setCargandoEstadoFidelizacion(false)
    setFidelizacionEstado(data || null)
  }

  // Suma en pantalla lo que ya se puso en el carrito para canjear, así
  // no se puede agregar un premio de más aunque el saldo real todavía
  // no se haya descontado (eso pasa recién al confirmar el pedido).
  const puntosReservados = premiosEnCarrito.reduce((s, p) => s + p.costoPuntos, 0)
  const puntosDisponibles = (fidelizacionEstado?.puntos || 0) - puntosReservados

  function canjearPremio(premio) {
    // En modo camarero, este teléfono nunca envía el pedido — el canje
    // solo puede quedar en manos de quien sí lo hace (Camarero.jsx).
    if (esModoCamarero) return
    if (premio.costo_puntos > puntosDisponibles) return
    setPremiosEnCarrito(prev => [...prev, {
      key: crypto.randomUUID(),
      premioId: premio.id,
      nombre: premio.nombre,
      tipo: premio.tipo,
      costoPuntos: premio.costo_puntos,
      descuentoImporte: premio.descuento_importe || 0,
      comensal: selectedComensal,
    }])
  }

  function quitarPremioCarrito(key) {
    setPremiosEnCarrito(prev => prev.filter(p => p.key !== key))
  }

  // fn_registrar_cliente_sesion valida, del lado del servidor, que la
  // sesión realmente pertenece a la mesa de este QR y que sigue
  // abierta — así ningún cliente puede escribir el teléfono de la
  // sesión de otra mesa aunque conozca su session_id.
  async function guardarCliente() {
    const telefono = telefonoInput.trim()
    if (!telefono) { setClienteError('Introduce tu número de teléfono.'); return }
    setGuardandoCliente(true)
    setClienteError(null)
    const { error: err } = await supabase.rpc('fn_registrar_cliente_sesion', {
      p_session_id: session.id,
      p_qr_token: token,
      p_telefono: telefono,
      p_nombre: nombreInput.trim() || null,
    })
    setGuardandoCliente(false)
    if (err) { setClienteError(err.message); return }
    // Aplicamos el cambio en local de inmediato (igual que el resto de
    // acciones de la app) en vez de esperar a que llegue el evento de
    // Realtime — así el botón refleja "Sumando puntos" al instante,
    // sin depender de la latencia de la suscripción. La misma lógica
    // de coalesce que usa fn_registrar_cliente_sesion: si no se cargó
    // nombre nuevo, se conserva el que ya hubiera.
    setSession(prev => prev ? {
      ...prev,
      cliente_telefono: telefono,
      cliente_nombre: nombreInput.trim() || prev.cliente_nombre || null,
    } : prev)
    setEditandoTelefono(false)
    await cargarEstadoFidelizacion(telefono)
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
          precio: parseFloat(row.item_precio) + parseFloat(row.item_modificadores_extra || 0),
          cantidad: row.item_cantidad,
          notas: row.item_notas,
          modificadores: row.item_modificadores,
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

  if (table && table.activa && !session && lastClosedSessionId && resenaEstado === 'pendiente') return (
    <div style={S.app}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
        </div>
        <div style={S.badge}>Mesa {table?.numero}</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, padding: 40, textAlign: 'center', gap: 10 }}>
        <div style={{ fontSize: 40 }}>🙏</div>
        <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' }}>¡Gracias por tu visita!</div>
        <div style={{ fontSize: 14, color: '#7a6a50', lineHeight: 1.6 }}>¿Cómo estuvo todo?</div>
        <div style={S.starsRow}>
          {[1, 2, 3, 4, 5].map(n => (
            <span key={n} style={S.star(n <= resenaPuntuacion)} onClick={() => setResenaPuntuacion(n)}>★</span>
          ))}
        </div>
        {resenaPuntuacion > 0 && (
          <>
            <textarea
              style={S.resenaTextarea}
              placeholder="Contanos algo más (opcional)"
              value={resenaComentario}
              onChange={e => setResenaComentario(e.target.value)}
            />
            {resenaError && <div style={{ ...S.error, margin: '4px 0 0' }}>{resenaError}</div>}
            <button style={{ ...S.confirmBtn(false), maxWidth: 320 }} onClick={enviarResena} disabled={enviandoResena}>
              {enviandoResena ? 'Enviando...' : 'Enviar reseña'}
            </button>
          </>
        )}
        <button style={S.resenaSkip} onClick={() => setResenaEstado('omitida')}>Omitir</button>
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
        <div style={{ fontSize: 40 }}>{lastClosedSessionId ? '👋' : '🕒'}</div>
        <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' }}>
          {lastClosedSessionId ? '¡Hasta la próxima!' : 'Espera a que te atiendan'}
        </div>
        <div style={{ fontSize: 14, color: '#7a6a50', lineHeight: 1.6 }}>
          {lastClosedSessionId
            ? (resenaEstado === 'enviada' ? '¡Gracias por tu reseña!' : 'Esperamos verte pronto de nuevo.')
            : (<>El camarero abrirá tu mesa en breve.<br />En cuanto lo haga, podrás ver la carta y pedir aquí mismo.</>)}
        </div>
        {!lastClosedSessionId && (
          overlay === 'waiter' ? (
            <div style={{ fontSize: 13, color: '#e8c97a', marginTop: 8 }}>🛎 Camarero avisado, ¡ya vamos!</div>
          ) : (
            <div style={{ ...S.callBtn, margin: '8px 0 0', width: '100%', boxSizing: 'border-box', justifyContent: 'center' }} onClick={callWaiter}>
              <span style={{ fontSize: 20 }}>🛎</span>
              <div>
                <div style={S.callTitle}>Avisar que ya llegué</div>
                <div style={S.callSub}>Toca aquí para llamar al camarero</div>
              </div>
            </div>
          )
        )}
      </div>
    </div>
  )

  return (
    <div style={S.app}>
      <div style={S.stickyTop}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
          <div style={S.sub}>Bienvenido · Pide desde la mesa</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
          <div style={S.badge}>Mesa {table?.numero} · {table?.zona?.charAt(0).toUpperCase() + table?.zona?.slice(1)}</div>
          <div style={{ display: 'flex', gap: 6 }}>
            <button
              onClick={() => setShowAlergenosPanel(true)}
              style={{ background: alergenosExcluidos.length > 0 ? '#3a2010' : 'transparent', border: `0.5px solid ${alergenosExcluidos.length > 0 ? '#e8c97a' : '#3a2e20'}`, borderRadius: 20, padding: '4px 12px', fontSize: 11, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
            >
              🌾 Alérgenos{alergenosExcluidos.length > 0 ? ` (${alergenosExcluidos.length})` : ''}
            </button>
            <button onClick={abrirMisPedidos} style={{ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 20, padding: '4px 12px', fontSize: 11, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
              🧾 Mis pedidos
            </button>
            <button
              onClick={abrirFidelizacion}
              style={{ background: session?.cliente_telefono ? '#3a2010' : 'transparent', border: `0.5px solid ${session?.cliente_telefono ? '#e8c97a' : '#3a2e20'}`, borderRadius: 20, padding: '4px 12px', fontSize: 11, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
            >
              🎁 {session?.cliente_telefono ? 'Sumando puntos' : 'Sumar puntos'}
            </button>
          </div>
        </div>
      </div>

      <div style={S.catsBar}>
        <button style={S.cat(activeCat === 'todos')} onClick={() => setActiveCat('todos')}>Todos</button>
        {categories.map(c => (
          <button key={c.id} style={S.cat(activeCat === c.id)} onClick={() => setActiveCat(c.id)}>{c.nombre}</button>
        ))}
      </div>

      {!esModoCamarero && session?.comensales > 1 && (
        <div style={S.comensalBar}>
          <span style={S.comensalLabel}>¿Para quién?</span>
          {Array.from({ length: session.comensales }, (_, i) => i + 1).map(n => (
            <button key={n} style={S.comensalChip(selectedComensal === n)} onClick={() => setSelectedComensal(n)}>{n}</button>
          ))}
          <button style={S.comensalChip(selectedComensal == null)} onClick={() => setSelectedComensal(null)}>Compartido</button>
        </div>
      )}
      </div>

      <div style={S.scroll}>
        {filteredCats.map(cat => {
          const catItems = items
            .filter(i => i.category_id === cat.id)
            .filter(i => !alergenosExcluidos.some(k => (i.alergenos || []).includes(k)))
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
                      <div style={S.price}>{formatMoney(item.precio, restaurant?.moneda)}</div>
                      {item.alergenos && item.alergenos.length > 0 && (
                        <div style={{ fontSize: 13, marginTop: 3 }} title={item.alergenos.map(k => ALERGENOS.find(a => a.key === k)?.label).join(', ')}>
                          {item.alergenos.map(k => ALERGENOS.find(a => a.key === k)?.emoji).join(' ')}
                        </div>
                      )}
                    </div>
                    {!esModoCamarero && (
                      itemModifiers[item.id]?.length > 0 ? (
                        <button style={{ ...S.btn, width: 'auto', padding: '0 14px', borderRadius: 16, fontSize: 12 }} onClick={() => change(item, 1)}>
                          Elegir
                        </button>
                      ) : (
                        <div style={S.qty}>
                          <button style={S.btn} onClick={() => change(item, -1)}>−</button>
                          <span style={S.qnum}>{cart[`${item.id}::${comensalTag(selectedComensal)}`]?.qty || 0}</span>
                          <button style={S.btn} onClick={() => change(item, 1)}>+</button>
                        </div>
                      )
                    )}
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

      {!esModoCamarero && (
        <div style={S.cartBar(cartCount > 0 || premiosEnCarrito.length > 0)} onClick={() => setOverlay('cart')}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={S.cartBadge}>{cartCount + premiosEnCarrito.length}</div>
            <span style={{ fontSize: 14, fontWeight: 500, color: '#1a1410' }}>Ver pedido</span>
          </div>
          <span style={{ fontSize: 15, fontWeight: 500, color: '#1a1410' }}>{formatMoney(cartTotal, restaurant?.moneda)}</span>
        </div>
      )}

      <div style={S.overlay(showAlergenosPanel)} onClick={e => { if (e.target === e.currentTarget) setShowAlergenosPanel(false) }}>
        <div style={S.sheet}>
          <button style={S.closeBtn} onClick={() => setShowAlergenosPanel(false)}>×</button>
          <div style={S.sheetTitle}>Alérgenos a evitar</div>
          <div style={{ fontSize: 12, color: '#8a7560', marginBottom: 14 }}>
            Marca los que quieres evitar — ocultaremos de la carta los platos que los contengan.
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '10px 12px', marginBottom: 16 }}>
            {ALERGENOS.map(a => {
              const checked = alergenosExcluidos.includes(a.key)
              return (
                <label key={a.key} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, color: '#f0e8d8', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={e => {
                      setAlergenosExcluidos(prev => e.target.checked ? [...prev, a.key] : prev.filter(k => k !== a.key))
                    }}
                  />
                  <span>{a.emoji} {a.label}</span>
                </label>
              )
            })}
          </div>
          {alergenosExcluidos.length > 0 && (
            <button
              onClick={() => setAlergenosExcluidos([])}
              style={{ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px', width: '100%', color: '#c4a85a', fontSize: 13, cursor: 'pointer', fontFamily: "'Inter', sans-serif", marginBottom: 10 }}
            >
              Quitar todos los filtros
            </button>
          )}
          <button
            onClick={() => setShowAlergenosPanel(false)}
            style={{ background: '#e8c97a', border: 'none', borderRadius: 10, padding: '12px', width: '100%', color: '#1a1410', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
          >
            Listo
          </button>
        </div>
      </div>

      <div style={S.overlay(modSelectorItem !== null)} onClick={e => { if (e.target === e.currentTarget) setModSelectorItem(null) }}>
        <div style={S.sheet}>
          {modSelectorItem && (
            <>
              <button style={S.closeBtn} onClick={() => setModSelectorItem(null)}>×</button>
              <div style={S.sheetTitle}>{modSelectorItem.nombre}</div>
              {(itemModifiers[modSelectorItem.id] || []).map(grupo => (
                <div key={grupo.grupo_id} style={{ marginBottom: 18 }}>
                  <div style={{ fontSize: 13, fontWeight: 500, color: '#c4a85a', marginBottom: 8 }}>
                    {grupo.grupo_nombre}
                    {grupo.obligatorio && <span style={{ color: '#e87a7a', fontSize: 11 }}> · obligatorio</span>}
                    {grupo.tipo_seleccion === 'multiple' && <span style={{ color: '#7a6a50', fontSize: 11 }}> · elige una o más</span>}
                  </div>
                  {grupo.opciones.map(op => {
                    const elegido = grupo.tipo_seleccion === 'multiple'
                      ? (modSelectorChoices[grupo.grupo_id] || []).includes(op.id)
                      : modSelectorChoices[grupo.grupo_id] === op.id
                    return (
                      <label key={op.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 0', borderBottom: '0.5px solid #2a2a2a', cursor: 'pointer' }}>
                        <span style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, color: '#f0e8d8' }}>
                          <input
                            type={grupo.tipo_seleccion === 'multiple' ? 'checkbox' : 'radio'}
                            name={`grupo-${grupo.grupo_id}`}
                            checked={elegido}
                            onChange={() => toggleModChoice(grupo, op.id)}
                          />
                          {op.nombre}
                        </span>
                        {op.precio_extra > 0 && <span style={{ fontSize: 13, color: '#c4a85a' }}>+{formatMoney(op.precio_extra, restaurant?.moneda)}</span>}
                      </label>
                    )
                  })}
                </div>
              ))}
              {(() => {
                const grupos = itemModifiers[modSelectorItem.id] || []
                const faltaObligatorio = grupos.some(g => g.obligatorio && (
                  g.tipo_seleccion === 'multiple'
                    ? !(modSelectorChoices[g.grupo_id]?.length > 0)
                    : !modSelectorChoices[g.grupo_id]
                ))
                return (
                  <button
                    onClick={confirmarModSelector}
                    disabled={faltaObligatorio}
                    style={{ background: faltaObligatorio ? '#5a4a2a' : '#e8c97a', color: faltaObligatorio ? '#8a7560' : '#1a1410', border: 'none', borderRadius: 10, padding: '12px', width: '100%', fontSize: 14, fontWeight: 500, cursor: faltaObligatorio ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }}
                  >
                    {faltaObligatorio ? 'Elige las opciones obligatorias' : 'Agregar al pedido'}
                  </button>
                )
              })()}
            </>
          )}
        </div>
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
                      <div style={S.oName}>
                        {v.nombre}
                        {session?.comensales > 1 && (
                          <span style={{ fontSize: 11, color: '#7a6a50', fontWeight: 400 }}> · {v.comensal == null ? 'Compartido' : `Comensal ${v.comensal}`}</span>
                        )}
                      </div>
                      {v.modificadoresDetalle?.length > 0 && (
                        <div style={{ fontSize: 12, color: '#8a7560', marginTop: 2 }}>
                          {v.modificadoresDetalle.map(m => m.opcion_nombre).join(', ')}
                        </div>
                      )}
                    </div>
                    <div style={S.oPrice}>{formatMoney(v.precio * v.qty, restaurant?.moneda)}</div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <button style={{ ...S.btn, width: 26, height: 26 }} onClick={() => changeQtyByKey(id, -1)}>−</button>
                    <span style={S.oQty}>{v.qty}</span>
                    <button style={{ ...S.btn, width: 26, height: 26 }} onClick={() => changeQtyByKey(id, 1)}>+</button>
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

              {premiosEnCarrito.length > 0 && (
                <div style={{ marginTop: 12 }}>
                  {premiosEnCarrito.map(p => (
                    <div key={p.key} style={S.oItem}>
                      <div>
                        <div style={S.oName}>🎁 {p.nombre}</div>
                        {session?.comensales > 1 && (
                          <div style={{ fontSize: 11, color: '#7a6a50' }}>{p.comensal == null ? 'Compartido' : `Comensal ${p.comensal}`}</div>
                        )}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <span style={S.oPrice}>{p.tipo === 'plato_gratis' ? 'GRATIS' : `-${formatMoney(p.descuentoImporte, restaurant?.moneda)}`}</span>
                        <button style={{ ...S.btn, width: 26, height: 26 }} onClick={() => quitarPremioCarrito(p.key)}>×</button>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <div style={{ marginTop: 12 }}>
                <div style={{ fontSize: 12, color: '#8a7560' }}>Nota general del pedido</div>
                <textarea
                  style={S.notesTextarea}
                  placeholder="Ej. para compartir, es un cumpleaños..."
                  value={orderNote}
                  onChange={e => setOrderNote(e.target.value)}
                />
              </div>

              {sugerencias.length > 0 && (
                <div style={{ marginTop: 16 }}>
                  {sugerencias.map(s => (
                    <div key={s.sugerida_categoria_id} style={S.upsellCard}>
                      <div style={S.upsellMsg}>{s.mensaje || `¿Le sumamos algo de ${s.categoria.nombre}?`}</div>
                      <button
                        style={S.upsellBtn}
                        onClick={() => { setActiveCat(s.sugerida_categoria_id); setOverlay(null) }}
                      >
                        Ver {s.categoria.nombre}
                      </button>
                    </div>
                  ))}
                </div>
              )}

              <div style={S.totalRow}>
                <span style={{ fontSize: 15, color: '#8a7560' }}>Total</span>
                <span style={{ fontSize: 17, fontWeight: 500, color: '#e8c97a' }}>{formatMoney(cartTotal, restaurant?.moneda)}</span>
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
                    <div key={item.id} style={{ padding: '2px 0' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, color: '#f0e8d8' }}>
                        <span>{item.cantidad}× {item.nombre}</span>
                        <span style={{ color: '#c4a85a' }}>{formatMoney(item.precio * item.cantidad, restaurant?.moneda)}</span>
                      </div>
                      {item.modificadores && (
                        <div style={{ fontSize: 11, color: '#8a7560', marginLeft: 12 }}>{item.modificadores}</div>
                      )}
                    </div>
                  ))}
                  <div style={{ textAlign: 'right', fontSize: 12, color: '#7a6a50', marginTop: 4 }}>
                    Subtotal: {formatMoney(pedido.total || 0, restaurant?.moneda)}
                  </div>
                </div>
              ))}
              {misPedidos.length > 0 && (
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 16, fontWeight: 600, color: '#e8c97a', paddingTop: 8 }}>
                  <span>Total pedido hasta ahora</span>
                  <span>{formatMoney(misPedidos.reduce((s, p) => s + parseFloat(p.total || 0), 0), restaurant?.moneda)}</span>
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

          {overlay === 'fidelizacion' && !editandoTelefono && session?.cliente_telefono && (
            <>
              <button style={S.closeBtn} onClick={() => setOverlay(null)}>×</button>
              <div style={S.sheetTitle}>🎁 Tu fidelización</div>
              {cargandoEstadoFidelizacion ? (
                <div style={{ textAlign: 'center', color: '#7a6a50', padding: '20px 0' }}>Cargando...</div>
              ) : fidelizacionEstado ? (
                <>
                  <div style={{ textAlign: 'center', margin: '8px 0 16px' }}>
                    <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 32, color: '#e8c97a' }}>{fidelizacionEstado.puntos}</div>
                    <div style={{ fontSize: 12, color: '#7a6a50' }}>puntos</div>
                  </div>
                  {fidelizacionEstado.nivel_actual && (
                    <div style={{ textAlign: 'center', fontSize: 14, color: '#c4a85a', marginBottom: 4 }}>
                      Nivel {fidelizacionEstado.nivel_actual.nombre}
                    </div>
                  )}
                  {fidelizacionEstado.proximo_nivel && (
                    <div style={{ textAlign: 'center', fontSize: 12, color: '#7a6a50', marginBottom: 16 }}>
                      Te faltan {formatMoney(fidelizacionEstado.proximo_nivel.umbral_gasto - fidelizacionEstado.gasto_acumulado, restaurant?.moneda)} para {fidelizacionEstado.proximo_nivel.nombre}
                    </div>
                  )}
                  {!esModoCamarero && premiosEnCarrito.length > 0 && (
                    <div style={{ marginTop: 8, marginBottom: 8 }}>
                      <div style={{ fontSize: 12, color: '#8a7560', marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.05em' }}>En tu pedido</div>
                      {premiosEnCarrito.map(p => (
                        <div key={p.key} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0' }}>
                          <div style={{ fontSize: 13, color: '#e8c97a' }}>🎁 {p.nombre} ({p.costoPuntos} pts)</div>
                          <button style={S.resenaSkip} onClick={() => quitarPremioCarrito(p.key)}>Quitar</button>
                        </div>
                      ))}
                    </div>
                  )}
                  {fidelizacionEstado.premios?.length > 0 && (
                    <div style={{ marginTop: 8 }}>
                      <div style={{ fontSize: 12, color: '#8a7560', marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Premios</div>
                      {fidelizacionEstado.premios.map(p => {
                        const puedeCanjear = p.costo_puntos <= puntosDisponibles
                        return (
                          <div key={p.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 0', borderBottom: '0.5px solid #2a2018', opacity: puedeCanjear ? 1 : 0.5 }}>
                            <div>
                              <div style={{ fontSize: 13, color: '#f0e8d8' }}>
                                {p.tipo === 'plato_gratis' ? `🍽 ${p.menu_item_nombre}` : `💶 -${formatMoney(p.descuento_importe, restaurant?.moneda)}`}
                                {' · '}{p.nombre}
                              </div>
                              {p.descripcion && <div style={{ fontSize: 11, color: '#7a6a50' }}>{p.descripcion}</div>}
                            </div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              <span style={{ fontSize: 12, color: puedeCanjear ? '#e8c97a' : '#7a6a50' }}>{p.costo_puntos} pts</span>
                              {esModoCamarero ? (
                                // En modo camarero, el cliente no puede enviar
                                // pedidos por su cuenta — el canje solo puede
                                // hacerlo quien realmente confirma el pedido.
                                puedeCanjear && <span style={{ fontSize: 11, color: '#7a6a50', fontStyle: 'italic' }}>Pídeselo al camarero</span>
                              ) : (
                                <button
                                  style={{ ...S.upsellBtn, opacity: puedeCanjear ? 1 : 0.4 }}
                                  disabled={!puedeCanjear}
                                  onClick={() => canjearPremio(p)}
                                >
                                  Canjear
                                </button>
                              )}
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  )}
                </>
              ) : (
                <div style={{ fontSize: 13, color: '#7a6a50' }}>Todavía no tienes puntos — vuelve después de tu próxima visita.</div>
              )}
              <button style={{ ...S.resenaSkip, marginTop: 16 }} onClick={() => setEditandoTelefono(true)}>Cambiar teléfono</button>
            </>
          )}

          {overlay === 'fidelizacion' && editandoTelefono && (
            <>
              <button style={S.closeBtn} onClick={() => setOverlay(null)}>×</button>
              <div style={S.sheetTitle}>🎁 Suma puntos por esta visita</div>
              <div style={{ fontSize: 13, color: '#8a7560', marginBottom: 16, lineHeight: 1.5 }}>
                Déjanos tu teléfono y, cuando el camarero cierre la mesa, sumaremos puntos por tu consumo automáticamente a tu cuenta de fidelización.
              </div>
              {clienteError && <div style={{ ...S.error, margin: '0 0 12px' }}>{clienteError}</div>}
              <input
                style={S.noteInput}
                type="tel"
                placeholder="Tu teléfono"
                value={telefonoInput}
                onChange={e => setTelefonoInput(e.target.value)}
                autoFocus
              />
              <input
                style={{ ...S.noteInput, marginTop: 8 }}
                type="text"
                placeholder="Tu nombre (opcional)"
                value={nombreInput}
                onChange={e => setNombreInput(e.target.value)}
              />
              <button style={{ ...S.confirmBtn(guardandoCliente), marginTop: 16 }} onClick={guardarCliente} disabled={guardandoCliente}>
                {guardandoCliente ? 'Guardando...' : (session?.cliente_telefono ? 'Actualizar teléfono' : 'Guardar y sumar puntos')}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
