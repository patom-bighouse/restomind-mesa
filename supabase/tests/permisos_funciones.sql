-- =============================================================================
-- Criterio 2 de docs/specs/2026-11-11-permisos-minimos.md
-- EXECUTE de cada función de public por grupos (A, B, C, T).
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql -f supabase/tests/permisos_funciones.sql
--
-- Resultado: una fila por comprobación (prueba, ok, detalle). Debe salir ok = true
-- en todas. Las filas "diferencia" solo aparecen si algo no coincide.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

create temp table _grupos (funcion text, grupo text) on commit drop;
insert into _grupos (funcion, grupo)
select f, 'A' from unnest(array[
  'get_table_by_qr', 'fn_sesion_abierta_por_token', 'fn_estado_sesion_mesa', 'fn_registrar_pedido',
  'get_session_orders', 'fn_registrar_cliente_sesion', 'fn_estado_fidelizacion', 'fn_consultar_vale',
  'fn_canjear_vale_regalo', 'fn_registrar_resena', 'fn_restaurante_accesible', 'fn_info_restaurante_publica',
  'fn_crear_reserva_web', 'fn_listar_camareros_nombres', 'fn_verificar_camarero_pin', 'fn_camarero_listar_sesiones',
  'fn_camarero_abrir_mesa', 'fn_camarero_tomar_mesa', 'fn_camarero_toggle_limpieza', 'fn_camarero_listar_pedidos_sesion',
  'fn_camarero_editar_cliente_sesion', 'fn_staff_contar_alertas', 'fn_staff_listar_llamadas',
  'fn_staff_marcar_llamada_atendida', 'fn_staff_listar_clientes', 'fn_staff_historial_cliente',
  'fn_staff_canjear_puntos', 'fn_staff_listar_reservas', 'fn_staff_cambiar_estado_reserva',
  'fn_staff_crear_reserva_manual', 'fn_staff_listar_pedidos_cocina', 'fn_staff_cambiar_estado_pedido'
]) f
union all
select f, 'B' from unnest(array[
  'fn_mi_restaurante', 'fn_es_superadmin', 'fn_mi_vendedor_id', 'is_restaurant_owner', 'fn_crm_cuenta_puede_ver',
  'fn_condiciones_pendientes', 'fn_aceptar_condiciones',
  'fn_asignar_modulo_a_plan', 'fn_iniciar_trial', 'fn_aplicar_descuento', 'fn_limpiar_trial', 'fn_limpiar_descuento',
  'fn_crear_camarero', 'fn_resetear_pin_camarero', 'fn_asignar_plan', 'fn_actualizar_precio_contrato',
  'fn_dar_baja_restaurante', 'fn_permanencia_penalizacion',
  'fn_crm_importar_restaurantes', 'fn_crm_restaurantes_cuentas', 'fn_crm_generar_comisiones',
  'fn_crm_cuota_restaurante', 'fn_crm_permanencias', 'fn_crm_vendedor_cambiar_password', 'fn_crm_puede_buscar',
  'fn_crm_uso_places', 'fn_crm_duplicados', 'fn_crm_registrar_busqueda', 'fn_crm_busquedas_recientes',
  'fn_crm_busqueda_cargar', 'fn_hoy_madrid', 'fn_normalizar_telefono'
]) f
union all
select f, 'C' from unnest(array[
  'fn_whatsapp_mensaje_nuevo', 'fn_reserva_contexto_cliente', 'fn_reserva_cliente_cancelar',
  'fn_reserva_cliente_modificar', 'fn_reserva_cliente_bloquear', 'fn_disparar_webhooks',
  'fn_reserva_whatsapp_crear', 'fn_reserva_hay_mesa', 'fn_reserva_fuera_de_horario', 'fn_carta_takeaway',
  'fn_menu_activo', 'fn_procesar_sellos', 'fn_staff_tiene_permiso', 'fn_restaurante_activo',
  'order_is_valid_for_items', 'fn_ahora_madrid', 'fn_hora_madrid'
]) f
union all
select f, 'T' from unnest(array[
  'fn_validar_modulo_pedido', 'fn_asegurar_sector_confirmacion', 'fn_otorgar_puntos_fidelizacion',
  'fn_otorgar_puntos_mesa', 'fn_marcar_timestamp_estado_pedido', 'fn_bloquear_si_restaurante_inactivo',
  'set_updated_at', 'fn_crm_cuentas_antes', 'fn_crm_cuentas_despues', 'fn_crm_actividades_antes',
  'fn_crm_actividades_despues', 'force_zero_total_on_mesa_insert', 'recalc_order_total',
  'fn_trigger_webhook_order_placed', 'fn_trigger_webhook_payment_received',
  'fn_trigger_webhook_reservation_created', 'fn_trigger_webhook_waiter_call', 'fn_activar_modulo_nucleo',
  'fn_restaurants_permanencia_alta', 'fn_restaurants_proteger_comercial',
  'fn_restaurants_proteger_comercial_alta', 'fn_trg_normalizar_telefono_cliente'
]) f;

