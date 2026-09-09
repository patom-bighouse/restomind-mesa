-- ============================================================================
-- Cierra del todo la fuga de table_sessions: hasta ahora, la política
-- "anon_select_open_sessions" (estado = 'abierta', sin ningún otro
-- filtro) permitía a cualquiera con la clave anon listar teléfono y
-- nombre de TODOS los clientes con una mesa abierta en TODA la
-- plataforma, con una sola petición REST — sin pasar por la app.
--
-- Se reemplaza el acceso directo a la tabla por funciones
-- SECURITY DEFINER (mismo patrón que ya usa fn_estado_sesion_mesa):
-- el qr_token de la mesa (ya protegido, ver
-- fix_seguridad_anon_columnas.sql) hace de credencial real para el
-- cliente; restaurant_id/camarero_id siguen el mismo modelo de
-- confianza que ya usa el resto del modo camarero.
--
-- Como la política de SELECT que se elimina es la misma que usaba el
-- Realtime de table_sessions en Mesa.jsx/Camarero.jsx, ese Realtime
-- deja de recibir eventos para esa tabla — se reemplaza por sondeo
-- (poll) cada pocos segundos vía estas mismas funciones, código aparte
-- en este mismo commit.
-- ============================================================================

-- Para el cliente (Mesa.jsx): la sesión abierta de SU mesa, validando
-- el qr_token — nadie puede leer la sesión de otra mesa sin conocer
-- su token.
create or replace function fn_sesion_abierta_por_token(p_qr_token text)
returns table(id uuid, estado text, abierta_at timestamptz, cliente_telefono text, cliente_nombre text, comensales integer)
language sql
stable
security definer
set search_path to 'public'
as $$
  select ts.id, ts.estado, ts.abierta_at, ts.cliente_telefono, ts.cliente_nombre, ts.comensales
  from table_sessions ts
  join tables t on t.id = ts.table_id
  where t.qr_token = p_qr_token and ts.estado = 'abierta'
  order by ts.abierta_at desc
  limit 1
$$;

grant execute on function fn_sesion_abierta_por_token(text) to anon, authenticated;

-- Para el camarero: todas las sesiones abiertas de su restaurante
-- (igual alcance que ya tenía, solo que ahora pasa por una función en
-- vez de una lectura directa sin ningún filtro).
create or replace function fn_camarero_listar_sesiones(p_restaurant_id uuid)
returns table(id uuid, table_id uuid, comensales integer, camarero_id uuid, cliente_telefono text, cliente_nombre text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select ts.id, ts.table_id, ts.comensales, ts.camarero_id, ts.cliente_telefono, ts.cliente_nombre
  from table_sessions ts
  where ts.restaurant_id = p_restaurant_id and ts.estado = 'abierta'
$$;

grant execute on function fn_camarero_listar_sesiones(uuid) to anon, authenticated;

-- Abrir una mesa sin sesión (modo camarero). Valida que la mesa sea
-- de ese restaurante y que el camarero exista/esté activo antes de
-- crear la fila.
create or replace function fn_camarero_abrir_mesa(p_table_id uuid, p_restaurant_id uuid, p_camarero_id uuid, p_comensales integer)
returns table(id uuid, table_id uuid, comensales integer, camarero_id uuid, cliente_telefono text, cliente_nombre text)
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

grant execute on function fn_camarero_abrir_mesa(uuid, uuid, uuid, integer) to anon, authenticated;

-- Tomar una mesa que ya estaba abierta (desde el Dashboard, o soltada
-- por otro camarero) sin dueño asignado todavía.
create or replace function fn_camarero_tomar_mesa(p_table_session_id uuid, p_restaurant_id uuid, p_camarero_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

grant execute on function fn_camarero_tomar_mesa(uuid, uuid, uuid) to anon, authenticated;

-- El camarero carga/edita el teléfono y nombre del cliente en la
-- sesión (para fidelización), desde su propia pantalla.
create or replace function fn_camarero_editar_cliente_sesion(p_table_session_id uuid, p_restaurant_id uuid, p_camarero_id uuid, p_telefono text, p_nombre text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

grant execute on function fn_camarero_editar_cliente_sesion(uuid, uuid, uuid, text, text) to anon, authenticated;

-- Ya no hace falta que anon toque table_sessions directo para nada —
-- todo pasa por las funciones de arriba (más fn_registrar_pedido,
-- fn_registrar_cliente_sesion y fn_estado_sesion_mesa, que ya
-- funcionaban así desde antes).
drop policy if exists anon_select_open_sessions on table_sessions;
drop policy if exists anon_insert_table_sessions on table_sessions;
drop policy if exists anon_update_table_sessions on table_sessions;

revoke all on table table_sessions from anon;

notify pgrst, 'reload schema';
