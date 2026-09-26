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
        <Route path="/camarero/:restaurantId" element={<Camarero />} />
        <Route path="/cocina/:restaurantId" element={<Cocina />} />
        <Route path="/admin/login" element={<AdminLogin />} />
        <Route path="/admin/mesas/:restaurantId" element={<AdminMesas />} />
        <Route path="/admin/clientes/:restaurantId" element={<AdminClientes />} />
        <Route path="/admin/upsell/:restaurantId" element={<AdminUpsell />} />
        <Route path="/admin/reservas/:restaurantId" element={<AdminReservas />} />
        <Route path="/reservar/:restaurantId" element={<Reservar />} />
        <Route path="/admin/limpieza/:restaurantId" element={<AdminLimpieza />} />
        <Route path="/admin/fidelizacion/:restaurantId" element={<AdminFidelizacion />} />
        <Route path="/admin/carta/:restaurantId" element={<AdminCarta />} />
        <Route path="/admin/menus/:restaurantId" element={<AdminMenus />} />
        <Route path="/admin/stock/:restaurantId" element={<AdminStock />} />
        <Route path="/admin/vales/:restaurantId" element={<AdminVales />} />
        <Route path="/admin/webhooks/:restaurantId" element={<AdminWebhooks />} />
        <Route path="/admin/dashboard/:restaurantId" element={<AdminDashboard />} />
        <Route path="/admin/config/:restaurantId" element={<AdminConfig />} />
        <Route path="/superadmin/login" element={<SuperAdminLogin />} />
        <Route path="/superadmin/restaurantes" element={<SuperAdminRestaurantes />} />
        <Route path="/superadmin/planes" element={<SuperAdminPlanes />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>
)
