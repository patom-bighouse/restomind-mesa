import { useMemo, useState } from 'react'
import { S, C } from './estilos'
import { fmtFecha, fmtEuro, diasDesde, hoyISO } from '../../lib/crm'

// Posventa: los restaurantes ya convertidos de la cartera, con lo que
// importa para cuidarlos — si siguen activos, si se les acaba el trial o
// el descuento, y cuánto pagan hoy.
const DIAS_AVISO = 7

function alertas(info) {
  const out = []
  const hoy = hoyISO()
  if (!info.activo) out.push({ texto: 'Suspendido', color: C.mal, bg: C.malBg })
  if (info.trial_termina_en) {
    const d = -diasDesde(info.trial_termina_en + 'T00:00:00')
    if (info.trial_termina_en >= hoy && d <= DIAS_AVISO) out.push({ texto: `Trial vence en ${d} d`, color: C.aviso, bg: '#2a2014' })
    else if (info.trial_termina_en >= hoy) out.push({ texto: `En trial hasta ${fmtFecha(info.trial_termina_en)}`, color: C.oro, bg: '#2a2414' })
  }
  if (info.precio_override_hasta && info.precio_override_hasta >= hoy) {
    const d = -diasDesde(info.precio_override_hasta + 'T00:00:00')
    if (d <= DIAS_AVISO) out.push({ texto: `Descuento vence en ${d} d`, color: C.aviso, bg: '#2a2014' })
  }
  return out
}

export default function CrmClientes({ cuentas, clientesInfo, planes, esAdmin, nombreVendedor, onAbrir }) {
  const [soloAlertas, setSoloAlertas] = useState(false)

  const filas = useMemo(() => cuentas
    .filter(c => c.restaurant_id && clientesInfo[c.id])
    .map(c => ({ cuenta: c, info: clientesInfo[c.id], alertas: alertas(clientesInfo[c.id]) }))
    .filter(f => !soloAlertas || f.alertas.length)
    .sort((a, b) => b.alertas.length - a.alertas.length || a.cuenta.nombre.localeCompare(b.cuenta.nombre, 'es')),
  [cuentas, clientesInfo, soloAlertas])

  const pendientesAlta = cuentas.filter(c => c.etapa === 'ganado' && !c.restaurant_id)
  const mrr = filas.reduce((s, f) => s + (f.info.activo ? Number(f.info.cuota_actual) || 0 : 0), 0)
  const planNombre = key => planes.find(p => p.key === key)?.nombre || key || '—'

  return (
    <>
      {pendientesAlta.length > 0 && (
        <div style={{ ...S.card, marginBottom: 16, borderColor: '#5a4a2a' }}>
          <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginBottom: 6 }}>Pendientes de alta ({pendientesAlta.length})</div>
          <div style={{ fontSize: 12, color: C.texto2, marginBottom: 8 }}>
            {esAdmin ? 'Ganados que todavía no tienen restaurante creado. Ábrelos y pulsa "Convertir en restaurante".' : 'Ganados que administración todavía no ha dado de alta.'}
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {pendientesAlta.map(c => <button key={c.id} style={S.linkBtn} onClick={() => onAbrir(c.id)}>{c.nombre}</button>)}
          </div>
        </div>
      )}

      <div style={S.toolbar}>
        <span style={{ fontSize: 13, color: C.texto2 }}>{filas.length} clientes · cuota mensual activa {fmtEuro(mrr)}</span>
        <div style={{ flex: 1 }} />
        <label style={{ fontSize: 12, color: C.texto2, display: 'flex', gap: 6, alignItems: 'center', cursor: 'pointer' }}>
          <input type="checkbox" checked={soloAlertas} onChange={e => setSoloAlertas(e.target.checked)} /> Solo con alertas
        </label>
      </div>

      <div style={{ overflowX: 'auto' }}>
        <table style={S.table}>
          <thead>
            <tr>
              <th style={S.th}>Cliente</th>
              {esAdmin && <th style={S.th}>Vendedor</th>}
              <th style={S.th}>Plan</th>
              <th style={S.th}>Cuota actual</th>
              <th style={S.th}>Cliente desde</th>
              <th style={S.th}>Estado</th>
            </tr>
          </thead>
          <tbody>
            {filas.map(({ cuenta, info, alertas: al }) => (
              <tr key={cuenta.id} style={{ cursor: 'pointer' }} onClick={() => onAbrir(cuenta.id)}>
                <td style={S.td}>
                  <div style={{ fontWeight: 500 }}>{info.nombre}</div>
                  <div style={{ fontSize: 11, color: C.muted, marginTop: 2 }}>{[cuenta.contacto_nombre, cuenta.telefono].filter(Boolean).join(' · ') || '—'}</div>
                </td>
                {esAdmin && <td style={{ ...S.td, color: cuenta.vendedor_id ? C.texto : C.aviso }}>{nombreVendedor(cuenta.vendedor_id) || 'Sin asignar'}</td>}
                <td style={S.td}>{planNombre(info.plan)}</td>
                <td style={S.td}>{fmtEuro(info.cuota_actual)}</td>
                <td style={S.td}>{fmtFecha(cuenta.ganado_en || info.alta_en)}</td>
                <td style={S.td}>
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {info.activo && !al.some(a => a.texto === 'Suspendido') && <span style={S.badge(C.okBg, C.ok)}>Activo</span>}
                    {al.map(a => <span key={a.texto} style={S.badge(a.bg, a.color)}>{a.texto}</span>)}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {filas.length === 0 && <div style={S.vacio}>{soloAlertas ? 'Ningún cliente con alertas.' : 'Todavía no hay clientes convertidos.'}</div>}
      </div>
    </>
  )
}
