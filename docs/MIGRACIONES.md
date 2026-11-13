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
- **Agente de WhatsApp, entrega 1a** (spec `docs/specs/2026-11-13-agente-whatsapp-revision.md`). Cuatro migraciones de BD más una corrección, aplicadas en **Test** el 13-11-2026. **Pendientes en Producción** (paso 4 del despliegue de la spec):
  - `20261113114748_agente_errores.sql`: tablas `agente_errores` (en Realtime) y `agente_errores_detalle` (no publicada), con RLS (dueño: avisos visibles de su restaurante; superadmin: todo) y grants mínimos (`authenticated` solo SELECT; `service_role` solo SELECT, INSERT y UPDATE, sin DELETE: no se borra nada, decisión 13). Funciones `fn_agente_registrar_error` (solo `service_role`, agrupa repeticiones de 30 min y tapa claves en el detalle) y `fn_agente_error_marcar_atendida` (dueño de ese restaurante o superadmin; `authenticated` + `service_role`).
  - `20261113114751_pedido_whatsapp_crear.sql`: `orders.clave_whatsapp` con índice único parcial y `fn_pedido_whatsapp_crear` (solo `service_role`): pedido y líneas en una transacción, precio de `fn_carta_takeaway`, topes 20/60/30 y textos, idempotente por clave. Errores `RMP01` (pedido grande), `RMP02` (plato fuera de carta), `RMP03` (datos), `RMP04` (sin take away / inactivo).
  - `20261113114755_reserva_whatsapp_validaciones.sql`: `fn_reserva_whatsapp_crear` valida antelación (15 min, Madrid), horario, personas (1…máximo) y longitudes. Misma firma y grants.
  - `20261113114758_whatsapp_limpieza_sesiones.sql`: **borra datos** en cada mensaje: `fn_whatsapp_mensaje_nuevo` elimina las `whatsapp_sessions` sin actividad en 30 días (no toca pedidos ni reservas).
  - `20261113121550_agente_errores_tipos_entrada.sql`: corrige la primera tras el cambio de la decisión 6: tipos `numero_desconocido` y `mensajes_multiples`; `firma_invalida` y `numero_desconocido` se agrupan en una fila por tipo y media hora, sin restaurante ni teléfono, y solo guardan el detalle de las 5 primeras veces.
  - Pruebas (todas en Test, con `rollback`): `pedido_whatsapp.sql` 24/24, `reserva_whatsapp_validaciones.sql` 17/17, `agente_errores.sql` 28/28, `whatsapp_limpieza_sesiones.sql` 8/8; `permisos_funciones.sql`, `permisos_tablas.sql` y `permisos_service_role.sql` actualizados (grupo B: `fn_agente_error_marcar_atendida`; grupo C: `fn_pedido_whatsapp_crear` y `fn_agente_registrar_error`; excepción sin DELETE en las dos tablas de avisos; 86 funciones no trigger).
  - Huella de permisos en Test: antes 192 filas, md5 `a99c8f619564ade5f2f131e6fd85fa99`; después **197 filas, md5 `afde6bb23c96f9edbd87cf55e2cf29ea`**. Las 5 filas nuevas son exactamente las 3 funciones y las 2 tablas nuevas; ninguna otra cambia. Tras aplicarlas en Producción, Producción debe dar el mismo md5.
  - El agente nuevo de n8n llama a estas funciones: **primero `db push` en Producción y después reimportar el agente**. El agente actual sigue funcionando con la BD nueva (no usa nada nuevo y `fn_whatsapp_mensaje_nuevo` y `fn_reserva_whatsapp_crear` conservan la firma).
  - Pasos de n8n: ver "Agente de WhatsApp en n8n" más abajo.
- Desde esta migración los privilegios por defecto están cerrados: toda migración que cree tabla o función debe llevar sus `grant` (ver `docs/FLUJO_DE_TRABAJO.md`).

