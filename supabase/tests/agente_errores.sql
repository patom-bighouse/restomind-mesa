-- =============================================================================
-- Avisos de fallos del agente de WhatsApp (migraciones 20261113114748_agente_errores
-- , 20261113121550_agente_errores_tipos_entrada y 20261113164806_agente_errores_ocultar_sb_secret)
-- Criterio 5 de docs/specs/2026-11-13-agente-whatsapp-revision.md
-- Entrega 1b: bloque de estadísticas del criterio 12
-- (fn_superadmin_estadisticas_agente, migración 20261114095057), con los días
-- en hora de España e incluyendo un aviso a las 00:30 de Madrid.
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/agente_errores.sql
--
-- Crea en la transacción dos dueños (A y B) con su restaurante y un
-- superadmin de prueba, y simula sus sesiones con `set local role
-- authenticated` y request.jwt.claims. Los avisos se registran con
-- fn_agente_registrar_error como service_role.
--
-- Resultado: una fila por comprobación (prueba, ok, detalle) + TOTAL.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;
create temp table _ctx (clave text primary key, id uuid) on commit drop;

-- Sesión simulada: p_uid null = sin sesión.
create function pg_temp.como(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
                     case when p_uid is null then '' else json_build_object('sub', p_uid, 'role', 'authenticated')::text end, true);
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
end $$;

-- Registra un aviso como service_role.
create function pg_temp.registrar(p_rest uuid, p_tel text, p_tipo text, p_detalle jsonb default null) returns uuid
language plpgsql as $$
declare v uuid;
begin
  set local role service_role;
  v := public.fn_agente_registrar_error(p_rest, p_tel, p_tipo, 'Nodo de prueba', p_detalle);
  reset role;
  return v;
end $$;

