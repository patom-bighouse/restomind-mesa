// Prueba la comparación de la firma de Meta del nodo "Comprobar firma" del
// agente (criterio 1a de docs/specs/2026-11-13-agente-whatsapp-revision.md),
// con el HMAC calculado aquí como lo haría el nodo Crypto "Calcular firma".
//   node n8n/tests/probar_firma.cjs [n8n/workflows/restomind_whatsapp_agente.json]
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const ruta = process.argv[2] || path.join(__dirname, '..', 'workflows', 'restomind_whatsapp_agente.json');
const nodo = JSON.parse(fs.readFileSync(ruta, 'utf8')).nodes.find(n => n.name === 'Comprobar firma');
if (!nodo) { console.log('MAL no está el nodo "Comprobar firma"'); process.exit(1); }
const codigo = nodo.parameters.jsCode;
const SECRETO = 'secreto-de-prueba';
const cuerpo = JSON.stringify({ object: 'whatsapp_business_account', entry: [{ changes: [{ value: { metadata: { phone_number_id: '123' }, messages: [{ from: '34600000001', id: 'wamid.x', type: 'text', text: { body: 'hola ñ €' } }] } }] }] });
const hmac = b => crypto.createHmac('sha256', SECRETO).update(b, 'utf8').digest('hex');
const correr = (cuerpoBruto, firmaRecibida, secreto = SECRETO, calculada = hmac(cuerpoBruto)) => {
  const f = new Function('$', '$input', '$env', codigo);
  return f(() => ({ first: () => ({ json: { cuerpoBruto, firmaRecibida } }) }),
           { first: () => ({ json: { firmaCalculada: secreto ? calculada : '' } }) },
           { META_APP_SECRET_RESTOMIND: secreto })[0].json;
};
const casos = [
  ['firma correcta', correr(cuerpo, 'sha256=' + hmac(cuerpo)), r => r.firmaValida === true && r.aviso.entry[0].changes[0].value.metadata.phone_number_id === '123'],
  ['sin cabecera', correr(cuerpo, ''), r => r.firmaValida === false && /sin cabecera/.test(r.motivo)],
  ['firma inventada', correr(cuerpo, 'sha256=' + 'a'.repeat(64)), r => r.firmaValida === false],
  ['cuerpo cambiado en un carácter', correr(cuerpo.replace('hola', 'hola!'), 'sha256=' + hmac(cuerpo)), r => r.firmaValida === false],
  ['firma sin prefijo sha256=', correr(cuerpo, hmac(cuerpo)), r => r.firmaValida === false],
  ['sin secreto en n8n', correr(cuerpo, 'sha256=' + hmac(cuerpo), ''), r => r.firmaValida === false && /META_APP_SECRET/.test(r.motivo)],
];
let mal = 0;
for (const [n, r, ok] of casos) { const b = ok(r); mal += b ? 0 : 1; console.log((b ? 'OK  ' : 'MAL ') + n, b ? '' : JSON.stringify(r)); }
process.exit(mal ? 1 : 0);
