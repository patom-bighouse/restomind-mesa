import { Fragment } from 'react'

const NUMERO_WHATSAPP = '34678237019'

function linkWhatsapp(mensaje) {
  return `https://wa.me/${NUMERO_WHATSAPP}?text=${encodeURIComponent(mensaje)}`
}

const C = {
  bg: '#ffffff',
  bgSoft: '#faf6ee',
  border: '#ece1cc',
  text: '#241c14',
  textBody: '#5c5044',
  textMuted: '#9b8b70',
  gold: '#c99a35',
  goldSoft: 'rgba(201,154,53,0.12)',
  terracotta: '#c1502e',
  terracottaSoft: 'rgba(193,80,46,0.09)',
  creamMuted: '#cbbfa8',
}

const FEATURES = [
  {
    emoji: '📱',
    titulo: 'Carta digital con QR',
    texto: 'El cliente escanea el código de su mesa y ve la carta al instante, sin descargar nada.',
    puntos: ['Pide desde el móvil, sin esperar a que el camarero tome nota', 'La carta se actualiza sola: precios, fotos y disponibilidad al día'],
  },
  {
    emoji: '🛵',
    titulo: 'Takeaway y delivery',
    texto: 'Los pedidos para recoger o enviar entran directos a cocina, sin llamadas ni confusiones.',
    puntos: ['Un asistente por WhatsApp puede tomar el pedido de forma automática', 'El cliente recibe confirmación con hora de recogida y precio exacto'],
  },
  {
    emoji: '📅',
    titulo: 'Reservas',
    texto: 'Gestiona las reservas de tu restaurante sin depender de llamadas ni una libreta.',
    puntos: ['El sistema comprueba la disponibilidad real de mesas antes de confirmar', 'También se pueden recibir y confirmar por WhatsApp'],
  },
  {
    emoji: '📊',
    titulo: 'Todo en un panel',
    texto: 'Mesas, stock, equipo y fidelización de clientes, centralizados en un solo sitio.',
    puntos: ['Control de stock por ingrediente, con avisos cuando algo se agota', 'Reportes con datos reales para decidir, no a ojo'],
  },
]

const MAS_FUNCIONES = [
  '🌍 Multi-idioma', '🎁 Fidelización y vales regalo', '🍽 Varios menús', '🤖 Carta generada con IA',
  '🔐 Gestión de equipo con PIN', '🌐 Dominio y marca propia', '🔗 Integraciones y webhooks',
]

const PLANES = [
  {
    nombre: 'Básico',
    precio: 35,
    variante: 'basico',
    bullets: ['Carta digital con QR', 'Pedidos desde la mesa, sin esperar al camarero', 'Panel de administración'],
  },
  {
    nombre: 'Profesional',
    precio: 89,
    variante: 'pro',
    bullets: ['Todo lo de Básico', 'Reservas, stock y varios menús', 'Reportes y gestión de equipo'],
  },
  {
    nombre: 'Premium',
    precio: 169,
    variante: 'premium',
    bullets: ['Todo lo de Profesional', 'Pedidos y reservas por WhatsApp', 'Dominio propio y marca personalizada'],
  },
]

