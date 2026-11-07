-- ============================================================================
-- "Hoy", la hora y el día de la semana en hora de España en la base de datos.
--
-- La base de datos funciona en UTC: current_date, current_time y
-- extract(dow from now()) dan la fecha/hora de Londres, no la de España.
-- Entre las 00:00 y la 01:00 (02:00 en verano) "hoy" era todavía ayer, y la
-- hora iba 1-2 h atrasada. Afectaba a:
--   - fn_registrar_pedido: qué menú está activo (franja horaria y día de
--     la semana) — el menú del mediodía empezaba/terminaba 1-2 h tarde y no
--     coincidía con el que ve el cliente en la mesa — y vales caducados.
--   - fn_canjear_vale_regalo: vales caducados.
--   - fn_crear_reserva_web: reservar "para ayer" de 00:00 a 01:00/02:00.
--   - Trial, descuentos, permanencia, bajas y comisiones del CRM.
--   - crm_tareas.vence_en (valor por defecto).
--
--   1. fn_hoy_madrid(), fn_hora_madrid(), fn_ahora_madrid().
--   2. Reescribe las funciones que usan current_date, current_time o
--      extract(dow from now()) para que usen las de España (solo cambia
--      esas expresiones; el resto de cada función queda igual).
--   3. Valor por defecto de crm_tareas.vence_en.
--
-- Regla a partir de ahora: en SQL nuevo, nunca current_date/current_time;
-- usar fn_hoy_madrid()/fn_hora_madrid().
--
-- Re-ejecutable. Ejecutar en staging y después en producción.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Fecha y hora de España
-- ---------------------------------------------------------------------------

create or replace function fn_ahora_madrid()
returns timestamp without time zone
language sql
stable
set search_path to 'public'
as $$ select now() at time zone 'Europe/Madrid' $$;

create or replace function fn_hoy_madrid()
returns date
language sql
stable
set search_path to 'public'
as $$ select (now() at time zone 'Europe/Madrid')::date $$;

create or replace function fn_hora_madrid()
returns time without time zone
language sql
stable
set search_path to 'public'
as $$ select (now() at time zone 'Europe/Madrid')::time $$;

grant execute on function fn_ahora_madrid() to anon, authenticated;
grant execute on function fn_hoy_madrid() to anon, authenticated;
grant execute on function fn_hora_madrid() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Funciones existentes
-- ---------------------------------------------------------------------------

-- Se reescribe la definición vigente de cada función (CREATE OR REPLACE
-- conserva dueño y permisos). \m y \M son límites de palabra: no tocan
-- current_timestamp ni nombres que contengan current_date.
do $$
declare
  f record;
  v_def text;
  v_nueva text;
begin
  for f in
    select p.oid, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind in ('f', 'p')
      and p.proname not in ('fn_ahora_madrid', 'fn_hoy_madrid', 'fn_hora_madrid')
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
      and (p.prosrc ~* '\m(current_date|current_time)\M'
           or p.prosrc ~* '\mextract\s*\(\s*(dow|isodow)\s+from\s+now\(\)\s*\)'
           or pg_get_function_arguments(p.oid) ~* '\mcurrent_date\M')
  loop
    v_def := pg_get_functiondef(f.oid);
    v_nueva := regexp_replace(v_def, '\mcurrent_date\M', 'fn_hoy_madrid()', 'gi');
    v_nueva := regexp_replace(v_nueva, '\mcurrent_time\M', 'fn_hora_madrid()', 'gi');
    v_nueva := regexp_replace(v_nueva, '\mextract\s*\(\s*(dow|isodow)\s+from\s+now\(\)\s*\)', 'extract(\1 from fn_ahora_madrid())', 'gi');
    if v_nueva is distinct from v_def then
      execute v_nueva;
      raise notice 'Hora de España en %', f.proname;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Valores por defecto
-- ---------------------------------------------------------------------------

alter table crm_tareas alter column vence_en set default fn_hoy_madrid();

notify pgrst, 'reload schema';
