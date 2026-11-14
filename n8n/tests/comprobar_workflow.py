#!/usr/bin/env python3
"""
Comprueba un workflow de n8n del agente de WhatsApp antes de importarlo.

    python3 n8n/tests/comprobar_workflow.py [workflow.json ...]
    python3 n8n/tests/comprobar_workflow.py --probar-fixtures
    python3 n8n/tests/comprobar_workflow.py --para-importar n8n/workflows/restomind_whatsapp_agente.json

Sin argumentos comprueba todos los JSON de n8n/workflows/. Sale con código 1
si hay algún error (los avisos no hacen fallar). Amplía
n8n-agente-takeaway/comprobar_hora_espana.py (spec
docs/specs/2026-11-13-agente-whatsapp-revision.md, entrega 1a, punto 7).

En todos los workflows:
  1. Claves escritas en el JSON (Anthropic, Meta, JWT/service_role, Bearer,
     app secret, verify_token, clave compartida…): error.
  2. Nodo HTTP a Anthropic, Meta (graph.facebook.com) o Supabase sin
     retryOnFail o sin onError: error.
  3. Número de WhatsApp fijo (Phone number ID en la URL o "|| '1461…'"): error.
  4. Símbolo del euro escrito en el código o en las expresiones: error
     (regla fija 6; los importes van con formatMoney()).
  5. Credenciales sin id real de n8n: error. Un id PENDIENTE-… (credencial
     que todavía hay que crear en n8n) es un aviso; con --para-importar, error.
  6. settings.errorWorkflow: error si falta (salvo en el propio workflow de
     errores); un marcador PENDIENTE-… es un aviso; con --para-importar, error.
  7. Ningún nodo lee restaurant_id ni restaurant_nombre del cuerpo recibido.

Además, en el agente (el que tiene "Extraer mensaje y contexto"):
  E1. Entrada directa desde Meta (decisión 6): el webhook POST tiene Raw Body;
      hay un nodo Crypto HMAC-SHA256 con $env.META_APP_SECRET_RESTOMIND y un
      nodo que compara con la cabecera x-hub-signature-256; y ningún
      "Respond to Webhook" con 200 se alcanza desde el webhook sin pasar por
      "¿Firma válida?" (salida verdadera). La salida falsa responde 403.
  E2. El GET no puede llegar al nodo que devuelve hub.challenge sin pasar por
      un nodo que compare hub.verify_token con $env.META_VERIFY_TOKEN_RESTOMIND.
  E3. Los nodos de envío por WhatsApp usan la credencial
      "WhatsApp Graph API Token (RestomindWapp)".
  8. Hora de España: desfases fijos prohibidos y ahoraMadrid() probada en
     los próximos cambios de hora (lo de comprobar_hora_espana.py).
  9. La salida "Sin módulo whatsapp" de "¿Atiende por WhatsApp?" no puede
     llegar en el grafo a ningún nodo HTTP a api.anthropic.com (decisión 12).
 10. "Guardar sesión" va después de "Enviar respuesta WhatsApp" y no antes.
 11. Ya no existen "HTTP Crear order" ni "HTTP Insertar items".
 12. El prompt de "Preparar reserva" no contiene el teléfono del cliente.
 14. El teléfono del cliente tampoco llega a la IA por el historial ni por el
     último mensaje del bot: "Preparar reserva", "Preparar takeaway" y
     "Preparar clasificador" llaman a contextoSinTelefono() y "Preparar
     contexto" guarda con taparTelefono(); y taparTelefono() se prueba con un
     resumen real ("📞 Teléfono: …").
 15. Envío por WhatsApp (fallo del 14-11-2026): los nodos de envío usan
     {{ $json.phone_number_id }} y todo camino hacia ellos sale de nodos de
     código que ponen phone_number_id en el json (se recorre hacia atrás
     saltando IF/Switch hasta el primer nodo de código).
 16. Ninguna referencia $('Nodo').first() sin rama: con varias salidas (la de
     error), n8n puede elegir la rama vacía. Siempre .first(0).
 13. La función partirMensaje() de "Partir mensaje", con una carta de 6.000
     caracteres: varios mensajes, en orden, de 4.096 como máximo y cortados
     por final de línea.
"""
import json, re, shutil, subprocess, sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
CARPETA = RAIZ / 'n8n' / 'workflows'
FIXTURES = Path(__file__).resolve().parent / 'fixtures'

ANTHROPIC = 'api.anthropic.com'
META = 'graph.facebook.com'
SUPABASE = 'supabase.co'

