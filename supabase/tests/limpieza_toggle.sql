-- =============================================================================
-- fn_camarero_toggle_limpieza: la limpieza marcada desde el móvil del camarero
-- se guarda (migración 20261112143742_arreglar_toggle_limpieza).
-- Desde docs/specs/2026-11-12-pin-camarero.md la función exige sesión de
-- camarero: la prueba da de alta un camarero de prueba (PIN conocido, permiso
-- "limpieza") en ese restaurante, inicia sesión con fn_verificar_camarero_pin
-- y pasa p_camarero_id y p_token, como la app nueva.
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback
-- (la mesa de prueba vuelve a como estaba).
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/limpieza_toggle.sql
--
-- Usa la primera mesa activa de un restaurante con al menos 2 pasos de
-- limpieza activos. La marca como "necesita limpieza" y llama a la función
-- como anon (el camarero no tiene sesión de Supabase), con su token:
--   1. marcar el paso 1  → se guarda, la mesa sigue sucia
--   2. desmarcar paso 1  → se quita
--   3. marcar todos      → la mesa queda limpia y con todos los pasos
--
-- Resultado: una fila por comprobación (prueba, ok, detalle). Debe salir ok = true en todas.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

insert into _resultado (prueba, ok, detalle)
select 'anon, authenticated y service_role pueden ejecutarla; PUBLIC no',
       has_function_privilege('anon', p.oid, 'execute')
         and has_function_privilege('authenticated', p.oid, 'execute')
         and has_function_privilege('service_role', p.oid, 'execute')
         and not exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0),
       coalesce(p.proacl::text, 'null')
from pg_proc p
where p.oid = to_regprocedure('public.fn_camarero_toggle_limpieza(uuid, uuid, uuid, uuid, text)');

insert into _resultado (prueba, ok, detalle)
select 'existe fn_camarero_toggle_limpieza(uuid, uuid, uuid, uuid, text)',
       to_regprocedure('public.fn_camarero_toggle_limpieza(uuid, uuid, uuid, uuid, text)') is not null, '';

do $$
declare
  v_rest uuid;
  v_mesa uuid;
  v_pasos uuid[];
  v_paso uuid;
  v_prog jsonb;
  v_sucia boolean;
  v_err text;
  v_cam uuid;
  v_token text;
begin
  select lp.restaurant_id into v_rest
  from public.limpieza_pasos lp
  join public.tables t on t.restaurant_id = lp.restaurant_id and t.activa
  where lp.activo
  group by lp.restaurant_id
  having count(distinct lp.id) >= 2
  limit 1;

  if v_rest is null then
    insert into _resultado (prueba, ok, detalle) values ('datos de prueba', false, 'no hay restaurante con mesa activa y 2 pasos de limpieza');
    return;
  end if;

  select array_agg(id order by orden, id) into v_pasos
  from public.limpieza_pasos where restaurant_id = v_rest and activo;
  select id into v_mesa from public.tables where restaurant_id = v_rest and activa order by numero limit 1;

  update public.tables set necesita_limpieza = true, limpieza_progreso = '[]'::jsonb where id = v_mesa;

  -- Camarero de prueba y su sesión (como anon, igual que la app)
  insert into public.camareros (restaurant_id, nombre, permisos, pin_hash)
  values (v_rest, 'zz Prueba limpieza', '{limpieza}', extensions.crypt('4826', extensions.gen_salt('bf')))
  returning id into v_cam;
  begin
    set local role anon;
    select x.token into v_token from public.fn_verificar_camarero_pin(v_rest, v_cam, '4826') x;
    reset role;
  exception when others then
    reset role;
    v_err := sqlerrm;
  end;
  insert into _resultado (prueba, ok, detalle) values (
    '0. el camarero de prueba inicia sesión con su PIN',
    v_token is not null, coalesce(v_err, 'token ' || left(v_token, 8) || '…'));
  v_err := null;

  -- 1. marcar el paso 1 (como anon)
  begin
    set local role anon;
    perform public.fn_camarero_toggle_limpieza(v_mesa, v_rest, v_pasos[1], v_cam, v_token);
    reset role;
  exception when others then
    reset role;
    v_err := sqlerrm;
  end;
  select limpieza_progreso, necesita_limpieza into v_prog, v_sucia from public.tables where id = v_mesa;
  insert into _resultado (prueba, ok, detalle) values (
    '1. anon marca el paso 1 → se guarda y la mesa sigue sucia',
    v_err is null and v_prog = jsonb_build_array(v_pasos[1]::text) and v_sucia,
    coalesce(v_err, v_prog::text || ' sucia=' || v_sucia));

  -- 2. desmarcar el paso 1
  v_err := null;
  begin
    set local role anon;
    perform public.fn_camarero_toggle_limpieza(v_mesa, v_rest, v_pasos[1], v_cam, v_token);
    reset role;
  exception when others then
    reset role;
    v_err := sqlerrm;
  end;
  select limpieza_progreso, necesita_limpieza into v_prog, v_sucia from public.tables where id = v_mesa;
  insert into _resultado (prueba, ok, detalle) values (
    '2. anon desmarca el paso 1 → se quita',
    v_err is null and v_prog = '[]'::jsonb and v_sucia,
    coalesce(v_err, v_prog::text || ' sucia=' || v_sucia));

  -- 3. marcar todos los pasos
  v_err := null;
  begin
    set local role anon;
    foreach v_paso in array v_pasos loop
      perform public.fn_camarero_toggle_limpieza(v_mesa, v_rest, v_paso, v_cam, v_token);
    end loop;
    reset role;
  exception when others then
    reset role;
    v_err := sqlerrm;
  end;
  select limpieza_progreso, necesita_limpieza into v_prog, v_sucia from public.tables where id = v_mesa;
  insert into _resultado (prueba, ok, detalle) values (
    '3. anon marca todos los pasos → la mesa queda limpia',
    v_err is null and not v_sucia and jsonb_array_length(v_prog) = array_length(v_pasos, 1),
    coalesce(v_err, jsonb_array_length(v_prog) || ' de ' || array_length(v_pasos, 1) || ' pasos, sucia=' || v_sucia));
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL limpieza_toggle', count(*) filter (where not ok) = 0,
       count(*) filter (where not ok) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
