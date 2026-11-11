# Backlog

Orden aproximado de prioridad. Cada tarea, al empezar, se convierte en mini especificación (ver `FLUJO_DE_TRABAJO.md`).

## Harness
- [x] Fase 1 — Diagnóstico (`docs/diagnostico-2026-11-11.md`)
- [x] Fase 2 — Base: documentación, migraciones (línea base `20261111193648` en Test y Producción)
- [ ] Fase 2b — n8n versionado (pendiente de los JSON exportados)
- [ ] Fase 3 — Red de seguridad (**antes del piloto**): ESLint, Vitest (`npm test`) en lógica crítica (`money.js`, `fechas.js`, `horarioReservas.js`), carpetas `supabase/tests/` y `n8n/tests/`, GitHub Actions (build + lint + test en cada PR)
- [ ] Fase 5 — Plantilla reutilizable para otros proyectos
- [ ] Futuro — Quinto agente `tester` cuando crezca la complejidad (criterios en `docs/decisiones/0002-cuatro-agentes.md`)

## Restomind
- [ ] **SEGURIDAD (prioridad alta) — funciones del camarero sin PIN.** `fn_staff_tiene_permiso` solo comprueba que el id de camarero exista y tenga el permiso; no el PIN. `fn_listar_camareros_nombres` da esos ids a cualquiera con el id del restaurante (está en la URL de `/camarero/...`). Con eso, sin PIN, se puede llamar a `fn_staff_listar_clientes` (teléfonos y puntos), `fn_staff_canjear_puntos`, `fn_staff_cambiar_estado_*`, etc. `fn_camarero_listar_sesiones` no comprueba nada y devuelve teléfonos de clientes de mesas abiertas. Solución propuesta: token de sesión de camarero emitido al validar el PIN y exigido por todas las `fn_staff_*` / `fn_camarero_*`. Verificado en Producción el 11-11-2026. Va justo después de la tarea de permisos mínimos.
- [ ] **Piloto del harness — Agente de WhatsApp (take away y reservas):** revisar estabilidad, seguridad y contexto para responder más preguntas de los clientes. Necesita los workflows exportados de n8n.
- [ ] **Zona horaria por restaurante** (obligatorio antes del primer cliente fuera de España peninsular — Canarias incluida): columna `restaurants.zona_horaria` (IANA, por defecto `Europe/Madrid`, propuesta según `pais` pero editable porque México o EE. UU. tienen varias), funciones SQL `fn_*_restaurante(restaurant_id)`, `fechas.js` con la zona como parámetro y n8n con la zona del restaurante. Afecta a unas 17 funciones SQL (reservas, `fn_menu_activo`, `fn_registrar_pedido`, vales…) y ~15 archivos del front. Lo de facturación/CRM de Restomind sigue en hora de España.
- [ ] **En curso** — Permisos mínimos iguales en Test y Producción: `docs/specs/2026-11-11-permisos-minimos.md` (rama `fix/igualar-permisos`). Aparte: aclarar `fn_disparar_webhooks`.
- [ ] Avisos del asesor: `search_path` en `fn_marcar_timestamp_estado_pedido`, extensión en `public`, protección de contraseñas filtradas.
- [ ] Trocear las páginas más grandes cuando se toquen (no como tarea aislada).