# 1. Patrones de clave. Se buscan en todo el JSON (parámetros, notas, pinData…).
CLAVES = [
    (r'sk-ant-[A-Za-z0-9_\-]{8,}', 'clave de Anthropic (sk-ant-…)'),
    (r'\bEAA[A-Za-z0-9]{30,}', 'token de Meta/WhatsApp (EAA…)'),
    (r'eyJhbGciOi[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+', 'JWT (service_role / anon de Supabase)'),
    (r'\bsb_secret_[A-Za-z0-9_\-]{10,}', 'clave secreta de Supabase (sb_secret_…)'),
    (r'Bearer\s+[A-Za-z0-9_\-\.]{20,}', 'cabecera Bearer con el token escrito'),
    (r'(?i)(app_?secret|client_?secret|verify_?token|hub\.verify_token|clave_?compartida|x-restomind-clave|shared_?secret)'
     r'["\']?\s*[:=]\s*["\'][A-Za-z0-9_\-]{8,}["\']', 'secreto escrito (app secret, verify_token o clave compartida)'),
    (r'(?i)hub\.verify_token[^"\n]{0,40}===?\s*["\'][^"\']{4,}["\']', 'verify_token comparado con un texto fijo'),
]

PROHIBIDO_HORA = [
    (r'[+-]\s*120\b', 'suma/resta 120 minutos fijos'),
    (r'[+-]\s*60\s*\)\s*%', 'suma 60 minutos fijos'),
    (r'(3600000|60\s*\*\s*60\s*\*\s*1000)\s*\*\s*[12]\b|7200000', 'suma horas fijas en milisegundos'),
    (r'getUTCHours|getUTCMinutes|getUTCDay', 'usa la hora UTC como si fuera la de España'),
    (r'UTC\s*\+\s*[12]', 'menciona un desfase UTC fijo'),
]

NODO_SWITCH_MODULO = '¿Atiende por WhatsApp?'
SALIDA_SIN_MODULO = 'Sin módulo whatsapp'
EURO = '€'


def sin_comentarios(codigo):
    codigo = re.sub(r'/\*.*?\*/', '', codigo, flags=re.S)
    return re.sub(r'(^|[^:\\])//[^\n]*', r'\1', codigo)


def url_de(n):
    return str(n.get('parameters', {}).get('url', ''))


def es_http(n):
    return n.get('type', '').endswith('.httpRequest')


def ejecutar_js(script):
    """Ejecuta JavaScript con node o, en macOS, con osascript. Devuelve (ok, salida)."""
    node = shutil.which('node') or ('/usr/local/bin/node' if Path('/usr/local/bin/node').exists() else None)
    if node:
        r = subprocess.run([node, '-e', 'const __r = (function(){' + script + '\n})(); if (__r !== undefined) process.stdout.write(String(__r));'],
                           capture_output=True, text=True)
    else:
        r = subprocess.run(['osascript', '-l', 'JavaScript', '-e', '(function(){' + script + '\n})()'],
                           capture_output=True, text=True)
    return r.returncode == 0, (r.stdout if r.returncode == 0 else r.stderr).strip()


# --- Hora de España (de comprobar_hora_espana.py) --------------------------------
def ultimo_domingo(anio, mes):
    d = datetime(anio, mes + 1, 1, tzinfo=timezone.utc) - timedelta(days=1) if mes < 12 else datetime(anio, 12, 31, tzinfo=timezone.utc)
    return d - timedelta(days=(d.weekday() + 1) % 7)


def casos_hora():
    anio = datetime.now(timezone.utc).year
    out = []
    for a in (anio, anio + 1):
        for mes, antes, despues in ((3, 1, 2), (10, 2, 1)):
            cambio = ultimo_domingo(a, mes).replace(hour=1, minute=0)
            for instante, desfase in ((cambio - timedelta(minutes=1), antes), (cambio, despues)):
                out.append((instante, instante + timedelta(hours=desfase)))
    out.append((datetime(anio, 1, 15, 23, 30, tzinfo=timezone.utc), datetime(anio, 1, 16, 0, 30, tzinfo=timezone.utc)))
    out.append((datetime(anio, 7, 15, 22, 30, tzinfo=timezone.utc), datetime(anio, 7, 16, 0, 30, tzinfo=timezone.utc)))
    return out


def extraer_funcion(codigo, firma):
    i = codigo.find(firma)
    if i < 0:
        return None
    j = codigo.index('\n}\n', i) + 2
    return codigo[i:j]


