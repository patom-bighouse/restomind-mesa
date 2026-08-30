import { useState, useEffect, useRef } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'
import { playWaiterBell, unlockAudio } from '../lib/sound'
import { resolverMenuActivo, aplicarPreciosMenu } from '../lib/menus'
import CamareroClientes from '../components/CamareroClientes'
import CamareroReservas from '../components/CamareroReservas'
import CamareroLimpieza from '../components/CamareroLimpieza'
import CamareroCocina from '../components/CamareroCocina'

const PERMISOS_IMPLEMENTADOS = ['pedidos', 'clientes', 'reservas', 'limpieza', 'cocina']
const PERMISOS_LABEL = { pedidos: 'Pedidos', clientes: 'Clientes', reservas: 'Reservas', limpieza: 'Limpieza', cocina: 'Cocina' }

// Mismo catálogo fijo que AdminCarta.jsx y Mesa.jsx (Reglamento UE 1169/2011).
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
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif", display: 'flex', flexDirection: 'column' },
  header: { background: '#0a0a0a', padding: '14px 20px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  stickyTop: { position: 'sticky', top: 0, zIndex: 15, background: '#111' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 18, fontWeight: 600, color: '#e8c97a' },
  sub: { fontSize: 12, color: '#8a7560', marginTop: 2 },
  badge: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 20, padding: '5px 14px', fontSize: 12, color: '#c4a85a' },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 12, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  sectionBtn: { position: 'relative', background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '16px', fontSize: 15, fontWeight: 500, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  alertBadge: { position: 'absolute', top: -8, right: -8, background: '#e74c3c', color: '#fff', fontSize: 11, fontWeight: 600, minWidth: 20, height: 20, borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 5px' },
  llamadaBanner: { background: '#2a1a00', border: '1px solid #d4a017', borderRadius: 12, padding: '10px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' },

  center: { display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, padding: 24, textAlign: 'center', gap: 18 },
  pinDots: { display: 'flex', gap: 14, margin: '8px 0' },
  pinDot: (filled) => ({ width: 16, height: 16, borderRadius: '50%', background: filled ? '#e8c97a' : 'transparent', border: `1.5px solid ${filled ? '#e8c97a' : '#3a2e20'}` }),
  pinPad: { display: 'grid', gridTemplateColumns: 'repeat(3, 64px)', gap: 12 },
  pinKey: { width: 64, height: 64, borderRadius: '50%', background: '#1a1a1a', border: '0.5px solid #3a2e20', color: '#f0e8d8', fontSize: 22, fontFamily: "'Inter', sans-serif", cursor: 'pointer' },
  pinKeyGhost: { width: 64, height: 64 },
  error: { fontSize: 13, color: '#e87a7a' },

  mesasGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))', gap: 12, padding: 20 },
  mesaCard: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '16px 14px', cursor: 'pointer', textAlign: 'center' },
  limpiezaOverlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 20 },
  limpiezaBox: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 16, padding: 24, width: '100%', maxWidth: 380 },
  limpiezaTitle: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 4 },
  limpiezaSub: { fontSize: 13, color: '#8a7560', marginBottom: 18 },
  limpiezaPasoRow: { display: 'flex', alignItems: 'center', gap: 10, padding: '10px 0', borderBottom: '0.5px solid #2a2a2a', cursor: 'pointer' },
  limpiezaCheck: (marcado) => ({ width: 22, height: 22, borderRadius: 6, border: `1.5px solid ${marcado ? '#2ecc71' : '#3a2e20'}`, background: marcado ? '#2ecc71' : 'transparent', color: '#111', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, flexShrink: 0 }),
  limpiezaTexto: (marcado) => ({ fontSize: 14, color: marcado ? '#7a6a50' : '#f0e8d8', textDecoration: marcado ? 'line-through' : 'none' }),
  limpiezaCloseBtn: { width: '100%', background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: 12, fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif", marginTop: 16 },
  mesaNum: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a' },
  mesaZona: { fontSize: 11, color: '#8a7560', marginTop: 2 },
  mesaComensales: { fontSize: 11, color: '#7a6a50', marginTop: 6 },
  emptyMsg: { padding: 40, textAlign: 'center', fontSize: 14, color: '#666' },

  catsBar: { display: 'flex', gap: 8, padding: '10px 16px', overflowX: 'auto', borderBottom: '0.5px solid #2a2a2a' },
  cat: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 20, padding: '6px 14px', fontSize: 12, fontWeight: 500, cursor: 'pointer', whiteSpace: 'nowrap', fontFamily: "'Inter', sans-serif" }),
  comensalBar: { display: 'flex', alignItems: 'center', gap: 8, padding: '8px 16px', overflowX: 'auto', borderBottom: '0.5px solid #2a2a2a' },
  comensalLabel: { fontSize: 11, color: '#7a6a50', whiteSpace: 'nowrap' },
  comensalChip: (active) => ({ fontSize: 12, fontWeight: 500, padding: '5px 12px', borderRadius: 20, border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, background: active ? '#e8c97a' : '#1a1a1a', color: active ? '#111' : '#c4a85a', cursor: 'pointer', whiteSpace: 'nowrap', fontFamily: "'Inter', sans-serif" }),
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
  upsellCard: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, background: '#1a1a1a', border: '0.5px dashed #4a3c25', borderRadius: 10, padding: '10px 12px', marginBottom: 8 },
  upsellMsg: { fontSize: 13, color: '#f0e8d8' },
  upsellBtn: { flexShrink: 0, background: 'transparent', border: '0.5px solid #e8c97a', borderRadius: 8, padding: '7px 12px', fontSize: 12, fontWeight: 500, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
}

