import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

const S = {
  app: { minHeight: '100vh', background: '#1a1410', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: "'Inter', sans-serif", padding: 20 },
  card: { background: '#221c14', border: '0.5px solid #3a2e20', borderRadius: 16, padding: 32, width: '100%', maxWidth: 380 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 26, fontWeight: 600, color: '#e8c97a', textAlign: 'center', marginBottom: 6 },
  sub: { fontSize: 13, color: '#7a6a50', textAlign: 'center', marginBottom: 32 },
  label: { fontSize: 13, color: '#8a7560', marginBottom: 6, display: 'block' },
  input: { width: '100%', background: '#1a1410', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '12px 14px', fontSize: 14, color: '#f0e8d8', fontFamily: "'Inter', sans-serif", outline: 'none', marginBottom: 16, boxSizing: 'border-box' },
  btn: (loading) => ({ width: '100%', background: loading ? '#5a4a2a' : '#e8c97a', color: loading ? '#8a7560' : '#1a1410', border: 'none', borderRadius: 10, padding: 14, fontSize: 15, fontWeight: 500, fontFamily: "'Inter', sans-serif", cursor: loading ? 'not-allowed' : 'pointer', marginTop: 8 }),
  error: { background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  ok: { background: '#1a2a14', border: '0.5px solid #2e6a20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#8ae87a', marginBottom: 16 },
}

export default function AdminRestablecer() {
  const [password, setPassword] = useState('')
  const [repetir, setRepetir] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [listo, setListo] = useState(false)
  const [sesion, setSesion] = useState(null) // null = comprobando, true/false = resultado
  const navigate = useNavigate()

  // Supabase convierte el enlace del correo en una sesión temporal al cargar la página
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSesion(!!data.session))
    const { data: sub } = supabase.auth.onAuthStateChange((_evento, session) => {
      if (session) setSesion(true)
    })
    return () => sub.subscription.unsubscribe()
  }, [])

  async function handleSubmit(e) {
    e.preventDefault()
    setError(null)
    if (password.length < 8) { setError('La contraseña debe tener al menos 8 caracteres.'); return }
    if (password !== repetir) { setError('Las contraseñas no coinciden.'); return }
    setLoading(true)
    const { error: err } = await supabase.auth.updateUser({ password })
    if (err) { setError(err.message); setLoading(false); return }
    await supabase.auth.signOut()
    setListo(true)
    setLoading(false)
    setTimeout(() => navigate('/admin/login'), 2500)
  }

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.card}>
        <div style={S.logo}>Restomind</div>
        <div style={S.sub}>Elige tu nueva contraseña</div>
        {listo ? (
          <div style={S.ok}>Contraseña actualizada. Te llevamos al inicio de sesión…</div>
        ) : sesion === false ? (
          <>
            <div style={S.error}>El enlace no es válido o ha caducado. Pide uno nuevo.</div>
            <button style={S.btn(false)} onClick={() => navigate('/admin/login')}>Ir al inicio de sesión</button>
          </>
        ) : (
          <form onSubmit={handleSubmit}>
            {error && <div style={S.error}>{error}</div>}
            <label style={S.label}>Nueva contraseña</label>
            <input style={S.input} type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="Mínimo 8 caracteres" required autoComplete="new-password" />
            <label style={S.label}>Repite la contraseña</label>
            <input style={S.input} type="password" value={repetir} onChange={e => setRepetir(e.target.value)} placeholder="••••••••" required autoComplete="new-password" />
            <button style={S.btn(loading || sesion === null)} type="submit" disabled={loading || sesion === null}>
              {loading ? 'Guardando...' : 'Guardar contraseña'}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}
