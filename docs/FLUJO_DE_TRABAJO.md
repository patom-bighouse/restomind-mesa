# Flujo de trabajo

Cómo se hace cualquier cambio en Restomind, de la idea a producción.

Quién hace cada paso: ver "4 agentes" en `CLAUDE.md` (orquestador, `spec`, `implementador`, `revisor`).

## 1. Especificación (antes de tocar código) — agente `spec`
Archivo `docs/specs/AAAA-MM-DD-<nombre>.md` con: qué y para quién, criterios de aceptación comprobables, fuera de alcance, impacto técnico (front, BD, n8n, módulo de pago), riesgos y preguntas abiertas.
**Patricio la aprueba** antes de seguir. En tareas pequeñas se puede saltar este paso.

## 2. Rama
```bash
git checkout staging && git pull
git checkout -b feature/<nombre-corto>     # o fix/<nombre-corto>
```

## 3. Base de datos (si aplica)
Ver `docs/MIGRACIONES.md`. Resumen:
```bash
npx supabase migration new <nombre>        # crea supabase/migrations/<timestamp>_<nombre>.sql
# escribir el SQL (idempotente: if not exists / or replace / drop ... if exists)
npx supabase db push --linked              # con el proyecto de TEST enlazado
```

## 4. Código
- Seguir las reglas fijas de `CLAUDE.md`.
- `npm run build` debe pasar.

## 4b. Revisión — agente `revisor`
Siempre, también en tareas pequeñas. Si el veredicto es "CAMBIOS NECESARIOS", vuelve al `implementador` con el informe y se revisa otra vez.

## 5. PR a `staging` — orquestador
- Título con prefijo: `feat:`, `fix:`, `chore:`, `docs:`.
- Descripción: la mini especificación + cómo probarlo.
- Vercel genera la preview contra Supabase Test → probar los criterios de aceptación ahí.

## 6. Paso a producción
1. Aplicar las migraciones pendientes en Producción (`supabase link` al proyecto de producción → `supabase db push`).
2. Si la tarea toca n8n: importar el workflow actualizado en el n8n de producción.
3. PR `staging` → `main`. Vercel despliega.
4. Prueba rápida en producción con Casa Montiel (restaurante de prueba).

## Checklist de "terminado"
- [ ] Cada criterio de aceptación tiene su prueba (auto, sql, conversación o manual) y pasa
- [ ] `npm run build` y `npm test` sin errores, ejecutados también por el `revisor`
- [ ] Criterios manuales validados por Patricio en la preview de staging
- [ ] Migración en `supabase/migrations/`, aplicada en Test (y en Producción al pasar a `main`)
- [ ] Tablas nuevas: RLS + políticas + grants mínimos + Realtime si hace falta
- [ ] Funciones nuevas `SECURITY DEFINER`: `search_path` fijo, permisos comprobados, `execute` revocado a quien no deba
- [ ] Asesor de seguridad de Supabase (Test) sin avisos nuevos
- [ ] Workflows de n8n exportados a `n8n/` si cambiaron (sin credenciales)
- [ ] `docs/` actualizado si cambia la arquitectura o se toma una decisión relevante
