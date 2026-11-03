// Condiciones del servicio (restomind.app/condiciones): contrato entre
// Restomind y los restaurantes. Los dueños de restaurantes con permanencia
// las aceptan al entrar al panel (ver GuardRestaurante).
import { CONDICIONES_FECHA, PERMANENCIA_MESES, PENALIZACION_PCT } from '../lib/condiciones'

const EMAIL_CONTACTO = 'patriciomara@gmail.com'

const C = {
  bg: '#ffffff',
  bgSoft: '#faf6ee',
  border: '#ece1cc',
  text: '#241c14',
  textBody: '#5c5044',
  textMuted: '#9b8b70',
  terracotta: '#c1502e',
}

const S = {
  page: { background: C.bg, color: C.textBody, minHeight: '100vh', fontFamily: "'Inter', system-ui, sans-serif" },
  nav: { borderBottom: `1px solid ${C.border}`, padding: '18px clamp(20px, 5vw, 60px)' },
  logo: { display: 'inline-flex', alignItems: 'center', gap: 8, fontFamily: "'Playfair Display', serif", fontSize: 22, color: C.text, textDecoration: 'none' },
  main: { maxWidth: 780, margin: '0 auto', padding: 'clamp(36px, 6vw, 64px) clamp(20px, 5vw, 40px) 80px' },
  h1: { fontFamily: "'Playfair Display', serif", fontSize: 'clamp(28px, 4vw, 38px)', color: C.text, margin: '0 0 8px' },
  fecha: { fontSize: 13, color: C.textMuted, marginBottom: 32 },
  h2: { fontFamily: "'Playfair Display', serif", fontSize: 21, color: C.text, margin: '38px 0 12px' },
  p: { fontSize: 15, lineHeight: 1.7, margin: '0 0 14px' },
  ul: { fontSize: 15, lineHeight: 1.7, margin: '0 0 14px', paddingLeft: 22 },
  resumen: { background: C.bgSoft, border: `1px solid ${C.border}`, borderRadius: 12, padding: '16px 20px', margin: '0 0 8px' },
  enlace: { color: C.terracotta },
  footer: { textAlign: 'center', padding: '34px 20px 44px', fontSize: 13, color: C.textMuted, borderTop: `1px solid ${C.border}` },
}

