import { useState, useEffect, useMemo, useCallback } from 'react'
import { supabase } from '../../lib/supabase'
import { S, FUENTES_LINK } from './estilos'
import { hoyISO } from '../../lib/crm'
import CrmTablero from './CrmTablero'
import CrmLista from './CrmLista'
import CrmTareas from './CrmTareas'
import CrmClientes from './CrmClientes'
import CrmComisiones from './CrmComisiones'
import CrmMetricas from './CrmMetricas'
import CrmVendedores from './CrmVendedores'
import CrmFicha from './CrmFicha'

/**
 * CRM de vendedores. La misma pantalla sirve a los dos roles:
 *   modo="superadmin" → toda la cartera, asignación, vendedores, comisiones.
 *   modo="vendedor"   → solo sus cuentas (lo garantiza la RLS, no esto).
 * Qué se puede tocar lo decide la base (sql/crm_vendedores.sql); aquí solo
 * se ocultan los controles que no aplican.
 */
export default function CrmApp({ modo, subtitulo, navExtra, onLogout }) {
  const esAdmin = modo === 'superadmin'
  const [tab, setTab] = useState('tablero')
  const [cuentas, setCuentas] = useState([])
  const [tareas, setTareas] = useState([])
  const [vendedores, setVendedores] = useState([])
  const [planes, setPlanes] = useState([])
  const [clientesInfo, setClientesInfo] = useState({}) // cuenta_id → datos del restaurante
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [aviso, setAviso] = useState(null)

  const [busqueda, setBusqueda] = useState('')
  const [filtroVendedor, setFiltroVendedor] = useState('todos') // todos | sin | <id>
  const [fichaId, setFichaId] = useState(null) // null | 'nueva' | uuid
  const [fichaEtapaInicial, setFichaEtapaInicial] = useState(null)

  const cargar = useCallback(async () => {
    const [cu, ta, ve, pl, ci] = await Promise.all([
      supabase.from('crm_cuentas').select('*').order('updated_at', { ascending: false }),
      supabase.from('crm_tareas').select('*').order('vence_en'),
      supabase.from('vendedores').select('*').order('nombre'),
      supabase.from('planes').select('key, nombre, precio, orden').order('orden'),
      supabase.rpc('fn_crm_restaurantes_cuentas'),
    ])
    const err = cu.error || ta.error || ve.error || pl.error || ci.error
    if (err) setError(err.message)
    setCuentas(cu.data || [])
    setTareas(ta.data || [])
    setVendedores(ve.data || [])
    setPlanes(pl.data || [])
    setClientesInfo(Object.fromEntries((ci.data || []).map(r => [r.cuenta_id, r])))
    setLoading(false)
  }, [])

  useEffect(() => { cargar() }, [cargar])

  const cuentasFiltradas = useMemo(() => {
    const q = busqueda.trim().toLowerCase()
    return cuentas.filter(c => {
      if (esAdmin && filtroVendedor === 'sin' && c.vendedor_id) return false
      if (esAdmin && filtroVendedor !== 'todos' && filtroVendedor !== 'sin' && c.vendedor_id !== filtroVendedor) return false
      if (!q) return true
      return [c.nombre, c.contacto_nombre, c.ciudad, c.telefono, c.email].some(v => v && v.toLowerCase().includes(q))
    })
  }, [cuentas, busqueda, filtroVendedor, esAdmin])

  const idsFiltrados = useMemo(() => new Set(cuentasFiltradas.map(c => c.id)), [cuentasFiltradas])
  const tareasFiltradas = useMemo(() => tareas.filter(t => idsFiltrados.has(t.cuenta_id)), [tareas, idsFiltrados])
  const tareasPendientesHoy = useMemo(
    () => tareasFiltradas.filter(t => !t.completada && t.vence_en <= hoyISO()).length,
    [tareasFiltradas]
  )

  async function moverEtapa(cuenta, etapa) {
    if (cuenta.etapa === etapa) return
    if (etapa === 'perdido') { abrirFicha(cuenta.id); setAviso('Indica el motivo de pérdida en la ficha y guarda.'); return }
    if (!esAdmin && cuenta.restaurant_id) { setError('Un cliente ya convertido no se mueve de etapa desde aquí. Habla con administración.'); return }
    setCuentas(prev => prev.map(c => c.id === cuenta.id ? { ...c, etapa } : c))
    const { data, error: err } = await supabase.from('crm_cuentas').update({ etapa }).eq('id', cuenta.id).select().single()
    if (err) { setError(err.message); cargar(); return }
    setCuentas(prev => prev.map(c => c.id === cuenta.id ? data : c))
    if (etapa === 'ganado' && !cuenta.restaurant_id) {
      setAviso(esAdmin
        ? `"${cuenta.nombre}" marcado como ganado. Ábrelo y pulsa "Convertir en restaurante" para darlo de alta.`
        : `¡Bien! "${cuenta.nombre}" marcado como ganado. Administración lo dará de alta como restaurante.`)
    }
  }

  function abrirFicha(id, etapaInicial = null) {
    setFichaEtapaInicial(etapaInicial)
    setFichaId(id)
  }

  const vendedoresActivos = vendedores.filter(v => v.activo)
  const nombreVendedor = useCallback(id => vendedores.find(v => v.id === id)?.nombre || null, [vendedores])

  const tabs = [
    { key: 'tablero', label: 'Tablero' },
    { key: 'lista', label: 'Lista' },
    { key: 'tareas', label: `Tareas${tareasPendientesHoy ? ` (${tareasPendientesHoy})` : ''}` },
    { key: 'clientes', label: 'Clientes' },
    { key: 'comisiones', label: 'Comisiones' },
    { key: 'metricas', label: 'Métricas' },
    ...(esAdmin ? [{ key: 'vendedores', label: 'Vendedores' }] : []),
  ]
  const tabUsaFiltros = ['tablero', 'lista', 'tareas', 'clientes', 'metricas'].includes(tab)

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <div style={S.app}>
      <link href={FUENTES_LINK} rel="stylesheet" />
      <div style={S.header}>
        <div>
          <div style={S.logo}><img src="/logos/opcion-2-monograma/icon-dark.svg" alt="" style={{ height: 22, verticalAlign: 'middle', marginRight: 8 }} />Restomind</div>
          <div style={S.sub}>{subtitulo}</div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          {navExtra}
          <button style={S.logoutBtn} onClick={onLogout}>Cerrar sesión</button>
        </div>
      </div>

      <div style={S.content}>
        {error && <div style={S.error} onClick={() => setError(null)} role="button" title="Click para cerrar">{error}</div>}
        {aviso && <div style={S.success} onClick={() => setAviso(null)} role="button" title="Click para cerrar">{aviso}</div>}

        <div style={S.tabBar}>
          {tabs.map(t => <button key={t.key} style={S.tabBtn(tab === t.key)} onClick={() => setTab(t.key)}>{t.label}</button>)}
        </div>

        {tabUsaFiltros && (
          <div style={S.toolbar}>
            <input style={{ ...S.inputSm, flex: '1 1 240px', maxWidth: 360 }} placeholder="Buscar por nombre, contacto, ciudad, teléfono…" value={busqueda} onChange={e => setBusqueda(e.target.value)} />
            {esAdmin && (
              <select style={S.inputSm} value={filtroVendedor} onChange={e => setFiltroVendedor(e.target.value)}>
                <option value="todos">Todos los vendedores</option>
                <option value="sin">Sin asignar</option>
                {vendedores.map(v => <option key={v.id} value={v.id}>{v.nombre}{v.activo ? '' : ' (inactivo)'}</option>)}
              </select>
            )}
            <div style={{ flex: 1 }} />
            <button style={S.primaryBtn(false)} onClick={() => abrirFicha('nueva')}>+ Nueva cuenta</button>
          </div>
        )}

        {tab === 'tablero' && (
          <CrmTablero cuentas={cuentasFiltradas} tareas={tareasFiltradas} esAdmin={esAdmin}
            nombreVendedor={nombreVendedor} onAbrir={abrirFicha} onMover={moverEtapa} />
        )}
        {tab === 'lista' && (
          <CrmLista cuentas={cuentasFiltradas} esAdmin={esAdmin} planes={planes}
            nombreVendedor={nombreVendedor} onAbrir={abrirFicha} />
        )}
        {tab === 'tareas' && (
          <CrmTareas tareas={tareasFiltradas} cuentas={cuentas} esAdmin={esAdmin}
            nombreVendedor={nombreVendedor} onAbrir={abrirFicha} onCambio={cargar} onError={setError} />
        )}
        {tab === 'clientes' && (
          <CrmClientes cuentas={cuentasFiltradas} clientesInfo={clientesInfo} planes={planes} esAdmin={esAdmin}
            nombreVendedor={nombreVendedor} onAbrir={abrirFicha} />
        )}
        {tab === 'comisiones' && (
          <CrmComisiones esAdmin={esAdmin} cuentas={cuentas} clientesInfo={clientesInfo} vendedores={vendedores}
            onError={setError} onAviso={setAviso} />
        )}
        {tab === 'metricas' && (
          <CrmMetricas cuentas={cuentasFiltradas} clientesInfo={clientesInfo} vendedores={vendedores}
            esAdmin={esAdmin} filtroVendedor={filtroVendedor} />
        )}
        {tab === 'vendedores' && esAdmin && (
          <CrmVendedores vendedores={vendedores} cuentas={cuentas} clientesInfo={clientesInfo}
            onCambio={cargar} onError={setError} onAviso={setAviso} />
        )}
      </div>

      {fichaId && (
        <CrmFicha
          cuentaId={fichaId === 'nueva' ? null : fichaId}
          etapaInicial={fichaEtapaInicial}
          esAdmin={esAdmin}
          vendedores={vendedoresActivos}
          todosVendedores={vendedores}
          planes={planes}
          cuentas={cuentas}
          clienteInfo={fichaId !== 'nueva' ? clientesInfo[fichaId] : null}
          vendedorPorDefecto={esAdmin && filtroVendedor !== 'todos' && filtroVendedor !== 'sin' ? filtroVendedor : null}
          onCerrar={() => setFichaId(null)}
          onGuardado={async (id) => { await cargar(); if (id) setFichaId(id) }}
          onBorrado={async () => { setFichaId(null); await cargar() }}
        />
      )}
    </div>
  )
}
