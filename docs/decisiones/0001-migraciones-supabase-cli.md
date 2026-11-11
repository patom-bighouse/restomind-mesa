# 0001 — Migraciones con la CLI de Supabase

- **Fecha:** 2026-11-11
- **Estado:** aceptada

## Contexto
Hasta ahora cada cambio de esquema era un `.sql` en `sql/` que se pegaba a mano en el editor de Supabase, primero en Test y luego en Producción. Ninguna de las dos bases registraba qué se había aplicado (historial de migraciones vacío). El diagnóstico del 11-11-2026 encontró diferencias reales entre Test y Producción (permisos y una función).

## Decisión
- Los cambios de esquema nuevos van en `supabase/migrations/` y se aplican con `supabase db push`.
- La línea base es el esquema actual de Producción (`supabase db pull`).
- `sql/` pasa a `sql/historico/`, de solo lectura.

## Consecuencias
- Cada base de datos sabe qué tiene aplicado (`supabase migration list`).
- Hace falta la CLI y la contraseña de la BD de cada proyecto en el Mac.
- Abre la puerta a comprobar en CI que las migraciones se aplican sin error.