const S = {
  page: { minHeight: '100vh', background: C.bg, color: C.text, fontFamily: "'Inter', sans-serif", overflowX: 'hidden' },
  nav: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '22px clamp(20px, 5vw, 60px)' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 24, fontWeight: 600, color: C.text },
  navBtn: { background: 'transparent', border: `1.5px solid ${C.terracotta}`, borderRadius: 30, padding: '10px 22px', fontSize: 14, color: C.terracotta, textDecoration: 'none', fontWeight: 600 },

  heroWrap: {
    backgroundImage: "url('/hero-restaurante.jpg')",
    backgroundSize: 'cover', backgroundPosition: 'center',
    padding: 'clamp(50px, 10vw, 110px) clamp(16px, 5vw, 60px)',
    display: 'flex', justifyContent: 'center',
  },
  hero: {
    textAlign: 'center', maxWidth: 720, width: '100%',
    background: 'rgba(255,255,255,0.92)', backdropFilter: 'blur(6px)', WebkitBackdropFilter: 'blur(6px)',
    borderRadius: 28, padding: 'clamp(36px, 6vw, 60px) clamp(24px, 5vw, 56px)',
    boxShadow: '0 30px 70px rgba(36,28,20,0.25)',
  },
  h1: { fontFamily: "'Playfair Display', serif", fontSize: 'clamp(34px, 6vw, 58px)', color: C.text, lineHeight: 1.18, marginBottom: 22 },
  heroSub: { fontSize: 'clamp(16px, 2.2vw, 19px)', color: C.textBody, lineHeight: 1.6, marginBottom: 38, maxWidth: 600, marginLeft: 'auto', marginRight: 'auto' },
  ctaBtn: {
    display: 'inline-block', background: C.terracotta, color: '#fff', border: 'none', borderRadius: 40,
    padding: '17px 38px', fontSize: 16, fontWeight: 700, textDecoration: 'none',
    boxShadow: '0 10px 24px rgba(193,80,46,0.28)',
  },

  comoSection: { background: C.bgSoft, padding: 'clamp(60px, 8vw, 90px) clamp(20px, 5vw, 60px)' },
  comoInner: { maxWidth: 1100, margin: '0 auto' },
  comoHeader: { textAlign: 'center', maxWidth: 560, margin: '0 auto 54px' },
  eyebrow: { fontSize: 13.5, letterSpacing: 2, textTransform: 'uppercase', color: C.terracotta, fontWeight: 700, marginBottom: 14 },
  h2: { fontFamily: "'Playfair Display', serif", fontSize: 'clamp(26px, 3.6vw, 36px)', color: C.text, marginBottom: 14, lineHeight: 1.25 },
  h2Sub: { fontSize: 16, color: C.textBody, lineHeight: 1.6 },
  cfRow: { display: 'flex', alignItems: 'flex-start', justifyContent: 'center', gap: 8 },
  cfStep: { display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', width: 250, flexShrink: 0 },
  cfIlustracion: { width: '100%', maxWidth: 190, marginBottom: 22 },
  cfSvg: { width: '100%', height: 'auto', display: 'block' },
  cfNumero: {
    fontSize: 12.5, color: C.terracotta, letterSpacing: 1.5, textTransform: 'uppercase', marginBottom: 8, fontWeight: 700,
  },
  cfTitulo: { fontFamily: "'Playfair Display', serif", fontSize: 19, color: C.text, marginBottom: 8, lineHeight: 1.3 },
  cfTexto: { fontSize: 14.5, color: C.textBody, lineHeight: 1.55 },
  cfArrow: { flexShrink: 0, fontSize: 26, color: C.terracotta, marginTop: 60, opacity: 0.55 },

  featuresSection: { padding: 'clamp(60px, 8vw, 90px) clamp(20px, 5vw, 60px) clamp(50px, 7vw, 80px)', maxWidth: 1160, margin: '0 auto' },
  featuresHeader: { textAlign: 'center', maxWidth: 600, margin: '0 auto 50px' },
  features: { display: 'flex', flexWrap: 'wrap', gap: 24, justifyContent: 'center' },
  featureCard: {
    flex: '1 1 260px', maxWidth: 280, background: C.bgSoft,
    border: `1px solid ${C.border}`, borderRadius: 8, padding: '10px',
    boxShadow: '0 12px 28px rgba(36,28,20,0.06)', position: 'relative', textAlign: 'center',
  },
  featureCardInner: {
    border: `1px solid ${C.border}`, borderRadius: 5, padding: '28px 22px 26px',
  },
  featureIndice: { position: 'absolute', top: 18, right: 20, fontSize: 12, color: C.textMuted, fontWeight: 700, letterSpacing: 1 },
  featureIconWrap: {
    width: 56, height: 56, borderRadius: '50%', background: C.goldSoft,
    border: `1px solid ${C.gold}`, display: 'flex', alignItems: 'center',
    justifyContent: 'center', fontSize: 24, margin: '0 auto 18px',
  },
  featureTitulo: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: C.text, letterSpacing: 0.2, marginBottom: 12 },
  ornamento: { display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, margin: '0 0 16px' },
  ornamentoLinea: { width: 28, height: 1, background: C.border },
  ornamentoDiamante: { color: C.gold, fontSize: 10 },
  featureTexto: { fontSize: 14, color: C.textBody, lineHeight: 1.6, fontStyle: 'italic', marginBottom: 18 },
  featureIncluyeLabel: { fontSize: 11, letterSpacing: 1.5, textTransform: 'uppercase', color: C.textMuted, fontWeight: 700, textAlign: 'left', marginBottom: 10 },
  featurePuntos: { listStyle: 'none', padding: 0, margin: 0, fontSize: 13.5, color: C.textBody, lineHeight: 1.85, textAlign: 'left' },
  featurePunto: { display: 'flex', gap: 8 },
  featurePuntoMarca: { color: C.terracotta, flexShrink: 0, fontWeight: 700 },

  masWrap: {
    backgroundImage: "linear-gradient(rgba(255,255,255,0.18), rgba(255,255,255,0.22)), url('/mesa-restaurante.jpg')",
    backgroundSize: 'cover', backgroundPosition: 'center',
    padding: 'clamp(50px, 8vw, 90px) clamp(16px, 5vw, 60px)',
    display: 'flex', justifyContent: 'center',
  },
  masSection: { maxWidth: 920, width: '100%', textAlign: 'center' },
  masCard: {
    background: 'rgba(255,255,255,0.85)', backdropFilter: 'blur(6px)', WebkitBackdropFilter: 'blur(6px)',
    border: `1px solid rgba(255,255,255,0.6)`, borderRadius: 24,
    padding: 'clamp(36px, 6vw, 54px) clamp(24px, 5vw, 54px)',
    boxShadow: '0 24px 60px rgba(36,28,20,0.18)',
  },
  masTitulo: { fontFamily: "'Playfair Display', serif", fontSize: 'clamp(22px, 3vw, 28px)', color: C.text, marginBottom: 14 },
  masSub: { fontSize: 15, color: C.textBody, lineHeight: 1.65, marginBottom: 34, maxWidth: 540, marginLeft: 'auto', marginRight: 'auto' },
  masTags: { display: 'flex', flexWrap: 'wrap', gap: 18, justifyContent: 'center', marginBottom: 38, padding: '10px 4px' },
  masTag: (deg) => ({
    position: 'relative', fontFamily: "'Kalam', cursive", fontWeight: 700, fontSize: 16.5,
    color: '#f2ecd8', background: '#2e2419',
    border: '2px solid #6b4a30', borderRadius: 7,
    padding: '13px 18px 11px', boxShadow: '0 10px 20px rgba(36,28,20,0.3)',
    transform: `rotate(${deg}deg)`,
  }),
  masTagClip: { position: 'absolute', top: -9, left: '50%', transform: 'translateX(-50%)', width: 22, height: 12, background: '#b9ab8f', borderRadius: 3, boxShadow: '0 2px 4px rgba(0,0,0,0.3)' },
  masBtn: { display: 'inline-block', textDecoration: 'none', color: '#fff', background: C.terracotta, borderRadius: 30, padding: '13px 28px', fontSize: 14.5, fontWeight: 700 },

  pricing: { padding: '10px clamp(20px, 5vw, 60px) 100px', maxWidth: 1100, margin: '0 auto' },
  pricingGrid: { display: 'flex', flexWrap: 'wrap', gap: 22, justifyContent: 'center' },
  planCard: (variante) => ({
    flex: '1 1 270px', maxWidth: 310, borderRadius: 18, padding: '30px 28px',
    display: 'flex', flexDirection: 'column',
    ...(variante === 'basico' && { background: C.goldSoft, border: `1px solid ${C.gold}` }),
    ...(variante === 'pro' && { background: C.terracottaSoft, border: `2px solid ${C.terracotta}` }),
    ...(variante === 'premium' && { background: C.text, border: `1px solid ${C.text}` }),
  }),
  planNombre: (variante) => ({
    fontFamily: "'Playfair Display', serif", fontSize: 20, marginBottom: 12,
    color: variante === 'premium' ? C.gold : C.text,
  }),
  planPrecio: (variante) => ({
    fontSize: 36, fontWeight: 700, marginBottom: 20,
    color: variante === 'premium' ? '#fff' : C.text,
  }),
  planPrecioSub: (variante) => ({ fontSize: 15, fontWeight: 400, color: variante === 'premium' ? C.creamMuted : C.textMuted }),
  planBullets: (variante) => ({
    listStyle: 'none', padding: 0, margin: '0 0 26px', fontSize: 14.5, lineHeight: 2, flex: 1,
    color: variante === 'premium' ? C.creamMuted : C.textBody,
  }),
  planBtn: (variante) => {
    if (variante === 'basico') return { textAlign: 'center', display: 'block', textDecoration: 'none', background: 'transparent', color: C.gold, border: `1.5px solid ${C.gold}`, borderRadius: 30, padding: '13px 0', fontSize: 15, fontWeight: 700 }
    if (variante === 'premium') return { textAlign: 'center', display: 'block', textDecoration: 'none', background: C.gold, color: C.text, border: 'none', borderRadius: 30, padding: '13px 0', fontSize: 15, fontWeight: 700 }
    return { textAlign: 'center', display: 'block', textDecoration: 'none', background: C.terracotta, color: '#fff', border: 'none', borderRadius: 30, padding: '13px 0', fontSize: 15, fontWeight: 700 }
  },

  footer: { textAlign: 'center', padding: '34px 20px 44px', fontSize: 13, color: C.textMuted, borderTop: `1px solid ${C.border}` },
}

