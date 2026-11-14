-- =============================================================================
-- Contexto del agente de WhatsApp (migración 20261114095054_agente_whatsapp_contexto)
-- Criterio 13 de docs/specs/2026-11-13-agente-whatsapp-revision.md (parte de BD):
--   - fn_agente_datos_restaurante: dirección, teléfono (config.telefono_reservas
--     o restaurants.whatsapp), moneda, horario semanal en texto y el día de hoy,
--     sin depender del módulo info_restaurante (decisión 1);
--   - fn_carta_takeaway devuelve `alergenos` (decisión 2);
--   - las dos, solo service_role.
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/agente_datos_restaurante.sql
--
-- Resultado: una fila por comprobación (prueba, ok, detalle) + TOTAL.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;
create temp table _ctx (clave text primary key, id uuid) on commit drop;

-- Llama a fn_agente_datos_restaurante como service_role (la que usa n8n).
create function pg_temp.datos(p_rest uuid, p_zona text default null) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  set local role service_role;
  if p_zona is null then
    v := public.fn_agente_datos_restaurante(p_rest);
  else
    v := public.fn_agente_datos_restaurante(p_rest, p_zona);
  end if;
  reset role;
  return v;
end $$;

-- Ejecuta una sentencia con el rol dado; '' si fue bien, si no el error.
create function pg_temp.intentar(p_rol text, p_sql text) returns text
language plpgsql as $$
begin
  execute format('set local role %I', p_rol);
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlstate || ': ' || sqlerrm;
end $$;

do $$
declare
  v_rest uuid;
  v_solo_wa uuid;
  v_sin_nada uuid;
  v_usd uuid;
begin
  -- Restaurante de prueba con dirección, teléfono, horario y alérgenos,
  -- SIN el módulo info_restaurante.
  insert into restaurants (nombre, slug, direccion, whatsapp, moneda, config)
  values ('ZZ Datos WA', 'zz-datos-wa-' || substr(gen_random_uuid()::text, 1, 8), '  Calle Mayor 1, Sevilla ', '+34 600 111 222', 'EUR',
          jsonb_build_object(
            'telefono_reservas', '954 000 111',
            'horario', jsonb_build_object(
              'lunes',   jsonb_build_object('abierto', false, 'apertura', '13:00', 'cierre', '16:00'),
              'martes',  jsonb_build_object('abierto', true, 'apertura', '13:00', 'cierre', '16:00'),
              'jueves',  jsonb_build_object('abierto', true),
              'viernes', jsonb_build_object('abierto', true, 'apertura', '13:00:00', 'cierre', '16:00:00', 'apertura2', '20:00', 'cierre2', '00:30'),
              'sabado',  jsonb_build_object('abierto', true, 'apertura', '13:00', 'cierre', '16:00', 'apertura2', '20:00', 'cierre2', '23:30'),
              'domingo', jsonb_build_object('abierto', 'false'))))
  returning id into v_rest;

  -- Solo whatsapp (sin telefono_reservas), sin horario.
  insert into restaurants (nombre, slug, whatsapp, config)
  values ('ZZ Solo WA', 'zz-solo-wa-' || substr(gen_random_uuid()::text, 1, 8), '600 333 444', jsonb_build_object('telefono_reservas', '  '))
  returning id into v_solo_wa;

  -- Sin dirección, teléfono ni horario.
  insert into restaurants (nombre, slug) values ('ZZ Sin datos', 'zz-sin-datos-' || substr(gen_random_uuid()::text, 1, 8))
  returning id into v_sin_nada;

  insert into restaurants (nombre, slug, moneda) values ('ZZ USD', 'zz-usd-' || substr(gen_random_uuid()::text, 1, 8), 'USD')
  returning id into v_usd;

  insert into _ctx values ('rest', v_rest), ('solo_wa', v_solo_wa), ('sin_nada', v_sin_nada), ('usd', v_usd);

  insert into restaurant_modulos (restaurant_id, modulo_key, activo) values (v_rest, 'whatsapp', true);
  -- Texto libre del dueño (solo sale con el módulo info_restaurante, que no tiene).
  insert into restaurant_info (restaurant_id, titulo, contenido, activo) values (v_rest, 'Parking', 'Hay parking gratis', true);

  insert into menu_items (restaurant_id, nombre, precio, disponible, alergenos)
  values (v_rest, 'Tortilla de patatas', 9.50, true, '["huevos", "gluten"]'::jsonb);
  insert into menu_items (restaurant_id, nombre, precio, disponible)
  values (v_rest, 'Secreto ibérico', 14.50, true);
  insert into menu_items (restaurant_id, nombre, precio, disponible, alergenos)
  values (v_rest, 'Agotado', 5.00, false, '["lacteos"]'::jsonb);
