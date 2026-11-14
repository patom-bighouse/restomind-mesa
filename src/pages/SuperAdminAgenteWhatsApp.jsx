import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { ZONA_POR_DEFECTO, fechaHoraConLocal, inicioDiaEnZona, partesEnZona, sumarDiasISO } from '../lib/fechas'
import { COLUMNAS_AVISO, TIPOS_AVISO, telefonoAviso, textoAviso } from '../lib/avisosAgente'

// Panel de superadmin del agente de WhatsApp (entrega 1b, criterio 12 de
// docs/specs/2026-11-13-agente-whatsapp-revision.md): todos los avisos de
// todos los restaurantes y de cualquier fecha (también sin restaurante),
// filtros, detalle técnico y estadísticas de fn_superadmin_estadisticas_agente.
// Los días y las estadísticas son de España (regla 7, negocio de Restomind),
// con la zona como parámetro. Cada hora sale en España y, si el restaurante
// está en otra zona, con su hora local al lado (decisión 7 de
// docs/specs/2026-11-14-zona-horaria-restaurante.md).
const ZONA = ZONA_POR_DEFECTO
const POR_PAGINA = 200
const SIN_RESTAURANTE = '__sin__'

const S = {
  app: { minHeight: '100vh', background: '#0a0a0a', color: '#f0f0f0', fontFamily: "'Inter', sans-serif" },
  header: { background: '#111', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10, flexWrap: 'wrap', gap: 12 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  sub: { fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: '0.1em', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a8a8a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  linkBtn: { background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' },
  content: { padding: 24, maxWidth: 1200, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 6 },
  sectionHint: { fontSize: 12, color: '#666', marginBottom: 20, lineHeight: 1.5 },
  subTitle: { fontSize: 13, color: '#c4a85a', textTransform: 'uppercase', letterSpacing: '0.06em', margin: '28px 0 10px' },
  filtros: { display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-end', background: '#161616', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 14, marginBottom: 20 },
  field: { display: 'flex', flexDirection: 'column', gap: 4 },
  label: { fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: '0.05em' },
  select: { background: '#0a0a0a', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '7px 10px', fontSize: 13, color: '#f0f0f0', fontFamily: "'Inter', sans-serif" },
  btn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 8, padding: '8px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  btnSec: { background: 'transparent', color: '#e8c97a', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 12px', fontSize: 12, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: '0.06em', padding: '8px 10px', borderBottom: '0.5px solid #2a2a2a', whiteSpace: 'nowrap' },
  td: { padding: '9px 10px', fontSize: 13, borderBottom: '0.5px solid #1a1a1a', verticalAlign: 'top' },
  num: { padding: '9px 10px', fontSize: 13, borderBottom: '0.5px solid #1a1a1a', textAlign: 'right', fontVariantNumeric: 'tabular-nums' },
  fila: (abierta) => ({ background: abierta ? '#161616' : 'transparent', cursor: 'pointer' }),
  estado: (atendida) => ({ fontSize: 11, padding: '2px 8px', borderRadius: 20, border: `0.5px solid ${atendida ? '#2e6a3a' : '#6a2e20'}`, color: atendida ? '#7ae8a0' : '#e87a7a', whiteSpace: 'nowrap' }),
  detalle: { background: '#111', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: 12, margin: '4px 0 10px' },
  pre: { fontFamily: 'monospace', fontSize: 12, color: '#c8c8c8', whiteSpace: 'pre-wrap', wordBreak: 'break-word', margin: '6px 0 0', background: '#0a0a0a', borderRadius: 8, padding: 10 },
  statsGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 16 },
  statsCard: { background: '#161616', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 12, overflowX: 'auto' },
  statsTitulo: { fontSize: 12, color: '#c4a85a', marginBottom: 6 },
  barra: (pct) => ({ height: 6, borderRadius: 3, background: '#e8c97a', width: `${Math.max(2, pct)}%` }),
  error: { background: '#2a1414', border: '0.5px solid #5a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { padding: 16, color: '#666', fontSize: 13 },
}

export default function SuperAdminAgenteWhatsApp() {
  const navigate = useNavigate()
  const [listo, setListo] = useState(false)
  const [usuarioId, setUsuarioId] = useState(null)
  const [restaurantes, setRestaurantes] = useState({})
  const [avisos, setAvisos] = useState([])
  const [hayMas, setHayMas] = useState(false)
  const [stats, setStats] = useState([])
  const [cargando, setCargando] = useState(false)
  const [error, setError] = useState(null)
  const [abierto, setAbierto] = useState(null)
  const [detalles, setDetalles] = useState({}) // error_id → filas | 'cargando'
  const [marcando, setMarcando] = useState(null)
  const [vistaTiempo, setVistaTiempo] = useState('dia') // dia | semana
  const [aplicados, setAplicados] = useState({ desde: '', hasta: '', rest: '', tipo: '', atendida: '' })

  // Filtros: restaurante ('' todos, SIN_RESTAURANTE, id), tipo, atendida ('' | 'no' | 'si'), periodo (días de España).
  const [fRest, setFRest] = useState('')
  const [fTipo, setFTipo] = useState('')
  const [fAtendida, setFAtendida] = useState('')
  const [fDesde, setFDesde] = useState('')
  const [fHasta, setFHasta] = useState('')

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/superadmin/login'); return }
    const { data: sa } = await supabase.from('superadmins').select('id').eq('user_id', session.user.id).single()
    if (!sa) { navigate('/superadmin/login'); return }
    setUsuarioId(session.user.id)
    const { data: rs } = await supabase.from('restaurants').select('id, nombre, user_id, email_dueno, zona_horaria').order('nombre')
    setRestaurantes(Object.fromEntries((rs || []).map(r => [r.id, r])))
    setListo(true)
    await cargar({ desde: '', hasta: '', rest: '', tipo: '', atendida: '' }, 0)
  }

  function filtrosActuales() {
    return { desde: fDesde, hasta: fHasta, rest: fRest, tipo: fTipo, atendida: fAtendida }
  }

  async function cargar(f, desdeFila) {
    setError(null)
    if (f.desde && f.hasta && f.desde > f.hasta) { setError('La fecha "desde" es posterior a "hasta".'); return }
    setCargando(true)
    if (desdeFila === 0) setAplicados(f)
    let q = supabase.from('agente_errores').select(COLUMNAS_AVISO)
      .order('created_at', { ascending: false })
      .range(desdeFila, desdeFila + POR_PAGINA - 1)
    if (f.rest === SIN_RESTAURANTE) q = q.is('restaurant_id', null)
    else if (f.rest) q = q.eq('restaurant_id', f.rest)
    if (f.tipo) q = q.eq('tipo', f.tipo)
    if (f.atendida === 'si') q = q.eq('atendida', true)
    if (f.atendida === 'no') q = q.eq('atendida', false)
    if (f.desde) q = q.gte('created_at', inicioDiaEnZona(f.desde, ZONA).toISOString())
    if (f.hasta) q = q.lt('created_at', inicioDiaEnZona(sumarDiasISO(f.hasta, 1), ZONA).toISOString())

    const peticiones = [q]
    if (desdeFila === 0) {
      peticiones.push(supabase.rpc('fn_superadmin_estadisticas_agente', {
        p_desde: f.desde || null, p_hasta: f.hasta || null, p_zona: ZONA,
      }))
    }
    const [r, st] = await Promise.all(peticiones)
    setCargando(false)
    if (r.error) { setError(r.error.message); return }
    const filas = r.data || []
    setAvisos(prev => (desdeFila === 0 ? filas : [...prev, ...filas]))
    setHayMas(filas.length === POR_PAGINA)
    if (st) {
      if (st.error) setError('Estadísticas: ' + st.error.message)
      else setStats(st.data || [])
    }
  }

  function aplicar() {
    setAbierto(null)
    cargar(filtrosActuales(), 0)
  }

  function ultimosDias(n) {
    const hasta = partesEnZona(new Date(), ZONA).fecha
    const desde = sumarDiasISO(hasta, -(n - 1))
    setFDesde(desde); setFHasta(hasta)
    setAbierto(null)
    cargar({ ...filtrosActuales(), desde, hasta }, 0)
  }

  async function verDetalle(aviso) {
    if (abierto === aviso.id) { setAbierto(null); return }
    setAbierto(aviso.id)
    if (detalles[aviso.id]) return
    setDetalles(prev => ({ ...prev, [aviso.id]: 'cargando' }))
    const { data, error: err } = await supabase.from('agente_errores_detalle')
      .select('id, detalle, created_at').eq('error_id', aviso.id).order('created_at', { ascending: true })
    setDetalles(prev => ({ ...prev, [aviso.id]: err ? { error: err.message } : (data || []) }))
  }

  async function marcarAtendida(aviso) {
    setError(null)
    setMarcando(aviso.id)
    const { data, error: err } = await supabase.rpc('fn_agente_error_marcar_atendida', { p_error_id: aviso.id })
    setMarcando(null)
    if (err) { setError(err.message); return }
    const fila = data && data.id ? data : { ...aviso, atendida: true, atendida_por: usuarioId, atendida_at: new Date().toISOString() }
    setAvisos(prev => prev.map(a => a.id === aviso.id ? { ...a, ...fila } : a))
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/superadmin/login')
  }

  // Zona horaria del restaurante del aviso (null si no tiene restaurante:
  // entonces solo la hora de España).
  function zonaDe(a) {
    return (a?.restaurant_id && restaurantes[a.restaurant_id]?.zona_horaria) || null
  }
  // "22:00 (21:00 en el restaurante)" o solo la de España.
  function horaAviso(instante, a) {
    return fechaHoraConLocal(instante, zonaDe(a))
  }

  function nombreRest(id) {
    if (!id) return 'Sin restaurante'
    return restaurantes[id]?.nombre || id.slice(0, 8)
  }

  function quienMarco(a) {
    if (!a.atendida_por) return '—'
    if (a.atendida_por === usuarioId) return 'Tú'
    const r = restaurantes[a.restaurant_id]
    if (r && r.user_id === a.atendida_por) return `Dueño${r.email_dueno ? ` (${r.email_dueno})` : ''}`
    return 'Otro superadmin'
  }

  if (!listo) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  const statsDe = (agr) => stats.filter(s => s.agrupacion === agr)
  const total = statsDe('total')[0]
  const tablaStats = (titulo, filas, etiqueta) => {
    const max = Math.max(1, ...filas.map(f => Number(f.avisos)))
    return (
      <div style={S.statsCard}>
        <div style={S.statsTitulo}>{titulo}</div>
        {filas.length === 0 ? <div style={S.empty}>Sin avisos en el periodo.</div> : (
          <table style={S.table}>
            <thead><tr>
              <th style={S.th}></th><th style={{ ...S.th, textAlign: 'right' }}>Avisos</th>
              <th style={{ ...S.th, textAlign: 'right' }}>Veces</th><th style={{ ...S.th, textAlign: 'right' }}>Pendientes</th>
            </tr></thead>
            <tbody>
              {filas.map(f => (
                <tr key={f.clave}>
                  <td style={S.td}>
                    <div>{etiqueta(f)}</div>
                    <div style={S.barra((Number(f.avisos) / max) * 100)} />
                  </td>
                  <td style={S.num}>{f.avisos}</td>
                  <td style={S.num}>{f.veces}</td>
                  <td style={S.num}>{f.pendientes}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    )
  }
  const fechaCorta = (iso) => { const [a, m, d] = iso.split('-'); return `${d}/${m}/${a}` }
  const tiempo = statsDe(vistaTiempo).slice().sort((a, b) => b.clave.localeCompare(a.clave))

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.header}>
        <div>
          <div style={S.logo}><img src="/logos/opcion-2-monograma/icon-dark.svg" alt="" style={{ height: 22, verticalAlign: 'middle', marginRight: 8 }} />Restomind</div>
          <div style={S.sub}>Agente de WhatsApp</div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <a href="/superadmin/restaurantes" style={S.linkBtn}>← Restaurantes</a>
          <a href="/superadmin/planes" style={S.linkBtn}>Planes</a>
          <a href="/superadmin/crm" style={S.linkBtn}>CRM</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Avisos del agente de WhatsApp</div>
        <div style={S.sectionHint}>
          Todos los avisos de todos los restaurantes, también los que no tienen restaurante (firma no válida, número
          desconocido…) y los atendidos de cualquier fecha. Días y horas en hora de España. Pulsa una fila para ver el
          detalle técnico.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.filtros}>
          <div style={S.field}>
            <span style={S.label}>Restaurante</span>
            <select style={S.select} value={fRest} onChange={e => setFRest(e.target.value)}>
              <option value="">Todos</option>
              <option value={SIN_RESTAURANTE}>Sin restaurante</option>
              {Object.values(restaurantes).map(r => <option key={r.id} value={r.id}>{r.nombre}</option>)}
            </select>
          </div>
          <div style={S.field}>
            <span style={S.label}>Tipo</span>
            <select style={S.select} value={fTipo} onChange={e => setFTipo(e.target.value)}>
              <option value="">Todos</option>
              {Object.entries(TIPOS_AVISO).map(([k, t]) => <option key={k} value={k}>{t.etiqueta}{t.visible ? '' : ' (solo superadmin)'}</option>)}
            </select>
          </div>
          <div style={S.field}>
            <span style={S.label}>Estado</span>
            <select style={S.select} value={fAtendida} onChange={e => setFAtendida(e.target.value)}>
              <option value="">Todos</option>
              <option value="no">Pendientes</option>
              <option value="si">Atendidos</option>
            </select>
          </div>
          <div style={S.field}>
            <span style={S.label}>Desde</span>
            <input style={S.select} type="date" value={fDesde} onChange={e => setFDesde(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Hasta</span>
            <input style={S.select} type="date" value={fHasta} onChange={e => setFHasta(e.target.value)} />
          </div>
          <button style={S.btn} onClick={aplicar} disabled={cargando}>{cargando ? 'Cargando…' : 'Aplicar'}</button>
          <button style={S.btnSec} onClick={() => ultimosDias(7)}>7 días</button>
          <button style={S.btnSec} onClick={() => ultimosDias(30)}>30 días</button>
          <button style={S.btnSec} onClick={() => { setFDesde(''); setFHasta(''); setFRest(''); setFTipo(''); setFAtendida(''); setAbierto(null); cargar({ desde: '', hasta: '', rest: '', tipo: '', atendida: '' }, 0) }}>Quitar filtros</button>
        </div>

        <div style={S.subTitle}>
          Estadísticas {aplicados.desde || aplicados.hasta ? `del ${aplicados.desde ? fechaCorta(aplicados.desde) : 'principio'} al ${aplicados.hasta ? fechaCorta(aplicados.hasta) : 'hoy'}` : 'de todo el registro'}
          {total ? ` · ${total.avisos} avisos, ${total.veces} veces, ${total.pendientes} pendientes` : ''}
        </div>
        <div style={{ ...S.sectionHint, marginBottom: 10 }}>Las estadísticas son del periodo elegido, de todos los restaurantes y tipos.</div>
        <div style={S.statsGrid}>
          {tablaStats('Por tipo', statsDe('tipo'), f => TIPOS_AVISO[f.clave]?.etiqueta || f.clave)}
          {tablaStats('Por restaurante', statsDe('restaurante'), f => f.nombre)}
          <div>
            <div style={{ display: 'flex', gap: 6, marginBottom: 6 }}>
              <button style={vistaTiempo === 'dia' ? S.btn : S.btnSec} onClick={() => setVistaTiempo('dia')}>Por día</button>
              <button style={vistaTiempo === 'semana' ? S.btn : S.btnSec} onClick={() => setVistaTiempo('semana')}>Por semana</button>
            </div>
            {tablaStats(vistaTiempo === 'dia' ? 'Por día (hora de España)' : 'Por semana (desde el lunes)', tiempo,
              f => (vistaTiempo === 'semana' ? 'Semana del ' : '') + fechaCorta(f.clave))}
          </div>
        </div>

        <div style={S.subTitle}>Avisos ({avisos.length}{hayMas ? '+' : ''})</div>
        <div style={{ overflowX: 'auto' }}>
          <table style={S.table}>
            <thead><tr>
              <th style={S.th}>Fecha</th><th style={S.th}>Restaurante</th><th style={S.th}>Tipo</th>
              <th style={S.th}>Teléfono</th><th style={S.th}>Veces</th><th style={S.th}>Estado</th><th style={S.th}></th>
            </tr></thead>
            <tbody>
              {avisos.length === 0 && <tr><td style={S.td} colSpan={7}><div style={S.empty}>No hay avisos con estos filtros.</div></td></tr>}
              {avisos.map(a => {
                const tel = telefonoAviso(a.telefono_cliente)
                const det = detalles[a.id]
                return [
                  <tr key={a.id} style={S.fila(abierto === a.id)} onClick={() => verDetalle(a)}>
                    <td style={{ ...S.td, whiteSpace: 'nowrap' }}>{horaAviso(a.created_at, a)}</td>
                    <td style={S.td}>{nombreRest(a.restaurant_id)}</td>
                    <td style={S.td}>{TIPOS_AVISO[a.tipo]?.etiqueta || a.tipo}{a.visible_restaurante ? '' : <span style={{ color: '#666' }}> · no lo ve el restaurante</span>}</td>
                    <td style={S.td}>{tel ? <a href={tel.href} style={{ color: '#e8c97a' }} onClick={e => e.stopPropagation()}>{tel.texto}</a> : '—'}</td>
                    <td style={S.num}>{a.veces}</td>
                    <td style={S.td}>
                      <span style={S.estado(a.atendida)}>{a.atendida ? 'Atendido' : 'Pendiente'}</span>
                      {a.atendida && <div style={{ fontSize: 11, color: '#666', marginTop: 4 }}>{quienMarco(a)} · {horaAviso(a.atendida_at, a)}</div>}
                    </td>
                    <td style={S.td}>
                      {!a.atendida && (
                        <button style={S.btnSec} disabled={marcando === a.id} onClick={e => { e.stopPropagation(); marcarAtendida(a) }}>
                          {marcando === a.id ? 'Marcando…' : 'Marcar atendido'}
                        </button>
                      )}
                    </td>
                  </tr>,
                  abierto === a.id && (
                    <tr key={a.id + '-det'}>
                      <td colSpan={7} style={{ padding: '0 10px' }}>
                        <div style={S.detalle}>
                          <div style={{ fontSize: 13, marginBottom: 6 }}>{a.visible_restaurante ? textoAviso(a, zonaDe(a) || ZONA) : TIPOS_AVISO[a.tipo]?.texto}</div>
                          <div style={{ fontSize: 12, color: '#8a8a8a' }}>
                            Paso (nodo de n8n): <strong style={{ color: '#f0f0f0' }}>{a.paso || '—'}</strong>
                            {' · '}Primera vez: {horaAviso(a.created_at, a)}
                            {' · '}Última vez: {horaAviso(a.ultima_vez_at, a)}
                            {' · '}Id: <code>{a.id}</code>
                          </div>
                          {det === 'cargando' && <div style={S.empty}>Cargando detalle…</div>}
                          {det && det.error && <div style={S.error}>{det.error}</div>}
                          {Array.isArray(det) && det.length === 0 && <div style={S.empty}>Sin detalle técnico guardado.</div>}
                          {Array.isArray(det) && det.map(d => (
                            <div key={d.id} style={{ marginTop: 8 }}>
                              <div style={{ fontSize: 12, color: '#8a8a8a' }}>
                                {horaAviso(d.created_at, a)}
                                {d.detalle?.ejecucion ? <> · Ejecución de n8n: <code style={{ color: '#e8c97a' }}>{String(d.detalle.ejecucion)}</code></> : null}
                              </div>
                              {d.detalle?.error && <div style={{ fontSize: 13, color: '#e87a7a', marginTop: 4 }}>{String(d.detalle.error)}</div>}
                              <pre style={S.pre}>{JSON.stringify(d.detalle, null, 2)}</pre>
                            </div>
                          ))}
                        </div>
                      </td>
                    </tr>
                  ),
                ]
              })}
            </tbody>
          </table>
        </div>
        {hayMas && (
          <div style={{ marginTop: 14 }}>
            <button style={S.btnSec} disabled={cargando} onClick={() => cargar(aplicados, avisos.length)}>Cargar más</button>
          </div>
        )}
      </div>
    </div>
  )
}
