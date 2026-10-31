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
  ok: { background: '#142a14', border: '0.5px solid #2a5a2a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#8ae87a', marginBottom: 16, lineHeight: 1.5 },
  link: { display: 'block', width: '100%', background: 'none', border: 'none', color: '#8a8a8a', fontSize: 13, fontFamily: "'Inter', sans-serif", cursor: 'pointer', marginTop: 16, textAlign: 'center', textDecoration: 'underline' },
  error: { background: '#2a1414', border: '0.5px solid #5a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
}

export default function VendedorLogin() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [olvido, setOlvido] = useState(false)
  const [enviado, setEnviado] = useState(false)
  const navigate = useNavigate()

  async function handleLogin(e) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    const { error: err } = await supabase.auth.signInWithPassword({ email, password })
    if (err) { setError(err.message); setLoading(false); return }

    // fn_mi_vendedor_id solo devuelve vendedores activos.
    const { data: vendedorId } = await supabase.rpc('fn_mi_vendedor_id')
    if (!vendedorId) {
      await supabase.auth.signOut()
      setError('Este usuario no tiene acceso al CRM de vendedores, o su cuenta está desactivada.')
      setLoading(false)
      return
    }
    navigate('/vendedor/crm')
  }

  async function handleRecuperar(e) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    // Marca para que, si el enlace aterriza en "/", se vaya a la pantalla de vendedor.
    localStorage.setItem('recuperacion_destino', 'vendedor')
    const { error: err } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/vendedor/restablecer`,
    })
    setLoading(false)
    if (err) { setError(err.message); return }
    setEnviado(true)
  }

  function cambiarModo(valor) {
    setOlvido(valor)
    setEnviado(false)
    setError(null)
  }

  return (
    <div style={S.app}>
      <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap" rel="stylesheet" />
      <div style={S.card}>
        <div style={S.logo}><img src="/logos/opcion-2-monograma/icon-dark.svg" alt="" style={{ height: 28, verticalAlign: 'middle', marginRight: 10 }} />Restomind</div>
        <div style={S.sub}>Vendedores</div>
        {error && <div style={S.error}>{error}</div>}
        {olvido ? (
          enviado ? (
            <>
              <div style={S.ok}>Si {email.trim()} es un usuario del CRM, recibirás un correo con un enlace para elegir una contraseña nueva. Revisa también la carpeta de spam.</div>
              <button style={S.link} onClick={() => cambiarModo(false)}>Volver a iniciar sesión</button>
            </>
          ) : (
            <form onSubmit={handleRecuperar}>
              <label style={S.label}>Email</label>
              <input style={S.input} type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="tu@email.com" required />
              <button style={S.btn(loading)} type="submit" disabled={loading}>
                {loading ? 'Enviando...' : 'Enviar enlace'}
              </button>
              <button style={S.link} type="button" onClick={() => cambiarModo(false)}>Volver a iniciar sesión</button>
            </form>
          )
        ) : (
        <form onSubmit={handleLogin}>
          <label style={S.label}>Email</label>
          <input style={S.input} type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="tu@email.com" required />
          <label style={S.label}>Contraseña</label>
          <input style={S.input} type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" required />
          <button style={S.btn(loading)} type="submit" disabled={loading}>
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
          <button style={S.link} type="button" onClick={() => cambiarModo(true)}>¿Olvidaste tu contraseña?</button>
        </form>
        )}
      </div>
    </div>
  )
}