create temp table _esperado (funcion text, rol text) on commit drop;
insert into _esperado
select g.funcion, r.rol
from _grupos g
join (values ('A','anon'), ('A','authenticated'), ('A','service_role'), ('A','postgres'),
             ('B','authenticated'), ('B','service_role'), ('B','postgres'),
             ('C','service_role'), ('C','postgres'),
             ('T','postgres')) as r(grupo, rol) using (grupo);

create temp table _funciones on commit drop as
select p.oid, p.proname::text as funcion, p.proacl
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname <> 'rls_auto_enable'
  and not exists (select 1 from pg_depend d
                  where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e');

create temp table _real on commit drop as
select f.funcion, case when a.grantee = 0 then 'PUBLIC' else pg_get_userbyid(a.grantee)::text end as rol
from _funciones f, aclexplode(coalesce(f.proacl, acldefault('f', (select proowner from pg_proc where oid = f.oid)))) a
where a.privilege_type = 'EXECUTE';

insert into _resultado (prueba, ok, detalle)
select 'diferencia', false, 'falta: ' || funcion || ' → ' || rol
from (select * from _esperado except select * from _real) x
union all
select 'diferencia', false, 'sobra: ' || funcion || ' → ' || rol
from (select * from _real except select * from _esperado) x
union all
select 'diferencia', false, 'función no clasificada en la spec: ' || funcion
from (select funcion from _funciones except select funcion from _grupos) x
union all
select 'diferencia', false, 'función de la spec que no existe: ' || funcion
from (select funcion from _grupos except select funcion from _funciones) x;

insert into _resultado (prueba, ok, detalle)
select 'EXECUTE por grupos = spec',
       not exists (select 1 from _resultado where prueba = 'diferencia'),
       (select string_agg(grupo || '=' || n, ' ' order by grupo)
        from (select grupo, count(*) n from _grupos group by grupo) s) ||
       '; funciones en BD: ' || (select count(*) from _funciones) ||
       '; diferencias: ' || (select count(*) from _resultado where prueba = 'diferencia');

insert into _resultado (prueba, ok, detalle)
select 'PUBLIC sin EXECUTE en ninguna', count(*) = 0, count(*) || ' funciones con PUBLIC'
from _real where rol = 'PUBLIC';

-- Comprobaciones en vivo como anon ----------------------------------------------------
do $$
declare
  n int;
begin
  begin
    set local role anon;
    perform public.fn_iniciar_trial('00000000-0000-0000-0000-000000000000', 1);
    reset role;
    insert into _resultado (prueba, ok, detalle) values ('anon: fn_iniciar_trial → permission denied', false, 'no dio error');
  exception when insufficient_privilege then
    insert into _resultado (prueba, ok, detalle)
    values ('anon: fn_iniciar_trial → permission denied', sqlerrm = 'permission denied for function fn_iniciar_trial', sqlerrm);
  when others then
    insert into _resultado (prueba, ok, detalle)
    values ('anon: fn_iniciar_trial → permission denied', false, 'otro error: ' || sqlerrm);
  end;

  begin
    set local role anon;
    perform public.fn_procesar_sellos('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '{}'::jsonb);
    reset role;
    insert into _resultado (prueba, ok, detalle) values ('anon: fn_procesar_sellos → permission denied', false, 'no dio error');
  exception when insufficient_privilege then
    insert into _resultado (prueba, ok, detalle)
    values ('anon: fn_procesar_sellos → permission denied', sqlerrm = 'permission denied for function fn_procesar_sellos', sqlerrm);
  when others then
    insert into _resultado (prueba, ok, detalle)
    values ('anon: fn_procesar_sellos → permission denied', false, 'otro error: ' || sqlerrm);
  end;

  begin
    set local role anon;
    perform public.fn_reserva_whatsapp_crear('00000000-0000-0000-0000-000000000000', 'x', '600000000',
                                             current_date, '12:00'::time, 2, null, null, 90);
    reset role;
    insert into _resultado (prueba, ok, detalle) values ('anon: fn_reserva_whatsapp_crear → permission denied', false, 'no dio error');
  exception when insufficient_privilege then
    insert into _resultado (prueba, ok, detalle)
    values ('anon: fn_reserva_whatsapp_crear → permission denied', sqlerrm = 'permission denied for function fn_reserva_whatsapp_crear', sqlerrm);
  when others then
    insert into _resultado (prueba, ok, detalle)
    values ('anon: fn_reserva_whatsapp_crear → permission denied', false, 'otro error: ' || sqlerrm);
  end;

  begin
    set local role anon;
    select count(*) into n from public.get_table_by_qr('x');
    reset role;
    insert into _resultado (prueba, ok, detalle) values ('anon: get_table_by_qr(''x'') → sin error y 0 filas', n = 0, n || ' filas');
  exception when others then
    insert into _resultado (prueba, ok, detalle) values ('anon: get_table_by_qr(''x'') → sin error y 0 filas', false, sqlerrm);
  end;
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL permisos_funciones', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
