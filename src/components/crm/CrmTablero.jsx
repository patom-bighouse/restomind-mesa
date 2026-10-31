import { useState, useMemo } from 'react'
import { S, C } from './estilos'
import { ETAPAS, DIAS_SIN_ACTIVIDAD, ETAPAS_ABIERTAS, hoyISO, fmtFecha, fmtEuro, diasDesde, enlaceMaps } from '../../lib/crm'

const MAX_PERDIDOS = 30

const T = {
  scroller: { display: 'flex', gap: 12, overflowX: 'auto', paddingBottom: 12, alignItems: 'flex-start' },
  col: (sobre) => ({ flex: '0 0 250px', background: sobre ? '#1a1810' : C.panel, border: `0.5px solid ${sobre ? C.oro : C.borde}`, borderRadius: 12, padding: 10, minHeight: 200, transition: 'border-color .15s' }),
  colHead: { display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', padding: '2px 4px 10px' },
  colTitulo: { fontSize: 13, fontWeight: 500, color: C.texto },
  colMeta: { fontSize: 11, color: C.muted },
  card: { background: C.card, border: `0.5px solid ${C.borde}`, borderRadius: 10, padding: '10px 12px', marginBottom: 8, cursor: 'grab' },
  cardNombre: { fontSize: 13, fontWeight: 500, color: C.texto, marginBottom: 2 },
  cardLinea: { fontSize: 11, color: C.texto2, marginTop: 3 },
  pie: { fontSize: 11, color: C.muted, textAlign: 'center', padding: '6px 0' },
}

export default function CrmTablero({ cuentas, tareas, proximaTarea, esAdmin, nombreVendedor, onAbrir, onMover }) {
  const [arrastrando, setArrastrando] = useState(null)
  const [sobre, setSobre] = useState(null)
  const hoy = hoyISO()

  const tareasPorCuenta = useMemo(() => {
    const m = {}
    for (const t of tareas) if (!t.completada) m[t.cuenta_id] = (m[t.cuenta_id] || 0) + 1
    return m
  }, [tareas])

  // En "Ganado" solo se ven las cuentas pendientes de alta: los clientes
  // ya convertidos viven en la pestaña Clientes.
  const columnas = useMemo(() => ETAPAS.map(e => {
    let items = cuentas.filter(c => c.etapa === e.key)
    let extra = null
    if (e.key === 'ganado') {
      const convertidos = items.filter(c => c.restaurant_id).length
      items = items.filter(c => !c.restaurant_id)
      if (convertidos) extra = `${convertidos} ya convertidos → pestaña Clientes`
    }
    if (e.key === 'perdido' && items.length > MAX_PERDIDOS) {
      extra = `${items.length - MAX_PERDIDOS} más en la pestaña Lista`
      items = [...items].sort((a, b) => (b.perdido_en || '').localeCompare(a.perdido_en || '')).slice(0, MAX_PERDIDOS)
    }
    const total = items.reduce((s, c) => s + (Number(c.cuota_estimada) || 0), 0)
    return { ...e, items, extra, total }
  }), [cuentas])

  function soltar(etapa) {
    const cuenta = cuentas.find(c => c.id === arrastrando)
    setArrastrando(null)
    setSobre(null)
    if (cuenta) onMover(cuenta, etapa)
  }

  return (
    <>
      <div style={{ ...S.hint, marginTop: 0, marginBottom: 10 }}>
        Arrastra una tarjeta para cambiarla de etapa. Click para abrir la ficha.
        El importe de cada columna es la suma de cuotas mensuales estimadas.
      </div>
      <div style={T.scroller}>
        {columnas.map(col => (
          <div
            key={col.key}
            style={T.col(sobre === col.key)}
            onDragOver={e => { e.preventDefault(); if (sobre !== col.key) setSobre(col.key) }}
            onDragLeave={e => { if (!e.currentTarget.contains(e.relatedTarget)) setSobre(null) }}
            onDrop={e => { e.preventDefault(); soltar(col.key) }}
          >
            <div style={T.colHead}>
              <span style={T.colTitulo}>{col.label} <span style={{ color: C.muted, fontWeight: 400 }}>· {col.items.length}</span></span>
              {col.total > 0 && <span style={T.colMeta}>{fmtEuro(col.total)}/mes</span>}
            </div>
            {col.items.map(c => {
              const proxima = proximaTarea[c.id]
              const vencida = proxima && proxima.vence_en < hoy
              const abierta = ETAPAS_ABIERTAS.includes(c.etapa)
              const dias = diasDesde(c.ultima_actividad_en || c.created_at)
              const fria = abierta && dias != null && dias >= DIAS_SIN_ACTIVIDAD
              return (
                <div
                  key={c.id}
                  style={{ ...T.card, opacity: arrastrando === c.id ? 0.4 : 1 }}
                  draggable
                  onDragStart={e => { setArrastrando(c.id); e.dataTransfer.effectAllowed = 'move' }}
                  onDragEnd={() => { setArrastrando(null); setSobre(null) }}
                  onClick={() => onAbrir(c.id)}
                >
                  <div style={{ ...T.cardNombre, display: 'flex', justifyContent: 'space-between', gap: 6 }}>
                    <span>{c.nombre}</span>
                    {enlaceMaps(c) && (
                      <a href={enlaceMaps(c)} target="_blank" rel="noreferrer" title="Ver en Google Maps" draggable={false}
                        onClick={e => e.stopPropagation()} style={{ textDecoration: 'none', flexShrink: 0 }}>📍</a>
                    )}
                  </div>
                  {(c.ciudad || c.tipo_local) && <div style={T.cardLinea}>{[c.tipo_local, c.ciudad].filter(Boolean).join(' · ')}</div>}
                  {c.cuota_estimada != null && <div style={T.cardLinea}>{fmtEuro(c.cuota_estimada)}/mes{c.plan_interes ? ` · ${c.plan_interes}` : ''}</div>}
                  {proxima ? (
                    <div style={{ ...T.cardLinea, color: vencida ? C.mal : proxima.vence_en === hoy ? C.oro : C.texto2 }}>
                      {vencida ? '⚠ ' : '→ '}{proxima.titulo} · {fmtFecha(proxima.vence_en)}
                    </div>
                  ) : abierta && (
                    <div style={{ ...T.cardLinea, color: C.aviso }}>Sin próxima tarea</div>
                  )}
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 6 }}>
                    {esAdmin && <span style={S.badge('#1f1f1f', nombreVendedor(c.vendedor_id) ? C.texto2 : C.aviso)}>{nombreVendedor(c.vendedor_id) || 'Sin asignar'}</span>}
                    {tareasPorCuenta[c.id] > 0 && <span style={S.badge('#1f1f1f', C.texto2)}>☑ {tareasPorCuenta[c.id]}</span>}
                    {fria && <span style={S.badge('#2a2014', C.aviso)} title={`Sin actividad desde hace ${dias} días`}>❄ {dias} d</span>}
                    {c.etapa === 'ganado' && !c.restaurant_id && <span style={S.badge('#2a2414', C.oro)}>Pendiente de alta</span>}
                  </div>
                </div>
              )
            })}
            {col.items.length === 0 && <div style={T.pie}>—</div>}
            {col.extra && <div style={T.pie}>{col.extra}</div>}
          </div>
        ))}
      </div>
    </>
  )
}
