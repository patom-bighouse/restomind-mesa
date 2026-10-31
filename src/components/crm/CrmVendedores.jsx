import { useState } from 'react'
import { createClient } from '@supabase/supabase-js'
import { supabase } from '../../lib/supabase'
import { S, C } from './estilos'
import { ETAPAS_ABIERTAS, fmtEuro } from '../../lib/crm'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

const VACIO = { nombre: '', email: '', password: '', telefono: '', comision_pct: '10', comision_cuotas: '12', sinLimite: false, activo: true }

export default function CrmVendedores({ vendedores, cuentas, clientesInfo, onCambio, onError, onAviso }) {
  const [modal, setModal] = useState(null) // null | 'crear' | vendedor
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorModal, setErrorModal] = useState(null)
  const [importando, setImportando] = useState(false)
  const [reasignar, setReasignar] = useState({ desde: '', hacia: '', soloAbiertas: true })

  const set = (k, v) => setForm(prev => ({ ...prev, [k]: v }))

  function abrirCrear() {
    setForm(VACIO)
    setErrorModal(null)
    setModal('crear')
  }

  function abrirEditar(v) {
    setForm({
      nombre: v.nombre, email: v.email, password: '', telefono: v.telefono || '',
      comision_pct: String(v.comision_pct), comision_cuotas: v.comision_cuotas ? String(v.comision_cuotas) : '',
      sinLimite: !v.comision_cuotas, activo: v.activo,
    })
    setErrorModal(null)
    setModal(v)
  }

  function validar() {
    if (!form.nombre.trim() || !form.email.trim()) return 'Nombre y email son obligatorios.'
    // Misma política que exige Supabase Auth en el proyecto. Al editar, la
    // contraseña es opcional: vacía = no se cambia.
    if ((modal === 'crear' || form.password) && (form.password.length < 8 || !/[a-z]/.test(form.password) || !/[A-Z]/.test(form.password) || !/\d/.test(form.password))) {
      return 'La contraseña debe tener al menos 8 caracteres, con una minúscula, una mayúscula y un número.'
    }
    const pct = Number(form.comision_pct)
    if (form.comision_pct === '' || isNaN(pct) || pct < 0 || pct > 100) return 'La comisión debe estar entre 0 y 100 %.'
    if (!form.sinLimite && !(parseInt(form.comision_cuotas, 10) > 0)) return 'Indica cuántas cuotas cobra, o marca "Sin límite".'
    return null
  }

  async function guardar() {
    const err = validar()
    if (err) { setErrorModal(err); return }
    setGuardando(true)
    setErrorModal(null)
    const datos = {
      nombre: form.nombre.trim(),
      email: form.email.trim(),
      telefono: form.telefono.trim() || null,
      comision_pct: Number(form.comision_pct),
      comision_cuotas: form.sinLimite ? null : parseInt(form.comision_cuotas, 10),
      activo: form.activo,
    }
    try {
      if (modal === 'crear') {
        // Cliente aparte sin persistir sesión: si no, el signUp pisaría la
        // sesión del superadmin (mismo motivo que en SuperAdminRestaurantes).
        const tempClient = createClient(supabaseUrl, supabaseAnonKey, { auth: { persistSession: false, autoRefreshToken: false } })
        const { data, error } = await tempClient.auth.signUp({ email: datos.email, password: form.password })
        if (error) throw error
        if (!data.user) throw new Error('No se pudo crear el usuario.')
        const { error: insErr } = await supabase.from('vendedores').insert({ ...datos, user_id: data.user.id })
        if (insErr) throw insErr
        onAviso(`Vendedor "${datos.nombre}" creado.\n\nAcceso: ${datos.email} / (la contraseña que definiste)\nPanel: /vendedor/login`)
      } else {
        const { error } = await supabase.from('vendedores').update(datos).eq('id', modal.id)
        if (error) throw error
        if (form.password) {
          const { error: pwErr } = await supabase.rpc('fn_crm_vendedor_cambiar_password', { p_vendedor: modal.id, p_password: form.password })
          if (pwErr) throw pwErr
          onAviso(`Contraseña de "${datos.nombre}" actualizada.\n\nAcceso: ${modal.email} / (la nueva contraseña)\nPanel: /vendedor/login`)
        }
      }
      setModal(null)
      onCambio()
    } catch (e) {
      setErrorModal(e.message)
    } finally {
      setGuardando(false)
    }
  }

  async function importar() {
    setImportando(true)
    const { data, error } = await supabase.rpc('fn_crm_importar_restaurantes')
    setImportando(false)
    if (error) { onError(error.message); return }
    onAviso(data ? `Importados ${data} restaurantes como clientes sin asignar. Asígnalos desde el filtro "Sin asignar".` : 'Todos los restaurantes ya están en el CRM.')
    onCambio()
  }

  async function ejecutarReasignacion() {
    const { desde, hacia, soloAbiertas } = reasignar
    if (!desde || !hacia || desde === hacia) { onError('Elige un vendedor de origen y otro de destino.'); return }
    let q = supabase.from('crm_cuentas').update({ vendedor_id: hacia }).eq('vendedor_id', desde)
    if (soloAbiertas) q = q.in('etapa', ETAPAS_ABIERTAS)
    const n = cuentas.filter(c => c.vendedor_id === desde && (!soloAbiertas || ETAPAS_ABIERTAS.includes(c.etapa))).length
    if (!window.confirm(`¿Pasar ${n} cuentas de ${vendedores.find(v => v.id === desde)?.nombre} a ${vendedores.find(v => v.id === hacia)?.nombre}?`)) return
    const { error } = await q
    if (error) { onError(error.message); return }
    onAviso(`${n} cuentas reasignadas.`)
    setReasignar({ desde: '', hacia: '', soloAbiertas: true })
    onCambio()
  }

  const resumen = id => {
    const cs = cuentas.filter(c => c.vendedor_id === id)
    return {
      abiertas: cs.filter(c => ETAPAS_ABIERTAS.includes(c.etapa)).length,
      clientes: cs.filter(c => c.restaurant_id).length,
      mrr: cs.reduce((s, c) => s + (clientesInfo[c.id]?.activo ? Number(clientesInfo[c.id].cuota_actual) || 0 : 0), 0),
    }
  }
  const sinAsignar = cuentas.filter(c => !c.vendedor_id).length

  return (
    <>
      <div style={S.toolbar}>
        <button style={S.primaryBtn(false)} onClick={abrirCrear}>+ Nuevo vendedor</button>
        <button style={S.linkBtn} disabled={importando} onClick={importar}>{importando ? 'Importando…' : 'Importar restaurantes existentes'}</button>
        {sinAsignar > 0 && <span style={{ fontSize: 12, color: C.aviso }}>{sinAsignar} cuentas sin asignar</span>}
      </div>

      <div style={{ overflowX: 'auto', marginBottom: 28 }}>
        <table style={S.table}>
          <thead>
            <tr>
              <th style={S.th}>Vendedor</th>
              <th style={S.th}>Comisión por defecto</th>
              <th style={S.th}>Abiertas</th>
              <th style={S.th}>Clientes</th>
              <th style={S.th}>Cartera €/mes</th>
              <th style={S.th}>Estado</th>
              <th style={S.th}></th>
            </tr>
          </thead>
          <tbody>
            {vendedores.map(v => {
              const r = resumen(v.id)
              return (
                <tr key={v.id}>
                  <td style={S.td}>
                    <div style={{ fontWeight: 500 }}>{v.nombre}</div>
                    <div style={{ fontSize: 11, color: C.muted, marginTop: 2 }}>{[v.email, v.telefono].filter(Boolean).join(' · ')}</div>
                  </td>
                  <td style={S.td}>{v.comision_pct} % · {v.comision_cuotas ? `${v.comision_cuotas} cuotas` : 'sin límite'}</td>
                  <td style={S.td}>{r.abiertas}</td>
                  <td style={S.td}>{r.clientes}</td>
                  <td style={S.td}>{fmtEuro(r.mrr)}</td>
                  <td style={S.td}><span style={v.activo ? S.badge(C.okBg, C.ok) : S.badge(C.malBg, C.mal)}>{v.activo ? 'Activo' : 'Inactivo'}</span></td>
                  <td style={S.td}><button style={S.linkBtn} onClick={() => abrirEditar(v)}>Editar</button></td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {vendedores.length === 0 && <div style={S.vacio}>Todavía no hay vendedores. Crea el primero arriba.</div>}
      </div>

      {vendedores.length > 1 && (
        <div style={S.card}>
          <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginBottom: 6 }}>Reasignar cartera</div>
          <div style={{ fontSize: 12, color: C.texto2, marginBottom: 10, lineHeight: 1.5 }}>
            Útil cuando un vendedor se va o cambia de zona. Las cuentas mantienen sus condiciones de comisión; las comisiones futuras se generan para el nuevo vendedor.
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            <select style={S.inputSm} value={reasignar.desde} onChange={e => setReasignar(p => ({ ...p, desde: e.target.value }))}>
              <option value="">De…</option>
              {vendedores.map(v => <option key={v.id} value={v.id}>{v.nombre}</option>)}
            </select>
            <span style={{ color: C.muted }}>→</span>
            <select style={S.inputSm} value={reasignar.hacia} onChange={e => setReasignar(p => ({ ...p, hacia: e.target.value }))}>
              <option value="">A…</option>
              {vendedores.filter(v => v.activo).map(v => <option key={v.id} value={v.id}>{v.nombre}</option>)}
            </select>
            <label style={{ fontSize: 12, color: C.texto2, display: 'flex', gap: 6, alignItems: 'center' }}>
              <input type="checkbox" checked={reasignar.soloAbiertas} onChange={e => setReasignar(p => ({ ...p, soloAbiertas: e.target.checked }))} />
              Solo oportunidades abiertas
            </label>
            <button style={S.linkBtn} onClick={ejecutarReasignacion}>Reasignar</button>
          </div>
        </div>
      )}

      {modal && (
        <div style={S.modal} onClick={e => { if (e.target === e.currentTarget) setModal(null) }}>
          <div style={S.modalBox(440)}>
            <div style={S.modalTitle}>{modal === 'crear' ? 'Nuevo vendedor' : 'Editar vendedor'}</div>
            {errorModal && <div style={{ ...S.error, marginTop: 12 }}>{errorModal}</div>}

            <label style={S.label}>Nombre *</label>
            <input style={S.input} value={form.nombre} onChange={e => set('nombre', e.target.value)} />

            <label style={S.label}>Email {modal === 'crear' ? '(acceso al CRM) *' : ''}</label>
            <input style={S.input} type="email" value={form.email} onChange={e => set('email', e.target.value)} />
            {modal !== 'crear' && <div style={S.hint}>Solo referencia: no cambia el login. Para eso, Authentication → Users en Supabase.</div>}

            <label style={S.label}>{modal === 'crear' ? 'Contraseña inicial *' : 'Nueva contraseña'}</label>
            <input style={S.input} type="text" value={form.password} onChange={e => set('password', e.target.value)} placeholder={modal === 'crear' ? 'mín. 8, con minúscula, mayúscula y número' : 'Déjala vacía para no cambiarla'} autoComplete="new-password" />
            <div style={S.hint}>
              {modal === 'crear'
                ? 'Compártesela al vendedor; entrará en /vendedor/login'
                : 'Mín. 8, con minúscula, mayúscula y número. El vendedor también puede restablecerla él mismo desde "¿Olvidaste tu contraseña?" en /vendedor/login.'}
            </div>

            <label style={S.label}>Teléfono</label>
            <input style={S.input} value={form.telefono} onChange={e => set('telefono', e.target.value)} />

            <div style={{ fontSize: 13, color: C.oro, fontWeight: 500, marginTop: 20 }}>Comisión por defecto</div>
            <div style={S.hint}>Se aplica a cada cuenta que se le asigne; luego se puede ajustar cuenta por cuenta. Cambiarla aquí no modifica las cuentas que ya tiene.</div>
            <div style={S.fila}>
              <div style={S.col}>
                <label style={S.label}>% de la cuota mensual</label>
                <input style={S.input} type="number" min="0" max="100" step="0.5" value={form.comision_pct} onChange={e => set('comision_pct', e.target.value)} />
              </div>
              <div style={S.col}>
                <label style={S.label}>Nº de cuotas</label>
                <input style={S.input} type="number" min="1" disabled={form.sinLimite} value={form.sinLimite ? '' : form.comision_cuotas} onChange={e => set('comision_cuotas', e.target.value)} />
              </div>
            </div>
            <label style={{ fontSize: 12, color: C.texto2, display: 'flex', gap: 6, alignItems: 'center', marginTop: 10, cursor: 'pointer' }}>
              <input type="checkbox" checked={form.sinLimite} onChange={e => set('sinLimite', e.target.checked)} /> Sin límite (mientras siga siendo cliente)
            </label>

            {modal !== 'crear' && (
              <label style={{ fontSize: 12, color: C.texto2, display: 'flex', gap: 6, alignItems: 'center', marginTop: 16, cursor: 'pointer' }}>
                <input type="checkbox" checked={form.activo} onChange={e => set('activo', e.target.checked)} /> Activo (si lo desactivas, pierde el acceso al CRM al instante; sus cuentas siguen asignadas)
              </label>
            )}

            <div style={S.modalBtns}>
              <button style={{ ...S.ghostBtn, flex: 1 }} onClick={() => setModal(null)}>Cancelar</button>
              <button style={{ ...S.primaryBtn(guardando), flex: 1 }} disabled={guardando} onClick={guardar}>{guardando ? 'Guardando…' : modal === 'crear' ? 'Crear vendedor' : 'Guardar'}</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
