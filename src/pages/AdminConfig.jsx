import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useRestaurantModulos } from '../lib/modulos'

const DIAS = [
  { key: 'lunes',     label: 'Lunes' },
  { key: 'martes',    label: 'Martes' },
  { key: 'miercoles', label: 'Miércoles' },
  { key: 'jueves',    label: 'Jueves' },
  { key: 'viernes',   label: 'Viernes' },
  { key: 'sabado',    label: 'Sábado' },
  { key: 'domingo',   label: 'Domingo' },
]

const DEFAULT_DIA = { abierto: true, apertura: '13:00', cierre: '16:00', apertura2: '20:00', cierre2: '23:30' }

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10, flexWrap: 'wrap', gap: 12 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  navTabs: { display: 'flex', gap: 8, flexWrap: 'wrap' },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 24, maxWidth: 800, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 8 },
  sectionSub: { fontSize: 13, color: '#7a6a50', marginBottom: 24 },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  success: { background: '#142a1a', border: '0.5px solid #2a5a3a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#7ae8a0', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },

  diaCard: (abierto) => ({ background: '#1a1a1a', border: `0.5px solid ${abierto ? '#3a2e20' : '#2a2a2a'}`, borderRadius: 12, padding: '16px 20px', marginBottom: 10, opacity: abierto ? 1 : 0.5 }),
  diaHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  diaLabel: { fontSize: 15, fontWeight: 500, color: '#f0e8d8' },
  toggleSwitch: (on) => ({ width: 42, height: 24, borderRadius: 12, background: on ? '#27ae60' : '#3a2a2a', position: 'relative', cursor: 'pointer', transition: 'background 0.15s', flexShrink: 0 }),
  toggleDot: (on) => ({ width: 20, height: 20, borderRadius: '50%', background: '#fff', position: 'absolute', top: 2, left: on ? 20 : 2, transition: 'left 0.15s' }),

  franjaRow: { display: 'flex', gap: 12, alignItems: 'center', marginBottom: 8, flexWrap: 'wrap' },
  franjaLabel: { fontSize: 12, color: '#8a7560', minWidth: 80 },
  timeInput: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '7px 12px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', width: 100 },
  franjaToggle: (on) => ({ fontSize: 11, fontWeight: 500, padding: '4px 10px', borderRadius: 8, border: `0.5px solid ${on ? '#27ae60' : '#3a2e20'}`, background: 'transparent', color: on ? '#2ecc71' : '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }),

  saveBtn: (saving) => ({ background: saving ? '#5a4a2a' : '#e8c97a', color: saving ? '#8a7560' : '#111', border: 'none', borderRadius: 10, padding: '12px 28px', fontSize: 15, fontWeight: 500, cursor: saving ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif", marginTop: 24 }),

  infoCard: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '16px 20px', marginBottom: 24 },
  infoLabel: { fontSize: 12, color: '#8a7560', marginBottom: 6, display: 'block', marginTop: 12 },
  infoInput: { width: '100%', background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' },

  modoCocinaOptions: { display: 'flex', gap: 8, marginTop: 8 },
  modoCocinaBtn: (active) => ({ flex: 1, textAlign: 'left', background: active ? '#2a2010' : '#111', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 10, padding: '12px 14px', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }),
  modoCocinaBtnTitle: (active) => ({ fontSize: 14, fontWeight: 500, color: active ? '#e8c97a' : '#f0e8d8', marginBottom: 3 }),
  modoCocinaBtnDesc: { fontSize: 12, color: '#8a7560', lineHeight: 1.4 },
  minutosRow: { display: 'flex', alignItems: 'center', gap: 10, marginTop: 14 },
  minutosInput: { width: 70, background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '8px 10px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', textAlign: 'center' },
}

export default function AdminConfig() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [horario, setHorario] = useState({})
  const [nombre, setNombre] = useState('')
  const [whatsapp, setWhatsapp] = useState('')
  const [modoCocina, setModoCocina] = useState('orden_llegada')
  const [minutosLimite, setMinutosLimite] = useState(20)
  const [umbralMargenAlerta, setUmbralMargenAlerta] = useState(20)
  const [modoPedidos, setModoPedidos] = useState('cliente')
  const [camareros, setCamareros] = useState([])
  const [nuevoCamareroNombre, setNuevoCamareroNombre] = useState('')
  const [nuevoCamareroPin, setNuevoCamareroPin] = useState('')
  const [camareroError, setCamareroError] = useState(null)
  const [sectoresCocinaActivo, setSectoresCocinaActivo] = useState(false)
  const [envasesSostenibles, setEnvasesSostenibles] = useState(false)
  const [puntosPorEuro, setPuntosPorEuro] = useState(1)
  const [sectores, setSectores] = useState([])
  const [nuevoSectorNombre, setNuevoSectorNombre] = useState('')
  const [sectorError, setSectorError] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    loadData()
  }

  async function loadData() {
    const { data: rest } = await supabase
      .from('restaurants')
      .select('nombre, whatsapp, config, modo_cocina, minutos_limite_agrupado')
      .eq('id', restaurantId)
      .single()
    if (rest) {
      setRestaurant(rest)
      setNombre(rest.nombre || '')
      setWhatsapp(rest.whatsapp || '')
      setModoCocina(rest.modo_cocina || 'orden_llegada')
      setMinutosLimite(rest.minutos_limite_agrupado ?? 20)
      setUmbralMargenAlerta(rest.config?.umbral_margen_alerta ?? 20)
      setModoPedidos(rest.config?.modo_pedidos || 'cliente')
      setSectoresCocinaActivo(rest.config?.sectores_cocina_activo || false)
      setEnvasesSostenibles(rest.config?.envases_sostenibles_takeaway || false)
      setPuntosPorEuro(rest.config?.puntos_por_euro ?? 1)
      // Init horario with defaults for any missing days
      const h = rest.config?.horario || {}
      const horarioCompleto = {}
      DIAS.forEach(d => {
        horarioCompleto[d.key] = h[d.key] || { ...DEFAULT_DIA }
      })
      setHorario(horarioCompleto)
    }
    await loadCamareros()
    await loadSectores()
    setLoading(false)
  }

  async function loadSectores() {
    const { data } = await supabase
      .from('sectores_cocina')
      .select('id, nombre, orden')
      .eq('restaurant_id', restaurantId)
      .order('orden')
    setSectores(data || [])
  }

  async function addSector() {
    setSectorError(null)
    const nombre = nuevoSectorNombre.trim()
    if (!nombre) { setSectorError('Ingresá el nombre del sector.'); return }
    const orden = sectores.length
    const { error: err } = await supabase
      .from('sectores_cocina')
      .insert({ restaurant_id: restaurantId, nombre, orden })
    if (err) { setSectorError(err.message); return }
    setNuevoSectorNombre('')
    await loadSectores()
  }

  async function renombrarSector(sector, nuevoNombre) {
    const nombre = nuevoNombre.trim()
    if (!nombre || nombre === sector.nombre) return
    await supabase.from('sectores_cocina').update({ nombre }).eq('id', sector.id)
    await loadSectores()
  }

  async function eliminarSector(sector) {
    if (!confirm(`¿Eliminar el sector "${sector.nombre}"? Los platos que lo tenían asignado quedarán sin sector (generales).`)) return
    await supabase.from('sectores_cocina').delete().eq('id', sector.id)
    await loadSectores()
  }

  async function loadCamareros() {
    const { data } = await supabase
      .from('camareros')
      .select('id, nombre, pin, activo')
      .eq('restaurant_id', restaurantId)
      .order('nombre')
    setCamareros(data || [])
  }

  async function addCamarero() {
    setCamareroError(null)
    const nombre = nuevoCamareroNombre.trim()
    const pin = nuevoCamareroPin.trim()
    if (!nombre) { setCamareroError('Ingresá el nombre del camarero.'); return }
    if (!/^\d{4}$/.test(pin)) { setCamareroError('El PIN debe ser de 4 dígitos numéricos.'); return }
    const { error: err } = await supabase
      .from('camareros')
      .insert({ restaurant_id: restaurantId, nombre, pin })
    if (err) {
      setCamareroError(err.code === '23505' ? 'Ya existe un camarero con ese PIN. Elegí otro.' : err.message)
      return
    }
    setNuevoCamareroNombre('')
    setNuevoCamareroPin('')
    await loadCamareros()
  }

  async function toggleCamareroActivo(camarero) {
    await supabase.from('camareros').update({ activo: !camarero.activo }).eq('id', camarero.id)
    await loadCamareros()
  }

  async function eliminarCamarero(camarero) {
    if (!confirm(`¿Eliminar a ${camarero.nombre}? Los pedidos que ya cargó quedan igual en el historial.`)) return
    await supabase.from('camareros').delete().eq('id', camarero.id)
    await loadCamareros()
  }

  function updateDia(diaKey, field, value) {
    setHorario(prev => ({
      ...prev,
      [diaKey]: { ...prev[diaKey], [field]: value }
    }))
  }

  function toggleFranja2(diaKey) {
    const dia = horario[diaKey]
    if (dia.apertura2) {
      // Remove franja 2
      const { apertura2, cierre2, ...rest } = dia
      setHorario(prev => ({ ...prev, [diaKey]: rest }))
    } else {
      // Add franja 2
      setHorario(prev => ({ ...prev, [diaKey]: { ...dia, apertura2: '20:00', cierre2: '23:30' } }))
    }
  }

  async function handleSave() {
    setError(null)
    setSuccess(null)

    const minutos = parseInt(minutosLimite, 10)
    if (modoCocina === 'agrupado_mesa' && (!Number.isInteger(minutos) || minutos <= 0)) {
      setError('Los minutos para agrupar pedidos deben ser un número mayor a 0.')
      return
    }

    const umbral = parseInt(umbralMargenAlerta, 10)
    if (!Number.isInteger(umbral) || umbral < 0 || umbral > 100) {
      setError('El umbral de alerta de margen debe ser un número entre 0 y 100.')
      return
    }

    setSaving(true)
    try {
      const { error: err } = await supabase
        .from('restaurants')
        .update({
          nombre: nombre.trim(),
          whatsapp: whatsapp.trim(),
          config: { ...restaurant?.config, horario, umbral_margen_alerta: umbral, modo_pedidos: modoPedidos, sectores_cocina_activo: sectoresCocinaActivo, envases_sostenibles_takeaway: envasesSostenibles, puntos_por_euro: parseFloat(puntosPorEuro) || 1 },
          modo_cocina: modoCocina,
          minutos_limite_agrupado: minutos,
        })
        .eq('id', restaurantId)
      if (err) throw err
      setSuccess('Configuración guardada correctamente.')
      setRestaurant(prev => ({ ...prev, nombre: nombre.trim(), whatsapp: whatsapp.trim() }))
    } catch (e) {
      setError(e.message)
    } finally {
      setSaving(false)
    }
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.header}>
        <div>
          <div style={S.logo}>Restomind Admin</div>
          <div style={S.restName}>{restaurant?.nombre}</div>
        </div>
        <div style={S.navTabs}>
          {tieneModulo('reportes') && <a href={`/admin/dashboard/${restaurantId}`} style={S.navTab(false)}>Dashboard</a>}
          <a href={`/admin/mesas/${restaurantId}`} style={S.navTab(false)}>Mesas</a>
          <a href={`/admin/carta/${restaurantId}`} style={S.navTab(false)}>Carta</a>
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(false)}>Clientes</a>
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>
          <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(false)}>Reservas</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(true)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Configuración del restaurante</div>
        <div style={S.sectionSub}>Estos datos son usados por el agente de WhatsApp para responder correctamente a los clientes.</div>

        {error && <div style={S.error}>{error}</div>}
        {success && <div style={S.success}>{success}</div>}

        {/* Datos básicos */}
        <div style={S.infoCard}>
          <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 }}>Datos del restaurante</div>
          <label style={S.infoLabel}>Nombre</label>
          <input style={S.infoInput} value={nombre} onChange={e => setNombre(e.target.value)} placeholder="Nombre del restaurante" />
          <label style={S.infoLabel}>WhatsApp (con prefijo, sin +)</label>
          <input style={S.infoInput} value={whatsapp} onChange={e => setWhatsapp(e.target.value)} placeholder="34600000000" />
          <div style={{ fontSize: 11, color: '#555', marginTop: 4 }}>El agente de WhatsApp identifica el restaurante por este número.</div>
        </div>

        {/* Modo de cocina */}
        <div style={S.infoCard}>
          <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 }}>Modo de cocina</div>
          <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 4 }}>Define cómo se agrupan los pedidos de una misma mesa en la pantalla de Cocina.</div>

          <div style={S.modoCocinaOptions}>
            <div style={S.modoCocinaBtn(modoCocina === 'orden_llegada')} onClick={() => setModoCocina('orden_llegada')}>
              <div style={S.modoCocinaBtnTitle(modoCocina === 'orden_llegada')}>Orden de llegada</div>
              <div style={S.modoCocinaBtnDesc}>Cada pedido se prepara y se sirve por separado, en el orden en que llegó.</div>
            </div>
            <div style={S.modoCocinaBtn(modoCocina === 'agrupado_mesa')} onClick={() => setModoCocina('agrupado_mesa')}>
              <div style={S.modoCocinaBtnTitle(modoCocina === 'agrupado_mesa')}>Agrupado por mesa</div>
              <div style={S.modoCocinaBtnDesc}>Los pedidos de una misma mesa se juntan para prepararlos y servirlos a la vez.</div>
            </div>
          </div>

          {modoCocina === 'agrupado_mesa' && (
            <div style={S.minutosRow}>
              <span style={{ fontSize: 13, color: '#8a7560' }}>Agrupar pedidos de la misma mesa durante</span>
              <input
                style={S.minutosInput}
                type="number"
                min="1"
                value={minutosLimite}
                onChange={e => setMinutosLimite(e.target.value)}
              />
              <span style={{ fontSize: 13, color: '#8a7560' }}>minutos</span>
            </div>
          )}
        </div>

        {/* Alerta de margen */}
        <div style={S.infoCard}>
          <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 }}>Alerta de rentabilidad</div>
          <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 4 }}>
            En el Dashboard, la sección "Rentabilidad por producto" resalta en rojo los productos cuyo margen esté por debajo de este porcentaje.
          </div>
          <div style={S.minutosRow}>
            <span style={{ fontSize: 13, color: '#8a7560' }}>Avisar cuando el margen sea menor a</span>
            <input
              style={S.minutosInput}
              type="number"
              min="0"
              max="100"
              value={umbralMargenAlerta}
              onChange={e => setUmbralMargenAlerta(e.target.value)}
            />
            <span style={{ fontSize: 13, color: '#8a7560' }}>%</span>
          </div>
        </div>

        {/* Modo de pedidos: cliente desde la mesa vs camarero con tablet */}
        <div style={S.infoCard}>
          <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 }}>Modo de pedidos</div>
          <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 4 }}>Define quién carga los pedidos de las mesas.</div>

          <div style={S.modoCocinaOptions}>
            <div style={S.modoCocinaBtn(modoPedidos === 'cliente')} onClick={() => setModoPedidos('cliente')}>
              <div style={S.modoCocinaBtnTitle(modoPedidos === 'cliente')}>Cliente desde la mesa</div>
              <div style={S.modoCocinaBtnDesc}>El cliente escanea el QR y arma su pedido solo, desde su celular.</div>
            </div>
            <div style={S.modoCocinaBtn(modoPedidos === 'camarero')} onClick={() => setModoPedidos('camarero')}>
              <div style={S.modoCocinaBtnTitle(modoPedidos === 'camarero')}>Camarero con tablet</div>
              <div style={S.modoCocinaBtnDesc}>El camarero toma el pedido desde su propia pantalla. El cliente solo ve la carta y su cuenta.</div>
            </div>
          </div>
        </div>

        {/* Gestión de camareros, solo relevante en modo 'camarero' */}
        {modoPedidos === 'camarero' && (
          <div style={S.infoCard}>
            <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 }}>Camareros</div>
            <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 12 }}>
              Cada camarero entra a su pantalla con este PIN de 4 dígitos. Recordá guardar la configuración de arriba para activar el modo camarero.
            </div>

            {camareroError && <div style={{ ...S.error, marginBottom: 12 }}>{camareroError}</div>}

            {camareros.length > 0 && (
              <div style={{ marginBottom: 16 }}>
                {camareros.map(c => (
                  <div key={c.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 0', borderBottom: '0.5px solid #2a2a2a' }}>
                    <div>
                      <span style={{ fontSize: 14, color: c.activo ? '#f0e8d8' : '#666' }}>{c.nombre}</span>
                      <span style={{ fontSize: 12, color: '#7a6a50', marginLeft: 10 }}>PIN: {c.pin}</span>
                      {!c.activo && <span style={{ fontSize: 11, color: '#e87a7a', marginLeft: 10 }}>Inactivo</span>}
                    </div>
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button style={S.franjaToggle(c.activo)} onClick={() => toggleCamareroActivo(c)}>
                        {c.activo ? 'Desactivar' : 'Activar'}
                      </button>
                      <button style={{ ...S.franjaToggle(false), color: '#e87a7a', borderColor: '#6a2e20' }} onClick={() => eliminarCamarero(c)}>
                        Eliminar
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}

            <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
              <input
                style={{ ...S.infoInput, width: 180 }}
                placeholder="Nombre del camarero"
                value={nuevoCamareroNombre}
                onChange={e => setNuevoCamareroNombre(e.target.value)}
              />
              <input
                style={{ ...S.infoInput, width: 90 }}
                placeholder="PIN (4 dígitos)"
                maxLength={4}
                value={nuevoCamareroPin}
                onChange={e => setNuevoCamareroPin(e.target.value.replace(/\D/g, ''))}
              />
              <button style={S.franjaToggle(true)} onClick={addCamarero}>+ Agregar</button>
            </div>
          </div>
        )}

        {/* Sectores de cocina */}
        <div style={S.infoCard}>
          <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 }}>Sectores de cocina</div>
          <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 12 }}>
            Si tu cocina está dividida en estaciones (Parrilla, Cocina fría, Postres...), activá esto para poder filtrar las comandas por sector en la pantalla de Cocina.
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: sectoresCocinaActivo ? 16 : 0 }}>
            <div style={S.toggleSwitch(sectoresCocinaActivo)} onClick={() => setSectoresCocinaActivo(!sectoresCocinaActivo)}>
              <div style={S.toggleDot(sectoresCocinaActivo)}></div>
            </div>
            <span style={{ fontSize: 13, color: '#8a7560' }}>¿Tiene distintos sectores de cocina?</span>
          </div>

          {sectoresCocinaActivo && (
            <>
              {sectorError && <div style={{ ...S.error, marginBottom: 12 }}>{sectorError}</div>}

              {sectores.length > 0 && (
                <div style={{ marginBottom: 16 }}>
                  {sectores.map(s => (
                    <div key={s.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 0', borderBottom: '0.5px solid #2a2a2a' }}>
                      <input
                        style={{ ...S.infoInput, width: 220, padding: '6px 10px' }}
                        defaultValue={s.nombre}
                        onBlur={e => renombrarSector(s, e.target.value)}
                      />
                      <button style={{ ...S.franjaToggle(false), color: '#e87a7a', borderColor: '#6a2e20' }} onClick={() => eliminarSector(s)}>
                        Eliminar
                      </button>
                    </div>
                  ))}
                </div>
              )}

              <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
                <input
                  style={{ ...S.infoInput, width: 220 }}
                  placeholder="Nombre del sector (ej: Parrilla)"
                  value={nuevoSectorNombre}
                  onChange={e => setNuevoSectorNombre(e.target.value)}
                />
                <button style={S.franjaToggle(true)} onClick={addSector}>+ Agregar</button>
              </div>

              <div style={{ fontSize: 11, color: '#555', marginTop: 12 }}>
                Los platos sin sector asignado se consideran "generales" y aparecen siempre visibles en Cocina, sin importar el filtro activo.
              </div>
            </>
          )}
        </div>

        {/* Envases (take away) */}
        <div style={S.infoCard}>
          <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 }}>Envases (take away)</div>
          <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 12 }}>
            La Ley 7/2022 obliga a cobrar por separado el envase si es de plástico de un solo uso. Si usás envases compostables, reciclables o reutilizables, la ley prohíbe cobrarlos aparte — deben ser gratuitos.
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={S.toggleSwitch(envasesSostenibles)} onClick={() => setEnvasesSostenibles(!envasesSostenibles)}>
              <div style={S.toggleDot(envasesSostenibles)}></div>
            </div>
            <span style={{ fontSize: 13, color: '#8a7560' }}>Usamos envases sostenibles (no plástico de un solo uso)</span>
          </div>
          {envasesSostenibles && (
            <div style={{ fontSize: 11, color: '#555', marginTop: 10 }}>
              El agente de WhatsApp avisará automáticamente al cliente que no se cobra recargo por el envase en sus pedidos para llevar.
            </div>
          )}
        </div>

        {/* Fidelización */}
        <div style={S.infoCard}>
          <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 }}>Fidelización (puntos)</div>
          <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 12 }}>
            Los puntos se otorgan automáticamente al marcar un pedido de take away como "Entregado". Por ahora solo aplica a pedidos por WhatsApp (take away), no a pedidos de mesa.
          </div>
          <div style={S.minutosRow}>
            <span style={{ fontSize: 13, color: '#8a7560' }}>Puntos por cada 1€ gastado</span>
            <input
              style={S.minutosInput}
              type="number"
              min="0"
              step="0.1"
              value={puntosPorEuro}
              onChange={e => setPuntosPorEuro(e.target.value)}
            />
          </div>
        </div>

        {/* Horarios */}
        <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 16 }}>Horarios de apertura</div>

        {DIAS.map(({ key, label }) => {
          const dia = horario[key] || { ...DEFAULT_DIA }
          return (
            <div key={key} style={S.diaCard(dia.abierto)}>
              <div style={S.diaHeader}>
                <span style={S.diaLabel}>{label}</span>
                <div style={S.toggleSwitch(dia.abierto)} onClick={() => updateDia(key, 'abierto', !dia.abierto)}>
                  <div style={S.toggleDot(dia.abierto)}></div>
                </div>
              </div>

              {dia.abierto && (
                <>
                  {/* Franja 1 */}
                  <div style={S.franjaRow}>
                    <span style={S.franjaLabel}>Mediodía</span>
                    <input style={S.timeInput} type="time" value={dia.apertura || ''} onChange={e => updateDia(key, 'apertura', e.target.value)} />
                    <span style={{ fontSize: 12, color: '#555' }}>a</span>
                    <input style={S.timeInput} type="time" value={dia.cierre || ''} onChange={e => updateDia(key, 'cierre', e.target.value)} />
                  </div>

                  {/* Franja 2 */}
                  <div style={S.franjaRow}>
                    <span style={S.franjaLabel}>Noche</span>
                    {dia.apertura2 ? (
                      <>
                        <input style={S.timeInput} type="time" value={dia.apertura2 || ''} onChange={e => updateDia(key, 'apertura2', e.target.value)} />
                        <span style={{ fontSize: 12, color: '#555' }}>a</span>
                        <input style={S.timeInput} type="time" value={dia.cierre2 || ''} onChange={e => updateDia(key, 'cierre2', e.target.value)} />
                        <button style={S.franjaToggle(true)} onClick={() => toggleFranja2(key)}>Quitar</button>
                      </>
                    ) : (
                      <button style={S.franjaToggle(false)} onClick={() => toggleFranja2(key)}>+ Añadir turno de noche</button>
                    )}
                  </div>
                </>
              )}
            </div>
          )
        })}

        <button style={S.saveBtn(saving)} onClick={handleSave} disabled={saving}>
          {saving ? 'Guardando...' : 'Guardar configuración'}
        </button>
      </div>
    </div>
  )
}
