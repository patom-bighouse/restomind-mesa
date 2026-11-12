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
  - Vuelta atrás preparada, **no** aplicada: `supabase/rollback/pin_camarero_fase2_revertir.sql` (vuelve al modo tolerante; una función y la tabla de anotaciones) y `supabase/rollback/pin_camarero_fase1_revertir.sql` (repone firmas y cuerpos de antes; **antes** hay que volver a la versión anterior del front en Vercel). Probadas en Test dentro de `begin … rollback`: tras la de fase 1 la huella vuelve a `0eb487db…`. Se aplican como migración, igual que la de permisos mínimos.
- Desde esta migración los privilegios por defecto están cerrados: toda migración que cree tabla o función debe llevar sus `grant` (ver `docs/FLUJO_DE_TRABAJO.md`).

## Pruebas SQL (`supabase/tests/`)
Solo contra **Test** y dentro de `begin … rollback` (no dejan datos ni objetos). Cada una devuelve filas `prueba | ok | detalle` y una fila `TOTAL`:
```bash
npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/permisos_tablas.sql
```
Para ver solo los fallos, añadir `--output-format json` y filtrar las filas con `"ok": false`.
Excepción: `permisos_huella.sql` es de solo lectura y también se puede ejecutar en Producción con `--read-only` (consulta 1: resumen `filas | md5`; consulta 2: detalle; la CLI muestra el resultado de la última, así que para el resumen se ejecuta la consulta 1 por separado).

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
