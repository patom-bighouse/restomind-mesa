# Migraciones de base de datos

Desde noviembre de 2026 todos los cambios de esquema van en `supabase/migrations/` y se aplican con la CLI de Supabase. Cada base de datos (Test y Producción) registra qué migraciones tiene aplicadas.

Los scripts anteriores están en `sql/historico/`: se aplicaron a mano desde el editor de Supabase. Se conservan como referencia; **no** se vuelven a ejecutar.

## Estado
- **Línea base:** `20261111193648_remote_schema.sql` — esquema de Producción del 11-11-2026 (`db pull`). Registrada como aplicada en Producción y en Test.
- Ojo: Test tenía entonces permisos más estrictos que Producción (ver `docs/diagnostico-2026-11-11.md`). La primera migración posterior los iguala.
- **`20261111215753_permisos_minimos.sql`** — iguala los permisos del esquema `public` en Test y Producción con el mínimo privilegio (spec `docs/specs/2026-11-11-permisos-minimos.md`): grants de tabla y columna para `anon`/`authenticated`, `service_role` con todo, EXECUTE de funciones por grupos, privilegios por defecto cerrados y `search_path` de `fn_marcar_timestamp_estado_pedido`.
  - Aplicada en **Test** el 11-11-2026. Pendiente en **Producción** (tras validar la preview de `staging` y comprobar el rol de n8n; criterios 7 y 8 de la spec).
  - Huella de permisos (`supabase/tests/permisos_huella.sql`, solo lectura): Test después = 189 filas, md5 `0eb487db5184139d07e719e1a461b76a`. Producción antes = 190 filas, md5 `21ebb850fcf9ba425bd22a0849a6d229`. Tras aplicarla en Producción, Producción debe dar el mismo md5 que Test.
  - Vuelta atrás preparada, **no** aplicada y fuera de `supabase/migrations/`: `supabase/rollback/20261111215753_permisos_minimos_revertir.sql` (repone los grants de Producción del 11-11-2026; probada en Test dentro de una transacción con `rollback`: deja la huella de Producción). Si hiciera falta, se aplica **como migración**, nunca con `db query` ni SQL suelto: `npx supabase migration new revertir_permisos_minimos`, copiar el archivo en `supabase/migrations/<ts nuevo>_revertir_permisos_minimos.sql` quitando `begin;` y `commit;`, aplicarla primero en Test (`db push --remote=sfkwbhzelrestmrmptql`) y después en Producción (`db push --remote=mfxrluanpawfjncpqrvu`).
  - Efecto secundario de quitar el EXECUTE a `PUBLIC`: `supabase_read_only_user` (el que usan la CLI con `--read-only`, el panel en modo lectura y el MCP) ya no puede **llamar** a funciones de `public`. No afecta a la app (anon/authenticated/service_role tienen sus grants explícitos) y la huella sigue funcionando porque solo lee el catálogo.
  - El `alter default privileges for role postgres revoke execute on functions from public` es **global** (sin `in schema`): afecta a las funciones nuevas que cree `postgres` en **cualquier** esquema, no solo en `public`. Quien cree funciones en otros esquemas debe dar sus `grant execute` explícitos.
- **`20261112143742_arreglar_toggle_limpieza.sql`** — `fn_camarero_toggle_limpieza` trabaja con `jsonb` (la limpieza desde el móvil no se guardaba). Aplicada en **Test** y en **Producción** (`migration list` del 12-11-2026).
- **`20261112152109_pin_camarero_fase1.sql`** — sesión de camarero con PIN, **fase 1 (modo tolerante)** (spec `docs/specs/2026-11-12-pin-camarero.md`): tablas `camarero_sesiones` y `camarero_llamadas_sin_token`, `fn_staff_exigir_sesion` (grupo C), `fn_camarero_cerrar_sesion` (grupo A), `p_token` en las funciones del camarero, token en `fn_verificar_camarero_pin` y revocación en `fn_resetear_pin_camarero`. Sin token, las funciones hacen la comprobación de antes y anotan la llamada.
  - Aplicada en **Test** y en **Producción** el 12-11-2026 (en Producción, antes de publicar el front de `main`: el front nuevo envía `p_token` y con la BD vieja daría "función no encontrada").
  - Huella de permisos después, igual en Test y Producción: 193 filas, md5 `f81c51b3b13b0770a5cbabd2505f0ac1` (antes `0eb487db5184139d07e719e1a461b76a`).
  - Pruebas: `supabase/tests/pin_camarero_fase1.sql` (criterio 7; solo entre la fase 1 y la 2, o tras revertir la fase 2) y `supabase/tests/pin_camarero.sql` (criterios 1–6; con solo la fase 1 fallan, a propósito, las 20 filas marcadas `[fase 2]`).
