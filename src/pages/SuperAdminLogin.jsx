import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

const S = {
  app: { minHeight: '100vh', background: '#0a0a0a', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: "'Inter', sans-serif", padding: 20 },
  card: { background: '#161616', border: '0.5px solid #2a2a2a', borderRadius: 16, padding: 32, width: '100%', maxWidth: 380 },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 24, fontWeight: 600, color: '#e8c97a', textAlign: 'center', marginBottom: 4 },
  sub: { fontSize: 12, color: '#666', textAlign: 'center', marginBottom: 32, textTransform: 'uppercase', letterSpacing: '0.1em' },
  label: { fontSize: 13, color: '#8a8a8a', marginBottom: 6, display: 'block' },
  input: { width: '100%', background: '#0a0a0a', border: '0.5px solid #2a2a2a', borderRadius: 10, padding: '12px 14px', fontSize: 14, color: '#f0f0f0', fontFamily: "'Inter', sans-serif", outline: 'none', marginBottom: 16, boxSizing: 'border-box' },
  btn: (loading) => ({ width: '100%', background: loading ? '#3a3a3a' : '#e8c97a', color: loading ? '#888' : '#111', border: 'none', borderRadius: 10, padding: 14, fontSize: 15, fontWeight: 500, fontFamily: "'Inter', sans-serif", cursor: loading ? 'not-allowed' : 'pointer', marginTop: 8 }),
  error: { background: '#2a1414', border: '0.5px solid #5a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
}

export default function SuperAdminLogin() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const navigate = useNavigate()

  async function handleLogin(e) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    const { data, error: err } = await supabase.auth.signInWithPassword({ email, password })
    if (err) { setError(err.message); setLoading(false); return }

    const { data: sa } = await supabase
      .from('superadmins')
      .select('id')
      .eq('user_id', data.user.id)
      .single()

    if (!sa) {
      await supabase.auth.signOut()
      setError('Este usuario no tiene permisos de super admin.')
      setLoading(false)
      return
    }
    navigate('/superadmin/restaurantes')
  }

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.card}>
        <div style={S.logo}>Restomind</div>
        <div style={S.sub}>Super Admin</div>
        {error && <div style={S.error}>{error}</div>}
        <form onSubmit={handleLogin}>
          <label style={S.label}>Email</label>
          <input style={S.input} type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="patricio@restomind.com" required />
          <label style={S.label}>Contraseña</label>
          <input style={S.input} type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" required />
          <button style={S.btn(loading)} type="submit" disabled={loading}>
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
        </form>
      </div>
    </div>
  )
}
