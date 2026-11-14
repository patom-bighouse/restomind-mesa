-- =============================================================================
-- Zona horaria por restaurante (migración 20261114151610_zona_horaria_restaurante)
-- Criterios 1 a 6 de docs/specs/2026-11-14-zona-horaria-restaurante.md
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/zona_horaria.sql
--
-- Crea en la transacción un superadmin, un dueño y restaurantes de prueba en
-- Europe/Madrid, Atlantic/Canary y America/Mexico_City. Para no depender de la
-- hora a la que se ejecute:
--   - fn_menu_activo se prueba con instantes fijos (p_momento);
--   - reservas, vales y recogidas se calculan desde L = fn_ahora_restaurante(id)
--     o desde fn_hoy_restaurante(id).
--
-- Resultado: una fila por comprobación (prueba, ok, detalle) + TOTAL.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;
create temp table _ctx (clave text primary key, id uuid) on commit drop;

create function pg_temp.id(p text) returns uuid language sql as $$ select id from _ctx where clave = p $$;

-- Ejecuta p_sql con el rol dado y, si p_uid no es null, con la sesión de ese
-- usuario (auth.uid()). Devuelve '' si fue bien; si no, 'SQLSTATE: mensaje'.
create function pg_temp.intentar(p_rol text, p_sql text, p_uid uuid default null) returns text
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
                     case when p_uid is null then '' else json_build_object('sub', p_uid, 'role', p_rol)::text end, true);
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  execute format('set local role %I', p_rol);
  execute p_sql;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  return '';
exception when others then
  reset role;
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  return sqlstate || ': ' || sqlerrm;
end $$;

create function pg_temp.anotar(p_prueba text, p_ok boolean, p_detalle text) returns void
language sql as $$ insert into _resultado (prueba, ok, detalle) values (p_prueba, p_ok, p_detalle) $$;

-- Preparación ----------------------------------------------------------------------
do $$
declare
  v_super uuid := gen_random_uuid();
  v_duenio uuid := gen_random_uuid();
  v_mad uuid; v_can uuid; v_mex uuid; v_sin uuid;
  r uuid;
  v_mesa uuid;
  v_id uuid;