- **`20261112162501_pin_camarero_fase2.sql`** — sesión de camarero con PIN, **fase 2 (token obligatorio)**: `fn_staff_exigir_sesion` rechaza el token nulo (RM401) y se borra `camarero_llamadas_sin_token`. Aplicada en **Test** y en **Producción** el 12-11-2026; tras ella `pin_camarero.sql` da 0 fallos de 149. Huella de permisos en Test después: 192 filas, md5 `a99c8f619564ade5f2f131e6fd85fa99` (tras aplicarla en Producción deben coincidir). Vueltas atrás probadas sobre la fase 2 (con `rollback`): la de la fase 2 deja `pin_camarero_fase1.sql` en 0 fallos; la de la fase 1 devuelve la huella a `0eb487db…`. Justo antes del `db push` en Producción, consultar `camarero_llamadas_sin_token` (después ya no existe). En Producción, con clientes reales, solo cuando `camarero_llamadas_sin_token` no tenga llamadas en las últimas 24 h (decisión 2 de la spec).
- **`20261113082049_pin_bloqueo_progresivo.sql`** — bloqueo progresivo del PIN (`fn_verificar_camarero_pin`: 5 min, 30 min, 2 h y 24 h por cada 10 fallos seguidos; el contador vuelve a cero tras 24 h sin fallos contadas desde el último fallo o el fin del último bloqueo) y `fn_resetear_pin_camarero` borra el bloqueo. Mismas firmas y grants; la huella no cambia (`a99c8f61…`). Prueba: `supabase/tests/pin_bloqueo.sql` (antes 5 fallos de 10, después 0). Aplicada en **Test** y en **Producción** el 13-11-2026 (huella `a99c8f61…` en ambos).
- **`20261113082740_pin_bloqueo_concurrencia.sql`** — corrige la anterior: `fn_verificar_camarero_pin` crea la fila de `camarero_pin_intentos` si no existe y la lee con `for update` (los intentos simultáneos de un camarero van de uno en uno; antes K intentos a la vez sumaban 1) y el mensaje de bloqueo pasa a "Espera un rato o pide al encargado que te cambie el PIN". `pin_bloqueo.sql`: 0 fallos de 13. Concurrencia comprobada en Test con dos conexiones (la segunda espera a la primera). Aplicada en **Test** y en **Producción** el 13-11-2026.
  - Vuelta atrás preparada, **no** aplicada: `supabase/rollback/pin_camarero_fase2_revertir.sql` (vuelve al modo tolerante; una función y la tabla de anotaciones) y `supabase/rollback/pin_camarero_fase1_revertir.sql` (repone firmas y cuerpos de antes; **antes** hay que volver a la versión anterior del front en Vercel). Probadas en Test dentro de `begin … rollback`: tras la de fase 1 la huella vuelve a `0eb487db…`. Se aplican como migración, igual que la de permisos mínimos.
