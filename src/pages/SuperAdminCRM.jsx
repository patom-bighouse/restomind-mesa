import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import CrmApp from '../components/crm/CrmApp'
import { S } from '../components/crm/estilos'

export default function SuperAdminCRM() {
  const navigate = useNavigate()
  const [listo, setListo] = useState(false)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/superadmin/login'); return }
    const { data: sa } = await supabase.from('superadmins').select('id').eq('user_id', session.user.id).single()
    if (!sa) { navigate('/superadmin/login'); return }
    setListo(true)
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/superadmin/login')
  }

  if (!listo) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <CrmApp
      modo="superadmin"
      subtitulo="CRM comercial"
      onLogout={handleLogout}
      navExtra={<>
        <a href="/superadmin/restaurantes" style={S.linkBtn}>Restaurantes</a>
        <a href="/superadmin/planes" style={S.linkBtn}>Planes</a>
      </>}
    />
  )
}
