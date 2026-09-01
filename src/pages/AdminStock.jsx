import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useRestaurantModulos } from '../lib/modulos'

const UNIDADES = ['kg', 'g', 'l', 'ml', 'unidad']

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
  select: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', minWidth: 100 },
  input: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', flex: 1, minWidth: 140 },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 11, color: '#7a6a50', textTransform: 'uppercase', letterSpacing: '0.05em', padding: '0 14px 10px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '14px', fontSize: 14, color: '#f0e8d8', borderBottom: '0.5px solid #222' },
  row: (bajo) => ({ background: bajo ? '#2a1a10' : '#1a1a1a' }),
  chip: { fontSize: 11, color: '#8a7560', background: '#111', border: '0.5px solid #3a2e20', borderRadius: 20, padding: '3px 10px' },
  alertBadge: { fontSize: 11, color: '#e8a03a', fontWeight: 500 },
  btnSm: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 12px', fontSize: 12, fontWeight: 500, cursor: 'pointer', color: '#c4a85a', fontFamily: "'Inter', sans-serif" },
  deleteBtn: { background: 'transparent', border: 'none', color: '#8a5050', fontSize: 12, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'underline' },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  empty: { textAlign: 'center', padding: 60, color: '#555', fontSize: 14 },
  alertaBanner: { background: '#2a1a00', border: '1px solid #d4a017', borderRadius: 12, padding: '12px 16px', marginBottom: 20, fontSize: 13, color: '#f0e8d8' },

  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 20 },
  sheet: { background: '#141414', width: '100%', maxWidth: 380, borderRadius: 16, padding: 24 },
  sheetWide: { background: '#141414', width: '100%', maxWidth: 640, maxHeight: '85vh', overflowY: 'auto', borderRadius: 16, padding: 24 },
  sheetTitle: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 16 },
  sheetHint: { fontSize: 12, color: '#7a6a50', marginBottom: 14, lineHeight: 1.5 },
  textarea: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#f0e8d8', fontFamily: "'Inter', monospace", outline: 'none', width: '100%', minHeight: 160, resize: 'vertical' },
  sheetFooter: { display: 'flex', gap: 10, marginTop: 20 },
  cancelBtn: { flex: 1, background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: 12, fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  saveBtn: (busy) => ({ flex: 1, background: busy ? '#5a4a2a' : '#e8c97a', color: busy ? '#8a7560' : '#111', border: 'none', borderRadius: 10, padding: 12, fontSize: 14, fontWeight: 500, cursor: busy ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
}

export default function AdminStock() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const { tieneModulo, loading: modulosLoading } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [ingredientes, setIngredientes] = useState([])
  const [movimientos, setMovimientos] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [vista, setVista] = useState('ingredientes') // 'ingredientes' | 'movimientos'

  const [nombre, setNombre] = useState('')
  const [unidad, setUnidad] = useState('unidad')
  const [stockInicial, setStockInicial] = useState('0')
  const [umbral, setUmbral] = useState('')
  const [adding, setAdding] = useState(false)

  const [movimientoIngrediente, setMovimientoIngrediente] = useState(null) // ingrediente | null
  const [tipoMovimiento, setTipoMovimiento] = useState('reposicion') // 'reposicion' | 'merma'
  const [cantidadMovimiento, setCantidadMovimiento] = useState('')
  const [motivoMovimiento, setMotivoMovimiento] = useState('')
  const [guardandoMovimiento, setGuardandoMovimiento] = useState(false)

  const [showCargaMasiva, setShowCargaMasiva] = useState(false)
  const [textoCargaMasiva, setTextoCargaMasiva] = useState('')
  const [filasCargaMasiva, setFilasCargaMasiva] = useState(null) // null = sin previsualizar aún
  const [guardandoCargaMasiva, setGuardandoCargaMasiva] = useState(false)

  const [showReposicionMasiva, setShowReposicionMasiva] = useState(false)
  const [cantidadesReposicion, setCantidadesReposicion] = useState({}) // { [ingrediente_id]: '12' }
  const [motivoReposicionMasiva, setMotivoReposicionMasiva] = useState('')
  const [guardandoReposicionMasiva, setGuardandoReposicionMasiva] = useState(false)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    const { data: rest } = await supabase.from('restaurants').select('nombre, moneda').eq('id', restaurantId).single()
    setRestaurant(rest)
    await loadIngredientes()
    setLoading(false)
  }

  async function loadIngredientes() {
    const { data, error: err } = await supabase
      .from('ingredientes')
      .select('id, nombre, unidad, stock_actual, umbral_alerta, activo')
      .eq('restaurant_id', restaurantId)
      .eq('activo', true)
      .order('nombre')
    if (err) { setError(err.message); return }
    setIngredientes(data || [])
  }

  async function loadMovimientos() {
    const { data, error: err } = await supabase
      .from('stock_movimientos')
      .select('id, ingrediente_id, tipo, cantidad, motivo, created_at')
      .eq('restaurant_id', restaurantId)
      .order('created_at', { ascending: false })
      .limit(50)
    if (err) { setError(err.message); return }
    setMovimientos(data || [])
  }

  function nombreIngrediente(id) { return ingredientes.find(i => i.id === id)?.nombre || '—' }

  async function addIngrediente() {
    if (!nombre.trim()) return
    setError(null)
    setAdding(true)
    const { error: err } = await supabase
      .from('ingredientes')
      .insert({
        restaurant_id: restaurantId,
        nombre: nombre.trim(),
        unidad,
        stock_actual: parseFloat(stockInicial) || 0,
        umbral_alerta: umbral !== '' ? parseFloat(umbral) : null,
      })
    setAdding(false)
    if (err) { setError(err.message); return }
    setNombre(''); setUnidad('unidad'); setStockInicial('0'); setUmbral('')
    await loadIngredientes()
  }

  // ---------- Carga masiva (pegar texto tipo CSV) ----------
  function previsualizarCargaMasiva() {
    const filas = textoCargaMasiva
      .split('\n')
      .map(l => l.trim())
      .filter(Boolean)
      .map(linea => {
        const partes = linea.split(',').map(p => p.trim())
        const [nom, unid, stock, umb] = partes
        const yaExiste = ingredientes.some(i => i.nombre.trim().toLowerCase() === (nom || '').toLowerCase())
        return {
          key: crypto.randomUUID(),
          nombre: nom || '',
          unidad: UNIDADES.includes(unid) ? unid : 'unidad',
          stock: stock || '0',
          umbral: umb || '',
          incluida: !!nom && !yaExiste,
          yaExiste,
        }
      })
    setFilasCargaMasiva(filas)
  }

  function actualizarFilaCargaMasiva(key, patch) {
    setFilasCargaMasiva(prev => prev.map(f => f.key === key ? { ...f, ...patch } : f))
  }

  async function confirmarCargaMasiva() {
    const incluidas = filasCargaMasiva.filter(f => f.incluida && f.nombre.trim())
    if (!incluidas.length) return
    setGuardandoCargaMasiva(true)
    setError(null)
    const filas = incluidas.map(f => ({
      restaurant_id: restaurantId,
      nombre: f.nombre.trim(),
      unidad: f.unidad,
      stock_actual: parseFloat(f.stock) || 0,
      umbral_alerta: f.umbral !== '' ? parseFloat(f.umbral) : null,
    }))
    const { error: err } = await supabase.from('ingredientes').insert(filas)
    setGuardandoCargaMasiva(false)
    if (err) { setError(err.message); return }
    setShowCargaMasiva(false)
    setTextoCargaMasiva('')
    setFilasCargaMasiva(null)
    await loadIngredientes()
  }

  // ---------- Reposición masiva ----------
  async function confirmarReposicionMasiva() {
    const entradas = Object.entries(cantidadesReposicion).filter(([, v]) => parseFloat(v) > 0)
    if (!entradas.length) return
    setGuardandoReposicionMasiva(true)
    setError(null)
    try {
      for (const [ingredienteId, cantidadStr] of entradas) {
        const cantidad = parseFloat(cantidadStr)
        const ing = ingredientes.find(i => i.id === ingredienteId)
        if (!ing) continue
        const { error: err1 } = await supabase
          .from('ingredientes')
          .update({ stock_actual: ing.stock_actual + cantidad })
          .eq('id', ingredienteId)
        if (err1) throw err1
        const { error: err2 } = await supabase
          .from('stock_movimientos')
          .insert({
            restaurant_id: restaurantId,
            ingrediente_id: ingredienteId,
            tipo: 'reposicion',
            cantidad,
            motivo: motivoReposicionMasiva.trim() || null,
          })
        if (err2) throw err2
      }
      setShowReposicionMasiva(false)
      setCantidadesReposicion({})
      setMotivoReposicionMasiva('')
      await loadIngredientes()
      if (vista === 'movimientos') await loadMovimientos()
    } catch (e) {
      setError(e.message)
    } finally {
      setGuardandoReposicionMasiva(false)
    }
  }

  async function renombrarIngrediente(ing, nuevoNombre) {
    if (!nuevoNombre.trim() || nuevoNombre === ing.nombre) return
    const { error: err } = await supabase.from('ingredientes').update({ nombre: nuevoNombre.trim() }).eq('id', ing.id)
    if (err) { setError(err.message); return }
    setIngredientes(prev => prev.map(i => i.id === ing.id ? { ...i, nombre: nuevoNombre.trim() } : i))
  }

  async function cambiarUmbral(ing, nuevoUmbral) {
    const valor = nuevoUmbral === '' ? null : parseFloat(nuevoUmbral)
    const { error: err } = await supabase.from('ingredientes').update({ umbral_alerta: valor }).eq('id', ing.id)
    if (err) { setError(err.message); return }
    setIngredientes(prev => prev.map(i => i.id === ing.id ? { ...i, umbral_alerta: valor } : i))
  }

  async function eliminarIngrediente(ing) {
    if (!window.confirm(`¿Eliminar "${ing.nombre}"? Se quitará también de cualquier receta que lo use.`)) return
    const { error: err } = await supabase.from('ingredientes').delete().eq('id', ing.id)
    if (err) { setError(err.message); return }
    setIngredientes(prev => prev.filter(i => i.id !== ing.id))
  }

  function abrirMovimiento(ing, tipo) {
    setMovimientoIngrediente(ing)
    setTipoMovimiento(tipo)
    setCantidadMovimiento('')
    setMotivoMovimiento('')
  }

  async function confirmarMovimiento() {
    const cantidad = parseFloat(cantidadMovimiento)
    if (!cantidad || cantidad <= 0) return
    if (tipoMovimiento === 'merma' && !motivoMovimiento.trim()) {
      setError('Indica el motivo de la merma.')
      return
    }
    setGuardandoMovimiento(true)
    setError(null)
    const delta = tipoMovimiento === 'merma' ? -cantidad : cantidad
    const nuevoStock = movimientoIngrediente.stock_actual + delta
    const { error: err1 } = await supabase.from('ingredientes').update({ stock_actual: nuevoStock }).eq('id', movimientoIngrediente.id)
    if (err1) { setError(err1.message); setGuardandoMovimiento(false); return }
    const { error: err2 } = await supabase.from('stock_movimientos').insert({
      restaurant_id: restaurantId,
      ingrediente_id: movimientoIngrediente.id,
      tipo: tipoMovimiento,
      cantidad: delta,
      motivo: motivoMovimiento.trim() || null,
    })
    setGuardandoMovimiento(false)
    if (err2) { setError(err2.message); return }
    setIngredientes(prev => prev.map(i => i.id === movimientoIngrediente.id ? { ...i, stock_actual: nuevoStock } : i))
    setMovimientoIngrediente(null)
    if (vista === 'movimientos') await loadMovimientos()
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  const ingredientesBajos = ingredientes.filter(i => i.umbral_alerta != null && i.stock_actual <= i.umbral_alerta)

  if (loading || modulosLoading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  if (!tieneModulo('control_stock')) {
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
          <div style={S.sectionTitle}>Control de stock</div>
          <div style={S.sectionHint}>Este restaurante no tiene activo el módulo de control de stock.</div>
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
          <a href={`/admin/stock/${restaurantId}`} style={S.navTab(true)}>Stock</a>
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
        <div style={S.sectionTitle}>Stock de ingredientes</div>
        <div style={S.sectionHint}>
          Da de alta tus ingredientes y, desde cada plato en Carta, la receta que lleva. Con el
          descuento automático activado en Configuración, el stock baja solo con cada pedido —
          aquí puedes registrar reposiciones (llegó un pedido del proveedor) y mermas.
        </div>

        {error && <div style={S.error}>{error}</div>}

        {ingredientesBajos.length > 0 && (
          <div style={S.alertaBanner}>
            ⚠ Bajo stock: {ingredientesBajos.map(i => `${i.nombre} (${i.stock_actual} ${i.unidad})`).join(', ')}
          </div>
        )}

        <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
          <button style={S.navTab(vista === 'ingredientes')} onClick={() => setVista('ingredientes')}>Ingredientes</button>
          <button
            style={S.navTab(vista === 'movimientos')}
            onClick={() => { setVista('movimientos'); loadMovimientos() }}
          >
            Movimientos
          </button>
        </div>

        {vista === 'ingredientes' && (
          <>
            <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
              <button style={S.btnSm} onClick={() => { setTextoCargaMasiva(''); setFilasCargaMasiva(null); setShowCargaMasiva(true) }}>
                📋 Carga masiva
              </button>
              <button style={S.btnSm} onClick={() => { setCantidadesReposicion({}); setMotivoReposicionMasiva(''); setShowReposicionMasiva(true) }}>
                📦 Reposición masiva
              </button>
            </div>

            <div style={S.addBar}>
              <div style={{ ...S.field, flex: 1 }}>
                <span style={S.label}>Nombre</span>
                <input style={S.input} placeholder="Ej. Jamón ibérico" value={nombre} onChange={e => setNombre(e.target.value)} />
              </div>
              <div style={S.field}>
                <span style={S.label}>Unidad</span>
                <select style={S.select} value={unidad} onChange={e => setUnidad(e.target.value)}>
                  {UNIDADES.map(u => <option key={u} value={u}>{u}</option>)}
                </select>
              </div>
              <div style={S.field}>
                <span style={S.label}>Stock inicial</span>
                <input style={{ ...S.input, width: 100 }} type="number" step="0.001" min="0" value={stockInicial} onChange={e => setStockInicial(e.target.value)} />
              </div>
              <div style={S.field}>
                <span style={S.label}>Umbral alerta</span>
                <input style={{ ...S.input, width: 100 }} type="number" step="0.001" min="0" placeholder="Opcional" value={umbral} onChange={e => setUmbral(e.target.value)} />
              </div>
              <button style={S.addBtn} onClick={addIngrediente} disabled={adding || !nombre.trim()}>
                {adding ? 'Añadiendo...' : '+ Añadir ingrediente'}
              </button>
            </div>

            {ingredientes.length === 0 ? (
              <div style={S.empty}>Todavía no diste de alta ningún ingrediente.</div>
            ) : (
              <table style={S.table}>
                <thead>
                  <tr>
                    <th style={S.th}>Ingrediente</th>
                    <th style={S.th}>Stock actual</th>
                    <th style={S.th}>Umbral de alerta</th>
                    <th style={S.th}></th>
                  </tr>
                </thead>
                <tbody>
                  {ingredientes.map(ing => {
                    const bajo = ing.umbral_alerta != null && ing.stock_actual <= ing.umbral_alerta
                    return (
                      <tr key={ing.id} style={S.row(bajo)}>
                        <td style={S.td}>
                          <input
                            style={{ background: 'transparent', border: 'none', color: '#f0e8d8', fontSize: 14, fontFamily: "'Inter', sans-serif", outline: 'none', width: 160 }}
                            defaultValue={ing.nombre}
                            onBlur={e => renombrarIngrediente(ing, e.target.value)}
                          />
                        </td>
                        <td style={S.td}>
                          {ing.stock_actual} {ing.unidad}
                          {bajo && <div style={S.alertBadge}>⚠ bajo stock</div>}
                        </td>
                        <td style={S.td}>
                          <input
                            style={{ ...S.input, width: 90, padding: '6px 8px', fontSize: 13 }}
                            type="number" step="0.001" min="0"
                            defaultValue={ing.umbral_alerta ?? ''}
                            placeholder="—"
                            onBlur={e => cambiarUmbral(ing, e.target.value)}
                          />
                        </td>
                        <td style={{ ...S.td, display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                          <button style={S.btnSm} onClick={() => abrirMovimiento(ing, 'reposicion')}>+ Reponer</button>
                          <button style={{ ...S.btnSm, color: '#e8a03a' }} onClick={() => abrirMovimiento(ing, 'merma')}>− Merma</button>
                          <button style={S.deleteBtn} onClick={() => eliminarIngrediente(ing)}>Eliminar</button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            )}
          </>
        )}

        {vista === 'movimientos' && (
          movimientos.length === 0 ? (
            <div style={S.empty}>Sin movimientos todavía.</div>
          ) : (
            <table style={S.table}>
              <thead>
                <tr>
                  <th style={S.th}>Fecha</th>
                  <th style={S.th}>Ingrediente</th>
                  <th style={S.th}>Tipo</th>
                  <th style={S.th}>Cantidad</th>
                  <th style={S.th}>Motivo</th>
                </tr>
              </thead>
              <tbody>
                {movimientos.map(m => (
                  <tr key={m.id} style={S.row(false)}>
                    <td style={S.td}>{new Date(m.created_at).toLocaleString('es-ES')}</td>
                    <td style={S.td}>{nombreIngrediente(m.ingrediente_id)}</td>
                    <td style={S.td}><span style={S.chip}>{m.tipo}</span></td>
                    <td style={{ ...S.td, color: m.cantidad < 0 ? '#e87a7a' : '#7ae8a0' }}>{m.cantidad > 0 ? '+' : ''}{m.cantidad}</td>
                    <td style={S.td}>{m.motivo || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )
        )}
      </div>

      {movimientoIngrediente && (
        <div style={S.overlay} onClick={() => setMovimientoIngrediente(null)}>
          <div style={S.sheet} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>
              {tipoMovimiento === 'reposicion' ? 'Reponer' : 'Registrar merma'} · {movimientoIngrediente.nombre}
            </div>
            <div style={S.field}>
              <span style={S.label}>Cantidad ({movimientoIngrediente.unidad})</span>
              <input
                style={S.input}
                type="number" step="0.001" min="0"
                autoFocus
                value={cantidadMovimiento}
                onChange={e => setCantidadMovimiento(e.target.value)}
              />
            </div>
            <div style={{ ...S.field, marginTop: 12 }}>
              <span style={S.label}>Motivo {tipoMovimiento === 'merma' ? '(obligatorio)' : '(opcional)'}</span>
              <input
                style={S.input}
                placeholder={tipoMovimiento === 'merma' ? 'Ej. se echó a perder' : 'Ej. pedido al proveedor'}
                value={motivoMovimiento}
                onChange={e => setMotivoMovimiento(e.target.value)}
              />
            </div>
            <div style={S.sheetFooter}>
              <button style={S.cancelBtn} onClick={() => setMovimientoIngrediente(null)}>Cancelar</button>
              <button style={S.saveBtn(guardandoMovimiento)} onClick={confirmarMovimiento} disabled={guardandoMovimiento}>
                {guardandoMovimiento ? 'Guardando...' : 'Confirmar'}
              </button>
            </div>
          </div>
        </div>
      )}

      {showCargaMasiva && (
        <div style={S.overlay} onClick={() => setShowCargaMasiva(false)}>
          <div style={S.sheetWide} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>Carga masiva de ingredientes</div>

            {!filasCargaMasiva ? (
              <>
                <div style={S.sheetHint}>
                  Pega una lista, una línea por ingrediente: <code>nombre, unidad, stock inicial, umbral de alerta</code>.
                  La unidad debe ser una de kg/g/l/ml/unidad (si no, se usa "unidad"); stock y umbral son
                  opcionales (umbral en blanco = sin alerta). Ejemplo:
                  <br />
                  <code>Jamón ibérico, kg, 5, 1{'\n'}Agua mineral, unidad, 48, 12{'\n'}Aceite de oliva, l, 10,</code>
                </div>
                <textarea
                  style={S.textarea}
                  placeholder={'Jamón ibérico, kg, 5, 1\nAgua mineral, unidad, 48, 12'}
                  value={textoCargaMasiva}
                  onChange={e => setTextoCargaMasiva(e.target.value)}
                />
                <div style={S.sheetFooter}>
                  <button style={S.cancelBtn} onClick={() => setShowCargaMasiva(false)}>Cancelar</button>
                  <button style={S.saveBtn(false)} onClick={previsualizarCargaMasiva} disabled={!textoCargaMasiva.trim()}>
                    Previsualizar
                  </button>
                </div>
              </>
            ) : (
              <>
                {filasCargaMasiva.length === 0 ? (
                  <div style={S.empty}>No se pudo leer ninguna fila — revisa el formato.</div>
                ) : (
                  filasCargaMasiva.map(f => (
                    <div key={f.key} style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '6px 0', borderBottom: '0.5px solid #2a2a2a', opacity: f.incluida ? 1 : 0.4 }}>
                      <input
                        type="checkbox"
                        checked={f.incluida}
                        onChange={e => actualizarFilaCargaMasiva(f.key, { incluida: e.target.checked })}
                      />
                      <input
                        style={{ ...S.input, flex: 2 }}
                        value={f.nombre}
                        onChange={e => actualizarFilaCargaMasiva(f.key, { nombre: e.target.value })}
                      />
                      <select
                        style={{ ...S.select, flex: 'none', width: 90 }}
                        value={f.unidad}
                        onChange={e => actualizarFilaCargaMasiva(f.key, { unidad: e.target.value })}
                      >
                        {UNIDADES.map(u => <option key={u} value={u}>{u}</option>)}
                      </select>
                      <input
                        style={{ ...S.input, flex: 'none', width: 80 }}
                        type="number" step="0.001" min="0"
                        value={f.stock}
                        onChange={e => actualizarFilaCargaMasiva(f.key, { stock: e.target.value })}
                      />
                      <input
                        style={{ ...S.input, flex: 'none', width: 80 }}
                        type="number" step="0.001" min="0"
                        placeholder="Umbral"
                        value={f.umbral}
                        onChange={e => actualizarFilaCargaMasiva(f.key, { umbral: e.target.value })}
                      />
                      {f.yaExiste && <span style={{ fontSize: 10, color: '#e8a03a', whiteSpace: 'nowrap' }}>ya existe</span>}
                    </div>
                  ))
                )}
                <div style={S.sheetFooter}>
                  <button style={S.cancelBtn} onClick={() => setFilasCargaMasiva(null)}>← Volver</button>
                  <button style={S.saveBtn(guardandoCargaMasiva)} onClick={confirmarCargaMasiva} disabled={guardandoCargaMasiva}>
                    {guardandoCargaMasiva ? 'Guardando...' : 'Crear ingredientes'}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {showReposicionMasiva && (
        <div style={S.overlay} onClick={() => setShowReposicionMasiva(false)}>
          <div style={S.sheetWide} onClick={e => e.stopPropagation()}>
            <div style={S.sheetTitle}>Reposición masiva</div>
            <div style={S.sheetHint}>
              Llena solo los ingredientes que llegaron — el resto se deja en blanco y no se toca.
            </div>
            <div style={{ ...S.field, marginBottom: 14 }}>
              <span style={S.label}>Motivo (opcional, se aplica a todos)</span>
              <input
                style={S.input}
                placeholder="Ej. pedido del 1 de septiembre a Proveedor X"
                value={motivoReposicionMasiva}
                onChange={e => setMotivoReposicionMasiva(e.target.value)}
              />
            </div>
            {ingredientes.map(ing => (
              <div key={ing.id} style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '6px 0', borderBottom: '0.5px solid #2a2a2a' }}>
                <span style={{ flex: 1, fontSize: 13 }}>{ing.nombre}</span>
                <span style={{ fontSize: 11, color: '#7a6a50', width: 90 }}>actual: {ing.stock_actual} {ing.unidad}</span>
                <input
                  style={{ ...S.input, flex: 'none', width: 90 }}
                  type="number" step="0.001" min="0"
                  placeholder="0"
                  value={cantidadesReposicion[ing.id] || ''}
                  onChange={e => setCantidadesReposicion(prev => ({ ...prev, [ing.id]: e.target.value }))}
                />
                <span style={{ fontSize: 12, color: '#7a6a50', width: 40 }}>{ing.unidad}</span>
              </div>
            ))}
            <div style={S.sheetFooter}>
              <button style={S.cancelBtn} onClick={() => setShowReposicionMasiva(false)}>Cancelar</button>
              <button style={S.saveBtn(guardandoReposicionMasiva)} onClick={confirmarReposicionMasiva} disabled={guardandoReposicionMasiva}>
                {guardandoReposicionMasiva ? 'Guardando...' : 'Confirmar reposición'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