- **Agente de WhatsApp, entrega 1a** (spec `docs/specs/2026-11-13-agente-whatsapp-revision.md`): ocho migraciones, aplicadas en **Test** el 13-11-2026. **Pendientes en Producción** (paso 4 del despliegue de la spec; se aplican todas juntas con un `db push`):
  - `20261113114748_agente_errores.sql`: tablas `agente_errores` (en Realtime) y `agente_errores_detalle` (no publicada), con RLS (dueño: avisos visibles de su restaurante; superadmin: todo) y grants mínimos (`authenticated` solo SELECT; `service_role` solo SELECT, INSERT y UPDATE, sin DELETE: no se borra nada, decisión 13). Funciones `fn_agente_registrar_error` (solo `service_role`, agrupa repeticiones de 30 min y tapa claves en el detalle) y `fn_agente_error_marcar_atendida` (dueño de ese restaurante o superadmin; `authenticated` + `service_role`).
  - `20261113114751_pedido_whatsapp_crear.sql`: `orders.clave_whatsapp` con índice único parcial y `fn_pedido_whatsapp_crear` (solo `service_role`): pedido y líneas en una transacción, precio de `fn_carta_takeaway`, topes 20/60/30 y textos, idempotente por clave. Errores `RMP01` (pedido grande), `RMP02` (plato fuera de carta), `RMP03` (datos), `RMP04` (sin take away / inactivo).
  - `20261113114755_reserva_whatsapp_validaciones.sql`: `fn_reserva_whatsapp_crear` valida antelación (15 min, Madrid), horario, personas (1…máximo) y longitudes. Misma firma y grants.
  - `20261113114758_whatsapp_limpieza_sesiones.sql`: **borra datos** en cada mensaje: `fn_whatsapp_mensaje_nuevo` elimina las `whatsapp_sessions` sin actividad en 30 días (no toca pedidos ni reservas).
  - `20261113121550_agente_errores_tipos_entrada.sql`: tipos `numero_desconocido` y `mensajes_multiples` (decisión 6 cambiada); `firma_invalida` y `numero_desconocido` se agrupan en una fila por tipo y media hora, sin restaurante ni teléfono, y solo guardan el detalle de las 5 primeras veces.
  - `20261113164800_pedido_whatsapp_validaciones.sql`: `fn_pedido_whatsapp_crear` rechaza cantidades que no son enteros y horas de recogida pasadas (`RMP03`, después de la clave). El horario de take away no se comprueba en la BD (queda en n8n; anotado para la fase 2).
  - `20261113164803_reserva_whatsapp_idempotente.sql`: `reservations.clave_whatsapp` con índice único parcial y `fn_reserva_whatsapp_crear(…, p_clave)` → json `{id, ya_existia}`: la misma clave devuelve la reserva que ya existe. La versión de 9 argumentos (la del agente actual) se mantiene y llama a la nueva sin clave.
  - `20261113164806_agente_errores_ocultar_sb_secret.sql`: el detalle tapa también las claves `sb_secret_…` de Supabase.
  - Pruebas (todas en Test, con `rollback`): `pedido_whatsapp.sql` 28/28, `reserva_whatsapp_validaciones.sql` 17/17, `reserva_whatsapp_idempotente.sql` 7/7, `agente_errores.sql` 28/28 (incluye 100 repeticiones de `firma_invalida` → `veces = 100`), `whatsapp_limpieza_sesiones.sql` 8/8. Actualizados:
    - `permisos_funciones.sql`: grupo B con `fn_agente_error_marcar_atendida`; grupo C con `fn_pedido_whatsapp_crear` y `fn_agente_registrar_error`;
    - `permisos_tablas.sql`;
    - `permisos_service_role.sql`: excepción sin DELETE en las dos tablas de avisos; 87 funciones no trigger.
  - Huella de permisos en Test: antes 192 filas, md5 `a99c8f619564ade5f2f131e6fd85fa99`; después **198 filas, md5 `5f9df4394dd646e535cf63d5d0363638`**. Hay 6 filas nuevas: `fn_agente_error_marcar_atendida`, `fn_agente_registrar_error`, `fn_pedido_whatsapp_crear`, `fn_reserva_whatsapp_crear(…, p_clave)` y las tablas `agente_errores` y `agente_errores_detalle`. Ninguna otra cambia. Tras aplicarlas en Producción, Producción debe dar el mismo md5.
  - El agente nuevo de n8n llama a estas funciones: **primero `db push` en Producción y después reimportar el agente**. El agente actual sigue funcionando con la BD nueva (`fn_whatsapp_mensaje_nuevo` y la versión de 9 argumentos de `fn_reserva_whatsapp_crear` conservan su firma y su resultado).
  - Pasos de n8n y Meta: ver "Agente de WhatsApp en n8n y Meta" más abajo.