end
$$;

-- Permisos -------------------------------------------------------------------------
insert into _resultado (prueba, ok, detalle)
select 'fn_agente_datos_restaurante: solo service_role',
       not has_function_privilege('anon', 'public.fn_agente_datos_restaurante(uuid,text)', 'execute')
       and not has_function_privilege('authenticated', 'public.fn_agente_datos_restaurante(uuid,text)', 'execute')
       and has_function_privilege('service_role', 'public.fn_agente_datos_restaurante(uuid,text)', 'execute'),
       'has_function_privilege';

insert into _resultado (prueba, ok, detalle)
select 'fn_carta_takeaway (firma nueva): solo service_role',
       not has_function_privilege('anon', 'public.fn_carta_takeaway(uuid,timestamptz)', 'execute')
       and not has_function_privilege('authenticated', 'public.fn_carta_takeaway(uuid,timestamptz)', 'execute')
       and has_function_privilege('service_role', 'public.fn_carta_takeaway(uuid,timestamptz)', 'execute'),
       'has_function_privilege';

insert into _resultado (prueba, ok, detalle)
select 'las dos con search_path = public y SECURITY DEFINER',
       bool_and(proconfig = array['search_path=public'] and prosecdef), string_agg(proname || '=' || coalesce(proconfig::text, 'null'), ', ')
from pg_proc where oid in ('public.fn_agente_datos_restaurante(uuid,text)'::regprocedure, 'public.fn_carta_takeaway(uuid,timestamptz)'::regprocedure);