function IlustracionEscanear() {
  return (
    <svg viewBox="0 0 220 200" style={S.cfSvg}>
      <rect x="140" y="60" width="56" height="72" rx="6" fill="#fff" stroke={C.border} strokeWidth="2" />
      <g fill={C.text}>
        <rect x="152" y="74" width="10" height="10" />
        <rect x="172" y="74" width="10" height="10" />
        <rect x="152" y="94" width="10" height="10" />
        <rect x="172" y="114" width="10" height="10" />
        <rect x="162" y="94" width="10" height="10" />
        <rect x="152" y="114" width="10" height="10" />
      </g>
      <circle className="rm-ill-pulse" cx="168" cy="96" r="34" fill="none" stroke={C.gold} strokeWidth="3" />

      <circle cx="55" cy="80" r="24" fill="#f2c9a0" />
      <path d="M31 80a24 24 0 0 1 48 0" fill={C.text} />
      <rect x="32" y="118" width="60" height="70" rx="22" fill={C.terracotta} />
      <g className="rm-ill-arm">
        <rect x="80" y="108" width="46" height="15" rx="7" fill={C.terracotta} />
        <rect x="118" y="86" width="20" height="34" rx="4" fill={C.text} />
        <rect x="122" y="92" width="12" height="18" rx="1.5" fill={C.gold} />
      </g>
    </svg>
  )
}

