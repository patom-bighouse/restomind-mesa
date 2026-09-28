import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter, Routes, Route, useNavigate } from 'react-router-dom'
import { supabase } from './lib/supabase'
import AdminRestablecer from './pages/AdminRestablecer'
import Landing from './pages/Landing'
import Mesa from './pages/Mesa'
import Camarero from './pages/Camarero'
import Cocina from './pages/Cocina'
import AdminLogin from './pages/AdminLogin'
import AdminMesas from './pages/AdminMesas'
import AdminClientes from './pages/AdminClientes'
import AdminUpsell from './pages/AdminUpsell'
import AdminReservas from './pages/AdminReservas'
import Reservar from './pages/Reservar'
import AdminLimpieza from './pages/AdminLimpieza'
import AdminFidelizacion from './pages/AdminFidelizacion'
import AdminCarta from './pages/AdminCarta'
import AdminMenus from './pages/AdminMenus'
import AdminStock from './pages/AdminStock'
import AdminVales from './pages/AdminVales'
import AdminWebhooks from './pages/AdminWebhooks'
import AdminDashboard from './pages/AdminDashboard'
import AdminConfig from './pages/AdminConfig'
import SuperAdminLogin from './pages/SuperAdminLogin'
import SuperAdminRestaurantes from './pages/SuperAdminRestaurantes'
import SuperAdminPlanes from './pages/SuperAdminPlanes'
import NotFound from './pages/NotFound'
import GuardRestaurante from './components/GuardRestaurante'

// El enlace de recuperación de Supabase aterriza en la Site URL (normalmente "/"):
// al detectar el evento PASSWORD_RECOVERY llevamos al usuario a la pantalla de nueva contraseña.
function RecuperacionRedirect() {
  const navigate = useNavigate()
  React.useEffect(() => {
    const { data: sub } = supabase.auth.onAuthStateChange((evento) => {
      if (evento === 'PASSWORD_RECOVERY') navigate('/admin/restablecer', { replace: true })
    })
    return () => sub.subscription.unsubscribe()
  }, [navigate])
  return null
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <RecuperacionRedirect />
      <Routes>
        <Route path="/admin/restablecer" element={<AdminRestablecer />} />
        <Route path="/" element={<Landing />} />
        <Route path="/mesa/:token" element={<Mesa />} />
        <Route path="/camarero/:restaurantId" element={<GuardRestaurante><Camarero /></GuardRestaurante>} />
        <Route path="/cocina/:restaurantId" element={<GuardRestaurante><Cocina /></GuardRestaurante>} />
        <Route path="/admin/login" element={<AdminLogin />} />
        <Route path="/admin/mesas/:restaurantId" element={<GuardRestaurante><AdminMesas /></GuardRestaurante>} />
        <Route path="/admin/clientes/:restaurantId" element={<GuardRestaurante><AdminClientes /></GuardRestaurante>} />
        <Route path="/admin/upsell/:restaurantId" element={<GuardRestaurante><AdminUpsell /></GuardRestaurante>} />
        <Route path="/admin/reservas/:restaurantId" element={<GuardRestaurante><AdminReservas /></GuardRestaurante>} />
        <Route path="/reservar/:restaurantId" element={<GuardRestaurante publico><Reservar /></GuardRestaurante>} />
        <Route path="/admin/limpieza/:restaurantId" element={<GuardRestaurante><AdminLimpieza /></GuardRestaurante>} />
        <Route path="/admin/fidelizacion/:restaurantId" element={<GuardRestaurante><AdminFidelizacion /></GuardRestaurante>} />
        <Route path="/admin/carta/:restaurantId" element={<GuardRestaurante><AdminCarta /></GuardRestaurante>} />
        <Route path="/admin/menus/:restaurantId" element={<GuardRestaurante><AdminMenus /></GuardRestaurante>} />
        <Route path="/admin/stock/:restaurantId" element={<GuardRestaurante><AdminStock /></GuardRestaurante>} />
        <Route path="/admin/vales/:restaurantId" element={<GuardRestaurante><AdminVales /></GuardRestaurante>} />
        <Route path="/admin/webhooks/:restaurantId" element={<GuardRestaurante><AdminWebhooks /></GuardRestaurante>} />
        <Route path="/admin/dashboard/:restaurantId" element={<GuardRestaurante><AdminDashboard /></GuardRestaurante>} />
        <Route path="/admin/config/:restaurantId" element={<GuardRestaurante><AdminConfig /></GuardRestaurante>} />
        <Route path="/superadmin/login" element={<SuperAdminLogin />} />
        <Route path="/superadmin/restaurantes" element={<SuperAdminRestaurantes />} />
        <Route path="/superadmin/planes" element={<SuperAdminPlanes />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>
)
