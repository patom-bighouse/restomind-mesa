# Diagnóstico — 11 de noviembre de 2026

Revisión del repositorio y de los dos proyectos de Supabase (solo lectura).

## Diferencias Test / Producción
Comparadas columnas, funciones, políticas RLS, triggers, publicación Realtime y grants del esquema `public`.

- **Columnas, políticas, triggers y Realtime: idénticos.**
- **Funciones:** mismo código en todas salvo:
  - `fn_disparar_webhooks(uuid,text,jsonb)`: el código es distinto entre Test y Producción. Revisar cuál es la buena.
  - `rls_auto_enable()`: existe solo en Test.
- **Permisos: Producción es bastante más permisiva que Test.**
  - 79 grants de tabla a `anon`/`authenticated` que existen en Producción y no en Test (p. ej. `anon` con INSERT/UPDATE/DELETE en `planes`, `crm_config`, `crm_busquedas`, `restaurant_info`, `promos_sellos`, `clientes_sellos`, `whatsapp_mensajes_procesados`, `camarero_pin_intentos`).
  - En casi todas las funciones, Producción concede EXECUTE a `PUBLIC`/`anon`; en Test no (endurecimiento que se aplicó en Test y nunca llegó a Producción).
  - Mitigación actual: todas las tablas tienen RLS activado y las funciones de administración comprobadas (`fn_aplicar_descuento`, `fn_asignar_modulo_a_plan`, `fn_crear_camarero`, `fn_iniciar_trial`, `fn_limpiar_*`, `fn_resetear_pin_camarero`) verifican superadmin/`auth.uid()` por dentro. **No se ha visto un agujero explotable**, pero la defensa depende de una sola capa.

## Asesor de seguridad de Supabase (Producción)
- 73 funciones `SECURITY DEFINER` ejecutables por `anon` y 88 por `authenticated` (muchas intencionadas: mesa, camarero por PIN, reservas web).
- `fn_marcar_timestamp_estado_pedido` sin `search_path` fijo.
- Una extensión instalada en `public`.
- 4 tablas con RLS sin políticas (`camarero_pin_intentos`, `whatsapp_mensajes_procesados`, `whatsapp_sessions`, `router.clientes_cache`): correcto si solo las usa `service_role`/funciones, pero conviene documentarlo.
- Protección de contraseñas filtradas desactivada (Auth).

## Repositorio
- Sin lint, tests ni CI; único script útil: `build`.
- Workflows de n8n fuera del repo (`n8n-agente-takeaway/` en `.gitignore`).
- 10 scripts SQL históricos no idempotentes.
- Páginas muy grandes: `Camarero.jsx` (1.694 líneas), `Mesa.jsx` (1.641), `AdminCarta.jsx` (1.496), `AdminDashboard.jsx` (1.217), `SuperAdminRestaurantes.jsx` (1.065).
