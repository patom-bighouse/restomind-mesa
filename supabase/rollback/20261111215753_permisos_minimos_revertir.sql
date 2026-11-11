-- =============================================================================
-- VUELTA ATRÁS de supabase/migrations/20261111215753_permisos_minimos.sql
--
-- NO es una migración: no está en supabase/migrations/ a propósito, para que
-- `db push` no la aplique. Solo se usa si, tras aplicar permisos_minimos en
-- Producción, algo deja de funcionar (Riesgo 1 de
-- docs/specs/2026-11-11-permisos-minimos.md).
--
-- Repone EXACTAMENTE los grants que tenía Producción (mfxrluanpawfjncpqrvu)
-- el 11-11-2026 antes de la migración. Generado a partir de la salida de
-- supabase/tests/permisos_huella.sql (consulta 2, solo lectura) en Producción.
-- Huella de Producción antes de la migración: 190 filas,
-- md5 21ebb850fcf9ba425bd22a0849a6d229. Tras ejecutar este script, la huella
-- de Producción debe volver a dar ese md5.
--
-- NO TOCA DATOS. No revoca nada a postgres. Deja el search_path de
-- fn_marcar_timestamp_estado_pedido() como lo dejó la migración (es inocuo).
--
-- Cómo aplicarlo (lo decide Patricio; siempre como migración, regla 1 de
-- CLAUDE.md; nunca con `db query` ni SQL suelto en Producción):
--   1. npx supabase migration new revertir_permisos_minimos
--      y copiar este archivo en supabase/migrations/<ts nuevo>_revertir_permisos_minimos.sql
--      QUITANDO las líneas `begin;` y `commit;` (db push ya va en transacción).
--   2. Aplicarla primero en Test:
--        npx supabase db push --remote=sfkwbhzelrestmrmptql --dry-run
--        npx supabase db push --remote=sfkwbhzelrestmrmptql
--   3. Después en Producción:
--        npx supabase db push --remote=mfxrluanpawfjncpqrvu --dry-run
--        npx supabase db push --remote=mfxrluanpawfjncpqrvu
--   4. Comprobar con supabase/tests/permisos_huella.sql (--read-only) que
--      Producción vuelve a dar el md5 de arriba.
-- =============================================================================
begin;

-- 1. Quitar todo lo que haya ahora a PUBLIC/anon/authenticated/service_role -------
do $$
declare r record;
begin
  for r in
    select c.oid::regclass as obj from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p','v','m','f')
      and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  loop
    execute format('revoke all on table %s from public, anon, authenticated, service_role', r.obj);
  end loop;

  for r in
    select c.oid::regclass as obj, string_agg(quote_ident(a.attname), ', ') as cols
    from pg_class c
    join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped and a.attacl is not null
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p','v','m','f')
      and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
    group by c.oid
  loop
    execute format('revoke all (%s) on table %s from public, anon, authenticated, service_role', r.cols, r.obj);
  end loop;

  for r in
    select p.oid::regprocedure as fn from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname <> 'rls_auto_enable'
      and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke all on routine %s from public, anon, authenticated, service_role', r.fn);
  end loop;
end
$$;

-- 2. Esquema ----------------------------------------------------------------------
grant usage on schema public to public, anon, authenticated, service_role;

