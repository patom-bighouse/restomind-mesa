import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'

const ZONAS = ['sin preferencia', 'interior', 'terraza', 'privado', 'barra']

const S = {
  app: { minHeight: '100vh', background: '#1a1410', color: '#f0e8d8', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '32px 20px' },
  card: { width: '100%', maxWidth: 420 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 22, fontWeight: 600, color: '#e8c97a', textAlign: 'center', marginBottom: 4 },
  sub: { fontSize: 13, color: '#8a7560', textAlign: 'center', marginBottom: 28 },
  field: { marginBottom: 16 },
  label: { fontSize: 12, color: '#8a7560', marginBottom: 6, display: 'block' },
  input: { width: '100%', background: '#221c14', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '12px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' },
  row: { display: 'flex', gap: 12 },
  submitBtn: (disabled) => ({ width: '100%', background: disabled ? '#5a4a2a' : '#e8c97a', color: disabled ? '#8a7560' : '#1a1410', border: 'none', borderRadius: 10, padding: 14, fontSize: 15, fontWeight: 500, fontFamily: "'Inter', sans-serif", cursor: disabled ? 'not-allowed' : 'pointer', marginTop: 8 }),
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  center: { textAlign: 'center', padding: '40px 0' },
  big: { fontSize: 40, marginBottom: 14 },
  ctitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 8 },
  csub: { fontSize: 13, color: '#7a6a50', lineHeight: 1.5 },
  loading: { display: 'flex', flex: 1, alignItems: 'center', justifyContent: 'center', color: '#555', fontSize: 14 },
}

export default function Reservar() {
  const { restaurantId } = useParams()
  const [restaurant, setRestaurant] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [enviando, setEnviando] = useState(false)
  const [enviado, setEnviado] = useState(false)

  const [nombre, setNombre] = useState('')
  const [telefono, setTelefono] = useState('')
  const [fecha, setFecha] = useState('')
  const [hora, setHora] = useState('')
  const [personas, setPersonas] = useState('2')
  const [zona, setZona] = useState('sin preferencia')
  const [notas, setNotas] = useState('')

  useEffect(() => {
    async function load() {
      const { data, error: err } = await supabase.from('restaurants').select('nombre').eq('id', restaurantId).single()
      if (err || !data) { setError('No encontramos este restaurante.'); setLoading(false); return }
      setRestaurant(data)
      setLoading(false)
    }
    load()
  }, [restaurantId])

  const hoy = new Date().toISOString().slice(0, 10)
  const puedeEnviar = nombre.trim() && telefono.trim() && fecha && hora && parseInt(personas, 10) > 0

  async function enviarReserva() {
    if (!puedeEnviar) return
    setEnviando(true)
    setError(null)
    const { error: err } = await supabase.rpc('fn_crear_reserva_web', {
      p_restaurant_id: restaurantId,
      p_nombre: nombre.trim(),
      p_telefono: telefono.trim(),
      p_fecha: fecha,
      p_hora: hora,
      p_personas: parseInt(personas, 10),
      p_zona: zona,
      p_notas: notas.trim() || null,
    })
    setEnviando(false)
    if (err) { setError(err.message); return }
    setEnviado(true)
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  if (error && !restaurant) return (
    <div style={S.app}>
      <div style={{ ...S.card, ...S.center }}>
        <div style={S.big}>🚫</div>
        <div style={S.ctitle}>No encontrado</div>
        <div style={S.csub}>{error}</div>
      </div>
    </div>
  )

  if (enviado) return (
    <div style={S.app}>
      <div style={{ ...S.card, ...S.center }}>
        <div style={S.big}>🙏</div>
        <div style={S.ctitle}>¡Solicitud enviada!</div>
        <div style={S.csub}>{restaurant?.nombre} va a confirmar tu reserva a la brevedad. Gracias por elegirnos.</div>
      </div>
    </div>
  )

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.card}>
        <div style={S.logo}>{restaurant?.nombre}</div>
        <div style={S.sub}>Reservá tu mesa</div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.field}>
          <label style={S.label}>Nombre</label>
          <input style={S.input} value={nombre} onChange={e => setNombre(e.target.value)} placeholder="Tu nombre" />
        </div>
        <div style={S.field}>
          <label style={S.label}>Teléfono</label>
          <input style={S.input} type="tel" value={telefono} onChange={e => setTelefono(e.target.value)} placeholder="+34 6XX XXX XXX" />
        </div>
        <div style={{ ...S.row, ...S.field }}>
          <div style={{ flex: 1 }}>
            <label style={S.label}>Fecha</label>
            <input style={S.input} type="date" value={fecha} min={hoy} onChange={e => setFecha(e.target.value)} />
          </div>
          <div style={{ flex: 1 }}>
            <label style={S.label}>Hora</label>
            <input style={S.input} type="time" value={hora} onChange={e => setHora(e.target.value)} />
          </div>
        </div>
        <div style={{ ...S.row, ...S.field }}>
          <div style={{ flex: 1 }}>
            <label style={S.label}>Personas</label>
            <input style={S.input} type="number" min="1" value={personas} onChange={e => setPersonas(e.target.value)} />
          </div>
          <div style={{ flex: 1 }}>
            <label style={S.label}>Zona</label>
            <select style={S.input} value={zona} onChange={e => setZona(e.target.value)}>
              {ZONAS.map(z => <option key={z} value={z}>{z.charAt(0).toUpperCase() + z.slice(1)}</option>)}
            </select>
          </div>
        </div>
        <div style={S.field}>
          <label style={S.label}>Nota (opcional)</label>
          <input style={S.input} value={notas} onChange={e => setNotas(e.target.value)} placeholder="Ej. es un cumpleaños" />
        </div>

        <button style={S.submitBtn(!puedeEnviar || enviando)} onClick={enviarReserva} disabled={!puedeEnviar || enviando}>
          {enviando ? 'Enviando...' : 'Solicitar reserva'}
        </button>
      </div>
    </div>
  )
}
