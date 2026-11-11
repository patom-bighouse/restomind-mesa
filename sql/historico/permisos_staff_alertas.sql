-- ============================================================================
-- Avisos en la pantalla de personal con PIN: cuántas mesas esperan
-- limpieza y cuántas llamadas al camarero hay pendientes, para que
-- aparezcan en cuanto entra en sus opciones (antes de elegir sección).
-- anon no tiene lectura de waiter_calls (solo puede insertar su propia
-- llamada), así que hace falta pasar por la caja fuerte para leerlas.
-- ============================================================================

create or replace function fn_staff_contar_alertas(p_restaurant_id uuid, p_camarero_id uuid)
returns json
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

-- Detalle de las llamadas pendientes (con número de mesa), para el
-- aviso dentro de la sección Pedidos, y su marcado como atendida.
create or replace function fn_staff_listar_llamadas(p_restaurant_id uuid, p_camarero_id uuid)
returns table(id uuid, table_id uuid, mesa_numero integer, created_at timestamp with time zone)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  return query
    select w.id, w.table_id, t.numero, w.created_at
    from waiter_calls w
    join tables t on t.id = w.table_id
    where w.restaurant_id = p_restaurant_id and w.estado = 'pendiente'
    order by w.created_at;
end;
$$;

create or replace function fn_staff_marcar_llamada_atendida(p_restaurant_id uuid, p_camarero_id uuid, p_llamada_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  update waiter_calls set estado = 'atendido'
  where id = p_llamada_id and restaurant_id = p_restaurant_id;
end;
$$;

grant execute on function fn_staff_contar_alertas(uuid, uuid) to anon, authenticated;
grant execute on function fn_staff_listar_llamadas(uuid, uuid) to anon, authenticated;
grant execute on function fn_staff_marcar_llamada_atendida(uuid, uuid, uuid) to anon, authenticated;
