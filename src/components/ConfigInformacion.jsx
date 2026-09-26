import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'

// Atajos para no empezar con la página en blanco: al pulsar uno se crea
// la entrada con ese título y el dueño solo tiene que escribir el texto.
const PLANTILLAS = [
  'Parking',
  'Climatización',
  'Accesibilidad',
  'Mascotas',
  'Menú infantil',
  'Opciones sin gluten y alérgenos',
  'Formas de pago',
  'Cómo llegar',
  'Grupos y eventos',
  'Terraza',
]

// Aviso orientativo (no bloquea): todo este texto acaba dentro del
// prompt del agente de WhatsApp, y demasiado texto lo hace más lento.
const LIMITE_ORIENTATIVO = 4000
const MAX_CONTENIDO = 2000
const MAX_TITULO = 80

const S = {
  card: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '16px 20px', marginBottom: 16 },
  cardOff: { opacity: 0.6 },
  title: { fontSize: 14, fontWeight: 500, color: '#c4a85a', marginBottom: 4 },
  hint: { fontSize: 12, color: '#7a6a50', marginBottom: 12, lineHeight: 1.5 },
  input: { width: '100%', background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' },
  textarea: { width: '100%', background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box', minHeight: 90, resize: 'vertical', marginTop: 8, lineHeight: 1.5 },
  chips: { display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 4 },
  chip: (disabled) => ({ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 16, padding: '5px 12px', fontSize: 12, color: disabled ? '#5a4a2a' : '#c4a85a', cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
  addBtn: (disabled) => ({ background: 'transparent', border: '0.5px dashed #e8c97a', borderRadius: 10, padding: '10px 16px', fontSize: 13, color: disabled ? '#5a4a2a' : '#e8c97a', cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif", width: '100%' }),
  rowTop: { display: 'flex', alignItems: 'center', gap: 10 },
  iconBtn: (disabled) => ({ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 6, width: 28, height: 28, fontSize: 13, color: disabled ? '#3a2e20' : '#8a7560', cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif", flexShrink: 0 }),
  delBtn: { background: 'transparent', border: 'none', fontSize: 12, color: '#c0605a', cursor: 'pointer', fontFamily: "'Inter', sans-serif", padding: 0 },
  toggleSwitch: (on) => ({ width: 42, height: 24, borderRadius: 12, background: on ? '#27ae60' : '#3a2a2a', position: 'relative', cursor: 'pointer', transition: 'background 0.15s', flexShrink: 0 }),
  toggleDot: (on) => ({ width: 20, height: 20, borderRadius: '50%', background: '#fff', position: 'absolute', top: 2, left: on ? 20 : 2, transition: 'left 0.15s' }),
  footRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 8, fontSize: 11, color: '#555' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  aviso: { background: '#2a2010', border: '0.5px solid #5a4a2a', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#c4a85a', marginBottom: 16, lineHeight: 1.5 },
  vacio: { fontSize: 13, color: '#7a6a50', textAlign: 'center', padding: '20px 0' },
}

export default function ConfigInformacion({ restaurantId }) {
  const [entradas, setEntradas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [guardadoId, setGuardadoId] = useState(null)
  const [ocupado, setOcupado] = useState(false)

  useEffect(() => { cargar() }, [restaurantId])

  async function cargar() {
    const { data, error: err } = await supabase
      .from('restaurant_info')
      .select('id, titulo, contenido, orden, activo')
      .eq('restaurant_id', restaurantId)
      .order('orden')
      .order('created_at')
    if (err) setError(err.message)
    setEntradas(data || [])
    setLoading(false)
  }

  function marcarGuardado(id) {
    setGuardadoId(id)
    setTimeout(() => setGuardadoId(prev => (prev === id ? null : prev)), 1800)
  }

  async function anadir(titulo) {
    if (ocupado) return
    setOcupado(true)
    setError(null)
    const siguienteOrden = entradas.reduce((max, e) => Math.max(max, e.orden), 0) + 1
    const { data, error: err } = await supabase
      .from('restaurant_info')
      .insert({ restaurant_id: restaurantId, titulo, contenido: '', orden: siguienteOrden })
      .select('id, titulo, contenido, orden, activo')
      .single()
    setOcupado(false)
    if (err) { setError(err.message); return }
    setEntradas(prev => [...prev, data])
  }

  function editarLocal(id, cambios) {
    setEntradas(prev => prev.map(e => e.id === id ? { ...e, ...cambios } : e))
  }

  // Se guarda al salir del campo (onBlur) y al cambiar el interruptor.
  async function guardar(entrada) {
    const titulo = entrada.titulo.trim()
    if (!titulo) { setError('El título no puede estar vacío.'); return }
    setError(null)
    const { error: err } = await supabase
      .from('restaurant_info')
      .update({ titulo, contenido: entrada.contenido, activo: entrada.activo, updated_at: new Date().toISOString() })
      .eq('id', entrada.id)
    if (err) { setError(err.message); return }
    marcarGuardado(entrada.id)
  }

  async function alternarActivo(entrada) {
    const actualizada = { ...entrada, activo: !entrada.activo }
    editarLocal(entrada.id, { activo: actualizada.activo })
    await guardar(actualizada)
  }

  async function eliminar(entrada) {
    if (!window.confirm(`¿Eliminar "${entrada.titulo}"?`)) return
    setError(null)
    const { error: err } = await supabase.from('restaurant_info').delete().eq('id', entrada.id)
    if (err) { setError(err.message); return }
    setEntradas(prev => prev.filter(e => e.id !== entrada.id))
  }

  async function mover(indice, delta) {
    const destino = indice + delta
    if (destino < 0 || destino >= entradas.length || ocupado) return
    const nueva = [...entradas]
    ;[nueva[indice], nueva[destino]] = [nueva[destino], nueva[indice]]
    const renumerada = nueva.map((e, i) => ({ ...e, orden: i + 1 }))
    setEntradas(renumerada)
    setOcupado(true)
    const cambiadas = renumerada.filter((e, i) => e.orden !== entradas.find(o => o.id === e.id)?.orden)
    const resultados = await Promise.all(
      cambiadas.map(e => supabase.from('restaurant_info').update({ orden: e.orden }).eq('id', e.id))
    )
    setOcupado(false)
    const fallo = resultados.find(r => r.error)
    if (fallo) { setError(fallo.error.message); await cargar() }
  }

  if (loading) return <div style={S.vacio}>Cargando...</div>

  const totalCaracteres = entradas
    .filter(e => e.activo)
    .reduce((sum, e) => sum + e.titulo.length + e.contenido.length, 0)
  const titulosUsados = new Set(entradas.map(e => e.titulo.trim().toLowerCase()))

  return (
    <div>
      <div style={S.card}>
        <div style={S.title}>Información de tu restaurante</div>
        <div style={S.hint}>
          Escribe aquí todo lo que quieras que sepan tus clientes: parking, climatización, accesibilidad, mascotas…
          El agente de WhatsApp responderá con esta información (y solo con ella, sin inventar nada) y se mostrará también
          en tu página de reservas. Lo que no escribas aquí, el agente dirá que no lo sabe.
        </div>
        <div style={{ fontSize: 12, color: '#8a7560', marginBottom: 4 }}>Añadir con una plantilla:</div>
        <div style={S.chips}>
          {PLANTILLAS.map(p => {
            const usada = titulosUsados.has(p.toLowerCase())
            return (
              <button key={p} style={S.chip(usada || ocupado)} disabled={usada || ocupado} onClick={() => anadir(p)}>
                + {p}
              </button>
            )
          })}
        </div>
      </div>

      {error && <div style={S.error}>{error}</div>}

      {totalCaracteres > LIMITE_ORIENTATIVO && (
        <div style={S.aviso}>
          Llevas {totalCaracteres} caracteres de información activa. Con tanto texto el asistente puede responder más despacio:
          intenta resumir o desactiva lo que menos consulten tus clientes.
        </div>
      )}

      {entradas.length === 0 && (
        <div style={S.vacio}>Todavía no has añadido nada. Elige una plantilla o crea tu propia entrada.</div>
      )}

      {entradas.map((e, i) => (
        <div key={e.id} style={{ ...S.card, ...(e.activo ? {} : S.cardOff) }}>
          <div style={S.rowTop}>
            <input
              style={{ ...S.input, flex: 1, fontWeight: 500 }}
              value={e.titulo}
              maxLength={MAX_TITULO}
              onChange={ev => editarLocal(e.id, { titulo: ev.target.value })}
              onBlur={() => guardar(e)}
              placeholder="Título (ej. Parking)"
            />
            <button style={S.iconBtn(i === 0 || ocupado)} disabled={i === 0 || ocupado} onClick={() => mover(i, -1)} title="Subir">↑</button>
            <button style={S.iconBtn(i === entradas.length - 1 || ocupado)} disabled={i === entradas.length - 1 || ocupado} onClick={() => mover(i, 1)} title="Bajar">↓</button>
            <div style={S.toggleSwitch(e.activo)} onClick={() => alternarActivo(e)} title={e.activo ? 'Visible para los clientes' : 'Oculta'}>
              <div style={S.toggleDot(e.activo)}></div>
            </div>
          </div>
          <textarea
            style={S.textarea}
            value={e.contenido}
            maxLength={MAX_CONTENIDO}
            onChange={ev => editarLocal(e.id, { contenido: ev.target.value })}
            onBlur={() => guardar(e)}
            placeholder="Escribe aquí la información…"
          />
          <div style={S.footRow}>
            <span>
              {guardadoId === e.id
                ? <span style={{ color: '#7ae8a0' }}>Guardado ✓</span>
                : `${e.contenido.length}/${MAX_CONTENIDO}${e.activo ? '' : ' · Oculta (no se muestra ni se usa)'}`}
            </span>
            <button style={S.delBtn} onClick={() => eliminar(e)}>Eliminar</button>
          </div>
        </div>
      ))}

      <button style={S.addBtn(ocupado)} disabled={ocupado} onClick={() => anadir('Nueva información')}>
        + Añadir otra entrada
      </button>
    </div>
  )
}
