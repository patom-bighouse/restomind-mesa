// Estilos compartidos por las pantallas del CRM — mismo lenguaje visual
// que SuperAdminRestaurantes (fondo negro, acento dorado, Inter/Playfair).

export const C = {
  bg: '#0a0a0a', panel: '#111', card: '#161616', borde: '#2a2a2a', bordeSuave: '#1f1f1f',
  texto: '#f0f0f0', texto2: '#8a8a8a', muted: '#666', oro: '#e8c97a',
  ok: '#2ecc71', okBg: '#142a1a', mal: '#e74c3c', malBg: '#2a1414', aviso: '#e8a33a',
}

export const S = {
  app: { minHeight: '100vh', background: C.bg, color: C.texto, fontFamily: "'Inter', sans-serif" },
  header: { background: C.panel, padding: '14px 24px', borderBottom: `0.5px solid ${C.borde}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10, gap: 12, flexWrap: 'wrap' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 20, fontWeight: 600, color: C.oro },
  sub: { fontSize: 11, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.1em', marginTop: 2 },
  logoutBtn: { background: 'transparent', border: `0.5px solid ${C.borde}`, borderRadius: 8, padding: '6px 14px', fontSize: 13, color: C.texto2, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  linkBtn: { background: 'transparent', border: `0.5px solid ${C.borde}`, borderRadius: 8, padding: '6px 12px', fontSize: 12, color: C.oro, cursor: 'pointer', fontFamily: "'Inter', sans-serif", textDecoration: 'none', display: 'inline-block' },
  content: { padding: 24, maxWidth: 1400, margin: '0 auto' },
  sectionTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: C.oro, marginBottom: 6 },
  hint: { fontSize: 11, color: '#555', marginTop: 4, lineHeight: 1.5 },
  error: { background: C.malBg, border: '0.5px solid #5a2a2a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#e87a7a', marginBottom: 16 },
  success: { background: C.okBg, border: '0.5px solid #2a5a3a', borderRadius: 10, padding: '10px 14px', fontSize: 13, color: '#7ae8a0', marginBottom: 16, lineHeight: 1.6 },
  loading: { display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh', color: '#555', fontSize: 14 },
  vacio: { fontSize: 13, color: '#555', textAlign: 'center', padding: '40px 0' },

  primaryBtn: (disabled) => ({ background: disabled ? '#3a3a2a' : C.oro, color: disabled ? '#888' : '#111', border: 'none', borderRadius: 10, padding: '10px 18px', fontSize: 14, fontWeight: 500, cursor: disabled ? 'not-allowed' : 'pointer', fontFamily: "'Inter', sans-serif" }),
  ghostBtn: { background: 'transparent', border: `0.5px solid ${C.borde}`, borderRadius: 10, padding: '10px 18px', fontSize: 14, color: C.texto2, cursor: 'pointer', fontFamily: "'Inter', sans-serif" },
  dangerBtn: { background: 'transparent', border: '0.5px solid #5a2a2a', borderRadius: 8, padding: '6px 12px', fontSize: 12, color: '#e87a7a', cursor: 'pointer', fontFamily: "'Inter', sans-serif" },

  tabBar: { display: 'flex', gap: 4, marginBottom: 20, borderBottom: `0.5px solid ${C.borde}`, overflowX: 'auto' },
  tabBtn: (active) => ({ background: 'transparent', border: 'none', borderBottom: active ? `2px solid ${C.oro}` : '2px solid transparent', color: active ? C.oro : C.texto2, padding: '8px 4px', marginRight: 18, fontSize: 13, fontWeight: 500, cursor: 'pointer', fontFamily: "'Inter', sans-serif", whiteSpace: 'nowrap' }),

  toolbar: { display: 'flex', gap: 10, alignItems: 'center', marginBottom: 16, flexWrap: 'wrap' },
  label: { fontSize: 12, color: C.texto2, marginBottom: 6, display: 'block', marginTop: 14 },
  input: { width: '100%', background: C.bg, border: `0.5px solid ${C.borde}`, borderRadius: 10, padding: '10px 14px', fontSize: 14, color: C.texto, fontFamily: "'Inter', sans-serif", outline: 'none', boxSizing: 'border-box' },
  inputSm: { background: C.bg, border: `0.5px solid ${C.borde}`, borderRadius: 8, padding: '7px 10px', fontSize: 13, color: C.texto, fontFamily: "'Inter', sans-serif", outline: 'none' },
  fila: { display: 'flex', gap: 12 },
  col: { flex: 1, minWidth: 0 },

  table: { width: '100%', borderCollapse: 'collapse' },
  th: { textAlign: 'left', fontSize: 12, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.06em', padding: '10px 12px', borderBottom: `0.5px solid ${C.borde}`, whiteSpace: 'nowrap' },
  td: { padding: '12px', fontSize: 13, borderBottom: '0.5px solid #1a1a1a', verticalAlign: 'middle' },

  card: { background: C.card, border: `0.5px solid ${C.borde}`, borderRadius: 12, padding: 16 },
  badge: (bg, color) => ({ fontSize: 11, fontWeight: 500, padding: '3px 10px', borderRadius: 20, background: bg, color, whiteSpace: 'nowrap', display: 'inline-block' }),

  modal: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 50, padding: 20 },
  modalBox: (ancho = 460) => ({ background: C.card, border: `0.5px solid ${C.borde}`, borderRadius: 16, padding: 24, width: '100%', maxWidth: ancho, maxHeight: '90vh', overflowY: 'auto', boxSizing: 'border-box' }),
  modalTitle: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: C.oro, marginBottom: 4 },
  modalBtns: { display: 'flex', gap: 10, marginTop: 22 },
}

// Color del badge de cada etapa. Ganado/perdido usan los colores de
// estado; las etapas abiertas, tonos neutros con el dorado al final del
// embudo.
export function estiloEtapa(etapa) {
  switch (etapa) {
    case 'ganado': return S.badge(C.okBg, C.ok)
    case 'perdido': return S.badge(C.malBg, C.mal)
    case 'negociacion':
    case 'propuesta': return S.badge('#2a2414', C.oro)
    default: return S.badge('#1f1f1f', C.texto2)
  }
}

export const FUENTES_LINK = 'https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600&family=Inter:wght@400;500&display=swap'
