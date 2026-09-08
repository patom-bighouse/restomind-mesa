import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useRestaurantModulos } from '../lib/modulos'

const EVENTOS = [
  { key: 'order.placed', label: 'Pedido nuevo' },
  { key: 'payment.received', label: 'Pago recibido' },
  { key: 'reservation.created', label: 'Reserva creada' },
  { key: 'waiter.call', label: 'Llamada al camarero' },
]

function generarSecreto() {
  const bytes = crypto.getRandomValues(new Uint8Array(24))
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')
}

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  navTabs: { display: 'flex', gap: 8, flexWrap: 'wrap' },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  content: { padding: 24, maxWidth: 900, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 6 },
  sectionHint: { fontSize: 12, color: '#7a6a50', marginBottom: 20, lineHeight: 1.5 },
  card: { background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16, marginBottom: 20 },
  field: { display: 'flex', flexDirection: 'column', gap: 4, marginBottom: 14 },
  label: { fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em' },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  checkboxRow: { display: 'flex', flexWrap: 'wrap', gap: 12 },
  checkboxLabel: { display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, color: '#d8cbb0', cursor: 'pointer' },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  secretBox: { background: '#111', border: '0.5px solid #e8c97a', borderRadius: 10, padding: '10px 14px', fontSize: 13, fontFamily: 'monospace', color: '#e8c97a', wordBreak: 'break-all', marginTop: 10 },
  webhookRow: { background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16, marginBottom: 14 },
  url: { fontSize: 14, color: '#f0e8d8', fontWeight: 500, wordBreak: 'break-all' },
  chip: (color) => ({ fontSize: 11, color, background: '#111', border: `0.5px solid ${color}`, borderRadius: 20, padding: '3px 10px', marginRight: 6, display: 'inline-block', marginTop: 6 }),
  rowActions: { display: 'flex', gap: 8, marginTop: 12 },
  toggleBtn: (activo) => ({ background: 'transparent', border: `0.5px solid ${activo ? '#27ae60' : '#3a2e20'}`, borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: activo ? '#2ecc71' : '#666', fontFamily: "'Inter', sans-serif" }),
  deleteBtn: { background: 'transparent', border: '0.5px solid #6a2e20', borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: '#e87a7a', fontFamily: "'Inter', sans-serif" },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 14px 10px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '10px 14px', fontSize: 13, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 40, color: '#555', fontSize: 14 },
}

