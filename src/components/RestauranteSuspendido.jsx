// Pantalla que sustituye a cualquier página de un restaurante inactivo.
// `publico` = la ve un cliente (QR de mesa, web de reservas), así que no
// se le habla de cuentas ni de Restomind.
export default function RestauranteSuspendido({ publico = false }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', gap: 16, padding: 24, textAlign: 'center', background: '#1a1410', fontFamily: "'Inter', sans-serif" }}>
      <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 22, color: '#e8c97a' }}>
        {publico ? 'Restaurante no disponible' : 'Cuenta suspendida'}
      </div>
      <div style={{ fontSize: 14, color: '#7a6a50', maxWidth: 360 }}>
        {publico
          ? 'Este restaurante no está disponible temporalmente. Disculpa las molestias.'
          : 'El acceso a este restaurante está desactivado. Ponte en contacto con Restomind para reactivarlo.'}
      </div>
    </div>
  )
}
