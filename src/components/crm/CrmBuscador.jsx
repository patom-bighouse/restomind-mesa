import { useState, useEffect, useMemo } from 'react'
import { supabase } from '../../lib/supabase'
import { S, C } from './estilos'
import {
  TIPOS_BUSQUEDA, PAISES_BUSQUEDA, TAMANOS, tamanoPorResenas, tamanoLabel, nivelPrecioLabel,
  diasDesde, fmtFechaHora,
} from '../../lib/crm'

const B = {
  uso: { display: 'flex', gap: 16, alignItems: 'center', flexWrap: 'wrap', background: C.bg, border: `0.5px solid ${C.borde}`, borderRadius: 12, padding: '12px 16px', marginTop: 14 },
  usoNum: { fontSize: 22, fontWeight: 600, fontFamily: "'Playfair Display', serif" },
  barra: { flex: '1 1 160px', height: 6, background: '#222', borderRadius: 3, overflow: 'hidden', minWidth: 120 },
  bloque: { background: C.bg, border: `0.5px solid ${C.borde}`, borderRadius: 12, padding: '4px 16px 16px', marginTop: 14 },
  chk: { fontSize: 12, color: C.texto2, display: 'flex', gap: 6, alignItems: 'center', cursor: 'pointer', whiteSpace: 'nowrap' },
  reciente: activa => ({ background: activa ? '#1a1810' : 'transparent', border: `0.5px solid ${activa ? C.oro : C.borde}`, borderRadius: 8, padding: '7px 12px', fontSize: 12, color: C.texto, cursor: 'pointer', textAlign: 'left', fontFamily: "'Inter', sans-serif" }),
  pie: { position: 'sticky', bottom: -24, background: C.card, borderTop: `0.5px solid ${C.borde}`, padding: '14px 0 0', marginTop: 12, display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' },
}

const fmtUsd = n => `${Number(n || 0).toLocaleString('es-ES', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} US$`
const tipoBusquedaLabel = key => TIPOS_BUSQUEDA.find(t => t.key === key)?.label || key
const hace = iso => { const d = diasDesde(iso); return d === 0 ? 'hoy' : d === 1 ? 'ayer' : `hace ${d} días` }
const normalizarNombre = s => (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]/g, '')

async function mensajeError(err, data) {
  let msg = data?.error || err?.message || 'Error desconocido'
  // supabase-js no expone el cuerpo cuando la función responde con un
  // status distinto de 2xx: se lee del Response crudo.
  if (err?.context?.json) {
    try { const body = await err.context.json(); if (body?.error) msg = body.error } catch { /* noop */ }
  }
  return msg
}