export default function AdminWebhooks() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo, loading: modulosLoading } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [webhooks, setWebhooks] = useState([])
  const [entregas, setEntregas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const [url, setUrl] = useState('')
  const [eventosSel, setEventosSel] = useState([])
  const [adding, setAdding] = useState(false)
  const [secretoNuevo, setSecretoNuevo] = useState(null)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('nombre').eq('id', restaurantId).single()
    setRestaurant(rest)
    await loadWebhooks()
    setLoading(false)
  }

  async function loadWebhooks() {
    const { data, error: err } = await supabase
      .from('webhooks')
      .select('id, url, eventos, activo, secreto, created_at')
      .eq('restaurant_id', restaurantId)
      .order('created_at', { ascending: false })
    if (err) { setError(err.message); return }
    setWebhooks(data || [])
    const ids = (data || []).map(w => w.id)
    if (ids.length > 0) {
      const { data: log } = await supabase
        .from('webhook_entregas')
        .select('id, webhook_id, evento, created_at')
        .in('webhook_id', ids)
        .order('created_at', { ascending: false })
        .limit(30)
      setEntregas(log || [])
    } else {
      setEntregas([])
    }
  }

  function toggleEvento(key) {
    setEventosSel(prev => prev.includes(key) ? prev.filter(e => e !== key) : [...prev, key])
  }

  async function addWebhook() {
    if (!url.trim() || !/^https?:\/\/.+/.test(url.trim())) { setError('Indica una URL válida (http:// o https://).'); return }
    if (eventosSel.length === 0) { setError('Selecciona al menos un evento.'); return }
    setError(null)
    setAdding(true)
    const secreto = generarSecreto()
    const { error: err } = await supabase
      .from('webhooks')
      .insert({ restaurant_id: restaurantId, url: url.trim(), eventos: eventosSel, secreto })
    setAdding(false)
    if (err) { setError(err.message); return }
    setSecretoNuevo(secreto)
    setUrl(''); setEventosSel([])
    await loadWebhooks()
  }

  async function toggleWebhook(w) {
    const { error: err } = await supabase.from('webhooks').update({ activo: !w.activo }).eq('id', w.id)
    if (err) { setError(err.message); return }
    setWebhooks(prev => prev.map(x => x.id === w.id ? { ...x, activo: !x.activo } : x))
  }

  async function eliminarWebhook(w) {
    if (!confirm(`¿Eliminar el webhook hacia ${w.url}? Dejará de recibir notificaciones.`)) return
    const { error: err } = await supabase.from('webhooks').delete().eq('id', w.id)
    if (err) { setError(err.message); return }
    await loadWebhooks()
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  if (loading || modulosLoading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  if (!tieneModulo('webhooks')) {
    return (
      <div style={S.app}>
        <div style={S.header}>
          <div>
            <div style={S.logo}>Restomind Admin</div>
            <div style={S.restName}>{restaurant?.nombre}</div>
          </div>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
        <div style={S.content}>
          <div style={S.sectionTitle}>Webhooks</div>
          <div style={S.sectionHint}>Este restaurante no tiene activo el módulo de webhooks.</div>
        </div>
      </div>
    )
  }

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
          <a href={`/admin/menus/${restaurantId}`} style={S.navTab(false)}>Menús</a>
          {tieneModulo('control_stock') && <a href={`/admin/stock/${restaurantId}`} style={S.navTab(false)}>Stock</a>}
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(false)}>Clientes</a>
          <a href={`/admin/vales/${restaurantId}`} style={S.navTab(false)}>Vales</a>
          <a href={`/admin/webhooks/${restaurantId}`} style={S.navTab(true)}>Webhooks</a>
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>
          <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(false)}>Reservas</a>
          <a href={`/admin/limpieza/${restaurantId}`} style={S.navTab(false)}>Limpieza</a>
          <a href={`/admin/fidelizacion/${restaurantId}`} style={S.navTab(false)}>Fidelización</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Webhooks</div>
        <div style={S.sectionHint}>
          Recibe un aviso en tu propia URL (Zapier, Make, tu ERP, un canal de Slack...) cada vez que
          pasa algo en tu restaurante. Cada envío incluye una firma HMAC-SHA256 en la cabecera
          <code style={{ color: '#e8c97a' }}> X-Restomind-Signature</code> para que puedas verificar que viene de Restomind.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.card}>
          <div style={S.field}>
            <span style={S.label}>URL de destino</span>
            <input style={S.input} placeholder="https://..." value={url} onChange={e => setUrl(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Eventos a notificar</span>
            <div style={S.checkboxRow}>
              {EVENTOS.map(ev => (
                <label key={ev.key} style={S.checkboxLabel}>
                  <input type="checkbox" checked={eventosSel.includes(ev.key)} onChange={() => toggleEvento(ev.key)} />
                  {ev.label}
                </label>
              ))}
            </div>
          </div>
          <button style={S.addBtn} onClick={addWebhook} disabled={adding}>
            {adding ? 'Creando...' : '+ Crear webhook'}
          </button>
          {secretoNuevo && (
            <div style={S.secretBox}>
              Secreto (guárdalo, no se volverá a mostrar): {secretoNuevo}
            </div>
          )}
        </div>

        {webhooks.length === 0 ? (
          <div style={S.empty}>Todavía no configuraste ningún webhook.</div>
        ) : (
          webhooks.map(w => (
            <div key={w.id} style={{ ...S.webhookRow, opacity: w.activo ? 1 : 0.5 }}>
              <div style={S.url}>{w.url}</div>
              <div>
                {w.eventos.map(ek => (
                  <span key={ek} style={S.chip('#8a7560')}>{EVENTOS.find(e => e.key === ek)?.label || ek}</span>
                ))}
              </div>
              <div style={S.rowActions}>
                <button style={S.toggleBtn(w.activo)} onClick={() => toggleWebhook(w)}>
                  {w.activo ? 'Desactivar' : 'Reactivar'}
                </button>
                <button style={S.deleteBtn} onClick={() => eliminarWebhook(w)}>Eliminar</button>
              </div>
            </div>
          ))
        )}

        {entregas.length > 0 && (
          <>
            <div style={{ ...S.sectionTitle, marginTop: 32, fontSize: 15 }}>Últimos envíos</div>
            <div style={{ ...S.sectionHint, marginBottom: 12 }}>
              Registro de los intentos de envío realizados. No refleja si el destino respondió
              correctamente — para comprobar la entrega real, revisa del lado receptor.
            </div>
            <table style={S.table}>
              <thead>
                <tr>
                  <th style={S.th}>Fecha</th>
                  <th style={S.th}>Evento</th>
                  <th style={S.th}>Destino</th>
                </tr>
              </thead>
              <tbody>
                {entregas.map(e => (
                  <tr key={e.id}>
                    <td style={S.td}>{new Date(e.created_at).toLocaleString('es-ES')}</td>
                    <td style={S.td}>{EVENTOS.find(ev => ev.key === e.evento)?.label || e.evento}</td>
                    <td style={S.td}>{webhooks.find(w => w.id === e.webhook_id)?.url || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </>
        )}
      </div>
    </div>
  )
}