begin
  insert into auth.users (id, email, aud, role, instance_id) values
    (v_super, 'zz_zona_super@example.invalid', 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000'),
    (v_duenio, 'zz_zona_duenio@example.invalid', 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000');
  insert into superadmins (user_id, nombre) values (v_super, 'ZZ superadmin zona');

  insert into restaurants (nombre, slug, user_id)
  values ('ZZ Zona Madrid', 'zz-zona-mad-' || substr(v_duenio::text, 1, 8), v_duenio) returning id into v_mad;
  insert into restaurants (nombre, slug, zona_horaria, direccion)
  values ('ZZ Zona Canarias', 'zz-zona-can-' || substr(v_duenio::text, 1, 8), 'Atlantic/Canary', 'C/ Mayor 3, 35600 Puerto del Rosario')
  returning id into v_can;
  insert into restaurants (nombre, slug, zona_horaria, moneda)
  values ('ZZ Zona México', 'zz-zona-mex-' || substr(v_duenio::text, 1, 8), 'America/Mexico_City', 'MXN') returning id into v_mex;
  -- Sin zona en el insert: debe quedar en Madrid.
  insert into restaurants (nombre, slug) values ('ZZ Zona sin dato', 'zz-zona-sin-' || substr(v_duenio::text, 1, 8)) returning id into v_sin;

  insert into _ctx values ('super', v_super), ('duenio', v_duenio), ('mad', v_mad), ('can', v_can), ('mex', v_mex), ('sin', v_sin);

  -- Menús: 13:00–14:00 y 02:00–03:00, en los tres restaurantes (sin días ni zona del salón).
  foreach r in array array[v_mad, v_can, v_mex] loop
    insert into menus (restaurant_id, nombre, hora_inicio, hora_fin) values (r, 'ZZ Mediodía', '13:00', '14:00');
    insert into menus (restaurant_id, nombre, hora_inicio, hora_fin) values (r, 'ZZ Madrugada', '02:00', '03:00');
    -- Una mesa de 4 (disponibilidad de WhatsApp y máximo de personas) con una sesión abierta (vales).
    insert into tables (restaurant_id, numero, capacidad) values (r, 9101, 4) returning id into v_mesa;
    insert into tables (restaurant_id, numero, capacidad) values (r, 9102, 4);
    insert into table_sessions (table_id, restaurant_id, comensales) values (v_mesa, r, 2) returning id into v_id;
    insert into _ctx values ('sesion_' || r::text, v_id);
  end loop;

  insert into restaurant_modulos (restaurant_id, modulo_key, activo) values (v_can, 'takeaway_delivery', true);
  insert into menu_items (restaurant_id, nombre, precio, disponible)
  values (v_can, 'ZZ Papas arrugadas', 6.50, true) returning id into v_id;
  insert into _ctx values ('plato_can', v_id);

  -- Vales en Canarias: uno vencido ayer (en Canarias) y otro que vence hoy.
  insert into vales_regalo (restaurant_id, codigo, importe_inicial, saldo_actual, fecha_vencimiento) values
    (v_can, 'ZZAYER', 50, 50, fn_hoy_restaurante(v_can) - 1),
    (v_can, 'ZZHOY', 50, 50, fn_hoy_restaurante(v_can)),
    (v_can, 'ZZAYER2', 50, 50, fn_hoy_restaurante(v_can) - 1),
    (v_can, 'ZZHOY2', 50, 50, fn_hoy_restaurante(v_can));
  -- Lo mismo en México (se distingue de Madrid de 00:00 a 07:00 de Madrid).
  insert into vales_regalo (restaurant_id, codigo, importe_inicial, saldo_actual, fecha_vencimiento) values
    (v_mex, 'ZZMXAYER', 50, 50, fn_hoy_restaurante(v_mex) - 1),
    (v_mex, 'ZZMXHOY', 50, 50, fn_hoy_restaurante(v_mex)),
    (v_mex, 'ZZMXAYER2', 50, 50, fn_hoy_restaurante(v_mex) - 1),
    (v_mex, 'ZZMXHOY2', 50, 50, fn_hoy_restaurante(v_mex));
end
$$;

-- Criterio 1: los restaurantes existentes siguen en Madrid ------------------------------
select pg_temp.anotar('1. columna zona_horaria: not null, default Europe/Madrid',
  a.attnotnull and pg_get_expr(d.adbin, d.adrelid) = '''Europe/Madrid''::text',
  pg_get_expr(d.adbin, d.adrelid))
from pg_attribute a join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
where a.attrelid = 'public.restaurants'::regclass and a.attname = 'zona_horaria';

select pg_temp.anotar('1. restaurante sin zona en el alta → Europe/Madrid',
  zona_horaria = 'Europe/Madrid', zona_horaria) from restaurants where id = pg_temp.id('sin');

-- Restaurantes que ya existían (fuera de los de prueba): cuántos siguen en Madrid
-- y que en ellos las funciones nuevas den exactamente lo mismo que las de Madrid.
select pg_temp.anotar('1. restaurantes de Test en Madrid: fn_ahora/fn_hoy_restaurante = fn_ahora/fn_hoy_madrid',
  bool_and(fn_ahora_restaurante(id) = fn_ahora_madrid() and fn_hoy_restaurante(id) = fn_hoy_madrid()),
  count(*) || ' restaurantes en Madrid de ' || (select count(*) from restaurants where nombre not like 'ZZ Zona %') ||
  ' (los que no estén en Madrid los ha cambiado el superadmin a propósito)')
from restaurants where zona_horaria = 'Europe/Madrid' and nombre not like 'ZZ Zona %';

select pg_temp.anotar('1. restaurante que no existe → Madrid',
  fn_zona_restaurante(gen_random_uuid()) = 'Europe/Madrid' and fn_ahora_restaurante(gen_random_uuid()) = fn_ahora_madrid(),
  fn_zona_restaurante(gen_random_uuid()));

select pg_temp.anotar('1. ninguna de las 12 funciones de operativa usa ya _madrid() ni ''Europe/Madrid'' (salvo el respaldo de fn_agente_datos_restaurante)',
  bool_and(case when p.proname = 'fn_agente_datos_restaurante'
                then (select count(*) from regexp_matches(p.prosrc, 'Europe/Madrid', 'g')) = 1 and p.prosrc !~ '_madrid\('
                else p.prosrc !~ '_madrid\(|Europe/Madrid' end),
  string_agg(p.proname, ', ' order by p.proname) filter (where p.prosrc ~ '_madrid\(' or (p.proname <> 'fn_agente_datos_restaurante' and p.prosrc ~ 'Europe/Madrid')))
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('fn_menu_activo', 'fn_registrar_pedido', 'fn_canjear_vale_regalo', 'fn_crear_reserva_web',
                    'fn_reserva_whatsapp_crear', 'fn_reserva_cliente_bloquear', 'fn_reserva_cliente_cancelar',
                    'fn_reserva_cliente_modificar', 'fn_reserva_contexto_cliente', 'fn_reserva_hay_mesa',
                    'fn_pedido_whatsapp_crear', 'fn_agente_datos_restaurante');

select pg_temp.anotar('1. funciones de ayuda: stable, security invoker, search_path = public, sin anon ni authenticated',
  bool_and(p.provolatile = 's' and not p.prosecdef and p.proconfig = array['search_path=public']
           and not has_function_privilege('anon', p.oid, 'execute')
           and not has_function_privilege('authenticated', p.oid, 'execute')
           and has_function_privilege('service_role', p.oid, 'execute')),
  string_agg(p.proname, ', ' order by p.proname))
from pg_proc p
where p.pronamespace = 'public'::regnamespace and p.proname in ('fn_zona_restaurante', 'fn_ahora_restaurante', 'fn_hoy_restaurante');

select pg_temp.anotar('1. fn_ahora_restaurante en Canarias y México = now() en su zona',
  fn_ahora_restaurante(pg_temp.id('can')) = now() at time zone 'Atlantic/Canary'
  and fn_ahora_restaurante(pg_temp.id('mex')) = now() at time zone 'America/Mexico_City'
  and fn_hoy_restaurante(pg_temp.id('mex')) = (now() at time zone 'America/Mexico_City')::date,
  fn_ahora_restaurante(pg_temp.id('can'))::text || ' / ' || fn_ahora_restaurante(pg_temp.id('mex'))::text);

-- Criterio 2: validación de la zona -------------------------------------------------------
do $$
declare
  v_z text;
  v_err text;
begin
  foreach v_z in array array['Europe/Madird', 'CET', 'UTC', 'Etc/GMT+3', '', 'posix/Europe/Madrid', 'europe/madrid'] loop
    v_err := pg_temp.intentar('authenticated',
               format('update public.restaurants set zona_horaria = %L where id = %L', v_z, pg_temp.id('mad')), pg_temp.id('super'));
    perform pg_temp.anotar(format('2. superadmin guarda %L → 22023 y no se guarda', v_z),
      v_err like '22023: Zona horaria no válida:%' and (select zona_horaria from restaurants where id = pg_temp.id('mad')) = 'Europe/Madrid',
      coalesce(nullif(v_err, ''), 'no dio error'));
  end loop;

  foreach v_z in array array['Atlantic/Canary', 'America/Mexico_City', 'America/Argentina/Buenos_Aires', 'Europe/Madrid'] loop
    v_err := pg_temp.intentar('authenticated',
               format('update public.restaurants set zona_horaria = %L where id = %L', v_z, pg_temp.id('mad')), pg_temp.id('super'));
    perform pg_temp.anotar(format('2. superadmin guarda %L → se guarda', v_z),
      v_err = '' and (select zona_horaria from restaurants where id = pg_temp.id('mad')) = v_z,
      coalesce(nullif(v_err, ''), (select zona_horaria from restaurants where id = pg_temp.id('mad'))));
  end loop;

  -- En el alta también se valida.
  v_err := pg_temp.intentar('authenticated',
             format('insert into public.restaurants (nombre, slug, zona_horaria) values (''ZZ Zona mala'', %L, ''CET'')',
                    'zz-zona-mala-' || substr(gen_random_uuid()::text, 1, 8)), pg_temp.id('super'));
  perform pg_temp.anotar('2. alta con zona ''CET'' → 22023', v_err like '22023:%', coalesce(nullif(v_err, ''), 'no dio error'));
end
$$;

create function pg_temp.leer_como_anon(p_rest uuid) returns text
language plpgsql as $$
declare v text;
begin
  set local role anon;
  execute format('select zona_horaria from public.restaurants where id = %L', p_rest) into v;
  reset role;
  return v;
exception when others then
  reset role;
  return sqlstate || ': ' || sqlerrm;
end $$;

select pg_temp.anotar('2. anon puede leer zona_horaria',
  pg_temp.leer_como_anon(pg_temp.id('can')) = 'Atlantic/Canary', pg_temp.leer_como_anon(pg_temp.id('can')));

-- Criterio 3: solo el superadmin la cambia ------------------------------------------------
do $$
declare
  v_err text;
begin
  v_err := pg_temp.intentar('authenticated',
             format('update public.restaurants set zona_horaria = ''Atlantic/Canary'', nombre = ''ZZ Zona Madrid X'' where id = %L', pg_temp.id('mad')),
             pg_temp.id('duenio'));
  perform pg_temp.anotar('3. dueño cambia zona y nombre → el nombre cambia, la zona sigue en Madrid, sin error',
    v_err = '' and (select nombre = 'ZZ Zona Madrid X' and zona_horaria = 'Europe/Madrid' from restaurants where id = pg_temp.id('mad')),
    coalesce(nullif(v_err, ''), (select nombre || ' / ' || zona_horaria from restaurants where id = pg_temp.id('mad'))));

  v_err := pg_temp.intentar('authenticated',
             format('update public.restaurants set zona_horaria = ''Zona/Inventada'', nombre = ''ZZ Zona Madrid Y'' where id = %L', pg_temp.id('mad')),
             pg_temp.id('duenio'));
  perform pg_temp.anotar('3. dueño con zona no válida → se ignora sin error (la protección va antes que la validación)',
    v_err = '' and (select nombre = 'ZZ Zona Madrid Y' and zona_horaria = 'Europe/Madrid' from restaurants where id = pg_temp.id('mad')),
    coalesce(nullif(v_err, ''), (select nombre || ' / ' || zona_horaria from restaurants where id = pg_temp.id('mad'))));

  v_err := pg_temp.intentar('authenticated',
             format('update public.restaurants set zona_horaria = ''Atlantic/Canary'' where id = %L', pg_temp.id('mad')),
             pg_temp.id('super'));
  perform pg_temp.anotar('3. superadmin cambia la zona → cambia',
    v_err = '' and (select zona_horaria from restaurants where id = pg_temp.id('mad')) = 'Atlantic/Canary',
    coalesce(nullif(v_err, ''), (select zona_horaria from restaurants where id = pg_temp.id('mad'))));

  -- Sin sesión (service_role / migraciones): no la protege el trigger.
  update restaurants set zona_horaria = 'Europe/Madrid' where id = pg_temp.id('mad');
  perform pg_temp.anotar('3. sin sesión (postgres) se puede volver a Madrid',
    (select zona_horaria from restaurants where id = pg_temp.id('mad')) = 'Europe/Madrid',
    (select zona_horaria from restaurants where id = pg_temp.id('mad')));
end
$$;

-- Criterio 4: fn_menu_activo con instantes fijos -------------------------------------------
create function pg_temp.menu(p_rest uuid, p_momento timestamptz) returns text
language sql as $$ select coalesce((select nombre from menus where id = fn_menu_activo(p_rest, null, p_momento, false)), '(ninguno)') $$;

select pg_temp.anotar('4. 2027-01-15 12:30Z: Madrid (13:30) → Mediodía', pg_temp.menu(pg_temp.id('mad'), '2027-01-15 12:30Z') = 'ZZ Mediodía',
  pg_temp.menu(pg_temp.id('mad'), '2027-01-15 12:30Z'));
select pg_temp.anotar('4. 2027-01-15 12:30Z: Canarias (12:30) → ninguno', pg_temp.menu(pg_temp.id('can'), '2027-01-15 12:30Z') = '(ninguno)',
  pg_temp.menu(pg_temp.id('can'), '2027-01-15 12:30Z'));
select pg_temp.anotar('4. 2027-07-15 19:30Z: México (13:30, sin horario de verano) → Mediodía', pg_temp.menu(pg_temp.id('mex'), '2027-07-15 19:30Z') = 'ZZ Mediodía',
  pg_temp.menu(pg_temp.id('mex'), '2027-07-15 19:30Z'));
select pg_temp.anotar('4. 2027-07-15 19:30Z: Madrid (21:30) → ninguno', pg_temp.menu(pg_temp.id('mad'), '2027-07-15 19:30Z') = '(ninguno)',
  pg_temp.menu(pg_temp.id('mad'), '2027-07-15 19:30Z'));
select pg_temp.anotar('4. cambio de hora 2027-03-28 00:59Z: Canarias (00:59) → ninguno', pg_temp.menu(pg_temp.id('can'), '2027-03-28 00:59Z') = '(ninguno)',
  pg_temp.menu(pg_temp.id('can'), '2027-03-28 00:59Z'));
select pg_temp.anotar('4. cambio de hora 2027-03-28 01:00Z: Canarias (02:00, ya en verano) → Madrugada', pg_temp.menu(pg_temp.id('can'), '2027-03-28 01:00Z') = 'ZZ Madrugada',
  pg_temp.menu(pg_temp.id('can'), '2027-03-28 01:00Z'));
select pg_temp.anotar('4. cambio de hora 2027-03-28 01:00Z: Madrid (03:00) → ninguno', pg_temp.menu(pg_temp.id('mad'), '2027-03-28 01:00Z') = '(ninguno)',
  pg_temp.menu(pg_temp.id('mad'), '2027-03-28 01:00Z'));
select pg_temp.anotar('4. día de la semana en la zona: 2027-01-17 23:30Z es domingo en México y lunes en Madrid',
  extract(dow from ('2027-01-17 23:30Z'::timestamptz at time zone fn_zona_restaurante(pg_temp.id('mex')))) = 0
  and extract(dow from ('2027-01-17 23:30Z'::timestamptz at time zone fn_zona_restaurante(pg_temp.id('mad')))) = 1,
  'dow');

-- Menú solo los domingos: activo en México y no en Madrid a la misma hora UTC.
do $$
declare v_m uuid;
begin
  insert into menus (restaurant_id, nombre, dias_semana, orden) values (pg_temp.id('mex'), 'ZZ Domingo', array[0]::smallint[], 0) returning id into v_m;
  insert into menus (restaurant_id, nombre, dias_semana, orden) values (pg_temp.id('mad'), 'ZZ Domingo', array[0]::smallint[], 0);
  perform pg_temp.anotar('4. menú de domingo a las 2027-01-17 23:30Z: México (domingo 17:30) sí, Madrid (lunes 00:30) no',
    pg_temp.menu(pg_temp.id('mex'), '2027-01-17 23:30Z') = 'ZZ Domingo' and pg_temp.menu(pg_temp.id('mad'), '2027-01-17 23:30Z') = '(ninguno)',
    pg_temp.menu(pg_temp.id('mex'), '2027-01-17 23:30Z') || ' / ' || pg_temp.menu(pg_temp.id('mad'), '2027-01-17 23:30Z'));
  delete from menus where nombre = 'ZZ Domingo' and restaurant_id in (pg_temp.id('mex'), pg_temp.id('mad'));
end
$$;

-- Criterio 5: reservas con la hora del restaurante (México y Canarias) -------------------------
do $$
declare
  v_clave text;
  r uuid;
  v_nombre text;
  L timestamp;
  v_t timestamp;
  v_err text;
  v_ctx json;
  v_futura uuid;
  v_pasada uuid;
  v_res text;
  n int := 0;
begin
  foreach v_clave in array array['mex', 'can'] loop
    r := pg_temp.id(v_clave);
    v_nombre := case v_clave when 'mex' then 'México' else 'Canarias' end;
    L := fn_ahora_restaurante(r);

    -- L + 5 min: rechazada por los 15 min de antelación.
    v_t := L + interval '5 minutes';
    v_err := pg_temp.intentar('anon', format('select public.fn_crear_reserva_web(%L, ''ZZ Web'', ''600000101'', %L::date, %L::time, 2)',
                                             r, v_t::date, v_t::time));
    perform pg_temp.anotar(format('5. %s: web L+5 min → 15 min de antelación', v_nombre),
      v_err like '%15 minutos de antelación%', coalesce(nullif(v_err, ''), 'se creó'));

    n := n + 1;
    v_err := pg_temp.intentar('service_role', format(
      'select public.fn_reserva_whatsapp_crear(%L, ''ZZ WA'', ''600000102'', %L::date, %L::time, 2, null, null, 120, %L)',
      r, v_t::date, v_t::time, 'zz-zona-' || n));
    perform pg_temp.anotar(format('5. %s: WhatsApp L+5 min → 15 min de antelación', v_nombre),
      v_err like '%15 minutos de antelación%', coalesce(nullif(v_err, ''), 'se creó'));

    -- L − 10 min: ya ha pasado (si L−10 cae ayer, la web dice "hoy o más adelante").
    v_t := L - interval '10 minutes';
    v_err := pg_temp.intentar('anon', format('select public.fn_crear_reserva_web(%L, ''ZZ Web'', ''600000101'', %L::date, %L::time, 2)',
                                             r, v_t::date, v_t::time));
    perform pg_temp.anotar(format('5. %s: web L−10 min → ya han pasado', v_nombre),
      v_err like '%ya han pasado%' or (v_t::date < L::date and v_err like '%hoy o más adelante%'), coalesce(nullif(v_err, ''), 'se creó'));

    n := n + 1;
    v_err := pg_temp.intentar('service_role', format(
      'select public.fn_reserva_whatsapp_crear(%L, ''ZZ WA'', ''600000102'', %L::date, %L::time, 2, null, null, 120, %L)',
      r, v_t::date, v_t::time, 'zz-zona-' || n));
    perform pg_temp.anotar(format('5. %s: WhatsApp L−10 min → ya han pasado', v_nombre),
      v_err like '%ya han pasado%', coalesce(nullif(v_err, ''), 'se creó'));

    -- L + 60 min: se crea (en la hora de Madrid sería pasado en México y justo ahora en Canarias).
    v_t := L + interval '60 minutes';
    v_err := pg_temp.intentar('anon', format('select public.fn_crear_reserva_web(%L, ''ZZ Web'', ''600000101'', %L::date, %L::time, 2)',
                                             r, v_t::date, v_t::time));
    perform pg_temp.anotar(format('5. %s: web L+60 min → se crea', v_nombre),
      v_err = '' and exists (select 1 from reservations where restaurant_id = r and origen = 'web' and fecha = v_t::date and hora = v_t::time),
      coalesce(nullif(v_err, ''), 'creada'));

    n := n + 1;
    v_err := pg_temp.intentar('service_role', format(
      'select public.fn_reserva_whatsapp_crear(%L, ''ZZ WA'', ''600000102'', %L::date, %L::time, 2, null, null, 120, %L)',
      r, v_t::date, v_t::time, 'zz-zona-' || n));
    perform pg_temp.anotar(format('5. %s: WhatsApp L+60 min → se crea', v_nombre),
      v_err = '' and exists (select 1 from reservations where restaurant_id = r and origen = 'whatsapp' and fecha = v_t::date and hora = v_t::time),
      coalesce(nullif(v_err, ''), 'creada'));

    -- fn_reserva_contexto_cliente: la de L+30 sí, la de L−30 no.
    insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, estado, origen)
    values (r, 'ZZ Futura', '600000199', (L + interval '30 minutes')::date, (L + interval '30 minutes')::time, 2, 'confirmada', 'manual')
    returning id into v_futura;
    insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, estado, origen)
    values (r, 'ZZ Pasada', '600000199', (L - interval '30 minutes')::date, (L - interval '30 minutes')::time, 2, 'confirmada', 'manual')
    returning id into v_pasada;
    v_ctx := fn_reserva_contexto_cliente(r, '600000199');
    perform pg_temp.anotar(format('5. %s: contexto del cliente → la de L+30 sí y la de L−30 no', v_nombre),
      json_array_length(v_ctx -> 'reservas') = 1 and (v_ctx -> 'reservas' -> 0 ->> 'id')::uuid = v_futura,
      (v_ctx -> 'reservas')::text);

    -- fn_reserva_cliente_modificar: mismos 15 min con L.
    v_t := L + interval '5 minutes';
    v_res := fn_reserva_cliente_modificar(r, '600000199', v_futura, v_t::date, v_t::time, 2, null, 120, false);
    perform pg_temp.anotar(format('5. %s: modificar a L+5 min → 15 min de antelación', v_nombre),
      v_res like '%15 minutos de antelación%', coalesce(v_res, 'aceptado'));

    v_t := L + interval '150 minutes';
    v_res := fn_reserva_cliente_modificar(r, '600000199', v_futura, v_t::date, v_t::time, 2, null, 120, false);
    perform pg_temp.anotar(format('5. %s: modificar a L+150 min → se puede', v_nombre),
      v_res is null, coalesce(v_res, 'aceptado'));

    -- fn_reserva_cliente_bloquear / cancelar: la pasada no se puede anular, la futura sí (nota con la hora local).
    begin
      perform fn_reserva_cliente_cancelar(r, '600000199', v_pasada);
      v_err := '';
    exception when others then v_err := sqlerrm;
    end;
    perform pg_temp.anotar(format('5. %s: anular la de L−30 → no la encuentra', v_nombre),
      v_err like 'No encuentro esa reserva%', coalesce(nullif(v_err, ''), 'la anuló'));

    perform fn_reserva_cliente_cancelar(r, '600000199', v_futura);
    perform pg_temp.anotar(format('5. %s: anular la de L+30 → nota con la hora del restaurante', v_nombre),
      (select estado = 'cancelada' and notas like '%el ' || to_char(fn_ahora_restaurante(r), 'DD/MM HH24:MI') from reservations where id = v_futura),
      (select notas from reservations where id = v_futura));
  end loop;
end
$$;

-- Criterio 6: vales, recogidas y datos del agente en Canarias ----------------------------------
do $$
declare
  r uuid := pg_temp.id('can');
  v_ses uuid := pg_temp.id('sesion_' || pg_temp.id('can')::text);
  v_err text;
  v_res json;
  v_manana date;
  v_d jsonb;
  v_plato uuid := pg_temp.id('plato_can');
  v_sin uuid := pg_temp.id('sin');
begin
  v_err := pg_temp.intentar('anon', format('select public.fn_canjear_vale_regalo(%L, ''ZZAYER'', 5)', v_ses));
  perform pg_temp.anotar('6. fn_canjear_vale_regalo: vale vencido ayer (Canarias) → rechazado',
    v_err like '%ya venció%', coalesce(nullif(v_err, ''), 'aceptado'));

  v_err := pg_temp.intentar('anon', format('select public.fn_canjear_vale_regalo(%L, ''ZZHOY'', 5)', v_ses));
  perform pg_temp.anotar('6. fn_canjear_vale_regalo: vale que vence hoy (Canarias) → aceptado',
    v_err = '' and (select saldo_actual from vales_regalo where restaurant_id = r and codigo = 'ZZHOY') = 45,
    coalesce(nullif(v_err, ''), 'aceptado'));

  v_err := pg_temp.intentar('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => ''[]''::jsonb, p_vale_codigo => ''ZZAYER2'', p_vale_importe => 5)', v_ses));
  perform pg_temp.anotar('6. fn_registrar_pedido: vale vencido ayer (Canarias) → rechazado',
    v_err like '%ya venció%', coalesce(nullif(v_err, ''), 'aceptado'));

  v_err := pg_temp.intentar('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => ''[]''::jsonb, p_vale_codigo => ''ZZHOY2'', p_vale_importe => 5)', v_ses));
  perform pg_temp.anotar('6. fn_registrar_pedido: vale que vence hoy (Canarias) → aceptado',
    v_err = '' and (select saldo_actual from vales_regalo where restaurant_id = r and codigo = 'ZZHOY2') = 45,
    coalesce(nullif(v_err, ''), 'aceptado'));

  -- Recogida mañana a las 21:30 de Canarias → nota "Recogida a las 21:30" (en Madrid diría 22:30).
  v_manana := fn_hoy_restaurante(r) + 1;
  set local role service_role;
  v_res := public.fn_pedido_whatsapp_crear(r, 'zz-zona-recogida', '600000301', 'Ana', (v_manana::text || ' 21:30 Atlantic/Canary')::timestamptz, null,
             jsonb_build_array(jsonb_build_object('menu_item_id', v_plato, 'cantidad', 1)));
  reset role;
  perform pg_temp.anotar('6. fn_pedido_whatsapp_crear: recogida 21:30 de Canarias → nota "Recogida a las 21:30"',
    (select notas = 'Recogida a las 21:30' and hora_recogida = (v_manana::text || ' 21:30 Atlantic/Canary')::timestamptz from orders where id = (v_res ->> 'id')::uuid),
    (select notas || ' / ' || hora_recogida::text from orders where id = (v_res ->> 'id')::uuid));

  -- fn_agente_datos_restaurante sin zona → la del restaurante; con zona → se respeta.
  set local role service_role;
  v_d := public.fn_agente_datos_restaurante(r);
  reset role;
  perform pg_temp.anotar('6. fn_agente_datos_restaurante(id) sin zona → Atlantic/Canary y hoy de Canarias',
    v_d ->> 'zona' = 'Atlantic/Canary' and v_d -> 'hoy' ->> 'fecha' = to_char(fn_hoy_restaurante(r), 'YYYY-MM-DD'),
    (v_d ->> 'zona') || ' ' || (v_d -> 'hoy')::text);

  set local role service_role;
  v_d := public.fn_agente_datos_restaurante(r, null);
  reset role;
  perform pg_temp.anotar('6. fn_agente_datos_restaurante(id, null) → Atlantic/Canary',
    v_d ->> 'zona' = 'Atlantic/Canary', v_d ->> 'zona');

  set local role service_role;
  v_d := public.fn_agente_datos_restaurante(r, 'Europe/Madrid');
  reset role;
  perform pg_temp.anotar('6. fn_agente_datos_restaurante(id, ''Europe/Madrid'') → se respeta la zona dada',
    v_d ->> 'zona' = 'Europe/Madrid' and v_d -> 'hoy' ->> 'fecha' = to_char(fn_hoy_madrid(), 'YYYY-MM-DD'), v_d ->> 'zona');

  set local role service_role;
  v_d := public.fn_agente_datos_restaurante(v_sin);
  reset role;
  perform pg_temp.anotar('6. fn_agente_datos_restaurante de un restaurante en Madrid sin zona → Europe/Madrid (como antes)',
    v_d ->> 'zona' = 'Europe/Madrid', v_d ->> 'zona');
end
$$;

-- Criterio 6 (ampliado): vales en México con fn_hoy_restaurante ----------------------------
do $$
declare
  r uuid := pg_temp.id('mex');
  v_ses uuid := pg_temp.id('sesion_' || pg_temp.id('mex')::text);
  v_err text;
begin
  v_err := pg_temp.intentar('anon', format('select public.fn_canjear_vale_regalo(%L, ''ZZMXAYER'', 5)', v_ses));
  perform pg_temp.anotar('6. México: fn_canjear_vale_regalo con vale vencido ayer (México) → rechazado',
    v_err like '%ya venció%', coalesce(nullif(v_err, ''), 'aceptado'));
  v_err := pg_temp.intentar('anon', format('select public.fn_canjear_vale_regalo(%L, ''ZZMXHOY'', 5)', v_ses));
  perform pg_temp.anotar('6. México: fn_canjear_vale_regalo con vale que vence hoy (México) → aceptado',
    v_err = '' and (select saldo_actual from vales_regalo where restaurant_id = r and codigo = 'ZZMXHOY') = 45,
    coalesce(nullif(v_err, ''), 'aceptado'));
  v_err := pg_temp.intentar('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => ''[]''::jsonb, p_vale_codigo => ''ZZMXAYER2'', p_vale_importe => 5)', v_ses));
  perform pg_temp.anotar('6. México: fn_registrar_pedido con vale vencido ayer (México) → rechazado',
    v_err like '%ya venció%', coalesce(nullif(v_err, ''), 'aceptado'));
  v_err := pg_temp.intentar('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => ''[]''::jsonb, p_vale_codigo => ''ZZMXHOY2'', p_vale_importe => 5)', v_ses));
  perform pg_temp.anotar('6. México: fn_registrar_pedido con vale que vence hoy (México) → aceptado',
    v_err = '' and (select saldo_actual from vales_regalo where restaurant_id = r and codigo = 'ZZMXHOY2') = 45,
    coalesce(nullif(v_err, ''), 'aceptado'));
  perform pg_temp.anotar('6. México: hoy del restaurante frente a hoy de Madrid (informativo)', true,
    fn_hoy_restaurante(r)::text || ' en México / ' || fn_hoy_madrid()::text || ' en Madrid');
end
$$;

-- Disponibilidad con una mesa abierta: la sesión cuenta en la hora del restaurante.
do $$
declare
  r uuid := pg_temp.id('mex');
  L timestamp := fn_ahora_restaurante(r);
  v_t timestamp := L + interval '20 minutes';
begin
  -- Las dos mesas de 4 ocupadas por sesiones abiertas ahora mismo: no hay mesa en L+20.
  insert into table_sessions (table_id, restaurant_id, comensales)
  select t.id, r, 4 from tables t where t.restaurant_id = r and t.numero = 9102;
  perform pg_temp.anotar('5. México: fn_reserva_hay_mesa con las dos mesas abiertas ahora → sin mesa en L+20',
    not fn_reserva_hay_mesa(r, v_t::date, v_t::time, 2, null, 120), 'hay_mesa');
  perform pg_temp.anotar('5. México: fn_reserva_hay_mesa a L+20 h → hay mesa',
    fn_reserva_hay_mesa(r, (L + interval '20 hours')::date, (L + interval '20 hours')::time, 2, null, 120), 'hay_mesa');
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL zona_horaria', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