function IlustracionCocina() {
  return (
    <svg viewBox="0 0 220 200" style={S.cfSvg}>
      <path className="rm-ill-steam rm-ill-steam-1" d="M75 95 q-8 -16 0 -30" stroke={C.textMuted} strokeWidth="4" fill="none" strokeLinecap="round" />
      <path className="rm-ill-steam rm-ill-steam-2" d="M108 95 q8 -18 0 -34" stroke={C.textMuted} strokeWidth="4" fill="none" strokeLinecap="round" />
      <path className="rm-ill-steam rm-ill-steam-3" d="M141 95 q-8 -16 0 -30" stroke={C.textMuted} strokeWidth="4" fill="none" strokeLinecap="round" />

      <ellipse cx="108" cy="128" rx="62" ry="18" fill={C.text} />
      <rect x="46" y="112" width="124" height="30" rx="15" fill={C.terracotta} />
      <rect x="24" y="118" width="20" height="10" rx="5" fill={C.terracotta} />
      <rect x="176" y="118" width="20" height="10" rx="5" fill={C.terracotta} />
      <rect x="70" y="146" width="76" height="10" rx="3" fill={C.border} />

      <g className="rm-ill-ticket">
        <rect x="10" y="30" width="58" height="42" rx="5" fill="#fff" stroke={C.border} strokeWidth="2" />
        <rect x="18" y="40" width="42" height="5" rx="2" fill={C.gold} />
        <rect x="18" y="50" width="30" height="5" rx="2" fill={C.border} />
        <rect x="18" y="59" width="34" height="5" rx="2" fill={C.border} />
      </g>
    </svg>
  )
}

