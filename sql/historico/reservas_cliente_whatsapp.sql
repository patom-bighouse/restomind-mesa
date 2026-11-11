-- ============================================================================
-- Reservas del propio cliente por WhatsApp: consultar, anular y cambiar.
--
-- El agente de WhatsApp solo podía crear reservas nuevas. Ahora el cliente
-- puede anular o cambiar (día, hora, personas, zona) SUS reservas próximas.
-- El cliente se identifica por el número de WhatsApp desde el que escribe:
-- las reservas de WhatsApp se guardan con ese número en reservations.telefono
-- y se compara normalizado (fn_normalizar_telefono), así también salen las
-- hechas desde la web o el panel con el mismo teléfono en otro formato.
--
--   fn_reserva_contexto_cliente(restaurante, telefono): json con
--       - reservas: las próximas del cliente (confirmadas o pendientes);
--       - max_personas: grupo más grande que se reserva por WhatsApp
--         (config.reservas_max_personas o, si no está, la mesa más grande);
--         los grupos mayores se remiten al teléfono del restaurante;
--       - telefono_reservas: config.telefono_reservas (para grupos).
--   fn_reserva_cliente_cancelar(restaurante, telefono, reserva): la pasa a
--       'cancelada' (deja la mesa libre) y lo anota en las notas.
--   fn_reserva_cliente_modificar(restaurante, telefono, reserva, fecha, hora,
--       personas, zona, duración, aplicar): comprueba horario y mesa libre
--       para los datos nuevos sin contar la propia reserva; con aplicar =
--       false solo comprueba. Devuelve null si se puede (o se ha hecho) y
--       el motivo si no.
--
-- Solo las llama n8n con la clave de servicio: no se dan permisos al rol
-- anónimo ni a usuarios con sesión (expondrían reservas por teléfono).
--
-- Necesita sql/reserva_web_horario.sql (fn_reserva_fuera_de_horario).
-- Re-ejecutable. Ejecutar en staging y después en producción.
-- ============================================================================

create or replace function fn_reserva_contexto_cliente(
  p_restaurant_id uuid,
  p_telefono text
)
returns json
language sql
stable
security definer
set search_path to 'public'
as $$
  select json_build_object(
    'reservas', coalesce((
      select json_agg(json_build_object(
               'id', r.id, 'nombre', r.nombre, 'fecha', r.fecha, 'hora', to_char(r.hora, 'HH24:MI'),
               'personas', r.personas, 'zona', r.zona, 'estado', r.estado
             ) order by r.fecha, r.hora)
      from (
        select * from reservations r
        where r.restaurant_id = p_restaurant_id
          and r.estado in ('confirmada', 'pendiente')
          and r.fecha + r.hora > fn_ahora_madrid()
          and fn_normalizar_telefono(r.telefono) = fn_normalizar_telefono(p_telefono)
          and coalesce(fn_normalizar_telefono(p_telefono), '') <> ''
        order by r.fecha, r.hora
        limit 5
      ) r
    ), '[]'::json),
    'max_personas', (
      select case
        when (rs.config ->> 'reservas_max_personas') ~ '^\d+$' and (rs.config ->> 'reservas_max_personas')::int > 0
          then (rs.config ->> 'reservas_max_personas')::int
        else (select max(t.capacidad) from tables t where t.restaurant_id = p_restaurant_id and t.activa = true)
      end
      from restaurants rs where rs.id = p_restaurant_id
    ),
    'telefono_reservas', (
      select nullif(trim(rs.config ->> 'telefono_reservas'), '') from restaurants rs where rs.id = p_restaurant_id
    )
  )
$$;

-- Reserva del cliente, próxima y activa, bloqueada para cambiarla.
create or replace function fn_reserva_cliente_bloquear(
  p_restaurant_id uuid,
  p_telefono text,
  p_reserva_id uuid
)
returns reservations
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_res reservations;
begin
  select * into v_res from reservations
  where id = p_reserva_id
    and restaurant_id = p_restaurant_id
    and estado in ('confirmada', 'pendiente')
    and fecha + hora > fn_ahora_madrid()
    and fn_normalizar_telefono(telefono) = fn_normalizar_telefono(p_telefono)
    and coalesce(fn_normalizar_telefono(p_telefono), '') <> ''
  for update;
  if v_res.id is null then
    raise exception 'No encuentro esa reserva: puede que ya esté anulada o que ya haya pasado.' using errcode = 'P0001';
  end if;
  return v_res;
end;
$$;

