import { Fragment } from 'react'

const NUMERO_WHATSAPP = '34678237019'

function linkWhatsapp(mensaje) {
  return `https://wa.me/${NUMERO_WHATSAPP}?text=${encodeURIComponent(mensaje)}`
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

const PASOS = [
  { emoji: '📱', titulo: 'El cliente escanea y pide', texto: 'Abre la carta desde su móvil y hace el pedido sin esperar al camarero.' },
  { emoji: '🍳', titulo: 'Llega directo a cocina', texto: 'El pedido aparece al instante en la pantalla de cocina, sin papelitos.' },
  { emoji: '💻', titulo: 'El admin lo ve en el panel', texto: 'Mesas, pedidos y cuentas, todo en un mismo panel en tiempo real.' },
]

const MAS_FUNCIONES = [
  '🌍 Multi-idioma', '🎁 Fidelización y vales regalo', '🍽 Varios menús', '🤖 Carta generada con IA',
  '🔐 Gestión de equipo con PIN', '🌐 Dominio y marca propia', '🔗 Integraciones y webhooks',
]

const PLANES = [
  {
    nombre: 'Básico',
    precio: 35,
    bullets: ['Carta digital con QR', 'Pedidos desde la mesa, sin esperar al camarero', 'Panel de administración'],
  },
  {
    nombre: 'Profesional',
    precio: 89,
    destacado: true,
    bullets: ['Todo lo de Básico', 'Reservas, stock y varios menús', 'Reportes y gestión de equipo'],
  },
  {
    nombre: 'Premium',
    precio: 169,
    bullets: ['Todo lo de Profesional', 'Pedidos y reservas por WhatsApp', 'Dominio propio y marca personalizada'],
  },
]

const S = {
  page: { minHeight: '100vh', background: '#1a1410', color: '#f0e8d8', fontFamily: "'Inter', sans-serif" },
  nav: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '20px clamp(20px, 5vw, 60px)' },
  logo: { fontFamily: "'Playfair Display', serif", fontSize: 22, fontWeight: 600, color: '#e8c97a' },
  navBtn: { background: 'transparent', border: '0.5px solid #3a2e20', borderRadius: 10, padding: '9px 18px', fontSize: 13, color: '#e8c97a', textDecoration: 'none', fontWeight: 500 },

  hero: { textAlign: 'center', padding: 'clamp(50px, 10vw, 110px) clamp(20px, 5vw, 60px) clamp(40px, 8vw, 80px)', maxWidth: 760, margin: '0 auto' },
  h1: { fontFamily: "'Playfair Display', serif", fontSize: 'clamp(28px, 5vw, 46px)', color: '#f0e8d8', lineHeight: 1.25, marginBottom: 18 },
  heroSub: { fontSize: 'clamp(14px, 2vw, 17px)', color: '#a89678', lineHeight: 1.6, marginBottom: 34, maxWidth: 560, marginLeft: 'auto', marginRight: 'auto' },
  ctaBtn: { display: 'inline-block', background: '#e8c97a', color: '#1a1410', border: 'none', borderRadius: 10, padding: '15px 32px', fontSize: 15, fontWeight: 600, textDecoration: 'none' },

  comoSection: { padding: 'clamp(10px, 3vw, 20px) clamp(20px, 5vw, 60px) clamp(50px, 8vw, 80px)', maxWidth: 900, margin: '0 auto' },
  comoHeader: { textAlign: 'center', maxWidth: 480, margin: '0 auto 46px' },
  cfRow: { display: 'flex', alignItems: 'flex-start', justifyContent: 'center' },
  cfStep: { display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', width: 150, flexShrink: 0 },
  cfIcon: {
    width: 62, height: 62, borderRadius: '50%', background: 'rgba(232,201,122,0.08)',
    border: '1px solid rgba(232,201,122,0.28)', display: 'flex', alignItems: 'center',
    justifyContent: 'center', fontSize: 26, marginBottom: 14,
  },
  cfNumero: { fontSize: 11, color: '#5a4a2a', letterSpacing: 1.5, textTransform: 'uppercase', marginBottom: 6, fontWeight: 600 },
  cfTitulo: { fontFamily: "'Playfair Display', serif", fontSize: 14.5, color: '#e8c97a', marginBottom: 6, lineHeight: 1.35 },
  cfTexto: { fontSize: 12, color: '#8a7560', lineHeight: 1.55 },
  cfConnector: { flex: '1 1 50px', height: 62, minWidth: 24, display: 'flex', alignItems: 'center', position: 'relative' },
  cfLinea: { width: '100%', height: 2, background: '#3a2e20' },

  featuresSection: { padding: '30px clamp(20px, 5vw, 60px) 80px', maxWidth: 1140, margin: '0 auto' },
  featuresHeader: { textAlign: 'center', maxWidth: 560, margin: '0 auto 48px' },
  eyebrow: { fontSize: 12, letterSpacing: 2, textTransform: 'uppercase', color: '#8a7560', fontWeight: 600, marginBottom: 12 },
  featuresTitulo: { fontFamily: "'Playfair Display', serif", fontSize: 'clamp(22px, 3vw, 28px)', color: '#f0e8d8', marginBottom: 12 },
  featuresSub: { fontSize: 14, color: '#8a7560', lineHeight: 1.6 },
  features: { display: 'flex', flexWrap: 'wrap', gap: 22, justifyContent: 'center' },
  featureCard: {
    flex: '1 1 250px', maxWidth: 270, background: '#221c14',
    border: '1px solid #3a2e20', borderRadius: 6, padding: '10px',
    boxShadow: '0 10px 30px rgba(0,0,0,0.25)', position: 'relative', textAlign: 'center',
  },
  featureCardInner: {
    border: '1px solid #3a2e20', borderRadius: 4, padding: '26px 22px 24px',
  },
  featureIndice: { position: 'absolute', top: 18, right: 20, fontSize: 11, color: '#4a3d2a', fontWeight: 600, letterSpacing: 1 },
  featureIconWrap: {
    width: 48, height: 48, borderRadius: '50%', background: 'rgba(232,201,122,0.08)',
    border: '1px solid rgba(232,201,122,0.28)', display: 'flex', alignItems: 'center',
    justifyContent: 'center', fontSize: 21, margin: '0 auto 16px',
  },
  featureTitulo: { fontFamily: "'Playfair Display', serif", fontSize: 16.5, color: '#e8c97a', letterSpacing: 0.3, marginBottom: 12 },
  ornamento: { display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, margin: '0 0 14px' },
  ornamentoLinea: { width: 26, height: 1, background: '#4a3d2a' },
  ornamentoDiamante: { color: '#e8c97a', fontSize: 9 },
  featureTexto: { fontSize: 12.5, color: '#c2ab85', lineHeight: 1.65, fontStyle: 'italic', marginBottom: 18 },
  featureIncluyeLabel: { fontSize: 10, letterSpacing: 1.5, textTransform: 'uppercase', color: '#5a4a2a', fontWeight: 600, textAlign: 'left', marginBottom: 8 },
  featurePuntos: { listStyle: 'none', padding: 0, margin: 0, fontSize: 12.5, color: '#8a7560', lineHeight: 1.9, textAlign: 'left' },
  featurePunto: { display: 'flex', gap: 8 },
  featurePuntoMarca: { color: '#e8c97a', flexShrink: 0 },

  masSection: { padding: '0 clamp(20px, 5vw, 60px) 80px', maxWidth: 860, margin: '0 auto', textAlign: 'center' },
  masCard: { background: '#221c14', border: '0.5px solid #3a2e20', borderRadius: 16, padding: 'clamp(32px, 6vw, 48px) clamp(24px, 5vw, 50px)' },
  masTitulo: { fontFamily: "'Playfair Display', serif", fontSize: 'clamp(19px, 2.6vw, 24px)', color: '#f0e8d8', marginBottom: 12 },
  masSub: { fontSize: 13.5, color: '#8a7560', lineHeight: 1.6, marginBottom: 26, maxWidth: 520, marginLeft: 'auto', marginRight: 'auto' },
  masTags: { display: 'flex', flexWrap: 'wrap', gap: 10, justifyContent: 'center', marginBottom: 28 },
  masTag: { fontSize: 12.5, color: '#c2ab85', background: 'rgba(232,201,122,0.06)', border: '0.5px solid #3a2e20', borderRadius: 20, padding: '7px 15px' },
  masBtn: { display: 'inline-block', textDecoration: 'none', color: '#e8c97a', border: '0.5px solid #e8c97a', borderRadius: 10, padding: '12px 26px', fontSize: 13.5, fontWeight: 600 },

  pricing: { padding: '20px clamp(20px, 5vw, 60px) 90px', maxWidth: 1080, margin: '0 auto' },
  h2: { fontFamily: "'Playfair Display', serif", fontSize: 'clamp(22px, 3vw, 30px)', color: '#f0e8d8', textAlign: 'center', marginBottom: 40 },
  pricingGrid: { display: 'flex', flexWrap: 'wrap', gap: 20, justifyContent: 'center' },
  planCard: (destacado) => ({
    flex: '1 1 260px', maxWidth: 300, background: destacado ? '#2a2116' : '#221c14',
    border: destacado ? '1px solid #e8c97a' : '0.5px solid #3a2e20', borderRadius: 16,
    padding: '28px 26px', display: 'flex', flexDirection: 'column',
  }),
  planNombre: { fontFamily: "'Playfair Display', serif", fontSize: 18, color: '#e8c97a', marginBottom: 10 },
  planPrecio: { fontSize: 32, fontWeight: 600, color: '#f0e8d8', marginBottom: 18 },
  planPrecioSub: { fontSize: 14, color: '#8a7560', fontWeight: 400 },
  planBullets: { listStyle: 'none', padding: 0, margin: '0 0 24px', fontSize: 13, color: '#a89678', lineHeight: 2, flex: 1 },
  planBtn: (destacado) => ({
    textAlign: 'center', display: 'block', textDecoration: 'none',
    background: destacado ? '#e8c97a' : 'transparent', color: destacado ? '#1a1410' : '#e8c97a',
    border: destacado ? 'none' : '0.5px solid #3a2e20', borderRadius: 10, padding: '12px 0',
    fontSize: 14, fontWeight: 600,
  }),

  footer: { textAlign: 'center', padding: '30px 20px 40px', fontSize: 12, color: '#5a4a2a' },
}

export default function Landing() {
  const mensajeGeneral = 'Hola, me gustaría saber más sobre Restomind'

  return (
    <div style={S.page}>
      <style>{`
        .rm-cf-dot {
          position: absolute; top: 50%; left: 0%; width: 8px; height: 8px; border-radius: 50%;
          background: #e8c97a; box-shadow: 0 0 8px rgba(232,201,122,0.75);
          transform: translate(-50%, -50%);
          animation: rmCfTravel 2.4s ease-in-out infinite;
        }
        .rm-cf-dot-2 { animation-delay: 2.2s; }
        @keyframes rmCfTravel {
          0% { left: 0%; opacity: 0; }
          8% { opacity: 1; }
          92% { opacity: 1; }
          100% { left: 100%; opacity: 0; }
        }
        @media (max-width: 640px) {
          .rm-cf-row { flex-direction: column; gap: 26px; }
          .rm-cf-connector { display: none; }
        }
        @media (prefers-reduced-motion: reduce) {
          .rm-cf-dot { animation: none; opacity: 0.7; }
        }
      `}</style>

      <header style={S.nav}>
        <span style={S.logo}>Restomind</span>
        <a href={linkWhatsapp(mensajeGeneral)} style={S.navBtn} target="_blank" rel="noreferrer">WhatsApp</a>
      </header>

      <section style={S.hero}>
        <h1 style={S.h1}>La gestión de tu restaurante, en un solo lugar</h1>
        <p style={S.heroSub}>
          Carta digital, pedidos, reservas y mucho más — todo conectado, para que dediques
          tu tiempo a lo que importa.
        </p>
        <a href={linkWhatsapp(mensajeGeneral)} style={S.ctaBtn} target="_blank" rel="noreferrer">
          Hablar por WhatsApp
        </a>
      </section>

      <section style={S.comoSection}>
        <div style={S.comoHeader}>
          <div style={S.eyebrow}>Cómo funciona</div>
          <h2 style={S.featuresTitulo}>De la mesa a la cocina, en segundos</h2>
        </div>
        <div className="rm-cf-row" style={S.cfRow}>
          {PASOS.map((p, i) => (
            <Fragment key={p.titulo}>
              <div style={S.cfStep}>
                <div style={S.cfIcon}>{p.emoji}</div>
                <div style={S.cfNumero}>Paso {i + 1}</div>
                <div style={S.cfTitulo}>{p.titulo}</div>
                <div style={S.cfTexto}>{p.texto}</div>
              </div>
              {i < PASOS.length - 1 && (
                <div className="rm-cf-connector" style={S.cfConnector}>
                  <div style={S.cfLinea} />
                  <span className={i === 0 ? 'rm-cf-dot' : 'rm-cf-dot rm-cf-dot-2'} />
                </div>
              )}
            </Fragment>
          ))}
        </div>
      </section>

      <section style={S.featuresSection}>
        <div style={S.featuresHeader}>
          <div style={S.eyebrow}>Funcionalidades</div>
          <h2 style={S.featuresTitulo}>Todo lo que tu restaurante necesita, en un solo sistema</h2>
          <p style={S.featuresSub}>Cada módulo funciona solo o combinado con el resto, según lo que tu negocio necesite hoy.</p>
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

      <section style={S.masSection}>
        <div style={S.masCard}>
          <div style={S.masTitulo}>Y esto es solo una parte</div>
          <p style={S.masSub}>
            Restomind se organiza en módulos, así que tu restaurante solo paga por lo que usa —
            y siempre puedes sumar más sobre la marcha, sin cambiar de sistema.
          </p>
          <div style={S.masTags}>
            {MAS_FUNCIONES.map((t) => <span key={t} style={S.masTag}>{t}</span>)}
          </div>
          <a href={linkWhatsapp('Hola, quiero saber qué otras funciones tiene Restomind')} style={S.masBtn} target="_blank" rel="noreferrer">
            Cuéntanos qué necesitas
          </a>
        </div>
      </section>

      <section style={S.pricing}>
        <h2 style={S.h2}>Planes</h2>
        <div style={S.pricingGrid}>
          {PLANES.map((p) => (
            <div key={p.nombre} style={S.planCard(p.destacado)}>
              <div style={S.planNombre}>{p.nombre}</div>
              <div style={S.planPrecio}>{p.precio}€<span style={S.planPrecioSub}>/mes</span></div>
              <ul style={S.planBullets}>
                {p.bullets.map((b) => <li key={b}>{b}</li>)}
              </ul>
              <a
                href={linkWhatsapp(`Hola, me interesa el plan ${p.nombre} de Restomind`)}
                style={S.planBtn(p.destacado)}
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