def comprobar_hora(w, errores):
    funciones = {}
    for n in w['nodes']:
        codigo = n['parameters'].get('jsCode')
        if not codigo:
            continue
        f = extraer_funcion(codigo, 'function ahoraMadrid(')
        resto = codigo.replace(f, '') if f else codigo
        for patron, motivo in PROHIBIDO_HORA:
            if re.search(patron, sin_comentarios(resto)):
                errores.append(f'[{n["name"]}] {motivo} ({patron})')
        if f:
            funciones[n['name']] = f
    if not funciones:
        errores.append('Ningún nodo define ahoraMadrid().')
    for nombre, funcion in funciones.items():
        for variante in ('Intl', 'regla UE'):
            js = funcion
            if variante == 'regla UE':
                js = js.replace('new Intl.DateTimeFormat(', "(() => { throw new Error('sin Intl'); })(")
            pruebas = ', '.join(f"['{i.strftime('%Y-%m-%dT%H:%M:%SZ')}', '{e.strftime('%Y-%m-%d')}', {e.hour * 60 + e.minute}, {(e.weekday() + 1) % 7}]" for i, e in casos_hora())
            ok, salida = ejecutar_js(js + f"""
return [{pruebas}].map(([i, fecha, min, dia]) => {{
  const r = ahoraMadrid(new Date(i));
  return (r.fecha === fecha && r.min === min && r.dia === dia) ? '' : `${{i}}: esperado ${{fecha}} ${{min}} d${{dia}}, obtenido ${{r.fecha}} ${{r.min}} d${{r.dia}}`;
}}).filter(Boolean).join('\\n');""")
            if not ok:
                errores.append(f'[{nombre}] ({variante}) no se pudo ejecutar ahoraMadrid(): {salida}')
            elif salida:
                errores.append(f'[{nombre}] ({variante}) hora incorrecta:\n{salida}')
    return len(funciones)


# --- Grafo ----------------------------------------------------------------------------
def sucesores(w, nombre, salida=None):
    out = []
    for i, destinos in enumerate(w.get('connections', {}).get(nombre, {}).get('main', [])):
        if salida is not None and i != salida:
            continue
        out.extend(x['node'] for x in (destinos or []))
    return out


def alcanzables(w, inicio):
    vistos, pila = set(), list(inicio)
    while pila:
        n = pila.pop()
        if n in vistos:
            continue
        vistos.add(n)
        pila.extend(sucesores(w, n))
    return vistos


def indice_salida(nodo_switch, clave):
    reglas = nodo_switch['parameters'].get('rules', {}).get('values', [])
    for i, r in enumerate(reglas):
        if r.get('outputKey') == clave:
            return i
    return None


def tipo_de(n):
    return n.get('type', '').split('.')[-1]


def alcanzables_sin(w, inicio, barreras):
    """Nodos alcanzables desde `inicio` sin atravesar los nodos de `barreras`."""
    vistos, pila = set(), list(inicio)
    while pila:
        n = pila.pop()
        if n in vistos:
            continue
        vistos.add(n)
        if n not in barreras:
            pila.extend(sucesores(w, n))
    return vistos


def codigo_respuesta(n):
    return int(((n.get('parameters') or {}).get('options') or {}).get('responseCode') or 200)


