import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'
import { useRestaurantModulos } from '../lib/modulos'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  navTabs: { display: 'flex', gap: 8, flexWrap: 'wrap' },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  content: { padding: 24, maxWidth: 800, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 6 },
  sectionHint: { fontSize: 12, color: '#7a6a50', marginBottom: 20, lineHeight: 1.5 },
  addBar: { display: 'flex', gap: 12, marginBottom: 28, flexWrap: 'wrap', alignItems: 'flex-end', background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16 },
  field: { display: 'flex', flexDirection: 'column', gap: 4 },
  label: { fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em' },
  select: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', minWidth: 180 },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', flex: 1, minWidth: 200 },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 14px 10px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '14px', fontSize: 14, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  row: { background: '#1a1a1a' },
  arrow: { color: '#7a6a50', padding: '0 8px' },
  mensajeText: { fontSize: 12, color: '#8a7560', fontStyle: 'italic' },
  toggleBtn: (activa) => ({ background: 'transparent', border: `0.5px solid ${activa ? '#27ae60' : '#3a2e20'}`, borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: activa ? '#2ecc71' : '#666', fontFamily: "'Inter', sans-serif" }),
  deleteBtn: { background: 'transparent', border: 'none', color: '#8a5050', fontSize: 12, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'underline' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 60, color: '#555', fontSize: 14 },
}

export default function AdminUpsell() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [categories, setCategories] = useState([])
  const [items, setItems] = useState([])
  const [rules, setRules] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [triggerCat, setTriggerCat] = useState('')
  const [sugeridoItem, setSugeridoItem] = useState('')
  const [mensaje, setMensaje] = useState('')
  const [adding, setAdding] = useState(false)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('nombre, moneda').eq('id', restaurantId).single()
    setRestaurant(rest)
    await loadAll()
    setLoading(false)
  }

  async function loadAll() {
    const { data: cats } = await supabase
      .from('categories').select('id, nombre').eq('restaurant_id', restaurantId).eq('activa', true).order('orden')
    setCategories(cats || [])
    const { data: menuItems } = await supabase
      .from('menu_items').select('id, nombre, precio, category_id').eq('restaurant_id', restaurantId).order('nombre')
    setItems(menuItems || [])
    await loadRules()
  }

  async function loadRules() {
    const { data, error: err } = await supabase
      .from('upsell_rules')
      .select('id, trigger_categoria_id, sugerido_item_id, mensaje, activa')
      .eq('restaurant_id', restaurantId)
      .order('created_at', { ascending: false })
    if (err) { setError(err.message); return }
    setRules(data || [])
  }

  function nombreCategoria(id) { return categories.find(c => c.id === id)?.nombre || '—' }
  function nombreItem(id) { return items.find(i => i.id === id)?.nombre || '—' }

  async function addRule() {
    if (!triggerCat || !sugeridoItem) return
    setError(null)
    setAdding(true)
    const { error: err } = await supabase
      .from('upsell_rules')
      .insert({
        restaurant_id: restaurantId,
        trigger_categoria_id: triggerCat,
        sugerido_item_id: sugeridoItem,
        mensaje: mensaje.trim() || null,
      })
    setAdding(false)
    if (err) {
      setError(err.code === '23505' ? 'Ya existe esa regla (misma categoría y plato sugerido).' : err.message)
      return
    }
    setTriggerCat('')
    setSugeridoItem('')
    setMensaje('')
    await loadRules()
  }

  async function toggleRule(rule) {
    const { error: err } = await supabase.from('upsell_rules').update({ activa: !rule.activa }).eq('id', rule.id)
    if (err) { setError(err.message); return }
    setRules(prev => prev.map(r => r.id === rule.id ? { ...r, activa: !r.activa } : r))
  }

  async function deleteRule(rule) {
    if (!window.confirm(`¿Eliminar la regla "${nombreCategoria(rule.trigger_categoria_id)} → ${nombreItem(rule.sugerido_item_id)}"?`)) return
    const { error: err } = await supabase.from('upsell_rules').delete().eq('id', rule.id)
    if (err) { setError(err.message); return }
    setRules(prev => prev.filter(r => r.id !== rule.id))
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
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(true)}>Upsell</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Sugerencias automáticas</div>
        <div style={S.sectionHint}>
          Cuando el cliente agrega un plato de la categoría disparadora a su pedido, le aparece una sugerencia
          para sumar el plato elegido con un toque — en la carta de Mesa y en la pantalla del camarero.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.addBar}>
          <div style={S.field}>
            <span style={S.label}>Si agrega de...</span>
            <select style={S.select} value={triggerCat} onChange={e => setTriggerCat(e.target.value)}>
              <option value="">Elegí una categoría</option>
              {categories.map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}
            </select>
          </div>
          <div style={S.field}>
            <span style={S.label}>Sugerir</span>
            <select style={S.select} value={sugeridoItem} onChange={e => setSugeridoItem(e.target.value)}>
              <option value="">Elegí un plato</option>
              {items.map(i => <option key={i.id} value={i.id}>{i.nombre}</option>)}
            </select>
          </div>
          <div style={{ ...S.field, flex: 1 }}>
            <span style={S.label}>Mensaje (opcional)</span>
            <input
              style={S.input}
              placeholder='Ej. "¿Le sumamos un café con el postre?"'
              value={mensaje}
              onChange={e => setMensaje(e.target.value)}
            />
          </div>
          <button style={S.addBtn} onClick={addRule} disabled={adding || !triggerCat || !sugeridoItem}>
            {adding ? 'Añadiendo...' : '+ Añadir regla'}
          </button>
        </div>

        {rules.length === 0 ? (
          <div style={S.empty}>Todavía no configuraste ninguna regla de sugerencia.</div>
        ) : (
          <table style={S.table}>
            <thead>
              <tr>
                <th style={S.th}>Regla</th>
                <th style={S.th}>Mensaje</th>
                <th style={S.th}></th>
              </tr>
            </thead>
            <tbody>
              {rules.map(r => (
                <tr key={r.id} style={{ ...S.row, opacity: r.activa ? 1 : 0.5 }}>
                  <td style={S.td}>
                    {nombreCategoria(r.trigger_categoria_id)}
                    <span style={S.arrow}>→</span>
                    {nombreItem(r.sugerido_item_id)}
                    {' '}
                    <span style={{ color: '#7a6a50', fontSize: 12 }}>
                      ({formatMoney(items.find(i => i.id === r.sugerido_item_id)?.precio, restaurant?.moneda)})
                    </span>
                  </td>
                  <td style={S.td}>
                    {r.mensaje ? <span style={S.mensajeText}>"{r.mensaje}"</span> : <span style={{ color: '#555' }}>—</span>}
                  </td>
                  <td style={{ ...S.td, display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
                    <button style={S.toggleBtn(r.activa)} onClick={() => toggleRule(r)}>
                      {r.activa ? 'Activa' : 'Inactiva'}
                    </button>
                    <button style={S.deleteBtn} onClick={() => deleteRule(r)}>Eliminar</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