export default function Condiciones() {
  const mail = <a href={`mailto:${EMAIL_CONTACTO}`} style={S.enlace}>{EMAIL_CONTACTO}</a>

  return (
    <div style={S.page}>
      <nav style={S.nav}>
        <a href="/" style={S.logo}><img src="/logos/opcion-2-monograma/icon.svg" alt="" style={{ height: 28 }} />Restomind</a>
      </nav>

      <main style={S.main}>
        <h1 style={S.h1}>Condiciones del servicio</h1>
        <div style={S.fecha}>Última actualización: {CONDICIONES_FECHA}</div>

        <div style={S.resumen}>
          <p style={{ ...S.p, margin: '0 0 8px', color: C.text, fontWeight: 600 }}>En resumen</p>
          <ul style={{ ...S.ul, margin: 0 }}>
            <li>Pagas una cuota mensual fija según tu plan. Sin comisiones por pedido ni por reserva.</li>
            <li>Permanencia mínima de {PERMANENCIA_MESES} meses desde la fecha de alta. Después, mes a mes.</li>
            <li>Si te das de baja durante el periodo de prueba, no pagas nada.</li>
            <li>Si te das de baja antes de que acabe la permanencia, pagas el {PENALIZACION_PCT} % de las cuotas que falten.</li>
          </ul>
        </div>

        <h2 style={S.h2}>1. Quiénes somos y a quién se aplican</h2>
        <p style={S.p}>
          Estas condiciones regulan la relación entre <strong>Restomind</strong> (en adelante, «Restomind») y el
          restaurante o negocio de hostelería que contrata el servicio (en adelante, «el Cliente»). Contacto: {mail}.
        </p>
        <p style={S.p}>
          El servicio está dirigido a empresas y profesionales. Al aceptar estas condiciones, la persona que lo hace
          declara que actúa en nombre del Cliente y que tiene capacidad para obligarlo.
        </p>

        <h2 style={S.h2}>2. El servicio</h2>
        <p style={S.p}>
          Restomind es una plataforma en la nube para la gestión de restaurantes: carta digital con código QR, pedidos
          desde la mesa y para llevar, cocina, reservas, fidelización, informes y, según el plan, un asistente
          automático de WhatsApp. Las funciones disponibles dependen del plan contratado, descrito en{' '}
          <a href="/" style={S.enlace}>restomind.app</a> o en la oferta comercial que haya recibido el Cliente.
        </p>

        <h2 style={S.h2}>3. Alta y periodo de prueba</h2>
        <p style={S.p}>
          La fecha de alta es el día en que Restomind crea la cuenta del Cliente y le da acceso al panel. Restomind
          puede ofrecer un periodo de prueba gratuito; su duración se indica al Cliente al darle de alta. Durante la
          prueba no se cobra ninguna cuota.
        </p>

        <h2 style={S.h2}>4. Precio y facturación</h2>
        <ul style={S.ul}>
          <li>El Cliente paga una cuota mensual fija según su plan. No hay comisiones por pedido, por reserva ni por volumen de ventas.</li>
          <li>La cuota se factura por meses. Los precios vigentes y los impuestos aplicables se detallan en la oferta comercial y en cada factura.</li>
          <li>Los descuentos o promociones acordados se aplican durante el plazo pactado; al terminar, se aplica el precio del plan.</li>
          <li>Restomind puede actualizar sus precios avisando al Cliente con al menos 30 días de antelación. Si el Cliente no está de acuerdo, puede darse de baja sin penalización antes de que el nuevo precio entre en vigor.</li>
        </ul>

        <h2 style={S.h2}>5. Permanencia mínima</h2>
        <p style={S.p}>
          El contrato tiene una <strong>permanencia mínima de {PERMANENCIA_MESES} meses</strong>, contados desde la
          fecha de alta. El periodo de prueba, si lo hay, forma parte de esos {PERMANENCIA_MESES} meses. La fecha de fin
          de la permanencia figura en el panel del Cliente, en Configuración.
        </p>
        <p style={S.p}>
          Al terminar la permanencia, el contrato continúa <strong>mes a mes, sin permanencia</strong>, hasta que
          cualquiera de las partes lo dé por terminado.
        </p>

        <h2 style={S.h2}>6. Baja</h2>
        <ul style={S.ul}>
          <li>El Cliente puede pedir la baja en cualquier momento escribiendo a {mail}. La baja es efectiva al final del mes ya facturado.</li>
          <li><strong>Baja durante el periodo de prueba:</strong> sin coste.</li>
          <li>
            <strong>Baja antes de que termine la permanencia</strong> (una vez acabada la prueba): el Cliente abonará, en
            concepto de penalización, el <strong>{PENALIZACION_PCT} % de las cuotas mensuales que falten</strong> hasta
            el fin de la permanencia, calculadas con la cuota vigente en el momento de la baja. Un mes empezado cuenta
            como un mes completo.
          </li>
          <li><strong>Baja después de la permanencia:</strong> sin penalización.</li>
        </ul>
        <p style={S.p}>
          Tras la baja, el acceso al panel, la carta digital, las reservas y el asistente de WhatsApp quedan
          desactivados. El Cliente puede pedir una copia de sus datos durante los 30 días siguientes.
        </p>

        <h2 style={S.h2}>7. Suspensión por impago</h2>
        <p style={S.p}>
          Si una cuota no se paga a su vencimiento, Restomind puede suspender el servicio tras avisar al Cliente. La
          suspensión no interrumpe la permanencia ni exime de pagar las cuotas pendientes. El servicio se reactiva al
          regularizar el pago.
        </p>

        <h2 style={S.h2}>8. Obligaciones del Cliente</h2>
        <ul style={S.ul}>
          <li>Mantener la confidencialidad de sus contraseñas y de los PIN de su personal, y responder del uso que se haga de su cuenta.</li>
          <li>Asegurarse de que la información que publica es correcta y está actualizada, en especial precios y <strong>alérgenos</strong>, que son responsabilidad del Cliente.</li>
          <li>Usar el asistente de WhatsApp conforme a las políticas de WhatsApp Business y sin enviar mensajes no solicitados.</li>
          <li>Cumplir la normativa de protección de datos frente a sus propios clientes.</li>
          <li>No usar el servicio para fines ilícitos ni intentar acceder a datos de otros restaurantes.</li>
        </ul>

        <h2 style={S.h2}>9. Datos personales</h2>
        <p style={S.p}>
          Los datos de los clientes del restaurante los trata Restomind como encargado del tratamiento, por cuenta del
          Cliente y solo para prestar el servicio. Los detalles están en la{' '}
          <a href="/privacidad" style={S.enlace}>política de privacidad</a>.
        </p>

        <h2 style={S.h2}>10. Disponibilidad y soporte</h2>
        <p style={S.p}>
          Restomind pone los medios razonables para que el servicio funcione de forma continua, pero no garantiza que
          esté libre de interrupciones. Las paradas por mantenimiento se avisarán con antelación siempre que sea
          posible. El servicio depende de proveedores externos (alojamiento, WhatsApp, inteligencia artificial) cuyo
          funcionamiento no controla Restomind.
        </p>

        <h2 style={S.h2}>11. Responsabilidad</h2>
        <p style={S.p}>
          Restomind no responde de los daños indirectos ni del lucro cesante. Su responsabilidad total frente al Cliente
          se limita al importe de las cuotas pagadas por el Cliente en los 12 meses anteriores al hecho que la origine,
          salvo dolo o culpa grave.
        </p>

        <h2 style={S.h2}>12. Propiedad intelectual</h2>
        <p style={S.p}>
          La plataforma y su software son de Restomind. El Cliente conserva la propiedad de sus contenidos (carta,
          fotos, logotipos) y autoriza a Restomind a usarlos solo para prestar el servicio.
        </p>

        <h2 style={S.h2}>13. Cambios en estas condiciones</h2>
        <p style={S.p}>
          Restomind puede modificar estas condiciones avisando al Cliente con al menos 30 días de antelación. Si el
          cambio perjudica al Cliente, este puede darse de baja sin penalización antes de que entre en vigor. Los
          cambios no afectan a la permanencia ya en curso.
        </p>

        <h2 style={S.h2}>14. Ley aplicable</h2>
        <p style={S.p}>
          Estas condiciones se rigen por la legislación española. Para cualquier controversia, las partes se someten
          a los juzgados y tribunales del domicilio de Restomind, salvo que la ley disponga otra cosa.
        </p>
      </main>

      <footer style={S.footer}>
        © {new Date().getFullYear()} Restomind · <a href="/" style={{ color: C.textMuted }}>Inicio</a> · <a href="/privacidad" style={{ color: C.textMuted }}>Política de privacidad</a>
      </footer>
    </div>
  )
}
