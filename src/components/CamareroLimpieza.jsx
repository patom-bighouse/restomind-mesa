import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'

const S = {
  app: { minHeight: '100vh', background: '#111', color: '#f0e8d8', fontFamily: "'Inter', sans-serif", display: 'flex', flexDirection: 'column' },
  header: { background: '#0a0a0a', padding: '14px 20px', borderBottom: '0.5px solid #2a2a2a', display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a' },
  backBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 8, padding: '6px 14px', fontSize: 13, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  content: { padding: 16, flex: 1, overflowY: 'auto' },
  card: { background: '#1a1a1a', border: '0.5px solid #d4a017', borderRadius: 10, padding: 14, marginBottom: 10, cursor: 'pointer' },
  cardTitle: { fontSize: 15, color: '#e8c97a', marginBottom: 2 },
  cardMeta: { fontSize: 12, color: '#7a6a50' },
  empty: { textAlign: 'center', padding: 60, color: '#555', fontSize: 14 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 20 },
  box: { background: '#1a1a1a', border: '0.5px solid #3a2e20', borderRadius: 16, padding: 24, width: '100%', maxWidth: 380 },
  title: { fontFamily: "'Playfair Display', serif", fontSize: 17, color: '#e8c97a', marginBottom: 4 },
  sub: { fontSize: 13, color: '#8a7560', marginBottom: 18 },
  pasoRow: { display: 'flex', alignItems: 'center', gap: 10, padding: '10px 0', borderBottom: '0.5px solid #2a2a2a', cursor: 'pointer' },
  check: (marcado) => ({ width: 22, height: 22, borderRadius: 6, border: `1.5px solid ${marcado ? '#2ecc71' : '#3a2e20'}`, background: marcado ? '#2ecc71' : 'transparent', color: '#111', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, flexShrink: 0 }),
  texto: (marcado) => ({ fontSize: 14, color: marcado ? '#7a6a50' : '#f0e8d8', textDecoration: marcado ? 'line-through' : 'none' }),
  closeBtn: { width: '100%', background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: 12, fontSize: 14, color: '#8a7560', cursor: 'pointer', fontFamily: "'Inter', sans-serif", marginTop: 16 },
}

// El checklist ya se podía marcar de forma anónima desde que se
// construyó (sql/checklist_limpieza.sql) — acá solo se filtra la vista
// según el permiso 'limpieza' que le diste a esta persona en AdminConfig,
// no hace falta ninguna función "caja fuerte" nueva para esto.
export default function CamareroLimpieza({ restaurantId, onVolver }) {
  const [tables, setTables] = useState([])
  const [pasos, setPasos] = useState([])
  const [loading, setLoading] = useState(true)
  const [modalTable, setModalTable] = useState(null)

  useEffect(() => {
    loadTodo()
    const interval = setInterval(loadTablasSucias, 15000)
    return () => clearInterval(interval)
  }, [])

  async function loadTodo() {
    await Promise.all([loadTablasSucias(), loadPasos()])
    setLoading(false)
  }

  async function loadTablasSucias() {
    const { data } = await supabase
      .from('tables')
      .select('id, numero, zona, necesita_limpieza, limpieza_progreso')
      .eq('restaurant_id', restaurantId)
      .eq('necesita_limpieza', true)
      .order('numero')
    setTables(data || [])
    setModalTable(prev => {
      if (!prev) return prev
      const actualizada = (data || []).find(t => t.id === prev.id)
      return actualizada || null
    })
  }

  async function loadPasos() {
    const { data } = await supabase
      .from('limpieza_pasos')
      .select('id, texto, orden')
      .eq('restaurant_id', restaurantId)
      .eq('activo', true)
      .order('orden')
    setPasos(data || [])
  }

  async function togglePaso(table, pasoId) {
    const actual = table.limpieza_progreso || []
    const nuevo = actual.includes(pasoId) ? actual.filter(id => id !== pasoId) : [...actual, pasoId]
    const completo = pasos.every(p => nuevo.includes(p.id))
    const patch = { limpieza_progreso: nuevo, necesita_limpieza: !completo }
    if (completo) {
      setTables(prev => prev.filter(t => t.id !== table.id))
      setModalTable(null)
    } else {
      setTables(prev => prev.map(t => t.id === table.id ? { ...t, ...patch } : t))
      setModalTable(prev => prev && prev.id === table.id ? { ...prev, ...patch } : prev)
    }
    await supabase.from('tables').update(patch).eq('id', table.id)
  }

  if (loading) return <div style={S.app}><div style={S.loading}>Cargando...</div></div>

  return (
    <div style={S.app}>
      <div style={S.header}>
        <div style={S.logo}>🧹 Limpieza</div>
        <button style={S.backBtn} onClick={onVolver}>← Volver</button>
      </div>

      <div style={S.content}>
        {tables.length === 0 ? (
          <div style={S.empty}>No hay ninguna mesa esperando limpieza ahora mismo.</div>
        ) : (
          tables.map(t => (
            <div key={t.id} style={S.card} onClick={() => setModalTable(t)}>
              <div style={S.cardTitle}>Mesa {t.numero}</div>
              <div style={S.cardMeta}>{t.zona} · {(t.limpieza_progreso || []).length}/{pasos.length} pasos hechos</div>
            </div>
          ))
        )}
      </div>

      {modalTable && (
        <div style={S.overlay} onClick={() => setModalTable(null)}>
          <div style={S.box} onClick={e => e.stopPropagation()}>
            <div style={S.title}>🧹 Mesa {modalTable.numero}</div>
            <div style={S.sub}>Marca cada paso a medida que lo completas — la mesa vuelve a estar libre sola.</div>
            {pasos.map(paso => {
              const marcado = (modalTable.limpieza_progreso || []).includes(paso.id)
              return (
                <div key={paso.id} style={S.pasoRow} onClick={() => togglePaso(modalTable, paso.id)}>
                  <div style={S.check(marcado)}>{marcado ? '✓' : ''}</div>
                  <div style={S.texto(marcado)}>{paso.texto}</div>
                </div>
              )
            })}
            <button style={S.closeBtn} onClick={() => setModalTable(null)}>Cerrar</button>
          </div>
        </div>
      )}
    </div>
  )
}
