-- =============================================================================
-- VUELTA ATRÁS de supabase/migrations/20261112152109_pin_camarero_fase1.sql
-- (docs/specs/2026-11-12-pin-camarero.md, "Despliegue y vuelta atrás").
--
-- NO es una migración: no está en supabase/migrations/ a propósito, para que
-- `db push` no la aplique.
--
-- Repone las funciones del camarero con sus FIRMAS y CUERPOS de antes de la
-- fase 1 (sacados con pg_get_functiondef de Test el 12-11-2026, idénticos a
-- remote_schema + 20261112143742_arreglar_toggle_limpieza), con sus grants de
-- grupo, y borra fn_staff_exigir_sesion, fn_camarero_cerrar_sesion,
-- camarero_sesiones y camarero_llamadas_sin_token.
-- Si la fase 2 está aplicada, esto también la deshace (la fase 2 solo cambia
-- fn_staff_exigir_sesion, que aquí se borra).
--
-- ORDEN (riesgo 2 de la spec): ANTES hay que volver a publicar en Vercel la
-- versión anterior del front. Si no, el front nuevo envía p_token a funciones
-- que ya no lo aceptan y todas las pantallas del camarero fallan.
--
-- Borra datos: las sesiones abiertas (camarero_sesiones) y la anotación de
-- llamadas sin token. Nada más.
--
-- Cómo aplicarlo (siempre como migración, regla 1 de CLAUDE.md):
--   1. npx supabase migration new revertir_pin_camarero_fase1
--      y copiar este archivo en supabase/migrations/<ts nuevo>_revertir_pin_camarero_fase1.sql
--      QUITANDO las líneas `begin;` y `commit;` (db push ya va en transacción).
--   2. Test:        npx supabase db push --remote=sfkwbhzelrestmrmptql --dry-run && npx supabase db push --remote=sfkwbhzelrestmrmptql
--   3. Producción:  npx supabase db push --remote=mfxrluanpawfjncpqrvu --dry-run && npx supabase db push --remote=mfxrluanpawfjncpqrvu
--   4. Comprobar:   supabase/tests/permisos_funciones.sql (versión anterior a
--      este PR) y supabase/tests/limpieza_toggle.sql (versión anterior) en Test;
--      permisos_huella.sql debe volver a dar el md5 de antes de la fase 1.
-- =============================================================================
begin;

-- 1. Funciones nuevas ------------------------------------------------------------
drop function if exists public.fn_staff_exigir_sesion(uuid, uuid, text, text[], text);
drop function if exists public.fn_camarero_cerrar_sesion(text);

