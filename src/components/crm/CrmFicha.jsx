import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { S, C, estiloEtapa } from './estilos'
import {
  ETAPAS, TIPOS_ACTIVIDAD, FUENTES, TIPOS_LOCAL, MOTIVOS_PERDIDA,
  etapaLabel, tipoActividad, hoyISO, fmtFecha, fmtFechaHora, fmtEuro, fmtMes,
} from '../../lib/crm'

const VACIO = {
  nombre: '', contacto_nombre: '', contacto_cargo: '', telefono: '', email: '',
  ciudad: '', pais: 'ES', direccion: '', tipo_local: '', num_mesas: '', fuente: '',
  etapa: 'prospecto', motivo_perdida: '', plan_interes: '', cuota_estimada: '',
  proxima_accion: '', proxima_accion_fecha: '', notas: '',
  vendedor_id: '', comision_pct: '', comision_cuotas: '', comision_inicio: '',
}

const CAMPOS_TEXTO = ['nombre', 'contacto_nombre', 'contacto_cargo', 'telefono', 'email', 'ciudad', 'pais', 'direccion',
  'tipo_local', 'fuente', 'etapa', 'motivo_perdida', 'plan_interes', 'proxima_accion', 'proxima_accion_fecha', 'notas']

function ahoraLocal() {
  const d = new Date()
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset())
  return d.toISOString().slice(0, 16)
}

