import { useState, useMemo } from 'react'
import { supabase } from '../../lib/supabase'
import { S, C } from './estilos'
import { hoyISO, fmtFecha, fmtFechaHora } from '../../lib/crm'

const GRUPOS = [
  { key: 'vencidas', label: 'Vencidas', color: C.mal },
  { key: 'hoy', label: 'Hoy', color: C.oro },
  { key: 'proximas', label: 'Próximas', color: C.texto2 },
]

export default function CrmTareas({ tareas, cuentas, esAdmin, nombreVendedor, onAbrir, onCambio, onError }) {
  const [verCompletadas, setVerCompletadas] = useState(false)
  const [guardando, setGuardando] = useState(null)
  const hoy = hoyISO()
  const cuentaPorId = useMemo(() => Object.fromEntries(cuentas.map(c => [c.id, c])), [cuentas])

  const grupos = useMemo(() => {
    const pendientes = tareas.filter(t => !t.completada)
    return {
      vencidas: pendientes.filter(t => t.vence_en < hoy),
      hoy: pendientes.filter(t => t.vence_en === hoy),
      proximas: pendientes.filter(t => t.vence_en > hoy),
    }
  }, [tareas, hoy])

  const completadas = useMemo(
    () => tareas.filter(t => t.completada).sort((a, b) => (b.completada_en || '').localeCompare(a.completada_en || '')).slice(0, 50),
    [tareas]
  )

  async function toggle(t) {
    setGuardando(t.id)
    const { error } = await supabase.from('crm_tareas')
      .update({ completada: !t.completada, completada_en: t.completada ? null : new Date().toISOString() })
      .eq('id', t.id)
    setGuardando(null)
    if (error) { onError(error.message); return }
    onCambio()
  }

  function fila(t) {
    const cuenta = cuentaPorId[t.cuenta_id]
    return (
      <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 4px', borderBottom: `0.5px solid ${C.bordeSuave}` }}>
        <input type="checkbox" checked={t.completada} disabled={guardando === t.id} onChange={() => toggle(t)} style={{ width: 16, height: 16, cursor: 'pointer' }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13, color: t.completada ? C.muted : C.texto, textDecoration: t.completada ? 'line-through' : 'none' }}>{t.titulo}</div>
          <div style={{ fontSize: 11, color: C.muted, marginTop: 2 }}>
            <span style={{ color: C.oro, cursor: 'pointer' }} onClick={() => onAbrir(t.cuenta_id)}>{cuenta?.nombre || 'Cuenta'}</span>
            {esAdmin && cuenta && ` · ${nombreVendedor(cuenta.vendedor_id) || 'Sin asignar'}`}
          </div>
        </div>
        <div style={{ fontSize: 12, color: !t.completada && t.vence_en < hoy ? C.mal : C.texto2, whiteSpace: 'nowrap' }}>
          {t.completada ? `Hecha ${fmtFechaHora(t.completada_en)}` : fmtFecha(t.vence_en)}
        </div>
      </div>
    )
  }

  return (
    <>
      <div style={{ ...S.hint, marginTop: 0, marginBottom: 16 }}>Las tareas se crean desde la ficha de cada cuenta (pestaña Tareas).</div>
      {GRUPOS.map(g => (
        <div key={g.key} style={{ marginBottom: 24 }}>
          <div style={{ fontSize: 13, fontWeight: 500, color: g.color, marginBottom: 6 }}>{g.label} · {grupos[g.key].length}</div>
          {grupos[g.key].length ? grupos[g.key].map(fila) : <div style={{ fontSize: 12, color: '#555', padding: '6px 4px' }}>Nada por aquí.</div>}
        </div>
      ))}
      <button style={S.linkBtn} onClick={() => setVerCompletadas(v => !v)}>
        {verCompletadas ? 'Ocultar completadas' : `Ver completadas (${completadas.length})`}
      </button>
      {verCompletadas && <div style={{ marginTop: 10 }}>{completadas.map(fila)}</div>}
    </>
  )
}
