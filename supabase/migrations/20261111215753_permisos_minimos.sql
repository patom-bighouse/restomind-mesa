-- =============================================================================
-- Permisos mínimos iguales en Test y Producción (esquema public)
-- Especificación: docs/specs/2026-11-11-permisos-minimos.md
--
-- NO TOCA DATOS. Solo cambia grants de tabla, de columna y de funciones del
-- esquema public, los privilegios por defecto del rol postgres y el
-- search_path de fn_marcar_timestamp_estado_pedido().
--
-- Idempotente: primero revoca todo a PUBLIC/anon/authenticated/service_role
-- recorriendo el catálogo (no depende de lo que haya hoy en cada entorno) y
-- después concede exactamente lo de la especificación. Nunca revoca nada a
-- postgres (dueño de todos los objetos).
--
-- Excluye objetos de extensiones (pg_depend deptype = 'e') y rls_auto_enable()
-- (solo existe en Test; fuera de alcance).
--
-- Vuelta atrás (no aplicada): supabase/rollback/20261111215753_permisos_minimos_revertir.sql
--
-- Ojo para el futuro: tras esta migración, las tablas y funciones nuevas que
-- cree postgres NO tienen permisos para anon ni authenticated. Toda migración
-- que cree una tabla o función debe incluir sus grants.
-- =============================================================================

-- 0. Esquema ------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;

do $$
declare
  r record;

  -- Grupo A: anon + authenticated + service_role (mesa, camarero/cocina con PIN, web pública)
  grupo_a text[] := array[
    'get_table_by_qr', 'fn_sesion_abierta_por_token', 'fn_estado_sesion_mesa', 'fn_registrar_pedido',
    'get_session_orders', 'fn_registrar_cliente_sesion', 'fn_estado_fidelizacion', 'fn_consultar_vale',
    'fn_canjear_vale_regalo', 'fn_registrar_resena', 'fn_restaurante_accesible', 'fn_info_restaurante_publica',
    'fn_crear_reserva_web', 'fn_listar_camareros_nombres', 'fn_verificar_camarero_pin', 'fn_camarero_listar_sesiones',
    'fn_camarero_abrir_mesa', 'fn_camarero_tomar_mesa', 'fn_camarero_toggle_limpieza', 'fn_camarero_listar_pedidos_sesion',
    'fn_camarero_editar_cliente_sesion', 'fn_staff_contar_alertas', 'fn_staff_listar_llamadas',
    'fn_staff_marcar_llamada_atendida', 'fn_staff_listar_clientes', 'fn_staff_historial_cliente',
    'fn_staff_canjear_puntos', 'fn_staff_listar_reservas', 'fn_staff_cambiar_estado_reserva',
    'fn_staff_crear_reserva_manual', 'fn_staff_listar_pedidos_cocina', 'fn_staff_cambiar_estado_pedido'
  ];

  -- Grupo B: authenticated + service_role (panel, superadmin, CRM, Edge Functions, políticas, DEFAULT)
  grupo_b text[] := array[
    'fn_mi_restaurante', 'fn_es_superadmin', 'fn_mi_vendedor_id', 'is_restaurant_owner', 'fn_crm_cuenta_puede_ver',
    'fn_condiciones_pendientes', 'fn_aceptar_condiciones',
    'fn_asignar_modulo_a_plan', 'fn_iniciar_trial', 'fn_aplicar_descuento', 'fn_limpiar_trial', 'fn_limpiar_descuento',
    'fn_crear_camarero', 'fn_resetear_pin_camarero', 'fn_asignar_plan', 'fn_actualizar_precio_contrato',
    'fn_dar_baja_restaurante', 'fn_permanencia_penalizacion',
    'fn_crm_importar_restaurantes', 'fn_crm_restaurantes_cuentas', 'fn_crm_generar_comisiones',
    'fn_crm_cuota_restaurante', 'fn_crm_permanencias', 'fn_crm_vendedor_cambiar_password', 'fn_crm_puede_buscar',
    'fn_crm_uso_places', 'fn_crm_duplicados', 'fn_crm_registrar_busqueda', 'fn_crm_busquedas_recientes',
    'fn_crm_busqueda_cargar',
    'fn_hoy_madrid', 'fn_normalizar_telefono'
  ];

  -- Grupo C: solo service_role (n8n / uso interno). Toda función no trigger que
  -- no esté en A ni en B queda así; esta lista solo sirve para avisar de
  -- funciones nuevas no clasificadas.
  grupo_c text[] := array[
    'fn_whatsapp_mensaje_nuevo', 'fn_reserva_contexto_cliente', 'fn_reserva_cliente_cancelar',
    'fn_reserva_cliente_modificar', 'fn_reserva_cliente_bloquear', 'fn_disparar_webhooks',
    'fn_reserva_whatsapp_crear', 'fn_reserva_hay_mesa', 'fn_reserva_fuera_de_horario', 'fn_carta_takeaway',
    'fn_menu_activo', 'fn_procesar_sellos', 'fn_staff_tiene_permiso', 'fn_restaurante_activo',
    'order_is_valid_for_items', 'fn_ahora_madrid', 'fn_hora_madrid'
  ];
  -- Grupo T (funciones de trigger, returns trigger): solo postgres. Se detectan por el tipo devuelto.