def comprobar_entrada(w, nodos, errores, info):
    posts = [n for n in w['nodes'] if tipo_de(n) == 'webhook' and n['parameters'].get('httpMethod') == 'POST']
    gets = [n for n in w['nodes'] if tipo_de(n) == 'webhook' and n['parameters'].get('httpMethod', 'GET') == 'GET']
    if len(posts) != 1:
        errores.append(f'el agente debe tener un solo webhook POST (tiene {len(posts)})')
        return
    post = posts[0]
    if not (post['parameters'].get('options') or {}).get('rawBody'):
        errores.append(f'[{post["name"]}] el webhook POST no tiene Raw Body: la firma de Meta no cuadraría')

    hmac = [n for n in w['nodes'] if tipo_de(n) == 'crypto' and n['parameters'].get('action') == 'hmac'
            and n['parameters'].get('type') == 'SHA256' and '$env.META_APP_SECRET_RESTOMIND' in str(n['parameters'].get('secret', ''))]
    if not hmac:
        errores.append('no hay nodo Crypto HMAC-SHA256 con $env.META_APP_SECRET_RESTOMIND')
    comparador = [n for n in w['nodes'] if 'x-hub-signature-256' in str(n['parameters'].get('jsCode', ''))]
    if not comparador:
        errores.append('ningún nodo lee la cabecera x-hub-signature-256')

    guardia = nodos.get('¿Firma válida?')
    if not guardia:
        errores.append('falta el nodo "¿Firma válida?"')
        return
    previos = alcanzables_sin(w, sucesores(w, post['name']), {guardia['name']})
    if guardia['name'] not in previos:
        errores.append('"¿Firma válida?" no se alcanza desde el webhook POST')
    for x in previos:
        if x in nodos and tipo_de(nodos[x]) == 'respondToWebhook' and codigo_respuesta(nodos[x]) == 200:
            errores.append(f'"{x}" responde 200 sin haber comprobado la firma')
        if x in nodos and es_http(nodos[x]):
            errores.append(f'"{x}" llama a un servicio antes de comprobar la firma')
    for h in hmac + comparador:
        if h['name'] not in previos:
            errores.append(f'"{h["name"]}" no va antes de "¿Firma válida?"')
    falsos = alcanzables(w, sucesores(w, guardia['name'], 1))
    resp_falso = [x for x in falsos if x in nodos and tipo_de(nodos[x]) == 'respondToWebhook']
    if not resp_falso or any(codigo_respuesta(nodos[x]) != 403 for x in resp_falso):
        errores.append('la salida falsa de "¿Firma válida?" no responde 403')
    if any(x in nodos and (es_http(nodos[x]) and ANTHROPIC in url_de(nodos[x])) for x in falsos):
        errores.append('con firma no válida se llega a la IA')
    if any(x in nodos and SUPABASE in url_de(nodos[x]) for x in falsos):
        errores.append('con firma no válida se llega a un nodo HTTP de Supabase')
    if not errores:
        info.append('entrada: Raw Body, HMAC con META_APP_SECRET_RESTOMIND y firma comprobada antes del 200')

    # GET de verificación
    for g in gets:
        def es_guardia(n):
            t = json.dumps(n.get('parameters', {}), ensure_ascii=False)
            return 'hub.verify_token' in t and '$env.META_VERIFY_TOKEN_RESTOMIND' in t
        barreras = {x for x in nodos if es_guardia(nodos[x])}
        for x in alcanzables_sin(w, sucesores(w, g['name']), barreras):
            if x in nodos and tipo_de(nodos[x]) == 'respondToWebhook' and 'hub.challenge' in json.dumps(nodos[x]['parameters']):
                errores.append(f'el GET devuelve hub.challenge ("{x}") sin comparar el verify_token')
        if not barreras:
            errores.append(f'[{g["name"]}] ningún nodo compara hub.verify_token con $env.META_VERIFY_TOKEN_RESTOMIND')

    # Credencial de envío
    for n in w['nodes']:
        if es_http(n) and META in url_de(n):
            nombre_cred = ((n.get('credentials') or {}).get('httpHeaderAuth') or {}).get('name')
            if nombre_cred != 'WhatsApp Graph API Token (RestomindWapp)':
                errores.append(f'[{n["name"]}] usa la credencial "{nombre_cred}" en vez de "WhatsApp Graph API Token (RestomindWapp)"')


def comprobar_partir(codigo, errores):
    inicio = codigo.find('const MAX_WHATSAPP')
    funcion = extraer_funcion(codigo, 'function partirMensaje(')
    if inicio < 0 or not funcion:
        errores.append('[Partir mensaje] no define MAX_WHATSAPP y partirMensaje()')
        return
    prueba = codigo[inicio:codigo.index(funcion) + len(funcion)] + r"""
const lineas = [];
let n = 0;
while (lineas.join('\n').length < 6000) {
  n++;
  lineas.push(n % 12 === 0 ? '' : `🍽 Plato de prueba número ${n} con su descripción — 12,50 €`);
  if (n % 5 === 0) lineas.push(`   _Descripción larga del plato ${n}: ingredientes de temporada, pan de la casa y aceite de oliva._`);
}
const carta = lineas.join('\n');
const partes = partirMensaje(carta);
const fallos = [];
if (carta.length < 6000) fallos.push('carta de prueba corta: ' + carta.length);
if (partes.length < 2) fallos.push('no se ha partido: ' + partes.length + ' parte(s)');
let pos = 0;
partes.forEach((p, i) => {
  if (p.length > 4096) fallos.push(`parte ${i + 1} con ${p.length} caracteres`);
  const idx = carta.indexOf(p, pos);
  if (idx < 0) { fallos.push(`parte ${i + 1} no está en el texto original (orden o contenido)`); return; }
  if (carta.slice(pos, idx).trim() !== '') fallos.push(`antes de la parte ${i + 1} se pierde texto`);
  pos = idx + p.length;
  if (pos < carta.length && carta[pos] !== '\n') fallos.push(`la parte ${i + 1} no acaba en final de línea`);
});
if (carta.slice(pos).trim() !== '') fallos.push('se pierde el final del texto');
if (partirMensaje('hola').length !== 1) fallos.push('un texto corto no se envía tal cual');
return fallos.length ? fallos.join('; ') : `OK ${carta.length} caracteres en ${partes.length} mensajes (${partes.map(p => p.length).join(', ')})`;
"""
    ok, salida = ejecutar_js(prueba)
    if not ok:
        errores.append(f'[Partir mensaje] no se pudo ejecutar partirMensaje(): {salida}')
    elif not salida.startswith('OK'):
        errores.append(f'[Partir mensaje] {salida}')
    return salida


