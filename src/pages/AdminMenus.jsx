import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/money'
import { useRestaurantModulos } from '../lib/modulos'

const ZONAS = ['interior', 'terraza', 'privado', 'barra']

// Mismo criterio que Date.getDay() en JS: 0=domingo...6=sábado.
const DIAS = [
  { v: 1, l: 'L' }, { v: 2, l: 'M' }, { v: 3, l: 'X' }, { v: 4, l: 'J' },
  { v: 5, l: 'V' }, { v: 6, l: 'S' }, { v: 0, l: 'D' },
]

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
  addBar: { display: 'flex', gap: 12, marginBottom: 28, flexWrap: 'wrap', alignItems: 'flex-end', background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16 },
  field: { display: 'flex', flexDirection: 'column', gap: 4 },
  label: { fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em' },
  select: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', minWidth: 150 },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', flex: 1, minWidth: 160 },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 14px 10px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '14px', fontSize: 14, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  row: { background: '#1a1a1a' },
  chip: { fontSize: 11, color: '#8a7560', background: '#111', border: '0.5px solid #3a2e20', borderRadius: 20, padding: '3px 10px', marginRight: 6 },
  diaChip: (active) => ({ width: 30, height: 30, borderRadius: '50%', background: active ? '#e8c97a' : '#111', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, fontSize: 12, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }),
  toggleBtn: (activo) => ({ background: 'transparent', border: `0.5px solid ${activo ? '#27ae60' : '#3a2e20'}`, borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: activo ? '#2ecc71' : '#666', fontFamily: "'Inter', sans-serif" }),
  editBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: '#c4a85a', fontFamily: "'Inter', sans-serif" },
  deleteBtn: { background: 'transparent', border: 'none', color: '#8a5050', fontSize: 12, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'underline' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 60, color: '#555', fontSize: 14 },

  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 20 },
  sheet: { background: '#141414', width: '100%', maxWidth: 640, maxHeight: '85vh', overflowY: 'auto', borderRadius: 16, padding: 24 },
  sheetTitle: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 4 },
  sheetHint: { fontSize: 12, color: '#7a6a50', marginBottom: 18, lineHeight: 1.5 },
  catTitle: { fontSize: 12, fontWeight: 600, color: '#c4a85a', textTransform: 'uppercase', letterSpacing: 0.5, margin: '18px 0 8px' },
  itemRow: { display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderBottom: '0.5px solid #222' },
  itemNombre: { flex: 1, fontSize: 14, color: '#f0e8d8' },
  itemBase: { fontSize: 12, color: '#7a6a50', width: 70, textAlign: 'right' },
  precioInput: { width: 80, background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 8px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  excluirLabel: { display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, color: '#8a7560', whiteSpace: 'nowrap' },
  sheetFooter: { display: 'flex', gap: 10, marginTop: 20 },
  saveBtn: (busy) => ({ flex: 1, background: busy ? '#5a4a2a' : '#e8c97a', color: busy ? '#8a7560' : '#111', border: 'none', borderRadius: 10, padding: '12px', fontSize: 14, fontWeight: 500, cursor: busy ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
  cancelBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '12px 20px', fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
}

export default function AdminMenus() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [categories, setCategories] = useState([])
  const [items, setItems] = useState([])
  const [menus, setMenus] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const [nombre, setNombre] = useState('')
  const [zona, setZona] = useState('')
  const [horaInicio, setHoraInicio] = useState('')
  const [horaFin, setHoraFin] = useState('')
  const [diasSemana, setDiasSemana] = useState([])
  const [adding, setAdding] = useState(false)
  const [editingMenuId, setEditingMenuId] = useState(null) // null = alta nueva

  const [editingMenu, setEditingMenu] = useState(null) // menu | null
  const [editValues, setEditValues] = useState({}) // menu_item_id -> { precio: string, excluido: bool }
  const [guardando, setGuardando] = useState(false)

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
      .from('menu_items').select('id, nombre, precio, category_id').eq('restaurant_id', restaurantId).order('orden')
    setItems(menuItems || [])
    await loadMenus()
  }

  async function loadMenus() {
    const { data, error: err } = await supabase
      .from('menus')
      .select('id, nombre, zona, hora_inicio, hora_fin, dias_semana, activo, orden')
      .eq('restaurant_id', restaurantId)
      .order('orden')
    if (err) { setError(err.message); return }
    setMenus(data || [])
  }

  function franjaLabel(m) {
    if (!m.hora_inicio || !m.hora_fin) return null
    return `${m.hora_inicio.slice(0, 5)}–${m.hora_fin.slice(0, 5)}`
  }

  function diasLabel(m) {
    if (!m.dias_semana || m.dias_semana.length === 0) return null
    return DIAS.filter(d => m.dias_semana.includes(d.v)).map(d => d.l).join(' ')
  }

  function toggleDia(v) {
    setDiasSemana(prev => prev.includes(v) ? prev.filter(d => d !== v) : [...prev, v])
  }

  function editarMenu(menu) {
    setEditingMenuId(menu.id)
    setNombre(menu.nombre)
    setZona(menu.zona || '')
    setHoraInicio(menu.hora_inicio ? menu.hora_inicio.slice(0, 5) : '')
    setHoraFin(menu.hora_fin ? menu.hora_fin.slice(0, 5) : '')
    setDiasSemana(menu.dias_semana || [])
  }

  function cancelarEdicion() {
    setEditingMenuId(null)
    setNombre(''); setZona(''); setHoraInicio(''); setHoraFin(''); setDiasSemana([])
  }

  async function guardarMenu() {
    if (!nombre.trim()) return
    setError(null)
    setAdding(true)
    const payload = {
      nombre: nombre.trim(),
      zona: zona || null,
      hora_inicio: horaInicio || null,
      hora_fin: horaFin || null,
      dias_semana: diasSemana.length ? diasSemana : null,
    }
    const { error: err } = editingMenuId
      ? await supabase.from('menus').update(payload).eq('id', editingMenuId)
      : await supabase.from('menus').insert({ restaurant_id: restaurantId, ...payload })
    setAdding(false)
    if (err) { setError(err.message); return }
    setEditingMenuId(null)
    setNombre(''); setZona(''); setHoraInicio(''); setHoraFin(''); setDiasSemana([])
    await loadMenus()
  }

  async function toggleMenu(menu) {
    const { error: err } = await supabase.from('menus').update({ activo: !menu.activo }).eq('id', menu.id)
    if (err) { setError(err.message); return }
    setMenus(prev => prev.map(m => m.id === menu.id ? { ...m, activo: !m.activo } : m))
  }

  async function deleteMenu(menu) {
    if (!window.confirm(`¿Eliminar el menú "${menu.nombre}"? Los platos vuelven a su precio de carta normal.`)) return
    const { error: err } = await supabase.from('menus').delete().eq('id', menu.id)
    if (err) { setError(err.message); return }
    setMenus(prev => prev.filter(m => m.id !== menu.id))
  }

  async function abrirEditorPrecios(menu) {
    setError(null)
    const { data, error: err } = await supabase
      .from('menu_item_precios_menu')
      .select('menu_item_id, precio, excluido')
      .eq('menu_id', menu.id)
    if (err) { setError(err.message); return }
    const values = {}
    ;(data || []).forEach(row => {
      values[row.menu_item_id] = { precio: row.precio != null ? String(row.precio) : '', excluido: row.excluido }
    })
    setEditValues(values)
    setEditingMenu(menu)
  }

  function setValorItem(itemId, patch) {
    setEditValues(prev => ({
      ...prev,
      [itemId]: { precio: prev[itemId]?.precio ?? '', excluido: prev[itemId]?.excluido ?? false, ...patch },
    }))
  }

  async function guardarPrecios() {
    setGuardando(true)
    setError(null)
    const filas = Object.entries(editValues)
      .filter(([, v]) => v.excluido || (v.precio !== '' && !isNaN(parseFloat(v.precio))))
      .map(([itemId, v]) => ({
        menu_id: editingMenu.id,
        menu_item_id: itemId,
        precio: v.excluido ? null : parseFloat(v.precio),
        excluido: v.excluido,
      }))
    const { error: delErr } = await supabase.from('menu_item_precios_menu').delete().eq('menu_id', editingMenu.id)
    if (delErr) { setError(delErr.message); setGuardando(false); return }
    if (filas.length) {
      const { error: insErr } = await supabase.from('menu_item_precios_menu').insert(filas)
      if (insErr) { setError(insErr.message); setGuardando(false); return }
    }
    setGuardando(false)
    setEditingMenu(null)
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
          <a href={`/admin/menus/${restaurantId}`} style={S.navTab(true)}>Menús</a>
          {tieneModulo('control_stock') && <a href={`/admin/stock/${restaurantId}`} style={S.navTab(false)}>Stock</a>}
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(false)}>Clientes</a>
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>
          <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(false)}>Reservas</a>
          <a href={`/admin/limpieza/${restaurantId}`} style={S.navTab(false)}>Limpieza</a>
          <a href={`/admin/fidelizacion/${restaurantId}`} style={S.navTab(false)}>Fidelización</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Menús</div>
        <div style={S.sectionHint}>
          Cada plato vive una sola vez en tu carta. Aquí puedes crear menús con precios distintos para algunos
          platos (o excluirlos) según la zona de la mesa y la hora — por ejemplo "Terraza" con precios más altos,
          o "Mediodía" de 12:00 a 16:00. Sin ningún menú activo para la mesa y la hora, se usa siempre la carta
          normal.
        </div>

        {error && <div style={S.error}>{error}</div>}

        <div style={S.addBar}>
          <div style={{ ...S.field, flex: 1 }}>
            <span style={S.label}>Nombre</span>
            <input style={S.input} placeholder="Ej. Terraza, Mediodía..." value={nombre} onChange={e => setNombre(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Zona</span>
            <select style={S.select} value={zona} onChange={e => setZona(e.target.value)}>
              <option value="">Cualquiera</option>
              {ZONAS.map(z => <option key={z} value={z}>{z.charAt(0).toUpperCase() + z.slice(1)}</option>)}
            </select>
          </div>
          <div style={S.field}>
            <span style={S.label}>Desde</span>
            <input style={S.select} type="time" value={horaInicio} onChange={e => setHoraInicio(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Hasta</span>
            <input style={S.select} type="time" value={horaFin} onChange={e => setHoraFin(e.target.value)} />
          </div>
          <div style={S.field}>
            <span style={S.label}>Días (vacío = todos)</span>
            <div style={{ display: 'flex', gap: 4 }}>
              {DIAS.map(d => (
                <button key={d.v} type="button" style={S.diaChip(diasSemana.includes(d.v))} onClick={() => toggleDia(d.v)}>
                  {d.l}
                </button>
              ))}
            </div>
          </div>
          <button style={S.addBtn} onClick={guardarMenu} disabled={adding || !nombre.trim()}>
            {adding ? 'Guardando...' : editingMenuId ? 'Guardar cambios' : '+ Añadir menú'}
          </button>
          {editingMenuId && (
            <button style={S.cancelBtn} onClick={cancelarEdicion}>Cancelar</button>
          )}
        </div>

        {menus.length === 0 ? (
          <div style={S.empty}>Todavía no configuraste ningún menú adicional.</div>
        ) : (
          <table style={S.table}>
            <thead>
              <tr>
                <th style={S.th}>Menú</th>
                <th style={S.th}>Cuándo aplica</th>
                <th style={S.th}></th>
              </tr>
            </thead>
            <tbody>
              {menus.map(m => (
                <tr key={m.id} style={{ ...S.row, opacity: m.activo ? 1 : 0.5 }}>
                  <td style={S.td}>{m.nombre}</td>
                  <td style={S.td}>
                    {m.zona && <span style={S.chip}>{m.zona.charAt(0).toUpperCase() + m.zona.slice(1)}</span>}
                    {franjaLabel(m) && <span style={S.chip}>{franjaLabel(m)}</span>}
                    {diasLabel(m) && <span style={S.chip}>{diasLabel(m)}</span>}
                    {!m.zona && !franjaLabel(m) && !diasLabel(m) && <span style={{ color: '#555' }}>Siempre</span>}
                  </td>
                  <td style={{ ...S.td, display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
                    <button style={S.editBtn} onClick={() => editarMenu(m)}>Editar</button>
                    <button style={S.editBtn} onClick={() => abrirEditorPrecios(m)}>Editar precios</button>
                    <button style={S.toggleBtn(m.activo)} onClick={() => toggleMenu(m)}>
                      {m.activo ? 'Activo' : 'Inactivo'}
                    </button>
                    <button style={S.deleteBtn} onClick={() => deleteMenu(m)}>Eliminar</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {editingMenu && (
        <div style={S.overlay} onClick={() => setEditingMenu(null)}>
          <div style={S.sheet} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>Precios · {editingMenu.nombre}</div>
            <div style={S.sheetHint}>
              Deja el precio en blanco para usar el de la carta normal. Marca "Excluir" para que ese plato no
              aparezca en este menú.
            </div>
            {categories.map(cat => {
              const catItems = items.filter(i => i.category_id === cat.id)
              if (!catItems.length) return null
              return (
                <div key={cat.id}>
                  <div style={S.catTitle}>{cat.nombre}</div>
                  {catItems.map(item => {
                    const v = editValues[item.id] || { precio: '', excluido: false }
                    return (
                      <div key={item.id} style={S.itemRow}>
                        <span style={S.itemNombre}>{item.nombre}</span>
                        <span style={S.itemBase}>{formatMoney(item.precio, restaurant?.moneda)}</span>
                        <input
                          style={S.precioInput}
                          type="number"
                          step="0.01"
                          min="0"
                          placeholder={item.precio}
                          value={v.precio}
                          disabled={v.excluido}
                          onChange={e => setValorItem(item.id, { precio: e.target.value })}
                        />
                        <label style={S.excluirLabel}>
                          <input
                            type="checkbox"
                            checked={v.excluido}
                            onChange={e => setValorItem(item.id, { excluido: e.target.checked })}
                          />
                          Excluir
                        </label>
                      </div>
                    )
                  })}
                </div>
              )
            })}
            <div style={S.sheetFooter}>
              <button style={S.cancelBtn} onClick={() => setEditingMenu(null)}>Cancelar</button>
              <button style={S.saveBtn(guardando)} onClick={guardarPrecios} disabled={guardando}>
                {guardando ? 'Guardando...' : 'Guardar'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
