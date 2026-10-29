import { useState, useEffect, useMemo } from 'react'
import { supabase } from '../../lib/supabase'
import { S, C } from './estilos'
import { fmtEuro, fmtMes, fmtFecha, mesISO } from '../../lib/crm'

function mesAnterior() {
  const d = new Date()
  d.setDate(1)
  d.setMonth(d.getMonth() - 1)
  return mesISO(d).slice(0, 7)
}

function Kpi({ titulo, valor, detalle }) {
  return (
    <div style={{ ...S.card, flex: '1 1 180px' }}>
      <div style={{ fontSize: 11, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.06em' }}>{titulo}</div>
      <div style={{ fontSize: 22, fontWeight: 600, color: C.texto, marginTop: 6 }}>{valor}</div>
      {detalle && <div style={{ fontSize: 11, color: C.texto2, marginTop: 4 }}>{detalle}</div>}
    </div>
  )
}

export default function CrmComisiones({ esAdmin, cuentas, clientesInfo, vendedores, onError, onAviso }) {
  const [comisiones, setComisiones] = useState([])
  const [cargando, setCargando] = useState(true)
  const [mesGenerar, setMesGenerar] = useState(mesAnterior())
  const [generando, setGenerando] = useState(false)
  const [filtroVendedor, setFiltroVendedor] = useState('todos')
  const [filtroEstado, setFiltroEstado] = useState('todos')
  const [filtroMes, setFiltroMes] = useState('')

  useEffect(() => { cargar() }, [])

  async function cargar() {
    const { data, error } = await supabase.from('crm_comisiones').select('*').order('periodo', { ascending: false })
    if (error) onError(error.message)
    setComisiones(data || [])
    setCargando(false)
  }

  const cuentaPorId = useMemo(() => Object.fromEntries(cuentas.map(c => [c.id, c])), [cuentas])
  const nombreVendedor = id => vendedores.find(v => v.id === id)?.nombre || '—'

  const filas = useMemo(() => comisiones.filter(c =>
    (filtroVendedor === 'todos' || c.vendedor_id === filtroVendedor)
    && (filtroEstado === 'todos' || c.estado === filtroEstado)
    && (!filtroMes || c.periodo.startsWith(filtroMes))
  ), [comisiones, filtroVendedor, filtroEstado, filtroMes])

  const suma = (lista, estado) => lista.filter(c => c.estado === estado).reduce((s, c) => s + Number(c.importe), 0)
  const mesActual = mesISO()
  const generadasMesPasado = comisiones.filter(c => c.periodo.startsWith(mesAnterior())).reduce((s, c) => s + (c.estado !== 'anulada' ? Number(c.importe) : 0), 0)

  // Comisión mensual que generaría hoy la cartera activa (estimación).
  const proyeccion = useMemo(() => cuentas.reduce((s, c) => {
    const info = clientesInfo[c.id]
    if (!info || !info.activo || !c.comision_pct || !c.vendedor_id) return s
    if (esAdmin && filtroVendedor !== 'todos' && c.vendedor_id !== filtroVendedor) return s
    const hechas = comisiones.filter(x => x.cuenta_id === c.id && x.estado !== 'anulada').length
    if (c.comision_cuotas && hechas >= c.comision_cuotas) return s
    return s + (Number(info.cuota_actual) || 0) * Number(c.comision_pct) / 100
  }, 0), [cuentas, clientesInfo, comisiones, esAdmin, filtroVendedor])

  async function generar() {
    if (!mesGenerar) return
    setGenerando(true)
    const { data, error } = await supabase.rpc('fn_crm_generar_comisiones', { p_periodo: `${mesGenerar}-01` })
    setGenerando(false)
    if (error) { onError(error.message); return }
    onAviso(data ? `Generadas ${data} comisiones de ${fmtMes(mesGenerar + '-01')}.` : `No había comisiones nuevas que generar para ${fmtMes(mesGenerar + '-01')}.`)
    cargar()
  }

  async function cambiarEstado(ids, estado) {
    if (!ids.length) return
    const { error } = await supabase.from('crm_comisiones')
      .update({ estado, pagada_en: estado === 'pagada' ? new Date().toISOString() : null })
      .in('id', ids)
    if (error) { onError(error.message); return }
    cargar()
  }

  async function borrar(c) {
    if (!window.confirm(`¿Borrar la comisión de ${fmtMes(c.periodo)}? Si vuelves a generar ese mes, se recreará.`)) return
    const { error } = await supabase.from('crm_comisiones').delete().eq('id', c.id)
    if (error) { onError(error.message); return }
    cargar()
  }

  const pendientesFiltradas = filas.filter(c => c.estado === 'pendiente')

  const resumenVendedores = useMemo(() => {
    if (!esAdmin) return []
    const m = {}
    for (const c of comisiones) {
      if (c.estado === 'anulada') continue
      m[c.vendedor_id] ??= { pendiente: 0, pagada: 0, mes: 0 }
      m[c.vendedor_id][c.estado] += Number(c.importe)
      if (c.periodo.startsWith(mesAnterior())) m[c.vendedor_id].mes += Number(c.importe)
    }
    return Object.entries(m).map(([id, v]) => ({ id, nombre: nombreVendedor(id), ...v })).sort((a, b) => b.pendiente - a.pendiente)
  }, [comisiones, esAdmin, vendedores])

  if (cargando) return <div style={S.vacio}>Cargando…</div>

  return (
    <>
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 20 }}>
        <Kpi titulo="Pendiente de pago" valor={fmtEuro(suma(filtroVendedor === 'todos' ? comisiones : comisiones.filter(c => c.vendedor_id === filtroVendedor), 'pendiente'))} />
        <Kpi titulo="Pagado" valor={fmtEuro(suma(filtroVendedor === 'todos' ? comisiones : comisiones.filter(c => c.vendedor_id === filtroVendedor), 'pagada'))} />
        {!esAdmin && <Kpi titulo={`Generado en ${fmtMes(mesAnterior() + '-01')}`} valor={fmtEuro(generadasMesPasado)} />}
        <Kpi titulo="Estimación mensual" valor={fmtEuro(proyeccion)} detalle="Con la cartera activa y las cuotas de hoy" />
      </div>

      {esAdmin && (
        <div style={{ ...S.card, marginBottom: 20 }}>
          <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginBottom: 6 }}>Generar comisiones del mes</div>
          <div style={{ fontSize: 12, color: C.texto2, marginBottom: 10, lineHeight: 1.5 }}>
            Crea una comisión por cada cliente con vendedor que haya pagado ese mes (activo, sin trial, cuota mayor que 0) y no haya agotado sus cuotas. Se puede repetir sin duplicar. La cuota base es el descuento vigente al inicio del mes, si lo hay; si no, el precio del plan.
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            <input style={S.inputSm} type="month" value={mesGenerar} max={mesActual.slice(0, 7)} onChange={e => setMesGenerar(e.target.value)} />
            <button style={S.primaryBtn(generando)} disabled={generando} onClick={generar}>{generando ? 'Generando…' : 'Generar'}</button>
          </div>
        </div>
      )}

      {esAdmin && resumenVendedores.length > 0 && (
        <div style={{ marginBottom: 24, overflowX: 'auto' }}>
          <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginBottom: 6 }}>Por vendedor</div>
          <table style={S.table}>
            <thead><tr><th style={S.th}>Vendedor</th><th style={S.th}>Generado mes anterior</th><th style={S.th}>Pendiente</th><th style={S.th}>Pagado</th></tr></thead>
            <tbody>
              {resumenVendedores.map(r => (
                <tr key={r.id} style={{ cursor: 'pointer' }} onClick={() => setFiltroVendedor(r.id)}>
                  <td style={S.td}>{r.nombre}</td>
                  <td style={S.td}>{fmtEuro(r.mes)}</td>
                  <td style={{ ...S.td, color: r.pendiente ? C.oro : C.texto2 }}>{fmtEuro(r.pendiente)}</td>
                  <td style={S.td}>{fmtEuro(r.pagada)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div style={S.toolbar}>
        {esAdmin && (
          <select style={S.inputSm} value={filtroVendedor} onChange={e => setFiltroVendedor(e.target.value)}>
            <option value="todos">Todos los vendedores</option>
            {vendedores.map(v => <option key={v.id} value={v.id}>{v.nombre}</option>)}
          </select>
        )}
        <select style={S.inputSm} value={filtroEstado} onChange={e => setFiltroEstado(e.target.value)}>
          <option value="todos">Todos los estados</option>
          <option value="pendiente">Pendientes</option>
          <option value="pagada">Pagadas</option>
          <option value="anulada">Anuladas</option>
        </select>
        <input style={S.inputSm} type="month" value={filtroMes} onChange={e => setFiltroMes(e.target.value)} />
        {filtroMes && <button style={S.linkBtn} onClick={() => setFiltroMes('')}>Todos los meses</button>}
        <div style={{ flex: 1 }} />
        {esAdmin && pendientesFiltradas.length > 0 && (
          <button style={S.linkBtn} onClick={() => {
            if (window.confirm(`¿Marcar como pagadas ${pendientesFiltradas.length} comisiones (${fmtEuro(suma(pendientesFiltradas, 'pendiente'))})?`)) cambiarEstado(pendientesFiltradas.map(c => c.id), 'pagada')
          }}>Marcar {pendientesFiltradas.length} como pagadas</button>
        )}
      </div>

      <div style={{ overflowX: 'auto' }}>
        <table style={S.table}>
          <thead>
            <tr>
              <th style={S.th}>Mes</th>
              {esAdmin && <th style={S.th}>Vendedor</th>}
              <th style={S.th}>Cliente</th>
              <th style={S.th}>Cuota</th>
              <th style={S.th}>Base</th>
              <th style={S.th}>Comisión</th>
              <th style={S.th}>Estado</th>
              {esAdmin && <th style={S.th}></th>}
            </tr>
          </thead>
          <tbody>
            {filas.map(c => {
              const cuenta = cuentaPorId[c.cuenta_id]
              return (
                <tr key={c.id}>
                  <td style={{ ...S.td, textTransform: 'capitalize' }}>{fmtMes(c.periodo)}</td>
                  {esAdmin && <td style={S.td}>{nombreVendedor(c.vendedor_id)}</td>}
                  <td style={S.td}>{cuenta?.nombre || '—'}</td>
                  <td style={S.td}>#{c.numero_cuota}{cuenta?.comision_cuotas ? ` de ${cuenta.comision_cuotas}` : ''}</td>
                  <td style={S.td}>{fmtEuro(c.cuota_base)}</td>
                  <td style={S.td}><span style={{ fontWeight: 500 }}>{fmtEuro(c.importe)}</span> <span style={{ fontSize: 11, color: C.muted }}>({c.porcentaje}%)</span></td>
                  <td style={S.td}>
                    <span style={c.estado === 'pagada' ? S.badge(C.okBg, C.ok) : c.estado === 'anulada' ? S.badge('#1f1f1f', C.muted) : S.badge('#2a2414', C.oro)}>
                      {c.estado === 'pagada' ? 'Pagada' : c.estado === 'anulada' ? 'Anulada' : 'Pendiente'}
                    </span>
                    {c.pagada_en && <div style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>{fmtFecha(c.pagada_en)}</div>}
                  </td>
                  {esAdmin && (
                    <td style={{ ...S.td, whiteSpace: 'nowrap' }}>
                      {c.estado === 'pendiente' && <button style={{ ...S.linkBtn, marginRight: 6 }} onClick={() => cambiarEstado([c.id], 'pagada')}>Pagada</button>}
                      {c.estado === 'pendiente' && <button style={{ ...S.logoutBtn, padding: '6px 10px', fontSize: 12, marginRight: 6 }} onClick={() => cambiarEstado([c.id], 'anulada')}>Anular</button>}
                      {c.estado !== 'pendiente' && <button style={{ ...S.logoutBtn, padding: '6px 10px', fontSize: 12, marginRight: 6 }} onClick={() => cambiarEstado([c.id], 'pendiente')}>Volver a pendiente</button>}
                      <button style={{ ...S.logoutBtn, padding: '6px 10px', fontSize: 12 }} onClick={() => borrar(c)} title="Borrar">✕</button>
                    </td>
                  )}
                </tr>
              )
            })}
          </tbody>
        </table>
        {filas.length === 0 && <div style={S.vacio}>{esAdmin ? 'No hay comisiones con estos filtros. Genera las de un mes arriba.' : 'Todavía no tienes comisiones generadas.'}</div>}
      </div>
    </>
  )
}
