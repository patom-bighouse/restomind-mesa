import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Mesa from './pages/Mesa'
import Cocina from './pages/Cocina'
import AdminLogin from './pages/AdminLogin'
import AdminMesas from './pages/AdminMesas'
import AdminCarta from './pages/AdminCarta'
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
        <Route path="/cocina/:restaurantId" element={<Cocina />} />
        <Route path="/admin/login" element={<AdminLogin />} />
        <Route path="/admin/mesas/:restaurantId" element={<AdminMesas />} />
        <Route path="/admin/carta/:restaurantId" element={<AdminCarta />} />
        <Route path="/admin/dashboard/:restaurantId" element={<AdminDashboard />} />
        <Route path="/admin/config/:restaurantId" element={<AdminConfig />} />
        <Route path="/superadmin/login" element={<SuperAdminLogin />} />
        <Route path="/superadmin/restaurantes" element={<SuperAdminRestaurantes />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>
)
