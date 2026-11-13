-- =============================================================================
-- fn_reserva_whatsapp_crear valida en BD
-- (migración 20261113114755_reserva_whatsapp_validaciones)
-- Criterio 4 de docs/specs/2026-11-13-agente-whatsapp-revision.md
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/reserva_whatsapp_validaciones.sql
--
-- Crea en la transacción dos restaurantes con una mesa de 6:
--   - A: horario de 12:00 a 16:00 todos los días (última reserva 15:00) y
--     máximo 6 personas;
--   - B: sin horario (no se comprueba) ni máximo propio (el de sus mesas, 6).
-- Llama a la función como service_role. Las fechas salen de fn_ahora_madrid().
--
-- Resultado: una fila por caso (prueba, ok, detalle) + TOTAL.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

-- Devuelve '' si se creó la reserva o 'SQLSTATE: mensaje' si no.
create function pg_temp.reservar(p_rest uuid, p_fecha date, p_hora time, p_personas int,
                                 p_nombre text default 'Ana', p_notas text default null) returns text
language plpgsql as $$
begin
  set local role service_role;
  perform public.fn_reserva_whatsapp_crear(p_rest, p_nombre, '600000002', p_fecha, p_hora, p_personas,
                                           null, p_notas, 90);
  reset role;
  return '';
exception when others then
  reset role;
  return sqlstate || ': ' || sqlerrm;
end $$;

do $$
declare
  v_a uuid;
  v_b uuid;
  v_horario jsonb := '{}'::jsonb;
  v_dia text;
  v_ahora timestamp := public.fn_ahora_madrid();
  v_manana date := (public.fn_ahora_madrid())::date + 1;
  v_err text;
  v_antes int;
  v_n int;
  v_ts timestamp;
