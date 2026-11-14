import { useState, useEffect } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { createClient } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { isValidIban, formatIbanDisplay } from '../lib/iban'
import { PENALIZACION_PCT, CONDICIONES_VERSION } from '../lib/condiciones'
import { hoyMadrid, sumarDiasISO, hoyEnZona, ZONA_POR_DEFECTO } from '../lib/fechas'
import { opcionesZona, zonaPropuesta, pareceCanarias, avisoDireccion, nombreZona, horaActualEnZona, zonaValida, contarReservasFuturas } from '../lib/zonasHorarias'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

const S = {
  app: { minHeight: '100vh', background: '#0a0a0a', color: '#f0f0f0', fontFamily: "'Inter', sans-serif" },
  header: { background: '#111', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  sub: { fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: '0.1em', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a8a8a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 24, maxWidth: 900, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 20 },
  error: { background: '#2a1414', border: '0.5px solid #5a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  success: { background: '#142a1a', border: '0.5px solid #2a5a3a', borderRadius: 10, padding: '14px 16px', fontSize: 13, color: '#7ae8a0', marginBottom: 16, lineHeight: 1.6 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },

  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", marginBottom: 24 },

  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: '0.06em', padding: '10px 14px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '14px', fontSize: 14, borderBottom: '0.5px solid #1a1a1a', verticalAlign: 'middle' },
  restName: { fontWeight: 500, color: '#f0f0f0' },
  restSlug: { fontSize: 12, color: '#666', marginTop: 2 },
  linkBtn: { background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 12px', fontSize: 12, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none', marginRight: 6, display: 'inline-block' },
  badge: (active) => ({ fontSize: 11, fontWeight: 500, padding: '3px 10px', borderRadius: 20, background: active ? '#142a1a' : '#2a1414', color: active ? '#2ecc71' : '#e74c3c' }),

  modal: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 50, padding: 20 },
  modalBox: { background: '#161616', border: '0.5px solid #2a2a2a', borderRadius: 16, padding: 24, width: '100%', maxWidth: 420, maxHeight: '85vh', overflowY: 'auto' },
  modalTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 18 },
  label: { fontSize: 12, color: '#8a8a8a', marginBottom: 6, display: 'block', marginTop: 14 },
  input: { width: '100%', background: '#0a0a0a', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0f0f0', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' },
  hint: { fontSize: 11, color: '#555', marginTop: 4 },
  modalBtns: { display: 'flex', gap: 10, marginTop: 22 },
  saveBtn: (disabled) => ({ flex: 1, background: disabled ? '#3a3a2a' : '#e8c97a', color: disabled ? '#888' : '#111', border: 'none', borderRadius: 10, padding: 12, fontSize: 14, fontWeight: 500, cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
  cancelBtn: { flex: 1, background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: 12, fontSize: 14, color: '#8a8a8a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  tabBar: { display: 'flex', gap: 4, marginTop: 16, marginBottom: 4, borderBottom: '0.5px solid #2a2a2a' },
  tabBtn: (active) => ({ background: 'transparent', border: 'none', borderBottom: active ? '2px solid #e8c97a' : '2px solid transparent', color: active ? '#e8c97a' : '#8a8a8a', padding: '8px 4px', marginRight: 18, fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }),
}

const MOTIVOS_BAJA = ['Precio', 'No lo usa', 'Cerró el local', 'Se va a otra solución', 'Problemas con el servicio', 'Otro']

const fmtFechaES = iso => new Date(iso + 'T00:00:00').toLocaleDateString('es-ES')
const hoyISO = () => hoyMadrid()
const fmtEur = n => `${Number(n || 0).toLocaleString('es-ES', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}€`

function slugify(text) {
  return text.toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
}

// Phone number ID de Meta: el número de WhatsApp al que escriben los
// clientes; el enrutador de n8n identifica el restaurante con él.
function phoneIdValido(id) {
  return !id.trim() || /^\d{6,20}$/.test(id.trim())
}

// Índice único restaurants_whatsapp_phone_number_id_unique (sql/whatsapp_phone_number_id.sql)
function errorPhoneId(err) {
  if (err.code === '23505' && err.message?.includes('whatsapp_phone_number_id')) {
    return new Error('Ese Phone number ID de WhatsApp ya está asignado a otro restaurante.')
  }
  return err
}

// Mismos países/monedas habilitados en el check constraint de la base
// (restaurants_moneda_check). Si añades una moneda nueva ahí, súmala aquí
// también para que aparezca en el selector.
const PAISES = [
  { code: 'ES', label: 'España', moneda: 'EUR' },
  { code: 'MX', label: 'México', moneda: 'MXN' },
  { code: 'AR', label: 'Argentina', moneda: 'ARS' },
  { code: 'CO', label: 'Colombia', moneda: 'COP' },
  { code: 'CL', label: 'Chile', moneda: 'CLP' },
  { code: 'PE', label: 'Perú', moneda: 'PEN' },
  { code: 'US', label: 'Estados Unidos', moneda: 'USD' },
]
const MONEDAS = ['EUR', 'USD', 'MXN', 'ARS', 'COP', 'CLP', 'PEN']

export default function SuperAdminRestaurantes() {
  const navigate = useNavigate()
  const [restaurants, setRestaurants] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)

  const [modalMode, setModalMode] = useState(null) // null | 'create' | 'edit'
  const [editingId, setEditingId] = useState(null)
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState({
    nombre: '', email: '', password: '', whatsapp: '', whatsappPhoneId: '',
    pais: 'ES', moneda: 'EUR', direccion: '',
    zonaHoraria: ZONA_POR_DEFECTO, zonaHorariaGuardada: null, zonaTocada: false,
    iban: '', titularCuenta: '',
  })
  const [ibanTouched, setIbanTouched] = useState(false)
  // Aviso antes de cambiar la zona horaria de un restaurante que ya existe
  // (decisión 5): null | { cargando, recogidas, reservas, error }.
  const [avisoZona, setAvisoZona] = useState(null)
  const [modulosCatalogo, setModulosCatalogo] = useState([])
  const [modulosActivos, setModulosActivos] = useState(new Set())
  const [editTab, setEditTab] = useState('datos') // 'datos' | 'facturacion' | 'modulos'
  const [planes, setPlanes] = useState([])
  const [aplicandoPlan, setAplicandoPlan] = useState(null) // key del plan que se está aplicando, o null
  const [trialInfo, setTrialInfo] = useState({ plan: null, precio_contrato: null, trial_termina_en: null, precio_override: null, precio_override_hasta: null, permanencia_hasta: null })
  const [permanenciaEdit, setPermanenciaEdit] = useState('')
  const [precioContratoEdit, setPrecioContratoEdit] = useState('')
  const [aceptaciones, setAceptaciones] = useState({}) // restaurant_id → aceptación de la versión vigente
  // Desactivar: elegir entre suspender (temporal) o dar de baja (se va).
  const [bajaModal, setBajaModal] = useState(null) // null | { rest, paso: 'elegir' | 'baja', calc, motivo, detalle, cobrar, guardando }
  const [descuentoPrecio, setDescuentoPrecio] = useState('')
  const [descuentoDias, setDescuentoDias] = useState('30')
  const [guardandoTrial, setGuardandoTrial] = useState(false)
  // Alta lanzada desde el CRM ("Convertir en restaurante"): ?cuenta=<id>
  const [searchParams, setSearchParams] = useSearchParams()
  const cuentaParam = searchParams.get('cuenta')
  const [cuentaOrigen, setCuentaOrigen] = useState(null)

  useEffect(() => { checkAuth() }, [])
  useEffect(() => { loadModulosCatalogo(); loadPlanes() }, [])
  useEffect(() => {
    if (cuentaParam && !cuentaOrigen && !loading && modulosCatalogo.length && planes.length) abrirDesdeCuenta(cuentaParam)
  }, [cuentaParam, loading, modulosCatalogo, planes])

  async function abrirDesdeCuenta(cuentaId) {
    const { data: cuenta, error: err } = await supabase.from('crm_cuentas').select('*').eq('id', cuentaId).maybeSingle()
    if (err || !cuenta) { setError(err?.message || 'No se encontró la cuenta del CRM.'); setSearchParams({}); return }
    if (cuenta.restaurant_id) { setError(`"${cuenta.nombre}" ya está vinculada a un restaurante.`); setSearchParams({}); return }
    setSearchParams({}, { replace: true })
    openCreateModal()
    setCuentaOrigen(cuenta)
    setForm(prev => ({
      ...prev,
      nombre: cuenta.nombre || '',
      email: cuenta.email || '',
      whatsapp: cuenta.telefono || '',
      direccion: [cuenta.direccion, cuenta.ciudad].filter(Boolean).join(', '),
      ...(PAISES.some(p => p.code === cuenta.pais) ? { pais: cuenta.pais, moneda: PAISES.find(p => p.code === cuenta.pais).moneda } : {}),
    }))
    setForm(prev => ({ ...prev, zonaHoraria: zonaPropuesta(prev.pais, prev.direccion), zonaTocada: false }))
    // Módulos del plan que le interesa (los planes son acumulativos).
    const plan = planes.find(p => p.key === cuenta.plan_interes)
    if (plan) {
      const ordenPorPlan = Object.fromEntries(planes.map(p => [p.key, p.orden]))
      setModulosActivos(new Set(['nucleo', ...modulosCatalogo.filter(m => ordenPorPlan[m.plan] <= plan.orden).map(m => m.key)]))
    }
  }

  async function loadModulosCatalogo() {
    const { data } = await supabase.from('modulos').select('key, nombre, descripcion, requiere, plan').order('orden')
    setModulosCatalogo(data || [])
  }

  async function loadPlanes() {
    const { data } = await supabase.from('planes').select('key, nombre, descripcion, orden, precio').order('orden')
    setPlanes(data || [])
  }

  async function aplicarPlan(planKey) {
    if (!editingId) return
    setAplicandoPlan(planKey)
    const { error: err } = await supabase.rpc('fn_asignar_plan', {
      p_restaurant_id: editingId, p_plan_key: planKey,
    })
    if (err) { setError(err.message); setAplicandoPlan(null); return }
    const { data: modActivos } = await supabase
      .from('restaurant_modulos')
      .select('modulo_key')
      .eq('restaurant_id', editingId)
      .eq('activo', true)
    setModulosActivos(new Set((modActivos || []).map(m => m.modulo_key)))
    // fn_asignar_plan fija el precio de contrato si el plan ha cambiado.
    const { data: rest } = await supabase.from('restaurants').select('plan, precio_contrato').eq('id', editingId).maybeSingle()
    if (rest) {
      setTrialInfo(prev => ({ ...prev, plan: rest.plan, precio_contrato: rest.precio_contrato ?? null }))
      setPrecioContratoEdit(rest.precio_contrato != null ? String(rest.precio_contrato) : '')
    }
    setAplicandoPlan(null)
    await loadRestaurants()
  }

  async function iniciarTrial() {
    if (!editingId) return
    setGuardandoTrial(true)
    const { error: err } = await supabase.rpc('fn_iniciar_trial', { p_restaurant_id: editingId, p_dias: 14 })
    setGuardandoTrial(false)
    if (err) { setError(err.message); return }
    // Igual que fn_iniciar_trial: hoy (España) + 14 días.
    setTrialInfo(prev => ({ ...prev, trial_termina_en: sumarDiasISO(hoyMadrid(), 14) }))
    await loadRestaurants()
  }

  async function limpiarTrial() {
    if (!editingId) return
    setGuardandoTrial(true)
    const { error: err } = await supabase.rpc('fn_limpiar_trial', { p_restaurant_id: editingId })
    setGuardandoTrial(false)
    if (err) { setError(err.message); return }
    setTrialInfo(prev => ({ ...prev, trial_termina_en: null }))
    await loadRestaurants()
  }

  async function aplicarDescuento() {
    if (!editingId) return
    const precio = parseFloat(descuentoPrecio)
    const dias = parseInt(descuentoDias, 10)
    if (isNaN(precio) || precio < 0) { setError('Indica un precio válido para el descuento.'); return }
    if (isNaN(dias) || dias <= 0) { setError('Indica cuántos días dura el descuento.'); return }
    setGuardandoTrial(true)
    const { error: err } = await supabase.rpc('fn_aplicar_descuento', {
      p_restaurant_id: editingId, p_precio: precio, p_dias: dias,
    })
    setGuardandoTrial(false)
    if (err) { setError(err.message); return }
    // Igual que fn_aplicar_descuento: hoy (España) + días.
    setTrialInfo(prev => ({ ...prev, precio_override: precio, precio_override_hasta: sumarDiasISO(hoyMadrid(), dias) }))
    setDescuentoPrecio('')
    await loadRestaurants()
  }

  async function limpiarDescuento() {
    if (!editingId) return
    setGuardandoTrial(true)
    const { error: err } = await supabase.rpc('fn_limpiar_descuento', { p_restaurant_id: editingId })
    setGuardandoTrial(false)
    if (err) { setError(err.message); return }
    setTrialInfo(prev => ({ ...prev, precio_override: null, precio_override_hasta: null }))
    await loadRestaurants()
  }

  async function guardarPermanencia() {
    if (!editingId) return
    setGuardandoTrial(true)
    const { data: filas, error: err } = await supabase.from('restaurants')
      .update({ permanencia_hasta: permanenciaEdit || null }).eq('id', editingId).select('id')
    setGuardandoTrial(false)
    if (err) { setError(err.message); return }
    if (!filas?.length) { setError('No se ha guardado: tu sesión de superadmin ya no está activa en este navegador.'); return }
    setTrialInfo(prev => ({ ...prev, permanencia_hasta: permanenciaEdit || null }))
    await loadRestaurants()
  }

  // p_precio null = pasarlo a la tarifa actual de su plan.
  async function guardarPrecioContrato(aTarifa) {
    if (!editingId) return
    let precio = null
    if (!aTarifa) {
      precio = parseFloat(String(precioContratoEdit).replace(',', '.'))
      if (isNaN(precio) || precio < 0) { setError('Indica un precio de contrato válido.'); return }
    }
    setGuardandoTrial(true)
    const { data: nuevo, error: err } = await supabase.rpc('fn_actualizar_precio_contrato', {
      p_restaurant_id: editingId, p_precio: precio,
    })
    setGuardandoTrial(false)
    if (err) { setError(err.message); return }
    setTrialInfo(prev => ({ ...prev, precio_contrato: nuevo }))
    setPrecioContratoEdit(nuevo != null ? String(nuevo) : '')
    await loadRestaurants()
  }

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/superadmin/login'); return }
    const { data: sa } = await supabase.from('superadmins').select('id').eq('user_id', session.user.id).single()
    if (!sa) { navigate('/superadmin/login'); return }
    loadRestaurants()
  }

  async function loadRestaurants() {
    const { data, error: err } = await supabase
      .from('restaurants')
      .select('id, nombre, slug, whatsapp, whatsapp_phone_number_id, activo, created_at, user_id, pais, moneda, direccion, zona_horaria, email_dueno, plan, precio_contrato, trial_termina_en, precio_override, precio_override_hasta, permanencia_hasta, baja_en, baja_motivo, baja_penalizacion')
      .order('created_at', { ascending: false })
    if (err) { setError(err.message); setLoading(false); return }
    setRestaurants(data || [])
    setLoading(false)
    // Quién aceptó las condiciones vigentes. Si la tabla aún no existe
    // (SQL pendiente), simplemente no se muestra.
    const { data: acep } = await supabase.from('condiciones_aceptaciones')
      .select('restaurant_id, aceptado_en, ip').eq('version', CONDICIONES_VERSION)
    setAceptaciones(Object.fromEntries((acep || []).map(a => [a.restaurant_id, a])))
  }

  function openCreateModal() {
    setForm({
      nombre: '', email: '', password: '', whatsapp: '', whatsappPhoneId: '',
      pais: 'ES', moneda: 'EUR', direccion: '',
      zonaHoraria: zonaPropuesta('ES', ''), zonaHorariaGuardada: null, zonaTocada: false,
      iban: '', titularCuenta: '',
    })
    setModulosActivos(new Set(['nucleo']))
    setIbanTouched(false)
    setError(null)
    setSuccess(null)
    setEditingId(null)
    setEditTab('datos')
    setCuentaOrigen(null)
    setModalMode('create')
  }

  async function openEditModal(rest) {
    setError(null)
    setSuccess(null)
    setIbanTouched(false)
    const { data: billing } = await supabase
      .from('restaurant_billing')
      .select('iban, titular_cuenta')
      .eq('restaurant_id', rest.id)
      .maybeSingle()
    const { data: modActivos } = await supabase
      .from('restaurant_modulos')
      .select('modulo_key')
      .eq('restaurant_id', rest.id)
      .eq('activo', true)
    setModulosActivos(new Set((modActivos || []).map(m => m.modulo_key)))
    setTrialInfo({
      plan: rest.plan || null,
      precio_contrato: rest.precio_contrato ?? null,
      trial_termina_en: rest.trial_termina_en || null,
      precio_override: rest.precio_override ?? null,
      precio_override_hasta: rest.precio_override_hasta || null,
      permanencia_hasta: rest.permanencia_hasta || null,
    })
    setPermanenciaEdit(rest.permanencia_hasta || '')
    setPrecioContratoEdit(rest.precio_contrato != null ? String(rest.precio_contrato) : '')
    setDescuentoPrecio('')
    setDescuentoDias('30')
    setEditTab('datos')
    setForm({
      nombre: rest.nombre || '',
      email: rest.email_dueno || '', password: '',
      whatsapp: rest.whatsapp || '',
      whatsappPhoneId: rest.whatsapp_phone_number_id || '',
      pais: rest.pais || 'ES',
      moneda: rest.moneda || 'EUR',
      direccion: rest.direccion || '',
      zonaHoraria: rest.zona_horaria || ZONA_POR_DEFECTO,
      zonaHorariaGuardada: rest.zona_horaria || ZONA_POR_DEFECTO,
      zonaTocada: true,
      iban: billing?.iban || '',
      titularCuenta: billing?.titular_cuenta || '',
    })
    setEditingId(rest.id)
    setModalMode('edit')
  }

  // Al cambiar el país se rellena la zona propuesta de ese país (decisión 2).
  function handlePaisChange(code) {
    const pais = PAISES.find(p => p.code === code)
    setForm(prev => ({ ...prev, pais: code, moneda: pais?.moneda || prev.moneda, zonaHoraria: zonaPropuesta(code, prev.direccion), zonaTocada: false }))
  }

  // Al crear, mientras el superadmin no elija otra, la zona sigue a la
  // dirección (Canarias por isla o código postal, decisión 3). Al editar,
  // cambiar la dirección no cambia la zona: sale el aviso (decisión 8).
  function handleDireccionChange(direccion) {
    setForm(prev => ({
      ...prev,
      direccion,
      ...(modalMode === 'create' && !prev.zonaTocada ? { zonaHoraria: zonaPropuesta(prev.pais, direccion) } : {}),
    }))
  }

  // Recogidas pendientes y reservas futuras del restaurante (decisión 5).
  // Las reservas futuras se cuentan con la hora de la zona guardada.
  async function contarEnMarcha(restaurantId, zonaGuardada) {
    const [ped, res] = await Promise.all([
      supabase.from('orders').select('id', { count: 'exact', head: true })
        .eq('restaurant_id', restaurantId).eq('tipo', 'takeaway').in('estado', ['pendiente', 'preparando', 'listo']),
      supabase.from('reservations').select('fecha, hora, estado')
        .eq('restaurant_id', restaurantId).in('estado', ['confirmada', 'pendiente']).gte('fecha', hoyEnZona(zonaGuardada)),
    ])
    if (ped.error || res.error) throw ped.error || res.error
    return { recogidas: ped.count || 0, reservas: contarReservasFuturas(res.data || [], zonaGuardada) }
  }

  // Guardar cambios: si la zona horaria cambia, antes el aviso con lo que
  // está en marcha; si no, se guarda directamente.
  async function guardarCambios() {
    if (form.zonaHorariaGuardada && form.zonaHoraria !== form.zonaHorariaGuardada) {
      setAvisoZona({ cargando: true })
      try {
        const cifras = await contarEnMarcha(editingId, form.zonaHorariaGuardada)
        setAvisoZona({ cargando: false, ...cifras })
      } catch {
        setAvisoZona({ cargando: false, error: true })
      }
      return
    }
    updateRestaurant()
  }

  function toggleModulo(key) {
    setModulosActivos(prev => {
      const next = new Set(prev)
      if (next.has(key)) {
        // Al apagar un módulo, apagar en cascada todo lo que dependa de
        // él — no puede quedar activo "Take away" sin "Agente WhatsApp",
        // por ejemplo.
        let cambio = true
        next.delete(key)
        while (cambio) {
          cambio = false
          for (const m of modulosCatalogo) {
            if (next.has(m.key) && m.requiere && !next.has(m.requiere)) {
              next.delete(m.key)
              cambio = true
            }
          }
        }
      } else {
        // Al prender un módulo, prender también, en cadena, todo lo que
        // necesita (ej. activar "Take away" prende "Agente WhatsApp" y,
        // si hiciera falta, lo que ese a su vez requiera).
        let actual = modulosCatalogo.find(m => m.key === key)
        const aActivar = [key]
        while (actual?.requiere) {
          aActivar.push(actual.requiere)
          actual = modulosCatalogo.find(m => m.key === actual.requiere)
        }
        aActivar.forEach(k => next.add(k))
      }
      return next
    })
  }

  async function createRestaurant() {
    if (!form.nombre.trim() || !form.email.trim() || !form.password.trim()) {
      setError('Nombre, email y contraseña son obligatorios.')
      return
    }
    if (!phoneIdValido(form.whatsappPhoneId)) {
      setError('El Phone number ID de WhatsApp solo lleva números (lo copias de Meta, no es el teléfono).')
      return
    }
    if (form.password.length < 8) {
      setError('La contraseña debe tener al menos 8 caracteres.')
      return
    }
    if (form.iban.trim() && !isValidIban(form.iban)) {
      setError('El IBAN no parece válido. Revísalo (o déjalo vacío y lo añades más adelante).')
      return
    }
    if (!zonaValida(form.zonaHoraria)) {
      setError('Elige la zona horaria del restaurante.')
      return
    }
    setCreating(true)
    setError(null)

    try {
      // Antes del signUp: si el insert fallara después por el índice único,
      // quedaría creado un usuario sin restaurante.
      if (form.whatsappPhoneId.trim()) {
        const { data: ocupado } = await supabase.from('restaurants').select('nombre')
          .eq('whatsapp_phone_number_id', form.whatsappPhoneId.trim()).maybeSingle()
        if (ocupado) throw new Error(`Ese Phone number ID de WhatsApp ya está asignado a "${ocupado.nombre}".`)
      }

      // Cliente Supabase separado para no afectar la sesión del superadmin
      // persistSession/autoRefreshToken en false: sin esto, el signUp()
      // de más abajo pisa en localStorage la sesión del superadmin (los
      // dos clientes comparten la misma clave de storage por defecto),
      // y el insert en "restaurants" que sigue se ejecuta como el
      // dueño recién creado en vez de como superadmin — rompe la RLS.
      const tempClient = createClient(supabaseUrl, supabaseAnonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      })

      const { data: signUpData, error: signUpErr } = await tempClient.auth.signUp({
        email: form.email.trim(),
        password: form.password,
      })
      if (signUpErr) throw signUpErr
      if (!signUpData.user) throw new Error('No se pudo crear el usuario.')

      const newUserId = signUpData.user.id
      const slug = slugify(form.nombre)

      // Crear restaurante vinculado
      const { data: restData, error: restErr } = await supabase
        .from('restaurants')
        .insert({
          nombre: form.nombre.trim(),
          slug,
          whatsapp: form.whatsapp.trim() || null,
          whatsapp_phone_number_id: form.whatsappPhoneId.trim() || null,
          direccion: form.direccion.trim() || null,
          pais: form.pais,
          moneda: form.moneda,
          zona_horaria: form.zonaHoraria,
          email_dueno: form.email.trim(),
          user_id: newUserId,
          activo: true,
        })
        .select().single()
      if (restErr) throw errorPhoneId(restErr)

      // Categoría demo
      const { data: catData, error: catErr } = await supabase
        .from('categories')
        .insert({ restaurant_id: restData.id, nombre: 'Entrantes', orden: 1, activa: true })
        .select().single()
      if (catErr) throw catErr

      // Plato demo
      await supabase.from('menu_items').insert({
        restaurant_id: restData.id,
        category_id: catData.id,
        nombre: 'Plato de bienvenida',
        descripcion: 'Edita o elimina este plato desde Gestión de carta',
        precio: 0,
        emoji: '🍽',
        disponible: true,
        orden: 1,
      })

      // Mesa demo
      await supabase.from('tables').insert({
        restaurant_id: restData.id,
        numero: 1,
        zona: 'interior',
        capacidad: 4,
        activa: true,
      })

      // Datos bancarios (opcional). Va en tabla separada, con RLS
      // restringida a superadmins — nunca se expone en el panel del
      // propio restaurante ni en ninguna pantalla de cliente.
      if (form.iban.trim()) {
        const { error: billErr } = await supabase.from('restaurant_billing').insert({
          restaurant_id: restData.id,
          iban: form.iban.replace(/\s+/g, '').toUpperCase(),
          titular_cuenta: form.titularCuenta.trim() || null,
        })
        if (billErr) throw billErr
      }

      // Viene del CRM con un plan elegido: deja la etiqueta del plan
      // puesta. Va antes del upsert de módulos para que, si se tocaron
      // los toggles a mano, mande lo elegido en la pestaña "Módulos".
      if (cuentaOrigen?.plan_interes) {
        const { error: planErr } = await supabase.rpc('fn_asignar_plan', {
          p_restaurant_id: restData.id, p_plan_key: cuentaOrigen.plan_interes,
        })
        if (planErr) throw planErr
      }

      // Módulos elegidos en la pestaña "Módulos" del alta. El trigger
      // trg_activar_modulo_nucleo ya insertó 'nucleo' — este upsert es
      // idempotente, así que no genera conflicto con eso.
      const filasModulos = modulosCatalogo.map(m => ({
        restaurant_id: restData.id,
        modulo_key: m.key,
        activo: modulosActivos.has(m.key),
      }))
      if (filasModulos.length) {
        const { error: modErr } = await supabase
          .from('restaurant_modulos')
          .upsert(filasModulos, { onConflict: 'restaurant_id,modulo_key' })
        if (modErr) throw modErr
      }

      // Cerrar el círculo en el CRM: la cuenta pasa a ser cliente.
      let avisoCrm = ''
      if (cuentaOrigen) {
        const { error: crmErr } = await supabase
          .from('crm_cuentas')
          .update({ restaurant_id: restData.id, etapa: 'ganado' })
          .eq('id', cuentaOrigen.id)
        avisoCrm = crmErr
          ? `\n\nAtención: no se pudo vincular con la cuenta del CRM (${crmErr.message}). Vincúlala a mano desde la ficha.`
          : '\n\nCuenta del CRM vinculada: ya cuenta como cliente y empieza a generar comisión el mes que viene.'
        setCuentaOrigen(null)
      }

      const avisoPermanencia = restData.permanencia_hasta ? `\nPermanencia hasta el ${fmtFechaES(restData.permanencia_hasta)} (al entrar al panel, el dueño tendrá que aceptar las condiciones).` : ''
      setSuccess(`Restaurante "${form.nombre}" creado correctamente.\n\nAcceso del cliente: ${form.email} / (la contraseña que definiste)\nPanel: /admin/login${avisoPermanencia}${avisoCrm}`)
      setModalMode(null)
      loadRestaurants()
    } catch (e) {
      setError(e.message)
    } finally {
      setCreating(false)
    }
  }

  async function updateRestaurant() {
    // La ventana del aviso de zona se cierra siempre: si falla una
    // validación, el error se ve en el formulario.
    setAvisoZona(null)
    if (!form.nombre.trim()) {
      setError('El nombre es obligatorio.')
      return
    }
    if (!phoneIdValido(form.whatsappPhoneId)) {
      setError('El Phone number ID de WhatsApp solo lleva números (lo copias de Meta, no es el teléfono).')
      return
    }
    if (form.iban.trim() && !isValidIban(form.iban)) {
      setError('El IBAN no parece válido. Revísalo (o déjalo vacío).')
      return
    }
    if (!zonaValida(form.zonaHoraria)) {
      setError('Elige la zona horaria del restaurante.')
      return
    }
    setCreating(true)
    setError(null)
    try {
      const { error: restErr } = await supabase
        .from('restaurants')
        .update({
          nombre: form.nombre.trim(),
          whatsapp: form.whatsapp.trim() || null,
          whatsapp_phone_number_id: form.whatsappPhoneId.trim() || null,
          direccion: form.direccion.trim() || null,
          pais: form.pais,
          moneda: form.moneda,
          email_dueno: form.email.trim() || null,
          // Solo si cambia (la BD la valida y solo la deja cambiar al superadmin).
          ...(form.zonaHoraria !== form.zonaHorariaGuardada ? { zona_horaria: form.zonaHoraria } : {}),
        })
        .eq('id', editingId)
      if (restErr) throw errorPhoneId(restErr)
      // Estado local al momento (regla 9), sin esperar a la recarga.
      setRestaurants(prev => prev.map(r => (r.id === editingId ? { ...r, zona_horaria: form.zonaHoraria } : r)))

      // upsert: si ya había datos bancarios los actualiza, si no, los crea.
      // Si se vació el campo, en vez de dejar un IBAN viejo guardado, se borra.
      if (form.iban.trim()) {
        const { error: billErr } = await supabase
          .from('restaurant_billing')
          .upsert({
            restaurant_id: editingId,
            iban: form.iban.replace(/\s+/g, '').toUpperCase(),
            titular_cuenta: form.titularCuenta.trim() || null,
            updated_at: new Date().toISOString(),
          }, { onConflict: 'restaurant_id' })
        if (billErr) throw billErr
      } else {
        await supabase.from('restaurant_billing').delete().eq('restaurant_id', editingId)
      }

      const filasModulos = modulosCatalogo.map(m => ({
        restaurant_id: editingId,
        modulo_key: m.key,
        activo: modulosActivos.has(m.key),
      }))
      if (filasModulos.length) {
        const { error: modErr } = await supabase
          .from('restaurant_modulos')
          .upsert(filasModulos, { onConflict: 'restaurant_id,modulo_key' })
        if (modErr) throw modErr
      }

      setSuccess(`Restaurante "${form.nombre}" actualizado correctamente.`)
      setModalMode(null)
      loadRestaurants()
    } catch (e) {
      setError(e.message)
    } finally {
      setCreating(false)
    }
  }

  // Activo → abre el diálogo para elegir entre suspender o dar de baja.
  // Inactivo → reactivar (borra los datos de la baja, si la hubo).
  async function toggleActivo(rest) {
    if (rest.activo) {
      setBajaModal({ rest, paso: 'elegir', calc: null, motivo: '', detalle: '', cobrar: true, guardando: false })
      return
    }
    const aviso = `¿Reactivar "${rest.nombre}"? El dueño, su personal y sus clientes vuelven a tener acceso.`
      + (rest.baja_en ? '\n\nSe borrarán los datos de la baja. Las comisiones retiradas al vendedor no se restauran solas: revísalas en CRM → Comisiones.' : '')
    if (!window.confirm(aviso)) return
    await cambiarActivo(rest, true, { baja_en: null, baja_motivo: null, baja_penalizacion: null })
  }

  async function cambiarActivo(rest, nuevo, extra = {}) {
    // .select() para saber si de verdad se cambió alguna fila: si la sesión
    // ya no es la del superadmin (hay una sola por navegador y el login de
    // un dueño la sustituye), RLS descarta el update sin dar error.
    const { data: filas, error: err } = await supabase.from('restaurants').update({ activo: nuevo, ...extra }).eq('id', rest.id).select('id')
    if (err) { setError(err.message); return false }
    if (!filas?.length) {
      setError('No se ha guardado el cambio: tu sesión de superadmin ya no está activa en este navegador. Vuelve a iniciar sesión como superadmin.')
      return false
    }
    setRestaurants(prev => prev.map(r => r.id === rest.id ? { ...r, activo: nuevo, ...extra } : r))
    return true
  }

  async function suspender() {
    if (await cambiarActivo(bajaModal.rest, false)) setBajaModal(null)
  }

  async function prepararBaja() {
    setBajaModal(m => ({ ...m, guardando: true }))
    const { data, error: err } = await supabase.rpc('fn_permanencia_penalizacion', { p_restaurant_id: bajaModal.rest.id })
    if (err) { setError(err.message); setBajaModal(null); return }
    setBajaModal(m => ({ ...m, paso: 'baja', calc: data?.[0] || null, guardando: false }))
  }

  async function confirmarBaja() {
    const { rest, motivo, detalle, cobrar } = bajaModal
    if (!motivo) return
    setBajaModal(m => ({ ...m, guardando: true }))
    const { data, error: err } = await supabase.rpc('fn_dar_baja_restaurante', {
      p_restaurant_id: rest.id,
      p_motivo: [motivo, detalle.trim()].filter(Boolean).join(': '),
      p_cobrar_penalizacion: cobrar,
    })
    if (err) { setError(err.message); setBajaModal(m => ({ ...m, guardando: false })); return }
    const r = data?.[0] || {}
    const partes = [`"${rest.nombre}" dado de baja.`]
    if (Number(r.penalizacion) > 0) partes.push(`Penalización a facturar: ${fmtEur(r.penalizacion)}.`)
    if (r.comisiones_anuladas) partes.push(`${r.comisiones_anuladas} comisiones pendientes anuladas.`)
    if (r.comisiones_a_descontar) partes.push(`${r.comisiones_a_descontar} comisiones ya pagadas quedan "a descontar" del vendedor.`)
    setSuccess(partes.join(' '))
    setBajaModal(null)
    loadRestaurants()
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/superadmin/login')
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.header}>
        <div>
          <div style={S.logo}><img src="/logos/opcion-2-monograma/icon-dark.svg" alt="" style={{ height: 22, verticalAlign: 'middle', marginRight: 8 }} />Restomind</div>
          <div style={S.sub}>Super Admin</div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <a href="/superadmin/crm" style={S.linkBtn}>CRM</a>
          <a href="/superadmin/planes" style={S.linkBtn}>Planes</a>
          <a href="/superadmin/agente-whatsapp" style={S.linkBtn}>Agente WhatsApp</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Restaurantes ({restaurants.length})</div>
        {error && <div style={S.error}>{error}</div>}
        {success && <div style={S.success}>{success}</div>}

        <button style={S.addBtn} onClick={openCreateModal}>+ Nuevo restaurante</button>

        <table style={S.table}>
          <thead>
            <tr>
              <th style={S.th}>Restaurante</th>
              <th style={S.th}>País / Moneda</th>
              <th style={S.th}>WhatsApp</th>
              <th style={S.th}>Plan</th>
              <th style={S.th}>Estado</th>
              <th style={S.th}>Accesos</th>
            </tr>
          </thead>
          <tbody>
            {restaurants.map(rest => (
              <tr key={rest.id}>
                <td style={S.td}>
                  <div style={S.restName}>{rest.nombre}</div>
                  <div style={S.restSlug}>{rest.slug} · {rest.id.slice(0, 8)}...</div>
                </td>
                <td style={S.td}>{PAISES.find(p => p.code === rest.pais)?.label || rest.pais || '—'} · {rest.moneda || '—'}</td>
                <td style={S.td}>{rest.whatsapp || '—'}</td>
                <td style={S.td}>
                  <div style={{ fontSize: 13, color: '#f0f0f0', textTransform: 'capitalize' }}>{rest.plan || '—'}</div>
                  {rest.precio_contrato != null && (() => {
                    const tarifa = planes.find(p => p.key === rest.plan)?.precio
                    const distinta = tarifa != null && Number(tarifa) !== Number(rest.precio_contrato)
                    return (
                      <div style={{ fontSize: 11, color: '#8a8a8a', marginTop: 2 }}>
                        {fmtEur(rest.precio_contrato)}/mes{distinta ? ` · tarifa actual ${fmtEur(tarifa)}` : ''}
                      </div>
                    )
                  })()}
                  {rest.trial_termina_en && (
                    <div style={{ fontSize: 11, color: new Date(rest.trial_termina_en) < new Date() ? '#e74c3c' : '#e8c97a', marginTop: 2 }}>
                      Trial hasta {new Date(rest.trial_termina_en + 'T00:00:00').toLocaleDateString('es-ES')}
                    </div>
                  )}
                  {rest.precio_override_hasta && (
                    <div style={{ fontSize: 11, color: new Date(rest.precio_override_hasta) < new Date() ? '#e74c3c' : '#7ae8a0', marginTop: 2 }}>
                      {rest.precio_override}€ hasta {new Date(rest.precio_override_hasta + 'T00:00:00').toLocaleDateString('es-ES')}
                    </div>
                  )}
                  {rest.permanencia_hasta && !rest.baja_en && (
                    <div style={{ fontSize: 11, color: rest.permanencia_hasta >= hoyISO() ? '#9aa7e8' : '#555', marginTop: 2 }}>
                      {rest.permanencia_hasta >= hoyISO() ? 'Permanencia hasta' : 'Permanencia cumplida'} {fmtFechaES(rest.permanencia_hasta)}
                    </div>
                  )}
                  {rest.permanencia_hasta && (aceptaciones[rest.id] ? (
                    <div style={{ fontSize: 11, color: '#2ecc71', marginTop: 2 }} title={`Versión ${CONDICIONES_VERSION}${aceptaciones[rest.id].ip ? ` · IP ${aceptaciones[rest.id].ip}` : ''}`}>
                      Condiciones aceptadas {new Date(aceptaciones[rest.id].aceptado_en).toLocaleString('es-ES', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                    </div>
                  ) : (
                    <div style={{ fontSize: 11, color: '#e8a33a', marginTop: 2 }}>Condiciones sin aceptar</div>
                  ))}
                  {rest.baja_en && (
                    <div style={{ fontSize: 11, color: '#e74c3c', marginTop: 2 }} title={rest.baja_motivo || ''}>
                      Baja {fmtFechaES(rest.baja_en)}{Number(rest.baja_penalizacion) > 0 ? ` · penalización ${fmtEur(rest.baja_penalizacion)}` : ''}
                    </div>
                  )}
                </td>
                <td style={S.td}>
                  <span style={S.badge(rest.activo)} onClick={() => toggleActivo(rest)} role="button" title="Click para cambiar">
                    {rest.activo ? 'Activo' : rest.baja_en ? 'Baja' : 'Inactivo'}
                  </span>
                </td>
                <td style={S.td}>
                  <a href={`/admin/mesas/${rest.id}`} style={S.linkBtn} target="_blank" rel="noreferrer">Mesas</a>
                  <a href={`/admin/carta/${rest.id}`} style={S.linkBtn} target="_blank" rel="noreferrer">Carta</a>
                  <a href={`/cocina/${rest.id}`} style={S.linkBtn} target="_blank" rel="noreferrer">Cocina</a>
                  <button style={{ ...S.linkBtn, cursor: 'pointer' }} onClick={() => openEditModal(rest)}>Editar</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {restaurants.length === 0 && (
          <div style={{ fontSize: 14, color: '#555', textAlign: 'center', padding: '60px 0' }}>
            Aún no hay restaurantes. Crea el primero arriba.
          </div>
        )}
      </div>

      {modalMode && (
        <div style={S.modal} onClick={e => { if (e.target === e.currentTarget) setModalMode(null) }}>
          <div style={S.modalBox}>
            <div style={S.modalTitle}>{modalMode === 'create' ? 'Nuevo restaurante' : 'Editar restaurante'}</div>
            {modalMode === 'create' && cuentaOrigen && (
              <div style={{ ...S.hint, color: '#e8c97a', marginTop: -10, marginBottom: 6 }}>
                Alta desde el CRM{cuentaOrigen.plan_interes ? ` · plan ${cuentaOrigen.plan_interes} preseleccionado en Módulos` : ''}. Al crearlo, la cuenta queda vinculada como cliente.
              </div>
            )}

            <label style={S.label}>Nombre del restaurante *</label>
            <input style={S.input} value={form.nombre} onChange={e => setForm(prev => ({ ...prev, nombre: e.target.value }))} placeholder="Ej. La Taberna del Puerto" />
            {modalMode === 'create' && form.nombre && <div style={S.hint}>slug: {slugify(form.nombre)}</div>}

            <div style={S.tabBar}>
              <button style={S.tabBtn(editTab === 'datos')} onClick={() => setEditTab('datos')}>Datos</button>
              <button style={S.tabBtn(editTab === 'facturacion')} onClick={() => setEditTab('facturacion')}>Facturación</button>
              <button style={S.tabBtn(editTab === 'modulos')} onClick={() => setEditTab('modulos')}>Módulos</button>
            </div>

            {editTab === 'datos' && (
              <>
                {modalMode === 'create' ? (
                  <>
                    <label style={S.label}>Email del dueño (acceso al panel) *</label>
                    <input style={S.input} type="email" value={form.email} onChange={e => setForm(prev => ({ ...prev, email: e.target.value }))} placeholder="dueno@restaurante.com" />

                    <label style={S.label}>Contraseña inicial *</label>
                    <input style={S.input} type="text" value={form.password} onChange={e => setForm(prev => ({ ...prev, password: e.target.value }))} placeholder="mínimo 8 caracteres, con letras y números" />
                    <div style={S.hint}>Compártesela al cliente; podrá usarla en /admin/login</div>
                  </>
                ) : (
                  <>
                    <label style={S.label}>Email del dueño (acceso al panel)</label>
                    <input style={S.input} type="email" value={form.email} onChange={e => setForm(prev => ({ ...prev, email: e.target.value }))} placeholder="dueno@restaurante.com" />
                    <div style={S.hint}>Esto NO cambia el login real — es solo una copia de referencia. Para cambiar el acceso de verdad, hazlo desde Authentication → Users en Supabase, y después actualiza este campo para que coincida.</div>
                  </>
                )}

                <label style={S.label}>WhatsApp (opcional)</label>
                <input style={S.input} value={form.whatsapp} onChange={e => setForm(prev => ({ ...prev, whatsapp: e.target.value }))} placeholder="+34600000000" />

                <label style={S.label}>WhatsApp – Phone number ID (opcional)</label>
                <input style={S.input} inputMode="numeric" value={form.whatsappPhoneId} onChange={e => setForm(prev => ({ ...prev, whatsappPhoneId: e.target.value.trim() }))} placeholder="Ej. 1067078033150321" />
                <div style={S.hint}>Con esto el agente de WhatsApp sabe que los mensajes a ese número son de este restaurante. Se copia en Meta: WhatsApp Manager › Números de teléfono (o API Setup), campo "Phone number ID". No es el teléfono.</div>

                <div style={{ display: 'flex', gap: 12 }}>
                  <div style={{ flex: 1 }}>
                    <label style={S.label}>País</label>
                    <select style={S.input} value={form.pais} onChange={e => handlePaisChange(e.target.value)}>
                      {PAISES.map(p => <option key={p.code} value={p.code}>{p.label}</option>)}
                    </select>
                  </div>
                  <div style={{ flex: 1 }}>
                    <label style={S.label}>Moneda</label>
                    <select style={S.input} value={form.moneda} onChange={e => setForm(prev => ({ ...prev, moneda: e.target.value }))}>
                      {MONEDAS.map(m => <option key={m} value={m}>{m}</option>)}
                    </select>
                  </div>
                </div>
                <div style={S.hint}>La moneda se ajusta sola según el país, pero puedes cambiarla si el restaurante factura en otra.</div>

                <label style={S.label}>Dirección (opcional)</label>
                <input style={S.input} value={form.direccion} onChange={e => handleDireccionChange(e.target.value)} placeholder="Calle, número, ciudad" />

                <label style={S.label}>Zona horaria</label>
                <select
                  style={S.input}
                  value={form.zonaHoraria}
                  onChange={e => setForm(prev => ({ ...prev, zonaHoraria: e.target.value, zonaTocada: true }))}
                >
                  {opcionesZona(form.pais, form.zonaHoraria, form.zonaHorariaGuardada).map(o => (
                    <option key={o.zona} value={o.zona}>{o.nombre} — ahora {horaActualEnZona(o.zona)}</option>
                  ))}
                </select>
                {modalMode === 'create' && form.pais === 'ES' && pareceCanarias(form.direccion) && form.zonaHoraria === 'Atlantic/Canary' && (
                  <div style={{ ...S.hint, color: '#e8c97a' }}>Propuesta por la dirección: Canarias</div>
                )}
                {modalMode === 'edit' && avisoDireccion(form.pais, form.direccion, form.zonaHoraria) && (
                  <div style={{ ...S.hint, color: '#e8c97a' }}>
                    Propuesta por la dirección: {nombreZona(zonaPropuesta(form.pais, form.direccion))}. {avisoDireccion(form.pais, form.direccion, form.zonaHoraria)}.{' '}
                    <button
                      type="button"
                      style={{ background: 'transparent', border: 'none', color: '#e8c97a', textDecoration: 'underline', cursor: 'pointer', padding: 0, fontSize: 11, fontFamily: "'Inter', sans-serif" }}
                      onClick={() => setForm(prev => ({ ...prev, zonaHoraria: zonaPropuesta(prev.pais, prev.direccion), zonaTocada: true }))}
                    >
                      Usar {nombreZona(zonaPropuesta(form.pais, form.direccion))}
                    </button>
                  </div>
                )}
                <div style={S.hint}>Las reservas, recogidas, menús por horario, vales y el cierre de caja usan esta hora. Solo la cambia Restomind; el dueño la ve en Configuración.</div>
              </>
            )}

            {editTab === 'facturacion' && (
              <>
                <label style={S.label}>IBAN — para cobrar la suscripción más adelante (opcional)</label>
                <input
                  style={S.input}
                  value={form.iban}
                  onChange={e => setForm(prev => ({ ...prev, iban: e.target.value }))}
                  onBlur={() => setIbanTouched(true)}
                  placeholder="ES91 2100 0418 4502 0005 1332"
                />
                {ibanTouched && form.iban.trim() && !isValidIban(form.iban) && (
                  <div style={{ ...S.hint, color: '#e87a7a' }}>Ese IBAN no parece válido — revísalo.</div>
                )}
                {form.iban.trim() && isValidIban(form.iban) && (
                  <div style={S.hint}>{formatIbanDisplay(form.iban)} ✓</div>
                )}
                <div style={S.hint}>
                  {modalMode === 'create'
                    ? 'Solo se guarda el dato — todavía no hay ningún cobro automático conectado.'
                    : 'Dejar este campo vacío y guardar borra el IBAN guardado para este restaurante.'}
                </div>

                <label style={S.label}>Titular de la cuenta (opcional)</label>
                <input style={S.input} value={form.titularCuenta} onChange={e => setForm(prev => ({ ...prev, titularCuenta: e.target.value }))} placeholder="Nombre tal como figura en el banco" />
              </>
            )}

            {editTab === 'modulos' && (
              <>
                {modalMode === 'edit' && (
                  <div style={{ marginBottom: 16, paddingBottom: 16, borderBottom: '0.5px solid #2a2a2a' }}>
                    <div style={{ fontSize: 13, fontWeight: 500, color: '#e8c97a', marginBottom: 8 }}>Trial, descuentos y permanencia</div>

                    {trialInfo.plan && (() => {
                      const tarifa = planes.find(p => p.key === trialInfo.plan)?.precio
                      const distinta = tarifa != null && Number(tarifa) !== Number(trialInfo.precio_contrato)
                      const sinCambios = precioContratoEdit === (trialInfo.precio_contrato != null ? String(trialInfo.precio_contrato) : '')
                      return (
                        <div style={{ marginBottom: 10 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                            <span style={{ fontSize: 12, color: '#8a8a8a' }}>Precio de contrato</span>
                            <input style={{ ...S.input, width: 100 }} type="number" min="0" step="0.01" placeholder="€/mes" value={precioContratoEdit} onChange={e => setPrecioContratoEdit(e.target.value)} />
                            <button style={{ ...S.linkBtn, cursor: 'pointer' }} disabled={guardandoTrial || sinCambios || precioContratoEdit === ''} onClick={() => guardarPrecioContrato(false)}>Guardar</button>
                            {distinta && (
                              <button style={{ ...S.linkBtn, cursor: 'pointer' }} disabled={guardandoTrial} onClick={() => guardarPrecioContrato(true)}>Pasar a tarifa actual ({fmtEur(tarifa)})</button>
                            )}
                          </div>
                          {distinta && (
                            <div style={{ fontSize: 11, color: '#e8c97a', marginTop: 4 }}>
                              {trialInfo.precio_contrato != null ? `Paga ${fmtEur(trialInfo.precio_contrato)}` : 'Sin precio de contrato'} · la tarifa actual del plan es {fmtEur(tarifa)}.
                            </div>
                          )}
                        </div>
                      )
                    })()}

                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10, flexWrap: 'wrap' }}>
                      {trialInfo.trial_termina_en ? (
                        <>
                          <span style={{ fontSize: 12, color: new Date(trialInfo.trial_termina_en) < new Date() ? '#e74c3c' : '#e8c97a' }}>
                            Trial hasta {new Date(trialInfo.trial_termina_en + 'T00:00:00').toLocaleDateString('es-ES')}
                          </span>
                          <button style={{ ...S.linkBtn, cursor: 'pointer' }} disabled={guardandoTrial} onClick={limpiarTrial}>Quitar trial</button>
                        </>
                      ) : (
                        <button style={{ ...S.linkBtn, cursor: 'pointer' }} disabled={guardandoTrial} onClick={iniciarTrial}>Iniciar trial de 14 días</button>
                      )}
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                      {trialInfo.precio_override_hasta ? (
                        <>
                          <span style={{ fontSize: 12, color: new Date(trialInfo.precio_override_hasta) < new Date() ? '#e74c3c' : '#7ae8a0' }}>
                            {trialInfo.precio_override}€ hasta {new Date(trialInfo.precio_override_hasta + 'T00:00:00').toLocaleDateString('es-ES')}
                          </span>
                          <button style={{ ...S.linkBtn, cursor: 'pointer' }} disabled={guardandoTrial} onClick={limpiarDescuento}>Quitar descuento</button>
                        </>
                      ) : (
                        <>
                          <input style={{ ...S.input, width: 90 }} type="number" min="0" step="0.01" placeholder="Precio €" value={descuentoPrecio} onChange={e => setDescuentoPrecio(e.target.value)} />
                          <input style={{ ...S.input, width: 70 }} type="number" min="1" placeholder="Días" value={descuentoDias} onChange={e => setDescuentoDias(e.target.value)} />
                          <button style={{ ...S.linkBtn, cursor: 'pointer' }} disabled={guardandoTrial} onClick={aplicarDescuento}>Aplicar descuento</button>
                        </>
                      )}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginTop: 10 }}>
                      <span style={{ fontSize: 12, color: '#8a8a8a' }}>Permanencia hasta</span>
                      <input style={{ ...S.input, width: 160 }} type="date" value={permanenciaEdit} onChange={e => setPermanenciaEdit(e.target.value)} />
                      <button style={{ ...S.linkBtn, cursor: 'pointer' }} disabled={guardandoTrial || permanenciaEdit === (trialInfo.permanencia_hasta || '')} onClick={guardarPermanencia}>Guardar</button>
                    </div>
                    <div style={S.hint}>Esto no cobra ni descuenta nada solo — es para que sepas qué precio y hasta cuándo le corresponde a este restaurante quien lo facture a mano. El precio de contrato se fija al aplicarle un plan y no cambia aunque cambie la tarifa del plan; el descuento, mientras dure, va por delante. La permanencia se pone sola al dar de alta (alta + 3 meses); vacía = sin permanencia.</div>
                  </div>
                )}
                {modalMode === 'edit' && planes.length > 0 && (
                  <div style={{ marginBottom: 16, paddingBottom: 16, borderBottom: '0.5px solid #2a2a2a' }}>
                    <div style={S.hint}>Aplicar un plan activa de golpe sus módulos y desactiva el resto — los toggles de abajo siguen disponibles para excepciones puntuales.</div>
                    <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                      {planes.map(p => (
                        <button
                          key={p.key}
                          style={{ ...S.linkBtn, cursor: aplicandoPlan ? 'not-allowed' : 'pointer', opacity: aplicandoPlan ? 0.6 : 1 }}
                          disabled={!!aplicandoPlan}
                          onClick={() => aplicarPlan(p.key)}
                        >
                          {aplicandoPlan === p.key ? 'Aplicando...' : `Aplicar ${p.nombre}`}
                        </button>
                      ))}
                    </div>
                  </div>
                )}
                {modulosCatalogo.map(m => {
                  const activo = modulosActivos.has(m.key)
                  const bloqueadoPorDependencia = m.key !== 'nucleo' && m.requiere && !modulosActivos.has(m.requiere) && !activo
                  return (
                    <div key={m.key} style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '10px 0', borderBottom: '0.5px solid #1f1f1f' }}>
                      <input
                        type="checkbox"
                        checked={activo}
                        disabled={m.key === 'nucleo'}
                        onChange={() => toggleModulo(m.key)}
                        style={{ marginTop: 3 }}
                      />
                      <div>
                        <div style={{ fontSize: 13, color: '#f0f0f0' }}>
                          {m.nombre}{m.key === 'nucleo' && <span style={{ color: '#555', fontSize: 11 }}> (siempre incluido)</span>}
                        </div>
                        <div style={{ fontSize: 11, color: '#666' }}>{m.descripcion}</div>
                        {bloqueadoPorDependencia && (
                          <div style={{ fontSize: 11, color: '#e8c97a' }}>Requiere: {modulosCatalogo.find(x => x.key === m.requiere)?.nombre}</div>
                        )}
                      </div>
                    </div>
                  )
                })}
                <div style={S.hint}>Activar un módulo prende automáticamente los que necesita. Desactivarlo apaga en cadena los que dependen de él.</div>
              </>
            )}

            <div style={S.modalBtns}>
              <button style={S.cancelBtn} onClick={() => setModalMode(null)}>Cancelar</button>
              <button
                style={S.saveBtn(creating)}
                onClick={modalMode === 'create' ? createRestaurant : guardarCambios}
                disabled={creating}
              >
                {creating ? 'Guardando...' : modalMode === 'create' ? 'Crear restaurante' : 'Guardar cambios'}
              </button>
            </div>
          </div>
        </div>
      )}

      {avisoZona && (
        <div style={{ ...S.modal, zIndex: 60 }}>
          <div style={S.modalBox}>
            <div style={S.modalTitle}>Cambiar la zona horaria</div>
            {avisoZona.cargando ? (
              <div style={{ fontSize: 13, color: '#8a8a8a' }}>Comprobando pedidos y reservas en marcha…</div>
            ) : (
              <div style={{ fontSize: 13, color: '#c8c8c8', lineHeight: 1.6 }}>
                Vas a cambiar la zona de <strong>{form.nombre}</strong> de {nombreZona(form.zonaHorariaGuardada)} a {nombreZona(form.zonaHoraria)}.{' '}
                {avisoZona.error
                  ? 'No he podido comprobar los pedidos y reservas en marcha.'
                  : `Tiene ${avisoZona.recogidas} ${avisoZona.recogidas === 1 ? 'recogida pendiente' : 'recogidas pendientes'} y ${avisoZona.reservas} ${avisoZona.reservas === 1 ? 'reserva futura' : 'reservas futuras'}.`}{' '}
                Las reservas mantienen su hora. Las recogidas pendientes pueden verse con una hora de diferencia. ¿Cambiar la zona?
              </div>
            )}
            <div style={S.modalBtns}>
              <button style={S.cancelBtn} onClick={() => setAvisoZona(null)}>Cancelar</button>
              <button style={S.saveBtn(avisoZona.cargando || creating)} disabled={avisoZona.cargando || creating} onClick={updateRestaurant}>Cambiar</button>
            </div>
          </div>
        </div>
      )}

      {bajaModal && (
        <div style={S.modal}>
          <div style={S.modalBox}>
            <div style={S.modalTitle}>Desactivar "{bajaModal.rest.nombre}"</div>

            {bajaModal.paso === 'elegir' && (
              <>
                <div style={{ fontSize: 13, color: '#8a8a8a', lineHeight: 1.6, marginBottom: 14 }}>
                  En los dos casos se bloquea todo: el dueño no podrá entrar al panel, el personal no podrá usar Cocina ni Camarero, y no se aceptarán pedidos ni reservas por ningún canal (QR, WhatsApp, web).
                </div>
                <button style={{ ...S.cancelBtn, width: '100%', textAlign: 'left', marginBottom: 10, color: '#f0f0f0' }} disabled={bajaModal.guardando} onClick={suspender}>
                  <strong>Suspender</strong>
                  <div style={{ fontSize: 12, color: '#8a8a8a', marginTop: 4 }}>Temporal, por ejemplo por impago. Sigue siendo cliente: no cuenta como baja ni toca la permanencia.</div>
                </button>
                <button style={{ ...S.cancelBtn, width: '100%', textAlign: 'left', color: '#f0f0f0' }} disabled={bajaModal.guardando} onClick={prepararBaja}>
                  <strong>Dar de baja</strong>
                  <div style={{ fontSize: 12, color: '#8a8a8a', marginTop: 4 }}>El cliente se va. Se registra la baja y, si está en permanencia, la penalización.</div>
                </button>
                <div style={S.modalBtns}>
                  <button style={S.cancelBtn} onClick={() => setBajaModal(null)}>Cancelar</button>
                </div>
              </>
            )}

            {bajaModal.paso === 'baja' && (() => {
              const c = bajaModal.calc
              return (
                <>
                  {!c?.permanencia_hasta && <div style={{ fontSize: 13, color: '#8a8a8a', marginBottom: 6 }}>Este restaurante no tiene permanencia: la baja no tiene coste.</div>}
                  {c?.permanencia_hasta && !c.en_permanencia && <div style={{ fontSize: 13, color: '#8a8a8a', marginBottom: 6 }}>Permanencia cumplida el {fmtFechaES(c.permanencia_hasta)}: la baja no tiene coste.</div>}
                  {c?.en_permanencia && c.en_trial && <div style={{ fontSize: 13, color: '#8a8a8a', marginBottom: 6 }}>Está en periodo de prueba: la baja no tiene coste. Si tiene comisiones, se retiran igualmente.</div>}
                  {c?.en_permanencia && !c.en_trial && (
                    <div style={{ background: '#2a2014', border: '0.5px solid #5a4a2a', borderRadius: 10, padding: '12px 14px', fontSize: 13, color: '#e8c97a', lineHeight: 1.6, marginBottom: 6 }}>
                      En permanencia hasta el <strong>{fmtFechaES(c.permanencia_hasta)}</strong>.<br />
                      Faltan {c.meses_pendientes} cuota{c.meses_pendientes === 1 ? '' : 's'} de {fmtEur(c.cuota)} → penalización del {Number(c.porcentaje) || PENALIZACION_PCT} %: <strong>{fmtEur(c.penalizacion)}</strong>
                      <label style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 10, color: '#f0f0f0', cursor: 'pointer' }}>
                        <input type="checkbox" checked={bajaModal.cobrar} onChange={e => setBajaModal(m => ({ ...m, cobrar: e.target.checked }))} />
                        Cobrar la penalización
                      </label>
                    </div>
                  )}
                  {c?.en_permanencia && (
                    <div style={S.hint}>Al estar en permanencia, las comisiones del vendedor por este cliente se retiran: las pendientes se anulan y las ya pagadas quedan "a descontar".</div>
                  )}

                  <label style={S.label}>Motivo de la baja *</label>
                  <select style={S.input} value={bajaModal.motivo} onChange={e => setBajaModal(m => ({ ...m, motivo: e.target.value }))}>
                    <option value="">Elige un motivo</option>
                    {MOTIVOS_BAJA.map(mo => <option key={mo} value={mo}>{mo}</option>)}
                  </select>
                  <label style={S.label}>Detalle (opcional)</label>
                  <input style={S.input} value={bajaModal.detalle} onChange={e => setBajaModal(m => ({ ...m, detalle: e.target.value }))} placeholder="Lo que haya contado el cliente" />

                  <div style={S.modalBtns}>
                    <button style={S.cancelBtn} onClick={() => setBajaModal(null)}>Cancelar</button>
                    <button style={S.saveBtn(bajaModal.guardando || !bajaModal.motivo)} disabled={bajaModal.guardando || !bajaModal.motivo} onClick={confirmarBaja}>
                      {bajaModal.guardando ? 'Guardando...' : 'Dar de baja'}
                    </button>
                  </div>
                </>
              )
            })()}
          </div>
        </div>
      )}
    </div>
  )
}