begin
  -- 1. Revocar en tablas, vistas y secuencias ----------------------------------
  for r in
    select c.oid::regclass as obj, c.relkind
    from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S')
      and not exists (select 1 from pg_depend d
                      where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  loop
    if r.relkind = 'S' then
      execute format('revoke all on sequence %s from public, anon, authenticated, service_role', r.obj);
    else
      execute format('revoke all on table %s from public, anon, authenticated, service_role', r.obj);
    end if;
  end loop;

  -- 2. Revocar grants por columna (revoke all de tabla no los quita) -----------
  for r in
    select c.oid::regclass as obj, string_agg(quote_ident(a.attname), ', ' order by a.attnum) as cols
    from pg_class c
    join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped and a.attacl is not null
    where c.relnamespace = 'public'::regnamespace
      and c.relkind in ('r', 'p', 'v', 'm', 'f')
      and not exists (select 1 from pg_depend d
                      where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
    group by c.oid
  loop
    execute format('revoke all (%s) on table %s from public, anon, authenticated, service_role', r.cols, r.obj);
  end loop;

  -- 3. service_role: todo en todas las tablas y secuencias ---------------------
  for r in
    select c.oid::regclass as obj, c.relkind
    from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S')
      and not exists (select 1 from pg_depend d
                      where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  loop
    if r.relkind = 'S' then
      execute format('grant all on sequence %s to service_role', r.obj);
    else
      execute format('grant all on table %s to service_role', r.obj);
    end if;
  end loop;

  -- 4. anon y authenticated: tabla "Grants de tabla" de la especificación ------
  for r in
    select * from (values
      ('camarero_pin_intentos',           null,                                     null),
      ('camareros',                       null,                                     'select, insert, update, delete'),
      ('categoria_traducciones',          'select',                                 'select, insert, update, delete'),
      ('categories',                      'select',                                 'select, insert, update, delete'),
      ('clientes',                        null,                                     'select, insert, update'),
      ('clientes_movimientos',            null,                                     'select, insert'),
      ('clientes_sellos',                 null,                                     'select'),
      ('condiciones_aceptaciones',        null,                                     'select'),
      ('crm_actividades',                 null,                                     'select, insert, update, delete'),
      ('crm_busquedas',                   null,                                     'select'),
      ('crm_comisiones',                  null,                                     'select, insert, update, delete'),
      ('crm_config',                      null,                                     'select, update'),
      ('crm_cuentas',                     null,                                     'select, insert, update, delete'),
      ('crm_historial',                   null,                                     'select'),
      ('crm_tareas',                      null,                                     'select, insert, update, delete'),
      ('ingredientes',                    null,                                     'select, insert, update, delete'),
      ('limpieza_pasos',                  'select',                                 'select, insert, update, delete'),
      ('menu_item_modificador_grupos',    'select',                                 'select, insert, update, delete'),
      ('menu_item_modificador_precios',   'select',                                 'select, insert, update, delete'),
      ('menu_item_precios_menu',          'select',                                 'select, insert, update, delete'),
      ('menu_item_traducciones',          'select',                                 'select, insert, update, delete'),
      ('menu_items',                      'select',                                 'select, insert, update, delete'),
      ('menus',                           'select',                                 'select, insert, update, delete'),
      ('modificador_grupo_traducciones',  'select',                                 'select, insert, update, delete'),
      ('modificador_grupos',              'select',                                 'select, insert, update, delete'),
      ('modificador_opcion_traducciones', 'select',                                 'select, insert, update, delete'),
      ('modificador_opciones',            'select',                                 'select, insert, update, delete'),
      ('modulos',                         null,                                     'select'),
      ('niveles_fidelizacion',            null,                                     'select, insert, update, delete'),
      ('order_deliveries',                null,                                     'select, insert, update'),
      ('order_item_modificadores',        null,                                     'select, insert'),
      ('order_items',                     null,                                     'select, insert, update, delete'),
      ('order_sector_confirmaciones',     null,                                     'select, insert, update'),
      ('orders',                          null,                                     'select, insert, update, delete'),
      ('planes',                          'select',                                 'select, insert, update, delete'),
      ('premios_fidelizacion',            null,                                     'select, insert, update, delete'),
      ('promos_sellos',                   null,                                     'select, insert, update, delete'),
      ('receta_items',                    null,                                     'select, insert, update, delete'),
      ('resenas',                         null,                                     'select'),
      ('reservations',                    null,                                     'select, insert, update, delete'),
      ('restaurant_billing',              null,                                     'select, insert, update, delete'),
      ('restaurant_info',                 null,                                     'select, insert, update, delete'),
      ('restaurant_modulos',              null,                                     'select, insert, update'),
      ('restaurants',                     'select (id, nombre, logo_url, activo, config, direccion, moneda, slug, subdominio, whatsapp)',
                                                                                    'select, insert, update, delete'),
      ('sectores_cocina',                 null,                                     'select, insert, update, delete'),
      ('stock_movimientos',               null,                                     'select, insert'),
      ('superadmins',                     null,                                     'select'),
      ('table_session_payments',          null,                                     'select, insert, update, delete'),
      ('table_sessions',                  null,                                     'select, insert, update, delete'),
      ('tables',                          'select (id, restaurant_id, numero, zona, capacidad, activa, necesita_limpieza, limpieza_progreso)',
                                                                                    'select, insert, update, delete'),
      ('upsell_rules',                    'select',                                 'select, insert, update, delete'),
      ('upsell_traducciones',             'select',                                 'select, insert, update, delete'),
      ('vale_movimientos',                null,                                     'select'),
      ('vales_regalo',                    null,                                     'select, insert, update'),
      ('vendedores',                      null,                                     'select, insert, update, delete'),
      ('waiter_calls',                    'insert',                                 'select, insert, update, delete'),
      ('webhook_entregas',                null,                                     'select'),
      ('webhooks',                        null,                                     'select, insert, update, delete'),
      ('whatsapp_mensajes_procesados',    null,                                     null),
      ('whatsapp_sessions',               null,                                     null)
    ) as v(tabla, priv_anon, priv_authenticated)
  loop
    if to_regclass(format('public.%I', r.tabla)) is null then
      raise notice 'permisos_minimos: la tabla public.% no existe; se omite', r.tabla;
      continue;
    end if;
    if r.priv_anon is not null then
      execute format('grant %s on table public.%I to anon', r.priv_anon, r.tabla);
    end if;
    if r.priv_authenticated is not null then
      execute format('grant %s on table public.%I to authenticated', r.priv_authenticated, r.tabla);
    end if;
  end loop;

  -- 5. Funciones ---------------------------------------------------------------
  for r in
    select p.oid::regprocedure as fn, p.proname, (p.prorettype = 'trigger'::regtype) as es_trigger
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname <> 'rls_auto_enable'
      and not exists (select 1 from pg_depend d
                      where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke all on routine %s from public, anon, authenticated, service_role', r.fn);

    if r.es_trigger then
      continue;  -- grupo T: solo postgres
    end if;

    execute format('grant execute on routine %s to service_role', r.fn);

    if r.proname = any (grupo_a) then
      execute format('grant execute on routine %s to anon, authenticated', r.fn);
    elsif r.proname = any (grupo_b) then
      execute format('grant execute on routine %s to authenticated', r.fn);
    elsif not (r.proname = any (grupo_c)) then
      raise notice 'permisos_minimos: % no está clasificada; queda solo para service_role', r.fn;
    end if;
  end loop;
end
$$;

-- 6. Privilegios por defecto de objetos nuevos creados por postgres -----------
-- Nada abierto salvo para service_role. El EXECUTE a PUBLIC es un valor por
-- defecto global de Postgres: se quita sin "in schema".
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from public;

alter default privileges for role postgres in schema public revoke all on tables    from anon, authenticated, service_role;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated, service_role;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated, service_role;

alter default privileges for role postgres in schema public grant all     on tables    to postgres, service_role;
alter default privileges for role postgres in schema public grant execute on functions to postgres, service_role;
alter default privileges for role postgres in schema public grant all     on sequences to postgres, service_role;

-- 7. search_path fijo (aviso del asesor de seguridad). El cuerpo no cambia. ----
alter function public.fn_marcar_timestamp_estado_pedido() set search_path = public;

-- 8. Que PostgREST recargue el esquema ------------------------------------------
notify pgrst, 'reload schema';
