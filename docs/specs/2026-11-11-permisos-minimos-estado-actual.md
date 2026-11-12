# Anexo: estado de permisos antes de la migración (leído de Test y Producción el 11-11-2026)

Ámbito: esquema `public`. Roles: `anon` (web pública: Mesa por QR, Reservar, Camarero/Cocina por PIN — el personal NO usa Supabase Auth), `authenticated` (dueño, superadmin, vendedor CRM), `service_role` (n8n del agente de WhatsApp y Edge Functions), `PUBLIC` (=todos).
Todas las tablas tienen RLS activado en ambos entornos. Políticas, columnas, triggers y Realtime son idénticos en ambos.

## Grants de TABLA

### Producción
- `service_role`: todos los privilegios en todas las tablas.
- `authenticated`: todos los privilegios (SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER) en todas las tablas.
- `anon`, todos los privilegios en: camarero_pin_intentos, clientes_sellos, crm_busquedas, crm_config, planes, promos_sellos, restaurant_info, whatsapp_mensajes_procesados.
- `anon` en restaurants y tables: INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER a nivel de tabla (sin SELECT de tabla) + SELECT por columnas:
  - restaurants: id, nombre, logo_url, activo, config, direccion, moneda, slug, subdominio, whatsapp
  - tables: id, restaurant_id, numero, zona, capacidad, activa, necesita_limpieza, limpieza_progreso
- `anon` SELECT en carta: categories, categoria_traducciones, menu_items, menu_item_traducciones, menu_item_modificador_grupos, menu_item_modificador_precios, menu_item_precios_menu, menus, modificador_grupos, modificador_grupo_traducciones, modificador_opciones, modificador_opcion_traducciones, upsell_rules, upsell_traducciones, limpieza_pasos.
- `anon` INSERT en waiter_calls.
- Privilegios por defecto (tablas/funciones nuevas creadas por postgres): todo a anon, authenticated y service_role (lo estándar de Supabase).

### Test (diferencias)
- **`service_role` NO tiene SELECT/INSERT/UPDATE/DELETE en NINGUNA tabla** (solo REFERENCES/TRIGGER/TRUNCATE). Con esto n8n y las Edge Functions no podrían leer ni escribir en Test. Probablemente efecto colateral de un script de endurecimiento: Test NO es un estado "correcto" que copiar tal cual.
- `anon`: solo SELECT en carta + limpieza_pasos, SELECT en planes, INSERT en waiter_calls; en restaurants/tables igual que Producción (INSERT/UPDATE/DELETE de tabla + SELECT por columnas). Restos de REFERENCES/TRIGGER/TRUNCATE en camarero_pin_intentos, clientes_sellos, crm_busquedas, crm_config, promos_sellos, restaurant_info, whatsapp_mensajes_procesados.
- `authenticated` reducido en: clientes (sin DELETE), clientes_movimientos (INSERT, SELECT), clientes_sellos (SELECT), condiciones_aceptaciones (SELECT), crm_busquedas (nada), crm_config (nada), crm_historial (SELECT), modulos (SELECT), order_deliveries (sin DELETE), order_item_modificadores (INSERT, SELECT), order_sector_confirmaciones (sin DELETE), resenas (SELECT), restaurant_modulos (sin DELETE), stock_movimientos (INSERT, SELECT), vale_movimientos (SELECT), vales_regalo (sin DELETE), webhook_entregas (SELECT), whatsapp_mensajes_procesados (nada). Resto: todo.
- Privilegios por defecto de postgres en Test: tablas nuevas → anon/authenticated/service_role solo DELETE/TRUNCATE/REFERENCES/TRIGGER (sin SELECT/INSERT/UPDATE); funciones nuevas → solo postgres.

Nota: TRUNCATE/REFERENCES/TRIGGER no son alcanzables desde la API REST, pero son higiene.

## EXECUTE en FUNCIONES (public)

### Producción
- Casi todas: PUBLIC + anon + authenticated + service_role. Incluye funciones de administración que comprueban superadmin por dentro: fn_asignar_modulo_a_plan, fn_iniciar_trial, fn_aplicar_descuento, fn_limpiar_trial, fn_limpiar_descuento, fn_crear_camarero, fn_resetear_pin_camarero (anon puede ejecutarlas; la función rechaza si no es superadmin/dueño).
- Solo authenticated + service_role: fn_mi_restaurante, fn_es_superadmin, fn_mi_vendedor_id, fn_crm_* (cuenta_puede_ver, importar_restaurantes, restaurantes_cuentas, generar_comisiones, cuota_restaurante, permanencias, vendedor_cambiar_password, puede_buscar, uso_places, duplicados, registrar_busqueda, busquedas_recientes, busqueda_cargar), fn_condiciones_pendientes, fn_aceptar_condiciones, fn_permanencia_penalizacion, fn_dar_baja_restaurante, fn_asignar_plan, fn_actualizar_precio_contrato.
- Solo service_role: fn_whatsapp_mensaje_nuevo, fn_reserva_contexto_cliente, fn_reserva_cliente_cancelar, fn_reserva_cliente_modificar, fn_reserva_cliente_bloquear, fn_disparar_webhooks.
- Funciones de trigger (no necesitan EXECUTE de nadie para dispararse): fn_validar_modulo_pedido, fn_asegurar_sector_confirmacion, fn_otorgar_puntos_fidelizacion, fn_otorgar_puntos_mesa, fn_marcar_timestamp_estado_pedido, fn_bloquear_si_restaurante_inactivo, set_updated_at, fn_crm_cuentas_antes/despues, fn_crm_actividades_antes/despues, force_zero_total_on_mesa_insert, recalc_order_total, fn_trigger_webhook_* (4), fn_activar_modulo_nucleo, fn_restaurants_permanencia_alta, fn_restaurants_proteger_comercial, fn_restaurants_proteger_comercial_alta, fn_trg_normalizar_telefono_cliente. En Producción todas ejecutables por todos.

### Test (diferencias)
- `service_role` sin EXECUTE en casi todo (solo conserva fn_whatsapp_mensaje_nuevo, fn_reserva_contexto/cancelar/modificar/bloquear, fn_info_restaurante_publica).
- Funciones de administración: solo authenticated (sin anon). Correcto.
- Funciones de trigger: EXECUTE vacío (nadie). Correcto.
- **fn_registrar_pedido, get_session_orders, fn_procesar_sellos, fn_reserva_fuera_de_horario: EXECUTE vacío (nadie)** — si la web (anon) o n8n las llaman por RPC, en Test fallarían. Verificar en `src/` con `.rpc(`.
- fn_disparar_webhooks: solo postgres; además su CÓDIGO es distinto entre Test y Producción.
- `rls_auto_enable()` existe solo en Test.

## Otros avisos del asesor de seguridad (Producción)
- fn_marcar_timestamp_estado_pedido sin search_path fijo.
- Extensión pg_net instalada en el esquema public.
- Protección de contraseñas filtradas desactivada (Auth, no es SQL).

## Desconocido
- Qué tablas/funciones usa n8n con service_role: los workflows aún no están en el repo. Por defecto service_role es el rol de backend de Supabase (ignora RLS) y debe tener acceso completo.