- Desde esta migración los privilegios por defecto están cerrados: toda migración que cree tabla o función debe llevar sus `grant` (ver `docs/FLUJO_DE_TRABAJO.md`).

## Pruebas SQL (`supabase/tests/`)
Solo contra **Test** y dentro de `begin … rollback` (no dejan datos ni objetos). Cada una devuelve filas `prueba | ok | detalle` y una fila `TOTAL`:
```bash
npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/permisos_tablas.sql
```
Para ver solo los fallos, añadir `--output-format json` y filtrar las filas con `"ok": false`.
Excepción: `permisos_huella.sql` es de solo lectura y también se puede ejecutar en Producción con `--read-only` (consulta 1: resumen `filas | md5`; consulta 2: detalle; la CLI muestra el resultado de la última, así que para el resumen se ejecuta la consulta 1 por separado).

## Agente de WhatsApp en n8n y Meta (entrega 1a)
El workflow versionado es `n8n/workflows/restomind_whatsapp_agente.json`, y el de errores es `n8n/workflows/restomind_whatsapp_errores.json`. El enrutador central no se toca ni se versiona aquí. El orden general está en la spec ("Despliegue de la entrega 1a"). Aquí va el detalle con los datos de Meta del 13-11-2026.

**Datos de partida (no son secretos):**
- El número de prueba **no cambia**: +1 555 612 6953, Phone number ID `1461480243709434`, cuenta de WhatsApp (WABA) `1695621985232265`.
- Ese número y su WABA están en el portfolio y ahora los ven las dos apps, PatricioAI y RestomindWapp. Casa Montiel ya tiene ese Phone number ID: **no hay que cambiarlo en superadmin**.
- Hoy la WABA está suscrita a **PatricioAI**, cuyo webhook es el enrutador. El número pasa a ser **solo de Restomind** (decisión de Patricio): al final del despliegue, la WABA solo queda suscrita a **RestomindWapp**.
- n8n corre en un VPS de Hostinger con Docker. En hPanel → Administrador de Docker → proyecto **n8n** (2 contenedores) → Administrar se edita el `docker-compose` y sus variables.

### Paso A. Exportar el agente activo y compararlo
El JSON nuevo se construyó a partir de `n8n-agente-takeaway/restomind_whatsapp_agente_V02.json` (copia del 9-nov, guardada también en `backups/…_BACKUP_pre_revision_1a_20261113.json`). Si alguien cambió el agente en n8n después, reimportar el nuevo borraría ese cambio. Patricio exporta el agente activo y el orquestador compara:
```bash
python3 -c "import json,sys; a,b=[json.load(open(f)) for f in sys.argv[1:]]; k=lambda w: (sorted((n['name'],json.dumps(n['parameters'],sort_keys=True)) for n in w['nodes']), json.dumps(w['connections'],sort_keys=True)); print('IGUALES' if k(a)==k(b) else 'DISTINTOS')" n8n-agente-takeaway/restomind_whatsapp_agente_V02.json <exportación de hoy>.json
```
Si sale **DISTINTOS**, se para. No se importa nada hasta rehacer el JSON nuevo sobre la exportación de hoy.

### Paso B. Migraciones en Producción
Las ocho de la 1a, con `db push` (ver arriba). El agente actual sigue funcionando con ellas.

### Paso C. Variables en el servidor de n8n (Hostinger)
1. hPanel → **Administrador de Docker** → proyecto **n8n** → **Administrar**. En el `docker-compose`, buscar el contenedor de n8n: el que usa la imagen `n8nio/n8n` o `docker.n8n.io/n8nio/n8n`, no el de la base de datos ni el proxy. Buscar su bloque `environment:`, donde ya están `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`.
2. Añadir dos líneas:
   - `META_APP_SECRET_RESTOMIND=` + la "Clave secreta de la app" de RestomindWapp (Meta → la app → Configuración → Básica → Mostrar);
   - `META_VERIFY_TOKEN_RESTOMIND=` + una frase larga que Patricio invente y no use en otro sitio. La vuelve a escribir en Meta en el paso F.

   Se pegan directamente ahí: no van en el chat, en el repositorio ni en el JSON.