export default function CrmBuscador({ vendedores, onCerrar, onImportado }) {
  const [uso, setUso] = useState(null)
  const [verAjustes, setVerAjustes] = useState(false)
  const [ajustes, setAjustes] = useState({ gratis: '', precio: '' })

  const [zona, setZona] = useState('')
  const [tipo, setTipo] = useState('restaurante')
  const [pais, setPais] = useState('ES')
  const [valoracionMin, setValoracionMin] = useState('0')
  const [paginas, setPaginas] = useState('3')

  const [buscando, setBuscando] = useState(false)
  const [error, setError] = useState(null)
  const [aviso, setAviso] = useState(null)
  const [locales, setLocales] = useState(null) // null = aún no se buscó
  const [buscado, setBuscado] = useState(null) // parámetros de la última búsqueda
  const [busquedaId, setBusquedaId] = useState(null) // búsqueda guardada que se está viendo
  const [recientes, setRecientes] = useState([])
  const [verTodasRecientes, setVerTodasRecientes] = useState(false)
  const [abriendo, setAbriendo] = useState(null)

  // Filtros sobre los resultados (no gastan consultas)
  const [tamanos, setTamanos] = useState(TAMANOS.map(t => t.key))
  const [minResenas, setMinResenas] = useState('')
  const [soloTelefono, setSoloTelefono] = useState(false)
  const [soloWeb, setSoloWeb] = useState(false)
  const [ocultarDuplicados, setOcultarDuplicados] = useState(true)
  const [ocultarCerrados, setOcultarCerrados] = useState(true)

  const [seleccion, setSeleccion] = useState(new Set())
  const [vendedorId, setVendedorId] = useState('')
  const [importando, setImportando] = useState(false)

  async function cargarUso() {
    const { data, error: err } = await supabase.rpc('fn_crm_uso_places')
    if (err) { setError(err.message); return }
    setUso(data?.[0] || null)
  }
  async function cargarRecientes() {
    const { data, error: err } = await supabase.rpc('fn_crm_busquedas_recientes')
    if (err) { setError(err.message); return }
    setRecientes(data || [])
  }
  useEffect(() => { cargarUso(); cargarRecientes() }, [])

  // Reabre una búsqueda guardada sin consultar a Google.
  async function abrirBusqueda(b) {
    setAbriendo(b.id)
    setError(null)
    setAviso(null)
    const { data, error: err } = await supabase.rpc('fn_crm_busqueda_cargar', { p_id: b.id })
    setAbriendo(null)
    if (err) { setError(err.message); return }
    const fila = data?.[0]
    if (!fila) { setError('Esta búsqueda ya no está disponible (los resultados se guardan 30 días).'); cargarRecientes(); return }
    const p = fila.parametros || {}
    setZona(p.zona || '')
    setTipo(p.tipo || 'restaurante')
    setPais(p.pais || 'ES')
    setValoracionMin(String(p.valoracion_min ?? 0))
    setPaginas(String(p.paginas || 3))
    setLocales(fila.locales || [])
    setBuscado(p)
    setBusquedaId(b.id)
    setSeleccion(new Set())
    setAviso(`Búsqueda del ${fmtFechaHora(fila.created_at)} abierta sin gastar consultas. Los datos de Google son de ese día; "Ya en el CRM" está actualizado a hoy.`)
  }

  async function guardarAjustes() {
    const gratis = parseInt(ajustes.gratis, 10)
    const precio = Number(ajustes.precio)
    if (!(gratis >= 0) || !(precio >= 0)) { setError('Revisa los valores: deben ser números positivos.'); return }
    const { error: err } = await supabase.from('crm_config').update({ places_gratis_mes: gratis, places_precio_1000: precio, updated_at: new Date().toISOString() }).eq('id', true)
    if (err) { setError(err.message); return }
    setVerAjustes(false)
    cargarUso()
  }

  async function buscar(e) {
    e.preventDefault()
    if (zona.trim().length < 2) { setError('Indica una zona: barrio, ciudad o código postal.'); return }
    setBuscando(true)
    setError(null)
    setAviso(null)
    const parametros = { zona: zona.trim(), tipo, pais, valoracion_min: Number(valoracionMin), paginas: Number(paginas) }
    const { data, error: err } = await supabase.functions.invoke('crm-buscar-restaurantes', { body: parametros })
    setBuscando(false)
    if (err || data?.error) {
      setError(await mensajeError(err, data))
      cargarUso()
      return
    }
    if (data.uso) setUso(data.uso)
    setLocales(data.locales || [])
    setBuscado(parametros)
    setBusquedaId(data.busqueda_id || null)
    setSeleccion(new Set())
    if (data.aviso) setAviso(data.aviso)
    cargarRecientes()
  }

  // Mismo nombre en varias direcciones dentro de los resultados → cadena.
  const cadenas = useMemo(() => {
    const n = {}
    for (const l of locales || []) { const k = normalizarNombre(l.nombre); n[k] = (n[k] || 0) + 1 }
    return n
  }, [locales])

  const visibles = useMemo(() => (locales || []).filter(l => {
    const tam = tamanoPorResenas(l.num_resenas)
    if (!tamanos.includes(tam)) return false
    if (minResenas !== '' && l.num_resenas < Number(minResenas)) return false
    if (soloTelefono && !l.telefono) return false
    if (soloWeb && !l.web) return false
    if (ocultarDuplicados && l.duplicado) return false
    if (ocultarCerrados && l.estado === 'CLOSED_PERMANENTLY') return false
    return true
  }).sort((a, b) => b.num_resenas - a.num_resenas), [locales, tamanos, minResenas, soloTelefono, soloWeb, ocultarDuplicados, ocultarCerrados])

  const seleccionables = visibles.filter(l => !l.duplicado)
  // Solo se importa lo seleccionado que sigue visible con los filtros actuales.
  const elegidos = seleccionables.filter(l => seleccion.has(l.place_id))
  const todosMarcados = seleccionables.length > 0 && seleccionables.every(l => seleccion.has(l.place_id))

  function alternar(id) {
    setSeleccion(prev => { const s = new Set(prev); s.has(id) ? s.delete(id) : s.add(id); return s })
  }
  function alternarTodos() {
    setSeleccion(prev => {
      const s = new Set(prev)
      if (todosMarcados) seleccionables.forEach(l => s.delete(l.place_id))
      else seleccionables.forEach(l => s.add(l.place_id))
      return s
    })
  }

  async function importar() {
    if (!elegidos.length) return
    const tipoLocal = TIPOS_BUSQUEDA.find(t => t.key === buscado?.tipo)?.tipoLocal || 'Restaurante'
    const filas = elegidos.map(l => ({
      nombre: l.nombre,
      direccion: l.direccion,
      ciudad: l.ciudad,
      pais: buscado?.pais || 'ES',
      telefono: l.telefono,
      web: /^https?:\/\//i.test(l.web || '') ? l.web : null,
      tipo_local: tipoLocal,
      fuente: 'Búsqueda Google',
      etapa: 'prospecto',
      vendedor_id: vendedorId || null,
      maps_url: l.maps_url,
      google_place_id: l.place_id,
      valoracion: l.valoracion,
      num_resenas: l.num_resenas,
      nivel_precio: l.nivel_precio,
      tamano_estimado: tamanoPorResenas(l.num_resenas),
      notas: l.tipo_google ? `Google: ${l.tipo_google}` : null,
    }))
    setImportando(true)
    setError(null)
    // Si otro usuario importó el mismo local mientras tanto, se ignora.
    const { data, error: err } = await supabase.from('crm_cuentas')
      .upsert(filas, { onConflict: 'google_place_id', ignoreDuplicates: true })
      .select('google_place_id')
    setImportando(false)
    if (err) { setError(err.message); return }
    const insertados = new Set((data || []).map(r => r.google_place_id))
    const ids = new Set(elegidos.map(l => l.place_id))
    setLocales(prev => prev.map(l => ids.has(l.place_id) ? { ...l, duplicado: l.duplicado || 'importado' } : l))
    setSeleccion(new Set())
    const omitidos = elegidos.length - insertados.size
    const vendedor = vendedores.find(v => v.id === vendedorId)?.nombre
    setAviso(`${insertados.size} restaurante${insertados.size === 1 ? '' : 's'} importado${insertados.size === 1 ? '' : 's'} como Prospecto${vendedor ? ` y asignado${insertados.size === 1 ? '' : 's'} a ${vendedor}` : ' sin asignar'}.${omitidos ? ` ${omitidos} ya estaban en el CRM.` : ''}`)
    onImportado()
  }

  const consultasMax = Number(paginas)
  const pct = uso ? Math.min(100, (uso.usadas_mes / Math.max(uso.gratis_mes, 1)) * 100) : 0

  return (
    <div style={S.modal}>
      <div style={{ ...S.modalBox(1300), maxHeight: '94vh' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
          <div>
            <div style={S.modalTitle}>Buscar restaurantes</div>
            <div style={{ fontSize: 12, color: C.texto2 }}>Encuentra locales en Google y súmalos al CRM como prospectos.</div>
          </div>
          <button style={S.ghostBtn} onClick={onCerrar}>Cerrar</button>
        </div>

        {/* Contador de consultas */}
        {uso && (
          <div style={B.uso}>
            {uso.excedidas > 0 ? (
              <>
                <div>
                  <div style={{ ...B.usoNum, color: C.mal }}>{uso.excedidas.toLocaleString('es-ES')}</div>
                  <div style={{ fontSize: 11, color: C.texto2 }}>consultas excedidas este mes</div>
                </div>
                <div style={{ fontSize: 13, color: C.texto }}>
                  Gratis agotadas ({uso.gratis_mes.toLocaleString('es-ES')}). Coste estimado: <strong style={{ color: C.mal }}>{fmtUsd(uso.coste_estimado)}</strong>
                  <div style={{ fontSize: 11, color: C.texto2, marginTop: 2 }}>{uso.precio_1000} US$ por cada 1.000 consultas · {uso.usadas_mes.toLocaleString('es-ES')} usadas este mes</div>
                </div>
              </>
            ) : (
              <>
                <div>
                  <div style={{ ...B.usoNum, color: uso.restantes < uso.gratis_mes * 0.1 ? C.aviso : C.ok }}>{uso.restantes.toLocaleString('es-ES')}</div>
                  <div style={{ fontSize: 11, color: C.texto2 }}>consultas gratis restantes este mes</div>
                </div>
                <div style={B.barra}><div style={{ width: `${pct}%`, height: '100%', background: C.oro }} /></div>
                <div style={{ fontSize: 12, color: C.texto2 }}>{uso.usadas_mes.toLocaleString('es-ES')} de {uso.gratis_mes.toLocaleString('es-ES')} usadas</div>
              </>
            )}
            <div style={{ flex: 1 }} />
            <button style={S.linkBtn} onClick={() => { setAjustes({ gratis: String(uso.gratis_mes), precio: String(uso.precio_1000) }); setVerAjustes(v => !v) }}>Ajustar tarifa</button>
          </div>
        )}
        {verAjustes && (
          <div style={{ ...S.toolbar, marginTop: 10, marginBottom: 0 }}>
            <label style={{ fontSize: 12, color: C.texto2 }}>Consultas gratis al mes</label>
            <input style={{ ...S.inputSm, width: 90 }} type="number" min="0" value={ajustes.gratis} onChange={e => setAjustes(a => ({ ...a, gratis: e.target.value }))} />
            <label style={{ fontSize: 12, color: C.texto2 }}>US$ por 1.000</label>
            <input style={{ ...S.inputSm, width: 80 }} type="number" min="0" step="0.01" value={ajustes.precio} onChange={e => setAjustes(a => ({ ...a, precio: e.target.value }))} />
            <button style={S.linkBtn} onClick={guardarAjustes}>Guardar</button>
          </div>
        )}
        <div style={S.hint}>
          Cada página de hasta 20 locales es 1 consulta a Google ("Text Search Enterprise"). El mes se reinicia el día 1 (hora del Pacífico).
          Este contador solo suma las búsquedas hechas en este entorno: si staging y producción usan la misma clave, Google descuenta ambas del mismo cupo.
        </div>

        {/* Búsqueda */}
        <form style={B.bloque} onSubmit={buscar}>
          <div style={{ ...S.fila, flexWrap: 'wrap' }}>
            <div style={{ flex: '2 1 260px' }}>
              <label style={S.label}>Zona *</label>
              <input style={S.input} value={zona} onChange={e => setZona(e.target.value)} placeholder="Barrio, ciudad o código postal · ej. Ruzafa, Valencia" />
            </div>
            <div style={{ flex: '1 1 180px' }}>
              <label style={S.label}>Tipo</label>
              <select style={S.input} value={tipo} onChange={e => setTipo(e.target.value)}>
                {TIPOS_BUSQUEDA.map(t => <option key={t.key} value={t.key}>{t.label}</option>)}
              </select>
            </div>
            <div style={{ flex: '1 1 130px' }}>
              <label style={S.label}>País</label>
              <select style={S.input} value={pais} onChange={e => setPais(e.target.value)}>
                {PAISES_BUSQUEDA.map(p => <option key={p.key} value={p.key}>{p.label}</option>)}
              </select>
            </div>
            <div style={{ flex: '1 1 130px' }}>
              <label style={S.label}>Valoración mínima</label>
              <select style={S.input} value={valoracionMin} onChange={e => setValoracionMin(e.target.value)}>
                <option value="0">Cualquiera</option>
                {['3', '3.5', '4', '4.5'].map(v => <option key={v} value={v}>★ {v.replace('.', ',')} o más</option>)}
              </select>
            </div>
            <div style={{ flex: '1 1 150px' }}>
              <label style={S.label}>Resultados</label>
              <select style={S.input} value={paginas} onChange={e => setPaginas(e.target.value)}>
                <option value="1">Hasta 20 (1 consulta)</option>
                <option value="2">Hasta 40 (2 consultas)</option>
                <option value="3">Hasta 60 (3 consultas)</option>
              </select>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginTop: 14, flexWrap: 'wrap' }}>
            <button type="submit" style={S.primaryBtn(buscando)} disabled={buscando}>{buscando ? 'Buscando…' : 'Buscar'}</button>
            <span style={{ fontSize: 12, color: C.texto2 }}>
              Gastará hasta {consultasMax} consulta{consultasMax > 1 ? 's' : ''}
              {uso && uso.restantes < consultasMax ? (uso.restantes > 0 ? ` · ${consultasMax - uso.restantes} de pago` : ' de pago') : ''}.
              Google devuelve como máximo 60 locales por búsqueda: para una ciudad grande, busca por barrios.
            </span>
          </div>
        </form>

        {/* Búsquedas guardadas */}
        {recientes.length > 0 && (
          <div style={{ marginTop: 14 }}>
            <div style={{ fontSize: 12, color: C.texto2, marginBottom: 8 }}>
              Búsquedas recientes · se abren <strong style={{ color: C.ok }}>sin gastar consultas</strong> · se guardan 30 días
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {(verTodasRecientes ? recientes : recientes.slice(0, 6)).map(b => (
                <button key={b.id} type="button" style={B.reciente(b.id === busquedaId)} disabled={!!abriendo} onClick={() => abrirBusqueda(b)}
                  title={`${fmtFechaHora(b.created_at)} · ${b.autor_nombre || ''}`}>
                  <div style={{ fontWeight: 500 }}>{abriendo === b.id ? 'Abriendo…' : `${tipoBusquedaLabel(b.parametros?.tipo)} · ${b.parametros?.zona || '—'}`}</div>
                  <div style={{ fontSize: 11, color: C.muted, marginTop: 2 }}>
                    {b.resultados} locales{Number(b.parametros?.valoracion_min) > 0 ? ` · ★ ${String(b.parametros.valoracion_min).replace('.', ',')}+` : ''} · {hace(b.created_at)}
                  </div>
                </button>
              ))}
              {recientes.length > 6 && (
                <button type="button" style={S.linkBtn} onClick={() => setVerTodasRecientes(v => !v)}>
                  {verTodasRecientes ? 'Ver menos' : `Ver las ${recientes.length}`}
                </button>
              )}
            </div>
          </div>
        )}

        {error && <div style={{ ...S.error, marginTop: 14 }} onClick={() => setError(null)} role="button">{error}</div>}
        {aviso && <div style={{ ...S.success, marginTop: 14 }} onClick={() => setAviso(null)} role="button">{aviso}</div>}

        {/* Resultados */}
        {locales && (
          <>
            <div style={{ ...S.toolbar, marginTop: 16, marginBottom: 10 }}>
              <span style={{ fontSize: 12, color: C.texto2 }}>Tamaño:</span>
              {TAMANOS.map(t => (
                <label key={t.key} style={B.chk}>
                  <input type="checkbox" checked={tamanos.includes(t.key)}
                    onChange={e => setTamanos(prev => e.target.checked ? [...prev, t.key] : prev.filter(k => k !== t.key))} />
                  {t.label}
                </label>
              ))}
              <span style={{ fontSize: 12, color: C.texto2, marginLeft: 8 }}>Mín. reseñas</span>
              <input style={{ ...S.inputSm, width: 70 }} type="number" min="0" value={minResenas} onChange={e => setMinResenas(e.target.value)} placeholder="0" />
              <label style={B.chk}><input type="checkbox" checked={soloTelefono} onChange={e => setSoloTelefono(e.target.checked)} /> Con teléfono</label>
              <label style={B.chk}><input type="checkbox" checked={soloWeb} onChange={e => setSoloWeb(e.target.checked)} /> Con web</label>
              <label style={B.chk}><input type="checkbox" checked={ocultarDuplicados} onChange={e => setOcultarDuplicados(e.target.checked)} /> Ocultar los que ya están en el CRM</label>
              <label style={B.chk}><input type="checkbox" checked={ocultarCerrados} onChange={e => setOcultarCerrados(e.target.checked)} /> Ocultar cerrados</label>
            </div>
            <div style={S.hint}>
              Tamaño estimado por nº de reseñas: Pequeño &lt;150 · Mediano 150–599 · Grande 600–1.499 · Muy grande 1.500+. Es orientativo: las reseñas también crecen con la antigüedad y el turismo.
            </div>

            <div style={{ fontSize: 12, color: C.texto2, margin: '12px 0 6px' }}>
              {visibles.length} de {locales.length} locales encontrados
              {locales.length - visibles.length > 0 ? ` (${locales.length - visibles.length} ocultos por los filtros)` : ''}
            </div>

            <div style={{ overflowX: 'auto' }}>
              <table style={S.table}>
                <thead>
                  <tr>
                    <th style={{ ...S.th, width: 30 }}><input type="checkbox" checked={todosMarcados} onChange={alternarTodos} disabled={!seleccionables.length} title="Seleccionar todos los visibles" /></th>
                    <th style={S.th}>Restaurante</th>
                    <th style={S.th}>Ubicación</th>
                    <th style={S.th}>Teléfono</th>
                    <th style={S.th}>Web</th>
                    <th style={S.th}>Google</th>
                    <th style={S.th}>Tamaño</th>
                    <th style={S.th}>Precio</th>
                    <th style={S.th}></th>
                  </tr>
                </thead>
                <tbody>
                  {visibles.map(l => {
                    const marcado = seleccion.has(l.place_id)
                    const esCadena = cadenas[normalizarNombre(l.nombre)] > 1
                    return (
                      <tr key={l.place_id} style={{ opacity: l.duplicado ? 0.5 : 1, background: marcado ? '#1a1810' : 'transparent', cursor: l.duplicado ? 'default' : 'pointer' }}
                        onClick={() => !l.duplicado && alternar(l.place_id)}>
                        <td style={S.td}><input type="checkbox" checked={marcado} disabled={!!l.duplicado} onChange={() => alternar(l.place_id)} onClick={e => e.stopPropagation()} /></td>
                        <td style={S.td}>
                          <div style={{ fontWeight: 500 }}>{l.nombre}</div>
                          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 4 }}>
                            {l.tipo_google && <span style={{ fontSize: 11, color: C.muted }}>{l.tipo_google}</span>}
                            {esCadena && <span style={S.badge('#1f1f2a', '#9aa7e8')}>Cadena</span>}
                            {l.duplicado && <span style={S.badge('#1f1f1f', C.texto2)}>{l.duplicado === 'importado' ? 'Importado' : l.duplicado === 'telefono' ? 'Ya en el CRM (mismo teléfono)' : 'Ya en el CRM'}</span>}
                            {l.estado === 'CLOSED_TEMPORARILY' && <span style={S.badge('#2a2014', C.aviso)}>Cerrado temporalmente</span>}
                            {l.estado === 'CLOSED_PERMANENTLY' && <span style={S.badge(C.malBg, C.mal)}>Cerrado</span>}
                          </div>
                        </td>
                        <td style={{ ...S.td, maxWidth: 280 }}>
                          <div>{l.direccion || '—'}</div>
                          {l.ciudad && <div style={{ fontSize: 11, color: C.muted, marginTop: 2 }}>{l.ciudad}{l.codigo_postal ? ` · ${l.codigo_postal}` : ''}</div>}
                        </td>
                        <td style={{ ...S.td, whiteSpace: 'nowrap' }}>{l.telefono || <span style={{ color: C.muted }}>—</span>}</td>
                        <td style={{ ...S.td, maxWidth: 180, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {l.web ? <a href={l.web} target="_blank" rel="noreferrer" onClick={e => e.stopPropagation()} style={{ color: C.oro }}>{l.web.replace(/^https?:\/\/(www\.)?/, '').replace(/\/$/, '')}</a> : <span style={{ color: C.muted }}>—</span>}
                        </td>
                        <td style={{ ...S.td, whiteSpace: 'nowrap' }}>
                          {l.valoracion != null ? <>★ {String(l.valoracion).replace('.', ',')}</> : '—'}
                          <div style={{ fontSize: 11, color: C.muted }}>{l.num_resenas.toLocaleString('es-ES')} reseñas</div>
                        </td>
                        <td style={S.td}>{tamanoLabel(tamanoPorResenas(l.num_resenas))}</td>
                        <td style={S.td}>{nivelPrecioLabel(l.nivel_precio) || '—'}</td>
                        <td style={S.td}>
                          {l.maps_url && <a href={l.maps_url} target="_blank" rel="noreferrer" title="Ver en Google Maps" onClick={e => e.stopPropagation()} style={{ textDecoration: 'none' }}>📍</a>}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
              {visibles.length === 0 && <div style={S.vacio}>{locales.length ? 'Ningún local cumple los filtros.' : 'Google no encontró locales con esta búsqueda. Prueba otra zona o tipo.'}</div>}
            </div>

            <div style={B.pie}>
              <span style={{ fontSize: 13, color: C.texto }}>{elegidos.length} seleccionado{elegidos.length === 1 ? '' : 's'}</span>
              <div style={{ flex: 1 }} />
              <label style={{ fontSize: 12, color: C.texto2 }}>Asignar a</label>
              <select style={S.inputSm} value={vendedorId} onChange={e => setVendedorId(e.target.value)}>
                <option value="">Sin asignar</option>
                {vendedores.map(v => <option key={v.id} value={v.id}>{v.nombre}</option>)}
              </select>
              <button style={S.primaryBtn(importando || !elegidos.length)} disabled={importando || !elegidos.length} onClick={importar}>
                {importando ? 'Importando…' : `Importar ${elegidos.length || ''} al CRM`}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