# --- Comprobación de un workflow --------------------------------------------------------
def comprobar(ruta, para_importar=False):
    texto = Path(ruta).read_text()
    w = json.loads(texto)
    errores, avisos, info = [], [], []
    nodos = {n['name']: n for n in w.get('nodes', [])}

    # 1. Claves
    for patron, motivo in CLAVES:
        for m in re.finditer(patron, texto):
            errores.append(f'{motivo}: "{m.group(0)[:14]}…"')

    for n in w.get('nodes', []):
        p = n.get('parameters', {})
        nombre = n['name']
        url = url_de(n)
        txt = json.dumps(p, ensure_ascii=False)

        # 2. Reintentos y onError en llamadas a servicios externos
        if es_http(n) and any(s in url for s in (ANTHROPIC, META, SUPABASE)):
            if not n.get('retryOnFail'):
                errores.append(f'[{nombre}] nodo HTTP a {url.split("/")[2] if "//" in url else url} sin retryOnFail')
            if not n.get('onError') or n.get('onError') == 'stopWorkflow':
                errores.append(f'[{nombre}] nodo HTTP sin onError (continueErrorOutput o continueRegularOutput)')

        # 3. Número de WhatsApp fijo
        if META in url and re.search(r'graph\.facebook\.com/v[\d.]+/\d+/', url):
            errores.append(f'[{nombre}] Phone number ID de WhatsApp fijo en la URL: {url}')
        if re.search(r"\|\|\s*\\?['\"]\d{10,}\\?['\"]", txt):
            errores.append(f'[{nombre}] número de respaldo fijo ("|| \'<número>\'")')

        # 4. Euro escrito a mano (código sin comentarios y expresiones)
        codigo = p.get('jsCode')
        if codigo and EURO in sin_comentarios(codigo):
            errores.append(f'[{nombre}] símbolo del euro escrito en el código: usar formatMoney()')
        otros = {k: v for k, v in p.items() if k != 'jsCode'}
        if EURO in json.dumps(otros, ensure_ascii=False):
            errores.append(f'[{nombre}] símbolo del euro escrito en una expresión o parámetro')

        # 5. Credenciales
        for tipo, cred in (n.get('credentials') or {}).items():
            cid = str(cred.get('id') or '')
            if not cid or cid.startswith('CREAR-EN-N8N') or cid.startswith('cred-'):
                errores.append(f'[{nombre}] credencial {tipo} "{cred.get("name")}" sin id real de n8n ({cid})')
            elif cid.startswith('PENDIENTE'):
                msg = f'[{nombre}] credencial "{cred.get("name")}" por crear en n8n: poner su id antes de importar ({cid})'
                (errores if para_importar else avisos).append(msg)

        # 7. restaurant_id / restaurant_nombre leídos del cuerpo recibido
        if re.search(r"(outer|body|aviso|input|\$json\.body)\??\.(restaurant_id|restaurant_nombre)\b", txt):
            errores.append(f'[{nombre}] lee restaurant_id o restaurant_nombre del cuerpo recibido (el restaurante sale de phone_number_id)')

    # 7. Workflow de errores
    es_flujo_errores = any(n.get('type', '').endswith('.errorTrigger') for n in w.get('nodes', []))
    ew = (w.get('settings') or {}).get('errorWorkflow')
    if not es_flujo_errores:
        if not ew:
            errores.append('settings.errorWorkflow vacío: los fallos no controlados no se registrarían')
        elif str(ew).startswith('PENDIENTE'):
            msg = f'settings.errorWorkflow = "{ew}": poner el id del workflow de errores tras importarlo en n8n'
            (errores if para_importar else avisos).append(msg)

    # Agente
    if 'Extraer mensaje y contexto' in nodos:
        comprobar_entrada(w, nodos, errores, info)
        info.append(f'{comprobar_hora(w, errores)} nodos con ahoraMadrid() probados en {len(casos_hora())} instantes')

        # 9. Sin módulo whatsapp → nunca la IA
        sw = nodos.get(NODO_SWITCH_MODULO)
        idx = indice_salida(sw, SALIDA_SIN_MODULO) if sw else None
        if idx is None:
            errores.append(f'no está la salida "{SALIDA_SIN_MODULO}" en "{NODO_SWITCH_MODULO}"')
        else:
            alc = alcanzables(w, sucesores(w, NODO_SWITCH_MODULO, idx))
            ia = sorted(x for x in alc if x in nodos and ANTHROPIC in url_de(nodos[x]))
            if ia:
                errores.append(f'la salida "{SALIDA_SIN_MODULO}" llega a nodos de Anthropic: {", ".join(ia)}')
            elif not alc:
                errores.append(f'la salida "{SALIDA_SIN_MODULO}" no lleva a ningún nodo (el cliente no recibiría el mensaje fijo)')
            else:
                info.append(f'sin módulo whatsapp: {len(alc)} nodos alcanzables, ninguno de Anthropic')
            # Y el resto de salidas que no son "Activo" tampoco.
            for i, r in enumerate(sw['parameters']['rules']['values']):
                if r.get('outputKey') != 'Activo':
                    alc_i = alcanzables(w, sucesores(w, NODO_SWITCH_MODULO, i))
                    if any(x in nodos and ANTHROPIC in url_de(nodos[x]) for x in alc_i):
                        errores.append(f'la salida "{r.get("outputKey")}" llega a un nodo de Anthropic')

        # 10. Enviar primero, guardar después
        if 'Guardar sesión' in nodos and 'Enviar respuesta WhatsApp' in nodos:
            if 'Guardar sesión' not in alcanzables(w, sucesores(w, 'Enviar respuesta WhatsApp')):
                errores.append('"Guardar sesión" no va después de "Enviar respuesta WhatsApp"')
            if 'Enviar respuesta WhatsApp' in alcanzables(w, sucesores(w, 'Guardar sesión')):
                errores.append('"Guardar sesión" va antes de "Enviar respuesta WhatsApp"')
        else:
            errores.append('faltan "Guardar sesión" o "Enviar respuesta WhatsApp"')

        # 11. Pedido en una sola llamada
        for viejo in ('HTTP Crear order', 'HTTP Insertar items'):
            if viejo in nodos:
                errores.append(f'sigue existiendo "{viejo}" (el pedido va con fn_pedido_whatsapp_crear)')
        if 'fn_pedido_whatsapp_crear' not in texto:
            errores.append('ningún nodo llama a fn_pedido_whatsapp_crear')

        # 12. Teléfono del cliente fuera del prompt de reservas
        cod = (nodos.get('Preparar reserva') or {}).get('parameters', {}).get('jsCode', '')
        m = re.search(r'const systemPrompt = `(.*?)`;\n', cod, re.S)
        if not m:
            errores.append('[Preparar reserva] no se encuentra el systemPrompt')
        elif re.search(r'telefonoWhatsapp|\$\{\s*d\.telefono\s*\}|\$\{\s*datos\.telefono\s*\}', m.group(1)):
            errores.append('[Preparar reserva] el prompt contiene el teléfono del cliente')

        # 14. Teléfono fuera del historial que va a la IA (S6)
        def llamadas(nombre_nodo, funcion):
            c = sin_comentarios((nodos.get(nombre_nodo) or {}).get('parameters', {}).get('jsCode', ''))
            return len(re.findall(r'(?<!function )\b' + funcion + r'\(', c))
        for nn in ('Preparar reserva', 'Preparar takeaway', 'Preparar clasificador'):
            if llamadas(nn, 'contextoSinTelefono') < 1:
                errores.append(f'[{nn}] no quita el teléfono del cliente del historial antes del prompt (contextoSinTelefono)')
        c_ctx = sin_comentarios((nodos.get('Preparar contexto') or {}).get('parameters', {}).get('jsCode', ''))
        if not re.search(r'ultimo_mensaje_bot:\s*taparTelefono\(', c_ctx):
            errores.append('[Preparar contexto] guarda el último mensaje del bot con el teléfono del cliente (taparTelefono)')
        if not re.search(r'historial\s*=\s*\[[^;]*\.map\([^;]*taparTelefono\(', c_ctx, re.S):
            errores.append('[Preparar contexto] guarda el historial con el teléfono del cliente (taparTelefono)')
        cod_ctx = (nodos.get('Preparar contexto') or {}).get('parameters', {}).get('jsCode', '')
        f_tapar = extraer_funcion(cod_ctx, 'function taparTelefono(')
        if f_tapar:
            ok, salida = ejecutar_js(f_tapar + r"""
const tel = '34678237019';
const casos = ['📞 *Teléfono:* 678237019\n\n¿Confirmas la reserva?', 'llámame al +34 678 23 70 19', 'o al 34678237019'];
const malos = casos.map(c => taparTelefono(c, tel)).filter(r => /678\s?23/.test(r) || !r.includes('[tu número]'));
return malos.length ? 'MAL ' + JSON.stringify(malos) : 'OK';""")
            if not ok or salida != 'OK':
                errores.append(f'[Preparar contexto] taparTelefono() no tapa el teléfono: {salida}')
            else:
                info.append('teléfono del cliente tapado en historial y prompts')
        else:
            errores.append('[Preparar contexto] no define taparTelefono()')

        # 15. phone_number_id en el json de todo lo que llega a un envío
        def predecesores(nombre_nodo):
            out = []
            for src, c in w.get('connections', {}).items():
                for salida in c.get('main', []):
                    if any(x['node'] == nombre_nodo for x in (salida or [])):
                        out.append(src)
            return out
        envios = [n for n in w['nodes'] if es_http(n) and META in url_de(n) and '/messages' in url_de(n)]
        for env in envios:
            if '$json.phone_number_id' not in url_de(env):
                errores.append(f'[{env["name"]}] la URL no usa {{{{ $json.phone_number_id }}}} (el id tiene que ir en el propio item)')
            vistos, pila = set(), predecesores(env['name'])
            while pila:
                x = pila.pop()
                if x in vistos or x not in nodos:
                    continue
                vistos.add(x)
                if tipo_de(nodos[x]) == 'code':
                    if 'phone_number_id' not in sin_comentarios(nodos[x]['parameters'].get('jsCode', '')):
                        errores.append(f'[{x}] llega a "{env["name"]}" sin poner phone_number_id en el json')
                    # La guardia de los mensajes fijos solo rellena por si acaso: cada
                    # rama que llega a ella también tiene que traer el id.
                    if x.startswith('Preparar envío'):
                        pila.extend(predecesores(x))
                elif tipo_de(nodos[x]) in ('if', 'switch', 'merge', 'noOp'):
                    pila.extend(predecesores(x))
                else:
                    errores.append(f'[{x}] llega a "{env["name"]}" desde un nodo que no es de código ni IF/Switch')
        if envios and not any('phone_number_id' in e for e in errores):
            info.append('envíos: phone_number_id en el json de todas las ramas')

        # 16. $('Nodo').first() sin rama
        for n in w['nodes']:
            p = n.get('parameters', {})
            texto_n = sin_comentarios(p.get('jsCode', '')) + json.dumps({k: v for k, v in p.items() if k != 'jsCode'}, ensure_ascii=False)
            if re.search(r"\$\(\s*['\"][^'\"]+['\"]\s*\)\.first\(\s*\)", texto_n):
                errores.append(f'[{n["name"]}] usa $(\'…\').first() sin rama: usar .first(0)')

        # 13. Partir mensajes largos
        partir = (nodos.get('Partir mensaje') or {}).get('parameters', {}).get('jsCode')
        if not partir:
            errores.append('falta el nodo "Partir mensaje"')
        else:
            r = comprobar_partir(partir, errores)
            if r and r.startswith('OK'):
                info.append('partirMensaje: ' + r[3:])

    return errores, avisos, info


