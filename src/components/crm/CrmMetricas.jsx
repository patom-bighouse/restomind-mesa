import { useState, useEffect, useMemo } from 'react'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { supabase } from '../../lib/supabase'
import { S, C } from './estilos'
import { ETAPAS, ETAPAS_ABIERTAS, DIAS_SIN_ACTIVIDAD, fmtEuro, diasDesde } from '../../lib/crm'

// Todas las gráficas son de una sola serie (sin leyenda: el título la
// nombra), en el dorado de la marca; el desglose exacto está en la tabla
// por vendedor y en la pestaña Lista.
const SERIE = C.oro
const EJE = { fontSize: 11, fill: C.texto2 }

function TooltipOscuro({ active, payload, label, unidad }) {
  if (!active || !payload?.length) return null
  return (
    <div style={{ background: '#1c1c1c', border: `0.5px solid ${C.borde}`, borderRadius: 8, padding: '8px 12px', fontSize: 12 }}>
      <div style={{ color: C.texto2, marginBottom: 2 }}>{label}</div>
      <div style={{ color: C.texto, fontWeight: 500 }}>{payload[0].value} {unidad}</div>
    </div>
  )
}

function Kpi({ titulo, valor, detalle }) {
  return (
    <div style={{ ...S.card, flex: '1 1 170px' }}>
      <div style={{ fontSize: 11, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.06em' }}>{titulo}</div>
      <div style={{ fontSize: 24, fontWeight: 600, color: C.texto, marginTop: 6 }}>{valor}</div>
      {detalle && <div style={{ fontSize: 11, color: C.texto2, marginTop: 4 }}>{detalle}</div>}
    </div>
  )
}

function Grafica({ titulo, children, alto = 240 }) {
  return (
    <div style={{ ...S.card, flex: '1 1 420px', minWidth: 0 }}>
      <div style={{ fontSize: 13, color: C.texto, fontWeight: 500, marginBottom: 12 }}>{titulo}</div>
      <div style={{ width: '100%', height: alto }}>{children}</div>
    </div>
  )
}

function ultimosMeses(n) {
  const out = []
  const d = new Date()
  d.setDate(1)
  for (let i = n - 1; i >= 0; i--) {
    const m = new Date(d.getFullYear(), d.getMonth() - i, 1)
    out.push({ key: `${m.getFullYear()}-${String(m.getMonth() + 1).padStart(2, '0')}`, label: m.toLocaleDateString('es-ES', { month: 'short' }) })
  }
  return out
}

export default function CrmMetricas({ cuentas, clientesInfo, vendedores, esAdmin }) {
  const [actividades, setActividades] = useState([])

  useEffect(() => {
    const desde = new Date(Date.now() - 30 * 86400000).toISOString()
    supabase.from('crm_actividades').select('cuenta_id, fecha').gte('fecha', desde)
      .then(({ data }) => setActividades(data || []))
  }, [])

  const m = useMemo(() => {
    const ids = new Set(cuentas.map(c => c.id))
    const abiertas = cuentas.filter(c => ETAPAS_ABIERTAS.includes(c.etapa))
    const ganadas = cuentas.filter(c => c.etapa === 'ganado')
    const perdidas = cuentas.filter(c => c.etapa === 'perdido')
    const cerradas = ganadas.length + perdidas.length
    const hace30 = Date.now() - 30 * 86400000
    const ganadas30 = ganadas.filter(c => c.ganado_en && new Date(c.ganado_en).getTime() >= hace30)
    const diasCierre = ganadas.filter(c => c.ganado_en && c.fuente !== 'Cliente existente')
      .map(c => (new Date(c.ganado_en) - new Date(c.created_at)) / 86400000)
    const clientes = cuentas.filter(c => clientesInfo[c.id]?.activo)
    const mrr = clientes.reduce((s, c) => s + (Number(clientesInfo[c.id].cuota_actual) || 0), 0)
    const frias = abiertas.filter(c => (diasDesde(c.ultima_actividad_en || c.created_at) ?? 0) >= DIAS_SIN_ACTIVIDAD)

    const embudo = ETAPAS.filter(e => e.key !== 'perdido').map(e => ({ etapa: e.label, cuentas: cuentas.filter(c => c.etapa === e.key).length }))
    const meses = ultimosMeses(6).map(mes => ({
      mes: mes.label,
      ganadas: ganadas.filter(c => c.ganado_en?.startsWith(mes.key) && c.fuente !== 'Cliente existente').length,
    }))
    const motivos = Object.entries(perdidas.reduce((acc, c) => { const k = c.motivo_perdida || 'Sin motivo'; acc[k] = (acc[k] || 0) + 1; return acc }, {}))
      .map(([motivo, cuentas]) => ({ motivo, cuentas })).sort((a, b) => b.cuentas - a.cuentas)

    const actividad30 = actividades.filter(a => ids.has(a.cuenta_id))

    const porVendedor = vendedores.map(v => {
      const cs = cuentas.filter(c => c.vendedor_id === v.id)
      const g = cs.filter(c => c.etapa === 'ganado').length
      const p = cs.filter(c => c.etapa === 'perdido').length
      const csIds = new Set(cs.map(c => c.id))
      return {
        id: v.id, nombre: v.nombre, activo: v.activo,
        abiertas: cs.filter(c => ETAPAS_ABIERTAS.includes(c.etapa)).length,
        pipeline: cs.filter(c => ETAPAS_ABIERTAS.includes(c.etapa)).reduce((s, c) => s + (Number(c.cuota_estimada) || 0), 0),
        ganadas: g, perdidas: p,
        conversion: g + p ? Math.round((g / (g + p)) * 100) : null,
        mrr: cs.filter(c => clientesInfo[c.id]?.activo).reduce((s, c) => s + (Number(clientesInfo[c.id].cuota_actual) || 0), 0),
        actividad: actividad30.filter(a => csIds.has(a.cuenta_id)).length,
      }
    }).filter(r => r.abiertas || r.ganadas || r.perdidas || r.activo)

    return {
      abiertas: abiertas.length,
      pipeline: abiertas.reduce((s, c) => s + (Number(c.cuota_estimada) || 0), 0),
      ganadas30: ganadas30.length,
      conversion: cerradas ? Math.round((ganadas.length / cerradas) * 100) : null,
      cerradas,
      clientes: clientes.length,
      mrr,
      diasCierre: diasCierre.length ? Math.round(diasCierre.reduce((a, b) => a + b, 0) / diasCierre.length) : null,
      frias: frias.length,
      actividad30: actividad30.length,
      embudo, meses, motivos, porVendedor,
    }
  }, [cuentas, clientesInfo, vendedores, actividades])

  return (
    <>
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 16 }}>
        <Kpi titulo="Oportunidades abiertas" valor={m.abiertas} detalle={`${fmtEuro(m.pipeline)}/mes estimados`} />
        <Kpi titulo="Ganadas (30 días)" valor={m.ganadas30} />
        <Kpi titulo="Conversión" valor={m.conversion != null ? `${m.conversion} %` : '—'} detalle={`sobre ${m.cerradas} cerradas`} />
        <Kpi titulo="Clientes activos" valor={m.clientes} detalle={`${fmtEuro(m.mrr)}/mes`} />
        <Kpi titulo="Días medios de cierre" valor={m.diasCierre ?? '—'} />
        <Kpi titulo="Actividades (30 días)" valor={m.actividad30} detalle={m.frias ? `${m.frias} oportunidades sin actividad ≥ ${DIAS_SIN_ACTIVIDAD} d` : 'Ninguna oportunidad fría'} />
      </div>

      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 16 }}>
        <Grafica titulo="Cuentas por etapa">
          <ResponsiveContainer>
            <BarChart data={m.embudo} layout="vertical" margin={{ top: 0, right: 16, bottom: 0, left: 8 }} barCategoryGap={6}>
              <CartesianGrid horizontal={false} stroke="#222" />
              <XAxis type="number" allowDecimals={false} tick={EJE} axisLine={false} tickLine={false} />
              <YAxis type="category" dataKey="etapa" width={110} tick={EJE} axisLine={false} tickLine={false} />
              <Tooltip content={<TooltipOscuro unidad="cuentas" />} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
              <Bar dataKey="cuentas" fill={SERIE} radius={[0, 4, 4, 0]} maxBarSize={22} />
            </BarChart>
          </ResponsiveContainer>
        </Grafica>
        <Grafica titulo="Nuevos clientes ganados por mes">
          <ResponsiveContainer>
            <BarChart data={m.meses} margin={{ top: 8, right: 8, bottom: 0, left: -16 }}>
              <CartesianGrid vertical={false} stroke="#222" />
              <XAxis dataKey="mes" tick={EJE} axisLine={false} tickLine={false} />
              <YAxis allowDecimals={false} tick={EJE} axisLine={false} tickLine={false} />
              <Tooltip content={<TooltipOscuro unidad="ganadas" />} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
              <Bar dataKey="ganadas" fill={SERIE} radius={[4, 4, 0, 0]} maxBarSize={36} />
            </BarChart>
          </ResponsiveContainer>
        </Grafica>
      </div>

      {m.motivos.length > 0 && (
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 16 }}>
          <Grafica titulo="Motivos de pérdida" alto={Math.max(120, m.motivos.length * 32)}>
            <ResponsiveContainer>
              <BarChart data={m.motivos} layout="vertical" margin={{ top: 0, right: 16, bottom: 0, left: 8 }} barCategoryGap={6}>
                <CartesianGrid horizontal={false} stroke="#222" />
                <XAxis type="number" allowDecimals={false} tick={EJE} axisLine={false} tickLine={false} />
                <YAxis type="category" dataKey="motivo" width={150} tick={EJE} axisLine={false} tickLine={false} />
                <Tooltip content={<TooltipOscuro unidad="cuentas" />} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
                <Bar dataKey="cuentas" fill={SERIE} radius={[0, 4, 4, 0]} maxBarSize={22} />
              </BarChart>
            </ResponsiveContainer>
          </Grafica>
        </div>
      )}

      {esAdmin && m.porVendedor.length > 0 && (
        <div style={{ ...S.card, overflowX: 'auto' }}>
          <div style={{ fontSize: 13, color: C.texto, fontWeight: 500, marginBottom: 8 }}>Rendimiento por vendedor</div>
          <table style={S.table}>
            <thead>
              <tr>
                <th style={S.th}>Vendedor</th>
                <th style={S.th}>Abiertas</th>
                <th style={S.th}>Pipeline €/mes</th>
                <th style={S.th}>Ganadas</th>
                <th style={S.th}>Perdidas</th>
                <th style={S.th}>Conversión</th>
                <th style={S.th}>Cartera €/mes</th>
                <th style={S.th}>Actividades 30 d</th>
              </tr>
            </thead>
            <tbody>
              {m.porVendedor.map(r => (
                <tr key={r.id}>
                  <td style={S.td}>{r.nombre}{!r.activo && <span style={{ color: C.muted, fontSize: 11 }}> (inactivo)</span>}</td>
                  <td style={S.td}>{r.abiertas}</td>
                  <td style={S.td}>{fmtEuro(r.pipeline)}</td>
                  <td style={S.td}>{r.ganadas}</td>
                  <td style={S.td}>{r.perdidas}</td>
                  <td style={S.td}>{r.conversion != null ? `${r.conversion} %` : '—'}</td>
                  <td style={S.td}>{fmtEuro(r.mrr)}</td>
                  <td style={S.td}>{r.actividad}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  )
}