insert into _resultado (prueba, ok, detalle)
select 'authenticated no puede llamar a fn_agente_datos_restaurante',
       pg_temp.intentar('authenticated', 'select public.fn_agente_datos_restaurante(''' || (select id from _ctx where clave = 'rest') || ''')') like '42501%',
       pg_temp.intentar('authenticated', 'select public.fn_agente_datos_restaurante(''' || (select id from _ctx where clave = 'rest') || ''')');

-- Datos -------------------------------------------------------------------------------
insert into _resultado (prueba, ok, detalle)
select 'dirección sin espacios sobrantes', d ->> 'direccion' = 'Calle Mayor 1, Sevilla', d ->> 'direccion'
from (select pg_temp.datos((select id from _ctx where clave = 'rest')) d) x;

insert into _resultado (prueba, ok, detalle)
select 'teléfono: config.telefono_reservas antes que whatsapp', d ->> 'telefono' = '954 000 111', d ->> 'telefono'
from (select pg_temp.datos((select id from _ctx where clave = 'rest')) d) x;

insert into _resultado (prueba, ok, detalle)
select 'teléfono: sin telefono_reservas (vacío) → restaurants.whatsapp', d ->> 'telefono' = '600 333 444', d ->> 'telefono'
from (select pg_temp.datos((select id from _ctx where clave = 'solo_wa')) d) x;

insert into _resultado (prueba, ok, detalle)
select 'sin dirección, teléfono ni horario → null (el agente dirá "no dispongo de ese dato")',
       d ? 'direccion' and d -> 'direccion' = 'null'::jsonb and d -> 'telefono' = 'null'::jsonb and d -> 'horario_texto' = 'null'::jsonb
       and d ->> 'nombre' = 'ZZ Sin datos',
       d::text
from (select pg_temp.datos((select id from _ctx where clave = 'sin_nada')) d) x;

insert into _resultado (prueba, ok, detalle)
select 'moneda: EUR y USD según el restaurante',
       (select pg_temp.datos((select id from _ctx where clave = 'rest')) ->> 'moneda') = 'EUR'
       and (select pg_temp.datos((select id from _ctx where clave = 'usd')) ->> 'moneda') = 'USD',
       (select pg_temp.datos((select id from _ctx where clave = 'usd')) ->> 'moneda');

insert into _resultado (prueba, ok, detalle)
select 'horario: sábado con dos franjas', position('Sábado: de 13:00 a 16:00 y de 20:00 a 23:30' in d ->> 'horario_texto') > 0, d ->> 'horario_texto'
from (select pg_temp.datos((select id from _ctx where clave = 'rest')) d) x;

insert into _resultado (prueba, ok, detalle)
select 'horario: lunes cerrado, martes una franja, miércoles sin horario, jueves sin horas, viernes cruza medianoche y en HH:MM, domingo cerrado',
       h like 'Lunes: cerrado' || E'\n' || 'Martes: de 13:00 a 16:00' || E'\n' || 'Miércoles: sin horario indicado' || E'\n'
              || 'Jueves: abierto, sin horas indicadas' || E'\n' || 'Viernes: de 13:00 a 16:00 y de 20:00 a 00:30' || E'\n'
              || 'Sábado: %' || E'\n' || 'Domingo: cerrado',
       h
from (select pg_temp.datos((select id from _ctx where clave = 'rest')) ->> 'horario_texto' h) x;

insert into _resultado (prueba, ok, detalle)
select 'hoy: fecha y día en hora de Madrid por defecto',
       d -> 'hoy' ->> 'fecha' = to_char(fn_hoy_madrid(), 'YYYY-MM-DD') and d ->> 'zona' = 'Europe/Madrid'
       and d -> 'hoy' ->> 'dia' = (array['lunes','martes','miércoles','jueves','viernes','sábado','domingo'])[extract(isodow from fn_hoy_madrid())::int],
       (d -> 'hoy')::text
from (select pg_temp.datos((select id from _ctx where clave = 'rest')) d) x;

insert into _resultado (prueba, ok, detalle)
select 'zona como parámetro: otra zona da su fecha; zona no válida → Europe/Madrid',
       a ->> 'zona' = 'Pacific/Kiritimati' and a -> 'hoy' ->> 'fecha' = to_char((now() at time zone 'Pacific/Kiritimati')::date, 'YYYY-MM-DD')
       and b ->> 'zona' = 'Europe/Madrid',
       (a -> 'hoy')::text || ' / ' || (b ->> 'zona')
from (select pg_temp.datos((select id from _ctx where clave = 'rest'), 'Pacific/Kiritimati') a,
             pg_temp.datos((select id from _ctx where clave = 'rest'), 'Marte/Olympus') b) x;

insert into _resultado (prueba, ok, detalle)
select 'restaurante que no existe → null', pg_temp.datos(gen_random_uuid()) is null, '';

insert into _resultado (prueba, ok, detalle)
select 'sin el módulo info_restaurante: los datos salen igual y el texto libre no',
       (select pg_temp.datos((select id from _ctx where clave = 'rest')) ->> 'telefono') is not null
       and (select count(*) from fn_info_restaurante_publica((select id from _ctx where clave = 'rest'))) = 0
       and not exists (select 1 from restaurant_modulos where restaurant_id = (select id from _ctx where clave = 'rest') and modulo_key = 'info_restaurante'),
       'fn_info_restaurante_publica: ' || (select count(*) from fn_info_restaurante_publica((select id from _ctx where clave = 'rest'))) || ' filas';

-- Carta con alérgenos -------------------------------------------------------------------
insert into _resultado (prueba, ok, detalle)
select 'fn_carta_takeaway devuelve alergenos (array del dueño) y [] si no tiene',
       (select alergenos from fn_carta_takeaway((select id from _ctx where clave = 'rest')) where nombre = 'Tortilla de patatas') = '["huevos", "gluten"]'::jsonb
       and (select alergenos from fn_carta_takeaway((select id from _ctx where clave = 'rest')) where nombre = 'Secreto ibérico') = '[]'::jsonb,
       (select string_agg(nombre || '=' || alergenos::text, '; ') from fn_carta_takeaway((select id from _ctx where clave = 'rest')));

insert into _resultado (prueba, ok, detalle)
select 'fn_carta_takeaway sigue igual en lo demás: no disponibles fuera, precio de carta',
       (select count(*) from fn_carta_takeaway((select id from _ctx where clave = 'rest'))) = 2
       and (select precio from fn_carta_takeaway((select id from _ctx where clave = 'rest')) where nombre = 'Secreto ibérico') = 14.50,
       (select count(*) from fn_carta_takeaway((select id from _ctx where clave = 'rest'))) || ' platos';

insert into _resultado (prueba, ok, detalle)
select 'service_role puede leer la carta con alérgenos (como n8n)',
       pg_temp.intentar('service_role', 'select alergenos from public.fn_carta_takeaway(''' || (select id from _ctx where clave = 'rest') || ''')') = '',
       pg_temp.intentar('service_role', 'select alergenos from public.fn_carta_takeaway(''' || (select id from _ctx where clave = 'rest') || ''')');

insert into _resultado (prueba, ok, detalle)
select 'TOTAL agente_datos_restaurante', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
