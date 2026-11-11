-- ============================================================================
-- Reserva web pública: comprobar el horario del restaurante.
--
-- fn_crear_reserva_web (página pública /reservar) solo comprobaba que la
-- fecha no fuese pasada: se podía reservar a cualquier hora, con el
-- restaurante cerrado, para dentro de 2 minutos o pasada la última reserva.
--
--   fn_reserva_fuera_de_horario(restaurante, fecha, hora): null si se puede
--       reservar a esa hora, o el motivo si no. Mismo criterio que el agente
--       de WhatsApp (horarioReserva en n8n) y que el formulario
--       (src/lib/horarioReservas.js):
--         - franjas de config.horario del día; una hora de madrugada (00:15)
--           vale si cae en la franja del día anterior que cruza la medianoche;
--         - última reserva: config.reservas_minutos_antes_cierre minutos
--           antes del cierre de cada franja (60 por defecto; 0 = hasta el
--           cierre);
--         - sin horario configurado no se comprueba.
--   fn_crear_reserva_web: además, para hoy, al menos 15 minutos de
--       antelación (como el agente).
--
-- Re-ejecutable. Ejecutar en staging y después en producción.
-- ============================================================================

create or replace function fn_reserva_fuera_de_horario(
  p_restaurant_id uuid,
  p_fecha date,
  p_hora time
)
returns text
language plpgsql
stable
set search_path to 'public'
as $$
declare
  v_config jsonb;
  v_horario jsonb;
  v_margen int;
  v_dias text[] := array['domingo','lunes','martes','miercoles','jueves','viernes','sabado'];
  v_dias_texto text[] := array['domingo','lunes','martes','miércoles','jueves','viernes','sábado'];
  v_dow int := extract(dow from p_fecha)::int;
  v_m int := extract(hour from p_hora)::int * 60 + extract(minute from p_hora)::int;
  v_dia jsonb;
  v_a text;
  v_c text;
  v_ini int;
  v_fin int;
  v_ultima int;
  v_abierto_ese_dia boolean := false;
  v_franjas_texto text[] := '{}';
  v_cierre_tarde int;
begin
  select config into v_config from restaurants where id = p_restaurant_id;
  v_horario := v_config -> 'horario';
  if v_horario is null or jsonb_typeof(v_horario) <> 'object' then
    return null;
  end if;

  v_margen := case
    when (v_config ->> 'reservas_minutos_antes_cierre') ~ '^\d+(\.\d+)?$'
      then floor((v_config ->> 'reservas_minutos_antes_cierre')::numeric)::int
    else 60
  end;

  -- i = 0: franjas del día de la reserva; i = 1: del día anterior (solo
  -- cuentan las que cruzan la medianoche).
  for i in 0..1 loop
    v_dia := v_horario -> v_dias[((v_dow - i + 7) % 7) + 1];
    if v_dia is null or coalesce(v_dia ->> 'abierto', 'false') <> 'true' then
      continue;
    end if;
    for j in 1..2 loop
      v_a := v_dia ->> (case j when 1 then 'apertura' else 'apertura2' end);
      v_c := v_dia ->> (case j when 1 then 'cierre' else 'cierre2' end);
      if coalesce(v_a, '') !~ '^\d{1,2}:\d{2}' or coalesce(v_c, '') !~ '^\d{1,2}:\d{2}' then
        continue;
      end if;
      v_ini := split_part(v_a, ':', 1)::int * 60 + substr(split_part(v_a, ':', 2), 1, 2)::int;
      v_fin := split_part(v_c, ':', 1)::int * 60 + substr(split_part(v_c, ':', 2), 1, 2)::int;
      if v_fin <= v_ini then v_fin := v_fin + 1440; end if;
      -- Último minuto en que se puede empezar una reserva en la franja.
      v_ultima := v_fin - greatest(v_margen, 1);

      if i = 0 then
        v_abierto_ese_dia := true;
        v_franjas_texto := v_franjas_texto || (v_a || '-' || v_c);
        if v_m >= v_ini and v_m <= v_ultima then return null; end if;
        if v_m >= v_ini and v_m < v_fin then v_cierre_tarde := coalesce(v_cierre_tarde, v_fin); end if;
      elsif v_fin > 1440 then
        if v_m + 1440 <= v_ultima then return null; end if;
        if v_m + 1440 < v_fin then v_cierre_tarde := coalesce(v_cierre_tarde, v_fin); end if;
      end if;
    end loop;
  end loop;

  if v_cierre_tarde is not null then
    return format('Lo sentimos, a las %s ya no admitimos reservas: la última es a las %s (cerramos a las %s).',
      to_char(p_hora, 'HH24:MI'),
      to_char(time '00:00' + make_interval(mins => v_cierre_tarde - v_margen), 'HH24:MI'),
      to_char(time '00:00' + make_interval(mins => v_cierre_tarde), 'HH24:MI'));
  end if;
  if not v_abierto_ese_dia then
    return format('Lo sentimos, el restaurante está cerrado el %s.', v_dias_texto[v_dow + 1]);
  end if;
  return format('Lo sentimos, el restaurante no está abierto a las %s. Nuestro horario ese día es %s.',
    to_char(p_hora, 'HH24:MI'), array_to_string(v_franjas_texto, ' y '));
end;
$$;

create or replace function fn_crear_reserva_web(
  p_restaurant_id uuid,
  p_nombre text,
  p_telefono text,
  p_fecha date,
  p_hora time without time zone,
  p_personas integer,
  p_zona text default 'sin preferencia'::text,
  p_notas text default null::text
)
returns void
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_motivo text;
begin
  if p_nombre is null or trim(p_nombre) = '' then
    raise exception 'Falta el nombre';
  end if;
  if p_telefono is null or trim(p_telefono) = '' then
    raise exception 'Falta el teléfono';
  end if;
  if p_personas is null or p_personas < 1 then
    raise exception 'Cantidad de personas inválida';
  end if;
  if p_fecha is null or p_fecha < fn_hoy_madrid() then
    raise exception 'La fecha tiene que ser hoy o más adelante';
  end if;
  if p_hora is null then
    raise exception 'Falta la hora';
  end if;
  if not exists (select 1 from restaurants where id = p_restaurant_id) then
    raise exception 'Restaurante no encontrado';
  end if;

  -- Hoy: hora no pasada y al menos 15 minutos de antelación (como el agente).
  if p_fecha + p_hora <= date_trunc('minute', fn_ahora_madrid()) then
    raise exception 'Las % de hoy ya han pasado. Elige una hora más tarde.', to_char(p_hora, 'HH24:MI');
  end if;
  if p_fecha + p_hora < date_trunc('minute', fn_ahora_madrid()) + interval '15 minutes' then
    raise exception 'Para reservar hoy necesitamos al menos 15 minutos de antelación. Elige una hora más tarde.';
  end if;

  v_motivo := fn_reserva_fuera_de_horario(p_restaurant_id, p_fecha, p_hora);
  if v_motivo is not null then
    raise exception '%', v_motivo;
  end if;

  insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, estado, origen)
  values (p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas, coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''), 'pendiente', 'web');
end;
$function$;

grant execute on function fn_crear_reserva_web(uuid, text, text, date, time, integer, text, text) to anon, authenticated;

notify pgrst, 'reload schema';
