import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

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
}

export default function AdminConfig() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const [restaurant, setRestaurant] = useState(null)
  const [horario, setHorario] = useState({})
  const [nombre, setNombre] = useState('')
  const [whatsapp, setWhatsapp] = useState('')
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
      .select('nombre, whatsapp, config')
      .eq('id', restaurantId)
      .single()
    if (rest) {
      setRestaurant(rest)
      setNombre(rest.nombre || '')
      setWhatsapp(rest.whatsapp || '')
      // Init horario with defaults for any missing days
      const h = rest.config?.horario || {}
      const horarioCompleto = {}
      DIAS.forEach(d => {
        horarioCompleto[d.key] = h[d.key] || { ...DEFAULT_DIA }
      })
      setHorario(horarioCompleto)
    }
    setLoading(false)
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
    setSaving(true)
    setError(null)
    setSuccess(null)
    try {
      const { error: err } = await supabase
        .from('restaurants')
        .update({
          nombre: nombre.trim(),
          whatsapp: whatsapp.trim(),
          config: { ...restaurant?.config, horario }
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
          <a href={`/admin/dashboard/${restaurantId}`} style={S.navTab(false)}>Dashboard</a>
          <a href={`/admin/mesas/${restaurantId}`} style={S.navTab(false)}>Mesas</a>
          <a href={`/admin/carta/${restaurantId}`} style={S.navTab(false)}>Carta</a>
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