-- Ejecuta una sentencia como authenticated con la sesión dada; '' si fue bien.
create function pg_temp.intentar(p_uid uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform pg_temp.como(p_uid);
  set local role authenticated;
  execute p_sql;
  reset role;
  perform pg_temp.como(null);
  return '';
exception when others then
  reset role;
  perform pg_temp.como(null);
  return sqlstate || ': ' || sqlerrm;
end $$;

-- Cuenta filas visibles como authenticated con la sesión dada (o como anon si p_anon).
create function pg_temp.contar(p_uid uuid, p_sql text, p_anon boolean default false) returns text
language plpgsql as $$
declare n bigint;
begin
  perform pg_temp.como(p_uid);
  if p_anon then set local role anon; else set local role authenticated; end if;
  execute p_sql into n;
  reset role;
  perform pg_temp.como(null);
  return n::text;
exception when others then
  reset role;
  perform pg_temp.como(null);
  return sqlstate || ': ' || sqlerrm;
end $$;

do $$
declare
  v_a uuid := gen_random_uuid();      -- dueño A
  v_b uuid := gen_random_uuid();      -- dueño B
  v_s uuid := gen_random_uuid();      -- superadmin
  v_rest_a uuid;
  v_rest_b uuid;
begin
  insert into auth.users (id, email, aud, role, instance_id) values
    (v_a, 'zz_err_a@example.invalid', 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000'),
    (v_b, 'zz_err_b@example.invalid', 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000'),
    (v_s, 'zz_err_s@example.invalid', 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000');
  insert into superadmins (user_id, nombre) values (v_s, 'ZZ superadmin de prueba');
  insert into restaurants (nombre, slug, user_id) values ('ZZ Err A', 'zz-err-a-' || substr(v_a::text, 1, 8), v_a) returning id into v_rest_a;
  insert into restaurants (nombre, slug, user_id) values ('ZZ Err B', 'zz-err-b-' || substr(v_b::text, 1, 8), v_b) returning id into v_rest_b;
  insert into _ctx values ('a', v_a), ('b', v_b), ('s', v_s), ('rest_a', v_rest_a), ('rest_b', v_rest_b);

  insert into _ctx values
    ('e_a_visible',   pg_temp.registrar(v_rest_a, '+34 600 000 003', 'sin_respuesta', '{"error": "timeout", "clave": "sk-ant-api03-FALSA", "supabase": "sb_secret_FALSA_0000"}')),
    ('e_a_interno',   pg_temp.registrar(v_rest_a, '600000003', 'error_interno', '{"error": "x"}')),
    ('e_b_visible',   pg_temp.registrar(v_rest_b, '600000004', 'pedido_no_creado', '{"error": "y"}')),
    ('e_sin_rest',    pg_temp.registrar(null, null, 'firma_invalida', '{"motivo": "firma"}')),
    ('e_rest_falso',  pg_temp.registrar(gen_random_uuid(), '600000005', 'sin_respuesta', null));
end
$$;

-- Esquema -------------------------------------------------------------------------
insert into _resultado (prueba, ok, detalle)
select 'RLS activado en las dos tablas', bool_and(relrowsecurity), string_agg(relname || '=' || relrowsecurity, ', ')
from pg_class where oid in ('public.agente_errores'::regclass, 'public.agente_errores_detalle'::regclass);

insert into _resultado (prueba, ok, detalle)
select 'grants: authenticated solo SELECT, anon nada, service_role sin DELETE',
       has_table_privilege('authenticated', 'public.agente_errores', 'select')
       and not has_table_privilege('authenticated', 'public.agente_errores', 'insert,update,delete,truncate')
       and has_table_privilege('authenticated', 'public.agente_errores_detalle', 'select')
       and not has_table_privilege('authenticated', 'public.agente_errores_detalle', 'insert,update,delete,truncate')
       and not has_table_privilege('anon', 'public.agente_errores', 'select,insert,update,delete')
       and not has_table_privilege('anon', 'public.agente_errores_detalle', 'select,insert,update,delete')
       and has_table_privilege('service_role', 'public.agente_errores', 'select,insert,update')
       and not has_table_privilege('service_role', 'public.agente_errores', 'delete')
       and not has_table_privilege('service_role', 'public.agente_errores_detalle', 'delete'),
       'has_table_privilege';

insert into _resultado (prueba, ok, detalle)
select 'Realtime: agente_errores en supabase_realtime y el detalle no',
       exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'agente_errores')
       and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'agente_errores_detalle'),
       (select coalesce(string_agg(tablename, ', '), 'ninguna') from pg_publication_tables
        where pubname = 'supabase_realtime' and tablename like 'agente_errores%');

insert into _resultado (prueba, ok, detalle)
select 'fn_agente_registrar_error: solo service_role',
       not has_function_privilege('anon', 'public.fn_agente_registrar_error(uuid,text,text,text,jsonb)', 'execute')
       and not has_function_privilege('authenticated', 'public.fn_agente_registrar_error(uuid,text,text,text,jsonb)', 'execute')
       and has_function_privilege('service_role', 'public.fn_agente_registrar_error(uuid,text,text,text,jsonb)', 'execute'),
       'has_function_privilege';

insert into _resultado (prueba, ok, detalle)
select 'fn_agente_error_marcar_atendida: authenticated sí, anon no',
       not has_function_privilege('anon', 'public.fn_agente_error_marcar_atendida(uuid)', 'execute')
       and has_function_privilege('authenticated', 'public.fn_agente_error_marcar_atendida(uuid)', 'execute'),
       'has_function_privilege';

-- Registro ------------------------------------------------------------------------
insert into _resultado (prueba, ok, detalle)
select 'registro: visible_restaurante según el catálogo, teléfono normalizado',
       (select visible_restaurante and telefono_cliente = '600000003' from agente_errores where id = (select id from _ctx where clave = 'e_a_visible'))
       and (select not visible_restaurante from agente_errores where id = (select id from _ctx where clave = 'e_a_interno'))
       and (select not visible_restaurante and restaurant_id is null from agente_errores where id = (select id from _ctx where clave = 'e_sin_rest')),
       'sin_respuesta visible, error_interno y firma_invalida no';

insert into _resultado (prueba, ok, detalle)
select 'registro: restaurante que no existe → sin restaurante (solo superadmin)',
       restaurant_id is null and not visible_restaurante, coalesce(restaurant_id::text, 'null')
from agente_errores where id = (select id from _ctx where clave = 'e_rest_falso');

insert into _resultado (prueba, ok, detalle)
select 'registro: el detalle no guarda claves (sk-ant-… y sb_secret_… → [oculto])',
       detalle::text not like '%sk-ant-%' and detalle::text not like '%sb_secret_%'
       and detalle ->> 'clave' = '[oculto]' and detalle ->> 'supabase' = '[oculto]', detalle::text
from agente_errores_detalle where error_id = (select id from _ctx where clave = 'e_a_visible');

do $$
declare
  v_rest_a uuid := (select id from _ctx where clave = 'rest_a');
  v_id uuid;
  v_id2 uuid;
  v_err text;
begin
  -- Mismo restaurante, teléfono y tipo pendiente en 30 min → suma veces.
  v_id := pg_temp.registrar(v_rest_a, '34600000003', 'sin_respuesta', '{"error": "otra vez"}');
  insert into _resultado (prueba, ok, detalle)
  select 'repetición en 30 min: suma veces (2) y no crea otra fila',
         v_id = (select id from _ctx where clave = 'e_a_visible')
         and (select veces from agente_errores where id = v_id) = 2
         and (select count(*) from agente_errores where restaurant_id = v_rest_a and tipo = 'sin_respuesta') = 1
         and (select count(*) from agente_errores_detalle where error_id = v_id) = 2,
         'veces=' || (select veces from agente_errores where id = v_id);

  -- Otro tipo → fila nueva.
  v_id2 := pg_temp.registrar(v_rest_a, '600000003', 'reserva_no_creada');
  insert into _resultado values (default, 'otro tipo: fila nueva', v_id2 <> v_id, v_id2::text);

  -- Última vez hace 31 min → fila nueva.
  update agente_errores set ultima_vez_at = now() - interval '31 minutes' where id = v_id2;
  insert into _resultado values (default, 'pasados 30 min: fila nueva',
    pg_temp.registrar(v_rest_a, '600000003', 'reserva_no_creada') <> v_id2, '');

  -- Tipo fuera del catálogo → error.
  begin
    perform pg_temp.registrar(v_rest_a, '600000003', 'inventado');
    insert into _resultado values (default, 'tipo fuera del catálogo → error', false, 'no dio error');
  exception when others then
    reset role;
    insert into _resultado values (default, 'tipo fuera del catálogo → error', true, sqlerrm);
  end;
end
$$;

-- Quién ve qué ----------------------------------------------------------------------
insert into _resultado (prueba, ok, detalle)
select 'dueño A: solo ve las visibles de su restaurante',
       pg_temp.contar((select id from _ctx where clave = 'a'), 'select count(*) from public.agente_errores')
         = (select count(*)::text from agente_errores where restaurant_id = (select id from _ctx where clave = 'rest_a') and visible_restaurante)
       and pg_temp.contar((select id from _ctx where clave = 'a'),
             'select count(*) from public.agente_errores where not visible_restaurante or restaurant_id is distinct from '''
             || (select id from _ctx where clave = 'rest_a') || '''') = '0',
       've ' || pg_temp.contar((select id from _ctx where clave = 'a'), 'select count(*) from public.agente_errores') || ' filas';

insert into _resultado (prueba, ok, detalle)
select 'dueño A: ninguna fila de detalle',
       pg_temp.contar((select id from _ctx where clave = 'a'), 'select count(*) from public.agente_errores_detalle') = '0',
       pg_temp.contar((select id from _ctx where clave = 'a'), 'select count(*) from public.agente_errores_detalle');

insert into _resultado (prueba, ok, detalle)
select 'dueño B: no ve nada del restaurante A',
       pg_temp.contar((select id from _ctx where clave = 'b'),
         'select count(*) from public.agente_errores where restaurant_id = ''' || (select id from _ctx where clave = 'rest_a') || '''') = '0'
       and pg_temp.contar((select id from _ctx where clave = 'b'), 'select count(*) from public.agente_errores') = '1',
       've ' || pg_temp.contar((select id from _ctx where clave = 'b'), 'select count(*) from public.agente_errores') || ' filas (la suya)';

insert into _resultado (prueba, ok, detalle)
select 'superadmin: ve todo, también sin restaurante, y el detalle',
       pg_temp.contar((select id from _ctx where clave = 's'), 'select count(*) from public.agente_errores')
         = (select count(*)::text from agente_errores)
       and pg_temp.contar((select id from _ctx where clave = 's'), 'select count(*) from public.agente_errores where restaurant_id is null') = '2'
       and pg_temp.contar((select id from _ctx where clave = 's'), 'select count(*) from public.agente_errores_detalle')
         = (select count(*)::text from agente_errores_detalle),
       've ' || pg_temp.contar((select id from _ctx where clave = 's'), 'select count(*) from public.agente_errores') || ' de '
       || (select count(*) from agente_errores);

insert into _resultado (prueba, ok, detalle)
select 'anon: no ve nada (sin permiso)',
       pg_temp.contar(null, 'select count(*) from public.agente_errores', true) like '42501%'
       and pg_temp.contar(null, 'select count(*) from public.agente_errores_detalle', true) like '42501%',
       pg_temp.contar(null, 'select count(*) from public.agente_errores', true);

insert into _resultado (prueba, ok, detalle)
select 'authenticated: no puede insertar, cambiar ni borrar',
       pg_temp.intentar((select id from _ctx where clave = 'a'),
         'insert into public.agente_errores (restaurant_id, tipo) values (''' || (select id from _ctx where clave = 'rest_a') || ''', ''sin_respuesta'')') like '42501%'
       and pg_temp.intentar((select id from _ctx where clave = 'a'), 'update public.agente_errores set atendida = true') like '42501%'
       and pg_temp.intentar((select id from _ctx where clave = 'a'), 'delete from public.agente_errores') like '42501%'
       and pg_temp.intentar((select id from _ctx where clave = 's'), 'delete from public.agente_errores_detalle') like '42501%',
       pg_temp.intentar((select id from _ctx where clave = 'a'), 'update public.agente_errores set atendida = true');

-- Marcar como atendida ------------------------------------------------------------
insert into _resultado (prueba, ok, detalle)
select 'marcar atendida: otro dueño (B) falla',
       pg_temp.intentar((select id from _ctx where clave = 'b'),
         'select public.fn_agente_error_marcar_atendida(''' || (select id from _ctx where clave = 'e_a_visible') || ''')') like '42501%'
       and not (select atendida from agente_errores where id = (select id from _ctx where clave = 'e_a_visible')),
       pg_temp.intentar((select id from _ctx where clave = 'b'),
         'select public.fn_agente_error_marcar_atendida(''' || (select id from _ctx where clave = 'e_a_visible') || ''')');

insert into _resultado (prueba, ok, detalle)
select 'marcar atendida: el dueño A no puede con un aviso no visible (error_interno)',
       pg_temp.intentar((select id from _ctx where clave = 'a'),
         'select public.fn_agente_error_marcar_atendida(''' || (select id from _ctx where clave = 'e_a_interno') || ''')') like '42501%',
       '';

-- (Cada marcado va en su propia sentencia: la comprobación posterior tiene que
-- ver la fila ya cambiada.)
create temp table _marcar (clave text primary key, resultado text) on commit drop;
insert into _marcar values ('a', pg_temp.intentar((select id from _ctx where clave = 'a'),
  'select public.fn_agente_error_marcar_atendida(''' || (select id from _ctx where clave = 'e_a_visible') || ''')'));
insert into _marcar values ('s', pg_temp.intentar((select id from _ctx where clave = 's'),
  'select public.fn_agente_error_marcar_atendida(''' || (select id from _ctx where clave = 'e_sin_rest') || ''')'));

insert into _resultado (prueba, ok, detalle)
select 'marcar atendida: el dueño A sí (atendida_por = A, atendida_at = ahora)',
       (select resultado from _marcar where clave = 'a') = ''
       and (select atendida and atendida_por = (select id from _ctx where clave = 'a') and atendida_at > now() - interval '1 minute'
            from agente_errores where id = (select id from _ctx where clave = 'e_a_visible')),
       coalesce(nullif((select resultado from _marcar where clave = 'a'), ''),
                (select atendida_por || ' ' || atendida_at from agente_errores where id = (select id from _ctx where clave = 'e_a_visible')));

insert into _resultado (prueba, ok, detalle)
select 'marcar atendida: el superadmin sí, también sin restaurante',
       (select resultado from _marcar where clave = 's') = ''
       and (select atendida and atendida_por = (select id from _ctx where clave = 's')
            from agente_errores where id = (select id from _ctx where clave = 'e_sin_rest')),
       (select resultado from _marcar where clave = 's');

insert into _resultado (prueba, ok, detalle)
select 'marcar atendida: sin sesión falla',
       pg_temp.intentar(null,
         'select public.fn_agente_error_marcar_atendida(''' || (select id from _ctx where clave = 'e_b_visible') || ''')') like '42501%',
       '';

-- Tras atenderlo, un fallo nuevo del mismo cliente crea otro aviso.
insert into _resultado (prueba, ok, detalle)
select 'tras marcar atendida, el mismo fallo crea un aviso nuevo',
       pg_temp.registrar((select id from _ctx where clave = 'rest_a'), '600000003', 'sin_respuesta')
         <> (select id from _ctx where clave = 'e_a_visible'),
       '';

-- Entrada directa desde Meta (migración 20261113121550_agente_errores_tipos_entrada) ---
do $$
declare
  v_rest_a uuid := (select id from _ctx where clave = 'rest_a');
  v_f1 uuid;
  v_f uuid;
  v_n uuid;
  v_m uuid;
  v_ok boolean := true;
begin
  -- firma_invalida: todo en una fila por media hora, aunque llegue con
  -- restaurante o teléfono (no son fiables). La fila e_sin_rest ya está atendida.
  v_f1 := pg_temp.registrar(null, null, 'firma_invalida', '{"intento": 1, "firma": "sha256=abcdef0123456789"}');
  for i in 2..100 loop
    v_f := pg_temp.registrar(case when i % 2 = 0 then v_rest_a end, '6000000' || i, 'firma_invalida', jsonb_build_object('intento', i));
    v_ok := v_ok and v_f = v_f1;
  end loop;
  insert into _resultado (prueba, ok, detalle)
  select 'firma_invalida: 100 peticiones (con y sin restaurante/teléfono) → 1 fila, veces = 100, sin restaurante ni teléfono',
         v_ok and veces = 100 and restaurant_id is null and telefono_cliente is null and not visible_restaurante,
         'veces=' || veces
  from agente_errores where id = v_f1;

  insert into _resultado (prueba, ok, detalle)
  select 'firma_invalida: solo se guarda el detalle de las 5 primeras veces, y sin la firma',
         count(*) = 5 and bool_and(detalle::text not like '%abcdef0123456789%'),
         count(*) || ' detalles'
  from agente_errores_detalle where error_id = v_f1;

  v_n := pg_temp.registrar(v_rest_a, '600000009', 'numero_desconocido', '{"phone_number_id": "123"}');
  insert into _resultado (prueba, ok, detalle)
  select 'numero_desconocido: aceptado, sin restaurante ni teléfono, solo superadmin',
         restaurant_id is null and telefono_cliente is null and not visible_restaurante
         and pg_temp.registrar(null, '600000010', 'numero_desconocido') = v_n,
         tipo
  from agente_errores where id = v_n;

  v_m := pg_temp.registrar(v_rest_a, '600000003', 'mensajes_multiples', '{"mensajes": 2}');
  insert into _resultado (prueba, ok, detalle)
  select 'mensajes_multiples: aceptado y no visible para el dueño',
         restaurant_id = v_rest_a and not visible_restaurante
         and pg_temp.contar((select id from _ctx where clave = 'a'),
               'select count(*) from public.agente_errores where id = ''' || v_m || '''') = '0',
         tipo
  from agente_errores where id = v_m;
end
$$;

-- Estadísticas del superadmin (entrega 1b, criterio 12) -----------------------------
-- Avisos con fechas de 2020 (no hay datos reales de entonces) para que las
-- cifras no dependan de lo que haya en Test:
--   e1: sin_respuesta de A, 3 veces, el 10-01-2020 a las 23:30 UTC = 11-01-2020 00:30 en Madrid;
--   e2: firma_invalida sin restaurante, 10-01-2020 12:00 UTC (13:00 Madrid);
--   e3: pedido_no_creado de B, atendido, 11-01-2020 22:59 UTC (23:59 Madrid);
--   e4: sin_respuesta de B, 12-01-2020 00:00 UTC (01:00 Madrid del 12: fuera del periodo).
do $$
declare
  v_rest_a uuid := (select id from _ctx where clave = 'rest_a');
  v_rest_b uuid := (select id from _ctx where clave = 'rest_b');
begin
  insert into agente_errores (restaurant_id, telefono_cliente, tipo, visible_restaurante, veces, created_at, ultima_vez_at)
  values (v_rest_a, '600000020', 'sin_respuesta', true, 3, '2020-01-10 23:30:00+00', '2020-01-10 23:40:00+00'),
         (null, null, 'firma_invalida', false, 1, '2020-01-10 12:00:00+00', '2020-01-10 12:00:00+00'),
         (v_rest_b, '600000021', 'pedido_no_creado', true, 1, '2020-01-11 22:59:00+00', '2020-01-11 22:59:00+00'),
         (v_rest_b, '600000022', 'sin_respuesta', true, 1, '2020-01-12 00:00:00+00', '2020-01-12 00:00:00+00');
  update agente_errores set atendida = true, atendida_at = '2020-01-12 09:00:00+00'
  where restaurant_id = v_rest_b and telefono_cliente = '600000021';
end
$$;

-- Llama a las estadísticas como authenticated con la sesión dada.
create function pg_temp.estadisticas(p_uid uuid, p_desde date, p_hasta date)
returns table (agrupacion text, clave text, nombre text, avisos bigint, veces bigint, pendientes bigint)
language plpgsql as $$
begin
  perform pg_temp.como(p_uid);
  set local role authenticated;
  return query select * from public.fn_superadmin_estadisticas_agente(p_desde, p_hasta);
  reset role;
  perform pg_temp.como(null);
end $$;

create temp table _est on commit drop as
select * from pg_temp.estadisticas((select id from _ctx where clave = 's'), '2020-01-10', '2020-01-11');

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: permisos (authenticated sí, anon no)',
       not has_function_privilege('anon', 'public.fn_superadmin_estadisticas_agente(date,date,text)', 'execute')
       and has_function_privilege('authenticated', 'public.fn_superadmin_estadisticas_agente(date,date,text)', 'execute'),
       'has_function_privilege';

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: total del periodo (3 avisos, 5 veces, 2 pendientes; el del 12 en Madrid queda fuera)',
       avisos = 3 and veces = 5 and pendientes = 2, avisos || ' avisos, ' || veces || ' veces, ' || pendientes || ' pendientes'
from _est where agrupacion = 'total';

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: por día en hora de España (00:30 de Madrid cuenta el 11, no el 10)',
       coalesce((select avisos = 1 and veces = 1 from _est where agrupacion = 'dia' and clave = '2020-01-10'), false)
       and coalesce((select avisos = 2 and veces = 4 and pendientes = 1 from _est where agrupacion = 'dia' and clave = '2020-01-11'), false)
       and not exists (select 1 from _est where agrupacion = 'dia' and clave = '2020-01-12'),
       (select string_agg(clave || ': ' || avisos || '/' || veces, ', ' order by clave) from _est where agrupacion = 'dia');

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: por tipo',
       coalesce((select avisos = 1 and veces = 3 from _est where agrupacion = 'tipo' and clave = 'sin_respuesta'), false)
       and coalesce((select avisos = 1 from _est where agrupacion = 'tipo' and clave = 'firma_invalida'), false)
       and coalesce((select avisos = 1 and pendientes = 0 from _est where agrupacion = 'tipo' and clave = 'pedido_no_creado'), false),
       (select string_agg(clave || ': ' || avisos || '/' || veces, ', ' order by clave) from _est where agrupacion = 'tipo');

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: por restaurante, también "Sin restaurante"',
       coalesce((select avisos = 1 and nombre = 'Sin restaurante' from _est where agrupacion = 'restaurante' and clave = ''), false)
       and coalesce((select avisos = 1 and nombre = 'ZZ Err A' from _est where agrupacion = 'restaurante' and clave = (select id from _ctx where clave = 'rest_a')::text), false)
       and coalesce((select avisos = 1 and nombre = 'ZZ Err B' from _est where agrupacion = 'restaurante' and clave = (select id from _ctx where clave = 'rest_b')::text), false),
       (select string_agg(nombre || ': ' || avisos, ', ' order by nombre) from _est where agrupacion = 'restaurante');

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: semana (lunes 06-01-2020) suma lo mismo que los días',
       coalesce((select avisos = 3 and veces = 5 from _est where agrupacion = 'semana' and clave = '2020-01-06'), false),
       (select string_agg(clave || ': ' || avisos, ', ') from _est where agrupacion = 'semana');

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: coinciden con contar las filas a mano por día de Madrid',
       not exists (
         select (created_at at time zone 'Europe/Madrid')::date::text as dia, count(*), sum(veces)
         from agente_errores
         where (created_at at time zone 'Europe/Madrid')::date between '2020-01-10' and '2020-01-11'
         group by 1
         except
         select clave, avisos, veces from _est where agrupacion = 'dia')
       and (select count(*) from _est where agrupacion = 'dia')
           = (select count(distinct (created_at at time zone 'Europe/Madrid')::date) from agente_errores
              where (created_at at time zone 'Europe/Madrid')::date between '2020-01-10' and '2020-01-11'),
       '';

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: sin límites de fecha ve todo el registro (también lo atendido hace tiempo)',
       pg_temp.contar((select id from _ctx where clave = 's'),
         'select avisos from public.fn_superadmin_estadisticas_agente(null, null) where agrupacion = ''total''')
         = (select count(*)::text from agente_errores),
       pg_temp.contar((select id from _ctx where clave = 's'),
         'select avisos from public.fn_superadmin_estadisticas_agente(null, null) where agrupacion = ''total''')
       || ' de ' || (select count(*) from agente_errores);

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: un dueño no puede (42501) y anon tampoco',
       pg_temp.intentar((select id from _ctx where clave = 'a'),
         'select * from public.fn_superadmin_estadisticas_agente(''2020-01-10'', ''2020-01-11'')') like '42501%'
       and pg_temp.contar(null, 'select count(*) from public.fn_superadmin_estadisticas_agente(null, null)', true) like '42501%',
       pg_temp.intentar((select id from _ctx where clave = 'a'),
         'select * from public.fn_superadmin_estadisticas_agente(''2020-01-10'', ''2020-01-11'')');

insert into _resultado (prueba, ok, detalle)
select 'estadísticas: periodo al revés → error claro',
       pg_temp.intentar((select id from _ctx where clave = 's'),
         'select * from public.fn_superadmin_estadisticas_agente(''2020-01-11'', ''2020-01-10'')') like '22023%',
       pg_temp.intentar((select id from _ctx where clave = 's'),
         'select * from public.fn_superadmin_estadisticas_agente(''2020-01-11'', ''2020-01-10'')');

-- Lectura de avisos de la pantalla del dueño (entrega 1b, criterio 11): una
-- atendida hace 31 días la sigue leyendo (el plazo de 30 días es solo un
-- filtro de la pantalla, decisión 13), y el superadmin también.
do $$
begin
  insert into agente_errores (restaurant_id, telefono_cliente, tipo, visible_restaurante, atendida, atendida_at, atendida_por)
  values ((select id from _ctx where clave = 'rest_a'), '600000031', 'reserva_no_creada', true, true,
          now() - interval '31 days', (select id from _ctx where clave = 'a'));
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'pantalla del dueño: consulta de atendidas de 30 días deja fuera la de hace 31 (y la fila sigue existiendo)',
       pg_temp.contar((select id from _ctx where clave = 'a'),
         'select count(*) from public.agente_errores where telefono_cliente = ''600000031'' and atendida and atendida_at >= now() - interval ''30 days''') = '0'
       and pg_temp.contar((select id from _ctx where clave = 'a'),
         'select count(*) from public.agente_errores where telefono_cliente = ''600000031''') = '1'
       and pg_temp.contar((select id from _ctx where clave = 's'),
         'select count(*) from public.agente_errores where telefono_cliente = ''600000031''') = '1',
       '';

insert into _resultado (prueba, ok, detalle)
select 'TOTAL agente_errores', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