function IlustracionPanel() {
  return (
    <svg viewBox="0 0 220 200" style={S.cfSvg}>
      <rect x="30" y="40" width="160" height="104" rx="8" fill={C.text} />
      <rect x="40" y="50" width="140" height="84" rx="4" fill={C.bgSoft} />
      <g>
        <rect className="rm-ill-bar rm-ill-bar-1" x="60" y="110" width="16" height="18" rx="3" fill={C.gold} />
        <rect className="rm-ill-bar rm-ill-bar-2" x="86" y="95" width="16" height="33" rx="3" fill={C.terracotta} />
        <rect className="rm-ill-bar rm-ill-bar-3" x="112" y="80" width="16" height="48" rx="3" fill={C.gold} />
        <rect className="rm-ill-bar rm-ill-bar-4" x="138" y="100" width="16" height="28" rx="3" fill={C.terracotta} />
      </g>
      <rect x="10" y="144" width="200" height="10" rx="5" fill={C.text} />

      <g className="rm-ill-check">
        <circle cx="178" cy="46" r="18" fill={C.terracotta} />
        <path d="M170 46l5 5 10 -11" stroke="#fff" strokeWidth="3.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      </g>
    </svg>
  )
}

const PASOS = [
  { Ilustracion: IlustracionEscanear, titulo: 'El cliente escanea y pide', texto: 'Abre la carta desde su móvil y hace el pedido sin esperar al camarero.' },
  { Ilustracion: IlustracionCocina, titulo: 'Llega directo a cocina', texto: 'El pedido aparece al instante en la pantalla de cocina, sin papelitos.' },
  { Ilustracion: IlustracionPanel, titulo: 'El admin lo ve en el panel', texto: 'Mesas, pedidos y cuentas, todo en un mismo panel en tiempo real.' },
]