export default function Camarero() {
  const { restaurantId } = useParams()
  const [restaurant, setRestaurant] = useState(null)
  const [camarero, setCamarero] = useState(null) // { id, nombre, permisos }
  const [seccionActiva, setSeccionActiva] = useState(null) // 'pedidos' | 'clientes' | null (selector)
  const [pinInput, setPinInput] = useState('')
  const [pinError, setPinError] = useState(null)
  const [verificando, setVerificando] = useState(false)

  const [tables, setTables] = useState([])
  const [sessions, setSessions] = useState({}) // table_id -> session row
  const [selectedTable, setSelectedTable] = useState(null)
  const [modoHabilitado, setModoHabilitado] = useState(true)
  const [abriendoMesa, setAbriendoMesa] = useState(null)
  const [limpiezaPasos, setLimpiezaPasos] = useState([])
  const [limpiezaModal, setLimpiezaModal] = useState(null) // table | null
  const [alertas, setAlertas] = useState({ limpieza: 0, llamadas: 0 })
  const [llamadasPendientes, setLlamadasPendientes] = useState([])
  const llamadaIdsPrevias = useRef(null) // null hasta la primera carga, para no sonar con llamadas ya existentes

  const [categories, setCategories] = useState([])
  const [items, setItems] = useState([])
  const [itemModifiers, setItemModifiers] = useState({})
  const [upsellRules, setUpsellRules] = useState([])
  const [modSelectorItem, setModSelectorItem] = useState(null)
  const [modSelectorChoices, setModSelectorChoices] = useState({})
  const [activeCat, setActiveCat] = useState('todos')
  const [selectedComensal, setSelectedComensal] = useState(1) // número de comensal | null ("Compartido")
  const [alergenosExcluidos, setAlergenosExcluidos] = useState([])
  const [showAlergenosPanel, setShowAlergenosPanel] = useState(false)
  const [cart, setCart] = useState({})
  const [showCart, setShowCart] = useState(false)
  const [sending, setSending] = useState(false)
  const [sendError, setSendError] = useState(null)
  const [sendSuccess, setSendSuccess] = useState(false)

  const [showFidelizacion, setShowFidelizacion] = useState(false)
  const [telefonoInput, setTelefonoInput] = useState('')
  const [nombreInput, setNombreInput] = useState('')
  const [guardandoCliente, setGuardandoCliente] = useState(false)
  const [clienteError, setClienteError] = useState(null)
  const [editandoTelefono, setEditandoTelefono] = useState(false)
  const [fidelizacionEstado, setFidelizacionEstado] = useState(null)
  const [cargandoEstadoFidelizacion, setCargandoEstadoFidelizacion] = useState(false)
  const [premiosEnCarrito, setPremiosEnCarrito] = useState([])

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
    const persona = data[0]
    setCamarero(persona)
    setPinInput('')
    const permisosUtiles = (persona.permisos || []).filter(p => PERMISOS_IMPLEMENTADOS.includes(p))
    // Con un solo permiso útil, entra directo a esa sección — el
    // selector solo aparece si hay más de uno para elegir.
    setSeccionActiva(permisosUtiles.length === 1 ? permisosUtiles[0] : null)
    if (permisosUtiles.includes('pedidos')) {
      await loadTablas()
      await loadLimpiezaPasos()
    }
  }

  function cambiarCamarero() {
    setCamarero(null)
    setSeccionActiva(null)
    setSelectedTable(null)
    setPinInput('')
  }

  // Si tenía más de un permiso, vuelve al selector; si era el único,
  // no hay a dónde volver más que salir.
  function volverDeSeccion() {
    const permisosUtiles = (camarero.permisos || []).filter(p => PERMISOS_IMPLEMENTADOS.includes(p))
    if (permisosUtiles.length > 1) setSeccionActiva(null)
    else cambiarCamarero()
  }

  // ---------- Selección de mesa ----------
  async function loadTablas() {
    const { data: tabs } = await supabase
      .from('tables')
      .select('id, numero, zona, capacidad, activa, necesita_limpieza, limpieza_progreso')
      .eq('restaurant_id', restaurantId)
      .eq('activa', true)
      .order('numero')
    setTables(tabs || [])

    const { data: sess } = await supabase
      .from('table_sessions')
      .select('id, table_id, comensales, camarero_id, cliente_telefono, cliente_nombre')
      .eq('restaurant_id', restaurantId)
      .eq('estado', 'abierta')
    const map = {}
    ;(sess || []).forEach(s => { map[s.table_id] = s })
    setSessions(map)
  }

  async function loadLimpiezaPasos() {
    const { data } = await supabase
      .from('limpieza_pasos')
      .select('id, texto, orden')
      .eq('restaurant_id', restaurantId)
      .eq('activo', true)
      .order('orden')
    setLimpiezaPasos(data || [])
  }

  // Tilda/destilda un paso del checklist de la mesa que se está
  // limpiando. Cuando quedan todos los pasos activos tildados, la
  // mesa vuelve a estar libre sola.
  async function toggleLimpiezaPaso(table, pasoId) {
    const actual = table.limpieza_progreso || []
    const nuevo = actual.includes(pasoId) ? actual.filter(id => id !== pasoId) : [...actual, pasoId]
    const completo = limpiezaPasos.every(p => nuevo.includes(p.id))
    const patch = { limpieza_progreso: nuevo, necesita_limpieza: !completo }
    setTables(prev => prev.map(t => t.id === table.id ? { ...t, ...patch } : t))
    setLimpiezaModal(prev => {
      if (!prev || prev.id !== table.id) return prev
      return completo ? null : { ...prev, ...patch }
    })
    await supabase.from('tables').update(patch).eq('id', table.id)
  }

  // Avisos de mesas por limpiar / llamadas al camarero pendientes: como
  // anon no puede leer waiter_calls directo, se pasa por la caja fuerte
  // (fn_staff_contar_alertas ya filtra según los permisos que tenga
  // este camarero). Se sondea cada 10s mientras haya sesión iniciada,
  // así el aviso aparece tanto en el selector de sección como recién
  // entra directo a Pedidos si ese es su único permiso.
  useEffect(() => {
    if (!camarero) return
    const unlock = () => { unlockAudio(); window.removeEventListener('pointerdown', unlock) }
    window.addEventListener('pointerdown', unlock)
    loadAlertas()
    const interval = setInterval(loadAlertas, 10000)
    return () => { clearInterval(interval); window.removeEventListener('pointerdown', unlock) }
  }, [camarero])

  async function loadAlertas() {
    const { data } = await supabase.rpc('fn_staff_contar_alertas', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
    })
    if (data) setAlertas(data)
  }

  // Detalle de las llamadas (con número de mesa) para el aviso dentro
  // de la pantalla de Pedidos — solo se sondea mientras esa pantalla
  // está a la vista, y suena la campanilla si aparece una llamada nueva.
  useEffect(() => {
    if (!camarero || seccionActiva !== 'pedidos' || selectedTable) return
    llamadaIdsPrevias.current = null
    loadLlamadas()
    const interval = setInterval(loadLlamadas, 10000)
    return () => clearInterval(interval)
  }, [camarero, seccionActiva, selectedTable])

  async function loadLlamadas() {
    const { data } = await supabase.rpc('fn_staff_listar_llamadas', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
    })
    const lista = data || []
    if (llamadaIdsPrevias.current && lista.some(l => !llamadaIdsPrevias.current.has(l.id))) playWaiterBell()
    llamadaIdsPrevias.current = new Set(lista.map(l => l.id))
    setLlamadasPendientes(lista)
  }

  async function atenderLlamada(id) {
    setLlamadasPendientes(prev => prev.filter(l => l.id !== id))
    await supabase.rpc('fn_staff_marcar_llamada_atendida', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
      p_llamada_id: id,
    })
    await loadAlertas()
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
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'tables',
        filter: `restaurant_id=eq.${restaurantId}`,
      }, (payload) => {
        // Mantiene sincronizado el progreso del checklist de limpieza
        // entre pestañas/dispositivos distintos.
        setTables(prev => prev.map(t => t.id === payload.new.id ? { ...t, ...payload.new } : t))
        setLimpiezaModal(prev => {
          if (!prev || prev.id !== payload.new.id) return prev
          return payload.new.necesita_limpieza ? { ...prev, ...payload.new } : null
        })
        // Si la mesa que este camarero tenía abierta para pedir se
        // acaba de marcar "necesita limpieza" (se cerró desde otro
        // lado mientras él estaba ahí — lo más probable es que sea el
        // mismo camarero quien la vuelva a atender), lo devolvemos a
        // la lista y le mostramos el checklist directamente.
        setSelectedTable(prev => {
          if (prev && prev.id === payload.new.id && payload.new.necesita_limpieza) {
            setLimpiezaModal({ ...prev, ...payload.new })
            return null
          }
          return prev
        })
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [camarero, restaurantId])

  async function abrirMesa(table) {
    if (table.necesita_limpieza) { setLimpiezaModal(table); return }
    setAbriendoMesa(table.id)
    const session = sessions[table.id]
    try {
      if (!session) {
        // Mesa sin sesión: el camarero la abre él mismo, asignándosela.
        const { data, error: err } = await supabase
          .from('table_sessions')
          .insert({ table_id: table.id, restaurant_id: restaurantId, comensales: table.capacidad, camarero_id: camarero.id })
          .select('id, table_id, comensales, camarero_id, cliente_telefono, cliente_nombre')
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
      await loadMenu(table.zona)
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

  // ---------- Fidelización: el camarero carga el teléfono del cliente ----------
  function abrirFidelizacion() {
    setTelefonoInput(selectedTable?.session?.cliente_telefono || '')
    setNombreInput(selectedTable?.session?.cliente_nombre || '')
    setClienteError(null)
    setShowFidelizacion(true)
    if (selectedTable?.session?.cliente_telefono) {
      setEditandoTelefono(false)
      cargarEstadoFidelizacion(selectedTable.session.cliente_telefono)
    } else {
      setEditandoTelefono(true)
      setFidelizacionEstado(null)
    }
  }

  async function cargarEstadoFidelizacion(telefono) {
    setCargandoEstadoFidelizacion(true)
    const { data } = await supabase.rpc('fn_estado_fidelizacion', {
      p_restaurant_id: restaurantId,
      p_telefono: telefono,
    })
    setCargandoEstadoFidelizacion(false)
    setFidelizacionEstado(data || null)
  }

  const puntosReservados = premiosEnCarrito.reduce((s, p) => s + p.costoPuntos, 0)
  const puntosDisponibles = (fidelizacionEstado?.puntos || 0) - puntosReservados

  function canjearPremio(premio) {
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

  async function guardarCliente() {
    const telefono = telefonoInput.trim()
    if (!telefono) { setClienteError('Introduce el teléfono del cliente.'); return }
    setGuardandoCliente(true)
    setClienteError(null)
    const nuevoNombre = nombreInput.trim() || selectedTable.session.cliente_nombre || null
    const { error: err } = await supabase
      .from('table_sessions')
      .update({ cliente_telefono: telefono, cliente_nombre: nuevoNombre })
      .eq('id', selectedTable.session.id)
    setGuardandoCliente(false)
    if (err) { setClienteError(err.message); return }
    setSelectedTable(prev => prev ? { ...prev, session: { ...prev.session, cliente_telefono: telefono, cliente_nombre: nuevoNombre } } : prev)
    setSessions(prev => ({ ...prev, [selectedTable.id]: { ...prev[selectedTable.id], cliente_telefono: telefono, cliente_nombre: nuevoNombre } }))
    setEditandoTelefono(false)
    await cargarEstadoFidelizacion(telefono)
  }

  // ---------- Carta ----------
  async function loadMenu(zona) {
    const { data: cats } = await supabase
      .from('categories')
      .select('id, nombre, orden, categoria_padre_id')
      .eq('restaurant_id', restaurantId)
      .order('orden')
    setCategories(cats || [])
    const { data: menuItems } = await supabase
      .from('menu_items')
      .select('id, nombre, descripcion, precio, emoji, foto_url, category_id, disponible, alergenos')
      .eq('restaurant_id', restaurantId)
      .eq('disponible', true)
      .order('orden')

    // Multi-menú: mismas excepciones de precio/exclusión que en
    // Mesa.jsx, según la zona de la mesa y la hora actual.
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

  // Cada línea del carrito queda atada a un comensal — dos unidades
  // del mismo plato para personas distintas son líneas separadas.
  // "x" identifica lo compartido (sin comensal).
  const comensalTag = (c) => (c == null ? 'x' : `c${c}`)

  function change(item, delta) {
    if (delta > 0 && itemModifiers[item.id]?.length > 0) {
      setModSelectorItem(item)
      setModSelectorChoices({})
      return
    }
    const cartKey = `${item.id}::${comensalTag(selectedComensal)}`
    setCart(prev => {
      const current = prev[cartKey]?.qty || 0
      const next = Math.max(0, current + delta)
      if (next === 0) {
        const { [cartKey]: _, ...rest } = prev
        return rest
      }
      return { ...prev, [cartKey]: { qty: next, precio: item.precio, nombre: item.nombre, menuItemId: item.id, comensal: selectedComensal } }
    })
  }

  function changeQtyByKey(key, delta) {
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
  }

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
    const faltante = grupos.find(g => g.obligatorio && (
      g.tipo_seleccion === 'multiple'
        ? !(modSelectorChoices[g.grupo_id]?.length > 0)
        : !modSelectorChoices[g.grupo_id]
    ))
    if (faltante) return

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
          menuItemId: item.id,
          modificadoresDetalle: detalle,
          comensal: selectedComensal,
        },
      }
    })
    setModSelectorItem(null)
    setModSelectorChoices({})
  }

  const cartCount = Object.values(cart).reduce((a, b) => a + b.qty, 0)
  const descuentoPremios = premiosEnCarrito.reduce((s, p) => s + (p.tipo === 'descuento' ? p.descuentoImporte : 0), 0)
  const cartTotal = Math.max(0, Object.values(cart).reduce((s, i) => s + i.precio * i.qty, 0) - descuentoPremios)

  const itemIdsEnCarrito = new Set(Object.values(cart).map(v => v.menuItemId))
  const categoriasEnCarrito = new Set(
    Object.values(cart).map(v => items.find(i => i.id === v.menuItemId)?.category_id).filter(Boolean)
  )
  const categoriasSugeridas = new Map()
  upsellRules.forEach(r => {
    if (!itemIdsEnCarrito.has(r.trigger_item_id)) return
    if (categoriasEnCarrito.has(r.sugerida_categoria_id)) return
    if (!categoriasSugeridas.has(r.sugerida_categoria_id)) categoriasSugeridas.set(r.sugerida_categoria_id, r)
  })
  const sugerencias = [...categoriasSugeridas.values()]
    .map(r => ({ ...r, categoria: categories.find(c => c.id === r.sugerida_categoria_id) }))
    .filter(r => r.categoria)

  async function confirmarPedido() {
    setSending(true)
    setSendError(null)
    try {
      const itemsPayload = Object.entries(cart).map(([id, v]) => ({
        menu_item_id: v.menuItemId || id,
        cantidad: v.qty,
        notas: null,
        comensal: v.comensal ?? null,
        modificadores: (v.modificadoresDetalle || []).map(m => ({ grupo_id: m.grupo_id, opcion_id: m.opcion_id })),
      }))
      const premiosPayload = premiosEnCarrito.map(p => ({ premio_id: p.premioId, comensal: p.comensal ?? null }))
      const { error: err } = await supabase.rpc('fn_registrar_pedido', {
        p_table_session_id: selectedTable.session.id,
        p_items: itemsPayload,
        p_camarero_id: camarero.id,
        p_premios_canjeados: premiosPayload,
      })
      if (err) throw err
      setCart({})
      setPremiosEnCarrito([])
      if (selectedTable?.session?.cliente_telefono) await cargarEstadoFidelizacion(selectedTable.session.cliente_telefono)
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
          <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' }}>Introduce tu PIN</div>
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

  // ---------- Render: selector de sección (solo si hay más de un permiso útil) ----------
  if (!seccionActiva) {
    const permisosUtiles = (camarero.permisos || []).filter(p => PERMISOS_IMPLEMENTADOS.includes(p))
    return (
      <div style={S.app}>
        <div style={S.header}>
          <div>
            <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
            <div style={S.sub}>Hola, {camarero.nombre}</div>
          </div>
          <button style={S.logoutBtn} onClick={cambiarCamarero}>Cambiar de persona</button>
        </div>
        <div style={S.center}>
          <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 6 }}>¿Qué quieres hacer?</div>
          {permisosUtiles.length === 0 ? (
            <div style={{ fontSize: 13, color: '#8a7560', textAlign: 'center' }}>No tienes ningún permiso asignado todavía. Pídele al dueño que te lo configure.</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, width: '100%', maxWidth: 280 }}>
              {permisosUtiles.map(p => {
                const alerta = p === 'limpieza' ? alertas.limpieza : p === 'pedidos' ? alertas.llamadas : 0
                return (
                  <button key={p} onClick={() => setSeccionActiva(p)} style={S.sectionBtn}>
                    {PERMISOS_LABEL[p]}
                    {alerta > 0 && <span style={S.alertBadge}>{alerta}</span>}
                  </button>
                )
              })}
            </div>
          )}
        </div>
      </div>
    )
  }

  // ---------- Render: secciones fuera de "Pedidos" ----------
  if (seccionActiva === 'clientes') {
    return <CamareroClientes camarero={camarero} restaurantId={restaurantId} restaurant={restaurant} onVolver={volverDeSeccion} />
  }
  if (seccionActiva === 'reservas') {
    return <CamareroReservas camarero={camarero} restaurantId={restaurantId} onVolver={volverDeSeccion} />
  }
  if (seccionActiva === 'limpieza') {
    return <CamareroLimpieza restaurantId={restaurantId} onVolver={volverDeSeccion} />
  }
  if (seccionActiva === 'cocina') {
    return <CamareroCocina camarero={camarero} restaurantId={restaurantId} onVolver={volverDeSeccion} />
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
          {llamadasPendientes.length > 0 && (
            <div style={{ padding: '16px 20px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
              {llamadasPendientes.map(call => (
                <div key={call.id} style={S.llamadaBanner}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <span style={{ fontSize: 18 }}>🛎</span>
                    <div style={{ fontSize: 14, fontWeight: 500, color: '#f0e8d8' }}>Mesa {call.mesa_numero} llama al camarero</div>
                  </div>
                  <button onClick={() => atenderLlamada(call.id)} style={{ background: '#d4a017', border: 'none', borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, color: '#111', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
                    Atendido
                  </button>
                </div>
              ))}
            </div>
          )}
          <div style={S.center}>
            <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a' }}>Modo camarero no habilitado</div>
            <div style={{ fontSize: 13, color: '#8a7560' }}>Este restaurante no tiene activado el modo de pedidos por camarero. Pídele al dueño que lo active desde Configuración.</div>
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
          <div style={{ display: 'flex', gap: 8 }}>
            {(camarero.permisos || []).filter(p => PERMISOS_IMPLEMENTADOS.includes(p)).length > 1 && (
              <button style={S.logoutBtn} onClick={() => setSeccionActiva(null)}>Cambiar de sección</button>
            )}
            <button style={S.logoutBtn} onClick={cambiarCamarero}>Cambiar de camarero</button>
          </div>
        </div>
        {sendError && <div style={{ ...S.error, padding: '10px 16px' }}>{sendError}</div>}

        {llamadasPendientes.length > 0 && (
          <div style={{ padding: '0 20px 4px', display: 'flex', flexDirection: 'column', gap: 8 }}>
            {llamadasPendientes.map(call => (
              <div key={call.id} style={S.llamadaBanner}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{ fontSize: 18 }}>🛎</span>
                  <div style={{ fontSize: 14, fontWeight: 500, color: '#f0e8d8' }}>Mesa {call.mesa_numero} llama al camarero</div>
                </div>
                <button onClick={() => atenderLlamada(call.id)} style={{ background: '#d4a017', border: 'none', borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, color: '#111', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
                  Atendido
                </button>
              </div>
            ))}
          </div>
        )}

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
              <div
                key={t.id}
                style={{ ...S.mesaCard, opacity: abriendoMesa === t.id ? 0.5 : 1, ...(t.necesita_limpieza ? { border: '0.5px solid #d4a017', background: '#2a2010' } : {}) }}
                onClick={() => abrirMesa(t)}
              >
                <div style={S.mesaNum}>Mesa {t.numero}</div>
                {t.zona && <div style={S.mesaZona}>{t.zona.charAt(0).toUpperCase() + t.zona.slice(1)}</div>}
                <div style={S.mesaComensales}>{t.necesita_limpieza ? '🧹 Necesita limpieza' : `Capacidad: ${t.capacidad}`}</div>
              </div>
            ))}
          </div>
        )}

        {limpiezaModal && (
          <div style={S.limpiezaOverlay} onClick={() => setLimpiezaModal(null)}>
            <div style={S.limpiezaBox} onClick={e => e.stopPropagation()}>
              <div style={S.limpiezaTitle}>🧹 Mesa {limpiezaModal.numero}</div>
              <div style={S.limpiezaSub}>Marca cada paso a medida que lo completas — la mesa vuelve a estar libre sola.</div>
              {limpiezaPasos.map(paso => {
                const marcado = (limpiezaModal.limpieza_progreso || []).includes(paso.id)
                return (
                  <div key={paso.id} style={S.limpiezaPasoRow} onClick={() => toggleLimpiezaPaso(limpiezaModal, paso.id)}>
                    <div style={S.limpiezaCheck(marcado)}>{marcado ? '✓' : ''}</div>
                    <div style={S.limpiezaTexto(marcado)}>{paso.texto}</div>
                  </div>
                )
              })}
              <button style={S.limpiezaCloseBtn} onClick={() => setLimpiezaModal(null)}>Cerrar</button>
            </div>
          </div>
        )}
      </div>
    )
  }

  // "Todos" itera solo las categorías principales (sus subcategorías
  // se listan anidadas debajo de cada una); elegir una categoría
  // puntual — principal o subcategoría — la aísla a ella sola.
  const filteredCats = activeCat === 'todos'
    ? categories.filter(c => !c.categoria_padre_id)
    : categories.filter(c => c.id === activeCat)

  function renderItemPedido(item) {
    return (
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
          {item.alergenos && item.alergenos.length > 0 && (
            <div style={{ fontSize: 13, marginTop: 3 }} title={item.alergenos.map(k => ALERGENOS.find(a => a.key === k)?.label).join(', ')}>
              {item.alergenos.map(k => ALERGENOS.find(a => a.key === k)?.emoji).join(' ')}
            </div>
          )}
        </div>
        {itemModifiers[item.id]?.length > 0 ? (
          <button style={{ ...S.btn, width: 'auto', padding: '0 14px', borderRadius: 16, fontSize: 12 }} onClick={() => change(item, 1)}>
            Elegir
          </button>
        ) : (
          <div style={S.qty}>
            <button style={S.btn} onClick={() => change(item, -1)}>−</button>
            <span style={S.qnum}>{cart[`${item.id}::${comensalTag(selectedComensal)}`]?.qty || 0}</span>
            <button style={S.btn} onClick={() => change(item, 1)}>+</button>
          </div>
        )}
      </div>
    )
  }

  // ---------- Render: carta para cargar pedido ----------
  return (
    <div style={S.app}>
      <div style={S.stickyTop}>
      <div style={S.header}>
        <div>
          <div style={S.logo}>{restaurant?.nombre || 'Restomind'}</div>
          <div style={S.sub}>{camarero.nombre} · Mesa {selectedTable.numero}</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {sendSuccess && <span style={{ fontSize: 12, color: '#7ae8a0' }}>✓ Pedido enviado</span>}
          <button
            onClick={() => setShowAlergenosPanel(true)}
            style={{ background: alergenosExcluidos.length > 0 ? '#3a2010' : 'transparent', border: `0.5px solid ${alergenosExcluidos.length > 0 ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 12, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
          >
            🌾 Alérgenos{alergenosExcluidos.length > 0 ? ` (${alergenosExcluidos.length})` : ''}
          </button>
          <button
            onClick={abrirFidelizacion}
            style={{ background: selectedTable?.session?.cliente_telefono ? '#3a2010' : 'transparent', border: `0.5px solid ${selectedTable?.session?.cliente_telefono ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 12, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
          >
            🎁 {selectedTable?.session?.cliente_telefono ? 'Sumando puntos' : 'Sumar puntos'}
          </button>
          <button style={S.logoutBtn} onClick={volverAMesas}>Cambiar de mesa</button>
        </div>
      </div>

      <div style={S.catsBar}>
        <button style={S.cat(activeCat === 'todos')} onClick={() => setActiveCat('todos')}>Todos</button>
        {categories.map(c => (
          <button key={c.id} style={S.cat(activeCat === c.id)} onClick={() => setActiveCat(c.id)}>{c.nombre}</button>
        ))}
      </div>

      {selectedTable?.session?.comensales > 1 && (
        <div style={S.comensalBar}>
          <span style={S.comensalLabel}>¿Para quién?</span>
          {Array.from({ length: selectedTable.session.comensales }, (_, i) => i + 1).map(n => (
            <button key={n} style={S.comensalChip(selectedComensal === n)} onClick={() => setSelectedComensal(n)}>{n}</button>
          ))}
          <button style={S.comensalChip(selectedComensal == null)} onClick={() => setSelectedComensal(null)}>Compartido</button>
        </div>
      )}
      </div>

      <div style={S.scroll}>
        {filteredCats.map(cat => {
          const filtroAlergenos = i => !alergenosExcluidos.some(k => (i.alergenos || []).includes(k))
          const catItems = items.filter(i => i.category_id === cat.id).filter(filtroAlergenos)
          const subcats = cat.categoria_padre_id ? [] : categories.filter(c => c.categoria_padre_id === cat.id)
          const subcatsConItems = subcats
            .map(sub => ({ sub, subItems: items.filter(i => i.category_id === sub.id).filter(filtroAlergenos) }))
            .filter(x => x.subItems.length > 0)
          if (!catItems.length && !subcatsConItems.length) return null
          return (
            <div key={cat.id}>
              {catItems.length > 0 && (
                <>
                  <div style={S.secTitle}>{cat.nombre}</div>
                  {catItems.map(item => renderItemPedido(item))}
                </>
              )}
              {subcatsConItems.map(({ sub, subItems }) => (
                <div key={sub.id}>
                  <div style={{ ...S.secTitle, fontSize: 13, opacity: 0.85, paddingLeft: 10 }}>{sub.nombre}</div>
                  {subItems.map(item => renderItemPedido(item))}
                </div>
              ))}
            </div>
          )
        })}
      </div>

      <div style={S.cartBar(cartCount > 0 || premiosEnCarrito.length > 0)} onClick={() => setShowCart(true)}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={S.cartBadge}>{cartCount + premiosEnCarrito.length}</div>
          <span style={{ fontSize: 14, fontWeight: 500, color: '#1a1410' }}>Enviar a cocina</span>
        </div>
        <span style={{ fontSize: 15, fontWeight: 500, color: '#1a1410' }}>{formatMoney(cartTotal, restaurant?.moneda)}</span>
      </div>

      {showAlergenosPanel && (
        <div style={S.overlay} onClick={() => setShowAlergenosPanel(false)}>
          <div style={S.sheet} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>Alérgenos a evitar</div>
            <div style={{ fontSize: 12, color: '#8a7560', marginBottom: 14 }}>
              Marca los que el comensal quiere evitar — se ocultan de la carta los platos que los contengan.
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
      )}

      {modSelectorItem && (
        <div style={S.overlay} onClick={() => setModSelectorItem(null)}>
          <div style={S.sheet} onClick={e => e.stopPropagation()}>
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
          </div>
        </div>
      )}

      {showCart && (
        <div style={S.overlay} onClick={() => setShowCart(false)}>
          <div style={S.sheet} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>Pedido — Mesa {selectedTable.numero}</div>
            {Object.entries(cart).map(([id, v]) => (
              <div key={id} style={{ ...S.cartLine, flexDirection: 'column', alignItems: 'stretch', gap: 6 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <div>
                    <div style={{ fontSize: 14 }}>
                      {v.nombre}
                      {selectedTable?.session?.comensales > 1 && (
                        <span style={{ fontSize: 11, color: '#7a6a50' }}> · {v.comensal == null ? 'Compartido' : `Comensal ${v.comensal}`}</span>
                      )}
                    </div>
                    {v.modificadoresDetalle?.length > 0 && (
                      <div style={{ fontSize: 12, color: '#8a7560', marginTop: 2 }}>
                        {v.modificadoresDetalle.map(m => m.opcion_nombre).join(', ')}
                      </div>
                    )}
                  </div>
                  <span style={{ fontSize: 14, color: '#c4a85a' }}>{formatMoney(v.precio * v.qty, restaurant?.moneda)}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <button style={{ ...S.btn, width: 26, height: 26 }} onClick={() => changeQtyByKey(id, -1)}>−</button>
                  <span style={S.qnum}>{v.qty}</span>
                  <button style={{ ...S.btn, width: 26, height: 26 }} onClick={() => changeQtyByKey(id, 1)}>+</button>
                </div>
              </div>
            ))}
            {premiosEnCarrito.length > 0 && (
              <div style={{ marginTop: 6 }}>
                {premiosEnCarrito.map(p => (
                  <div key={p.key} style={S.cartLine}>
                    <div>
                      <div style={{ fontSize: 14 }}>🎁 {p.nombre}</div>
                      {selectedTable?.session?.comensales > 1 && (
                        <div style={{ fontSize: 11, color: '#7a6a50' }}>{p.comensal == null ? 'Compartido' : `Comensal ${p.comensal}`}</div>
                      )}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <span style={{ fontSize: 14, color: '#e8c97a' }}>{p.tipo === 'plato_gratis' ? 'GRATIS' : `-${formatMoney(p.descuentoImporte, restaurant?.moneda)}`}</span>
                      <button style={{ ...S.btn, width: 26, height: 26 }} onClick={() => quitarPremioCarrito(p.key)}>×</button>
                    </div>
                  </div>
                ))}
              </div>
            )}
            {sugerencias.length > 0 && (
              <div style={{ marginTop: 12 }}>
                {sugerencias.map(s => (
                  <div key={s.sugerida_categoria_id} style={S.upsellCard}>
                    <div style={S.upsellMsg}>{s.mensaje || `¿Le sumamos algo de ${s.categoria.nombre}?`}</div>
                    <button
                      style={S.upsellBtn}
                      onClick={() => { setActiveCat(s.sugerida_categoria_id); setShowCart(false) }}
                    >
                      Ver {s.categoria.nombre}
                    </button>
                  </div>
                ))}
              </div>
            )}

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

      {showFidelizacion && !editandoTelefono && selectedTable?.session?.cliente_telefono && (
        <div style={S.overlay} onClick={() => setShowFidelizacion(false)}>
          <div style={S.sheet} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>🎁 Fidelización — Mesa {selectedTable.numero}</div>
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
                    Faltan {formatMoney(fidelizacionEstado.proximo_nivel.umbral_gasto - fidelizacionEstado.gasto_acumulado, restaurant?.moneda)} para {fidelizacionEstado.proximo_nivel.nombre}
                  </div>
                )}
                {premiosEnCarrito.length > 0 && (
                  <div style={{ marginTop: 8, marginBottom: 8 }}>
                    <div style={{ fontSize: 12, color: '#8a7560', marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.05em' }}>En el pedido</div>
                    {premiosEnCarrito.map(p => (
                      <div key={p.key} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0' }}>
                        <div style={{ fontSize: 13, color: '#e8c97a' }}>🎁 {p.nombre} ({p.costoPuntos} pts)</div>
                        <button style={{ background: 'none', border: 'none', color: '#7a6a50', fontSize: 12, textDecoration: 'underline', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }} onClick={() => quitarPremioCarrito(p.key)}>Quitar</button>
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
                        <div key={p.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 0', borderBottom: '0.5px solid #2a2a2a', opacity: puedeCanjear ? 1 : 0.5 }}>
                          <div>
                            <div style={{ fontSize: 13, color: '#f0e8d8' }}>
                              {p.tipo === 'plato_gratis' ? `🍽 ${p.menu_item_nombre}` : `💶 -${formatMoney(p.descuento_importe, restaurant?.moneda)}`}
                              {' · '}{p.nombre}
                            </div>
                            {p.descripcion && <div style={{ fontSize: 11, color: '#7a6a50' }}>{p.descripcion}</div>}
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <span style={{ fontSize: 12, color: puedeCanjear ? '#e8c97a' : '#7a6a50' }}>{p.costo_puntos} pts</span>
                            <button style={{ ...S.upsellBtn, opacity: puedeCanjear ? 1 : 0.4 }} disabled={!puedeCanjear} onClick={() => canjearPremio(p)}>
                              Canjear
                            </button>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </>
            ) : (
              <div style={{ fontSize: 13, color: '#7a6a50' }}>Este cliente todavía no tiene puntos.</div>
            )}
            <button
              style={{ background: 'none', border: 'none', color: '#7a6a50', fontSize: 12, textDecoration: 'underline', cursor: 'pointer', fontFamily: "'Inter', sans-serif", marginTop: 16 }}
              onClick={() => setEditandoTelefono(true)}
            >
              Cambiar teléfono
            </button>
          </div>
        </div>
      )}

      {showFidelizacion && editandoTelefono && (
        <div style={S.overlay} onClick={() => setShowFidelizacion(false)}>
          <div style={S.sheet} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>🎁 Fidelización — Mesa {selectedTable.numero}</div>
            <div style={{ fontSize: 12, color: '#8a7560', marginBottom: 14, lineHeight: 1.5 }}>
              Introduce el teléfono del cliente para que sume puntos automáticamente cuando se cierre la mesa como pagada.
            </div>
            {clienteError && <div style={{ fontSize: 13, color: '#e87a7a', marginBottom: 10 }}>{clienteError}</div>}
            <input
              style={{ width: '100%', background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '10px 12px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' }}
              type="tel"
              placeholder="Teléfono del cliente"
              value={telefonoInput}
              onChange={e => setTelefonoInput(e.target.value)}
              autoFocus
            />
            <input
              style={{ width: '100%', background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '10px 12px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box', marginTop: 8 }}
              type="text"
              placeholder="Nombre (opcional)"
              value={nombreInput}
              onChange={e => setNombreInput(e.target.value)}
            />
            <button style={S.confirmBtn(guardandoCliente)} onClick={guardarCliente} disabled={guardandoCliente}>
              {guardandoCliente ? 'Guardando...' : (selectedTable?.session?.cliente_telefono ? 'Actualizar teléfono' : 'Guardar y sumar puntos')}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
