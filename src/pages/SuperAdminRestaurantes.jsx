import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { createClient } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { isValidIban, formatIbanDisplay } from '../lib/iban'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

const S = {
  app: { minHeight: '100vh', background: '#0a0a0a', color: '#f0f0f0', fontFamily: "'Inter', sans-serif" },
  header: { background: '#111', padding: '14px 24px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: '#e8c97a' },
  sub: { fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: '0.1em', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a8a8a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 24, maxWidth: 900, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 20 },
  error: { background: '#2a1414', border: '0.5px solid #5a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  success: { background: '#142a1a', border: '0.5px solid #2a5a3a', borderRadius: 10, padding: '14px 16px', fontSize: 13, color: '#7ae8a0', marginBottom: 16, lineHeight: 1.6 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },

  addBtn: { background: '#e8c97a', color: '#111', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", marginBottom: 24 },

  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: '0.06em', padding: '10px 14px', borderBottom: '0.5px solid #2a2a2a' },
  td: { padding: '14px', fontSize: 14, borderBottom: '0.5px solid #1a1a1a', verticalAlign: 'middle' },
  restName: { fontWeight: 500, color: '#f0f0f0' },
  restSlug: { fontSize: 12, color: '#666', marginTop: 2 },
  linkBtn: { background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 8, padding: '6px 12px', fontSize: 12, color: '#e8c97a', cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none', marginRight: 6, display: 'inline-block' },
  badge: (active) => ({ fontSize: 11, fontWeight: 500, padding: '3px 10px', borderRadius: 20, background: active ? '#142a1a' : '#2a1414', color: active ? '#2ecc71' : '#e74c3c' }),

  modal: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 50, padding: 20 },
  modalBox: { background: '#161616', border: '0.5px solid #2a2a2a', borderRadius: 16, padding: 24, width: '100%', maxWidth: 420 },
  modalTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 18 },
  label: { fontSize: 12, color: '#8a8a8a', marginBottom: 6, display: 'block', marginTop: 14 },
  input: { width: '100%', background: '#0a0a0a', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 14, color: '#f0f0f0', fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' },
  hint: { fontSize: 11, color: '#555', marginTop: 4 },
  modalBtns: { display: 'flex', gap: 10, marginTop: 22 },
  saveBtn: (disabled) => ({ flex: 1, background: disabled ? '#3a3a2a' : '#e8c97a', color: disabled ? '#888' : '#111', border: 'none', borderRadius: 10, padding: 12, fontSize: 14, fontWeight: 500, cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
  cancelBtn: { flex: 1, background: 'transparent', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: 12, fontSize: 14, color: '#8a8a8a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
}

function slugify(text) {
  return text.toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
}

// Mismos países/monedas habilitados en el check constraint de la base
// (restaurants_moneda_check). Si agregás una moneda nueva ahí, sumala acá
// también para que aparezca en el selector.
const PAISES = [
  { code: 'ES', label: 'España', moneda: 'EUR' },
  { code: 'MX', label: 'México', moneda: 'MXN' },
  { code: 'AR', label: 'Argentina', moneda: 'ARS' },
  { code: 'CO', label: 'Colombia', moneda: 'COP' },
  { code: 'CL', label: 'Chile', moneda: 'CLP' },
  { code: 'PE', label: 'Perú', moneda: 'PEN' },
  { code: 'US', label: 'Estados Unidos', moneda: 'USD' },
]
const MONEDAS = ['EUR', 'USD', 'MXN', 'ARS', 'COP', 'CLP', 'PEN']

export default function SuperAdminRestaurantes() {
  const navigate = useNavigate()
  const [restaurants, setRestaurants] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)

  const [modalMode, setModalMode] = useState(null) // null | 'create' | 'edit'
  const [editingId, setEditingId] = useState(null)
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState({
    nombre: '', email: '', password: '', whatsapp: '',
    pais: 'ES', moneda: 'EUR', direccion: '',
    iban: '', titularCuenta: '',
  })
  const [ibanTouched, setIbanTouched] = useState(false)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/superadmin/login'); return }
    const { data: sa } = await supabase.from('superadmins').select('id').eq('user_id', session.user.id).single()
    if (!sa) { navigate('/superadmin/login'); return }
    loadRestaurants()
  }

  async function loadRestaurants() {
    const { data, error: err } = await supabase
      .from('restaurants')
      .select('id, nombre, slug, whatsapp, activo, created_at, user_id, pais, moneda, direccion')
      .order('created_at', { ascending: false })
    if (err) { setError(err.message); setLoading(false); return }
    setRestaurants(data || [])
    setLoading(false)
  }

  function openCreateModal() {
    setForm({
      nombre: '', email: '', password: '', whatsapp: '',
      pais: 'ES', moneda: 'EUR', direccion: '',
      iban: '', titularCuenta: '',
    })
    setIbanTouched(false)
    setError(null)
    setSuccess(null)
    setEditingId(null)
    setModalMode('create')
  }

  async function openEditModal(rest) {
    setError(null)
    setSuccess(null)
    setIbanTouched(false)
    const { data: billing } = await supabase
      .from('restaurant_billing')
      .select('iban, titular_cuenta')
      .eq('restaurant_id', rest.id)
      .maybeSingle()
    setForm({
      nombre: rest.nombre || '',
      email: '', password: '',
      whatsapp: rest.whatsapp || '',
      pais: rest.pais || 'ES',
      moneda: rest.moneda || 'EUR',
      direccion: rest.direccion || '',
      iban: billing?.iban || '',
      titularCuenta: billing?.titular_cuenta || '',
    })
    setEditingId(rest.id)
    setModalMode('edit')
  }

  function handlePaisChange(code) {
    const pais = PAISES.find(p => p.code === code)
    setForm(prev => ({ ...prev, pais: code, moneda: pais?.moneda || prev.moneda }))
  }

  async function createRestaurant() {
    if (!form.nombre.trim() || !form.email.trim() || !form.password.trim()) {
      setError('Nombre, email y contraseña son obligatorios.')
      return
    }
    if (form.password.length < 6) {
      setError('La contraseña debe tener al menos 6 caracteres.')
      return
    }
    if (form.iban.trim() && !isValidIban(form.iban)) {
      setError('El IBAN no parece válido. Revisalo (o dejalo vacío y lo cargás más adelante).')
      return
    }
    setCreating(true)
    setError(null)

    try {
      // Cliente Supabase separado para no afectar la sesión del superadmin
      const tempClient = createClient(supabaseUrl, supabaseAnonKey)

      const { data: signUpData, error: signUpErr } = await tempClient.auth.signUp({
        email: form.email.trim(),
        password: form.password,
      })
      if (signUpErr) throw signUpErr
      if (!signUpData.user) throw new Error('No se pudo crear el usuario.')

      const newUserId = signUpData.user.id
      const slug = slugify(form.nombre)

      // Crear restaurante vinculado
      const { data: restData, error: restErr } = await supabase
        .from('restaurants')
        .insert({
          nombre: form.nombre.trim(),
          slug,
          whatsapp: form.whatsapp.trim() || null,
          direccion: form.direccion.trim() || null,
          pais: form.pais,
          moneda: form.moneda,
          user_id: newUserId,
          activo: true,
        })
        .select().single()
      if (restErr) throw restErr

      // Categoría demo
      const { data: catData, error: catErr } = await supabase
        .from('categories')
        .insert({ restaurant_id: restData.id, nombre: 'Entrantes', orden: 1, activa: true })
        .select().single()
      if (catErr) throw catErr

      // Plato demo
      await supabase.from('menu_items').insert({
        restaurant_id: restData.id,
        category_id: catData.id,
        nombre: 'Plato de bienvenida',
        descripcion: 'Edita o elimina este plato desde Gestión de carta',
        precio: 0,
        emoji: '🍽',
        disponible: true,
        orden: 1,
      })

      // Mesa demo
      await supabase.from('tables').insert({
        restaurant_id: restData.id,
        numero: 1,
        zona: 'interior',
        capacidad: 4,
        activa: true,
      })

      // Datos bancarios (opcional). Va en tabla separada, con RLS
      // restringida a superadmins — nunca se expone en el panel del
      // propio restaurante ni en ninguna pantalla de cliente.
      if (form.iban.trim()) {
        const { error: billErr } = await supabase.from('restaurant_billing').insert({
          restaurant_id: restData.id,
          iban: form.iban.replace(/\s+/g, '').toUpperCase(),
          titular_cuenta: form.titularCuenta.trim() || null,
        })
        if (billErr) throw billErr
      }

      setSuccess(`Restaurante "${form.nombre}" creado correctamente.\n\nAcceso del cliente: ${form.email} / (la contraseña que definiste)\nPanel: /admin/login`)
      setModalMode(null)
      loadRestaurants()
    } catch (e) {
      setError(e.message)
    } finally {
      setCreating(false)
    }
  }

  async function updateRestaurant() {
    if (!form.nombre.trim()) {
      setError('El nombre es obligatorio.')
      return
    }
    if (form.iban.trim() && !isValidIban(form.iban)) {
      setError('El IBAN no parece válido. Revisalo (o dejalo vacío).')
      return
    }
    setCreating(true)
    setError(null)
    try {
      const { error: restErr } = await supabase
        .from('restaurants')
        .update({
          nombre: form.nombre.trim(),
          whatsapp: form.whatsapp.trim() || null,
          direccion: form.direccion.trim() || null,
          pais: form.pais,
          moneda: form.moneda,
        })
        .eq('id', editingId)
      if (restErr) throw restErr

      // upsert: si ya había datos bancarios los actualiza, si no, los crea.
      // Si se vació el campo, en vez de dejar un IBAN viejo guardado, se borra.
      if (form.iban.trim()) {
        const { error: billErr } = await supabase
          .from('restaurant_billing')
          .upsert({
            restaurant_id: editingId,
            iban: form.iban.replace(/\s+/g, '').toUpperCase(),
            titular_cuenta: form.titularCuenta.trim() || null,
            updated_at: new Date().toISOString(),
          }, { onConflict: 'restaurant_id' })
        if (billErr) throw billErr
      } else {
        await supabase.from('restaurant_billing').delete().eq('restaurant_id', editingId)
      }

      setSuccess(`Restaurante "${form.nombre}" actualizado correctamente.`)
      setModalMode(null)
      loadRestaurants()
    } catch (e) {
      setError(e.message)
    } finally {
      setCreating(false)
    }
  }

  async function toggleActivo(rest) {
    const nuevo = !rest.activo
    const { error: err } = await supabase.from('restaurants').update({ activo: nuevo }).eq('id', rest.id)
    if (err) { setError(err.message); return }
    setRestaurants(prev => prev.map(r => r.id === rest.id ? { ...r, activo: nuevo } : r))
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
          <div style={S.sub}>Super Admin</div>
        </div>
        <button style={S.logoutBtn} onClick={handleLogout}>Cerrar sesión</button>
      </div>

      <div style={S.content}>
        <div style={S.sectionTitle}>Restaurantes ({restaurants.length})</div>
        {error && <div style={S.error}>{error}</div>}
        {success && <div style={S.success}>{success}</div>}

        <button style={S.addBtn} onClick={openCreateModal}>+ Nuevo restaurante</button>

        <table style={S.table}>
          <thead>
            <tr>
              <th style={S.th}>Restaurante</th>
              <th style={S.th}>País / Moneda</th>
              <th style={S.th}>WhatsApp</th>
              <th style={S.th}>Estado</th>
              <th style={S.th}>Accesos</th>
            </tr>
          </thead>
          <tbody>
            {restaurants.map(rest => (
              <tr key={rest.id}>
                <td style={S.td}>
                  <div style={S.restName}>{rest.nombre}</div>
                  <div style={S.restSlug}>{rest.slug} · {rest.id.slice(0, 8)}...</div>
                </td>
                <td style={S.td}>{PAISES.find(p => p.code === rest.pais)?.label || rest.pais || '—'} · {rest.moneda || '—'}</td>
                <td style={S.td}>{rest.whatsapp || '—'}</td>
                <td style={S.td}>
                  <span style={S.badge(rest.activo)} onClick={() => toggleActivo(rest)} role="button" title="Click para cambiar">
                    {rest.activo ? 'Activo' : 'Inactivo'}
                  </span>
                </td>
                <td style={S.td}>
                  <a href={`/admin/mesas/${rest.id}`} style={S.linkBtn} target="_blank" rel="noreferrer">Mesas</a>
                  <a href={`/admin/carta/${rest.id}`} style={S.linkBtn} target="_blank" rel="noreferrer">Carta</a>
                  <a href={`/cocina/${rest.id}`} style={S.linkBtn} target="_blank" rel="noreferrer">Cocina</a>
                  <button style={{ ...S.linkBtn, cursor: 'pointer' }} onClick={() => openEditModal(rest)}>Editar</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {restaurants.length === 0 && (
          <div style={{ fontSize: 14, color: '#555', textAlign: 'center', padding: '60px 0' }}>
            Aún no hay restaurantes. Crea el primero arriba.
          </div>
        )}
      </div>

      {modalMode && (
        <div style={S.modal} onClick={e => { if (e.target === e.currentTarget) setModalMode(null) }}>
          <div style={S.modalBox}>
            <div style={S.modalTitle}>{modalMode === 'create' ? 'Nuevo restaurante' : 'Editar restaurante'}</div>

            <label style={S.label}>Nombre del restaurante *</label>
            <input style={S.input} value={form.nombre} onChange={e => setForm(prev => ({ ...prev, nombre: e.target.value }))} placeholder="Ej. La Taberna del Puerto" />
            {modalMode === 'create' && form.nombre && <div style={S.hint}>slug: {slugify(form.nombre)}</div>}

            {modalMode === 'create' ? (
              <>
                <label style={S.label}>Email del dueño (acceso al panel) *</label>
                <input style={S.input} type="email" value={form.email} onChange={e => setForm(prev => ({ ...prev, email: e.target.value }))} placeholder="dueno@restaurante.com" />

                <label style={S.label}>Contraseña inicial *</label>
                <input style={S.input} type="text" value={form.password} onChange={e => setForm(prev => ({ ...prev, password: e.target.value }))} placeholder="mínimo 6 caracteres" />
                <div style={S.hint}>Compártesela al cliente; podrá usarla en /admin/login</div>
              </>
            ) : (
              <div style={S.hint}>Para cambiar el email de acceso, hacelo directamente desde Authentication → Users en Supabase.</div>
            )}

            <label style={S.label}>WhatsApp (opcional)</label>
            <input style={S.input} value={form.whatsapp} onChange={e => setForm(prev => ({ ...prev, whatsapp: e.target.value }))} placeholder="+34600000000" />

            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: 1 }}>
                <label style={S.label}>País</label>
                <select style={S.input} value={form.pais} onChange={e => handlePaisChange(e.target.value)}>
                  {PAISES.map(p => <option key={p.code} value={p.code}>{p.label}</option>)}
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label style={S.label}>Moneda</label>
                <select style={S.input} value={form.moneda} onChange={e => setForm(prev => ({ ...prev, moneda: e.target.value }))}>
                  {MONEDAS.map(m => <option key={m} value={m}>{m}</option>)}
                </select>
              </div>
            </div>
            <div style={S.hint}>La moneda se ajusta sola según el país, pero podés cambiarla si el restaurante factura en otra.</div>

            <label style={S.label}>Dirección (opcional)</label>
            <input style={S.input} value={form.direccion} onChange={e => setForm(prev => ({ ...prev, direccion: e.target.value }))} placeholder="Calle, número, ciudad" />

            <label style={S.label}>IBAN — para cobrar la suscripción más adelante (opcional)</label>
            <input
              style={S.input}
              value={form.iban}
              onChange={e => setForm(prev => ({ ...prev, iban: e.target.value }))}
              onBlur={() => setIbanTouched(true)}
              placeholder="ES91 2100 0418 4502 0005 1332"
            />
            {ibanTouched && form.iban.trim() && !isValidIban(form.iban) && (
              <div style={{ ...S.hint, color: '#e87a7a' }}>Ese IBAN no parece válido — revisalo.</div>
            )}
            {form.iban.trim() && isValidIban(form.iban) && (
              <div style={S.hint}>{formatIbanDisplay(form.iban)} ✓</div>
            )}
            <div style={S.hint}>
              {modalMode === 'create'
                ? 'Solo se guarda el dato — todavía no hay ningún cobro automático conectado.'
                : 'Dejar este campo vacío y guardar borra el IBAN guardado para este restaurante.'}
            </div>

            <label style={S.label}>Titular de la cuenta (opcional)</label>
            <input style={S.input} value={form.titularCuenta} onChange={e => setForm(prev => ({ ...prev, titularCuenta: e.target.value }))} placeholder="Nombre tal como figura en el banco" />

            <div style={S.modalBtns}>
              <button style={S.cancelBtn} onClick={() => setModalMode(null)}>Cancelar</button>
              <button
                style={S.saveBtn(creating)}
                onClick={modalMode === 'create' ? createRestaurant : updateRestaurant}
                disabled={creating}
              >
                {creating ? 'Guardando...' : modalMode === 'create' ? 'Crear restaurante' : 'Guardar cambios'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
