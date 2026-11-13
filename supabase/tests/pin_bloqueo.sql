-- =============================================================================
-- Bloqueo progresivo del PIN del camarero
-- (migración 20261113082049_pin_bloqueo_progresivo).
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/pin_bloqueo.sql
--
-- Usa el primer camarero activo de un restaurante activo con dueño. Le pone el
-- PIN 4321 (solo dentro de la transacción) y llama a fn_verificar_camarero_pin
-- como anon con el PIN 0000. Para no esperar, "adelanta el reloj" moviendo
-- ultimo_intento y bloqueado_hasta hacia atrás.
--
-- Comprueba:
--   1. 9 fallos: sin bloqueo. 10.º fallo: bloqueo de 5 min.
--   2. Bloqueado, ni el PIN correcto entra.
--   3. Siguientes tandas de 10: 30 min, 2 h, 24 h y otra vez 24 h.
--   4. Tras un bloqueo de 24 h, un fallo justo al acabar NO vuelve a 5 min.
--   5. Tras 24 h sin fallos (y sin bloqueo en ese tiempo), vuelve a 5 min.
--   6. Acertar el PIN pone el contador a cero y da token.
--   7. Cambiar el PIN desde el panel (dueño, authenticated) desbloquea.
--
-- Resultado: una fila por comprobación (prueba, ok, detalle). Debe salir ok = true en todas.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

create function pg_temp.fallar(p_rest uuid, p_cam uuid, p_veces int) returns text
language plpgsql as $$
declare
  v_err text;
begin
  for i in 1..p_veces loop
    begin
      set local role anon;
      perform public.fn_verificar_camarero_pin(p_rest, p_cam, '0000');
      reset role;
    exception when others then
      reset role;
      v_err := sqlerrm;
    end;
  end loop;
  return v_err;
end $$;

create function pg_temp.minutos_bloqueo(p_cam uuid) returns int
language sql as $$
  select coalesce(round(extract(epoch from (bloqueado_hasta - now())) / 60)::int, 0)
  from public.camarero_pin_intentos where camarero_id = p_cam
$$;

-- Adelanta el reloj: el bloqueo acaba ya y el último fallo fue hace p_hace.
create function pg_temp.terminar_bloqueo(p_cam uuid, p_hace interval) returns void
language sql as $$
  update public.camarero_pin_intentos
  set bloqueado_hasta = case when bloqueado_hasta is null then null else now() - interval '1 second' end,
      ultimo_intento = now() - p_hace
  where camarero_id = p_cam
$$;

do $$
declare
  v_rest uuid;
  v_duenio uuid;
  v_cam uuid;
  v_err text;
  v_min int;
  v_fallidos int;
  v_token text;
