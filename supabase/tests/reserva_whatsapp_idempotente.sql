-- =============================================================================
-- fn_reserva_whatsapp_crear idempotente con clave
-- (migración 20261113164803_reserva_whatsapp_idempotente)
-- Criterio 4 de docs/specs/2026-11-13-agente-whatsapp-revision.md (revisión)
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/reserva_whatsapp_idempotente.sql
--
-- Crea en la transacción un restaurante sin horario con dos mesas de 4 y
-- llama a la función como service_role.
--
-- Comprueba:
--   1. Con clave: crea la reserva (ya_existia = false) y guarda la clave.
--   2. La misma clave otra vez: mismo id, ya_existia = true, una sola reserva
--      (también si la hora ya está a menos de 15 min: no vuelve a validar).
--   3. Otra clave: otra reserva.
--   4. Sin clave (versión de 9 argumentos, la del agente actual): crea como
--      antes, devuelve uuid y no guarda clave; dos llamadas = dos reservas.
--   5. Las validaciones siguen en la versión con clave (0 personas).
--   6. Solo service_role puede ejecutar las dos versiones.
--
-- Resultado: una fila por comprobación (prueba, ok, detalle) + TOTAL.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

do $$
declare
  v_rest uuid;
  v_manana date := public.fn_ahora_madrid()::date + 1;
  v_r1 json;
  v_r2 json;
  v_r3 json;
  v_u1 uuid;
  v_u2 uuid;
  v_n int;
  v_err text;
begin
  insert into restaurants (nombre, slug) values ('ZZ Reserva idem', 'zz-res-idem-' || substr(gen_random_uuid()::text, 1, 8))
  returning id into v_rest;
  insert into tables (restaurant_id, numero, zona, capacidad) values (v_rest, 1, 'interior', 4), (v_rest, 2, 'interior', 4);

  set local role service_role;
  v_r1 := public.fn_reserva_whatsapp_crear(v_rest, 'Ana', '600000020', v_manana, '13:00', 2, null, null, 90, 'clave-r1');
  v_r2 := public.fn_reserva_whatsapp_crear(v_rest, 'Ana', '600000020', v_manana, '13:00', 2, null, null, 90, 'clave-r1');
  reset role;

  insert into _resultado (prueba, ok, detalle)
  select 'con clave: crea la reserva (ya_existia = false) y guarda la clave',
         (v_r1 ->> 'ya_existia')::boolean = false
         and exists (select 1 from reservations where id = (v_r1 ->> 'id')::uuid and clave_whatsapp = 'clave-r1' and origen = 'whatsapp'),
         v_r1::text;

  select count(*) into v_n from reservations where restaurant_id = v_rest;
  insert into _resultado (prueba, ok, detalle)
  values ('misma clave otra vez: mismo id, ya_existia = true y una sola reserva',
          (v_r2 ->> 'id') = (v_r1 ->> 'id') and (v_r2 ->> 'ya_existia')::boolean and v_n = 1,
          v_n || ' reservas; ' || v_r2::text);

  -- La reserva existente se devuelve aunque ya no pasara las validaciones.
  update reservations set fecha = public.fn_ahora_madrid()::date, hora = (public.fn_ahora_madrid() + interval '5 minutes')::time
  where id = (v_r1 ->> 'id')::uuid;
  set local role service_role;
  v_r2 := public.fn_reserva_whatsapp_crear(v_rest, 'Ana', '600000020', public.fn_ahora_madrid()::date,
                                           (public.fn_ahora_madrid() + interval '5 minutes')::time, 2, null, null, 90, 'clave-r1');
  reset role;
  insert into _resultado (prueba, ok, detalle)
  values ('misma clave con la hora ya a menos de 15 min: devuelve la que existe, sin error',
          (v_r2 ->> 'id') = (v_r1 ->> 'id') and (v_r2 ->> 'ya_existia')::boolean, v_r2::text);

  set local role service_role;
  v_r3 := public.fn_reserva_whatsapp_crear(v_rest, 'Luis', '600000021', v_manana, '13:00', 2, null, null, 90, 'clave-r2');
  reset role;
  insert into _resultado (prueba, ok, detalle)
  values ('otra clave: otra reserva', (v_r3 ->> 'id') <> (v_r1 ->> 'id') and not (v_r3 ->> 'ya_existia')::boolean, v_r3::text);

  set local role service_role;
  v_u1 := public.fn_reserva_whatsapp_crear(v_rest, 'Eva', '600000022', v_manana, '20:00', 2, null, null, 90);
  v_u2 := public.fn_reserva_whatsapp_crear(v_rest, 'Eva', '600000022', v_manana, '20:00', 2, null, null, 90);
  reset role;
  insert into _resultado (prueba, ok, detalle)
  select 'sin clave (9 argumentos): crea como antes, sin clave; dos llamadas = dos reservas',
         v_u1 is not null and v_u2 is not null and v_u1 <> v_u2 and count(*) = 2 and bool_and(clave_whatsapp is null),
         count(*) || ' reservas de Eva'
  from reservations where id in (v_u1, v_u2);

  begin
    set local role service_role;
    perform public.fn_reserva_whatsapp_crear(v_rest, 'Ana', '600000020', v_manana, '13:00', 0, null, null, 90, 'clave-r3');
    reset role;
    v_err := '';
  exception when others then
    reset role;
    v_err := sqlstate || ': ' || sqlerrm;
  end;
  insert into _resultado values (default, 'con clave siguen las validaciones (0 personas)', v_err like 'P0001: El número de personas%', v_err);
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'solo service_role ejecuta las dos versiones',
       not has_function_privilege('anon', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer,text)', 'execute')
       and not has_function_privilege('authenticated', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer,text)', 'execute')
       and has_function_privilege('service_role', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer,text)', 'execute')
       and not has_function_privilege('anon', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer)', 'execute')
       and not has_function_privilege('authenticated', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer)', 'execute')
       and has_function_privilege('service_role', 'public.fn_reserva_whatsapp_crear(uuid,text,text,date,time,integer,text,text,integer)', 'execute'),
       'has_function_privilege';

insert into _resultado (prueba, ok, detalle)
select 'TOTAL reserva_whatsapp_idempotente', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
