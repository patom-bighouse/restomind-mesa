import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

const S = {
  app: { minHeight: '100vh', background: '#0a0a0a', color: '#f0f0f0', fontFamily: "'Inter', sans-serif" },
  header: { background: '#111', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  sub: { fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: '0.1em', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a8a8a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  linkBtn: { background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' },
  content: { padding: 24, maxWidth: 900, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 6 },
  sectionHint: { fontSize: 12, color: '#666', marginBottom: 20, lineHeight: 1.5 },
  error: { background: '#2a1414', border: '0.5px solid #5a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },

  planesRow: { display: 'flex', gap: 14, marginBottom: 28, flexWrap: 'wrap' },
  planCard: { flex: '1 1 220px', background: '#161616', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16 },
  planNombre: { fontFamily: "'Playfair Display', serif", fontSize: 15, color: '#e8c97a', marginBottom: 6 },
  planPrecio: { fontSize: 20, fontWeight: 600, color: '#f0f0f0', marginBottom: 6 },
  planDesc: { fontSize: 12, color: '#8a8a8a', lineHeight: 1.5 },

  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: '0.06em', padding: '10px 14px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '12px 14px', fontSize: 13, borderBottom: '0.5px solid #1a1a1a', verticalAlign: 'middle' },
  moduloNombre: { fontWeight: 500, color: '#f0f0f0' },
  moduloDesc: { fontSize: 11, color: '#666', marginTop: 2, maxWidth: 360 },
  input: { width: '100%', boxSizing: 'border-box', background: '#0a0a0a', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 10px', fontSize: 13, color: '#f0f0f0', fontFamily: "'Inter', sans-serif" },
  guardado: { fontSize: 11, color: '#7ae8a0', marginTop: 6, minHeight: 14 },
  select: { background: '#0a0a0a', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 10px', fontSize: 13, color: '#f0f0f0', fontFamily: "'Inter', sans-serif" },
}

export default function SuperAdminPlanes() {
  const navigate = useNavigate()
  const [planes, setPlanes] = useState([])
  const [modulos, setModulos] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [guardandoKey, setGuardandoKey] = useState(null)
  // Lo que se está escribiendo en cada tarjeta: { [key]: { nombre, descripcion, precio } }
  const [edicion, setEdicion] = useState({})
  const [estadoPlan, setEstadoPlan] = useState({}) // key → 'guardando' | 'guardado'

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/superadmin/login'); return }
    const { data: sa } = await supabase.from('superadmins').select('id').eq('user_id', session.user.id).single()
    if (!sa) { navigate('/superadmin/login'); return }
    await loadTodo()
  }

  async function loadTodo() {
    const [{ data: pl }, { data: mo }] = await Promise.all([
      supabase.from('planes').select('key, nombre, descripcion, orden, precio').order('orden'),
      supabase.from('modulos').select('key, nombre, descripcion, requiere, plan').order('orden'),
    ])
    setPlanes(pl || [])
    setEdicion(Object.fromEntries((pl || []).map(p => [p.key, {
      nombre: p.nombre || '', descripcion: p.descripcion || '', precio: p.precio != null ? String(p.precio) : '',
    }])))
    setModulos(mo || [])
    setLoading(false)
  }

  async function cambiarPlanModulo(moduloKey, nuevoPlan) {
    setGuardandoKey(moduloKey)
    setError(null)
    setModulos(prev => prev.map(m => m.key === moduloKey ? { ...m, plan: nuevoPlan } : m))
    const { error: err } = await supabase.rpc('fn_asignar_modulo_a_plan', {
      p_modulo_key: moduloKey, p_plan_key: nuevoPlan,
    })
    setGuardandoKey(null)
    if (err) { setError(err.message); await loadTodo(); return }
  }

  function editar(key, campo, valor) {
    setEdicion(prev => ({ ...prev, [key]: { ...prev[key], [campo]: valor } }))
  }

  // Se guarda al salir del campo, solo si ha cambiado. El precio nuevo vale
  // para los restaurantes que se den de alta desde ahora: los que ya tienen
  // el plan conservan su precio de contrato.
  async function guardarPlan(key, campo) {
    const plan = planes.find(p => p.key === key)
    const valor = edicion[key]?.[campo] ?? ''
    let nuevo
    if (campo === 'precio') {
      if (valor.trim() === '') nuevo = null
      else {
        nuevo = Math.round(parseFloat(valor.replace(',', '.')) * 100) / 100
        if (isNaN(nuevo) || nuevo < 0) { setError('Indica un precio válido.'); editar(key, 'precio', plan.precio != null ? String(plan.precio) : ''); return }
      }
      if (nuevo === (plan.precio != null ? Number(plan.precio) : null)) return
    } else {
      nuevo = valor.trim()
      if (campo === 'nombre' && !nuevo) { setError('El plan necesita un nombre.'); editar(key, 'nombre', plan.nombre); return }
      if (nuevo === (plan[campo] || '')) return
      if (campo === 'descripcion' && !nuevo) nuevo = null
    }
    setError(null)
    setEstadoPlan(prev => ({ ...prev, [key]: 'guardando' }))
    const { error: err } = await supabase.from('planes').update({ [campo]: nuevo }).eq('key', key)
    if (err) { setError(err.message); setEstadoPlan(prev => ({ ...prev, [key]: null })); await loadTodo(); return }
    setPlanes(prev => prev.map(p => p.key === key ? { ...p, [campo]: nuevo } : p))
    setEstadoPlan(prev => ({ ...prev, [key]: 'guardado' }))
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
          <div style={S.sub}>Planes de suscripción</div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <a href="/superadmin/restaurantes" style={S.linkBtn}>← Restaurantes</a>
          <a href="/superadmin/crm" style={S.linkBtn}>CRM</a>
          <a href="/superadmin/agente-whatsapp" style={S.linkBtn}>Agente WhatsApp</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Planes</div>
        <div style={S.sectionHint}>
          Cada módulo pertenece a un plan. Los planes son acumulativos — Premium incluye todo lo de
          Profesional y Básico también. Cambiar el plan de un módulo aquí no afecta a los restaurantes que
          ya lo tienen activado o desactivado — solo define a partir de qué plan se incluye de ahí en adelante.
        </div>
        <div style={S.sectionHint}>
          Nombre, precio y descripción se guardan al salir del campo y son los que ve la web pública. Un precio nuevo
          vale para los restaurantes que se den de alta a partir de ahora: los que ya tienen el plan conservan su precio
          de contrato, que se cambia desde su ficha en Restaurantes.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.planesRow}>
          {planes.map(p => {
            const e = edicion[p.key] || {}
            return (
              <div key={p.key} style={S.planCard}>
                <input style={{ ...S.input, ...S.planNombre, padding: '4px 8px' }} value={e.nombre ?? ''}
                  onChange={ev => editar(p.key, 'nombre', ev.target.value)} onBlur={() => guardarPlan(p.key, 'nombre')} />
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 6 }}>
                  <input style={{ ...S.input, ...S.planPrecio, width: 110, marginBottom: 0, padding: '4px 8px' }} type="number" min="0" step="0.01"
                    value={e.precio ?? ''} placeholder="—"
                    onChange={ev => editar(p.key, 'precio', ev.target.value)} onBlur={() => guardarPlan(p.key, 'precio')} />
                  <span style={{ fontSize: 12, color: '#8a8a8a' }}>€/mes</span>
                </div>
                <textarea style={{ ...S.input, ...S.planDesc, resize: 'vertical', minHeight: 64 }} value={e.descripcion ?? ''}
                  onChange={ev => editar(p.key, 'descripcion', ev.target.value)} onBlur={() => guardarPlan(p.key, 'descripcion')} />
                <div style={S.guardado}>{estadoPlan[p.key] === 'guardando' ? 'Guardando...' : estadoPlan[p.key] === 'guardado' ? 'Guardado ✓' : ''}</div>
              </div>
            )
          })}
        </div>

        <div style={{ ...S.sectionTitle, fontSize: 15 }}>Módulos</div>
        <table style={S.table}>
          <thead>
            <tr>
              <th style={S.th}>Módulo</th>
              <th style={S.th}>Plan</th>
            </tr>
          </thead>
          <tbody>
            {modulos.map(m => (
              <tr key={m.key}>
                <td style={S.td}>
                  <div style={S.moduloNombre}>{m.nombre}</div>
                  <div style={S.moduloDesc}>{m.descripcion}</div>
                </td>
                <td style={S.td}>
                  <select
                    style={S.select}
                    value={m.plan || ''}
                    disabled={m.key === 'nucleo' || guardandoKey === m.key}
                    onChange={e => cambiarPlanModulo(m.key, e.target.value)}
                  >
                    {planes.map(p => <option key={p.key} value={p.key}>{p.nombre}</option>)}
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
