# Flujo de trabajo

Cómo se hace cualquier cambio en Restomind, de la idea a producción.

## 1. Mini especificación (antes de tocar código)
Cinco líneas en el PR o en `docs/BACKLOG.md`:
- **Qué**: la funcionalidad o el fallo, en una frase.
- **Para quién**: dueño, camarero, cocina, cliente en mesa, cliente por WhatsApp, superadmin, vendedor.
- **Criterios de aceptación**: 2–5 comprobaciones concretas ("si el cliente pide X, ve Y").
- **Toca BD**: sí/no. Si sí, qué tablas/funciones.
- **Módulo de pago**: cuál, si aplica.

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

## 5. PR a `staging`
- Título con prefijo: `feat:`, `fix:`, `chore:`, `docs:`.
- Descripción: la mini especificación + cómo probarlo.
- Vercel genera la preview contra Supabase Test → probar los criterios de aceptación ahí.

## 6. Paso a producción
1. Aplicar las migraciones pendientes en Producción (`supabase link` al proyecto de producción → `supabase db push`).
2. Si la tarea toca n8n: importar el workflow actualizado en el n8n de producción.
3. PR `staging` → `main`. Vercel despliega.
4. Prueba rápida en producción con Casa Montiel (restaurante de prueba).

## Checklist de "terminado"
- [ ] Criterios de aceptación probados en la preview de staging
- [ ] `npm run build` sin errores
- [ ] Migración en `supabase/migrations/`, aplicada en Test (y en Producción al pasar a `main`)
- [ ] Tablas nuevas: RLS + políticas + grants mínimos + Realtime si hace falta
- [ ] Funciones nuevas `SECURITY DEFINER`: `search_path` fijo, permisos comprobados, `execute` revocado a quien no deba
- [ ] Asesor de seguridad de Supabase (Test) sin avisos nuevos
- [ ] Workflows de n8n exportados a `n8n/` si cambiaron (sin credenciales)
- [ ] `docs/` actualizado si cambia la arquitectura o se toma una decisión relevante
