import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import CrmApp from '../components/crm/CrmApp'
import { S } from '../components/crm/estilos'

export default function VendedorCRM() {
  const navigate = useNavigate()
  const [vendedor, setVendedor] = useState(null)

  useEffect(() => { checkAuth() }, [])

  async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) { navigate('/vendedor/login'); return }
    const { data } = await supabase.from('vendedores').select('*').eq('user_id', session.user.id).eq('activo', true).maybeSingle()
    if (!data) { navigate('/vendedor/login'); return }
    setVendedor(data)
  }

  async function handleLogout() {
    await supabase.auth.signOut()
    navigate('/vendedor/login')
  }

  if (!vendedor) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <CrmApp
      modo="vendedor"
      subtitulo={`CRM · ${vendedor.nombre}`}
      onLogout={handleLogout}
    />
  )
}
