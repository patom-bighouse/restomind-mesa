-- =============================================================================
-- Avisos de fallos del agente de WhatsApp (migraciones 20261113114748_agente_errores
-- y 20261113121550_agente_errores_tipos_entrada)
-- Criterio 5 de docs/specs/2026-11-13-agente-whatsapp-revision.md
-- (El bloque de estadísticas del criterio 12 se añade en la entrega 1b, con
-- fn_superadmin_estadisticas_agente.)
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
    ('e_a_visible',   pg_temp.registrar(v_rest_a, '+34 600 000 003', 'sin_respuesta', '{"error": "timeout", "clave": "sk-ant-api03-FALSA"}')),
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
select 'registro: el detalle no guarda claves (sk-ant-… → [oculto])',
       detalle::text not like '%sk-ant-%' and detalle ->> 'clave' = '[oculto]', detalle::text
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
  for i in 2..8 loop
    v_f := pg_temp.registrar(case when i % 2 = 0 then v_rest_a end, '6000000' || i, 'firma_invalida', jsonb_build_object('intento', i));
    v_ok := v_ok and v_f = v_f1;
  end loop;
  insert into _resultado (prueba, ok, detalle)
  select 'firma_invalida: 8 peticiones (con y sin restaurante/teléfono) → 1 fila, veces = 8, sin restaurante ni teléfono',
         v_ok and veces = 8 and restaurant_id is null and telefono_cliente is null and not visible_restaurante,
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

insert into _resultado (prueba, ok, detalle)
select 'TOTAL agente_errores', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
