// Política de privacidad pública (restomind.app/privacidad). Meta la exige
// para publicar la app de WhatsApp; también sirve a restaurantes y clientes.
const EMAIL_CONTACTO = 'patricio@restomind.com'
const ULTIMA_ACTUALIZACION = '31 de octubre de 2026'

const C = {
  bg: '#ffffff',
  bgSoft: '#faf6ee',
  border: '#ece1cc',
  text: '#241c14',
  textBody: '#5c5044',
  textMuted: '#9b8b70',
  gold: '#c99a35',
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
  tabla: { width: '100%', borderCollapse: 'collapse', fontSize: 14, margin: '6px 0 16px' },
  th: { textAlign: 'left', background: C.bgSoft, color: C.text, padding: '10px 12px', borderBottom: `1px solid ${C.border}` },
  td: { padding: '10px 12px', borderBottom: `1px solid ${C.border}`, verticalAlign: 'top', lineHeight: 1.55 },
  enlace: { color: C.terracotta },
  footer: { textAlign: 'center', padding: '34px 20px 44px', fontSize: 13, color: C.textMuted, borderTop: `1px solid ${C.border}` },
}

const PROVEEDORES = [
  ['Supabase', 'Base de datos, autenticación y funciones del servidor'],
  ['Vercel', 'Alojamiento de la aplicación web'],
  ['Meta Platforms (WhatsApp Business)', 'Envío y recepción de mensajes de WhatsApp'],
  ['Hostinger', 'Servidor donde funciona el asistente automático de WhatsApp'],
  ['OpenAI y Anthropic', 'Modelos de inteligencia artificial que redactan las respuestas del asistente, traducen la carta y leen cartas a partir de fotos'],
]

