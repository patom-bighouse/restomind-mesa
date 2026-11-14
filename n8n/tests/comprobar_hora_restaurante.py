#!/usr/bin/env python3
"""
Comprueba que el agente de WhatsApp calcula bien la hora del restaurante.

    python3 n8n/tests/comprobar_hora_restaurante.py [workflow.json]

Sustituye a n8n-agente-takeaway/comprobar_hora_espana.py (que ahora solo llama
a este) y es el punto 8 de comprobar_workflow.py. Spec:
docs/specs/2026-11-14-zona-horaria-restaurante.md (criterio 7a).

1. En todos los nodos de código:
   - desfases horarios fijos prohibidos (sumar 1 o 2 horas a UTC,
     getUTCHours, "UTC+2"...), salvo dentro de ahoraEnZona(), que los usa como
     respaldo sin Intl con la regla de la UE;
   - ahoraMadrid() ya no puede existir;
   - 'Europe/Madrid' solo puede aparecer en `const ZONA_POR_DEFECTO = 'Europe/Madrid';`
     (y en el respaldo de ahoraEnZona()).
2. ahoraEnZona() de cada nodo se ejecuta con node (o con osascript, el
   JavaScript de macOS) en Europe/Madrid, Atlantic/Canary y America/Mexico_City:
   los próximos cambios de hora, los de la spec (2027-03-28, 2027-10-31) y
   México sin cambio (2027-04-04 y 2027-10-31). Con Intl en las tres zonas;
   sin Intl en Madrid y Canarias, y en México tiene que lanzar un error.
3. Cada llamada a ahoraEnZona() pasa la zona (ahoraEnZona(zonaRestaurante()…)),
   y zonaRestaurante() lee zona_horaria de "Verificar restaurante y módulo
   whatsapp" con .first(0) y, si falta, da Europe/Madrid.
4. "Preparar pedido datos" manda p_hora_recogida con la zona del restaurante.
5. "Verificar restaurante y módulo whatsapp" lee zona_horaria de restaurants
   y la deja en su salida.

Ejecutarlo antes de importar el JSON en n8n y antes de cada cambio de hora.
"""
import json, re, shutil, subprocess, sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
RUTA_POR_DEFECTO = RAIZ / 'n8n' / 'workflows' / 'restomind_whatsapp_agente.json'
NODO_RESTAURANTE = 'Verificar restaurante y módulo whatsapp'
NODO_PEDIDO = 'Preparar pedido datos'
NODOS_ESPERADOS = 7

PROHIBIDO_HORA = [
    (r'[+-]\s*120\b', 'suma/resta 120 minutos fijos'),
    (r'[+-]\s*60\s*\)\s*%', 'suma 60 minutos fijos'),
    (r'(3600000|60\s*\*\s*60\s*\*\s*1000)\s*\*\s*[12]\b|7200000', 'suma horas fijas en milisegundos'),
    (r'getUTCHours|getUTCMinutes|getUTCDay', 'usa la hora UTC como si fuera la local'),
    (r'UTC\s*\+\s*[12]', 'menciona un desfase UTC fijo'),
]

# Horas de invierno respecto a UTC y si aplican la regla de la UE (+1 en verano).
ZONAS = {
    'Europe/Madrid': (1, True),
    'Atlantic/Canary': (0, True),
    'America/Mexico_City': (-6, False),   # sin horario de verano desde 2022
}
SIN_INTL = ('Europe/Madrid', 'Atlantic/Canary')

# Casos fijos de la spec: (zona, instante UTC, 'YYYY-MM-DD HH:MM' local).
CASOS_SPEC = [
    ('Atlantic/Canary', '2027-03-28T00:59:00Z', '2027-03-28 00:59'),
    ('Europe/Madrid', '2027-03-28T00:59:00Z', '2027-03-28 01:59'),
    ('Atlantic/Canary', '2027-03-28T01:00:00Z', '2027-03-28 02:00'),
    ('Europe/Madrid', '2027-03-28T01:00:00Z', '2027-03-28 03:00'),
    ('Atlantic/Canary', '2027-10-31T00:59:00Z', '2027-10-31 01:59'),
    ('Atlantic/Canary', '2027-10-31T01:00:00Z', '2027-10-31 01:00'),
    ('Europe/Madrid', '2027-10-31T00:59:00Z', '2027-10-31 02:59'),
    ('Europe/Madrid', '2027-10-31T01:00:00Z', '2027-10-31 02:00'),
    ('America/Mexico_City', '2027-04-04T12:00:00Z', '2027-04-04 06:00'),
    ('America/Mexico_City', '2027-10-31T12:00:00Z', '2027-10-31 06:00'),
    # Cerca de medianoche: el día también cambia.
    ('America/Mexico_City', '2027-01-16T03:30:00Z', '2027-01-15 21:30'),
    ('Atlantic/Canary', '2027-07-15T23:30:00Z', '2027-07-16 00:30'),
]