export default function CrmFicha({
  cuentaId, etapaInicial, esAdmin, vendedores, todosVendedores, planes, cuentas, clienteInfo,
  vendedorPorDefecto, onCerrar, onGuardado, onBorrado,
}) {
  const navigate = useNavigate()
  const esNueva = !cuentaId
  const [tab, setTab] = useState('datos')
  const [cuenta, setCuenta] = useState(null)
  const [form, setForm] = useState({ ...VACIO, etapa: etapaInicial || 'prospecto', vendedor_id: vendedorPorDefecto || '' })
  const [actividades, setActividades] = useState([])
  const [historial, setHistorial] = useState([])
  const [tareas, setTareas] = useState([])
  const [comisiones, setComisiones] = useState([])
  const [cargando, setCargando] = useState(!esNueva)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState(null)

  const [nuevaAct, setNuevaAct] = useState({ tipo: 'llamada', descripcion: '', resultado: '', fecha: ahoraLocal() })
  const [nuevaTarea, setNuevaTarea] = useState({ titulo: '', vence_en: hoyISO() })
  const [restaurantesLibres, setRestaurantesLibres] = useState(null)
  const [vincularId, setVincularId] = useState('')

  useEffect(() => { if (cuentaId) cargar() }, [cuentaId])

  async function cargar() {
    const [cu, ac, hi, ta, co] = await Promise.all([
      supabase.from('crm_cuentas').select('*').eq('id', cuentaId).single(),
      supabase.from('crm_actividades').select('*').eq('cuenta_id', cuentaId).order('fecha', { ascending: false }),
      supabase.from('crm_historial').select('*').eq('cuenta_id', cuentaId).order('created_at', { ascending: false }),
      supabase.from('crm_tareas').select('*').eq('cuenta_id', cuentaId).order('vence_en'),
      supabase.from('crm_comisiones').select('*').eq('cuenta_id', cuentaId).order('periodo'),
    ])
    if (cu.error) { setError(cu.error.message); setCargando(false); return }
    const c = cu.data
    setCuenta(c)
    const f = { ...VACIO }
    for (const k of Object.keys(VACIO)) f[k] = c[k] == null ? '' : String(c[k])
    if (f.comision_inicio) f.comision_inicio = f.comision_inicio.slice(0, 7)
    setForm(f)
    setActividades(ac.data || [])
    setHistorial(hi.data || [])
    setTareas(ta.data || [])
    setComisiones(co.data || [])
    setCargando(false)
  }

  const set = (k, v) => setForm(prev => ({ ...prev, [k]: v }))

  // La cuota sigue al plan mientras no se haya escrito a mano: si está
  // vacía o coincide con el precio del plan anterior, pasa al del nuevo.
  function planElegido(key) {
    const plan = planes.find(p => p.key === key)
    setForm(prev => {
      const anterior = planes.find(p => p.key === prev.plan_interes)
      const automatica = prev.cuota_estimada === '' || (anterior?.precio != null && Number(prev.cuota_estimada) === Number(anterior.precio))
      return {
        ...prev,
        plan_interes: key,
        cuota_estimada: automatica ? (plan?.precio != null ? String(plan.precio) : '') : prev.cuota_estimada,
      }
    })
  }

  async function guardar() {
    if (!form.nombre.trim()) { setError('El nombre de la cuenta es obligatorio.'); return }
    if (form.etapa === 'perdido' && !form.motivo_perdida) { setError('Indica el motivo de pérdida.'); return }
    if (esAdmin && form.comision_pct !== '' && (Number(form.comision_pct) < 0 || Number(form.comision_pct) > 100)) {
      setError('La comisión debe estar entre 0 y 100 %.'); return
    }
    setGuardando(true)
    setError(null)
    const fila = {}
    for (const k of CAMPOS_TEXTO) fila[k] = form[k].trim?.() ? form[k].trim() : null
    fila.nombre = form.nombre.trim()
    fila.etapa = form.etapa
    fila.num_mesas = form.num_mesas === '' ? null : parseInt(form.num_mesas, 10)
    fila.cuota_estimada = form.cuota_estimada === '' ? null : Number(form.cuota_estimada)
    if (fila.etapa !== 'perdido') fila.motivo_perdida = null
    if (esAdmin) {
      fila.vendedor_id = form.vendedor_id || null
      fila.comision_pct = form.comision_pct === '' ? null : Number(form.comision_pct)
      fila.comision_cuotas = form.comision_cuotas === '' ? null : parseInt(form.comision_cuotas, 10)
      fila.comision_inicio = form.comision_inicio ? `${form.comision_inicio}-01` : null
      // Al cambiar de vendedor, si no se tocaron las condiciones, que
      // hereden las del nuevo vendedor (el trigger las rellena si van null).
      if (cuenta && cuenta.vendedor_id !== fila.vendedor_id
          && String(cuenta.comision_pct ?? '') === form.comision_pct
          && String(cuenta.comision_cuotas ?? '') === form.comision_cuotas) {
        fila.comision_pct = null
        fila.comision_cuotas = null
      }
    }

    const q = esNueva
      ? supabase.from('crm_cuentas').insert(fila).select().single()
      : supabase.from('crm_cuentas').update(fila).eq('id', cuentaId).select().single()
    const { data, error: err } = await q
    setGuardando(false)
    if (err) { setError(err.message); return }
    await onGuardado(data.id)
    if (!esNueva) await cargar()
  }

  async function borrar() {
    if (!window.confirm(`¿Borrar la cuenta "${cuenta.nombre}" con todas sus actividades, tareas y comisiones? No se puede deshacer. (El restaurante, si existe, no se toca.)`)) return
    const { error: err } = await supabase.from('crm_cuentas').delete().eq('id', cuentaId)
    if (err) { setError(err.message); return }
    onBorrado()
  }

  async function registrarActividad() {
    if (!nuevaAct.descripcion.trim()) { setError('Describe brevemente la actividad.'); return }
    setError(null)
    const { error: err } = await supabase.from('crm_actividades').insert({
      cuenta_id: cuentaId,
      tipo: nuevaAct.tipo,
      descripcion: nuevaAct.descripcion.trim(),
      resultado: nuevaAct.resultado.trim() || null,
      fecha: new Date(nuevaAct.fecha).toISOString(),
    })
    if (err) { setError(err.message); return }
    setNuevaAct({ tipo: nuevaAct.tipo, descripcion: '', resultado: '', fecha: ahoraLocal() })
    await cargar()
    onGuardado(null)
  }

  async function borrarActividad(a) {
    if (!window.confirm('¿Borrar esta actividad?')) return
    const { error: err } = await supabase.from('crm_actividades').delete().eq('id', a.id)
    if (err) { setError(err.message); return }
    cargar()
  }

  async function crearTarea() {
    if (!nuevaTarea.titulo.trim()) { setError('Escribe la tarea.'); return }
    setError(null)
    const { error: err } = await supabase.from('crm_tareas').insert({ cuenta_id: cuentaId, titulo: nuevaTarea.titulo.trim(), vence_en: nuevaTarea.vence_en || hoyISO() })
    if (err) { setError(err.message); return }
    setNuevaTarea({ titulo: '', vence_en: hoyISO() })
    await cargar()
    onGuardado(null)
  }

  async function toggleTarea(t) {
    const { error: err } = await supabase.from('crm_tareas')
      .update({ completada: !t.completada, completada_en: t.completada ? null : new Date().toISOString() }).eq('id', t.id)
    if (err) { setError(err.message); return }
    await cargar()
    onGuardado(null)
  }

  async function borrarTarea(t) {
    const { error: err } = await supabase.from('crm_tareas').delete().eq('id', t.id)
    if (err) { setError(err.message); return }
    await cargar()
    onGuardado(null)
  }

  async function cargarRestaurantesLibres() {
    const { data, error: err } = await supabase.from('restaurants').select('id, nombre, slug').order('nombre')
    if (err) { setError(err.message); return }
    const usados = new Set(cuentas.map(c => c.restaurant_id).filter(Boolean))
    setRestaurantesLibres((data || []).filter(r => !usados.has(r.id)))
  }

  async function vincular(restaurantId) {
    const { error: err } = await supabase.from('crm_cuentas')
      .update({ restaurant_id: restaurantId, etapa: restaurantId ? 'ganado' : cuenta.etapa })
      .eq('id', cuentaId)
    if (err) { setError(err.message); return }
    setRestaurantesLibres(null)
    setVincularId('')
    await cargar()
    onGuardado(null)
  }

  const timeline = useMemo(() => {
    const nombreV = id => todosVendedores.find(v => v.id === id)?.nombre || 'Sin asignar'
    const items = [
      ...actividades.map(a => ({ tipo: 'actividad', fecha: a.fecha, a })),
      ...historial.map(h => ({
        tipo: 'sistema', fecha: h.created_at,
        texto: h.campo === 'etapa'
          ? (h.valor_anterior ? `Etapa: ${etapaLabel(h.valor_anterior)} → ${etapaLabel(h.valor_nuevo)}` : `Cuenta creada en ${etapaLabel(h.valor_nuevo)}`)
          : `Vendedor: ${h.valor_anterior ? nombreV(h.valor_anterior) : 'Sin asignar'} → ${h.valor_nuevo ? nombreV(h.valor_nuevo) : 'Sin asignar'}`,
      })),
    ]
    return items.sort((x, y) => y.fecha.localeCompare(x.fecha))
  }, [actividades, historial, todosVendedores])

  const hoy = hoyISO()
  const esCliente = !!cuenta?.restaurant_id
  const bloqueaEtapa = !esAdmin && esCliente
  const totalComisiones = comisiones.filter(c => c.estado !== 'anulada').reduce((s, c) => s + Number(c.importe), 0)
  const cuotasGeneradas = comisiones.filter(c => c.estado !== 'anulada').length

  const tabs = esNueva ? [{ key: 'datos', label: 'Datos' }] : [
    { key: 'datos', label: 'Datos' },
    { key: 'actividad', label: `Actividad (${actividades.length})` },
    { key: 'tareas', label: `Tareas (${tareas.filter(t => !t.completada).length})` },
    { key: 'comercial', label: esCliente ? 'Cliente y comisión' : 'Comisión' },
  ]

  return (
    <div style={S.modal} onClick={e => { if (e.target === e.currentTarget) onCerrar() }}>
      <div style={S.modalBox(720)}>
        {cargando || (!esNueva && !cuenta) ? <div style={{ ...S.loading, height: 200 }}>{error || 'Cargando…'}</div> : (
          <>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
              <div>
                <div style={S.modalTitle}>{esNueva ? 'Nueva cuenta' : cuenta.nombre}</div>
                {!esNueva && (
                  <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap', marginTop: 4 }}>
                    <span style={estiloEtapa(cuenta.etapa)}>{etapaLabel(cuenta.etapa)}</span>
                    {esCliente && <span style={S.badge(C.okBg, C.ok)}>Cliente</span>}
                    {cuenta.etapa === 'ganado' && !esCliente && <span style={S.badge('#2a2414', C.oro)}>Pendiente de alta</span>}
                    <span style={{ fontSize: 11, color: C.muted }}>En CRM desde {fmtFecha(cuenta.created_at)}</span>
                  </div>
                )}
              </div>
              <button style={{ ...S.logoutBtn, padding: '4px 10px' }} onClick={onCerrar}>✕</button>
            </div>

            <div style={{ ...S.tabBar, marginTop: 16, marginBottom: 4 }}>
              {tabs.map(t => <button key={t.key} style={S.tabBtn(tab === t.key)} onClick={() => setTab(t.key)}>{t.label}</button>)}
            </div>

            {error && <div style={{ ...S.error, marginTop: 12 }}>{error}</div>}

            {tab === 'datos' && (
              <>
                <label style={S.label}>Nombre del restaurante *</label>
                <input style={S.input} value={form.nombre} onChange={e => set('nombre', e.target.value)} placeholder="Ej. La Taberna del Puerto" />

                <div style={S.fila}>
                  <div style={S.col}>
                    <label style={S.label}>Etapa</label>
                    <select style={S.input} value={form.etapa} disabled={bloqueaEtapa} onChange={e => set('etapa', e.target.value)}>
                      {ETAPAS.map(e => <option key={e.key} value={e.key}>{e.label}</option>)}
                    </select>
                    {bloqueaEtapa && <div style={S.hint}>Ya es cliente: la etapa solo la cambia administración.</div>}
                  </div>
                  {form.etapa === 'perdido' && (
                    <div style={S.col}>
                      <label style={S.label}>Motivo de pérdida *</label>
                      <select style={S.input} value={form.motivo_perdida} onChange={e => set('motivo_perdida', e.target.value)}>
                        <option value="">Elegir…</option>
                        {MOTIVOS_PERDIDA.map(m => <option key={m} value={m}>{m}</option>)}
                      </select>
                    </div>
                  )}
                  {esAdmin && (
                    <div style={S.col}>
                      <label style={S.label}>Vendedor</label>
                      <select style={S.input} value={form.vendedor_id} onChange={e => set('vendedor_id', e.target.value)}>
                        <option value="">Sin asignar</option>
                        {todosVendedores.filter(v => v.activo || v.id === form.vendedor_id).map(v => (
                          <option key={v.id} value={v.id}>{v.nombre}{v.activo ? '' : ' (inactivo)'}</option>
                        ))}
                      </select>
                    </div>
                  )}
                </div>

                <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginTop: 20 }}>Contacto</div>
                <div style={S.fila}>
                  <div style={S.col}>
                    <label style={S.label}>Persona de contacto</label>
                    <input style={S.input} value={form.contacto_nombre} onChange={e => set('contacto_nombre', e.target.value)} />
                  </div>
                  <div style={S.col}>
                    <label style={S.label}>Cargo</label>
                    <input style={S.input} value={form.contacto_cargo} onChange={e => set('contacto_cargo', e.target.value)} placeholder="Dueño, gerente…" />
                  </div>
                </div>
                <div style={S.fila}>
                  <div style={S.col}>
                    <label style={S.label}>Teléfono / WhatsApp</label>
                    <input style={S.input} value={form.telefono} onChange={e => set('telefono', e.target.value)} placeholder="+34600000000" />
                    {form.telefono && (
                      <div style={{ ...S.hint, display: 'flex', gap: 10 }}>
                        <a href={`tel:${form.telefono.replace(/\s+/g, '')}`} style={{ color: C.oro }}>Llamar</a>
                        <a href={`https://wa.me/${form.telefono.replace(/[^\d]/g, '')}`} target="_blank" rel="noreferrer" style={{ color: C.oro }}>WhatsApp</a>
                      </div>
                    )}
                  </div>
                  <div style={S.col}>
                    <label style={S.label}>Email</label>
                    <input style={S.input} type="email" value={form.email} onChange={e => set('email', e.target.value)} />
                    {form.email && <div style={S.hint}><a href={`mailto:${form.email}`} style={{ color: C.oro }}>Escribir</a></div>}
                  </div>
                </div>

                <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginTop: 20 }}>El local</div>
                <div style={S.fila}>
                  <div style={S.col}>
                    <label style={S.label}>Tipo</label>
                    <select style={S.input} value={form.tipo_local} onChange={e => set('tipo_local', e.target.value)}>
                      <option value="">—</option>
                      {TIPOS_LOCAL.map(t => <option key={t} value={t}>{t}</option>)}
                    </select>
                  </div>
                  <div style={S.col}>
                    <label style={S.label}>Nº de mesas</label>
                    <input style={S.input} type="number" min="0" value={form.num_mesas} onChange={e => set('num_mesas', e.target.value)} />
                  </div>
                  <div style={S.col}>
                    <label style={S.label}>Ciudad</label>
                    <input style={S.input} value={form.ciudad} onChange={e => set('ciudad', e.target.value)} />
                  </div>
                </div>
                <label style={S.label}>Dirección</label>
                <input style={S.input} value={form.direccion} onChange={e => set('direccion', e.target.value)} placeholder="Calle, número, ciudad" />

                <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginTop: 20 }}>Oportunidad</div>
                <div style={S.fila}>
                  <div style={S.col}>
                    <label style={S.label}>Origen</label>
                    <select style={S.input} value={form.fuente} onChange={e => set('fuente', e.target.value)}>
                      <option value="">—</option>
                      {FUENTES.map(f => <option key={f} value={f}>{f}</option>)}
                    </select>
                  </div>
                  <div style={S.col}>
                    <label style={S.label}>Plan de interés</label>
                    <select style={S.input} value={form.plan_interes} onChange={e => planElegido(e.target.value)}>
                      <option value="">—</option>
                      {planes.map(p => <option key={p.key} value={p.key}>{p.nombre}{p.precio != null ? ` (${p.precio}€)` : ''}</option>)}
                    </select>
                  </div>
                  <div style={S.col}>
                    <label style={S.label}>Cuota estimada €/mes</label>
                    <input style={S.input} type="number" min="0" step="0.01" value={form.cuota_estimada} onChange={e => set('cuota_estimada', e.target.value)} />
                  </div>
                </div>
                <div style={S.fila}>
                  <div style={{ ...S.col, flex: 2 }}>
                    <label style={S.label}>Próxima acción</label>
                    <input style={S.input} value={form.proxima_accion} onChange={e => set('proxima_accion', e.target.value)} placeholder="Ej. Llamar para agendar demo" />
                  </div>
                  <div style={S.col}>
                    <label style={S.label}>Fecha</label>
                    <input style={{ ...S.input, borderColor: form.proxima_accion_fecha && form.proxima_accion_fecha < hoy ? '#5a2a2a' : C.borde }} type="date" value={form.proxima_accion_fecha} onChange={e => set('proxima_accion_fecha', e.target.value)} />
                  </div>
                </div>
                <label style={S.label}>Notas</label>
                <textarea style={{ ...S.input, minHeight: 80, resize: 'vertical' }} value={form.notas} onChange={e => set('notas', e.target.value)} />

                <div style={S.modalBtns}>
                  {!esNueva && esAdmin && <button style={S.dangerBtn} onClick={borrar}>Borrar</button>}
                  <div style={{ flex: 1 }} />
                  <button style={S.ghostBtn} onClick={onCerrar}>Cerrar</button>
                  <button style={S.primaryBtn(guardando)} disabled={guardando} onClick={guardar}>{guardando ? 'Guardando…' : esNueva ? 'Crear cuenta' : 'Guardar cambios'}</button>
                </div>
              </>
            )}

            {tab === 'actividad' && (
              <>
                <div style={{ ...S.card, marginTop: 14 }}>
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 10 }}>
                    {TIPOS_ACTIVIDAD.map(t => (
                      <button key={t.key} onClick={() => setNuevaAct(p => ({ ...p, tipo: t.key }))}
                        style={{ ...S.linkBtn, color: nuevaAct.tipo === t.key ? '#111' : C.texto2, background: nuevaAct.tipo === t.key ? C.oro : 'transparent' }}>
                        {t.icono} {t.label}
                      </button>
                    ))}
                  </div>
                  <textarea style={{ ...S.input, minHeight: 60, resize: 'vertical' }} placeholder="¿Qué pasó? Ej. Hablé con el dueño, le interesa el QR en mesa…" value={nuevaAct.descripcion} onChange={e => setNuevaAct(p => ({ ...p, descripcion: e.target.value }))} />
                  <div style={{ ...S.fila, marginTop: 8, alignItems: 'center' }}>
                    <input style={{ ...S.input, flex: 2 }} placeholder="Resultado (opcional)" value={nuevaAct.resultado} onChange={e => setNuevaAct(p => ({ ...p, resultado: e.target.value }))} />
                    <input style={{ ...S.input, flex: 1 }} type="datetime-local" value={nuevaAct.fecha} onChange={e => setNuevaAct(p => ({ ...p, fecha: e.target.value }))} />
                    <button style={S.primaryBtn(false)} onClick={registrarActividad}>Registrar</button>
                  </div>
                </div>

                <div style={{ marginTop: 16 }}>
                  {timeline.length === 0 && <div style={S.vacio}>Sin actividad todavía.</div>}
                  {timeline.map((it, i) => it.tipo === 'sistema' ? (
                    <div key={`h${i}`} style={{ fontSize: 11, color: C.muted, padding: '8px 0 8px 28px', borderLeft: `1px solid ${C.borde}`, marginLeft: 8 }}>
                      {it.texto} · {fmtFechaHora(it.fecha)}
                    </div>
                  ) : (
                    <div key={it.a.id} style={{ display: 'flex', gap: 10, padding: '10px 0', borderBottom: `0.5px solid ${C.bordeSuave}` }}>
                      <div style={{ fontSize: 16, width: 20, textAlign: 'center' }}>{tipoActividad(it.a.tipo).icono}</div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: 11, color: C.muted }}>
                          {tipoActividad(it.a.tipo).label} · {fmtFechaHora(it.a.fecha)}{it.a.autor_nombre ? ` · ${it.a.autor_nombre}` : ''}
                        </div>
                        <div style={{ fontSize: 13, color: C.texto, marginTop: 3, whiteSpace: 'pre-wrap' }}>{it.a.descripcion}</div>
                        {it.a.resultado && <div style={{ fontSize: 12, color: C.oro, marginTop: 3 }}>→ {it.a.resultado}</div>}
                      </div>
                      <button style={{ ...S.logoutBtn, padding: '2px 8px', fontSize: 11, alignSelf: 'flex-start' }} onClick={() => borrarActividad(it.a)} title="Borrar">✕</button>
                    </div>
                  ))}
                </div>
              </>
            )}

            {tab === 'tareas' && (
              <>
                <div style={{ ...S.fila, marginTop: 14, alignItems: 'center' }}>
                  <input style={{ ...S.input, flex: 3 }} placeholder="Ej. Enviar propuesta con el plan Profesional" value={nuevaTarea.titulo}
                    onChange={e => setNuevaTarea(p => ({ ...p, titulo: e.target.value }))}
                    onKeyDown={e => { if (e.key === 'Enter') crearTarea() }} />
                  <input style={{ ...S.input, flex: 1 }} type="date" value={nuevaTarea.vence_en} onChange={e => setNuevaTarea(p => ({ ...p, vence_en: e.target.value }))} />
                  <button style={S.primaryBtn(false)} onClick={crearTarea}>Añadir</button>
                </div>
                <div style={{ marginTop: 12 }}>
                  {tareas.length === 0 && <div style={S.vacio}>Sin tareas.</div>}
                  {tareas.map(t => (
                    <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '9px 0', borderBottom: `0.5px solid ${C.bordeSuave}` }}>
                      <input type="checkbox" checked={t.completada} onChange={() => toggleTarea(t)} style={{ width: 16, height: 16, cursor: 'pointer' }} />
                      <div style={{ flex: 1, fontSize: 13, color: t.completada ? C.muted : C.texto, textDecoration: t.completada ? 'line-through' : 'none' }}>{t.titulo}</div>
                      <div style={{ fontSize: 12, color: !t.completada && t.vence_en < hoy ? C.mal : C.texto2 }}>{fmtFecha(t.vence_en)}</div>
                      <button style={{ ...S.logoutBtn, padding: '2px 8px', fontSize: 11 }} onClick={() => borrarTarea(t)} title="Borrar">✕</button>
                    </div>
                  ))}
                </div>
              </>
            )}

            {tab === 'comercial' && (
              <div style={{ marginTop: 14 }}>
                {esCliente && clienteInfo && (
                  <div style={{ ...S.card, marginBottom: 14 }}>
                    <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginBottom: 8 }}>Restaurante</div>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 10, fontSize: 13 }}>
                      <div><div style={{ fontSize: 11, color: C.muted }}>Nombre</div>{clienteInfo.nombre}</div>
                      <div><div style={{ fontSize: 11, color: C.muted }}>Plan</div>{planes.find(p => p.key === clienteInfo.plan)?.nombre || '—'}</div>
                      <div><div style={{ fontSize: 11, color: C.muted }}>Cuota actual</div>{fmtEuro(clienteInfo.cuota_actual)}</div>
                      <div><div style={{ fontSize: 11, color: C.muted }}>Estado</div><span style={{ color: clienteInfo.activo ? C.ok : C.mal }}>{clienteInfo.activo ? 'Activo' : 'Suspendido'}</span></div>
                      {clienteInfo.trial_termina_en && <div><div style={{ fontSize: 11, color: C.muted }}>Trial hasta</div>{fmtFecha(clienteInfo.trial_termina_en)}</div>}
                      {clienteInfo.precio_override_hasta && <div><div style={{ fontSize: 11, color: C.muted }}>Descuento</div>{fmtEuro(clienteInfo.precio_override)} hasta {fmtFecha(clienteInfo.precio_override_hasta)}</div>}
                    </div>
                    {esAdmin && (
                      <div style={{ display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
                        <a href="/superadmin/restaurantes" style={S.linkBtn}>Gestionar en Restaurantes</a>
                        <button style={S.dangerBtn} onClick={() => { if (window.confirm('¿Desvincular el restaurante de esta cuenta? El restaurante no se borra.')) vincular(null) }}>Desvincular</button>
                      </div>
                    )}
                  </div>
                )}

                {esAdmin && !esCliente && (
                  <div style={{ ...S.card, marginBottom: 14, borderColor: cuenta.etapa === 'ganado' ? '#5a4a2a' : C.borde }}>
                    <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginBottom: 6 }}>Convertir en cliente</div>
                    <div style={{ fontSize: 12, color: C.texto2, marginBottom: 10, lineHeight: 1.5 }}>
                      Crea el restaurante con los datos de esta ficha ya rellenados, o vincúlalo a uno que ya exista. La comisión empieza a contar el mes siguiente (puedes cambiarlo abajo).
                    </div>
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
                      <button style={S.primaryBtn(false)} onClick={() => navigate(`/superadmin/restaurantes?cuenta=${cuentaId}`)}>Convertir en restaurante</button>
                      {restaurantesLibres === null ? (
                        <button style={S.linkBtn} onClick={cargarRestaurantesLibres}>Vincular a uno existente</button>
                      ) : (
                        <>
                          <select style={S.inputSm} value={vincularId} onChange={e => setVincularId(e.target.value)}>
                            <option value="">{restaurantesLibres.length ? 'Elegir restaurante…' : 'No hay restaurantes sin cuenta'}</option>
                            {restaurantesLibres.map(r => <option key={r.id} value={r.id}>{r.nombre}</option>)}
                          </select>
                          <button style={S.linkBtn} disabled={!vincularId} onClick={() => vincular(vincularId)}>Vincular</button>
                        </>
                      )}
                    </div>
                  </div>
                )}

                <div style={S.card}>
                  <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginBottom: 4 }}>Condiciones de comisión</div>
                  <div style={{ fontSize: 12, color: C.texto2, lineHeight: 1.5 }}>
                    Porcentaje de la cuota mensual que paga el restaurante, durante el número de cuotas pactado. Solo cuentan los meses en que el restaurante está activo, fuera de trial y con cuota mayor que 0.
                  </div>
                  {esAdmin ? (
                    <>
                      <div style={S.fila}>
                        <div style={S.col}>
                          <label style={S.label}>Comisión %</label>
                          <input style={S.input} type="number" min="0" max="100" step="0.5" value={form.comision_pct} onChange={e => set('comision_pct', e.target.value)} placeholder="Del vendedor" />
                        </div>
                        <div style={S.col}>
                          <label style={S.label}>Nº de cuotas</label>
                          <input style={S.input} type="number" min="1" value={form.comision_cuotas} onChange={e => set('comision_cuotas', e.target.value)} placeholder="Sin límite" />
                        </div>
                        <div style={S.col}>
                          <label style={S.label}>Primer mes</label>
                          <input style={S.input} type="month" value={form.comision_inicio} onChange={e => set('comision_inicio', e.target.value)} />
                        </div>
                      </div>
                      <div style={S.hint}>Nº de cuotas vacío = mientras siga siendo cliente. Si cambias de vendedor sin tocar estos campos, se aplican las condiciones del nuevo vendedor.</div>
                      <div style={S.modalBtns}>
                        <div style={{ flex: 1 }} />
                        <button style={S.primaryBtn(guardando)} disabled={guardando} onClick={guardar}>{guardando ? 'Guardando…' : 'Guardar condiciones'}</button>
                      </div>
                    </>
                  ) : (
                    <div style={{ display: 'flex', gap: 24, marginTop: 10, fontSize: 13, flexWrap: 'wrap' }}>
                      <div><div style={{ fontSize: 11, color: C.muted }}>Comisión</div>{cuenta.comision_pct != null ? `${cuenta.comision_pct} %` : 'Por definir'}</div>
                      <div><div style={{ fontSize: 11, color: C.muted }}>Cuotas</div>{cuenta.comision_cuotas ?? (cuenta.comision_pct != null ? 'Sin límite' : '—')}</div>
                      <div><div style={{ fontSize: 11, color: C.muted }}>Desde</div>{cuenta.comision_inicio ? fmtMes(cuenta.comision_inicio) : '—'}</div>
                    </div>
                  )}
                </div>

                {comisiones.length > 0 && (
                  <div style={{ marginTop: 14 }}>
                    <div style={{ fontSize: 12, color: C.texto2, marginBottom: 6 }}>
                      {cuotasGeneradas}{cuenta.comision_cuotas ? ` de ${cuenta.comision_cuotas}` : ''} cuotas generadas · total {fmtEuro(totalComisiones)}
                    </div>
                    <table style={S.table}>
                      <thead><tr><th style={S.th}>Mes</th><th style={S.th}>Cuota</th><th style={S.th}>Comisión</th><th style={S.th}>Estado</th></tr></thead>
                      <tbody>
                        {comisiones.map(c => (
                          <tr key={c.id}>
                            <td style={S.td}>{fmtMes(c.periodo)} <span style={{ color: C.muted, fontSize: 11 }}>#{c.numero_cuota}</span></td>
                            <td style={S.td}>{fmtEuro(c.cuota_base)}</td>
                            <td style={S.td}>{fmtEuro(c.importe)} <span style={{ color: C.muted, fontSize: 11 }}>({c.porcentaje}%)</span></td>
                            <td style={{ ...S.td, color: c.estado === 'pagada' ? C.ok : c.estado === 'anulada' ? C.muted : C.oro }}>{c.estado}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
