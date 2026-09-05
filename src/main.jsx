import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
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
import AdminDashboard from './pages/AdminDashboard'
import AdminConfig from './pages/AdminConfig'
import SuperAdminLogin from './pages/SuperAdminLogin'
import SuperAdminRestaurantes from './pages/SuperAdminRestaurantes'
import NotFound from './pages/NotFound'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
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
        <Route path="/admin/dashboard/:restaurantId" element={<AdminDashboard />} />
        <Route path="/admin/config/:restaurantId" element={<AdminConfig />} />
        <Route path="/superadmin/login" element={<SuperAdminLogin />} />
        <Route path="/superadmin/restaurantes" element={<SuperAdminRestaurantes />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>
)
