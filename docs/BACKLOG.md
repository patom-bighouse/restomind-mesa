# Backlog

Orden aproximado de prioridad. Cada tarea, al empezar, se convierte en mini especificación (ver `FLUJO_DE_TRABAJO.md`).

## Harness
- [x] Fase 1 — Diagnóstico (`docs/diagnostico-2026-11-11.md`)
- [ ] Fase 2 — Base: documentación, migraciones (línea base pendiente de `supabase db pull`), n8n versionado
- [ ] Fase 3 — Red de seguridad: ESLint, Vitest en lógica crítica (`money.js`, `fechas.js`, `horarioReservas.js`), GitHub Actions (build + lint + test en cada PR)
- [ ] Fase 5 — Plantilla reutilizable para otros proyectos

## Restomind
- [ ] **Piloto del harness — Agente de WhatsApp (take away y reservas):** revisar estabilidad, seguridad y contexto para responder más preguntas de los clientes. Necesita los workflows exportados de n8n.
- [ ] Igualar permisos de Producción con Test (migración de endurecimiento de grants) y aclarar `fn_disparar_webhooks`.
- [ ] Avisos del asesor: `search_path` en `fn_marcar_timestamp_estado_pedido`, extensión en `public`, protección de contraseñas filtradas.
- [ ] Trocear las páginas más grandes cuando se toquen (no como tarea aislada).
