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
  section: { marginBottom: 40 },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 6 },
  sectionHint: { fontSize: 12, color: '#7a6a50', marginBottom: 20, lineHeight: 1.5 },
  addBar: { display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap', alignItems: 'flex-end', background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 16 },
  field: { display: 'flex', flexDirection: 'column', gap: 4 },
  label: { fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em' },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  select: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none' },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 12px 10px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '12px', fontSize: 14, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  row: { background: '#1a1a1a' },
  actionBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '5px 10px', fontSize: 11, cursor: 'pointer', fontFamily: "'Inter', sans-serif", marginRight: 6 },
  toggleBtn: (activo) => ({ background: 'transparent', border: `0.5px solid ${activo ? '#27ae60' : '#3a2e20'}`, borderRadius: 8, padding: '5px 10px', fontSize: 11, fontWeight: 500, cursor: 'pointer', color: activo ? '#2ecc71' : '#666', fontFamily: "'Inter', sans-serif", marginRight: 6 }),
  deleteBtn: { background: 'transparent', border: 'none', color: '#8a5050', fontSize: 12, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'underline' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 40, color: '#555', fontSize: 14 },
}

export default function AdminFidelizacion() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [niveles, setNiveles] = useState([])
  const [premios, setPremios] = useState([])
  const [menuItems, setMenuItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const [nombreNivel, setNombreNivel] = useState('')
  const [umbralNivel, setUmbralNivel] = useState('')
  const [addingNivel, setAddingNivel] = useState(false)

  const [nombrePremio, setNombrePremio] = useState('')
  const [descripcionPremio, setDescripcionPremio] = useState('')
  const [costoPremio, setCostoPremio] = useState('')
  const [nivelMinimoPremio, setNivelMinimoPremio] = useState('')
  const [tipoPremio, setTipoPremio] = useState('plato_gratis')
  const [menuItemPremio, setMenuItemPremio] = useState('')
  const [descuentoImportePremio, setDescuentoImportePremio] = useState('')
  const [addingPremio, setAddingPremio] = useState(false)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('nombre, moneda').eq('id', restaurantId).single()
    setRestaurant(rest)
    await loadNiveles()
    await loadPremios()
    await loadMenuItems()
    setLoading(false)
  }

  async function loadMenuItems() {
    const { data } = await supabase
      .from('menu_items')
      .select('id, nombre')
      .eq('restaurant_id', restaurantId)
      .order('nombre')
    setMenuItems(data || [])
  }

  async function loadNiveles() {
    const { data, error: err } = await supabase
      .from('niveles_fidelizacion')
      .select('id, nombre, umbral_gasto, orden')
      .eq('restaurant_id', restaurantId)
      .order('umbral_gasto')
    if (err) { setError(err.message); return }
    setNiveles(data || [])
  }

  async function loadPremios() {
    const { data, error: err } = await supabase
      .from('premios_fidelizacion')
      .select('id, nombre, descripcion, costo_puntos, nivel_minimo_id, activo, tipo, menu_item_id, descuento_importe')
      .eq('restaurant_id', restaurantId)
      .order('costo_puntos')
    if (err) { setError(err.message); return }
    setPremios(data || [])
  }

  function nombreNivelPorId(id) {
    return niveles.find(n => n.id === id)?.nombre || '—'
  }

  function nombreMenuItemPorId(id) {
    return menuItems.find(i => i.id === id)?.nombre || '—'
  }

  async function addNivel() {
    if (!nombreNivel.trim() || umbralNivel === '') return
    setError(null)
    setAddingNivel(true)
    const orden = niveles.length > 0 ? Math.max(...niveles.map(n => n.orden)) + 1 : 0
    const { data, error: err } = await supabase
      .from('niveles_fidelizacion')
      .insert({ restaurant_id: restaurantId, nombre: nombreNivel.trim(), umbral_gasto: parseFloat(umbralNivel) || 0, orden })
      .select().single()
    setAddingNivel(false)
    if (err) {
      setError(err.code === '23505' ? 'Ya existe un nivel con ese nombre.' : err.message)
      return
    }
    setNiveles(prev => [...prev, data].sort((a, b) => a.umbral_gasto - b.umbral_gasto))
    setNombreNivel('')
    setUmbralNivel('')
  }

  async function eliminarNivel(nivel) {
    if (!window.confirm(`¿Eliminar el nivel "${nivel.nombre}"? Los premios que lo tengan como mínimo quedarán sin esa restricción.`)) return
    const { error: err } = await supabase.from('niveles_fidelizacion').delete().eq('id', nivel.id)
    if (err) { setError(err.message); return }
    setNiveles(prev => prev.filter(n => n.id !== nivel.id))
    await loadPremios()
  }

  async function addPremio() {
    if (!nombrePremio.trim() || !costoPremio) return
    if (tipoPremio === 'plato_gratis' && !menuItemPremio) { setError('Elige el plato que se entrega gratis.'); return }
    if (tipoPremio === 'descuento' && !descuentoImportePremio) { setError('Introduce el importe del descuento.'); return }
    setError(null)
    setAddingPremio(true)
    const { data, error: err } = await supabase
      .from('premios_fidelizacion')
      .insert({
        restaurant_id: restaurantId,
        nombre: nombrePremio.trim(),
        descripcion: descripcionPremio.trim() || null,
        costo_puntos: parseInt(costoPremio, 10),
        nivel_minimo_id: nivelMinimoPremio || null,
        tipo: tipoPremio,
        menu_item_id: tipoPremio === 'plato_gratis' ? menuItemPremio : null,
        descuento_importe: tipoPremio === 'descuento' ? parseFloat(descuentoImportePremio) : null,
      })
      .select().single()
    setAddingPremio(false)
    if (err) { setError(err.message); return }
    setPremios(prev => [...prev, data].sort((a, b) => a.costo_puntos - b.costo_puntos))
    setNombrePremio('')
    setDescripcionPremio('')
    setCostoPremio('')
    setNivelMinimoPremio('')
    setTipoPremio('plato_gratis')
    setMenuItemPremio('')
    setDescuentoImportePremio('')
  }

  async function togglePremioActivo(premio) {
    const { error: err } = await supabase.from('premios_fidelizacion').update({ activo: !premio.activo }).eq('id', premio.id)
    if (err) { setError(err.message); return }
    setPremios(prev => prev.map(p => p.id === premio.id ? { ...p, activo: !p.activo } : p))
  }

  async function eliminarPremio(premio) {
    if (!window.confirm(`¿Eliminar el premio "${premio.nombre}"?`)) return
    const { error: err } = await supabase.from('premios_fidelizacion').delete().eq('id', premio.id)
    if (err) { setError(err.message); return }
    setPremios(prev => prev.filter(p => p.id !== premio.id))
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
          <a href={`/admin/menus/${restaurantId}`} style={S.navTab(false)}>Menús</a>
          {tieneModulo('control_stock') && <a href={`/admin/stock/${restaurantId}`} style={S.navTab(false)}>Stock</a>}
          <a href={`/admin/clientes/${restaurantId}`} style={S.navTab(false)}>Clientes</a>
          <a href={`/admin/upsell/${restaurantId}`} style={S.navTab(false)}>Upsell</a>
          <a href={`/admin/reservas/${restaurantId}`} style={S.navTab(false)}>Reservas</a>
          <a href={`/admin/limpieza/${restaurantId}`} style={S.navTab(false)}>Limpieza</a>
          <a href={`/admin/fidelizacion/${restaurantId}`} style={S.navTab(true)}>Fidelización</a>
          <a href={`/admin/config/${restaurantId}`} style={S.navTab(false)}>Configuración</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        {error && <div style={S.error}>{error}</div>}

        <div style={S.section}>
          <div style={S.sectionTitle}>Niveles</div>
          <div style={S.sectionHint}>
            El nivel de cada cliente se calcula según su gasto acumulado histórico — no baja al canjear puntos.
          </div>

          <div style={S.addBar}>
            <div style={S.field}>
              <span style={S.label}>Nombre</span>
              <input style={S.input} placeholder="Ej. Plata" value={nombreNivel} onChange={e => setNombreNivel(e.target.value)} />
            </div>
            <div style={S.field}>
              <span style={S.label}>Gasto mínimo ({restaurant?.moneda})</span>
              <input style={S.input} type="number" min="0" step="0.01" placeholder="500" value={umbralNivel} onChange={e => setUmbralNivel(e.target.value)} />
            </div>
            <button style={S.addBtn} onClick={addNivel} disabled={addingNivel}>
              {addingNivel ? 'Añadiendo...' : '+ Añadir nivel'}
            </button>
          </div>

          {niveles.length === 0 ? (
            <div style={S.empty}>Todavía no configuraste ningún nivel.</div>
          ) : (
            <table style={S.table}>
              <thead>
                <tr>
                  <th style={S.th}>Nivel</th>
                  <th style={S.th}>Gasto mínimo</th>
                  <th style={S.th}></th>
                </tr>
              </thead>
              <tbody>
                {niveles.map(n => (
                  <tr key={n.id} style={S.row}>
                    <td style={S.td}>{n.nombre}</td>
                    <td style={S.td}>{formatMoney(n.umbral_gasto, restaurant?.moneda)}</td>
                    <td style={S.td}><button style={S.deleteBtn} onClick={() => eliminarNivel(n)}>Eliminar</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        <div style={S.section}>
          <div style={S.sectionTitle}>Premios</div>
          <div style={S.sectionHint}>
            Catálogo de premios canjeables por puntos — aparecen tanto en el canje desde Clientes como en el panel del cliente en Mesa.
          </div>

          <div style={S.addBar}>
            <div style={S.field}>
              <span style={S.label}>Nombre</span>
              <input style={S.input} placeholder="Ej. Postre gratis" value={nombrePremio} onChange={e => setNombrePremio(e.target.value)} />
            </div>
            <div style={S.field}>
              <span style={S.label}>Puntos</span>
              <input style={{ ...S.input, width: 90 }} type="number" min="1" placeholder="200" value={costoPremio} onChange={e => setCostoPremio(e.target.value)} />
            </div>
            <div style={S.field}>
              <span style={S.label}>Tipo</span>
              <select style={S.select} value={tipoPremio} onChange={e => setTipoPremio(e.target.value)}>
                <option value="plato_gratis">Plato gratis</option>
                <option value="descuento">Descuento en efectivo</option>
              </select>
            </div>
            {tipoPremio === 'plato_gratis' ? (
              <div style={S.field}>
                <span style={S.label}>Plato</span>
                <select style={S.select} value={menuItemPremio} onChange={e => setMenuItemPremio(e.target.value)}>
                  <option value="">Elige un plato</option>
                  {menuItems.map(i => <option key={i.id} value={i.id}>{i.nombre}</option>)}
                </select>
              </div>
            ) : (
              <div style={S.field}>
                <span style={S.label}>Importe ({restaurant?.moneda})</span>
                <input style={{ ...S.input, width: 90 }} type="number" min="0.01" step="0.01" placeholder="5" value={descuentoImportePremio} onChange={e => setDescuentoImportePremio(e.target.value)} />
              </div>
            )}
            <div style={S.field}>
              <span style={S.label}>Nivel mínimo</span>
              <select style={S.select} value={nivelMinimoPremio} onChange={e => setNivelMinimoPremio(e.target.value)}>
                <option value="">Cualquiera</option>
                {niveles.map(n => <option key={n.id} value={n.id}>{n.nombre}</option>)}
              </select>
            </div>
            <div style={{ ...S.field, flex: 1 }}>
              <span style={S.label}>Descripción (opcional)</span>
              <input style={S.input} placeholder="Ej. Uno por mesa" value={descripcionPremio} onChange={e => setDescripcionPremio(e.target.value)} />
            </div>
            <button style={S.addBtn} onClick={addPremio} disabled={addingPremio}>
              {addingPremio ? 'Añadiendo...' : '+ Añadir premio'}
            </button>
          </div>

          {premios.length === 0 ? (
            <div style={S.empty}>Todavía no configuraste ningún premio.</div>
          ) : (
            <table style={S.table}>
              <thead>
                <tr>
                  <th style={S.th}>Premio</th>
                  <th style={S.th}>Puntos</th>
                  <th style={S.th}>Qué entrega</th>
                  <th style={S.th}>Nivel mínimo</th>
                  <th style={S.th}></th>
                </tr>
              </thead>
              <tbody>
                {premios.map(p => (
                  <tr key={p.id} style={{ ...S.row, opacity: p.activo ? 1 : 0.5 }}>
                    <td style={S.td}>
                      {p.nombre}
                      {p.descripcion && <div style={{ fontSize: 12, color: '#7a6a50' }}>{p.descripcion}</div>}
                    </td>
                    <td style={S.td}>{p.costo_puntos}</td>
                    <td style={S.td}>
                      {p.tipo === 'plato_gratis'
                        ? `🍽 ${nombreMenuItemPorId(p.menu_item_id)}`
                        : `💶 -${formatMoney(p.descuento_importe, restaurant?.moneda)}`}
                    </td>
                    <td style={S.td}>{p.nivel_minimo_id ? nombreNivelPorId(p.nivel_minimo_id) : '—'}</td>
                    <td style={S.td}>
                      <button style={S.toggleBtn(p.activo)} onClick={() => togglePremioActivo(p)}>
                        {p.activo ? 'Activo' : 'Inactivo'}
                      </button>
                      <button style={S.deleteBtn} onClick={() => eliminarPremio(p)}>Eliminar</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  )
}