create or replace function fn_reserva_cliente_cancelar(
  p_restaurant_id uuid,
  p_telefono text,
  p_reserva_id uuid
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_res reservations;
begin
  v_res := fn_reserva_cliente_bloquear(p_restaurant_id, p_telefono, p_reserva_id);
  update reservations
  set estado = 'cancelada',
      notas = concat_ws(' | ', nullif(notas, ''),
                'Anulada por el cliente por WhatsApp el ' || to_char(fn_ahora_madrid(), 'DD/MM HH24:MI'))
  where id = v_res.id;
end;
$$;

create or replace function fn_reserva_cliente_modificar(
  p_restaurant_id uuid,
  p_telefono text,
  p_reserva_id uuid,
  p_fecha date,
  p_hora time,
  p_personas integer,
  p_zona text,
  p_duracion_minutos integer,
  p_aplicar boolean default false
)
returns text
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_res reservations;
  v_motivo text;
  v_libre boolean;
  v_zona text := coalesce(nullif(trim(p_zona), ''), 'sin preferencia');
begin
  if p_fecha is null or p_hora is null or p_personas is null or p_personas < 1 then
    return 'Faltan datos para cambiar la reserva.';
  end if;

  -- Mismo bloqueo que fn_reserva_whatsapp_crear (restaurante + día), para
  -- el día nuevo y el de antes, en orden fijo para no bloquearse entre sí.
  perform pg_advisory_xact_lock(hashtext(p_restaurant_id::text || d::text))
  from (
    select distinct d from unnest(array[p_fecha, (select fecha from reservations where id = p_reserva_id)]) d
    where d is not null order by d
  ) x;

  v_res := fn_reserva_cliente_bloquear(p_restaurant_id, p_telefono, p_reserva_id);

  if p_fecha + p_hora <= date_trunc('minute', fn_ahora_madrid()) + interval '15 minutes' then
    return 'Para hoy necesitamos al menos 15 minutos de antelación.';
  end if;

  v_motivo := fn_reserva_fuera_de_horario(p_restaurant_id, p_fecha, p_hora);
  if v_motivo is not null then
    return v_motivo;
  end if;

  -- La disponibilidad se comprueba sin contar la propia reserva: se marca
  -- un momento como cancelada y se deja como estaba (todo dentro de esta
  -- transacción, nadie más lo ve).
  update reservations set estado = 'cancelada' where id = v_res.id;
  v_libre := fn_reserva_hay_mesa(p_restaurant_id, p_fecha, p_hora, p_personas, v_zona, coalesce(p_duracion_minutos, 120));

  if not v_libre then
    update reservations set estado = v_res.estado where id = v_res.id;
    return format('Lo sentimos, no tenemos mesa libre el %s a las %s para %s personas%s.',
      to_char(p_fecha, 'DD/MM'), to_char(p_hora, 'HH24:MI'), p_personas,
      case when v_zona <> 'sin preferencia' then ' en ' || v_zona else '' end);
  end if;

  if not p_aplicar then
    update reservations set estado = v_res.estado where id = v_res.id;
    return null;
  end if;

  update reservations
  set estado = v_res.estado,
      fecha = p_fecha,
      hora = p_hora,
      personas = p_personas,
      zona = v_zona,
      duracion_minutos = coalesce(p_duracion_minutos, duracion_minutos),
      notas = concat_ws(' | ', nullif(notas, ''),
                format('Cambiada por el cliente por WhatsApp el %s (antes: %s %s, %s pers., %s)',
                  to_char(fn_ahora_madrid(), 'DD/MM HH24:MI'),
                  to_char(v_res.fecha, 'DD/MM'), to_char(v_res.hora, 'HH24:MI'), v_res.personas,
                  coalesce(v_res.zona, 'sin preferencia')))
  where id = v_res.id;
  return null;
end;
$$;

revoke all on function fn_reserva_contexto_cliente(uuid, text) from public, anon, authenticated;
revoke all on function fn_reserva_cliente_bloquear(uuid, text, uuid) from public, anon, authenticated;
revoke all on function fn_reserva_cliente_cancelar(uuid, text, uuid) from public, anon, authenticated;
revoke all on function fn_reserva_cliente_modificar(uuid, text, uuid, date, time, integer, text, integer, boolean) from public, anon, authenticated;
grant execute on function fn_reserva_contexto_cliente(uuid, text) to service_role;
grant execute on function fn_reserva_cliente_cancelar(uuid, text, uuid) to service_role;
grant execute on function fn_reserva_cliente_modificar(uuid, text, uuid, date, time, integer, text, integer, boolean) to service_role;
grant execute on function fn_reserva_cliente_bloquear(uuid, text, uuid) to service_role;

notify pgrst, 'reload schema';
