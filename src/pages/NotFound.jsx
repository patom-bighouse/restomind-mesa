export default function NotFound() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100vh', gap: 16 }}>
      <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 22, color: '#e8c97a' }}>Mesa no encontrada</div>
      <div style={{ fontSize: 14, color: '#7a6a50' }}>Escanea el código QR de tu mesa para continuar.</div>
    </div>
  )
}
