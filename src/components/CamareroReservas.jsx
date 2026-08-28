import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'

const ZONAS = ['sin preferencia', 'interior', 'terraza', 'privado', 'barra']

const ESTADO_CFG = {
  pendiente: { label: 'Pendiente', color: '#e8b84a', bg: '#2a2010' },
  confirmada: { label: 'Confirmada', color: '#2ecc71', bg: '#0f2a15' },
  cancelada: { label: 'Cancelada', color: '#8a7560', bg: '#1a1a1a' },
  noshow: { label: 'No vino', color: '#e74c3c', bg: '#2a1410' },
}

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif", display: 'flex', flexDirection: 'column' },
  header: { background: '#0a0a0a', padding: '14px 20px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' },
  backBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 16, flex: 1, overflowY: 'auto' },
  addBar: { display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap', alignItems: 'flex-end', background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 14 },
  field: { display: 'flex', flexDirection: 'column', gap: 4 },
  label: { fontSize: 10, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em' },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '8px 10px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 8, padding: '9px 16px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  filterBar: { display: 'flex', gap: 8, marginBottom: 14, flexWrap: 'wrap' },
  filterBtn: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 20, padding: '5px 12px', fontSize: 11, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }),
  card: { background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: 12, marginBottom: 8 },
  cardTop: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 },
  cardTitle: { fontSize: 14, color: '#f0e8d8' },
  cardMeta: { fontSize: 12, color: '#7a6a50' },
  select: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '5px 8px', fontSize: 11, fontFamily: "'Inter', sans-serif", outline: 'none' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 40, color: '#555', fontSize: 14 },
}

// Igual que CamareroClientes: nunca lee `reservations` directo, todo
// pasa por las funciones fn_staff_* que revisan el permiso 'reservas'.
export default function CamareroReservas({ camarero, restaurantId, onVolver }) {
  const [reservas, setReservas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [filtro, setFiltro] = useState('proximas')

  const [nombre, setNombre] = useState('')
  const [telefono, setTelefono] = useState('')
  const [fecha, setFecha] = useState('')
  const [hora, setHora] = useState('')
  const [personas, setPersonas] = useState('2')
  const [zona, setZona] = useState('sin preferencia')
  const [adding, setAdding] = useState(false)

  useEffect(() => { loadReservas() }, [])

  async function loadReservas() {
    setLoading(true)
    const { data, error: err } = await supabase.rpc('fn_staff_listar_reservas', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
    })
    setLoading(false)
    if (err) { setError(err.message); return }
    setReservas(data || [])
  }

  const hoy = new Date().toISOString().slice(0, 10)
  const reservasFiltradas = reservas.filter(r => {
    if (filtro === 'proximas') return r.fecha >= hoy && r.estado !== 'cancelada'
    return true
  })

  async function cambiarEstado(reserva, nuevoEstado) {
    setReservas(prev => prev.map(r => r.id === reserva.id ? { ...r, estado: nuevoEstado } : r))
    const { error: err } = await supabase.rpc('fn_staff_cambiar_estado_reserva', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
      p_reserva_id: reserva.id,
      p_nuevo_estado: nuevoEstado,
    })
    if (err) { setError(err.message); await loadReservas() }
  }

  async function addReserva() {
    if (!nombre.trim() || !telefono.trim() || !fecha || !hora || !personas) return
    setError(null)
    setAdding(true)
    const { error: err } = await supabase.rpc('fn_staff_crear_reserva_manual', {
      p_restaurant_id: restaurantId,
      p_camarero_id: camarero.id,
      p_nombre: nombre.trim(),
      p_telefono: telefono.trim(),
      p_fecha: fecha,
      p_hora: hora,
      p_personas: parseInt(personas, 10),
      p_zona: zona,
      p_notas: null,
    })
    setAdding(false)
    if (err) { setError(err.message); return }
    setNombre(''); setTelefono(''); setFecha(''); setHora(''); setPersonas('2'); setZona('sin preferencia')
    await loadReservas()
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <div style={S.app}>
      <div style={S.header}>
        <div style={S.logo}>Reservas</div>
        <button style={S.backBtn} onClick={onVolver}>← Volver</button>
      </div>

      <div style={S.content}>
        {error && <div style={S.error}>{error}</div>}

        <div style={S.addBar}>
          <div style={S.field}>
            <span style={S.label}>Nombre</span>
            <input style={{ ...S.input, width: 120 }} value={nombre} onChange={e => setNombre(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Teléfono</span>
            <input style={{ ...S.input, width: 110 }} value={telefono} onChange={e => setTelefono(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Fecha</span>
            <input style={S.input} type="date" min={hoy} value={fecha} onChange={e => setFecha(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Hora</span>
            <input style={S.input} type="time" value={hora} onChange={e => setHora(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Personas</span>
            <input style={{ ...S.input, width: 55 }} type="number" min="1" value={personas} onChange={e => setPersonas(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Zona</span>
            <select style={S.input} value={zona} onChange={e => setZona(e.target.value)}>
              {ZONAS.map(z => <option key={z} value={z}>{z.charAt(0).toUpperCase() + z.slice(1)}</option>)}
            </select>
          </div>
          <button style={S.addBtn} onClick={addReserva} disabled={adding}>{adding ? '...' : '+ Añadir'}</button>
        </div>

        <div style={S.filterBar}>
          <button style={S.filterBtn(filtro === 'proximas')} onClick={() => setFiltro('proximas')}>Próximas</button>
          <button style={S.filterBtn(filtro === 'todas')} onClick={() => setFiltro('todas')}>Todas</button>
        </div>

        {reservasFiltradas.length === 0 ? (
          <div style={S.empty}>No hay reservas para este filtro.</div>
        ) : (
          reservasFiltradas.map(r => (
            <div key={r.id} style={S.card}>
              <div style={S.cardTop}>
                <div>
                  <div style={S.cardTitle}>{r.nombre} · {r.personas}p</div>
                  <div style={S.cardMeta}>{new Date(r.fecha + 'T00:00:00').toLocaleDateString('es-ES')} {r.hora?.slice(0, 5)} · {r.zona} · {r.telefono}</div>
                </div>
                <select
                  style={{ ...S.select, background: ESTADO_CFG[r.estado]?.bg, color: ESTADO_CFG[r.estado]?.color, borderColor: ESTADO_CFG[r.estado]?.color }}
                  value={r.estado}
                  onChange={e => cambiarEstado(r, e.target.value)}
                >
                  {Object.entries(ESTADO_CFG).map(([key, cfg]) => (
                    <option key={key} value={key}>{cfg.label}</option>
                  ))}
                </select>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
