import { useState, useMemo } from 'react'
import { S, C, estiloEtapa } from './estilos'
import { ETAPAS, etapaLabel, fmtFecha, fmtEuro, hoyISO } from '../../lib/crm'

const COLUMNAS = [
  { key: 'nombre', label: 'Cuenta' },
  { key: 'etapa', label: 'Etapa' },
  { key: 'cuota_estimada', label: 'Cuota est.' },
  { key: 'proxima_accion_fecha', label: 'Próxima acción' },
  { key: 'ultima_actividad_en', label: 'Últ. actividad' },
  { key: 'created_at', label: 'Alta en CRM' },
]

function exportarCsv(filas, nombreVendedor) {
  const cab = ['Nombre', 'Contacto', 'Teléfono', 'Email', 'Ciudad', 'Tipo', 'Etapa', 'Vendedor', 'Fuente', 'Plan', 'Cuota estimada', 'Próxima acción', 'Fecha próxima acción', 'Motivo pérdida']
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const lineas = filas.map(c => [
    c.nombre, c.contacto_nombre, c.telefono, c.email, c.ciudad, c.tipo_local, etapaLabel(c.etapa),
    nombreVendedor(c.vendedor_id), c.fuente, c.plan_interes, c.cuota_estimada, c.proxima_accion,
    c.proxima_accion_fecha, c.motivo_perdida,
  ].map(esc).join(';'))
  const blob = new Blob(['﻿' + [cab.map(esc).join(';'), ...lineas].join('\n')], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `crm-cuentas-${hoyISO()}.csv`
  a.click()
  URL.revokeObjectURL(a.href)
}

export default function CrmLista({ cuentas, esAdmin, nombreVendedor, onAbrir }) {
  const [etapa, setEtapa] = useState('todas')
  const [orden, setOrden] = useState({ key: 'updated_at', asc: false })
  const hoy = hoyISO()

  const filas = useMemo(() => {
    const base = etapa === 'todas' ? cuentas
      : etapa === 'abiertas' ? cuentas.filter(c => !['ganado', 'perdido'].includes(c.etapa))
      : cuentas.filter(c => c.etapa === etapa)
    const val = c => c[orden.key] ?? ''
    return [...base].sort((a, b) => {
      const va = val(a), vb = val(b)
      const cmp = typeof va === 'number' || typeof vb === 'number'
        ? (Number(va) || 0) - (Number(vb) || 0)
        : String(va).localeCompare(String(vb), 'es')
      return orden.asc ? cmp : -cmp
    })
  }, [cuentas, etapa, orden])

  function ordenarPor(key) {
    setOrden(prev => ({ key, asc: prev.key === key ? !prev.asc : true }))
  }

  return (
    <>
      <div style={S.toolbar}>
        <select style={S.inputSm} value={etapa} onChange={e => setEtapa(e.target.value)}>
          <option value="todas">Todas las etapas</option>
          <option value="abiertas">Solo abiertas</option>
          {ETAPAS.map(e => <option key={e.key} value={e.key}>{e.label}</option>)}
        </select>
        <span style={{ fontSize: 12, color: C.muted }}>{filas.length} cuentas</span>
        <div style={{ flex: 1 }} />
        <button style={S.linkBtn} onClick={() => exportarCsv(filas, nombreVendedor)}>Exportar CSV</button>
      </div>

      <div style={{ overflowX: 'auto' }}>
        <table style={S.table}>
          <thead>
            <tr>
              {COLUMNAS.slice(0, 2).map(col => (
                <th key={col.key} style={{ ...S.th, cursor: 'pointer' }} onClick={() => ordenarPor(col.key)}>
                  {col.label}{orden.key === col.key ? (orden.asc ? ' ↑' : ' ↓') : ''}
                </th>
              ))}
              {esAdmin && <th style={S.th}>Vendedor</th>}
              {COLUMNAS.slice(2).map(col => (
                <th key={col.key} style={{ ...S.th, cursor: 'pointer' }} onClick={() => ordenarPor(col.key)}>
                  {col.label}{orden.key === col.key ? (orden.asc ? ' ↑' : ' ↓') : ''}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filas.map(c => (
              <tr key={c.id} style={{ cursor: 'pointer' }} onClick={() => onAbrir(c.id)}>
                <td style={S.td}>
                  <div style={{ fontWeight: 500 }}>{c.nombre}</div>
                  <div style={{ fontSize: 11, color: C.muted, marginTop: 2 }}>
                    {[c.contacto_nombre, c.ciudad, c.telefono].filter(Boolean).join(' · ') || '—'}
                  </div>
                </td>
                <td style={S.td}>
                  <span style={estiloEtapa(c.etapa)}>{etapaLabel(c.etapa)}</span>
                  {c.etapa === 'ganado' && (
                    <div style={{ fontSize: 11, color: c.restaurant_id ? C.muted : C.oro, marginTop: 4 }}>
                      {c.restaurant_id ? 'Cliente' : 'Pendiente de alta'}
                    </div>
                  )}
                  {c.etapa === 'perdido' && c.motivo_perdida && <div style={{ fontSize: 11, color: C.muted, marginTop: 4 }}>{c.motivo_perdida}</div>}
                </td>
                {esAdmin && <td style={{ ...S.td, color: c.vendedor_id ? C.texto : C.aviso }}>{nombreVendedor(c.vendedor_id) || 'Sin asignar'}</td>}
                <td style={S.td}>{c.cuota_estimada != null ? fmtEuro(c.cuota_estimada) : '—'}</td>
                <td style={S.td}>
                  {c.proxima_accion_fecha ? (
                    <>
                      <div style={{ color: c.proxima_accion_fecha < hoy ? C.mal : C.texto }}>{fmtFecha(c.proxima_accion_fecha)}</div>
                      {c.proxima_accion && <div style={{ fontSize: 11, color: C.muted }}>{c.proxima_accion}</div>}
                    </>
                  ) : '—'}
                </td>
                <td style={S.td}>{fmtFecha(c.ultima_actividad_en)}</td>
                <td style={S.td}>{fmtFecha(c.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {filas.length === 0 && <div style={S.vacio}>No hay cuentas con estos filtros.</div>}
      </div>
    </>
  )
}
