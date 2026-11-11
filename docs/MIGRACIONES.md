# Migraciones de base de datos

Desde noviembre de 2026 todos los cambios de esquema van en `supabase/migrations/` y se aplican con la CLI de Supabase. Así cada base de datos (Test y Producción) sabe qué migraciones tiene aplicadas, y se acaba el "¿esto lo ejecuté en Producción?".

Los scripts anteriores están en `sql/historico/`: se aplicaron a mano desde el editor de Supabase. Se conservan como referencia; **no** se vuelven a ejecutar.

## Puesta en marcha (una sola vez, en tu Mac)

Necesitas la contraseña de la base de datos de cada proyecto (Supabase → Project Settings → Database). Si no la recuerdas, se puede restablecer ahí mismo.

```bash
npx supabase login                                    # abre el navegador

# 1) Línea base desde PRODUCCIÓN (la fuente de verdad)
npx supabase link --project-ref mfxrluanpawfjncpqrvu
npx supabase db pull                                  # crea supabase/migrations/<ts>_remote_schema.sql
                                                      # y la marca como aplicada en Producción
# 2) Marcar esa misma línea base como aplicada en TEST
npx supabase link --project-ref sfkwbhzelrestmrmptql
npx supabase migration repair --status applied <ts>   # <ts> = el número del archivo creado en el paso 1

git add supabase/migrations && git commit -m "chore: línea base del esquema de producción"
```

> Antes del paso 2, conviene igualar los permisos de Test y Producción: ver "Diferencias Test/Producción" en `docs/diagnostico-2026-11-11.md`.

## Día a día

```bash
npx supabase link --project-ref sfkwbhzelrestmrmptql   # TEST
npx supabase migration new nombre_descriptivo
# editar supabase/migrations/<ts>_nombre_descriptivo.sql
npx supabase db push                                   # aplica en Test lo pendiente
npx supabase migration list                            # qué está aplicado y qué no
```

Al pasar a producción:

```bash
npx supabase link --project-ref mfxrluanpawfjncpqrvu   # PRODUCCIÓN
npx supabase db push
npx supabase link --project-ref sfkwbhzelrestmrmptql   # volver a Test por seguridad
```

## Reglas para escribir una migración
- Un archivo = un cambio con sentido (no mezclar features).
- Idempotente: `create table if not exists`, `create or replace function`, `drop policy if exists` antes de `create policy`, `add column if not exists`.
- Nunca editar una migración ya aplicada: se crea otra nueva que corrige.
- Grants y Realtime dentro de la propia migración (ver reglas en `CLAUDE.md`).
- Si hay que tocar datos (no solo esquema), dejarlo claro en un comentario al principio.
