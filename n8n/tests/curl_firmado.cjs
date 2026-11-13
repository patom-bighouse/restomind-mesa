// Genera los `curl` de la prueba previa de la firma de Meta contra una COPIA
// del agente sin activar (docs/MIGRACIONES.md, "Prueba previa de la firma").
//
//   SECRETO_PRUEBA='una-frase-de-prueba' node n8n/tests/curl_firmado.cjs https://n8n.srv1244859.hstgr.cloud/webhook-test/restomind-whatsapp
//
// - El secreto es uno de PRUEBA, puesto solo en la copia: nunca el app secret
//   real. Se lee de la variable SECRETO_PRUEBA y no se guarda en ningún archivo.
// - El cuerpo lleva ñ, € y un emoji (para comprobar que la firma cuadra con
//   bytes que no son ASCII) y un phone_number_id que no es de ningún
//   restaurante: con la firma correcta el agente responde 200, registra
//   numero_desconocido y no contesta a nadie.
// - Escribe los dos cuerpos (el bueno y el cambiado en un carácter) en una
//   carpeta temporal y saca tres comandos. Antes de cada uno hay que pulsar
//   "Listen for test event" en el nodo Webhook1 de la copia.
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const url = process.argv[2];
const secreto = process.env.SECRETO_PRUEBA || '';
if (!url || !secreto) {
  console.error('Uso: SECRETO_PRUEBA=<secreto de prueba> node n8n/tests/curl_firmado.cjs <URL del webhook de prueba>');
  process.exit(1);
}

const ahora = Math.floor(Date.now() / 1000);
const cuerpo = JSON.stringify({
  object: 'whatsapp_business_account',
  entry: [{
    id: 'PRUEBA',
    changes: [{
      field: 'messages',
      value: {
        messaging_product: 'whatsapp',
        metadata: { display_phone_number: '000000000', phone_number_id: '000000000000000' },
        contacts: [{ profile: { name: 'Prueba firma' }, wa_id: '34600000001' }],
        messages: [{
          from: '34600000001',
          id: `wamid.PRUEBA-FIRMA-${ahora}`,
          timestamp: String(ahora),
          type: 'text',
          text: { body: 'Prueba de firma: España, 12,50 € y 🍽' }
        }]
      }
    }]
  }]
});
const cambiado = cuerpo.replace('España', 'Espana');
const firma = 'sha256=' + crypto.createHmac('sha256', secreto).update(Buffer.from(cuerpo, 'utf8')).digest('hex');

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'firma-meta-'));
const fBueno = path.join(dir, 'cuerpo.json');
const fMalo = path.join(dir, 'cuerpo_cambiado.json');
fs.writeFileSync(fBueno, cuerpo, 'utf8');
fs.writeFileSync(fMalo, cambiado, 'utf8');

const base = `curl -s -o /dev/null -w '%{http_code}\\n' -X POST '${url}' -H 'Content-Type: application/json'`;
console.log('# 1) Firma correcta → debe salir 200');
console.log(`${base} -H 'X-Hub-Signature-256: ${firma}' --data-binary @'${fBueno}'`);
console.log('\n# 2) Sin cabecera de firma → debe salir 403');
console.log(`${base} --data-binary @'${fBueno}'`);
console.log('\n# 3) Misma firma con el cuerpo cambiado en un carácter → debe salir 403');
console.log(`${base} -H 'X-Hub-Signature-256: ${firma}' --data-binary @'${fMalo}'`);
console.log(`\n# Cuerpos en ${dir} (bórralos al terminar).`);
