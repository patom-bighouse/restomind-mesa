# Migraciones de base de datos

Desde noviembre de 2026 todos los cambios de esquema van en `supabase/migrations/` y se aplican con la CLI de Supabase. Cada base de datos (Test y Producción) registra qué migraciones tiene aplicadas.

Los scripts anteriores están en `sql/historico/`: se aplicaron a mano desde el editor de Supabase. Se conservan como referencia; **no** se vuelven a ejecutar.

## Estado
- **Línea base:** `20261111193648_remote_schema.sql` — esquema de Producción del 11-11-2026 (`db pull`). Registrada como aplicada en Producción y en Test.
- Ojo: Test tenía entonces permisos más estrictos que Producción (ver `docs/diagnostico-2026-11-11.md`). La primera migración posterior los iguala.

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