-- 2. Funciones cambiadas: borrar la firma nueva y reponer la de antes -------------
-- fn_camarero_listar_sesiones(p_restaurant_id uuid)
drop function if exists public.fn_camarero_listar_sesiones(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_camarero_listar_sesiones(p_restaurant_id uuid)
 RETURNS TABLE(id uuid, table_id uuid, comensales integer, camarero_id uuid, cliente_telefono text, cliente_nombre text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select ts.id, ts.table_id, ts.comensales, ts.camarero_id, ts.cliente_telefono, ts.cliente_nombre
  from table_sessions ts
  where ts.restaurant_id = p_restaurant_id and ts.estado = 'abierta'
$function$;

revoke all on function public.fn_camarero_listar_sesiones(uuid) from public, anon, authenticated;
grant execute on function public.fn_camarero_listar_sesiones(uuid) to anon, authenticated, service_role;

-- fn_camarero_abrir_mesa(p_table_id uuid, p_restaurant_id uuid, p_camarero_id uuid, p_comensales integer)
drop function if exists public.fn_camarero_abrir_mesa(uuid, uuid, uuid, integer, text);
CREATE OR REPLACE FUNCTION public.fn_camarero_abrir_mesa(p_table_id uuid, p_restaurant_id uuid, p_camarero_id uuid, p_comensales integer)
 RETURNS TABLE(id uuid, table_id uuid, comensales integer, camarero_id uuid, cliente_telefono text, cliente_nombre text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  if not exists (select 1 from tables t where t.id = p_table_id and t.restaurant_id = p_restaurant_id and t.activa = true) then
    raise exception 'Mesa no encontrada.';
  end if;
  if p_camarero_id is not null and not exists (
    select 1 from camareros c where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true
  ) then
    raise exception 'Camarero no válido.';
  end if;

  insert into table_sessions (table_id, restaurant_id, comensales, camarero_id)
  values (p_table_id, p_restaurant_id, p_comensales, p_camarero_id)
  returning table_sessions.id into v_id;

  return query
    select ts.id, ts.table_id, ts.comensales, ts.camarero_id, ts.cliente_telefono, ts.cliente_nombre
    from table_sessions ts where ts.id = v_id;
end;
$function$;

revoke all on function public.fn_camarero_abrir_mesa(uuid, uuid, uuid, integer) from public, anon, authenticated;
grant execute on function public.fn_camarero_abrir_mesa(uuid, uuid, uuid, integer) to anon, authenticated, service_role;

-- fn_camarero_tomar_mesa(p_table_session_id uuid, p_restaurant_id uuid, p_camarero_id uuid)
drop function if exists public.fn_camarero_tomar_mesa(uuid, uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_camarero_tomar_mesa(p_table_session_id uuid, p_restaurant_id uuid, p_camarero_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from camareros c where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true
  ) then
    raise exception 'Camarero no válido.';
  end if;

  update table_sessions
  set camarero_id = p_camarero_id
  where id = p_table_session_id and restaurant_id = p_restaurant_id and estado = 'abierta';
end;
$function$;

revoke all on function public.fn_camarero_tomar_mesa(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_camarero_tomar_mesa(uuid, uuid, uuid) to anon, authenticated, service_role;

-- fn_camarero_listar_pedidos_sesion(p_restaurant_id uuid, p_camarero_id uuid, p_table_session_id uuid)
drop function if exists public.fn_camarero_listar_pedidos_sesion(uuid, uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_camarero_listar_pedidos_sesion(p_restaurant_id uuid, p_camarero_id uuid, p_table_session_id uuid)
 RETURNS TABLE(order_id uuid, order_created_at timestamp with time zone, order_estado text, order_total numeric, order_notas text, item_id uuid, item_nombre text, item_precio numeric, item_cantidad integer, item_notas text, item_modificadores text, item_modificadores_extra numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  return query
    select
      o.id, o.created_at, o.estado, o.total, o.notas,
      oi.id, oi.nombre_snapshot, oi.precio_snapshot, oi.cantidad, oi.notas,
      (
        select string_agg(oim.opcion_nombre, ', ' order by oim.grupo_nombre, oim.opcion_nombre)
        from order_item_modificadores oim
        where oim.order_item_id = oi.id
      ) as item_modificadores,
      (
        select coalesce(sum(oim.precio_extra), 0)
        from order_item_modificadores oim
        where oim.order_item_id = oi.id
      ) as item_modificadores_extra
    from orders o
    join table_sessions ts on ts.id = o.table_session_id
    left join order_items oi on oi.order_id = o.id
    where o.table_session_id = p_table_session_id
      and ts.restaurant_id = p_restaurant_id
      and o.estado != 'cancelado'
    order by o.created_at asc, oi.id asc;
end;
$function$;

revoke all on function public.fn_camarero_listar_pedidos_sesion(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_camarero_listar_pedidos_sesion(uuid, uuid, uuid) to anon, authenticated, service_role;

-- fn_camarero_editar_cliente_sesion(p_table_session_id uuid, p_restaurant_id uuid, p_camarero_id uuid, p_telefono text, p_nombre text)
drop function if exists public.fn_camarero_editar_cliente_sesion(uuid, uuid, uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.fn_camarero_editar_cliente_sesion(p_table_session_id uuid, p_restaurant_id uuid, p_camarero_id uuid, p_telefono text, p_nombre text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from camareros c where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true
  ) then
    raise exception 'Camarero no válido.';
  end if;

  update table_sessions
  set cliente_telefono = p_telefono,
      cliente_nombre = coalesce(p_nombre, cliente_nombre)
  where id = p_table_session_id and restaurant_id = p_restaurant_id and estado = 'abierta';
end;
$function$;

revoke all on function public.fn_camarero_editar_cliente_sesion(uuid, uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.fn_camarero_editar_cliente_sesion(uuid, uuid, uuid, text, text) to anon, authenticated, service_role;

-- fn_staff_listar_llamadas(p_restaurant_id uuid, p_camarero_id uuid)
drop function if exists public.fn_staff_listar_llamadas(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_staff_listar_llamadas(p_restaurant_id uuid, p_camarero_id uuid)
 RETURNS TABLE(id uuid, table_id uuid, mesa_numero integer, mesa_zona text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  return query
    select w.id, w.table_id, t.numero, t.zona, w.created_at
    from waiter_calls w
    join tables t on t.id = w.table_id
    where w.restaurant_id = p_restaurant_id and w.estado = 'pendiente'
    order by w.created_at;
end;
$function$;

revoke all on function public.fn_staff_listar_llamadas(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_staff_listar_llamadas(uuid, uuid) to anon, authenticated, service_role;

-- fn_staff_marcar_llamada_atendida(p_restaurant_id uuid, p_camarero_id uuid, p_llamada_id uuid)
drop function if exists public.fn_staff_marcar_llamada_atendida(uuid, uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_staff_marcar_llamada_atendida(p_restaurant_id uuid, p_camarero_id uuid, p_llamada_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  update waiter_calls set estado = 'atendido'
  where id = p_llamada_id and restaurant_id = p_restaurant_id;
end;
$function$;

revoke all on function public.fn_staff_marcar_llamada_atendida(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_staff_marcar_llamada_atendida(uuid, uuid, uuid) to anon, authenticated, service_role;

-- fn_camarero_toggle_limpieza(p_table_id uuid, p_restaurant_id uuid, p_paso_id uuid)
drop function if exists public.fn_camarero_toggle_limpieza(uuid, uuid, uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_camarero_toggle_limpieza(p_table_id uuid, p_restaurant_id uuid, p_paso_id uuid)
 RETURNS TABLE(necesita_limpieza boolean, limpieza_progreso uuid[])
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actual jsonb;
  v_nuevo jsonb;
  v_completo boolean;
begin
  select t.limpieza_progreso into v_actual
  from tables t
  where t.id = p_table_id and t.restaurant_id = p_restaurant_id
  for update;

  if not found then
    raise exception 'Mesa no encontrada.';
  end if;

  if v_actual is null or jsonb_typeof(v_actual) <> 'array' then
    v_actual := '[]'::jsonb;
  end if;

  if v_actual ? p_paso_id::text then
    v_nuevo := v_actual - p_paso_id::text;
  else
    v_nuevo := v_actual || jsonb_build_array(p_paso_id::text);
  end if;

  select not exists (
    select 1 from limpieza_pasos lp
    where lp.restaurant_id = p_restaurant_id
      and lp.activo = true
      and not (v_nuevo ? lp.id::text)
  ) into v_completo;

  update tables t
  set limpieza_progreso = v_nuevo,
      necesita_limpieza = not v_completo
  where t.id = p_table_id and t.restaurant_id = p_restaurant_id;

  return query
  select (not v_completo),
         array(select e::uuid from jsonb_array_elements_text(v_nuevo) as e);
end;
$function$;

revoke all on function public.fn_camarero_toggle_limpieza(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_camarero_toggle_limpieza(uuid, uuid, uuid) to anon, authenticated, service_role;

-- fn_staff_contar_alertas(p_restaurant_id uuid, p_camarero_id uuid)
drop function if exists public.fn_staff_contar_alertas(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_staff_contar_alertas(p_restaurant_id uuid, p_camarero_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limpieza integer := 0;
  v_llamadas integer := 0;
begin
  if fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'limpieza') then
    select count(*) into v_limpieza from tables
    where restaurant_id = p_restaurant_id and necesita_limpieza = true;
  end if;

  if fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    select count(*) into v_llamadas from waiter_calls
    where restaurant_id = p_restaurant_id and estado = 'pendiente';
  end if;

  return json_build_object('limpieza', v_limpieza, 'llamadas', v_llamadas);
end;
$function$;

revoke all on function public.fn_staff_contar_alertas(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_staff_contar_alertas(uuid, uuid) to anon, authenticated, service_role;

-- fn_staff_listar_clientes(p_restaurant_id uuid, p_camarero_id uuid)
drop function if exists public.fn_staff_listar_clientes(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_staff_listar_clientes(p_restaurant_id uuid, p_camarero_id uuid)
 RETURNS TABLE(id uuid, telefono text, nombre text, puntos integer, gasto_acumulado numeric, ultima_visita timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  return query
    select c.id, c.telefono, c.nombre, c.puntos, c.gasto_acumulado, c.ultima_visita, c.updated_at
    from clientes c
    where c.restaurant_id = p_restaurant_id
    order by c.puntos desc;
end;
$function$;

revoke all on function public.fn_staff_listar_clientes(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_staff_listar_clientes(uuid, uuid) to anon, authenticated, service_role;

-- fn_staff_historial_cliente(p_restaurant_id uuid, p_camarero_id uuid, p_cliente_id uuid)
drop function if exists public.fn_staff_historial_cliente(uuid, uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_staff_historial_cliente(p_restaurant_id uuid, p_camarero_id uuid, p_cliente_id uuid)
 RETURNS TABLE(id uuid, tipo text, puntos integer, motivo text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  return query
    select m.id, m.tipo, m.puntos, m.motivo, m.created_at
    from clientes_movimientos m
    join clientes c on c.id = m.cliente_id
    where c.id = p_cliente_id and c.restaurant_id = p_restaurant_id
    order by m.created_at desc;
end;
$function$;

revoke all on function public.fn_staff_historial_cliente(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_staff_historial_cliente(uuid, uuid, uuid) to anon, authenticated, service_role;

-- fn_staff_canjear_puntos(p_restaurant_id uuid, p_camarero_id uuid, p_cliente_id uuid, p_cantidad integer, p_motivo text)
drop function if exists public.fn_staff_canjear_puntos(uuid, uuid, uuid, integer, text, text);
CREATE OR REPLACE FUNCTION public.fn_staff_canjear_puntos(p_restaurant_id uuid, p_camarero_id uuid, p_cliente_id uuid, p_cantidad integer, p_motivo text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_puntos_actuales integer;
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'Cantidad de puntos inválida';
  end if;

  select puntos into v_puntos_actuales
  from clientes
  where id = p_cliente_id and restaurant_id = p_restaurant_id;

  if v_puntos_actuales is null then
    raise exception 'Cliente no encontrado';
  end if;

  if p_cantidad > v_puntos_actuales then
    raise exception 'Ese cliente no tiene suficientes puntos';
  end if;

  update clientes
  set puntos = puntos - p_cantidad, updated_at = now()
  where id = p_cliente_id;

  insert into clientes_movimientos (cliente_id, tipo, puntos, motivo)
  values (p_cliente_id, 'resta', p_cantidad, coalesce(nullif(trim(p_motivo), ''), 'Canje en el local'));
end;
$function$;

revoke all on function public.fn_staff_canjear_puntos(uuid, uuid, uuid, integer, text) from public, anon, authenticated;
grant execute on function public.fn_staff_canjear_puntos(uuid, uuid, uuid, integer, text) to anon, authenticated, service_role;

-- fn_staff_listar_reservas(p_restaurant_id uuid, p_camarero_id uuid)
drop function if exists public.fn_staff_listar_reservas(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_staff_listar_reservas(p_restaurant_id uuid, p_camarero_id uuid)
 RETURNS TABLE(id uuid, nombre text, telefono text, fecha date, hora time without time zone, personas integer, zona text, notas text, estado text, origen text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'reservas') then
    raise exception 'No autorizado';
  end if;

  return query
    select r.id, r.nombre, r.telefono, r.fecha, r.hora, r.personas, r.zona, r.notas, r.estado, r.origen, r.created_at
    from reservations r
    where r.restaurant_id = p_restaurant_id
    order by r.fecha, r.hora;
end;
$function$;

revoke all on function public.fn_staff_listar_reservas(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_staff_listar_reservas(uuid, uuid) to anon, authenticated, service_role;

-- fn_staff_cambiar_estado_reserva(p_restaurant_id uuid, p_camarero_id uuid, p_reserva_id uuid, p_nuevo_estado text)
drop function if exists public.fn_staff_cambiar_estado_reserva(uuid, uuid, uuid, text, text);
CREATE OR REPLACE FUNCTION public.fn_staff_cambiar_estado_reserva(p_restaurant_id uuid, p_camarero_id uuid, p_reserva_id uuid, p_nuevo_estado text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'reservas') then
    raise exception 'No autorizado';
  end if;

  if p_nuevo_estado not in ('pendiente', 'confirmada', 'cancelada', 'noshow') then
    raise exception 'Estado inválido';
  end if;

  update reservations
  set estado = p_nuevo_estado
  where id = p_reserva_id and restaurant_id = p_restaurant_id;
end;
$function$;

revoke all on function public.fn_staff_cambiar_estado_reserva(uuid, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fn_staff_cambiar_estado_reserva(uuid, uuid, uuid, text) to anon, authenticated, service_role;

-- fn_staff_crear_reserva_manual(p_restaurant_id uuid, p_camarero_id uuid, p_nombre text, p_telefono text, p_fecha date, p_hora time without time zone, p_personas integer, p_zona text, p_notas text)
drop function if exists public.fn_staff_crear_reserva_manual(uuid, uuid, text, text, date, time, integer, text, text, text);
CREATE OR REPLACE FUNCTION public.fn_staff_crear_reserva_manual(p_restaurant_id uuid, p_camarero_id uuid, p_nombre text, p_telefono text, p_fecha date, p_hora time without time zone, p_personas integer, p_zona text DEFAULT 'sin preferencia'::text, p_notas text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'reservas') then
    raise exception 'No autorizado';
  end if;

  if p_nombre is null or trim(p_nombre) = '' then raise exception 'Falta el nombre'; end if;
  if p_telefono is null or trim(p_telefono) = '' then raise exception 'Falta el teléfono'; end if;
  if p_personas is null or p_personas < 1 then raise exception 'Cantidad de personas inválida'; end if;

  insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, estado, origen)
  values (p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas,
    coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''), 'confirmada', 'manual')
  returning id into v_id;

  return v_id;
end;
$function$;

revoke all on function public.fn_staff_crear_reserva_manual(uuid, uuid, text, text, date, time, integer, text, text) from public, anon, authenticated;
grant execute on function public.fn_staff_crear_reserva_manual(uuid, uuid, text, text, date, time, integer, text, text) to anon, authenticated, service_role;

-- fn_staff_listar_pedidos_cocina(p_restaurant_id uuid, p_camarero_id uuid)
drop function if exists public.fn_staff_listar_pedidos_cocina(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_staff_listar_pedidos_cocina(p_restaurant_id uuid, p_camarero_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_result json;
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'cocina') then
    raise exception 'No autorizado';
  end if;

  select coalesce(json_agg(json_build_object(
      'id', o.id,
      'estado', o.estado,
      'tipo', o.tipo,
      'notas', o.notas,
      'created_at', o.created_at,
      'mesa_numero', t.numero,
      'mesa_zona', t.zona,
      'items', (
        select coalesce(json_agg(json_build_object(
          'id', oi.id, 'nombre', oi.nombre_snapshot, 'cantidad', oi.cantidad, 'notas', oi.notas
        )), '[]'::json)
        from order_items oi where oi.order_id = o.id
      )
    ) order by o.created_at), '[]'::json)
    into v_result
  from orders o
  left join tables t on t.id = o.table_id
  where o.restaurant_id = p_restaurant_id
    and o.estado in ('pendiente', 'preparando', 'listo');

  return v_result;
end;
$function$;

revoke all on function public.fn_staff_listar_pedidos_cocina(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_staff_listar_pedidos_cocina(uuid, uuid) to anon, authenticated, service_role;

-- fn_staff_cambiar_estado_pedido(p_restaurant_id uuid, p_camarero_id uuid, p_order_id uuid, p_nuevo_estado text)
drop function if exists public.fn_staff_cambiar_estado_pedido(uuid, uuid, uuid, text, text);
CREATE OR REPLACE FUNCTION public.fn_staff_cambiar_estado_pedido(p_restaurant_id uuid, p_camarero_id uuid, p_order_id uuid, p_nuevo_estado text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'cocina') then
    raise exception 'No autorizado';
  end if;

  if p_nuevo_estado not in ('pendiente', 'preparando', 'listo', 'entregado') then
    raise exception 'Estado inválido';
  end if;

  update orders
  set estado = p_nuevo_estado, updated_at = now()
  where id = p_order_id and restaurant_id = p_restaurant_id;
end;
$function$;

revoke all on function public.fn_staff_cambiar_estado_pedido(uuid, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fn_staff_cambiar_estado_pedido(uuid, uuid, uuid, text) to anon, authenticated, service_role;

-- fn_registrar_pedido(p_table_session_id uuid, p_items jsonb, p_notas text, p_camarero_id uuid, p_premios_canjeados jsonb, p_vale_codigo text, p_vale_importe numeric)
drop function if exists public.fn_registrar_pedido(uuid, jsonb, text, uuid, jsonb, text, numeric, text);
CREATE OR REPLACE FUNCTION public.fn_registrar_pedido(p_table_session_id uuid, p_items jsonb, p_notas text DEFAULT NULL::text, p_camarero_id uuid DEFAULT NULL::uuid, p_premios_canjeados jsonb DEFAULT '[]'::jsonb, p_vale_codigo text DEFAULT NULL::text, p_vale_importe numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_restaurant_id     uuid;
  v_table_id          uuid;
  v_modo_cocina       text;
  v_minutos_limite    int;
  v_cliente_telefono  text;
  v_restaurant_config jsonb;
  v_control_stock_activo boolean;
  v_order_id          uuid;
  v_notas_actual      text;
  v_item              jsonb;
  v_mod                jsonb;
  v_menu_item          record;
  v_order_item_id      uuid;
  v_extra              numeric;
  v_opcion_nombre      text;
  v_grupo_nombre       text;
  v_premio_item        jsonb;
  v_premio             record;
  v_cliente_id         uuid;
  v_cliente_puntos     integer;
  v_cliente_gasto      numeric;
  v_comensal_premio    int;
  v_zona                text;
  v_menu_activo_id      uuid;
  v_precio_override     numeric;
  v_receta              record;
  v_cantidad_pedida      int;
  v_vale                 record;
  v_promo_sello           record;
begin
  perform pg_advisory_xact_lock(hashtext(p_table_session_id::text));

  select ts.restaurant_id, ts.table_id, r.modo_cocina, r.minutos_limite_agrupado, ts.cliente_telefono, r.config
    into v_restaurant_id, v_table_id, v_modo_cocina, v_minutos_limite, v_cliente_telefono, v_restaurant_config
  from table_sessions ts
  join restaurants r on r.id = ts.restaurant_id
  where ts.id = p_table_session_id
    and ts.estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa % no existe o ya está cerrada', p_table_session_id;
  end if;

  v_control_stock_activo := coalesce((v_restaurant_config->>'control_stock_activo')::boolean, false);

  select zona into v_zona from tables where id = v_table_id;

  -- Menú activo para esta mesa ahora mismo: más específico gana
  -- (zona+hora+días > menos criterios), igual que en el frontend.
  -- Mismo criterio que WhatsApp: fn_menu_activo (sql/menu_activo_unico.sql).
  v_menu_activo_id := fn_menu_activo(v_restaurant_id, v_zona, now(), false);

  if v_modo_cocina = 'agrupado_mesa' then
    select id into v_order_id
    from orders
    where table_session_id = p_table_session_id
      and estado = 'pendiente'
      and created_at > now() - (v_minutos_limite || ' minutes')::interval
    order by created_at desc
    limit 1;
  end if;

  if v_order_id is null then
    insert into orders (restaurant_id, table_id, table_session_id, tipo, estado, notas, tomado_por)
    values (v_restaurant_id, v_table_id, p_table_session_id, 'mesa', 'pendiente', p_notas, p_camarero_id)
    returning id into v_order_id;
  elsif p_notas is not null and length(trim(p_notas)) > 0 then
    select notas into v_notas_actual from orders where id = v_order_id;
    if v_notas_actual is null or length(trim(v_notas_actual)) = 0 then
      update orders set notas = p_notas where id = v_order_id;
    elsif position(p_notas in v_notas_actual) = 0 then
      update orders set notas = v_notas_actual || ' · ' || p_notas where id = v_order_id;
    end if;
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, nombre, precio, precio_costo into v_menu_item
    from menu_items
    where id = (v_item->>'menu_item_id')::uuid;

    v_precio_override := null;
    if v_menu_activo_id is not null then
      select precio into v_precio_override
      from menu_item_precios_menu
      where menu_id = v_menu_activo_id
        and menu_item_id = v_menu_item.id
        and excluido = false;
    end if;

    v_cantidad_pedida := (v_item->>'cantidad')::int;

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, agregado_at, restaurant_id
    )
    values (
      v_order_id,
      v_menu_item.id,
      v_menu_item.nombre,
      coalesce(v_precio_override, v_menu_item.precio),
      v_menu_item.precio_costo,
      v_cantidad_pedida,
      v_item->>'notas',
      nullif(v_item->>'comensal', '')::int,
      now(),
      v_restaurant_id
    )
    returning id into v_order_item_id;

    if v_control_stock_activo then
      for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_menu_item.id
      loop
        update ingredientes
        set stock_actual = stock_actual - (v_receta.cantidad * v_cantidad_pedida)
        where id = v_receta.ingrediente_id;

        insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
        values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -(v_receta.cantidad * v_cantidad_pedida), v_order_id);
      end loop;
    end if;

    if v_item ? 'modificadores' then
      for v_mod in select * from jsonb_array_elements(v_item->'modificadores')
      loop
        select nombre into v_grupo_nombre from modificador_grupos where id = (v_mod->>'grupo_id')::uuid;
        select nombre into v_opcion_nombre from modificador_opciones where id = (v_mod->>'opcion_id')::uuid;

        select coalesce(precio_extra, 0) into v_extra
        from menu_item_modificador_precios
        where menu_item_id = v_menu_item.id
          and opcion_id = (v_mod->>'opcion_id')::uuid;

        insert into order_item_modificadores (
          order_item_id, grupo_id, opcion_id, grupo_nombre, opcion_nombre, precio_extra
        )
        values (
          v_order_item_id,
          (v_mod->>'grupo_id')::uuid,
          (v_mod->>'opcion_id')::uuid,
          coalesce(v_grupo_nombre, ''),
          coalesce(v_opcion_nombre, ''),
          coalesce(v_extra, 0)
        );
      end loop;
    end if;
  end loop;

  -- Canje de premios: uno por uno, para que si alguno falla (puntos
  -- insuficientes, nivel no alcanzado, sin premios de sello
  -- disponibles) todo el pedido se cancele en vez de dejar canjes a
  -- medias.
  for v_premio_item in select * from jsonb_array_elements(p_premios_canjeados)
  loop
    if v_cliente_telefono is null then
      raise exception 'No hay un cliente asociado a esta mesa para canjear premios';
    end if;

    select id, puntos, gasto_acumulado into v_cliente_id, v_cliente_puntos, v_cliente_gasto
    from clientes
    where restaurant_id = v_restaurant_id and telefono = v_cliente_telefono;

    -- ---- Premio ganado por sellos (tarjeta de "compra N, la siguiente gratis") ----
    if coalesce(v_premio_item->>'origen', 'puntos') = 'sello' then
      select ps.id, ps.nombre, ps.producto_premio_id, ps.cantidad_premio
        into v_promo_sello
      from promos_sellos ps
      where ps.id = (v_premio_item->>'premio_id')::uuid
        and ps.restaurant_id = v_restaurant_id
        and ps.activo = true;

      if v_promo_sello.id is null then
        raise exception 'Esa promoción ya no está disponible';
      end if;

      if v_cliente_id is null then
        raise exception 'No hay un cliente asociado a esta mesa para canjear premios';
      end if;

      update clientes_sellos
      set premios_disponibles = premios_disponibles - 1, updated_at = now()
      where cliente_id = v_cliente_id and promo_id = v_promo_sello.id and premios_disponibles > 0;

      if not found then
        raise exception 'No tienes premios disponibles para "%"', v_promo_sello.nombre;
      end if;

      v_comensal_premio := nullif(v_premio_item->>'comensal', '')::int;

      select nombre, precio_costo into v_menu_item
      from menu_items where id = v_promo_sello.producto_premio_id;

      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, promo_sello_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, v_promo_sello.producto_premio_id, v_menu_item.nombre, 0, v_menu_item.precio_costo, v_promo_sello.cantidad_premio,
        'Premio por sellos: ' || v_promo_sello.nombre, v_comensal_premio, v_promo_sello.id, now(), v_restaurant_id
      );

      if v_control_stock_activo then
        for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_promo_sello.producto_premio_id
        loop
          update ingredientes set stock_actual = stock_actual - (v_receta.cantidad * v_promo_sello.cantidad_premio) where id = v_receta.ingrediente_id;
          insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
          values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -(v_receta.cantidad * v_promo_sello.cantidad_premio), v_order_id);
        end loop;
      end if;

      continue;
    end if;

    -- ---- Premio por puntos (como siempre) ----
    select id, nombre, tipo, costo_puntos, menu_item_id, descuento_importe, nivel_minimo_id
      into v_premio
    from premios_fidelizacion
    where id = (v_premio_item->>'premio_id')::uuid
      and restaurant_id = v_restaurant_id
      and activo = true;

    if v_premio.id is null then
      raise exception 'Ese premio ya no está disponible';
    end if;

    if v_cliente_id is null or coalesce(v_cliente_puntos, 0) < v_premio.costo_puntos then
      raise exception 'No hay puntos suficientes para canjear "%"', v_premio.nombre;
    end if;

    if v_premio.nivel_minimo_id is not null and not exists (
      select 1 from niveles_fidelizacion nm
      where nm.id = v_premio.nivel_minimo_id and nm.umbral_gasto <= coalesce(v_cliente_gasto, 0)
    ) then
      raise exception 'Todavía no alcanzas el nivel necesario para "%"', v_premio.nombre;
    end if;

    update clientes set puntos = puntos - v_premio.costo_puntos, updated_at = now() where id = v_cliente_id;

    insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, order_id)
    values (v_cliente_id, 'resta', v_premio.costo_puntos, 'Canje: ' || v_premio.nombre, v_order_id);

    v_comensal_premio := nullif(v_premio_item->>'comensal', '')::int;

    if v_premio.tipo = 'plato_gratis' then
      select nombre, precio_costo into v_menu_item
      from menu_items where id = v_premio.menu_item_id;

      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, premio_canjeado_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, v_premio.menu_item_id, v_menu_item.nombre, 0, v_menu_item.precio_costo, 1,
        'Canjeado con puntos', v_comensal_premio, v_premio.id, now(), v_restaurant_id
      );

      if v_control_stock_activo then
        for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_premio.menu_item_id
        loop
          update ingredientes set stock_actual = stock_actual - v_receta.cantidad where id = v_receta.ingrediente_id;
          insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
          values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -v_receta.cantidad, v_order_id);
        end loop;
      end if;
    else
      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, cantidad, notas, comensal, premio_canjeado_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, null, 'Descuento fidelización: ' || v_premio.nombre, -v_premio.descuento_importe, 1,
        null, v_comensal_premio, v_premio.id, now(), v_restaurant_id
      );
    end if;
  end loop;

  -- Vale regalo: se bloquea la fila para que no se pueda gastar el
  -- mismo saldo dos veces en simultáneo desde mesas distintas.
  if p_vale_codigo is not null and p_vale_importe is not null and p_vale_importe > 0 then
    select id, saldo_actual, activo, fecha_vencimiento into v_vale
    from vales_regalo
    where restaurant_id = v_restaurant_id and upper(codigo) = upper(p_vale_codigo)
    for update;

    if v_vale.id is null then
      raise exception 'Ese vale no existe';
    end if;
    if not v_vale.activo then
      raise exception 'Ese vale ya no está activo';
    end if;
    if v_vale.fecha_vencimiento < fn_hoy_madrid() then
      raise exception 'Ese vale ya venció';
    end if;
    if p_vale_importe > v_vale.saldo_actual then
      raise exception 'El vale no tiene saldo suficiente';
    end if;

    update vales_regalo set saldo_actual = saldo_actual - p_vale_importe where id = v_vale.id;

    insert into vale_movimientos (vale_id, importe, order_id)
    values (v_vale.id, -p_vale_importe, v_order_id);

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, cantidad, notas, agregado_at, restaurant_id
    )
    values (
      v_order_id, null, 'Vale regalo: ' || upper(p_vale_codigo), -p_vale_importe, 1, null, now(), v_restaurant_id
    );
  end if;

  update orders o
  set total = coalesce((
    select sum(oi.precio_snapshot * oi.cantidad) + coalesce((
      select sum(oim.precio_extra) from order_item_modificadores oim
      join order_items oi2 on oi2.id = oim.order_item_id
      where oi2.order_id = o.id
    ), 0)
    from order_items oi where oi.order_id = o.id
  ), 0)
  where o.id = v_order_id;

  return v_order_id;
end;
$function$;

revoke all on function public.fn_registrar_pedido(uuid, jsonb, text, uuid, jsonb, text, numeric) from public, anon, authenticated;
grant execute on function public.fn_registrar_pedido(uuid, jsonb, text, uuid, jsonb, text, numeric) to anon, authenticated, service_role;

-- fn_verificar_camarero_pin(p_restaurant_id uuid, p_camarero_id uuid, p_pin text)
drop function if exists public.fn_verificar_camarero_pin(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.fn_verificar_camarero_pin(p_restaurant_id uuid, p_camarero_id uuid, p_pin text)
 RETURNS TABLE(id uuid, nombre text, permisos text[])
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_bloqueo camarero_pin_intentos;
  v_match record;
  v_nuevos_fallidos integer;
begin
  if not fn_restaurante_activo(p_restaurant_id) then
    raise exception 'Este restaurante no está disponible en este momento.';
  end if;

  select c.id, c.nombre, c.permisos, c.pin_hash into v_match
  from camareros c
  where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true;

  if v_match.id is null then
    raise exception 'Camarero no válido.';
  end if;

  select * into v_bloqueo from camarero_pin_intentos where camarero_id = p_camarero_id;

  if v_bloqueo.bloqueado_hasta is not null and v_bloqueo.bloqueado_hasta > now() then
    raise exception 'Demasiados intentos fallidos. Inténtalo de nuevo en unos minutos.';
  end if;

  if crypt(p_pin, v_match.pin_hash) = v_match.pin_hash then
    insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
    values (p_camarero_id, 0, null, now())
    on conflict (camarero_id) do update set fallidos = 0, bloqueado_hasta = null, ultimo_intento = now();

    return query select v_match.id, v_match.nombre, v_match.permisos;
    return;
  end if;

  v_nuevos_fallidos := case
    when v_bloqueo.camarero_id is null or v_bloqueo.ultimo_intento < now() - interval '5 minutes' then 1
    else v_bloqueo.fallidos + 1
  end;

  insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
  values (p_camarero_id, v_nuevos_fallidos, case when v_nuevos_fallidos >= 10 then now() + interval '5 minutes' else null end, now())
  on conflict (camarero_id) do update
    set fallidos = v_nuevos_fallidos,
        bloqueado_hasta = case when v_nuevos_fallidos >= 10 then now() + interval '5 minutes' else null end,
        ultimo_intento = now();

  return;
end;
$function$;

revoke all on function public.fn_verificar_camarero_pin(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fn_verificar_camarero_pin(uuid, uuid, text) to anon, authenticated, service_role;

-- fn_resetear_pin_camarero(p_camarero_id uuid, p_restaurant_id uuid, p_pin_nuevo text)
CREATE OR REPLACE FUNCTION public.fn_resetear_pin_camarero(p_camarero_id uuid, p_restaurant_id uuid, p_pin_nuevo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not exists (select 1 from restaurants r where r.id = p_restaurant_id and r.user_id = auth.uid())
     and not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if p_pin_nuevo !~ '^\d{4}$' then
    raise exception 'El PIN debe ser de 4 dígitos numéricos.';
  end if;
  if exists (
    select 1 from camareros c
    where c.restaurant_id = p_restaurant_id and c.id != p_camarero_id and crypt(p_pin_nuevo, c.pin_hash) = c.pin_hash
  ) then
    raise exception 'Ya existe un camarero con ese PIN en este restaurante.';
  end if;

  update camareros set pin_hash = crypt(p_pin_nuevo, gen_salt('bf'))
  where id = p_camarero_id and restaurant_id = p_restaurant_id;
end;
$function$;

revoke all on function public.fn_resetear_pin_camarero(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fn_resetear_pin_camarero(uuid, uuid, text) to authenticated, service_role;

-- 3. Tablas ----------------------------------------------------------------------
drop table if exists public.camarero_llamadas_sin_token;
drop table if exists public.camarero_sesiones;

notify pgrst, 'reload schema';

commit;
