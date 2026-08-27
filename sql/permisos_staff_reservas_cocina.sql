-- ============================================================================
-- Segunda vuelta de permisos a la carta para el personal con PIN:
-- Reservas y Cocina. Mismo patrón que Clientes (sql/permisos_staff.sql)
-- — funciones "caja fuerte" que revisan el permiso en cada llamada.
-- Limpieza no necesita funciones nuevas: el checklist ya se podía
-- marcar de forma anónima desde que se construyó (ver
-- sql/checklist_limpieza.sql) — ahí solo falta la pantalla, no el permiso.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Reservas
-- ----------------------------------------------------------------------------
create or replace function fn_staff_listar_reservas(p_restaurant_id uuid, p_camarero_id uuid)
returns table(id uuid, nombre text, telefono text, fecha date, hora time, personas integer, zona text, notas text, estado text, origen text, created_at timestamp with time zone)
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

create or replace function fn_staff_cambiar_estado_reserva(p_restaurant_id uuid, p_camarero_id uuid, p_reserva_id uuid, p_nuevo_estado text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

create or replace function fn_staff_crear_reserva_manual(
  p_restaurant_id uuid, p_camarero_id uuid,
  p_nombre text, p_telefono text, p_fecha date, p_hora time, p_personas integer,
  p_zona text default 'sin preferencia', p_notas text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

grant execute on function fn_staff_listar_reservas(uuid, uuid) to anon, authenticated;
grant execute on function fn_staff_cambiar_estado_reserva(uuid, uuid, uuid, text) to anon, authenticated;
grant execute on function fn_staff_crear_reserva_manual(uuid, uuid, text, text, date, time, integer, text, text) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- Cocina: versión acotada (sin sectores ni estado de envío de delivery,
-- eso queda para más adelante si hace falta) — lista de pedidos activos
-- con sus platos, y avanzar/revertir estado.
-- ----------------------------------------------------------------------------
create or replace function fn_staff_listar_pedidos_cocina(p_restaurant_id uuid, p_camarero_id uuid)
returns json
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

create or replace function fn_staff_cambiar_estado_pedido(p_restaurant_id uuid, p_camarero_id uuid, p_order_id uuid, p_nuevo_estado text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
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
$$;

grant execute on function fn_staff_listar_pedidos_cocina(uuid, uuid) to anon, authenticated;
grant execute on function fn_staff_cambiar_estado_pedido(uuid, uuid, uuid, text) to anon, authenticated;