begin
  select r.id, r.user_id, c.id into v_rest, v_duenio, v_cam
  from public.restaurants r
  join public.camareros c on c.restaurant_id = r.id and c.activo
  where r.activo and r.user_id is not null
  order by r.created_at, c.created_at
  limit 1;

  if v_cam is null then
    insert into _resultado (prueba, ok, detalle) values ('datos de prueba', false, 'no hay restaurante activo con dueño y camarero activo');
    return;
  end if;

  update public.camareros set pin_hash = extensions.crypt('4321', extensions.gen_salt('bf')) where id = v_cam;
  delete from public.camarero_pin_intentos where camarero_id = v_cam;

  -- 1. 9 fallos sin bloqueo; el 10.º bloquea 5 min.
  v_err := pg_temp.fallar(v_rest, v_cam, 9);
  v_min := pg_temp.minutos_bloqueo(v_cam);
  insert into _resultado (prueba, ok, detalle) values ('1a. 9 fallos → sin bloqueo', v_err is null and v_min = 0, coalesce(v_err, 'bloqueo ' || v_min || ' min'));
  v_err := pg_temp.fallar(v_rest, v_cam, 1);
  v_min := pg_temp.minutos_bloqueo(v_cam);
  insert into _resultado (prueba, ok, detalle) values ('1b. 10.º fallo → bloqueo de 5 min', v_err is null and v_min = 5, coalesce(v_err, 'bloqueo ' || v_min || ' min'));

  -- 2. Bloqueado: ni el PIN correcto entra.
  v_err := null;
  begin
    set local role anon;
    perform public.fn_verificar_camarero_pin(v_rest, v_cam, '4321');
    reset role;
  exception when others then
    reset role;
    v_err := sqlerrm;
  end;
  insert into _resultado (prueba, ok, detalle) values ('2. bloqueado: el PIN correcto da "Demasiados intentos"', v_err like 'Demasiados intentos%', coalesce(v_err, 'entró'));

  -- 3. Siguientes tandas: 30 min, 2 h, 24 h, 24 h.
  perform pg_temp.terminar_bloqueo(v_cam, interval '6 minutes');
  v_err := pg_temp.fallar(v_rest, v_cam, 10);
  v_min := pg_temp.minutos_bloqueo(v_cam);
  insert into _resultado (prueba, ok, detalle) values ('3a. 20 fallos → bloqueo de 30 min', v_err is null and v_min = 30, coalesce(v_err, 'bloqueo ' || v_min || ' min'));

  perform pg_temp.terminar_bloqueo(v_cam, interval '31 minutes');
  v_err := pg_temp.fallar(v_rest, v_cam, 10);
  v_min := pg_temp.minutos_bloqueo(v_cam);
  insert into _resultado (prueba, ok, detalle) values ('3b. 30 fallos → bloqueo de 2 h', v_err is null and v_min = 120, coalesce(v_err, 'bloqueo ' || v_min || ' min'));

  perform pg_temp.terminar_bloqueo(v_cam, interval '121 minutes');
  v_err := pg_temp.fallar(v_rest, v_cam, 10);
  v_min := pg_temp.minutos_bloqueo(v_cam);
  insert into _resultado (prueba, ok, detalle) values ('3c. 40 fallos → bloqueo de 24 h', v_err is null and v_min = 1440, coalesce(v_err, 'bloqueo ' || v_min || ' min'));

  -- 4. Justo al acabar un bloqueo de 24 h (último fallo hace 24 h y 1 min),
  --    el contador NO vuelve a cero: la siguiente tanda vuelve a bloquear 24 h.
  perform pg_temp.terminar_bloqueo(v_cam, interval '24 hours 1 minute');
  v_err := pg_temp.fallar(v_rest, v_cam, 10);
  v_min := pg_temp.minutos_bloqueo(v_cam);
  select fallidos into v_fallidos from public.camarero_pin_intentos where camarero_id = v_cam;
  insert into _resultado (prueba, ok, detalle) values ('4. tras un bloqueo de 24 h, 50 fallos → otra vez 24 h (no vuelve a 5 min)', v_err is null and v_min = 1440 and v_fallidos = 50, coalesce(v_err, 'bloqueo ' || v_min || ' min, fallidos ' || v_fallidos));

  -- 5. 24 h sin fallos y sin bloqueo en ese tiempo → vuelve a empezar (5 min).
  update public.camarero_pin_intentos
  set bloqueado_hasta = now() - interval '25 hours', ultimo_intento = now() - interval '49 hours'
  where camarero_id = v_cam;
  v_err := pg_temp.fallar(v_rest, v_cam, 10);
  v_min := pg_temp.minutos_bloqueo(v_cam);
  insert into _resultado (prueba, ok, detalle) values ('5. tras 24 h sin fallos, 10 fallos → bloqueo de 5 min', v_err is null and v_min = 5, coalesce(v_err, 'bloqueo ' || v_min || ' min'));

  -- 6. Sin bloqueo, acertar el PIN pone el contador a cero y da token.
  perform pg_temp.terminar_bloqueo(v_cam, interval '6 minutes');
  v_err := null;
  begin
    set local role anon;
    select t.token into v_token from public.fn_verificar_camarero_pin(v_rest, v_cam, '4321') t;
    reset role;
  exception when others then
    reset role;
    v_err := sqlerrm;
  end;
  select fallidos into v_fallidos from public.camarero_pin_intentos where camarero_id = v_cam;
  insert into _resultado (prueba, ok, detalle) values ('6. PIN correcto → token y contador a 0', v_err is null and v_token is not null and v_fallidos = 0, coalesce(v_err, 'fallidos ' || v_fallidos || ', token ' || (v_token is not null)));

  -- 7. Bloqueado de nuevo; el dueño le cambia el PIN y queda desbloqueado.
  v_err := pg_temp.fallar(v_rest, v_cam, 10);
  v_min := pg_temp.minutos_bloqueo(v_cam);
  v_err := null;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_duenio, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_duenio::text, true);
    set local role authenticated;
    perform public.fn_resetear_pin_camarero(v_cam, v_rest, '8765');
    reset role;
  exception when others then
    reset role;
    v_err := sqlerrm;
  end;
  v_token := null;
  begin
    set local role anon;
    select t.token into v_token from public.fn_verificar_camarero_pin(v_rest, v_cam, '8765') t;
    reset role;
  exception when others then
    reset role;
    v_err := coalesce(v_err, sqlerrm);
  end;
  insert into _resultado (prueba, ok, detalle) values ('7. bloqueado (' || v_min || ' min) → el dueño cambia el PIN → entra con el nuevo', v_min > 0 and v_err is null and v_token is not null, coalesce(v_err, 'token ' || (v_token is not null)));
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL pin_bloqueo', count(*) filter (where not ok) = 0,
       count(*) filter (where not ok) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