def mutaciones(agente):
    """Copias del agente con un fallo metido a propósito → texto que debe salir en los errores."""
    import copy
    def m(f):
        w = copy.deepcopy(agente)
        f(w, {n['name']: n for n in w['nodes']})
        return w
    def conectar(w, src, destinos, salida=0):
        c = w['connections'].setdefault(src, {}).setdefault('main', [])
        while len(c) <= salida:
            c.append([])
        c[salida] = [{'node': d, 'type': 'main', 'index': 0} for d in destinos]
    return [
        ('sin Raw Body', m(lambda w, n: n['Webhook1']['parameters']['options'].pop('rawBody')), 'Raw Body'),
        ('200 antes de la firma', m(lambda w, n: conectar(w, 'Webhook1', ['Responder OK'])), 'sin haber comprobado la firma'),
        ('GET sin comparar verify_token', m(lambda w, n: conectar(w, 'Webhook GET (verificación de Meta)', ['Responder challenge'])),
         'sin comparar el verify_token'),
        ('restaurant_id del cuerpo', m(lambda w, n: n['Extraer mensaje y contexto']['parameters'].update(
            jsCode=n['Extraer mensaje y contexto']['parameters']['jsCode'] + '\nconst r = aviso?.restaurant_id;')), 'restaurant_id'),
        ('sin módulo → IA', m(lambda w, n: conectar(w, 'Respuesta: sin módulo whatsapp', ['Message a model'])), 'Sin módulo whatsapp'),
        ('euro escrito', m(lambda w, n: n['Formatear carta']['parameters'].update(
            jsCode=n['Formatear carta']['parameters']['jsCode'] + "\nconst x = '1,00 \u20ac';")), 'euro'),
        ('número de respaldo fijo', m(lambda w, n: n['Enviar respuesta WhatsApp']['parameters'].update(
            url="=https://graph.facebook.com/v25.0/{{ $json.phone_number_id || '1461480243709434' }}/messages")), 'respaldo fijo'),
        ('HTTP sin reintentos', m(lambda w, n: n['Buscar sesión'].pop('retryOnFail')), 'sin retryOnFail'),
        ('sin errorWorkflow', m(lambda w, n: w['settings'].pop('errorWorkflow')), 'errorWorkflow'),
        ('guardar antes de enviar', m(lambda w, n: (conectar(w, 'Comprobar envío', []), conectar(w, 'Partir mensaje', ['Guardar sesión']),
                                                    conectar(w, 'Guardar sesión', ['Enviar respuesta WhatsApp']))), 'Guardar sesión'),
        ('teléfono en el prompt de reservas', m(lambda w, n: n['Preparar reserva']['parameters'].update(
            jsCode=n['Preparar reserva']['parameters']['jsCode'].replace('Fecha actual: ', 'Tel: ${telefonoWhatsapp}. Fecha actual: ', 1))),
         'teléfono del cliente'),
        ('teléfono en el historial del prompt de reservas', m(lambda w, n: n['Preparar reserva']['parameters'].update(
            jsCode=n['Preparar reserva']['parameters']['jsCode'].replace('contexto = contextoSinTelefono(contexto, d.telefono);', ''))),
         'historial'),
        ('teléfono guardado en el historial', m(lambda w, n: n['Preparar contexto']['parameters'].update(
            jsCode=n['Preparar contexto']['parameters']['jsCode'].replace('ultimo_mensaje_bot: taparTelefono(mensajeRespuesta, telefono)', 'ultimo_mensaje_bot: mensajeRespuesta'))),
         'Preparar contexto'),
        ('respuesta sin phone_number_id', m(lambda w, n: n['Respuesta: solo texto']['parameters'].update(
            jsCode=n['Respuesta: solo texto']['parameters']['jsCode'].replace('  phone_number_id: d.phone_number_id,\n', ''))),
         'phone_number_id'),
        ('envío con el id de otro nodo', m(lambda w, n: n['Enviar respuesta WhatsApp (rechazo)']['parameters'].update(
            url="=https://graph.facebook.com/v25.0/{{ $('Extraer mensaje y contexto').first(0).json.phone_number_id }}/messages")),
         '$json.phone_number_id'),
        ('first() sin rama', m(lambda w, n: n['Partir mensaje']['parameters'].update(
            jsCode=n['Partir mensaje']['parameters']['jsCode'] + "\nconst x = $('Extraer mensaje y contexto').first();")),
         'sin rama'),
        ('credencial de envío antigua', m(lambda w, n: n['Enviar respuesta WhatsApp'].update(
            credentials={'httpHeaderAuth': {'id': 'DpQ4wmSyfHTEQVG4', 'name': 'WhatsApp Graph API Token'}})), 'RestomindWapp'),
    ]