def sin_comentarios(codigo):
    codigo = re.sub(r'/\*.*?\*/', '', codigo, flags=re.S)
    return re.sub(r'(^|[^:\\])//[^\n]*', r'\1', codigo)


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


def ultimo_domingo(anio, mes):
    d = datetime(anio, mes + 1, 1, tzinfo=timezone.utc) - timedelta(days=1) if mes < 12 else datetime(anio, 12, 31, tzinfo=timezone.utc)
    return d - timedelta(days=(d.weekday() + 1) % 7)


def local(zona, instante):
    invierno, ue = ZONAS[zona]
    verano = ue and ultimo_domingo(instante.year, 3).replace(hour=1) <= instante < ultimo_domingo(instante.year, 10).replace(hour=1)
    return instante + timedelta(hours=invierno + (1 if verano else 0))


def casos_hora():
    """(zona, instante UTC, hora local esperada): próximos cambios de hora en las
    tres zonas, un día de invierno y uno de verano cerca de medianoche, y los
    casos fijos de la spec."""
    anio = datetime.now(timezone.utc).year
    out = []
    for zona in ZONAS:
        for a in (anio, anio + 1):
            for mes in (3, 10):
                cambio = ultimo_domingo(a, mes).replace(hour=1, minute=0)
                for instante in (cambio - timedelta(minutes=1), cambio):
                    out.append((zona, instante, local(zona, instante)))
        for instante in (datetime(anio, 1, 15, 23, 30, tzinfo=timezone.utc), datetime(anio, 7, 15, 22, 30, tzinfo=timezone.utc)):
            out.append((zona, instante, local(zona, instante)))
    for zona, i, e in CASOS_SPEC:
        instante = datetime.strptime(i, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
        esperado = datetime.strptime(e, '%Y-%m-%d %H:%M')
        if local(zona, instante).replace(tzinfo=None) != esperado:
            raise SystemExit(f'caso de la spec mal calculado por el propio comprobador: {zona} {i}')
        out.append((zona, instante, esperado))
    return out


def extraer_funcion(codigo, firma):
    i = codigo.find(firma)
    if i < 0:
        return None
    j = codigo.index('\n}\n', i) + 2
    return codigo[i:j]


def comprobar_hora(w, errores):
    """Puntos 1 a 5. Devuelve cuántos nodos definen ahoraEnZona()."""
    nodos = {n['name']: n for n in w.get('nodes', [])}
    funciones = {}
    for n in w.get('nodes', []):
        codigo = n.get('parameters', {}).get('jsCode')
        otros = json.dumps({k: v for k, v in n.get('parameters', {}).items() if k != 'jsCode'}, ensure_ascii=False)
        if 'Europe/Madrid' in otros:
            errores.append(f'[{n["name"]}] \'Europe/Madrid\' escrito en un parámetro (la zona sale del restaurante)')
        if not codigo:
            continue
        f = extraer_funcion(codigo, 'function ahoraEnZona(')
        resto = sin_comentarios(codigo.replace(f, '') if f else codigo)
        for patron, motivo in PROHIBIDO_HORA:
            if re.search(patron, resto):
                errores.append(f'[{n["name"]}] {motivo} ({patron})')
        if re.search(r'\bahoraMadrid\b', resto):
            errores.append(f'[{n["name"]}] sigue usando ahoraMadrid(): usar ahoraEnZona(zonaRestaurante())')
        if 'Europe/Madrid' in resto.replace("const ZONA_POR_DEFECTO = 'Europe/Madrid';", ''):
            errores.append(f'[{n["name"]}] \'Europe/Madrid\' escrito fuera de ZONA_POR_DEFECTO (la zona sale del restaurante)')
        # Toda llamada a ahoraEnZona() pasa la zona del restaurante.
        for m in re.finditer(r'(?<!function )\bahoraEnZona\(([^)]*)', resto):
            if not m.group(1).strip().startswith('zonaRestaurante('):
                errores.append(f'[{n["name"]}] llama a ahoraEnZona() sin la zona del restaurante: ahoraEnZona({m.group(1)}…)')
        if f:
            funciones[n['name']] = f
        if f or 'zonaRestaurante()' in resto:
            zr = extraer_funcion(codigo, 'function zonaRestaurante(')
            if not zr:
                errores.append(f'[{n["name"]}] usa la zona del restaurante pero no define zonaRestaurante()')
            else:
                comprobar_zona_restaurante(n['name'], zr, errores)

    if len(funciones) != NODOS_ESPERADOS:
        errores.append(f'{len(funciones)} nodos definen ahoraEnZona() y se esperaban {NODOS_ESPERADOS}')

    casos = casos_hora()
    for nombre, funcion in funciones.items():
        for variante in ('Intl', 'sin Intl'):
            js = "const ZONA_POR_DEFECTO = 'Europe/Madrid';\n" + funcion
            if variante == 'sin Intl':
                js = js.replace('new Intl.DateTimeFormat(', "(() => { throw new Error('sin Intl'); })(")
            lista = [c for c in casos if variante == 'Intl' or c[0] in SIN_INTL]
            pruebas = ', '.join(
                f"['{z}', '{i.strftime('%Y-%m-%dT%H:%M:%SZ')}', '{e.strftime('%Y-%m-%d')}', {e.hour * 60 + e.minute}, {(e.weekday() + 1) % 7}]"
                for z, i, e in lista)
            extra = ''
            if variante == 'sin Intl':
                extra = """
let lanza = false;
try { ahoraEnZona('America/Mexico_City', new Date('2027-04-04T12:00:00Z')); } catch (e) { lanza = true; }
if (!lanza) malos.push('America/Mexico_City sin Intl: tenía que lanzar un error (problema técnico) y no lo hizo');"""
            ok, salida = ejecutar_js(js + f"""
const malos = [{pruebas}].map(([z, i, fecha, min, dia]) => {{
  const r = ahoraEnZona(z, new Date(i));
  return (r.fecha === fecha && r.min === min && r.dia === dia) ? '' : `${{z}} ${{i}}: esperado ${{fecha}} ${{min}} d${{dia}}, obtenido ${{r.fecha}} ${{r.min}} d${{r.dia}}`;
}}).filter(Boolean);{extra}
return malos.join('\\n');""")
            if not ok:
                errores.append(f'[{nombre}] ({variante}) no se pudo ejecutar ahoraEnZona(): {salida}')
            elif salida:
                errores.append(f'[{nombre}] ({variante}) hora incorrecta:\n{salida}')

    # 4. Preparar pedido datos: p_hora_recogida con la zona del restaurante.
    ped = sin_comentarios((nodos.get(NODO_PEDIDO) or {}).get('parameters', {}).get('jsCode', ''))
    m = re.search(r'p_hora_recogida:[^\n]*', ped)
    if not m:
        errores.append(f'[{NODO_PEDIDO}] no se encuentra p_hora_recogida')
    elif '${zonaRestaurante()}' not in m.group(0):
        errores.append(f'[{NODO_PEDIDO}] p_hora_recogida no usa la zona del restaurante: {m.group(0).strip()[:120]}')

    # 5. Verificar restaurante: lee zona_horaria y la deja en su salida.
    ver = sin_comentarios((nodos.get(NODO_RESTAURANTE) or {}).get('parameters', {}).get('jsCode', ''))
    sel = re.search(r'select=([^\'"`&]+)', ver)
    if not sel or 'zona_horaria' not in sel.group(1).split(','):
        errores.append(f'[{NODO_RESTAURANTE}] no lee zona_horaria de restaurants')
    if not re.search(r'zona_horaria:\s*rest\.zona_horaria', ver):
        errores.append(f'[{NODO_RESTAURANTE}] no deja zona_horaria en su salida (datosRest)')
    return len(funciones)


def comprobar_zona_restaurante(nombre, funcion, errores):
    if f"$('{NODO_RESTAURANTE}').first(0)" not in funcion:
        errores.append(f'[{nombre}] zonaRestaurante() no lee "{NODO_RESTAURANTE}" con .first(0)')
        return
    base = "const ZONA_POR_DEFECTO = 'Europe/Madrid';\n"
    for datos, esperado in (({'zona_horaria': 'Atlantic/Canary'}, 'Atlantic/Canary'), ({}, 'Europe/Madrid'), (None, 'Europe/Madrid')):
        mock = (f"const $ = (n) => {{ if (n !== {json.dumps(NODO_RESTAURANTE, ensure_ascii=False)} || {json.dumps(datos)} === null) throw new Error('sin nodo');"
                f" return {{ first: (i) => ({{ json: {json.dumps(datos)} }}) }}; }};\n")
        ok, salida = ejecutar_js(base + mock + funcion + '\nreturn zonaRestaurante();')
        if not ok or salida != esperado:
            errores.append(f'[{nombre}] zonaRestaurante() con {datos} da {salida!r} y debía dar {esperado!r}')


def main():
    ruta = Path(sys.argv[1]) if len(sys.argv) > 1 else RUTA_POR_DEFECTO
    w = json.loads(ruta.read_text())
    errores = []
    n = comprobar_hora(w, errores)
    if errores:
        print('ERRORES:\n' + '\n'.join(errores))
        sys.exit(1)
    print(f'OK: {n} nodos con ahoraEnZona(), {len(casos_hora())} instantes en {", ".join(ZONAS)} '
          f'(próximos cambios de hora y los de la spec; sin Intl en Madrid y Canarias), sin desfases fijos ni Europe/Madrid escrito.')


if __name__ == '__main__':
    main()
