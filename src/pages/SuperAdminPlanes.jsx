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
  planDesc: { fontSize: 12, color: '#8a8a8a', lineHeight: 1.5 },

  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: '0.06em', padding: '10px 14px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '12px 14px', fontSize: 13, borderBottom: '0.5px solid #1a1a1a', verticalAlign: 'middle' },
  moduloNombre: { fontWeight: 500, color: '#f0f0f0' },
  moduloDesc: { fontSize: 11, color: '#666', marginTop: 2, maxWidth: 360 },
  select: { background: '#0a0a0a', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 10px', fontSize: 13, color: '#f0f0f0', fontFamily: "'Inter', sans-serif" },
}

export default function SuperAdminPlanes() {
  const navigate = useNavigate()
  const [planes, setPlanes] = useState([])
  const [modulos, setModulos] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [guardandoKey, setGuardandoKey] = useState(null)

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
      supabase.from('planes').select('key, nombre, descripcion, orden').order('orden'),
      supabase.from('modulos').select('key, nombre, descripcion, requiere, plan').order('orden'),
    ])
    setPlanes(pl || [])
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
          <div style={S.logo}>Restomind</div>
          <div style={S.sub}>Planes de suscripción</div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <a href="/superadmin/restaurantes" style={S.linkBtn}>← Restaurantes</a>
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

        {error && <div style={S.error}>{error}</div>}

        <div style={S.planesRow}>
          {planes.map(p => (
            <div key={p.key} style={S.planCard}>
              <div style={S.planNombre}>{p.nombre}</div>
              <div style={S.planDesc}>{p.descripcion}</div>
            </div>
          ))}
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