begin
  foreach v_dia in array array['lunes','martes','miercoles','jueves','viernes','sabado','domingo'] loop
    v_horario := v_horario || jsonb_build_object(v_dia, jsonb_build_object('abierto', true, 'apertura', '12:00', 'cierre', '16:00'));
  end loop;

  insert into restaurants (nombre, slug, config)
  values ('ZZ Reservas A', 'zz-res-a-' || substr(gen_random_uuid()::text, 1, 8),
          jsonb_build_object('horario', v_horario, 'reservas_max_personas', '6', 'reservas_minutos_antes_cierre', 60))
  returning id into v_a;
  insert into restaurants (nombre, slug) values ('ZZ Reservas B', 'zz-res-b-' || substr(gen_random_uuid()::text, 1, 8))
  returning id into v_b;
  insert into tables (restaurant_id, numero, zona, capacidad) values (v_a, 1, 'interior', 6), (v_b, 1, 'interior', 6);

  select count(*) into v_antes from reservations where restaurant_id in (v_a, v_b);

  -- Rechazos ----------------------------------------------------------------
  v_err := pg_temp.reservar(v_a, v_manana - 2, '13:00', 2);
  insert into _resultado values (default, 'rechaza fecha pasada (ayer)', v_err like 'P0001: Esa fecha y hora ya han pasado%', v_err);

  v_ts := v_ahora - interval '1 minute';
  v_err := pg_temp.reservar(v_b, v_ts::date, v_ts::time, 2);
  insert into _resultado values (default, 'rechaza hora de hoy ya pasada', v_err like 'P0001: Esa fecha y hora ya han pasado%', v_err);

  v_ts := v_ahora + interval '5 minutes';
  v_err := pg_temp.reservar(v_b, v_ts::date, v_ts::time, 2);
  insert into _resultado values (default, 'rechaza con menos de 15 min de antelación (+5 min, Madrid)',
                                 v_err like 'P0001: Para reservar hoy necesitamos al menos 15 minutos%', v_err);

  v_err := pg_temp.reservar(v_a, v_manana, '18:00', 2);
  insert into _resultado values (default, 'rechaza fuera de horario (18:00, abre de 12 a 16)',
                                 v_err like 'P0001: Lo sentimos, el restaurante no está abierto a las 18:00%', v_err);

  v_err := pg_temp.reservar(v_a, v_manana, '15:30', 2);
  insert into _resultado values (default, 'rechaza después de la última reserva (15:30, última 15:00)',
                                 v_err like 'P0001: Lo sentimos, a las 15:30 ya no admitimos reservas%', v_err);

  v_err := pg_temp.reservar(v_a, v_manana, '13:00', 0);
  insert into _resultado values (default, 'rechaza 0 personas', v_err like 'P0001: El número de personas no es válido%', v_err);

  v_err := pg_temp.reservar(v_a, v_manana, '13:00', 7);
  insert into _resultado values (default, 'rechaza 7 personas (máximo 6 del panel)', v_err like 'P0001: Por WhatsApp podemos reservar como máximo para 6%', v_err);

  v_err := pg_temp.reservar(v_b, v_manana, '13:00', 7);
  insert into _resultado values (default, 'rechaza 7 personas sin máximo propio (mesa mayor, 6)', v_err like 'P0001: Por WhatsApp podemos reservar como máximo para 6%', v_err);

  v_err := pg_temp.reservar(v_a, v_manana, '13:00', 2, repeat('x', 101));
  insert into _resultado values (default, 'rechaza nombre de 101 caracteres', v_err like 'P0001: El nombre es demasiado largo%', v_err);

  v_err := pg_temp.reservar(v_a, v_manana, '13:00', 2, '   ');
  insert into _resultado values (default, 'rechaza nombre vacío', v_err like 'P0001: Falta el nombre%', v_err);

  v_err := pg_temp.reservar(v_a, v_manana, '13:00', 2, 'Ana', repeat('x', 501));
  insert into _resultado values (default, 'rechaza notas de 501 caracteres', v_err like 'P0001: Las notas son demasiado largas%', v_err);

  v_err := pg_temp.reservar(v_a, null, '13:00', 2);
  insert into _resultado values (default, 'rechaza sin fecha', v_err like 'P0001: Falta la fecha o la hora%', v_err);

  select count(*) into v_n from reservations where restaurant_id in (v_a, v_b);
  insert into _resultado values (default, 'los rechazos no insertan nada', v_n = v_antes, 'antes=' || v_antes || ', después=' || v_n);

  -- Datos correctos: como hoy -----------------------------------------------
  v_err := pg_temp.reservar(v_a, v_manana, '13:00', 6, 'Ana', 'Trona');
  insert into _resultado (prueba, ok, detalle)
  select 'datos correctos (mañana 13:00, 6 pers.): crea la reserva confirmada de WhatsApp',
         v_err = '' and count(*) = 1 and bool_and(estado = 'confirmada' and origen = 'whatsapp' and personas = 6
                                                  and nombre = 'Ana' and notas = 'Trona' and zona = 'sin preferencia'),
         coalesce(nullif(v_err, ''), count(*) || ' reservas')
  from reservations where restaurant_id = v_a;

  v_ts := v_ahora + interval '20 minutes';
  v_err := pg_temp.reservar(v_b, v_ts::date, date_trunc('minute', v_ts)::time, 2);
  insert into _resultado values (default, 'hoy con 20 min de antelación (sin horario): la crea', v_err = '',
                                 coalesce(nullif(v_err, ''), 'sin error'));

  -- Disponibilidad: la única mesa ya está ocupada a las 13:00.
  v_err := pg_temp.reservar(v_a, v_manana, '13:30', 2);
  insert into _resultado values (default, 'sigue comprobando la mesa (ocupada → sin disponibilidad)',
                                 v_err like 'P0001: Ya no hay disponibilidad%', v_err);
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'solo service_role puede ejecutarla',
       not has_function_privilege('anon', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer)', 'execute')
       and not has_function_privilege('authenticated', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer)', 'execute')
       and has_function_privilege('service_role', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer)', 'execute'),
       'anon/authenticated sin EXECUTE';

insert into _resultado (prueba, ok, detalle)
select 'TOTAL reserva_whatsapp_validaciones', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
