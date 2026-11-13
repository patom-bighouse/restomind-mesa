-- =============================================================================
-- Conversaciones de WhatsApp borradas a los 30 días sin actividad
-- (migración 20261113114758_whatsapp_limpieza_sesiones)
-- Criterio 8 de docs/specs/2026-11-13-agente-whatsapp-revision.md (parte sql)
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback
-- (el borrado de las sesiones antiguas de Test también se deshace).
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/whatsapp_limpieza_sesiones.sql
--
-- Crea un restaurante con take away, tres sesiones (31 días, 29 días y hoy) y
-- un pedido y una reserva del teléfono de la sesión de 31 días. Llama a
-- fn_whatsapp_mensaje_nuevo como service_role (con wamid y sin wamid).
--
-- Resultado: una fila por comprobación (prueba, ok, detalle) + TOTAL.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

do $$
declare
  v_rest uuid;
  v_order uuid;
  v_res uuid;
  v_order_antes text;
  v_res_antes text;
  v_nuevo boolean;
begin
  insert into restaurants (nombre, slug) values ('ZZ Limpieza WA', 'zz-limp-wa-' || substr(gen_random_uuid()::text, 1, 8))
  returning id into v_rest;
  insert into restaurant_modulos (restaurant_id, modulo_key, activo) values (v_rest, 'takeaway_delivery', true);

  insert into whatsapp_sessions (restaurant_id, telefono, contexto, updated_at) values
    (v_rest, '34600000031', '{"historial": [{"de": "cliente", "texto": "soy alérgico"}]}', now() - interval '31 days'),
    (v_rest, '34600000029', '{}', now() - interval '29 days'),
    (v_rest, '34600000000', '{}', now());

  insert into orders (restaurant_id, tipo, estado, cliente_telefono, total) values (v_rest, 'takeaway', 'entregado', '34600000031', 0)
  returning id into v_order;
  insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, estado)
  values (v_rest, 'Ana', '34600000031', current_date - 40, '13:00', 2, 'confirmada')
  returning id into v_res;

  select row(o.*)::text into v_order_antes from orders o where id = v_order;
  select row(r.*)::text into v_res_antes from reservations r where id = v_res;

  -- Mensaje nuevo (cualquier cliente, cualquier restaurante).
  set local role service_role;
  v_nuevo := public.fn_whatsapp_mensaje_nuevo('wamid.zz-prueba-' || gen_random_uuid(), v_rest);
  reset role;

  insert into _resultado (prueba, ok, detalle) values
    ('sigue detectando mensajes nuevos', v_nuevo, coalesce(v_nuevo::text, 'null'));

  insert into _resultado (prueba, ok, detalle)
  select 'sesión de hace 31 días: borrada', count(*) = 0, count(*) || ' filas'
  from whatsapp_sessions where restaurant_id = v_rest and telefono = '34600000031';

  insert into _resultado (prueba, ok, detalle)
  select 'sesiones de hace 29 días y de hoy: se quedan', count(*) = 2, string_agg(telefono, ', ')
  from whatsapp_sessions where restaurant_id = v_rest and telefono in ('34600000029', '34600000000');

  insert into _resultado (prueba, ok, detalle)
  select 'ninguna sesión de más de 30 días en toda la tabla', count(*) = 0, count(*) || ' filas'
  from whatsapp_sessions where updated_at < now() - interval '30 days';

  insert into _resultado (prueba, ok, detalle) values
    ('el pedido de ese teléfono no cambia',
     (select row(o.*)::text from orders o where id = v_order) is not distinct from v_order_antes, ''),
    ('la reserva de ese teléfono no cambia',
     (select row(r.*)::text from reservations r where id = v_res) is not distinct from v_res_antes, '');

  -- Sin wamid también limpia.
  -- (el trigger sessions_updated_at pone now() en los UPDATE: se fuerza sin él)
  alter table whatsapp_sessions disable trigger sessions_updated_at;
  update whatsapp_sessions set updated_at = now() - interval '31 days' where restaurant_id = v_rest and telefono = '34600000029';
  alter table whatsapp_sessions enable trigger sessions_updated_at;

  set local role service_role;
  perform public.fn_whatsapp_mensaje_nuevo(null, v_rest);
  reset role;

  insert into _resultado (prueba, ok, detalle)
  select 'mensaje sin wamid: también borra las de más de 30 días', count(*) = 0, count(*) || ' filas'
  from whatsapp_sessions where restaurant_id = v_rest and telefono = '34600000029';
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'fn_whatsapp_mensaje_nuevo: solo service_role',
       not has_function_privilege('anon', 'public.fn_whatsapp_mensaje_nuevo(text,uuid)', 'execute')
       and not has_function_privilege('authenticated', 'public.fn_whatsapp_mensaje_nuevo(text,uuid)', 'execute')
       and has_function_privilege('service_role', 'public.fn_whatsapp_mensaje_nuevo(text,uuid)', 'execute'),
       'has_function_privilege';

insert into _resultado (prueba, ok, detalle)
select 'TOTAL whatsapp_limpieza_sesiones', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