export default function Privacidad() {
  const mail = <a href={`mailto:${EMAIL_CONTACTO}`} style={S.enlace}>{EMAIL_CONTACTO}</a>

  return (
    <div style={S.page}>
      <nav style={S.nav}>
        <a href="/" style={S.logo}><img src="/logos/opcion-2-monograma/icon.svg" alt="" style={{ height: 28 }} />Restomind</a>
      </nav>

      <main style={S.main}>
        <h1 style={S.h1}>Política de privacidad</h1>
        <div style={S.fecha}>Última actualización: {ULTIMA_ACTUALIZACION}</div>

        <p style={S.p}>
          Restomind es una plataforma para restaurantes: carta digital con QR, pedidos desde la mesa y para llevar,
          reservas, fidelización y un asistente automático por WhatsApp. Esta política explica qué datos personales
          tratamos, para qué, con quién los compartimos y cómo puedes ejercer tus derechos, de acuerdo con el
          Reglamento General de Protección de Datos (RGPD) y la Ley Orgánica 3/2018 (LOPDGDD).
        </p>

        <h2 style={S.h2}>1. Quién es el responsable</h2>
        <p style={S.p}>
          <strong>Restomind</strong> es responsable de los datos de los restaurantes que contratan el servicio y de sus
          usuarios. Contacto: {mail}.
        </p>
        <p style={S.p}>
          Los datos de los clientes de cada restaurante (comensales, reservas, pedidos y mensajes de WhatsApp) los
          trata Restomind <strong>por cuenta del restaurante</strong>, que es su responsable. Restomind actúa como
          encargado del tratamiento y solo los usa para prestar el servicio a ese restaurante.
        </p>

        <h2 style={S.h2}>2. Qué datos tratamos</h2>
        <ul style={S.ul}>
          <li><strong>Restaurantes y su personal:</strong> nombre del local, dirección, email y contraseña de acceso, nombre y PIN del personal, datos de facturación.</li>
          <li><strong>Comensales:</strong> pedidos realizados desde la mesa, alergias que filtran en la carta y reseñas que dejan voluntariamente.</li>
          <li><strong>Clientes del programa de fidelización:</strong> nombre, teléfono, puntos acumulados y canjeados, y vales regalo.</li>
          <li><strong>Reservas:</strong> nombre, teléfono, email si se facilita, fecha, hora, número de personas y comentarios.</li>
          <li><strong>Mensajes de WhatsApp:</strong> número de teléfono, nombre de perfil y contenido de los mensajes enviados al número de WhatsApp del restaurante, junto con los pedidos y reservas que se gestionan en esa conversación.</li>
        </ul>
        <p style={S.p}>No pedimos datos de pago con tarjeta: los cobros se registran en el restaurante, no a través de Restomind.</p>

        <h2 style={S.h2}>3. Para qué los usamos</h2>
        <ul style={S.ul}>
          <li>Mostrar la carta, recibir pedidos y enviarlos a cocina.</li>
          <li>Gestionar reservas y avisar al restaurante.</li>
          <li>Sumar y canjear puntos de fidelización.</li>
          <li>Responder por WhatsApp a las consultas, reservas y pedidos para llevar de los clientes del restaurante.</li>
          <li>Dar acceso al panel al restaurante y a su personal, y facturar el servicio.</li>
          <li>Mantener la seguridad de la plataforma y resolver incidencias.</li>
        </ul>
        <p style={S.p}>No vendemos datos personales ni los usamos para publicidad.</p>

        <h2 style={S.h2}>4. Base legal</h2>
        <ul style={S.ul}>
          <li><strong>Ejecución de un contrato:</strong> el servicio contratado por el restaurante, y las reservas, pedidos y conversaciones que inicia el propio cliente.</li>
          <li><strong>Consentimiento:</strong> unirse al programa de puntos o dejar una reseña. Puedes retirarlo cuando quieras.</li>
          <li><strong>Interés legítimo:</strong> seguridad de la plataforma y prevención de abusos.</li>
          <li><strong>Obligación legal:</strong> conservación de datos de facturación.</li>
        </ul>

        <h2 style={S.h2}>5. Con quién los compartimos</h2>
        <p style={S.p}>
          Los datos de cada cliente solo los ve el restaurante con el que interactúa. Para prestar el servicio usamos
          estos proveedores, que tratan los datos siguiendo nuestras instrucciones:
        </p>
        <table style={S.tabla}>
          <thead>
            <tr><th style={S.th}>Proveedor</th><th style={S.th}>Para qué</th></tr>
          </thead>
          <tbody>
            {PROVEEDORES.map(([nombre, uso]) => (
              <tr key={nombre}><td style={S.td}>{nombre}</td><td style={S.td}>{uso}</td></tr>
            ))}
          </tbody>
        </table>
        <p style={S.p}>
          Algunos de estos proveedores están en Estados Unidos. Las transferencias se amparan en el Marco de Privacidad
          de Datos UE-EE. UU. o en las cláusulas contractuales tipo aprobadas por la Comisión Europea. Los proveedores
          de inteligencia artificial no usan estos datos para entrenar sus modelos.
        </p>

        <h2 style={S.h2}>6. Cuánto tiempo los conservamos</h2>
        <ul style={S.ul}>
          <li>Datos del restaurante y su personal: mientras dure el contrato y, después, el plazo que exija la ley.</li>
          <li>Clientes de fidelización: hasta que pidan la baja o el restaurante los elimine.</li>
          <li>Reservas, pedidos y conversaciones de WhatsApp: el tiempo necesario para gestionarlos y como máximo 24 meses, salvo que el restaurante los elimine antes.</li>
        </ul>

        <h2 style={S.h2}>7. Tus derechos</h2>
        <p style={S.p}>
          Puedes solicitar el acceso, la rectificación, la eliminación, la limitación, la portabilidad de tus datos u
          oponerte a su tratamiento escribiendo a {mail}. Si tus datos los trata Restomind por cuenta de un
          restaurante, también puedes dirigirte a ese restaurante; trasladaremos tu solicitud.
        </p>
        <p style={S.p}>
          Si crees que no hemos atendido bien tu solicitud, puedes reclamar ante la Agencia Española de Protección de
          Datos (<a href="https://www.aepd.es" style={S.enlace} target="_blank" rel="noreferrer">www.aepd.es</a>).
        </p>

        <h2 style={S.h2}>8. Cómo eliminar tus datos</h2>
        <p style={S.p}>Para borrar tus datos, incluidos los de tus conversaciones de WhatsApp con un restaurante:</p>
        <ol style={S.ul}>
          <li>Escribe a {mail} con el asunto «Eliminar mis datos».</li>
          <li>Indica tu número de teléfono o email y, si lo sabes, el nombre del restaurante.</li>
          <li>Eliminaremos tus datos en un plazo máximo de 30 días y te confirmaremos por email cuando esté hecho.</li>
        </ol>
        <p style={S.p}>Solo conservaremos lo que la ley nos obligue a guardar, como las facturas.</p>

        <h2 style={S.h2}>9. Seguridad</h2>
        <p style={S.p}>
          Las conexiones van cifradas (HTTPS), el acceso al panel requiere usuario y contraseña, y cada restaurante
          solo puede ver sus propios datos.
        </p>

        <h2 style={S.h2}>10. Cambios en esta política</h2>
        <p style={S.p}>
          Si cambiamos esta política, actualizaremos la fecha de arriba. Si el cambio es importante, avisaremos a los
          restaurantes por email.
        </p>
      </main>

      <footer style={S.footer}>© {new Date().getFullYear()} Restomind · <a href="/" style={{ color: C.textMuted }}>Inicio</a></footer>
    </div>
  )
}
