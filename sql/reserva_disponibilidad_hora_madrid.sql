-- ============================================================================
-- Disponibilidad de mesas para reservas en hora de España.
--
-- fn_reserva_hay_mesa (la usan el agente de WhatsApp y la creación atómica
-- fn_reserva_whatsapp_crear) comparaba la hora de la reserva (hora local)
-- con horas sacadas en UTC, que es la zona de la base de datos:
--   - extract(hour from ts.abierta_at): una mesa abierta a las 21:00 en
--     España contaba como abierta a las 20:00 (invierno) o 19:00 (verano).
--   - current_date: entre las 00:00 y la 01:00/02:00 "hoy" era ayer y no se
--     contaban las mesas ocupadas.
-- Además:
--   - Cruce de medianoche: una mesa abierta a las 23:30, o una reserva de
--     ayer a las 23:30, no bloqueaba una reserva de las 00:15.
--   - Una mesa abierta más tiempo del estimado (90-180 min según
--     comensales) se daba por libre aunque siguiera ocupada. Ahora, si la
--     sesión sigue abierta, se cuenta ocupada al menos hasta dentro de
--     30 minutos.
--
-- Todo se calcula en minutos desde la medianoche (hora de España) del día
-- de la reserva, así los días anterior y siguiente encajan solos.
--
-- Re-ejecutable. Ejecutar en staging y después en producción.
-- ============================================================================

create or replace function fn_reserva_hay_mesa(
  p_restaurant_id uuid,
  p_fecha date,
  p_hora time without time zone,
  p_personas integer,
  p_zona text,
  p_duracion_minutos integer
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  -- Minutos de una sesión que sigue abierta: aunque haya superado la
  -- duración estimada, se cuenta ocupada al menos hasta ahora + este margen.
  c_margen_sesion_abierta constant integer := 30;
  v_inicio integer;
  v_fin integer;
  v_ahora integer;
  v_candidatas uuid[];
  v_ocup record;
  v_elegida uuid;
begin
  v_inicio := extract(hour from p_hora)::int * 60 + extract(minute from p_hora)::int;
  v_fin := v_inicio + p_duracion_minutos;
  -- "Ahora" en minutos desde la medianoche (España) del día de la reserva:
  -- negativo si la reserva es de un día futuro, > 1440 si fuera pasado.
  v_ahora := floor(extract(epoch from ((now() at time zone 'Europe/Madrid') - p_fecha::timestamp)) / 60)::int;

  -- Mesas que individualmente caben el grupo, de la zona pedida (o
  -- todas si "sin preferencia"/null), ordenadas de menor a mayor
  -- capacidad: así el hueco libre más ajustado se gasta primero y no
  -- se "quema" una mesa grande en un grupo pequeño sin necesidad.
  select array_agg(id order by capacidad asc) into v_candidatas
  from tables
  where restaurant_id = p_restaurant_id
    and activa = true
    and capacidad >= p_personas
    and (p_zona is null or p_zona = 'sin preferencia' or zona = p_zona);

  if v_candidatas is null or array_length(v_candidatas, 1) = 0 then
    return false;
  end if;

  -- Demanda ya existente que se solapa con la franja pedida: otras
  -- reservas confirmadas (sin mesa fija — se les asigna por tamaño, de
  -- mayor a menor), incluidas las del día anterior y siguiente que
  -- cruzan la medianoche, y sesiones de mesa abiertas (mesa fija conocida).
  for v_ocup in (
    select x.tam, x.mesa_fija
    from (
      select r.personas as tam, null::uuid as mesa_fija,
             (r.fecha - p_fecha) * 1440
               + extract(hour from r.hora)::int * 60 + extract(minute from r.hora)::int as ini,
             coalesce(r.duracion_minutos, 120) as dur
      from reservations r
      where r.restaurant_id = p_restaurant_id
        and r.fecha between p_fecha - 1 and p_fecha + 1
        and r.estado = 'confirmada'
        and (p_zona is null or p_zona = 'sin preferencia'
             or r.zona is null or r.zona = 'sin preferencia' or r.zona = p_zona)
    ) x
    where v_inicio < x.ini + x.dur and v_fin > x.ini

    union all

    select s.tam, s.mesa_fija
    from (
      select t.capacidad as tam, t.id as mesa_fija,
             floor(extract(epoch from ((ts.abierta_at at time zone 'Europe/Madrid') - p_fecha::timestamp)) / 60)::int as ini,
             -- Igual que getDuracion() en n8n (90/120/150/180 según
             -- comensales); sin comensales cargados, 150 min.
             case
               when ts.comensales is null then 150
               when ts.comensales <= 2 then 90
               when ts.comensales <= 4 then 120
               when ts.comensales <= 8 then 150
               else 180
             end as dur
      from table_sessions ts
      join tables t on t.id = ts.table_id
      where ts.restaurant_id = p_restaurant_id
        and ts.estado = 'abierta'
        and t.activa = true
        and (p_zona is null or p_zona = 'sin preferencia' or t.zona = p_zona)
    ) s
    where v_inicio < greatest(s.ini + s.dur, v_ahora + c_margen_sesion_abierta)
      and v_fin > s.ini

    order by tam desc
  )
  loop
    if v_ocup.mesa_fija is not null then
      -- Sesión de mesa: sabemos exactamente qué mesa ocupa.
      v_candidatas := array_remove(v_candidatas, v_ocup.mesa_fija);
    else
      -- Reserva sin mesa fija: le quitamos a las candidatas la más
      -- ajustada que todavía le entre.
      v_elegida := null;
      select id into v_elegida
      from tables
      where id = any(v_candidatas) and capacidad >= v_ocup.tam
      order by capacidad asc
      limit 1;
      if v_elegida is not null then
        v_candidatas := array_remove(v_candidatas, v_elegida);
      end if;
    end if;
  end loop;

  -- array_length(...) de un array vacío (tras quitarle todos los
  -- elementos con array_remove) da NULL, no 0 — con coalesce nos
  -- aseguramos de que "sin mesas candidatas" dé `false` de verdad, no
  -- NULL (que en el `if not ...` de fn_reserva_whatsapp_crear se
  -- trataría como "no lanzar la excepción", dejando pasar la reserva).
  return coalesce(array_length(v_candidatas, 1), 0) > 0;
end;
$$;

notify pgrst, 'reload schema';