3. **Acceso a `$env`.** El agente lee estas variables (y las de Supabase) con `$env`, en nodos de código y en expresiones. En las versiones recientes de n8n, `N8N_BLOCK_ENV_ACCESS_IN_NODE` vale `true` por defecto y bloquea ese acceso. Hoy el agente ya usa `$env.SUPABASE_SERVICE_ROLE_KEY` y funciona, así que en esta instancia el acceso está permitido: por la versión, o porque la variable ya está en `false`. Al editar el `docker-compose`:
   - si aparece `N8N_BLOCK_ENV_ACCESS_IN_NODE`, debe seguir en `false`;
   - si no aparece y se va a actualizar la imagen de n8n en el mismo cambio, añadir `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`. Si no, la firma fallaría siempre (403 a todo) y tampoco funcionarían las llamadas a Supabase.
   - Mejor no actualizar la versión de n8n en este paso.
4. Guardar y volver a desplegar el proyecto. **Aviso: el reinicio corta unos segundos todos los productos de n8n** (Restomind, Facturas e Inmobiliaria). Mejor fuera de horas.
5. Comprobar que n8n vuelve a estar arriba y que el agente actual sigue contestando un "hola".

### Paso D. Credencial, workflow de errores y marcadores
1. **Crear la credencial** "WhatsApp Graph API Token (RestomindWapp)" en n8n: Credenciales → Nueva → "Header Auth", con nombre de cabecera `Authorization` y valor `Bearer ` seguido del token nuevo de `n8n-whatsapp-bot` generado desde RestomindWapp. La credencial antigua "WhatsApp Graph API Token" no se toca. Apuntar el **id** de la nueva: sale en la dirección de la página al abrirla y no es secreto.
2. **Importar el workflow de errores** (`restomind_whatsapp_errores.json`), sin activarlo: n8n lo usa solo. Apuntar su **id**, que también sale en la dirección.
3. En `restomind_whatsapp_agente.json`, el orquestador cambia los dos marcadores por esos ids:
   - `PENDIENTE-CREDENCIAL-RESTOMINDWAPP`, en los dos nodos de envío;
   - `PENDIENTE-ID-WORKFLOW-ERRORES`, en `settings.errorWorkflow`.

   Después comprueba:
   ```bash
   python3 n8n/tests/comprobar_workflow.py --para-importar n8n/workflows/restomind_whatsapp_agente.json
   python3 n8n-agente-takeaway/comprobar_hora_espana.py n8n/workflows/restomind_whatsapp_agente.json
   node n8n/tests/probar_firma.cjs
   ```
   Si no se ponen los ids, al importar n8n puede asignar a los nodos de envío otra credencial del mismo tipo (por ejemplo la de Anthropic).

### Paso E (recomendado). Prueba previa de la firma, sin tocar el agente activo
Comprueba en la instancia real que el nodo Crypto calcula la firma igual que Meta, también con ñ, € y emoji. Hace falta el paso C, porque la copia comprueba que exista `META_APP_SECRET_RESTOMIND` (aunque luego firma con el secreto de prueba).
1. En n8n, importar `restomind_whatsapp_agente.json` como workflow **nuevo**, con el nombre "PRUEBA FIRMA — borrar". **No activarlo**: un workflow sin activar no choca con la ruta del activo, porque solo escucha en `/webhook-test/…` y solo mientras se pulsa "Listen for test event".
2. En esa copia, abrir el nodo **Calcular firma** y, en "Secret", cambiar `{{ $env.META_APP_SECRET_RESTOMIND }}` por una frase de prueba inventada (por ejemplo `prueba-firma-2026`). Es la **única** copia con ese texto, y no se exporta.
3. En el Mac, generar los tres `curl` (el secreto de prueba va en la orden, no en un archivo):
   ```bash
   SECRETO_PRUEBA='prueba-firma-2026' node n8n/tests/curl_firmado.cjs https://n8n.srv1244859.hstgr.cloud/webhook-test/restomind-whatsapp
   ```