def probar_fixtures():
    """Cada fixture y cada mutación del agente tienen que FALLAR con el error esperado."""
    import tempfile
    fallos = 0
    casos = [(f.name, f, 'clave') for f in sorted(FIXTURES.glob('*.json'))]
    agente = CARPETA / 'restomind_whatsapp_agente.json'
    tmp = Path(tempfile.mkdtemp())
    for nombre, w, esperado in mutaciones(json.loads(agente.read_text())):
        ruta = tmp / (re.sub(r'\W+', '_', nombre) + '.json')
        ruta.write_text(json.dumps(w, ensure_ascii=False))
        casos.append(('mutación: ' + nombre, ruta, esperado))
    for nombre, ruta, esperado in casos:
        errores, _, _ = comprobar(ruta)
        ok = any(esperado.lower() in e.lower() for e in errores)
        print(f'{"OK " if ok else "MAL"} {nombre}: {"falla como debe" if ok else "NO detecta el fallo"}'
              + ('' if ok else f' (errores: {"; ".join(errores) or "ninguno"})'))
        fallos += 0 if ok else 1
    print(f'{len(casos) - fallos} de {len(casos)} detectados')
    return 1 if fallos else 0


def main(args):
    exigir = '--para-importar' in args
    args = [a for a in args if a != '--para-importar']

    if args == ['--probar-fixtures']:
        sys.exit(probar_fixtures())

    rutas = [Path(a) for a in args] or sorted(CARPETA.glob('*.json'))
    total = 0
    for ruta in rutas:
        errores, avisos, info = comprobar(ruta, exigir)
        print(f'== {ruta.name}')
        for i in info:
            print(f'   {i}')
        for a in avisos:
            print(f'   AVISO: {a}')
        for e in errores:
            print(f'   ERROR: {e}')
        print(f'   {"OK" if not errores else str(len(errores)) + " errores"}')
        total += len(errores)
    sys.exit(1 if total else 0)


if __name__ == '__main__':
    main(sys.argv[1:])
