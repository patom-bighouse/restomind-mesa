import { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  header: { background: '#0a0a0a', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  restName: { fontSize: 13, color: '#8a7560', marginTop: 2 },
  navTabs: { display: 'flex', gap: 8 },
  navTab: (active) => ({ background: active ? '#e8c97a' : 'transparent', color: active ? '#111' : '#8a7560', border: `0.5px solid ${active ? '#e8c97a' : '#3a2e20'}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none' }),
  logoutBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 24, maxWidth: 960, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 20 },
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },

  catRow: { display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8, background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: '10px 14px' },
  catInput: { background: '#111', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '8px 12px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', flex: 1 },
  iconBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, width: 34, height: 34, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: '#8a7560', fontSize: 14 },
  toggleSwitch: (on) => ({ width: 38, height: 22, borderRadius: 12, background: on ? '#27ae60' : '#3a2a2a', position: 'relative', cursor: 'pointer', transition: 'background 0.15s', flexShrink: 0 }),
  toggleDot: (on) => ({ width: 18, height: 18, borderRadius: '50%', background: '#fff', position: 'absolute', top: 2, left: on ? 18 : 2, transition: 'left 0.15s' }),

  addCatBar: { display: 'flex', gap: 10, marginBottom: 28 },
  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", whiteSpace: 'nowrap' },

  catSection: { marginBottom: 32 },
  catHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14, paddingBottom: 10, borderBottom: '0.5px solid #2a2a2a' },
  catName: { fontSize: 15, fontWeight: 600, color: '#e8c97a', fontFamily: "'Playfair Display', serif" },
  addItemBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 12px', fontSize: 12, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },

  itemGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 12 },
  itemCard: (disponible) => ({ background: '#1a1a1a', border: '0.5px solid #2a2a2a', borderRadius: 12, padding: 14, display: 'flex', gap: 12, opacity: disponible ? 1 : 0.45 }),
  itemImg: { width: 60, height: 60, borderRadius: 10, objectFit: 'cover', background: '#111', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24, cursor: 'pointer', border: '0.5px solid #2a2a2a' },
  itemInfo: { flex: 1, display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 },
  itemName: { fontSize: 14, fontWeight: 500, color: '#f0e8d8' },
  itemDesc: { fontSize: 12, color: '#7a6a50', lineHeight: 1.4 },
  itemPrice: { fontSize: 14, fontWeight: 500, color: '#e8c97a' },
  itemActions: { display: 'flex', gap: 6, marginTop: 4, alignItems: 'center' },

  modal: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 50, padding: 20 },
  modalBox: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 16, padding: 24, width: '100%', maxWidth: 420, maxHeight: '85vh', overflowY: 'auto' },
  modalTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 18 },
  label: { fontSize: 12, color: '#8a7560', marginBottom: 6, display: 'block', marginTop: 14 },
  input: { width: '100%', background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' },
  textarea: { width: '100%', background: '#111', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box', resize: 'vertical', minHeight: 60 },
  imgPreviewWrap: { display: 'flex', alignItems: 'center', gap: 12, marginTop: 6 },
  imgPreview: { width: 60, height: 60, borderRadius: 10, objectFit: 'cover', background: '#111', border: '0.5px solid #3a2e20' },
  uploadBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '8px 14px', fontSize: 12, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  modalBtns: { display: 'flex', gap: 10, marginTop: 22 },
  saveBtn: (disabled) => ({ flex: 1, background: disabled ? '#5a4a2a' : '#e8c97a', color: disabled ? '#8a7560' : '#111', border: 'none', borderRadius: 10, padding: 12, fontSize: 14, fontWeight: 500, cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
  cancelBtn: { flex: 1, background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: 12, fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  deleteBtn: { background: 'transparent', border: '0.5px solid #3a2020', borderRadius: 10, padding: 12, fontSize: 14, color: '#e74c3c', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  emojiHint: { fontSize: 11, color: '#555', marginTop: 4 },
}

const EMOJI_OPTIONS = ['🍽','🥗','🍖','🐟','🥩','🍝','🍮','🍫','🍷','🍺','🍕','🍔','🍣','🥘','🧀','🥙','🍲','🥟','🌮','🍤','🍰','🥧','🧁','☕','🍹','🥤','🍞','🥖']

export default function AdminCarta() {
  const { restaurantId } = useParams()
  const navigate = useNavigate()
  const [restaurant, setRestaurant] = useState(null)
  const [categories, setCategories] = useState([])
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [newCatName, setNewCatName] = useState('')

  // Item modal
  const [editingItem, setEditingItem] = useState(null) // null | 'new' | item object
  const [editingCatId, setEditingCatId] = useState(null)
  const [formData, setFormData] = useState({})
  const [uploading, setUploading] = useState(false)
  const [saving, setSaving] = useState(false)
  const fileInputRef = useRef(null)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/admin/login'); return }
    loadData()
  }

  async function loadData() {
    const { data: rest } = await supabase.from('restaurants').select('nombre').eq('id', restaurantId).single()
    setRestaurant(rest)

    const { data: cats, error: catErr } = await supabase
      .from('categories').select('id, nombre, orden, activa')
      .eq('restaurant_id', restaurantId).order('orden')
    if (catErr) { setError(catErr.message); setLoading(false); return }
    setCategories(cats || [])

    const { data: menuItems, error: itemErr } = await supabase
      .from('menu_items').select('id, nombre, descripcion, precio, emoji, foto_url, category_id, disponible, orden')
      .eq('restaurant_id', restaurantId).order('orden')
    if (itemErr) { setError(itemErr.message); setLoading(false); return }
    setItems(menuItems || [])
    setLoading(false)
  }

  // ---------- Categorías ----------
  async function addCategory() {
    if (!newCatName.trim()) return
    const orden = categories.length ? Math.max(...categories.map(c => c.orden)) + 1 : 1
    const { data, error: err } = await supabase
      .from('categories')
      .insert({ restaurant_id: restaurantId, nombre: newCatName.trim(), orden, activa: true })
      .select().single()
    if (err) { setError(err.message); return }
    setCategories(prev => [...prev, data])
    setNewCatName('')
  }

  async function renameCategory(cat, nuevoNombre) {
    if (!nuevoNombre.trim() || nuevoNombre === cat.nombre) return
    const { error: err } = await supabase.from('categories').update({ nombre: nuevoNombre.trim() }).eq('id', cat.id)
    if (err) { setError(err.message); return }
    setCategories(prev => prev.map(c => c.id === cat.id ? { ...c, nombre: nuevoNombre.trim() } : c))
  }

  async function toggleCategory(cat) {
    const nueva = !cat.activa
    const { error: err } = await supabase.from('categories').update({ activa: nueva }).eq('id', cat.id)
    if (err) { setError(err.message); return }
    setCategories(prev => prev.map(c => c.id === cat.id ? { ...c, activa: nueva } : c))
  }

  async function deleteCategory(cat) {
    const itemsInCat = items.filter(i => i.category_id === cat.id)
    if (itemsInCat.length > 0) {
      setError(`No se puede eliminar "${cat.nombre}" porque tiene ${itemsInCat.length} ${itemsInCat.length === 1 ? 'plato' : 'platos'}. Elimina o reasigna los platos primero.`)
      return
    }
    if (!window.confirm(`¿Eliminar la categoría "${cat.nombre}"?`)) return
    const { error: err } = await supabase.from('categories').delete().eq('id', cat.id)
    if (err) { setError(err.message); return }
    setCategories(prev => prev.filter(c => c.id !== cat.id))
  }

  async function moveCategory(cat, direction) {
    const sorted = [...categories].sort((a, b) => a.orden - b.orden)
    const idx = sorted.findIndex(c => c.id === cat.id)
    const swapIdx = direction === 'up' ? idx - 1 : idx + 1
    if (swapIdx < 0 || swapIdx >= sorted.length) return
    const other = sorted[swapIdx]
    const ordenA = cat.orden, ordenB = other.orden
    await supabase.from('categories').update({ orden: ordenB }).eq('id', cat.id)
    await supabase.from('categories').update({ orden: ordenA }).eq('id', other.id)
    setCategories(prev => prev.map(c => {
      if (c.id === cat.id) return { ...c, orden: ordenB }
      if (c.id === other.id) return { ...c, orden: ordenA }
      return c
    }))
  }

  // ---------- Items ----------
  function openNewItem(categoryId) {
    setEditingCatId(categoryId)
    setEditingItem('new')
    setFormData({ nombre: '', descripcion: '', precio: '', emoji: '🍽', foto_url: '', disponible: true })
  }

  function openEditItem(item) {
    setEditingCatId(item.category_id)
    setEditingItem(item)
    setFormData({ ...item })
  }

  function closeModal() {
    setEditingItem(null)
    setEditingCatId(null)
    setFormData({})
  }

  async function handleFileUpload(e) {
    const file = e.target.files[0]
    if (!file) return
    setUploading(true)
    setError(null)
    try {
      const ext = file.name.split('.').pop()
      const fileName = `${restaurantId}/${Date.now()}.${ext}`
      const { error: uploadErr } = await supabase.storage.from('menu-images').upload(fileName, file, { cacheControl: '3600', upsert: false })
      if (uploadErr) throw uploadErr
      const { data: urlData } = supabase.storage.from('menu-images').getPublicUrl(fileName)
      setFormData(prev => ({ ...prev, foto_url: urlData.publicUrl }))
    } catch (e) {
      setError('Error al subir imagen: ' + e.message)
    } finally {
      setUploading(false)
    }
  }

  async function saveItem() {
    if (!formData.nombre?.trim() || !formData.precio) {
      setError('Nombre y precio son obligatorios.')
      return
    }
    setSaving(true)
    setError(null)
    const targetCatId = formData.category_id || editingCatId
    const payload = {
      nombre: formData.nombre.trim(),
      descripcion: formData.descripcion?.trim() || null,
      precio: parseFloat(formData.precio),
      emoji: formData.emoji || '🍽',
      foto_url: formData.foto_url || null,
      disponible: formData.disponible !== false,
      category_id: targetCatId,
    }

    if (editingItem === 'new') {
      const itemsInCat = items.filter(i => i.category_id === targetCatId)
      const orden = itemsInCat.length ? Math.max(...itemsInCat.map(i => i.orden)) + 1 : 1
      const { data, error: err } = await supabase
        .from('menu_items')
        .insert({ ...payload, restaurant_id: restaurantId, orden })
        .select().single()
      if (err) { setError(err.message); setSaving(false); return }
      setItems(prev => [...prev, data])
    } else {
      const { error: err } = await supabase.from('menu_items').update(payload).eq('id', editingItem.id)
      if (err) { setError(err.message); setSaving(false); return }
      setItems(prev => prev.map(i => i.id === editingItem.id ? { ...i, ...payload } : i))
    }
    setSaving(false)
    closeModal()
  }

  async function deleteItem() {
    if (editingItem === 'new' || !editingItem) return
    if (!window.confirm(`¿Eliminar "${editingItem.nombre}"?`)) return
    const { error: err } = await supabase.from('menu_items').delete().eq('id', editingItem.id)
    if (err) { setError(err.message); return }
    setItems(prev => prev.filter(i => i.id !== editingItem.id))
    closeModal()
  }

  async function toggleDisponible(item) {
    const nuevo = !item.disponible
    const { error: err } = await supabase.from('menu_items').update({ disponible: nuevo }).eq('id', item.id)
    if (err) { setError(err.message); return }
    setItems(prev => prev.map(i => i.id === item.id ? { ...i, disponible: nuevo } : i))
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/admin/login')
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  const sortedCats = [...categories].sort((a, b) => a.orden - b.orden)

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.header}>
        <div>
          <div style={S.logo}>Restomind Admin</div>
          <div style={S.restName}>{restaurant?.nombre}</div>
        </div>
        <div style={S.navTabs}>
          <a href={`/admin/dashboard/${restaurantId}`} style={S.navTab(false)}>Dashboard</a>
          <a href={`/admin/mesas/${restaurantId}`} style={S.navTab(false)}>Mesas</a>
          <a href={`/admin/carta/${restaurantId}`} style={S.navTab(true)}>Carta</a>
          <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Gestión de carta</div>
        {error && <div style={S.error}>{error}</div>}

        {/* Añadir categoría */}
        <div style={S.addCatBar}>
          <input
            style={S.catInput}
            placeholder="Nueva categoría (ej. Postres)"
            value={newCatName}
            onChange={e => setNewCatName(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && addCategory()}
          />
          <button style={S.addBtn} onClick={addCategory}>+ Añadir categoría</button>
        </div>

        {/* Categorías y platos */}
        {sortedCats.map((cat, idx) => {
          const catItems = items.filter(i => i.category_id === cat.id).sort((a, b) => a.orden - b.orden)
          return (
            <div key={cat.id} style={S.catSection}>
              <div style={S.catHeader}>
                <input
                  style={{ ...S.catName, background: 'transparent', border: 'none', outline: 'none', fontFamily: "'Playfair Display', serif", width: 'auto', maxWidth: 240 }}
                  defaultValue={cat.nombre}
                  onBlur={e => renameCategory(cat, e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && e.target.blur()}
                />
                <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                  <button style={S.iconBtn} onClick={() => moveCategory(cat, 'up')} disabled={idx === 0} title="Subir">↑</button>
                  <button style={S.iconBtn} onClick={() => moveCategory(cat, 'down')} disabled={idx === sortedCats.length - 1} title="Bajar">↓</button>
                  <div style={S.toggleSwitch(cat.activa)} onClick={() => toggleCategory(cat)} title={cat.activa ? 'Visible para clientes' : 'Oculta para clientes'}>
                    <div style={S.toggleDot(cat.activa)}></div>
                  </div>
                  <button style={S.addItemBtn} onClick={() => openNewItem(cat.id)}>+ Plato</button>
                  <button style={{ ...S.iconBtn, color: '#e74c3c', borderColor: '#3a2020' }} onClick={() => deleteCategory(cat)} title="Eliminar categoría">×</button>
                </div>
              </div>

              {catItems.length === 0 ? (
                <div style={{ fontSize: 13, color: '#555', padding: '8px 0' }}>Sin platos en esta categoría.</div>
              ) : (
                <div style={S.itemGrid}>
                  {catItems.map(item => (
                    <div key={item.id} style={S.itemCard(item.disponible)}>
                      <div style={S.itemImg} onClick={() => openEditItem(item)}>
                        {item.foto_url ? <img src={item.foto_url} alt={item.nombre} style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 10 }} /> : item.emoji}
                      </div>
                      <div style={S.itemInfo}>
                        <div style={S.itemName}>{item.nombre}</div>
                        {item.descripcion && <div style={S.itemDesc}>{item.descripcion}</div>}
                        <div style={S.itemPrice}>{parseFloat(item.precio).toFixed(2).replace('.', ',')} €</div>
                        <div style={S.itemActions}>
                          <div style={S.toggleSwitch(item.disponible)} onClick={() => toggleDisponible(item)} title={item.disponible ? 'Disponible' : 'No disponible'}>
                            <div style={S.toggleDot(item.disponible)}></div>
                          </div>
                          <span style={{ fontSize: 11, color: '#7a6a50' }}>{item.disponible ? 'Disponible' : 'Agotado'}</span>
                          <button style={{ ...S.iconBtn, width: 'auto', height: 'auto', padding: '4px 10px', fontSize: 11, marginLeft: 'auto' }} onClick={() => openEditItem(item)}>Editar</button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )
        })}

        {sortedCats.length === 0 && (
          <div style={{ fontSize: 14, color: '#555', textAlign: 'center', padding: '60px 0' }}>
            Aún no hay categorías. Añade la primera arriba.
          </div>
        )}
      </div>

      {/* Modal de plato */}
      {editingItem && (
        <div style={S.modal} onClick={e => { if (e.target === e.currentTarget) closeModal() }}>
          <div style={S.modalBox}>
            <div style={S.modalTitle}>{editingItem === 'new' ? 'Nuevo plato' : 'Editar plato'}</div>

            <label style={S.label}>Nombre *</label>
            <input style={S.input} value={formData.nombre || ''} onChange={e => setFormData(prev => ({ ...prev, nombre: e.target.value }))} placeholder="Ej. Croquetas de jamón" />

            <label style={S.label}>Descripción</label>
            <textarea style={S.textarea} value={formData.descripcion || ''} onChange={e => setFormData(prev => ({ ...prev, descripcion: e.target.value }))} placeholder="Ingredientes, detalles..." />

            <label style={S.label}>Precio (€) *</label>
            <input style={S.input} type="number" step="0.01" min="0" value={formData.precio ?? ''} onChange={e => setFormData(prev => ({ ...prev, precio: e.target.value }))} placeholder="9.50" />

            <label style={S.label}>Categoría</label>
            <select
              style={S.input}
              value={formData.category_id || editingCatId || ''}
              onChange={e => setFormData(prev => ({ ...prev, category_id: e.target.value }))}
            >
              {sortedCats.map(c => (
                <option key={c.id} value={c.id}>{c.nombre}</option>
              ))}
            </select>

            <label style={S.label}>Foto</label>
            <div style={S.imgPreviewWrap}>
              <div style={S.imgPreview}>
                {formData.foto_url
                  ? <img src={formData.foto_url} alt="preview" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 10 }} />
                  : <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24 }}>{formData.emoji || '🍽'}</div>
                }
              </div>
              <button style={S.uploadBtn} onClick={() => fileInputRef.current?.click()} disabled={uploading}>
                {uploading ? 'Subiendo...' : 'Subir foto'}
              </button>
              {formData.foto_url && (
                <button style={S.uploadBtn} onClick={() => setFormData(prev => ({ ...prev, foto_url: '' }))}>Quitar foto</button>
              )}
              <input ref={fileInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleFileUpload} />
            </div>
            <div style={S.emojiHint}>Si no subes foto, se usa el emoji como icono.</div>

            <label style={S.label}>Emoji (icono si no hay foto)</label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 4 }}>
              {EMOJI_OPTIONS.map(em => (
                <div
                  key={em}
                  onClick={() => setFormData(prev => ({ ...prev, emoji: em }))}
                  style={{ fontSize: 20, padding: 6, borderRadius: 8, cursor: 'pointer', background: formData.emoji === em ? '#e8c97a' : '#111', border: '0.5px solid #3a2e20' }}
                >{em}</div>
              ))}
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 16 }}>
              <div style={S.toggleSwitch(formData.disponible !== false)} onClick={() => setFormData(prev => ({ ...prev, disponible: prev.disponible === false }))}>
                <div style={S.toggleDot(formData.disponible !== false)}></div>
              </div>
              <span style={{ fontSize: 13, color: '#8a7560' }}>{formData.disponible !== false ? 'Disponible para clientes' : 'No disponible (oculto)'}</span>
            </div>

            <div style={S.modalBtns}>
              <button style={S.cancelBtn} onClick={closeModal}>Cancelar</button>
              {editingItem !== 'new' && <button style={S.deleteBtn} onClick={deleteItem}>Eliminar</button>}
              <button style={S.saveBtn(saving)} onClick={saveItem} disabled={saving}>{saving ? 'Guardando...' : 'Guardar'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
