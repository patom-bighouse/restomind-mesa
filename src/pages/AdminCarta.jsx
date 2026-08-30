import { useState, useEffect, useRef, Fragment } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { formatMoney, getCurrencySymbol } from '../lib/money'
import { useRestaurantModulos } from '../lib/modulos'
import { IDIOMAS_CARTA } from '../lib/idiomas'

// Los 14 alérgenos del Anexo II del Reglamento UE 1169/2011. Es un
// catálogo fijo por ley, no configurable por restaurante — por eso vive
// acá en código y no en una tabla editable como sectores_cocina.
const ALERGENOS = [
  { key: 'gluten', label: 'Gluten', emoji: '🌾' },
  { key: 'crustaceos', label: 'Crustáceos', emoji: '🦐' },
  { key: 'huevos', label: 'Huevos', emoji: '🥚' },
  { key: 'pescado', label: 'Pescado', emoji: '🐟' },
  { key: 'cacahuetes', label: 'Cacahuetes', emoji: '🥜' },
  { key: 'soja', label: 'Soja', emoji: '🫘' },
  { key: 'lacteos', label: 'Lácteos', emoji: '🥛' },
  { key: 'frutos_cascara', label: 'Frutos de cáscara', emoji: '🌰' },
  { key: 'apio', label: 'Apio', emoji: '🥬' },
  { key: 'mostaza', label: 'Mostaza', emoji: '🟡' },
  { key: 'sesamo', label: 'Sésamo', emoji: '◯' },
  { key: 'sulfitos', label: 'Sulfitos', emoji: '🍷' },
  { key: 'altramuces', label: 'Altramuces', emoji: '🫛' },
  { key: 'moluscos', label: 'Moluscos', emoji: '🐚' },
]

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
  const { tieneModulo } = useRestaurantModulos(restaurantId)
  const [restaurant, setRestaurant] = useState(null)
  const [categories, setCategories] = useState([])
  const [items, setItems] = useState([])
  const [sectores, setSectores] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [newCatName, setNewCatName] = useState('')
  const [modGrupos, setModGrupos] = useState([]) // [{id, nombre, orden, opciones: [{id, nombre, orden}]}]
  const [showModGestion, setShowModGestion] = useState(false)
  const [showTraducciones, setShowTraducciones] = useState(false)
  const [idiomasSeleccionados, setIdiomasSeleccionados] = useState([])
  const [traduciendo, setTraduciendo] = useState(false)
  const [traduccionMsg, setTraduccionMsg] = useState(null)
  const [traduccionError, setTraduccionError] = useState(null)
  const [nuevoGrupoNombre, setNuevoGrupoNombre] = useState('')

  // Importador de carta con foto (IA)
  const [showImportador, setShowImportador] = useState(false)
  const [imagenesImportador, setImagenesImportador] = useState([]) // [{ nombre, dataUri }]
  const [extrayendo, setExtrayendo] = useState(false)
  const [importadorError, setImportadorError] = useState(null)
  const [categoriasExtraidas, setCategoriasExtraidas] = useState(null) // null = todavía no se extrajo nada
  const [importando, setImportando] = useState(false)
  const [importadorMsg, setImportadorMsg] = useState(null)
  const [ultimaImportacion, setUltimaImportacion] = useState(null) // { categoriaIds, itemIds } | null
  const [deshaciendo, setDeshaciendo] = useState(false)
  const importadorFileRef = useRef(null)

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
    const { data: rest } = await supabase.from('restaurants').select('nombre, moneda, config').eq('id', restaurantId).single()
    setRestaurant(rest)

    const { data: cats, error: catErr } = await supabase
      .from('categories').select('id, nombre, orden, activa')
      .eq('restaurant_id', restaurantId).order('orden')
    if (catErr) { setError(catErr.message); setLoading(false); return }
    setCategories(cats || [])

    const { data: menuItems, error: itemErr } = await supabase
      .from('menu_items').select('id, nombre, descripcion, precio, precio_costo, emoji, foto_url, category_id, disponible, orden, sector_cocina_id, alergenos')
      .eq('restaurant_id', restaurantId).order('orden')
    if (itemErr) { setError(itemErr.message); setLoading(false); return }
    setItems(menuItems || [])

    if (rest?.config?.sectores_cocina_activo) {
      const { data: secs } = await supabase
        .from('sectores_cocina').select('id, nombre, orden')
        .eq('restaurant_id', restaurantId).order('orden')
      setSectores(secs || [])
    }

    await loadModGrupos()
    setLoading(false)
  }

  async function loadModGrupos() {
    const { data: grupos } = await supabase
      .from('modificador_grupos').select('id, nombre, orden')
      .eq('restaurant_id', restaurantId).order('orden')
    const gruposConOpciones = []
    for (const g of (grupos || [])) {
      const { data: opciones } = await supabase
        .from('modificador_opciones').select('id, nombre, orden')
        .eq('grupo_id', g.id).order('orden')
      gruposConOpciones.push({ ...g, opciones: opciones || [] })
    }
    setModGrupos(gruposConOpciones)
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

  // ---------- Modificadores: catálogo (grupos y opciones) ----------
  async function addModGrupo() {
    if (!nuevoGrupoNombre.trim()) return
    const orden = modGrupos.length ? Math.max(...modGrupos.map(g => g.orden)) + 1 : 1
    const { data, error: err } = await supabase
      .from('modificador_grupos')
      .insert({ restaurant_id: restaurantId, nombre: nuevoGrupoNombre.trim(), orden })
      .select().single()
    if (err) { setError(err.message); return }
    setModGrupos(prev => [...prev, { ...data, opciones: [] }])
    setNuevoGrupoNombre('')
  }

  async function renameModGrupo(grupo, nuevoNombre) {
    if (!nuevoNombre.trim() || nuevoNombre === grupo.nombre) return
    await supabase.from('modificador_grupos').update({ nombre: nuevoNombre.trim() }).eq('id', grupo.id)
    setModGrupos(prev => prev.map(g => g.id === grupo.id ? { ...g, nombre: nuevoNombre.trim() } : g))
  }

  async function deleteModGrupo(grupo) {
    if (!window.confirm(`¿Eliminar el grupo "${grupo.nombre}"? Se quitará de todos los platos que lo tengan asignado.`)) return
    const { error: err } = await supabase.from('modificador_grupos').delete().eq('id', grupo.id)
    if (err) { setError(err.message); return }
    setModGrupos(prev => prev.filter(g => g.id !== grupo.id))
  }

  function toggleIdiomaSeleccionado(key) {
    setIdiomasSeleccionados(prev => prev.includes(key) ? prev.filter(k => k !== key) : [...prev, key])
  }

  // Llama a la función de servidor (nunca desde el navegador: la clave
  // de Anthropic es de la plataforma, no debe salir del backend) que
  // traduce toda la carta a los idiomas elegidos y guarda el resultado
  // en menu_item_traducciones — Mesa.jsx solo lee lo que quede ahí.
  async function traducirCarta() {
    if (idiomasSeleccionados.length === 0) return
    setTraduciendo(true)
    setTraduccionError(null)
    setTraduccionMsg(null)
    const { data, error: err } = await supabase.functions.invoke('traducir-carta', {
      body: { restaurant_id: restaurantId, idiomas: idiomasSeleccionados },
    })
    setTraduciendo(false)
    if (err || data?.error) {
      let msg = data?.error || err.message
      // supabase-js no expone el cuerpo de la respuesta cuando la
      // función devuelve un status distinto de 2xx — hay que leerlo
      // del Response crudo para ver el motivo real, no el genérico
      // "Edge Function returned a non-2xx status code".
      if (err?.context?.json) {
        try { const body = await err.context.json(); if (body?.error) msg = body.error } catch { /* noop */ }
      }
      setTraduccionError(msg)
      return
    }
    const resumen = Object.entries(data.traducidos || {}).map(([k, n]) => `${IDIOMAS_CARTA.find(i => i.key === k)?.label || k}: ${n} elementos`).join(' · ')
    setTraduccionMsg(resumen || 'Carta traducida.')
    const { data: rest } = await supabase.from('restaurants').select('nombre, moneda, config').eq('id', restaurantId).single()
    setRestaurant(rest)
  }

  // ---------- Copia de seguridad de la carta ----------
  // El importador de fotos solo AGREGA categorías/platos, nunca borra
  // ni sobreescribe lo que ya había — pero de todas formas conviene
  // tener un archivo al que volver antes de probarlo.
  function descargarCopiaCarta() {
    const contenido = {
      restaurante: restaurant?.nombre || null,
      exportado_en: new Date().toISOString(),
      categorias: categories.map(cat => ({
        nombre: cat.nombre,
        orden: cat.orden,
        activa: cat.activa,
        platos: items.filter(i => i.category_id === cat.id).map(i => ({
          nombre: i.nombre,
          descripcion: i.descripcion,
          precio: i.precio,
          precio_costo: i.precio_costo,
          alergenos: i.alergenos,
          emoji: i.emoji,
          foto_url: i.foto_url,
          disponible: i.disponible,
          orden: i.orden,
        })),
      })),
    }
    const blob = new Blob([JSON.stringify(contenido, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `carta-${(restaurant?.nombre || 'restomind').toLowerCase().replace(/\s+/g, '-')}-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  // ---------- Importador de carta con foto (IA) ----------
  function resizeImagen(file, maxAncho = 1400, calidad = 0.75) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onerror = reject
      reader.onload = () => {
        const img = new Image()
        img.onerror = reject
        img.onload = () => {
          const escala = Math.min(1, maxAncho / img.width)
          const canvas = document.createElement('canvas')
          canvas.width = img.width * escala
          canvas.height = img.height * escala
          const ctx = canvas.getContext('2d')
          ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
          resolve(canvas.toDataURL('image/jpeg', calidad))
        }
        img.src = reader.result
      }
      reader.readAsDataURL(file)
    })
  }

  async function manejarSeleccionImagenes(e) {
    const files = Array.from(e.target.files || [])
    if (!files.length) return
    setImportadorError(null)
    const nuevas = await Promise.all(files.map(async f => ({ nombre: f.name, dataUri: await resizeImagen(f) })))
    setImagenesImportador(prev => [...prev, ...nuevas].slice(0, 6))
    e.target.value = ''
  }

  function quitarImagenImportador(idx) {
    setImagenesImportador(prev => prev.filter((_, i) => i !== idx))
  }

  async function extraerCarta() {
    if (!imagenesImportador.length) return
    setExtrayendo(true)
    setImportadorError(null)
    setImportadorMsg(null)
    setUltimaImportacion(null)
    const { data, error: err } = await supabase.functions.invoke('importar-carta', {
      body: { restaurant_id: restaurantId, imagenes: imagenesImportador.map(i => i.dataUri) },
    })
    setExtrayendo(false)
    if (err || data?.error) {
      let msg = data?.error || err.message
      if (err?.context?.json) {
        try { const body = await err.context.json(); if (body?.error) msg = body.error } catch { /* noop */ }
      }
      setImportadorError(msg)
      return
    }
    setCategoriasExtraidas(
      (data.categorias || []).map(cat => ({
        nombre: cat.nombre,
        platos: (cat.platos || []).map(p => ({ ...p, incluido: true })),
      }))
    )
  }

  function actualizarCategoriaExtraida(catIdx, nombre) {
    setCategoriasExtraidas(prev => prev.map((c, i) => i === catIdx ? { ...c, nombre } : c))
  }

  function actualizarPlatoExtraido(catIdx, platoIdx, patch) {
    setCategoriasExtraidas(prev => prev.map((c, i) => {
      if (i !== catIdx) return c
      return { ...c, platos: c.platos.map((p, j) => j === platoIdx ? { ...p, ...patch } : p) }
    }))
  }

  function cancelarImportacion() {
    setCategoriasExtraidas(null)
    setImagenesImportador([])
    setImportadorError(null)
  }

  async function confirmarImportacion() {
    setImportando(true)
    setImportadorError(null)
    const categoriaIdsCreadas = []
    const itemIdsCreados = []
    try {
      let categoriasActuales = [...categories]
      for (const cat of categoriasExtraidas) {
        const platosIncluidos = cat.platos.filter(p => p.incluido && p.nombre?.trim())
        if (!platosIncluidos.length) continue

        let categoria = categoriasActuales.find(c => c.nombre.trim().toLowerCase() === cat.nombre.trim().toLowerCase())
        if (!categoria) {
          const orden = categoriasActuales.length ? Math.max(...categoriasActuales.map(c => c.orden)) + 1 : 1
          const { data, error: err } = await supabase
            .from('categories')
            .insert({ restaurant_id: restaurantId, nombre: cat.nombre.trim(), orden, activa: true })
            .select().single()
          if (err) throw err
          categoria = data
          categoriasActuales = [...categoriasActuales, categoria]
          categoriaIdsCreadas.push(categoria.id)
        }

        const itemsEnCat = items.filter(i => i.category_id === categoria.id)
        let orden = itemsEnCat.length ? Math.max(...itemsEnCat.map(i => i.orden)) : 0
        const filas = platosIncluidos.map(p => {
          orden += 1
          return {
            restaurant_id: restaurantId,
            category_id: categoria.id,
            nombre: p.nombre.trim(),
            descripcion: p.descripcion?.trim() || null,
            precio: parseFloat(p.precio) || 0,
            emoji: '🍽',
            disponible: true,
            orden,
          }
        })
        const { data: itemsCreados, error: insErr } = await supabase.from('menu_items').insert(filas).select('id')
        if (insErr) throw insErr
        itemIdsCreados.push(...itemsCreados.map(i => i.id))
      }

      setImportadorMsg(`Importado: ${categoriaIdsCreadas.length} categoría(s) nueva(s), ${itemIdsCreados.length} plato(s).`)
      setUltimaImportacion({ categoriaIds: categoriaIdsCreadas, itemIds: itemIdsCreados })
      setCategoriasExtraidas(null)
      setImagenesImportador([])
      await loadData()
    } catch (e) {
      setImportadorError(e.message)
    } finally {
      setImportando(false)
    }
  }

  // Borra exactamente lo que la última importación creó — y nada más:
  // ni toca las categorías que ya existían y solo recibieron platos
  // nuevos, ni nada que hubiera antes. Solo disponible justo después
  // de importar, mientras siga en esta pantalla.
  async function deshacerImportacion() {
    if (!ultimaImportacion) return
    if (!window.confirm('¿Deshacer la última importación? Se eliminarán los platos y categorías que se acaban de crear.')) return
    setDeshaciendo(true)
    setImportadorError(null)
    try {
      if (ultimaImportacion.itemIds.length) {
        const { error: err } = await supabase.from('menu_items').delete().in('id', ultimaImportacion.itemIds)
        if (err) throw err
      }
      if (ultimaImportacion.categoriaIds.length) {
        const { error: err } = await supabase.from('categories').delete().in('id', ultimaImportacion.categoriaIds)
        if (err) throw err
      }
      setUltimaImportacion(null)
      setImportadorMsg('Importación deshecha — la carta volvió a como estaba.')
      await loadData()
    } catch (e) {
      setImportadorError(e.message)
    } finally {
      setDeshaciendo(false)
    }
  }

  async function addModOpcion(grupo, nombre) {
    if (!nombre.trim()) return
    const orden = grupo.opciones.length ? Math.max(...grupo.opciones.map(o => o.orden)) + 1 : 1
    const { data, error: err } = await supabase
      .from('modificador_opciones')
      .insert({ grupo_id: grupo.id, nombre: nombre.trim(), orden })
      .select().single()
    if (err) { setError(err.message); return }
    setModGrupos(prev => prev.map(g => g.id === grupo.id ? { ...g, opciones: [...g.opciones, data] } : g))
  }

  async function renameModOpcion(grupo, opcion, nuevoNombre) {
    if (!nuevoNombre.trim() || nuevoNombre === opcion.nombre) return
    await supabase.from('modificador_opciones').update({ nombre: nuevoNombre.trim() }).eq('id', opcion.id)
    setModGrupos(prev => prev.map(g => g.id === grupo.id
      ? { ...g, opciones: g.opciones.map(o => o.id === opcion.id ? { ...o, nombre: nuevoNombre.trim() } : o) }
      : g))
  }

  async function deleteModOpcion(grupo, opcion) {
    if (!window.confirm(`¿Eliminar la opción "${opcion.nombre}"?`)) return
    const { error: err } = await supabase.from('modificador_opciones').delete().eq('id', opcion.id)
    if (err) { setError(err.message); return }
    setModGrupos(prev => prev.map(g => g.id === grupo.id
      ? { ...g, opciones: g.opciones.filter(o => o.id !== opcion.id) }
      : g))
  }

  // ---------- Modificadores: asignación a un plato ----------
  // formData.modSeleccion: { [grupo_id]: { activo, obligatorio, tipo_seleccion, precios: { [opcion_id]: '3.50' } } }
  async function loadModsDelItem(item) {
    const { data: asignados } = await supabase
      .from('menu_item_modificador_grupos')
      .select('grupo_id, obligatorio, tipo_seleccion')
      .eq('menu_item_id', item.id)
    const { data: precios } = await supabase
      .from('menu_item_modificador_precios')
      .select('opcion_id, precio_extra')
      .eq('menu_item_id', item.id)
    const modSeleccion = {}
    ;(asignados || []).forEach(a => {
      modSeleccion[a.grupo_id] = { activo: true, obligatorio: a.obligatorio, tipo_seleccion: a.tipo_seleccion, precios: {} }
    })
    ;(precios || []).forEach(p => {
      const grupo = modGrupos.find(g => g.opciones.some(o => o.id === p.opcion_id))
      if (grupo && modSeleccion[grupo.id]) {
        modSeleccion[grupo.id].precios[p.opcion_id] = String(p.precio_extra)
      }
    })
    return modSeleccion
  }
  function openNewItem(categoryId) {
    setEditingCatId(categoryId)
    setEditingItem('new')
    setFormData({ nombre: '', descripcion: '', precio: '', precio_costo: '', emoji: '🍽', foto_url: '', disponible: true, sector_cocina_id: '', alergenos: [], modSeleccion: {} })
  }

  async function openEditItem(item) {
    setEditingCatId(item.category_id)
    setEditingItem(item)
    setFormData({ ...item, modSeleccion: {} })
    const modSeleccion = await loadModsDelItem(item)
    setFormData(prev => ({ ...prev, modSeleccion }))
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
      precio_costo: formData.precio_costo !== '' && formData.precio_costo != null ? parseFloat(formData.precio_costo) : null,
      sector_cocina_id: formData.sector_cocina_id || null,
      alergenos: formData.alergenos || [],
      emoji: formData.emoji || '🍽',
      foto_url: formData.foto_url || null,
      disponible: formData.disponible !== false,
      category_id: targetCatId,
    }

    let menuItemId = null
    if (editingItem === 'new') {
      const itemsInCat = items.filter(i => i.category_id === targetCatId)
      const orden = itemsInCat.length ? Math.max(...itemsInCat.map(i => i.orden)) + 1 : 1
      const { data, error: err } = await supabase
        .from('menu_items')
        .insert({ ...payload, restaurant_id: restaurantId, orden })
        .select().single()
      if (err) { setError(err.message); setSaving(false); return }
      setItems(prev => [...prev, data])
      menuItemId = data.id
    } else {
      const { error: err } = await supabase.from('menu_items').update(payload).eq('id', editingItem.id)
      if (err) { setError(err.message); setSaving(false); return }
      setItems(prev => prev.map(i => i.id === editingItem.id ? { ...i, ...payload } : i))
      menuItemId = editingItem.id
    }

    // Reemplazar por completo la asignación de modificadores de este
    // plato (más simple y menos propenso a errores que ir comparando
    // qué cambió puntualmente).
    await supabase.from('menu_item_modificador_grupos').delete().eq('menu_item_id', menuItemId)
    await supabase.from('menu_item_modificador_precios').delete().eq('menu_item_id', menuItemId)
    const gruposActivos = Object.entries(formData.modSeleccion || {}).filter(([, v]) => v.activo)
    for (const [grupoId, sel] of gruposActivos) {
      await supabase.from('menu_item_modificador_grupos').insert({
        menu_item_id: menuItemId,
        grupo_id: grupoId,
        obligatorio: !!sel.obligatorio,
        tipo_seleccion: sel.tipo_seleccion || 'unica',
      })
      const grupo = modGrupos.find(g => g.id === grupoId)
      if (grupo) {
        const filasPrecios = grupo.opciones.map(o => ({
          menu_item_id: menuItemId,
          opcion_id: o.id,
          precio_extra: parseFloat(sel.precios?.[o.id] || 0) || 0,
        }))
        if (filasPrecios.length) {
          await supabase.from('menu_item_modificador_precios').insert(filasPrecios)
        }
      }
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
          {tieneModulo('reportes') && <a href={`/admin/dashboard/${restaurantId}`} style={S.navTab(false)}>Dashboard</a>}
          <a href={`/admin/mesas/${restaurantId}`} style={S.navTab(false)}>Mesas</a>
          <a href={`/admin/carta/${restaurantId}`} style={S.navTab(true)}>Carta</a>
          <a href={`/admin/menus/${restaurantId}`} style={S.navTab(false)}>Menús</a>
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
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
          <div style={S.sectionTitle}>Gestión de carta</div>
          <button
            onClick={descargarCopiaCarta}
            style={{ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 12px', fontSize: 12, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
          >
            ⬇ Descargar copia de la carta
          </button>
        </div>
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

        {/* Gestión de modificadores (catálogo reutilizable de grupos y opciones) */}
        <div style={{ background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '14px 18px', marginBottom: 20 }}>
          <div
            style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }}
            onClick={() => setShowModGestion(!showModGestion)}
          >
            <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a' }}>Modificadores de plato ({modGrupos.length})</div>
            <span style={{ color: '#8a7560', fontSize: 12 }}>{showModGestion ? '▲ ocultar' : '▼ gestionar'}</span>
          </div>
          {showModGestion && (
            <div style={{ marginTop: 14 }}>
              <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 12 }}>
                Grupos reutilizables (ej: "Punto de cocción", "Tamaño"). El precio extra de cada opción se define por plato, dentro de la ficha de cada uno.
              </div>
              {modGrupos.map(grupo => (
                <div key={grupo.id} style={{ background: '#141414', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: '10px 14px', marginBottom: 10 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                    <input
                      style={{ ...S.catInput, flex: 1, padding: '6px 10px', fontSize: 13 }}
                      defaultValue={grupo.nombre}
                      onBlur={e => renameModGrupo(grupo, e.target.value)}
                    />
                    <button style={{ ...S.iconBtn, color: '#e87a7a' }} onClick={() => deleteModGrupo(grupo)}>🗑</button>
                  </div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 8 }}>
                    {grupo.opciones.map(op => (
                      <span key={op.id} style={{ display: 'flex', alignItems: 'center', gap: 4, background: '#2a2a2a', borderRadius: 14, padding: '3px 4px 3px 10px', fontSize: 12, color: '#f0e8d8' }}>
                        <input
                          defaultValue={op.nombre}
                          onBlur={e => renameModOpcion(grupo, op, e.target.value)}
                          style={{ background: 'transparent', border: 'none', color: '#f0e8d8', fontSize: 12, width: Math.max(40, op.nombre.length * 7) }}
                        />
                        <button onClick={() => deleteModOpcion(grupo, op)} style={{ background: 'transparent', border: 'none', color: '#8a7560', cursor: 'pointer', fontSize: 12 }}>×</button>
                      </span>
                    ))}
                  </div>
                  <NuevaOpcionInput onAdd={nombre => addModOpcion(grupo, nombre)} />
                </div>
              ))}
              <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                <input
                  style={{ ...S.catInput, flex: 1 }}
                  placeholder="Nuevo grupo (ej. Punto de cocción)"
                  value={nuevoGrupoNombre}
                  onChange={e => setNuevoGrupoNombre(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && addModGrupo()}
                />
                <button style={S.addBtn} onClick={addModGrupo}>+ Añadir grupo</button>
              </div>
            </div>
          )}
        </div>

        {/* Carta multiidioma con IA — solo si el dueño tiene el módulo activo */}
        {tieneModulo('multiidioma') && (
          <div style={{ background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '14px 18px', marginBottom: 20 }}>
            <div
              style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }}
              onClick={() => setShowTraducciones(!showTraducciones)}
            >
              <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a' }}>
                Carta multiidioma con IA {restaurant?.config?.idiomas_carta?.length > 0 && `(${restaurant.config.idiomas_carta.length} activos)`}
              </div>
              <span style={{ color: '#8a7560', fontSize: 12 }}>{showTraducciones ? '▲ ocultar' : '▼ gestionar'}</span>
            </div>
            {showTraducciones && (
              <div style={{ marginTop: 14 }}>
                <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 12 }}>
                  Traduce con IA los platos, categorías, modificadores y mensajes de sugerencia de
                  toda la carta. Se guarda una sola vez — vuelve a traducir cuando cambies algo de
                  esto. El comensal podrá elegir el idioma desde Mesa.jsx. Los alérgenos ya están
                  traducidos (catálogo fijo, no hace falta IA).
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
                  {IDIOMAS_CARTA.map(idi => {
                    const activo = restaurant?.config?.idiomas_carta?.includes(idi.key)
                    const marcado = idiomasSeleccionados.includes(idi.key)
                    return (
                      <button
                        key={idi.key}
                        onClick={() => toggleIdiomaSeleccionado(idi.key)}
                        style={{
                          background: marcado ? '#e8c97a' : '#111',
                          color: marcado ? '#111' : '#8a7560',
                          border: `0.5px solid ${marcado ? '#e8c97a' : '#3a2e20'}`,
                          borderRadius: 20, padding: '6px 14px', fontSize: 13, cursor: 'pointer', fontFamily: "'Inter', sans-serif",
                        }}
                      >
                        {idi.bandera} {idi.label}{activo ? ' ✓' : ''}
                      </button>
                    )
                  })}
                </div>
                {traduccionError && <div style={{ ...S.error, marginBottom: 12 }}>{traduccionError}</div>}
                {traduccionMsg && <div style={{ fontSize: 12, color: '#7ae8a0', marginBottom: 12 }}>{traduccionMsg}</div>}
                <button
                  style={S.addBtn}
                  onClick={traducirCarta}
                  disabled={traduciendo || idiomasSeleccionados.length === 0}
                >
                  {traduciendo ? 'Traduciendo...' : `Traducir a ${idiomasSeleccionados.length || ''} idioma(s)`}
                </button>
              </div>
            )}
          </div>
        )}

        {/* Importador de carta con foto (IA) — solo si el dueño tiene el módulo activo */}
        {tieneModulo('importador_carta') && (
          <div style={{ background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 12, padding: '14px 18px', marginBottom: 20 }}>
            <div
              style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }}
              onClick={() => setShowImportador(!showImportador)}
            >
              <div style={{ fontSize: 14, fontWeight: 500, color: '#c4a85a' }}>Importar carta con foto (IA)</div>
              <span style={{ color: '#8a7560', fontSize: 12 }}>{showImportador ? '▲ ocultar' : '▼ gestionar'}</span>
            </div>
            {showImportador && (
              <div style={{ marginTop: 14 }}>
                <div style={{ fontSize: 12, color: '#7a6a50', marginBottom: 12 }}>
                  Sube fotos de tu carta impresa (hasta 6) — la IA extrae categorías y platos. Nada se
                  guarda todavía: podrás revisar y corregir cada plato antes de confirmar. Solo agrega
                  platos nuevos, nunca borra ni modifica lo que ya tienes.
                </div>

                {importadorError && <div style={{ ...S.error, marginBottom: 12 }}>{importadorError}</div>}
                {importadorMsg && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
                    <div style={{ fontSize: 12, color: '#7ae8a0' }}>{importadorMsg}</div>
                    {ultimaImportacion && (
                      <button
                        onClick={deshacerImportacion}
                        disabled={deshaciendo}
                        style={{ background: 'transparent', border: '0.5px solid #6a2e20', borderRadius: 8, padding: '4px 10px', fontSize: 11, color: '#e87a7a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
                      >
                        {deshaciendo ? 'Deshaciendo...' : '↩ Deshacer esta importación'}
                      </button>
                    )}
                  </div>
                )}

                {!categoriasExtraidas && (
                  <>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginBottom: 12 }}>
                      {imagenesImportador.map((img, idx) => (
                        <div key={idx} style={{ position: 'relative' }}>
                          <img src={img.dataUri} alt={img.nombre} style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 8, border: '0.5px solid #3a2e20' }} />
                          <button
                            onClick={() => quitarImagenImportador(idx)}
                            style={{ position: 'absolute', top: -6, right: -6, background: '#e74c3c', color: '#fff', border: 'none', borderRadius: '50%', width: 20, height: 20, fontSize: 12, cursor: 'pointer' }}
                          >×</button>
                        </div>
                      ))}
                      {imagenesImportador.length < 6 && (
                        <button
                          onClick={() => importadorFileRef.current?.click()}
                          style={{ width: 80, height: 80, background: '#111', border: '1px dashed #3a2e20', borderRadius: 8, color: '#8a7560', fontSize: 24, cursor: 'pointer' }}
                        >+</button>
                      )}
                      <input ref={importadorFileRef} type="file" accept="image/*" multiple hidden onChange={manejarSeleccionImagenes} />
                    </div>
                    <button
                      style={S.addBtn}
                      onClick={extraerCarta}
                      disabled={extrayendo || imagenesImportador.length === 0}
                    >
                      {extrayendo ? 'Leyendo la carta...' : 'Extraer con IA'}
                    </button>
                  </>
                )}

                {categoriasExtraidas && (
                  <div>
                    {categoriasExtraidas.map((cat, catIdx) => (
                      <div key={catIdx} style={{ marginBottom: 16 }}>
                        <input
                          value={cat.nombre}
                          onChange={e => actualizarCategoriaExtraida(catIdx, e.target.value)}
                          style={{ ...S.catInput, fontSize: 13, fontWeight: 600, color: '#e8c97a', marginBottom: 8, maxWidth: 260 }}
                        />
                        {cat.platos.map((p, platoIdx) => (
                          <div key={platoIdx} style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '6px 0', borderBottom: '0.5px solid #2a2a2a', opacity: p.incluido ? 1 : 0.4 }}>
                            <input
                              type="checkbox"
                              checked={p.incluido}
                              onChange={e => actualizarPlatoExtraido(catIdx, platoIdx, { incluido: e.target.checked })}
                            />
                            <input
                              value={p.nombre}
                              onChange={e => actualizarPlatoExtraido(catIdx, platoIdx, { nombre: e.target.value })}
                              style={{ ...S.catInput, flex: 2, fontSize: 13 }}
                            />
                            <input
                              value={p.descripcion || ''}
                              placeholder="Descripción (opcional)"
                              onChange={e => actualizarPlatoExtraido(catIdx, platoIdx, { descripcion: e.target.value })}
                              style={{ ...S.catInput, flex: 3, fontSize: 13 }}
                            />
                            <input
                              type="number" step="0.01" min="0"
                              value={p.precio}
                              onChange={e => actualizarPlatoExtraido(catIdx, platoIdx, { precio: e.target.value })}
                              style={{ ...S.catInput, width: 80, fontSize: 13 }}
                            />
                          </div>
                        ))}
                      </div>
                    ))}
                    <div style={{ display: 'flex', gap: 10, marginTop: 10 }}>
                      <button style={S.cancelBtn} onClick={cancelarImportacion}>Cancelar</button>
                      <button style={S.addBtn} onClick={confirmarImportacion} disabled={importando}>
                        {importando ? 'Importando...' : 'Importar a la carta'}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

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
                        <div style={S.itemPrice}>{formatMoney(item.precio, restaurant?.moneda)}</div>
                        {item.precio_costo != null && item.precio > 0 && (
                          <div style={{ fontSize: 11, color: '#8a8a8a' }}>
                            Margen: {formatMoney(item.precio - item.precio_costo, restaurant?.moneda)} ({(((item.precio - item.precio_costo) / item.precio) * 100).toFixed(0)}%)
                          </div>
                        )}
                        {restaurant?.config?.sectores_cocina_activo && item.sector_cocina_id && (
                          <div style={{ fontSize: 11, color: '#c4a85a', marginTop: 2 }}>
                            {sectores.find(s => s.id === item.sector_cocina_id)?.nombre || ''}
                          </div>
                        )}
                        {item.alergenos && item.alergenos.length > 0 && (
                          <div style={{ fontSize: 14, marginTop: 3 }} title={item.alergenos.map(k => ALERGENOS.find(a => a.key === k)?.label).join(', ')}>
                            {item.alergenos.map(k => ALERGENOS.find(a => a.key === k)?.emoji).join(' ')}
                          </div>
                        )}
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

            <label style={S.label}>Precio ({getCurrencySymbol(restaurant?.moneda)}) *</label>
            <input style={S.input} type="number" step="0.01" min="0" value={formData.precio ?? ''} onChange={e => setFormData(prev => ({ ...prev, precio: e.target.value }))} placeholder="9.50" />

            <label style={S.label}>Precio de coste ({getCurrencySymbol(restaurant?.moneda)})</label>
            <input style={S.input} type="number" step="0.01" min="0" value={formData.precio_costo ?? ''} onChange={e => setFormData(prev => ({ ...prev, precio_costo: e.target.value }))} placeholder="Opcional, para calcular rentabilidad" />

            {restaurant?.config?.sectores_cocina_activo && (
              <>
                <label style={S.label}>Sector de cocina</label>
                <select
                  style={S.input}
                  value={formData.sector_cocina_id || ''}
                  onChange={e => setFormData(prev => ({ ...prev, sector_cocina_id: e.target.value }))}
                >
                  <option value="">General (sin sector)</option>
                  {sectores.map(s => (
                    <option key={s.id} value={s.id}>{s.nombre}</option>
                  ))}
                </select>
              </>
            )}

            <label style={S.label}>Alérgenos</label>
            <div style={{ fontSize: 11, color: '#7a6a50', marginBottom: 8, marginTop: -4 }}>
              Marca los que contenga este plato (Reglamento UE 1169/2011). El cliente los verá en la carta y podrá filtrar por ellos.
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '6px 12px', marginBottom: 16 }}>
              {ALERGENOS.map(a => {
                const checked = (formData.alergenos || []).includes(a.key)
                return (
                  <label key={a.key} style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, color: '#f0e8d8', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={e => {
                        setFormData(prev => {
                          const current = prev.alergenos || []
                          const next = e.target.checked ? [...current, a.key] : current.filter(k => k !== a.key)
                          return { ...prev, alergenos: next }
                        })
                      }}
                    />
                    <span>{a.emoji} {a.label}</span>
                  </label>
                )
              })}
            </div>

            {modGrupos.length > 0 && (
              <>
                <label style={S.label}>Modificadores</label>
                <div style={{ fontSize: 11, color: '#7a6a50', marginBottom: 8, marginTop: -4 }}>
                  Elige qué grupos aplican a este plato. El precio extra de cada opción es propio de este plato.
                </div>
                <div style={{ marginBottom: 16 }}>
                  {modGrupos.map(grupo => {
                    const sel = formData.modSeleccion?.[grupo.id] || { activo: false, obligatorio: false, tipo_seleccion: 'unica', precios: {} }
                    function updateSel(cambios) {
                      setFormData(prev => ({
                        ...prev,
                        modSeleccion: { ...prev.modSeleccion, [grupo.id]: { ...sel, ...cambios } },
                      }))
                    }
                    return (
                      <div key={grupo.id} style={{ background: '#141414', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: '10px 14px', marginBottom: 10 }}>
                        <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, color: '#f0e8d8', cursor: 'pointer', marginBottom: sel.activo ? 10 : 0 }}>
                          <input type="checkbox" checked={sel.activo} onChange={e => updateSel({ activo: e.target.checked })} />
                          <strong>{grupo.nombre}</strong>
                          <span style={{ color: '#7a6a50', fontSize: 11 }}>({grupo.opciones.length} opciones)</span>
                        </label>
                        {sel.activo && (
                          <>
                            <div style={{ display: 'flex', gap: 16, marginBottom: 10, flexWrap: 'wrap' }}>
                              <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: '#c4a85a', cursor: 'pointer' }}>
                                <input type="checkbox" checked={!!sel.obligatorio} onChange={e => updateSel({ obligatorio: e.target.checked })} />
                                Obligatorio elegir
                              </label>
                              <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: '#c4a85a' }}>
                                Selección:
                                <select
                                  value={sel.tipo_seleccion}
                                  onChange={e => updateSel({ tipo_seleccion: e.target.value })}
                                  style={{ background: '#0f0f0f', border: '0.5px solid #3a2e20', borderRadius: 6, padding: '3px 8px', fontSize: 12, color: '#f0e8d8', fontFamily: "'Inter', sans-serif" }}
                                >
                                  <option value="unica">Única (una opción)</option>
                                  <option value="multiple">Múltiple (varias opciones)</option>
                                </select>
                              </label>
                            </div>
                            {grupo.opciones.length === 0 ? (
                              <div style={{ fontSize: 11, color: '#7a6a50' }}>Este grupo todavía no tiene opciones — agregalas desde "Modificadores de plato" arriba.</div>
                            ) : (
                              <div style={{ display: 'grid', gridTemplateColumns: '1fr 100px', gap: '6px 10px', alignItems: 'center' }}>
                                {grupo.opciones.map(op => (
                                  <Fragment key={op.id}>
                                    <span style={{ fontSize: 12, color: '#f0e8d8' }}>{op.nombre}</span>
                                    <input
                                      type="number" step="0.01" min="0"
                                      placeholder="0.00"
                                      value={sel.precios?.[op.id] ?? ''}
                                      onChange={e => updateSel({ precios: { ...sel.precios, [op.id]: e.target.value } })}
                                      style={{ background: '#0f0f0f', border: '0.5px solid #3a2e20', borderRadius: 6, padding: '4px 8px', fontSize: 12, color: '#f0e8d8', fontFamily: "'Inter', sans-serif" }}
                                    />
                                  </Fragment>
                                ))}
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    )
                  })}
                </div>
              </>
            )}

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

// Input local para agregar una opción nueva a un grupo de modificadores.
// Vive como componente aparte para no necesitar un estado extra por
// cada grupo en el componente principal.
function NuevaOpcionInput({ onAdd }) {
  const [valor, setValor] = useState('')
  return (
    <div style={{ display: 'flex', gap: 6 }}>
      <input
        placeholder="Nueva opción (ej. Poco hecho)"
        value={valor}
        onChange={e => setValor(e.target.value)}
        onKeyDown={e => {
          if (e.key === 'Enter' && valor.trim()) {
            onAdd(valor.trim())
            setValor('')
          }
        }}
        style={{ background: '#0f0f0f', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '5px 10px', fontSize: 12, color: '#f0e8d8', flex: 1, fontFamily: "'Inter', sans-serif" }}
      />
      <button
        onClick={() => { if (valor.trim()) { onAdd(valor.trim()); setValor('') } }}
        style={{ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '5px 12px', fontSize: 12, color: '#c4a85a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
      >
        + opción
      </button>
    </div>
  )
}