export default function Landing() {
  const mensajeGeneral = 'Hola, me gustaría saber más sobre Restomind'

  return (
    <div style={S.page}>
      <style>{`
        @keyframes rmPulse { 0% { opacity: 0; transform: scale(0.7); } 40% { opacity: 1; } 100% { opacity: 0; transform: scale(1.25); } }
        .rm-ill-pulse { animation: rmPulse 2.2s ease-out infinite; transform-origin: center; transform-box: fill-box; }

        @keyframes rmArmTap { 0%, 100% { transform: rotate(0deg); } 50% { transform: rotate(-8deg); } }
        .rm-ill-arm { animation: rmArmTap 1.8s ease-in-out infinite; transform-origin: 82px 116px; }

        @keyframes rmSteam { 0% { opacity: 0; transform: translateY(0); } 30% { opacity: 0.8; } 100% { opacity: 0; transform: translateY(-18px); } }
        .rm-ill-steam { animation: rmSteam 2.4s ease-in-out infinite; transform-box: fill-box; transform-origin: center; }
        .rm-ill-steam-2 { animation-delay: 0.4s; }
        .rm-ill-steam-3 { animation-delay: 0.8s; }

        @keyframes rmTicket { 0% { opacity: 0; transform: translate(-10px, 40px) rotate(-6deg); } 35% { opacity: 1; transform: translate(0, 55px) rotate(-2deg); } 70% { opacity: 1; transform: translate(0, 55px) rotate(-2deg); } 100% { opacity: 0; transform: translate(10px, 70px) rotate(4deg); } }
        .rm-ill-ticket { animation: rmTicket 3s ease-in-out infinite; transform-box: fill-box; transform-origin: center; }

        @keyframes rmBar { 0%, 100% { transform: scaleY(0.75); } 50% { transform: scaleY(1); } }
        .rm-ill-bar { animation: rmBar 1.8s ease-in-out infinite; transform-box: fill-box; transform-origin: bottom; }
        .rm-ill-bar-2 { animation-delay: 0.2s; }
        .rm-ill-bar-3 { animation-delay: 0.4s; }
        .rm-ill-bar-4 { animation-delay: 0.6s; }

        @keyframes rmCheck { 0%, 60% { opacity: 0; transform: scale(0.4); } 75% { opacity: 1; transform: scale(1.15); } 90%, 100% { opacity: 1; transform: scale(1); } }
        .rm-ill-check { animation: rmCheck 3s ease-in-out infinite; transform-box: fill-box; transform-origin: center; }

        @media (max-width: 780px) {
          .rm-cf-row { flex-direction: column !important; align-items: center !important; gap: 44px !important; width: 100% !important; }
          .rm-cf-step { width: 100% !important; max-width: 260px !important; margin: 0 auto !important; }
          .rm-cf-arrow { display: none !important; }
        }

        /* En móvil, la tarjeta translúcida no debe tapar casi toda la foto de
           fondo — le damos más aire arriba/abajo/costados y la achicamos un
           poco para que la foto se note. */
        @media (max-width: 640px) {
          .rm-hero-wrap { padding: 60px 10px 76px !important; }
          .rm-hero-card { width: 92% !important; padding: 30px 22px !important; border-radius: 22px !important; }
          .rm-hero-h1 { font-size: 30px !important; margin-bottom: 16px !important; }
          .rm-hero-sub { margin-bottom: 26px !important; }
          .rm-mas-wrap { padding: 56px 10px 64px !important; }
          .rm-mas-card { width: 92% !important; padding: 30px 22px !important; }
        }
      `}</style>

      <header style={S.nav}>
        <span style={S.logo}>Restomind</span>
        <a href={linkWhatsapp(mensajeGeneral)} style={S.navBtn} target="_blank" rel="noreferrer">WhatsApp</a>
      </header>

      <section className="rm-hero-wrap" style={S.heroWrap}>
        <div className="rm-hero-card" style={S.hero}>
          <h1 className="rm-hero-h1" style={S.h1}>La gestión de tu restaurante, en un solo lugar</h1>
          <p className="rm-hero-sub" style={S.heroSub}>
            Carta digital, pedidos, reservas y mucho más. Todo conectado, para que dediques
            tu tiempo a lo que importa.
          </p>
          <a href={linkWhatsapp(mensajeGeneral)} style={S.ctaBtn} target="_blank" rel="noreferrer">
            Hablar por WhatsApp
          </a>
        </div>
      </section>

      <section style={S.comoSection}>
        <div style={S.comoInner}>
          <div style={S.comoHeader}>
            <div style={S.eyebrow}>Cómo funciona</div>
            <h2 style={S.h2}>De la mesa a la cocina, en segundos</h2>
            <p style={S.h2Sub}>Así se ve un pedido real, de punta a punta.</p>
          </div>
          <div className="rm-cf-row" style={S.cfRow}>
            {PASOS.map((p, i) => (
              <Fragment key={p.titulo}>
                <div className="rm-cf-step" style={S.cfStep}>
                  <div style={S.cfIlustracion}><p.Ilustracion /></div>
                  <div style={S.cfNumero}>Paso {i + 1}</div>
                  <div style={S.cfTitulo}>{p.titulo}</div>
                  <div style={S.cfTexto}>{p.texto}</div>
                </div>
                {i < PASOS.length - 1 && <div className="rm-cf-arrow" style={S.cfArrow}>→</div>}
              </Fragment>
            ))}
          </div>
        </div>
      </section>

      <section style={S.featuresSection}>
        <div style={S.featuresHeader}>
          <div style={S.eyebrow}>Funcionalidades</div>
          <h2 style={S.h2}>Todo lo que tu restaurante necesita, en un solo sistema</h2>
          <p style={S.h2Sub}>Cada módulo funciona solo o combinado con el resto, según lo que tu negocio necesite hoy.</p>
        </div>
        <div style={S.features}>
          {FEATURES.map((f, i) => (
            <div key={f.titulo} style={S.featureCard}>
              <div style={S.featureCardInner}>
                <span style={S.featureIndice}>{String(i + 1).padStart(2, '0')}</span>
                <div style={S.featureIconWrap}>{f.emoji}</div>
                <div style={S.featureTitulo}>{f.titulo}</div>
                <div style={S.ornamento}>
                  <span style={S.ornamentoLinea} />
                  <span style={S.ornamentoDiamante}>❖</span>
                  <span style={S.ornamentoLinea} />
                </div>
                <div style={S.featureTexto}>{f.texto}</div>
                <div style={S.featureIncluyeLabel}>Incluye</div>
                <ul style={S.featurePuntos}>
                  {f.puntos.map((p) => (
                    <li key={p} style={S.featurePunto}>
                      <span style={S.featurePuntoMarca}>—</span>
                      <span>{p}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="rm-mas-wrap" style={S.masWrap}>
        <div style={S.masSection}>
        <div className="rm-mas-card" style={S.masCard}>
          <div style={S.masTitulo}>Y esto es solo una parte</div>
          <p style={S.masSub}>
            Restomind se organiza en módulos, así que tu restaurante solo paga por lo que usa.
            Y siempre puedes sumar más sobre la marcha, sin cambiar de sistema.
          </p>
          <div style={S.masTags}>
            {MAS_FUNCIONES.map((t, i) => (
              <span key={t} style={S.masTag([-3, 2, -1.5, 2.5, -2, 1.5, -2.5][i % 7])}>
                <span style={S.masTagClip} />
                {t}
              </span>
            ))}
          </div>
          <a href={linkWhatsapp('Hola, quiero saber qué otras funciones tiene Restomind')} style={S.masBtn} target="_blank" rel="noreferrer">
            Cuéntanos qué necesitas
          </a>
        </div>
        </div>
      </section>

      <section style={S.pricing}>
        <div style={S.featuresHeader}>
          <div style={S.eyebrow}>Planes</div>
          <h2 style={S.h2}>Elige según lo que tu restaurante necesita</h2>
        </div>
        <div style={S.pricingGrid}>
          {PLANES.map((p) => (
            <div key={p.nombre} style={S.planCard(p.variante)}>
              <div style={S.planNombre(p.variante)}>{p.nombre}</div>
              <div style={S.planPrecio(p.variante)}>{p.precio}€<span style={S.planPrecioSub(p.variante)}>/mes</span></div>
              <ul style={S.planBullets(p.variante)}>
                {p.bullets.map((b) => <li key={b}>{b}</li>)}
              </ul>
              <a
                href={linkWhatsapp(`Hola, me interesa el plan ${p.nombre} de Restomind`)}
                style={S.planBtn(p.variante)}
                target="_blank"
                rel="noreferrer"
              >
                Consultar
              </a>
            </div>
          ))}
        </div>
      </section>

      <footer style={S.footer}>© {new Date().getFullYear()} Restomind</footer>
    </div>
  )
}