4. En la copia, pulsar **"Listen for test event"** en el nodo Webhook1 y lanzar el primer `curl`. Debe salir **200**. En la ejecución se ve que pasa por "¿Firma válida?" (verdadero), "Responder OK" y "Extraer mensaje y contexto", y termina en "Ignorar (sin respuesta)": el número del cuerpo de prueba no es de ningún restaurante, así que no contesta a nadie y anota un `numero_desconocido`.
5. Pulsar otra vez "Listen for test event" y lanzar el segundo `curl` (sin cabecera): debe salir **403** y terminar en "Registrar firma inválida".
6. Igual con el tercero (el cuerpo cambiado en un carácter): **403**.
7. Borrar la copia en n8n y la carpeta temporal que indica el script.

Si el primero da 403, la firma no cuadra en esta instancia. Se para y se revisan el Raw Body, el nodo Crypto y el acceso a `$env` (paso C.3). Es el riesgo "Firma que no cuadra" de la spec.

### Paso F. Importar y activar el agente nuevo
- Importarlo **sobre el mismo workflow**: abrir el agente activo → menú "…" → "Import from File…", que sustituye su contenido. O bien **desactivar antes el agente anterior**. Dos workflows activos con la ruta `restomind-whatsapp` chocan: n8n no deja activar el segundo, o sigue contestando el viejo.
- Comprobar en "Configuración del workflow" que el "Error workflow" es el del paso D.2, y activarlo.
- Desde ese momento el agente solo acepta mensajes firmados por Meta. Los que le sigue reenviando el enrutador (sin firma) se rechazan y quedan anotados como `firma_invalida`. Es esperado hasta el paso H.

### Paso G. Conectar RestomindWapp en Meta
1. En developers.facebook.com → app **RestomindWapp** → WhatsApp → Configuración → **Webhook** → Editar:
   - URL de devolución de llamada: `https://n8n.srv1244859.hstgr.cloud/webhook/restomind-whatsapp`;
   - Token de verificación: la frase del paso C.2;
   - "Verificar y guardar". Meta llama al GET del agente; si no lo acepta, revisar `META_VERIFY_TOKEN_RESTOMIND` y el paso C.3.
2. En "Campos del webhook", **suscribirse a `messages`**.
3. **Suscribir la WABA a RestomindWapp.** Hay que hacerlo explícitamente: configurar el webhook de la app no basta. En el **Explorador de la Graph API** (developers.facebook.com/tools/explorer):
   - arriba a la derecha, en "Aplicación de Meta", elegir **RestomindWapp**;
   - en "Usuario o página", generar un token con el permiso `whatsapp_business_management` (o pegar el token de `n8n-whatsapp-bot` de RestomindWapp en el campo "Token de acceso");
   - en el desplegable del método, elegir **POST**; en el campo de la consulta, escribir `1695621985232265/subscribed_apps`; pulsar **Enviar**. Debe responder `{"success": true}`.
4. **Comprobar:** método **GET**, la misma consulta `1695621985232265/subscribed_apps`, Enviar. Ahora deben salir **las dos** apps, PatricioAI y RestomindWapp.

Mientras estén suscritas las dos, cada mensaje llega dos veces al agente: directo de Meta (con firma, se atiende) y por el enrutador (sin firma, 403 y `firma_invalida`). Es esperado durante esos minutos y el cliente recibe una sola respuesta.

### Paso H. Dejar el número solo para Restomind
1. En el Explorador de la Graph API, cambiar "Aplicación de Meta" a **PatricioAI** y usar un token de PatricioAI con `whatsapp_business_management`. La baja se aplica a la app del token.
2. Método **DELETE**, consulta `1695621985232265/subscribed_apps`, Enviar. Debe responder `{"success": true}`.
3. **Comprobar:** método **GET**, misma consulta, con cualquiera de los dos tokens. **Solo debe salir RestomindWapp.**
4. Desde aquí el enrutador deja de recibir los mensajes de este número, y ya no aparecen filas `firma_invalida` nuevas por cada mensaje.