## Pruebas SQL (`supabase/tests/`)
Solo contra **Test** y dentro de `begin … rollback` (no dejan datos ni objetos). Cada una devuelve filas `prueba | ok | detalle` y una fila `TOTAL`:
```bash
npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/permisos_tablas.sql
```
Para ver solo los fallos, añadir `--output-format json` y filtrar las filas con `"ok": false`.
Excepción: `permisos_huella.sql` es de solo lectura y también se puede ejecutar en Producción con `--read-only` (consulta 1: resumen `filas | md5`; consulta 2: detalle; la CLI muestra el resultado de la última, así que para el resumen se ejecuta la consulta 1 por separado).

## Agente de WhatsApp en n8n (entrega 1a)
El workflow versionado es `n8n/workflows/restomind_whatsapp_agente.json`, y el de errores es `n8n/workflows/restomind_whatsapp_errores.json`. El enrutador central no se toca ni se versiona aquí. El orden completo del despliegue está en la spec, en "Despliegue de la entrega 1a". Estos son los pasos de n8n de ese orden (el 5 y el 6), explicados sin tecnicismos:

1. **Guardar los dos secretos en el servidor de n8n** como variables de entorno, igual que ya está `SUPABASE_SERVICE_ROLE_KEY`:
   - `META_APP_SECRET_RESTOMIND`: la "Clave secreta de la app" de RestomindWapp;
   - `META_VERIFY_TOKEN_RESTOMIND`: la frase que inventa Patricio para la verificación.

   No se escriben en el chat, en el repositorio ni en el JSON. Puede hacer falta reiniciar n8n, lo que corta unos segundos Facturas e Inmobiliaria: mejor fuera de horas.
2. **Crear la credencial** "WhatsApp Graph API Token (RestomindWapp)" en n8n (Credenciales → Nueva → "Header Auth"; nombre de cabecera `Authorization`, valor `Bearer ` seguido del token nuevo). La credencial antigua "WhatsApp Graph API Token" no se toca. Apuntar el **id** de la credencial nueva: aparece en la dirección de la página al abrirla y no es secreto.
3. **Importar el workflow de errores** (`restomind_whatsapp_errores.json`), sin activarlo: n8n lo usa solo. Apuntar su **id**, que también sale en la dirección.
4. En `restomind_whatsapp_agente.json`, el orquestador cambia los dos marcadores por esos ids:
   - `PENDIENTE-CREDENCIAL-RESTOMINDWAPP`, en los dos nodos de envío;
   - `PENDIENTE-ID-WORKFLOW-ERRORES`, en `settings.errorWorkflow`.

   Después comprueba:
   ```bash
   python3 n8n/tests/comprobar_workflow.py --para-importar n8n/workflows/restomind_whatsapp_agente.json
   python3 n8n-agente-takeaway/comprobar_hora_espana.py n8n/workflows/restomind_whatsapp_agente.json
   node n8n/tests/probar_firma.cjs
   ```
   Si no se ponen los ids, al importar n8n puede asignar a los nodos de envío otra credencial del mismo tipo (por ejemplo la de Anthropic).
5. **Antes de importar**, comprobar en n8n que el nodo **Crypto** existe y acepta la acción *Hmac* con SHA256. Si no, avisar: la alternativa (`require('crypto')`) necesita `NODE_FUNCTION_ALLOW_BUILTIN=crypto` en el servidor.
6. **Importar el agente**, comprobar en "Configuración del workflow" que el "Error workflow" es el del paso 3, y activarlo (paso 6 del despliegue). Desde ese momento solo acepta mensajes firmados por Meta.
7. Después vienen los pasos 7-9 del despliegue: Patricio conecta el webhook en Meta, pone el Phone number ID nuevo en Casa Montiel y escribe "hola".

**Comprobar el JSON antes de cada importación:** `python3 n8n/tests/comprobar_workflow.py` (sin argumentos revisa `n8n/workflows/`; con `--probar-fixtures` comprueba que el propio script detecta claves y 12 fallos metidos a propósito).

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