-- 3. Tablas -----------------------------------------------------------------------
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.camarero_pin_intentos to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.camarero_pin_intentos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.camarero_pin_intentos to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.camareros to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.camareros to service_role;
grant select on table public.categoria_traducciones to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.categoria_traducciones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.categoria_traducciones to service_role;
grant select on table public.categories to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.categories to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.categories to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.clientes to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.clientes to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.clientes_movimientos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.clientes_movimientos to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.clientes_sellos to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.clientes_sellos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.clientes_sellos to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.condiciones_aceptaciones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.condiciones_aceptaciones to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_actividades to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_actividades to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_busquedas to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_busquedas to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_busquedas to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_comisiones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_comisiones to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_config to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_config to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_config to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_cuentas to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_cuentas to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_historial to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_historial to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_tareas to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.crm_tareas to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.ingredientes to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.ingredientes to service_role;
grant select on table public.limpieza_pasos to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.limpieza_pasos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.limpieza_pasos to service_role;
grant select on table public.menu_item_modificador_grupos to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_item_modificador_grupos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_item_modificador_grupos to service_role;
grant select on table public.menu_item_modificador_precios to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_item_modificador_precios to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_item_modificador_precios to service_role;
grant select on table public.menu_item_precios_menu to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_item_precios_menu to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_item_precios_menu to service_role;
grant select on table public.menu_item_traducciones to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_item_traducciones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_item_traducciones to service_role;
grant select on table public.menu_items to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_items to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menu_items to service_role;
grant select on table public.menus to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menus to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.menus to service_role;
grant select on table public.modificador_grupo_traducciones to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modificador_grupo_traducciones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modificador_grupo_traducciones to service_role;
grant select on table public.modificador_grupos to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modificador_grupos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modificador_grupos to service_role;
grant select on table public.modificador_opcion_traducciones to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modificador_opcion_traducciones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modificador_opcion_traducciones to service_role;
grant select on table public.modificador_opciones to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modificador_opciones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modificador_opciones to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modulos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.modulos to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.niveles_fidelizacion to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.niveles_fidelizacion to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.order_deliveries to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.order_deliveries to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.order_item_modificadores to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.order_item_modificadores to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.order_items to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.order_items to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.order_sector_confirmaciones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.order_sector_confirmaciones to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.orders to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.orders to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.planes to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.planes to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.planes to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.premios_fidelizacion to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.premios_fidelizacion to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.promos_sellos to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.promos_sellos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.promos_sellos to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.receta_items to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.receta_items to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.resenas to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.resenas to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.reservations to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.reservations to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurant_billing to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurant_billing to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurant_info to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurant_info to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurant_info to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurant_modulos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurant_modulos to service_role;
grant insert, update, delete, truncate, references, trigger, maintain on table public.restaurants to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurants to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.restaurants to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.sectores_cocina to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.sectores_cocina to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.stock_movimientos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.stock_movimientos to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.superadmins to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.superadmins to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.table_session_payments to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.table_session_payments to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.table_sessions to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.table_sessions to service_role;
grant insert, update, delete, truncate, references, trigger, maintain on table public.tables to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.tables to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.tables to service_role;
grant select on table public.upsell_rules to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.upsell_rules to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.upsell_rules to service_role;
grant select on table public.upsell_traducciones to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.upsell_traducciones to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.upsell_traducciones to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.vale_movimientos to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.vale_movimientos to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.vales_regalo to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.vales_regalo to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.vendedores to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.vendedores to service_role;
grant insert on table public.waiter_calls to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.waiter_calls to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.waiter_calls to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.webhook_entregas to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.webhook_entregas to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.webhooks to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.webhooks to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.whatsapp_mensajes_procesados to anon;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.whatsapp_mensajes_procesados to authenticated;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.whatsapp_mensajes_procesados to service_role;
grant select, insert, update, delete, truncate, references, trigger, maintain on table public.whatsapp_sessions to service_role;

-- 4. Columnas ---------------------------------------------------------------------
grant select (activo, config, direccion, id, logo_url, moneda, nombre, slug, subdominio, whatsapp) on table public.restaurants to anon;
grant select (cliente_nombre, cliente_telefono) on table public.table_sessions to authenticated;
grant update (cliente_nombre, cliente_telefono) on table public.table_sessions to authenticated;
grant select (activa, capacidad, id, limpieza_progreso, necesita_limpieza, numero, restaurant_id, zona) on table public.tables to anon;