### Paso I. Probar
Patricio escribe "hola" al +1 555 612 6953 desde su móvil y debe contestar el agente. Después, los criterios 1, 2, 6, 7 y 9 con `n8n/tests/conversaciones.md`.

### Vuelta atrás
1. **Volver a suscribir PatricioAI:** Explorador de la Graph API, app **PatricioAI**, token de PatricioAI, **POST** `1695621985232265/subscribed_apps`.
2. **Quitar RestomindWapp:** app **RestomindWapp**, token de RestomindWapp, **DELETE** `1695621985232265/subscribed_apps`. Comprobar con **GET** que solo sale PatricioAI. Si no se puede, quitar en RestomindWapp → Webhook la suscripción a `messages`, o cambiar la URL.
3. **Reimportar el agente anterior** (la exportación del paso A) sobre el mismo workflow y activarlo.

El Phone number ID de Casa Montiel no se ha tocado y el enrutador no ha cambiado, así que todo vuelve a como estaba. La BD no hace falta tocarla: el agente antiguo funciona con las migraciones nuevas. Las variables del paso C se pueden dejar; no molestan.

### Comprobar el JSON antes de cada importación
`python3 n8n/tests/comprobar_workflow.py`. Sin argumentos revisa `n8n/workflows/`. Con `--probar-fixtures` comprueba que el propio script detecta la clave del fixture y 14 fallos metidos a propósito en una copia del agente (15 casos en total).

## Requisitos en el Mac
- **Docker Desktop abierto** (la CLI lo usa por dentro para `db pull` y para comparar esquemas). Tras instalarlo, abrir una terminal nueva para que encuentre el comando `docker`.
- Sesión iniciada: `npx supabase login` (una vez).
- CLI **v3**: los comandos de base de datos van contra una base **local** salvo que se pase `--remote`. Por eso aquí siempre se escribe `--remote=<ref>` con el proyecto explícito: así nunca hay dudas de si se está tocando Test o Producción.
- Los cambios en un proyecto alojado piden confirmación y la respuesta por defecto es **No**: hay que elegir *Yes* con las flechas.

| Proyecto | Ref |
|---|---|
| Test | `sfkwbhzelrestmrmptql` |
| Producción | `mfxrluanpawfjncpqrvu` |

## Día a día

```bash
npx supabase migration new nombre_descriptivo
# editar supabase/migrations/<ts>_nombre_descriptivo.sql

# 1) Aplicar en TEST
npx supabase db push --remote=sfkwbhzelrestmrmptql --dry-run   # ver qué se va a aplicar
npx supabase db push --remote=sfkwbhzelrestmrmptql
npx supabase migration list --remote=sfkwbhzelrestmrmptql
```

Al pasar a producción (después de validar en la preview de `staging`):

```bash
npx supabase db push --remote=mfxrluanpawfjncpqrvu --dry-run
npx supabase db push --remote=mfxrluanpawfjncpqrvu
npx supabase migration list --remote=mfxrluanpawfjncpqrvu
```

Dejar el proyecto enlazado (`supabase link`) siempre a **Test**: `npx supabase link --project-ref sfkwbhzelrestmrmptql`.

## Reglas para escribir una migración
- Un archivo = un cambio con sentido (no mezclar features).
- Idempotente: `create table if not exists`, `create or replace function`, `drop policy if exists` antes de `create policy`, `add column if not exists`.
- Nunca editar una migración ya aplicada: se crea otra nueva que corrige.
- Grants y Realtime dentro de la propia migración (ver reglas en `CLAUDE.md`).
- Si hay que tocar datos (no solo esquema), dejarlo claro en un comentario al principio.

## Cómo se creó la línea base (referencia)
```bash
npx supabase db pull --remote=mfxrluanpawfjncpqrvu                                  # crea <ts>_remote_schema.sql y la marca aplicada en Producción
npx supabase migration repair --status applied <ts> --remote=sfkwbhzelrestmrmptql   # la marca aplicada en Test
```
