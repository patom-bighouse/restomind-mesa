import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { CONDICIONES_VERSION, PERMANENCIA_MESES, PENALIZACION_PCT } from '../lib/condiciones'

// Pantalla que bloquea el panel del dueño hasta que acepta las condiciones
// del servicio. La aceptación (versión, fecha, IP) queda registrada en
// condiciones_aceptaciones.
export default function AceptarCondiciones({ restaurantId, onAceptado }) {
  const [marcado, setMarcado] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState(null)

  async function aceptar() {
    setGuardando(true)
    setError(null)
    const { error: err } = await supabase.rpc('fn_aceptar_condiciones', { p_restaurant_id: restaurantId, p_version: CONDICIONES_VERSION })
    setGuardando(false)
    if (err) { setError(err.message); return }
    onAceptado()
  }

  async function salir() {
    await supabase.auth.signOut()
    window.location.href = '/admin/login'
  }

  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', padding: 24, background: '#111', fontFamily: "'Inter', sans-serif" }}>
      <div style={{ background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 16, padding: 28, maxWidth: 520, width: '100%', color: '#f0e8d8' }}>
        <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 22, color: '#e8c97a', marginBottom: 10 }}>Condiciones del servicio</div>
        <div style={{ fontSize: 14, color: '#b8a888', lineHeight: 1.6, marginBottom: 16 }}>
          Antes de empezar, revisa y acepta las condiciones de Restomind. Lo más importante:
        </div>
        <ul style={{ fontSize: 14, color: '#f0e8d8', lineHeight: 1.7, margin: '0 0 18px', paddingLeft: 20 }}>
          <li>Cuota mensual fija según tu plan, sin comisiones por pedido.</li>
          <li>Permanencia mínima de {PERMANENCIA_MESES} meses desde el alta; después, mes a mes.</li>
          <li>Baja durante el periodo de prueba: sin coste.</li>
          <li>Baja antes de terminar la permanencia: {PENALIZACION_PCT} % de las cuotas que falten.</li>
        </ul>
        <a href="/condiciones" target="_blank" rel="noreferrer" style={{ fontSize: 14, color: '#e8c97a' }}>Leer las condiciones completas ↗</a>

        <label style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginTop: 20, fontSize: 14, color: '#f0e8d8', cursor: 'pointer', lineHeight: 1.5 }}>
          <input type="checkbox" checked={marcado} onChange={e => setMarcado(e.target.checked)} style={{ marginTop: 4 }} />
          He leído y acepto las condiciones del servicio en nombre de mi restaurante.
        </label>

        {error && <div style={{ background: '#2a1410', border: '0.5px solid #6a2e20', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginTop: 16 }}>{error}</div>}

        <div style={{ display: 'flex', gap: 10, marginTop: 22 }}>
          <button onClick={aceptar} disabled={!marcado || guardando}
            style={{ flex: 1, background: !marcado || guardando ? '#5a4a2a' : '#e8c97a', color: !marcado || guardando ? '#8a7560' : '#111', border: 'none', borderRadius: 10, padding: 12, fontSize: 15, fontWeight: 500, cursor: !marcado || guardando ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }}>
            {guardando ? 'Guardando…' : 'Aceptar y continuar'}
          </button>
          <button onClick={salir} style={{ background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '12px 18px', fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}>
            Salir
          </button>
        </div>
      </div>
    </div>
  )
}