-- 5. Funciones --------------------------------------------------------------------
grant execute on function public.fn_aceptar_condiciones(p_restaurant_id uuid, p_version text) to authenticated, service_role;
grant execute on function public.fn_activar_modulo_nucleo() to public, anon, authenticated, service_role;
grant execute on function public.fn_actualizar_precio_contrato(p_restaurant_id uuid, p_precio numeric) to authenticated, service_role;
grant execute on function public.fn_ahora_madrid() to public, anon, authenticated, service_role;
grant execute on function public.fn_aplicar_descuento(p_restaurant_id uuid, p_precio numeric, p_dias integer) to anon, authenticated, service_role;
grant execute on function public.fn_asegurar_sector_confirmacion() to public, anon, authenticated, service_role;
grant execute on function public.fn_asignar_modulo_a_plan(p_modulo_key text, p_plan_key text) to anon, authenticated, service_role;
grant execute on function public.fn_asignar_plan(p_restaurant_id uuid, p_plan_key text) to authenticated, service_role;
grant execute on function public.fn_bloquear_si_restaurante_inactivo() to public, anon, authenticated, service_role;
grant execute on function public.fn_camarero_abrir_mesa(p_table_id uuid, p_restaurant_id uuid, p_camarero_id uuid, p_comensales integer) to public, anon, authenticated, service_role;
grant execute on function public.fn_camarero_editar_cliente_sesion(p_table_session_id uuid, p_restaurant_id uuid, p_camarero_id uuid, p_telefono text, p_nombre text) to public, anon, authenticated, service_role;
grant execute on function public.fn_camarero_listar_pedidos_sesion(p_restaurant_id uuid, p_camarero_id uuid, p_table_session_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_camarero_listar_sesiones(p_restaurant_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_camarero_toggle_limpieza(p_table_id uuid, p_restaurant_id uuid, p_paso_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_camarero_tomar_mesa(p_table_session_id uuid, p_restaurant_id uuid, p_camarero_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_canjear_vale_regalo(p_table_session_id uuid, p_vale_codigo text, p_vale_importe numeric) to public, anon, authenticated, service_role;
grant execute on function public.fn_carta_takeaway(p_restaurant_id uuid, p_momento timestamp with time zone) to public, anon, authenticated, service_role;
grant execute on function public.fn_condiciones_pendientes(p_restaurant_id uuid, p_version text) to authenticated, service_role;
grant execute on function public.fn_consultar_vale(p_restaurant_id uuid, p_codigo text) to public, anon, authenticated, service_role;
grant execute on function public.fn_crear_camarero(p_restaurant_id uuid, p_nombre text, p_pin text, p_permisos text[]) to anon, authenticated, service_role;
grant execute on function public.fn_crear_reserva_web(p_restaurant_id uuid, p_nombre text, p_telefono text, p_fecha date, p_hora time without time zone, p_personas integer, p_zona text, p_notas text) to public, anon, authenticated, service_role;
grant execute on function public.fn_crm_actividades_antes() to public, anon, authenticated, service_role;
grant execute on function public.fn_crm_actividades_despues() to public, anon, authenticated, service_role;
grant execute on function public.fn_crm_busqueda_cargar(p_id uuid) to authenticated, service_role;
grant execute on function public.fn_crm_busquedas_recientes() to authenticated, service_role;
grant execute on function public.fn_crm_cuenta_puede_ver(p_cuenta_id uuid) to public, authenticated, service_role;
grant execute on function public.fn_crm_cuentas_antes() to public, anon, authenticated, service_role;
grant execute on function public.fn_crm_cuentas_despues() to public, anon, authenticated, service_role;
grant execute on function public.fn_crm_cuota_restaurante(p_restaurant_id uuid, p_fecha date) to authenticated, service_role;
grant execute on function public.fn_crm_duplicados(p_locales jsonb) to authenticated, service_role;
grant execute on function public.fn_crm_generar_comisiones(p_periodo date) to public, authenticated, service_role;
grant execute on function public.fn_crm_importar_restaurantes() to public, authenticated, service_role;
grant execute on function public.fn_crm_permanencias() to authenticated, service_role;
grant execute on function public.fn_crm_puede_buscar() to authenticated, service_role;
grant execute on function public.fn_crm_registrar_busqueda(p_parametros jsonb, p_consultas integer, p_resultados integer, p_locales jsonb) to authenticated, service_role;
grant execute on function public.fn_crm_restaurantes_cuentas() to public, authenticated, service_role;
grant execute on function public.fn_crm_uso_places() to authenticated, service_role;
grant execute on function public.fn_crm_vendedor_cambiar_password(p_vendedor uuid, p_password text) to authenticated, service_role;
grant execute on function public.fn_dar_baja_restaurante(p_restaurant_id uuid, p_motivo text, p_cobrar_penalizacion boolean) to authenticated, service_role;
grant execute on function public.fn_disparar_webhooks(p_restaurant_id uuid, p_evento text, p_payload jsonb) to service_role;
grant execute on function public.fn_es_superadmin() to public, authenticated, service_role;
grant execute on function public.fn_estado_fidelizacion(p_restaurant_id uuid, p_telefono text) to public, anon, authenticated, service_role;
grant execute on function public.fn_estado_sesion_mesa(p_session_id uuid, p_qr_token text) to public, anon, authenticated, service_role;
grant execute on function public.fn_hora_madrid() to public, anon, authenticated, service_role;
grant execute on function public.fn_hoy_madrid() to public, anon, authenticated, service_role;
grant execute on function public.fn_info_restaurante_publica(p_restaurant_id uuid) to anon, authenticated, service_role;
grant execute on function public.fn_iniciar_trial(p_restaurant_id uuid, p_dias integer) to anon, authenticated, service_role;
grant execute on function public.fn_limpiar_descuento(p_restaurant_id uuid) to anon, authenticated, service_role;
grant execute on function public.fn_limpiar_trial(p_restaurant_id uuid) to anon, authenticated, service_role;
grant execute on function public.fn_listar_camareros_nombres(p_restaurant_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_marcar_timestamp_estado_pedido() to public, anon, authenticated, service_role;
grant execute on function public.fn_menu_activo(p_restaurant_id uuid, p_zona text, p_momento timestamp with time zone, p_whatsapp boolean) to public, anon, authenticated, service_role;
grant execute on function public.fn_mi_restaurante() to public, authenticated, service_role;
grant execute on function public.fn_mi_vendedor_id() to public, authenticated, service_role;
grant execute on function public.fn_normalizar_telefono(p_telefono text) to public, anon, authenticated, service_role;
grant execute on function public.fn_otorgar_puntos_fidelizacion() to public, anon, authenticated, service_role;
grant execute on function public.fn_otorgar_puntos_mesa() to public, anon, authenticated, service_role;
grant execute on function public.fn_permanencia_penalizacion(p_restaurant_id uuid, p_fecha date) to authenticated, service_role;
grant execute on function public.fn_procesar_sellos(p_restaurant_id uuid, p_cliente_id uuid, p_conteo_productos jsonb) to public, anon, authenticated, service_role;
grant execute on function public.fn_registrar_cliente_sesion(p_session_id uuid, p_qr_token text, p_telefono text, p_nombre text) to public, anon, authenticated, service_role;
grant execute on function public.fn_registrar_pedido(p_table_session_id uuid, p_items jsonb, p_notas text, p_camarero_id uuid, p_premios_canjeados jsonb, p_vale_codigo text, p_vale_importe numeric) to public, anon, authenticated, service_role;
grant execute on function public.fn_registrar_resena(p_session_id uuid, p_qr_token text, p_puntuacion integer, p_comentario text) to public, anon, authenticated, service_role;
grant execute on function public.fn_reserva_cliente_bloquear(p_restaurant_id uuid, p_telefono text, p_reserva_id uuid) to service_role;
grant execute on function public.fn_reserva_cliente_cancelar(p_restaurant_id uuid, p_telefono text, p_reserva_id uuid) to service_role;
grant execute on function public.fn_reserva_cliente_modificar(p_restaurant_id uuid, p_telefono text, p_reserva_id uuid, p_fecha date, p_hora time without time zone, p_personas integer, p_zona text, p_duracion_minutos integer, p_aplicar boolean) to service_role;
grant execute on function public.fn_reserva_contexto_cliente(p_restaurant_id uuid, p_telefono text) to service_role;
grant execute on function public.fn_reserva_fuera_de_horario(p_restaurant_id uuid, p_fecha date, p_hora time without time zone) to public, anon, authenticated, service_role;
grant execute on function public.fn_reserva_hay_mesa(p_restaurant_id uuid, p_fecha date, p_hora time without time zone, p_personas integer, p_zona text, p_duracion_minutos integer) to public, anon, authenticated, service_role;
grant execute on function public.fn_reserva_whatsapp_crear(p_restaurant_id uuid, p_nombre text, p_telefono text, p_fecha date, p_hora time without time zone, p_personas integer, p_zona text, p_notas text, p_duracion_minutos integer) to public, anon, authenticated, service_role;
grant execute on function public.fn_resetear_pin_camarero(p_camarero_id uuid, p_restaurant_id uuid, p_pin_nuevo text) to anon, authenticated, service_role;
grant execute on function public.fn_restaurante_accesible(p_restaurant_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_restaurante_activo(p_restaurant_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_restaurants_permanencia_alta() to public, anon, authenticated, service_role;
grant execute on function public.fn_restaurants_proteger_comercial() to public, anon, authenticated, service_role;
grant execute on function public.fn_restaurants_proteger_comercial_alta() to public, anon, authenticated, service_role;
grant execute on function public.fn_sesion_abierta_por_token(p_qr_token text) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_cambiar_estado_pedido(p_restaurant_id uuid, p_camarero_id uuid, p_order_id uuid, p_nuevo_estado text) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_cambiar_estado_reserva(p_restaurant_id uuid, p_camarero_id uuid, p_reserva_id uuid, p_nuevo_estado text) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_canjear_puntos(p_restaurant_id uuid, p_camarero_id uuid, p_cliente_id uuid, p_cantidad integer, p_motivo text) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_contar_alertas(p_restaurant_id uuid, p_camarero_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_crear_reserva_manual(p_restaurant_id uuid, p_camarero_id uuid, p_nombre text, p_telefono text, p_fecha date, p_hora time without time zone, p_personas integer, p_zona text, p_notas text) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_historial_cliente(p_restaurant_id uuid, p_camarero_id uuid, p_cliente_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_listar_clientes(p_restaurant_id uuid, p_camarero_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_listar_llamadas(p_restaurant_id uuid, p_camarero_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_listar_pedidos_cocina(p_restaurant_id uuid, p_camarero_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_listar_reservas(p_restaurant_id uuid, p_camarero_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_marcar_llamada_atendida(p_restaurant_id uuid, p_camarero_id uuid, p_llamada_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.fn_staff_tiene_permiso(p_restaurant_id uuid, p_camarero_id uuid, p_permiso text) to public, anon, authenticated, service_role;
grant execute on function public.fn_trg_normalizar_telefono_cliente() to public, anon, authenticated, service_role;
grant execute on function public.fn_trigger_webhook_order_placed() to public, anon, authenticated, service_role;
grant execute on function public.fn_trigger_webhook_payment_received() to public, anon, authenticated, service_role;
grant execute on function public.fn_trigger_webhook_reservation_created() to public, anon, authenticated, service_role;
grant execute on function public.fn_trigger_webhook_waiter_call() to public, anon, authenticated, service_role;
grant execute on function public.fn_validar_modulo_pedido() to public, anon, authenticated, service_role;
grant execute on function public.fn_verificar_camarero_pin(p_restaurant_id uuid, p_camarero_id uuid, p_pin text) to public, anon, authenticated, service_role;
grant execute on function public.fn_whatsapp_mensaje_nuevo(p_wamid text, p_restaurant_id uuid) to service_role;
grant execute on function public.force_zero_total_on_mesa_insert() to public, anon, authenticated, service_role;
grant execute on function public.get_session_orders(p_session_id uuid, p_qr_token text) to public, anon, authenticated, service_role;
grant execute on function public.get_table_by_qr(p_token text) to public, anon, authenticated, service_role;
grant execute on function public.is_restaurant_owner(rid uuid) to public, anon, authenticated, service_role;
grant execute on function public.order_is_valid_for_items(p_order_id uuid) to public, anon, authenticated, service_role;
grant execute on function public.recalc_order_total() to public, anon, authenticated, service_role;
grant execute on function public.set_updated_at() to public, anon, authenticated, service_role;

-- 6. Privilegios por defecto de postgres (como estaban en Producción) -----------------
alter default privileges for role postgres grant execute on functions to public;
alter default privileges for role postgres in schema public grant all     on tables    to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant execute on functions to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all     on sequences to postgres, anon, authenticated, service_role;

--   estado de referencia: postgres public S: anon=Urw authenticated=Urw postgres=Urw service_role=Urw
--   estado de referencia: postgres public f: anon=X authenticated=X postgres=X service_role=X
--   estado de referencia: postgres public r: anon=Dadmrtwx authenticated=Dadmrtwx postgres=Dadmrtwx service_role=Dadmrtwx
--   estado de referencia: supabase_admin public S: anon=Urw authenticated=Urw postgres=Urw service_role=Urw
--   estado de referencia: supabase_admin public f: anon=X authenticated=X postgres=X service_role=X
--   estado de referencia: supabase_admin public r: anon=Dadmrtwx authenticated=Dadmrtwx postgres=Dadmrtwx service_role=Dadmrtwx
--   esquema de referencia: public: PUBLIC=U anon=U authenticated=U pg_database_owner=CU postgres=U service_role=U

notify pgrst, 'reload schema';

commit;
