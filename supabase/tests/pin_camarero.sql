-- =============================================================================
-- Sesión de camarero con PIN — criterios 1 a 6 de
-- docs/specs/2026-11-12-pin-camarero.md
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback:
-- los restaurantes, camareros, mesas, pedidos y sesiones de prueba no quedan.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/pin_camarero.sql
--
-- Pensada para Test con las DOS fases aplicadas. Con solo la fase 1 (modo
-- tolerante) fallan, a propósito, las filas marcadas "[fase 2]": las llamadas
-- sin token todavía funcionan como antes (eso lo comprueba
-- supabase/tests/pin_camarero_fase1.sql). Todo lo demás debe salir ok ya
-- con la fase 1.
--
-- Crea como postgres dos restaurantes de prueba (R1 y R2, del primer dueño
-- que encuentra en Test), camareros con PIN conocido, mesas, una sesión de
-- mesa, un pedido, una llamada, un cliente con puntos, una reserva y un vale.
-- Las llamadas a las funciones van como anon (el personal no tiene sesión de
-- Supabase) con pg_temp.como(), que devuelve sqlstate, mensaje, resultado y si
-- cambió el estado de las filas de prueba (pg_temp.huella()).
--
-- Resultado: una fila por comprobación (prueba, ok, detalle) y una fila TOTAL.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;
create temp table _ctx (k text primary key, v text) on commit drop;

-- Ayudantes ------------------------------------------------------------------------
create function pg_temp.ctx(p_k text) returns text language sql as
$$ select v from _ctx where k = p_k $$;

create function pg_temp.guardar(p_k text, p_v text) returns void language sql as
$$ insert into _ctx (k, v) values (p_k, p_v) on conflict (k) do update set v = excluded.v $$;

create function pg_temp.anotar(p_prueba text, p_ok boolean, p_detalle text) returns void language sql as
$$ insert into _resultado (prueba, ok, detalle) values (p_prueba, coalesce(p_ok, false), coalesce(p_detalle, '')) $$;

-- Estado de las filas de prueba (para comprobar "no cambia nada").
create function pg_temp.huella() returns text language sql as $$
  with r as (select pg_temp.ctx('r1')::uuid as id union all select pg_temp.ctx('r2')::uuid)
  select md5(concat_ws('#',
    (select string_agg(x::text, ',' order by x.id) from public.tables x where x.restaurant_id in (select id from r)),
    (select string_agg(x::text, ',' order by x.id) from public.table_sessions x where x.restaurant_id in (select id from r)),
    (select string_agg(x::text, ',' order by x.id) from public.orders x where x.restaurant_id in (select id from r)),
    (select string_agg(x::text, ',' order by x.id) from public.order_items x where x.restaurant_id in (select id from r)),
    (select string_agg(x::text, ',' order by x.id) from public.reservations x where x.restaurant_id in (select id from r)),
    (select string_agg(x::text, ',' order by x.id) from public.waiter_calls x where x.restaurant_id in (select id from r)),
    (select string_agg(x::text, ',' order by x.id) from public.clientes x where x.restaurant_id in (select id from r)),
    (select string_agg(m::text, ',' order by m.id) from public.clientes_movimientos m
       join public.clientes c on c.id = m.cliente_id where c.restaurant_id in (select id from r)),
    (select string_agg(x::text, ',' order by x.id) from public.vales_regalo x where x.restaurant_id in (select id from r))
  ))
$$;

-- Ejecuta p_sql con el rol p_rol. Si p_deshacer, deshace lo que haya hecho.
create function pg_temp.como(p_rol text, p_sql text, p_deshacer boolean default false,
                             out estado text, out mensaje text, out resultado text, out cambio boolean)
language plpgsql as $$
declare
  v_antes text := pg_temp.huella();
begin
  cambio := false;
  begin
    execute format('set local role %I', p_rol);
    execute p_sql into resultado;
    estado := '00000';
    reset role;
    cambio := pg_temp.huella() is distinct from v_antes;
    if p_deshacer then
      raise exception using errcode = 'ZZ999', message = 'deshacer';
    end if;
  exception
    when sqlstate 'ZZ999' then null;
    when others then
      estado := sqlstate;
      mensaje := sqlerrm;
  end;
  reset role;
end
$$;

-- Inicia sesión (como anon) y devuelve el token, o null.
create function pg_temp.entrar(p_r uuid, p_c uuid, p_pin text) returns text language plpgsql as $$
declare q record;
begin
  q := pg_temp.como('anon', format(
    'select row_to_json(x)::text from public.fn_verificar_camarero_pin(%L, %L, %L) x', p_r, p_c, p_pin));
  if q.estado <> '00000' or q.resultado is null then return null; end if;
  return q.resultado::json->>'token';
end
$$;

-- Llamada a cada función protegida, con parámetros por nombre (como PostgREST).
create function pg_temp.sql_llamada(p_f text, p_r uuid, p_c uuid, p_t text) returns text language plpgsql as $$
begin
  return case p_f
    when 'fn_camarero_listar_sesiones' then format(
      'select count(*)::text from public.fn_camarero_listar_sesiones(p_restaurant_id => %L, p_camarero_id => %L, p_token => %L)', p_r, p_c, p_t)
    when 'fn_camarero_abrir_mesa' then format(
      'select count(*)::text from public.fn_camarero_abrir_mesa(p_table_id => %L, p_restaurant_id => %L, p_camarero_id => %L, p_comensales => 2, p_token => %L)',
      pg_temp.ctx('t2'), p_r, p_c, p_t)
    when 'fn_camarero_tomar_mesa' then format(
      'select count(*)::text from public.fn_camarero_tomar_mesa(p_table_session_id => %L, p_restaurant_id => %L, p_camarero_id => %L, p_token => %L)',
      pg_temp.ctx('s1'), p_r, p_c, p_t)
    when 'fn_camarero_listar_pedidos_sesion' then format(
      'select count(*)::text from public.fn_camarero_listar_pedidos_sesion(p_restaurant_id => %L, p_camarero_id => %L, p_table_session_id => %L, p_token => %L)',
      p_r, p_c, pg_temp.ctx('s1'), p_t)
    when 'fn_camarero_editar_cliente_sesion' then format(
      'select count(*)::text from public.fn_camarero_editar_cliente_sesion(p_table_session_id => %L, p_restaurant_id => %L, p_camarero_id => %L, p_telefono => %L, p_nombre => %L, p_token => %L)',
      pg_temp.ctx('s1'), p_r, p_c, '600000003', 'zz Nuevo', p_t)
    when 'fn_staff_listar_llamadas' then format(
      'select count(*)::text from public.fn_staff_listar_llamadas(p_restaurant_id => %L, p_camarero_id => %L, p_token => %L)', p_r, p_c, p_t)
    when 'fn_staff_marcar_llamada_atendida' then format(
      'select count(*)::text from public.fn_staff_marcar_llamada_atendida(p_restaurant_id => %L, p_camarero_id => %L, p_llamada_id => %L, p_token => %L)',
      p_r, p_c, pg_temp.ctx('w1'), p_t)
    when 'fn_registrar_pedido' then format(
      'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => %L::jsonb, p_camarero_id => %L, p_camarero_token => %L)::text',
      pg_temp.ctx('s1'), jsonb_build_array(jsonb_build_object('menu_item_id', pg_temp.ctx('m1'), 'cantidad', 1))::text, p_c, p_t)
    when 'fn_camarero_toggle_limpieza' then format(
      'select count(*)::text from public.fn_camarero_toggle_limpieza(p_table_id => %L, p_restaurant_id => %L, p_paso_id => %L, p_camarero_id => %L, p_token => %L)',
      pg_temp.ctx('t3'), p_r, pg_temp.ctx('p1'), p_c, p_t)
    when 'fn_staff_contar_alertas' then format(
      'select public.fn_staff_contar_alertas(p_restaurant_id => %L, p_camarero_id => %L, p_token => %L)::text', p_r, p_c, p_t)
    when 'fn_staff_listar_clientes' then format(
      'select count(*)::text from public.fn_staff_listar_clientes(p_restaurant_id => %L, p_camarero_id => %L, p_token => %L)', p_r, p_c, p_t)
    when 'fn_staff_historial_cliente' then format(
      'select count(*)::text from public.fn_staff_historial_cliente(p_restaurant_id => %L, p_camarero_id => %L, p_cliente_id => %L, p_token => %L)',
      p_r, p_c, pg_temp.ctx('cl1'), p_t)
    when 'fn_staff_canjear_puntos' then format(
      'select count(*)::text from public.fn_staff_canjear_puntos(p_restaurant_id => %L, p_camarero_id => %L, p_cliente_id => %L, p_cantidad => 10, p_token => %L)',
      p_r, p_c, pg_temp.ctx('cl1'), p_t)
    when 'fn_staff_listar_reservas' then format(
      'select count(*)::text from public.fn_staff_listar_reservas(p_restaurant_id => %L, p_camarero_id => %L, p_token => %L)', p_r, p_c, p_t)
    when 'fn_staff_cambiar_estado_reserva' then format(
      'select count(*)::text from public.fn_staff_cambiar_estado_reserva(p_restaurant_id => %L, p_camarero_id => %L, p_reserva_id => %L, p_nuevo_estado => %L, p_token => %L)',
      p_r, p_c, pg_temp.ctx('rs1'), 'cancelada', p_t)
    when 'fn_staff_crear_reserva_manual' then format(
      'select public.fn_staff_crear_reserva_manual(p_restaurant_id => %L, p_camarero_id => %L, p_nombre => %L, p_telefono => %L, p_fecha => current_date + 1, p_hora => %L, p_personas => 2, p_token => %L)::text',
      p_r, p_c, 'zz Reserva nueva', '600000004', '21:00', p_t)
    when 'fn_staff_listar_pedidos_cocina' then format(
      'select public.fn_staff_listar_pedidos_cocina(p_restaurant_id => %L, p_camarero_id => %L, p_token => %L)::text', p_r, p_c, p_t)
    when 'fn_staff_cambiar_estado_pedido' then format(
      'select count(*)::text from public.fn_staff_cambiar_estado_pedido(p_restaurant_id => %L, p_camarero_id => %L, p_order_id => %L, p_nuevo_estado => %L, p_token => %L)',
      p_r, p_c, pg_temp.ctx('o1'), 'preparando', p_t)
  end;
end
$$;

-- Funciones protegidas y el permiso que exigen (tabla de la spec).
create temp table _protegidas (orden int, funcion text, permiso text) on commit drop;
insert into _protegidas values
  (1,  'fn_camarero_listar_sesiones',       'pedidos'),
  (2,  'fn_camarero_abrir_mesa',            'pedidos'),
  (3,  'fn_camarero_tomar_mesa',            'pedidos'),
  (4,  'fn_camarero_listar_pedidos_sesion', 'pedidos'),
  (5,  'fn_camarero_editar_cliente_sesion', 'pedidos'),
  (6,  'fn_staff_listar_llamadas',          'pedidos'),
  (7,  'fn_staff_marcar_llamada_atendida',  'pedidos'),
  (8,  'fn_registrar_pedido',               'pedidos'),
  (9,  'fn_camarero_toggle_limpieza',       'limpieza o pedidos'),
  (10, 'fn_staff_contar_alertas',           'ninguno'),
  (11, 'fn_staff_listar_clientes',          'clientes'),
  (12, 'fn_staff_historial_cliente',        'clientes'),
  (13, 'fn_staff_canjear_puntos',           'clientes'),
  (14, 'fn_staff_listar_reservas',          'reservas'),
  (15, 'fn_staff_cambiar_estado_reserva',   'reservas'),
  (16, 'fn_staff_crear_reserva_manual',     'reservas'),
  (17, 'fn_staff_listar_pedidos_cocina',    'cocina'),
  (18, 'fn_staff_cambiar_estado_pedido',    'cocina');

-- Datos de prueba (como postgres) ---------------------------------------------------
do $$
declare
  v_owner uuid;
  v_suf text := substr(md5(random()::text), 1, 8);
  r1 uuid; r2 uuid; ca uuid; cb uuid; cc uuid; cd uuid;
  t1 uuid; t2 uuid; t3 uuid; t4 uuid; p1 uuid; p2 uuid;
  s1 uuid; sqr uuid; m1 uuid; o1 uuid; w1 uuid; cl1 uuid; rs1 uuid;
begin
  select r.user_id into v_owner from public.restaurants r where r.user_id is not null order by r.created_at limit 1;

  insert into public.restaurants (nombre, slug, user_id, config)
  values ('zz Prueba PIN 1', 'zz-pin-1-' || v_suf, v_owner, '{"modo_pedidos":"camarero"}') returning id into r1;
  insert into public.restaurants (nombre, slug, user_id, config)
  values ('zz Prueba PIN 2', 'zz-pin-2-' || v_suf, v_owner, '{"modo_pedidos":"camarero"}') returning id into r2;

  insert into public.camareros (restaurant_id, nombre, permisos, pin_hash)
  values (r1, 'zz Ana', '{pedidos,limpieza,clientes,reservas,cocina}', extensions.crypt('1234', extensions.gen_salt('bf'))) returning id into ca;
  insert into public.camareros (restaurant_id, nombre, permisos, pin_hash)
  values (r1, 'zz Bruno', '{pedidos}', extensions.crypt('5678', extensions.gen_salt('bf'))) returning id into cb;
  insert into public.camareros (restaurant_id, nombre, permisos, pin_hash)
  values (r2, 'zz Carla', '{pedidos,limpieza,clientes,reservas,cocina}', extensions.crypt('1234', extensions.gen_salt('bf'))) returning id into cc;
  insert into public.camareros (restaurant_id, nombre, permisos, pin_hash)
  values (r1, 'zz Dani', '{pedidos}', extensions.crypt('9999', extensions.gen_salt('bf'))) returning id into cd;

  insert into public.tables (restaurant_id, numero) values (r1, 9001) returning id into t1;
  insert into public.tables (restaurant_id, numero) values (r1, 9002) returning id into t2;
  insert into public.tables (restaurant_id, numero, necesita_limpieza) values (r1, 9003, true) returning id into t3;
  insert into public.tables (restaurant_id, numero) values (r1, 9004) returning id into t4;

  insert into public.limpieza_pasos (restaurant_id, texto, orden) values (r1, 'zz Paso 1', 1) returning id into p1;
  insert into public.limpieza_pasos (restaurant_id, texto, orden) values (r1, 'zz Paso 2', 2) returning id into p2;

  insert into public.table_sessions (table_id, restaurant_id, comensales, cliente_telefono, cliente_nombre)
  values (t1, r1, 2, '600000001', 'zz Cliente') returning id into s1;
  insert into public.table_sessions (table_id, restaurant_id, comensales, cliente_telefono, cliente_nombre)
  values (t4, r1, 2, '600000001', 'zz Cliente') returning id into sqr;

  insert into public.menu_items (restaurant_id, nombre, precio) values (r1, 'zz Caña', 2.50) returning id into m1;

  insert into public.orders (restaurant_id, table_id, table_session_id, tipo, estado)
  values (r1, t1, s1, 'mesa', 'pendiente') returning id into o1;

  insert into public.waiter_calls (restaurant_id, table_id, estado) values (r1, t1, 'pendiente') returning id into w1;

  insert into public.clientes (restaurant_id, telefono, nombre, puntos) values (r1, '600000001', 'zz Cliente', 100) returning id into cl1;

  insert into public.reservations (restaurant_id, nombre, telefono, fecha, hora, personas, estado, origen)
  values (r1, 'zz Reserva', '600000002', current_date + 1, '21:00', 2, 'confirmada', 'manual') returning id into rs1;

  insert into public.vales_regalo (restaurant_id, codigo, importe_inicial, saldo_actual, fecha_vencimiento)
  values (r1, 'ZZPIN1', 50, 50, current_date + 30);

  perform pg_temp.guardar('owner', v_owner::text);
  perform pg_temp.guardar('r1', r1::text);   perform pg_temp.guardar('r2', r2::text);
  perform pg_temp.guardar('ca', ca::text);   perform pg_temp.guardar('cb', cb::text);
  perform pg_temp.guardar('cc', cc::text);   perform pg_temp.guardar('cd', cd::text);
  perform pg_temp.guardar('t1', t1::text);   perform pg_temp.guardar('t2', t2::text);
  perform pg_temp.guardar('t3', t3::text);   perform pg_temp.guardar('t4', t4::text);
  perform pg_temp.guardar('p1', p1::text);   perform pg_temp.guardar('p2', p2::text);
  perform pg_temp.guardar('s1', s1::text);   perform pg_temp.guardar('sqr', sqr::text);
  perform pg_temp.guardar('m1', m1::text);   perform pg_temp.guardar('o1', o1::text);
  perform pg_temp.guardar('w1', w1::text);   perform pg_temp.guardar('cl1', cl1::text);
  perform pg_temp.guardar('rs1', rs1::text);

  perform pg_temp.anotar('0. datos de prueba creados', v_owner is not null,
    case when v_owner is null then 'no hay ningún restaurante con dueño en Test (hace falta para el criterio 4d)' else 'R1 ' || r1 || ', R2 ' || r2 end);
end
$$;

-- Criterio 1: inicio de sesión con PIN ------------------------------------------------
do $$
declare
  r1 uuid := pg_temp.ctx('r1'); r2 uuid := pg_temp.ctx('r2');
  ca uuid := pg_temp.ctx('ca'); cb uuid := pg_temp.ctx('cb'); cc uuid := pg_temp.ctx('cc'); cd uuid := pg_temp.ctx('cd');
  q record; j json; v_tok text; n int; n_antes int; i int;
begin
  q := pg_temp.como('anon', format(
    'select row_to_json(x)::text from public.fn_verificar_camarero_pin(%L, %L, %L) x', r1, ca, '1234'));
  j := case when q.resultado is not null then q.resultado::json end;
  v_tok := j->>'token';
  perform pg_temp.anotar('1. PIN correcto → id, nombre, permisos, token de 64 hex y caduca_at = ahora + 12 h',
    q.estado = '00000'
      and (j->>'id')::uuid = ca
      and j->>'nombre' = 'zz Ana'
      and json_array_length(j->'permisos') = 5
      and v_tok ~ '^[0-9a-f]{64}$'
      and abs(extract(epoch from ((j->>'caduca_at')::timestamptz - (now() + interval '12 hours')))) <= 60,
    coalesce(q.mensaje, left(q.resultado, 60) || '… caduca_at=' || coalesce(j->>'caduca_at', 'null')));
  perform pg_temp.guardar('ta', v_tok);

  begin
    select count(*) into n from public.camarero_sesiones s
    where s.camarero_id = ca and s.restaurant_id = r1
      and s.token_hash = encode(extensions.digest(v_tok, 'sha256'), 'hex')
      and s.revocada_at is null;
    perform pg_temp.anotar('1. camarero_sesiones: fila nueva con el sha256 del token y sin el token en claro',
      n = 1 and not exists (select 1 from public.camarero_sesiones s where position(v_tok in s::text) > 0),
      n || ' filas con ese hash');
  exception when others then
    perform pg_temp.anotar('1. camarero_sesiones: fila nueva con el sha256 del token y sin el token en claro', false, sqlerrm);
  end;

  -- PIN incorrecto: 0 filas y ninguna sesión nueva
  begin
    select count(*) into n_antes from public.camarero_sesiones;
  exception when others then n_antes := null;
  end;
  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_verificar_camarero_pin(%L, %L, %L)', r1, cb, '0000'));
  begin
    select count(*) into n from public.camarero_sesiones;
  exception when others then n := null;
  end;
  perform pg_temp.anotar('1. PIN incorrecto → 0 filas y ninguna sesión nueva',
    q.estado = '00000' and q.resultado = '0' and n_antes is not null and n = n_antes,
    coalesce(q.mensaje, q.resultado || ' filas; sesiones ' || coalesce(n_antes::text, '?') || ' → ' || coalesce(n::text, '?')));

  -- Tokens de B (mismo restaurante) y de C (otro restaurante) para los demás criterios
  perform pg_temp.guardar('tb', pg_temp.entrar(r1, cb, '5678'));
  perform pg_temp.guardar('tc', pg_temp.entrar(r2, cc, '1234'));
  perform pg_temp.anotar('1. B y C también inician sesión',
    pg_temp.ctx('tb') is not null and pg_temp.ctx('tc') is not null and pg_temp.ctx('tb') <> pg_temp.ctx('tc'),
    'tb ' || coalesce(left(pg_temp.ctx('tb'), 8), 'null') || '…, tc ' || coalesce(left(pg_temp.ctx('tc'), 8), 'null') || '…');

  -- 10 fallos seguidos → bloqueo (camarero D)
  for i in 1..10 loop
    q := pg_temp.como('anon', format(
      'select count(*)::text from public.fn_verificar_camarero_pin(%L, %L, %L)', r1, cd, '0000'));
  end loop;
  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_verificar_camarero_pin(%L, %L, %L)', r1, cd, '9999'));
  perform pg_temp.anotar('1. tras 10 fallos → "Demasiados intentos fallidos…" (aun con el PIN bueno)',
    q.estado <> '00000' and q.mensaje like 'Demasiados intentos fallidos%',
    coalesce(q.mensaje, 'sin error: ' || q.resultado));
end
$$;

-- Criterio 2: sin token, token inventado, de otro camarero o de otro restaurante → RM401 --
do $$
declare
  r1 uuid := pg_temp.ctx('r1'); ca uuid := pg_temp.ctx('ca');
  f record; c record; q record;
begin
  for f in select * from _protegidas order by orden loop
    for c in
      select * from (values
        (1, 'sin token [fase 2]',          null::text),
        (2, 'token inventado',             encode(extensions.gen_random_bytes(32), 'hex')),
        (3, 'token de otro camarero',      pg_temp.ctx('tb')),
        (4, 'token de otro restaurante',   pg_temp.ctx('tc'))
      ) as v(n, caso, tok)
      order by n
    loop
      q := pg_temp.como('anon', pg_temp.sql_llamada(f.funcion, r1, ca, c.tok), true);
      perform pg_temp.anotar('2. ' || f.funcion || ', ' || c.caso || ' → RM401 y sin cambios',
        q.estado = 'RM401' and not q.cambio,
        q.estado || ' ' || coalesce(q.mensaje, 'resultado ' || coalesce(q.resultado, 'null')) || case when q.cambio then ' (¡cambió datos!)' else '' end);
    end loop;
  end loop;

  -- La llamada de la versión vieja (solo p_restaurant_id) ya no da teléfonos ni nombres.
  q := pg_temp.como('anon', format(
    'select coalesce(string_agg(coalesce(cliente_telefono, '''') || coalesce(cliente_nombre, ''''), '',''), '''') from public.fn_camarero_listar_sesiones(p_restaurant_id => %L)', r1), true);
  perform pg_temp.anotar('2. fn_camarero_listar_sesiones(p_restaurant_id) sin más → RM401, sin teléfonos ni nombres [fase 2]',
    q.estado = 'RM401' and q.resultado is null,
    q.estado || ' ' || coalesce(q.mensaje, 'devolvió: ' || coalesce(q.resultado, 'null')));
end
$$;

-- Criterio 3: con sesión válida funciona como antes; sin el permiso, "No autorizado" ---
do $$
declare
  r1 uuid := pg_temp.ctx('r1'); ca uuid := pg_temp.ctx('ca'); cb uuid := pg_temp.ctx('cb');
  ta text := pg_temp.ctx('ta'); tb text := pg_temp.ctx('tb');
  q record; j jsonb; v_id uuid; n int; f record;
begin
  -- Lecturas
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_camarero_listar_sesiones → las 2 mesas abiertas',
    q.estado = '00000' and q.resultado = '2', coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_contar_alertas', r1, ca, ta));
  j := case when q.estado = '00000' then q.resultado::jsonb end;
  perform pg_temp.anotar('3. A (limpieza+pedidos): fn_staff_contar_alertas → limpieza 1, llamadas 1',
    (j->>'limpieza')::int = 1 and (j->>'llamadas')::int = 1, coalesce(q.mensaje, q.resultado));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_contar_alertas', r1, cb, tb));
  j := case when q.estado = '00000' then q.resultado::jsonb end;
  perform pg_temp.anotar('3. B (solo pedidos): fn_staff_contar_alertas → limpieza 0, llamadas 1',
    (j->>'limpieza')::int = 0 and (j->>'llamadas')::int = 1, coalesce(q.mensaje, q.resultado));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_listar_llamadas', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_listar_llamadas → 1 llamada',
    q.estado = '00000' and q.resultado = '1', coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_pedidos_sesion', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_camarero_listar_pedidos_sesion → el pedido de la mesa',
    q.estado = '00000' and q.resultado::int >= 1, coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_listar_clientes', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_listar_clientes → el cliente',
    q.estado = '00000' and q.resultado = '1', coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_historial_cliente', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_historial_cliente → sin error',
    q.estado = '00000', coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_listar_reservas', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_listar_reservas → la reserva',
    q.estado = '00000' and q.resultado = '1', coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_listar_pedidos_cocina', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_listar_pedidos_cocina → incluye el pedido de prueba',
    q.estado = '00000' and q.resultado::jsonb @> jsonb_build_array(jsonb_build_object('id', pg_temp.ctx('o1'))),
    coalesce(q.mensaje, left(q.resultado, 80)));

  -- Escrituras
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_abrir_mesa', r1, ca, ta));
  select count(*) into n from public.table_sessions
  where table_id = pg_temp.ctx('t2')::uuid and estado = 'abierta' and camarero_id = ca;
  perform pg_temp.anotar('3. A: fn_camarero_abrir_mesa → mesa abierta y asignada a A',
    q.estado = '00000' and n = 1, coalesce(q.mensaje, n || ' sesiones abiertas de A en la mesa'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_tomar_mesa', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_camarero_tomar_mesa → la sesión pasa a A',
    q.estado = '00000' and (select camarero_id from public.table_sessions where id = pg_temp.ctx('s1')::uuid) = ca,
    coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_editar_cliente_sesion', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_camarero_editar_cliente_sesion → teléfono y nombre guardados',
    q.estado = '00000' and exists (select 1 from public.table_sessions
      where id = pg_temp.ctx('s1')::uuid and cliente_telefono = '600000003' and cliente_nombre = 'zz Nuevo'),
    coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_registrar_pedido', r1, ca, ta));
  v_id := case when q.estado = '00000' then q.resultado::uuid end;
  perform pg_temp.anotar('3. A: fn_registrar_pedido con su token → tomado_por = A',
    v_id is not null and (select tomado_por from public.orders where id = v_id) = ca,
    coalesce(q.mensaje, 'pedido ' || v_id));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_toggle_limpieza', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_camarero_toggle_limpieza → paso guardado',
    q.estado = '00000' and (select limpieza_progreso from public.tables where id = pg_temp.ctx('t3')::uuid) ? pg_temp.ctx('p1'),
    coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_marcar_llamada_atendida', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_marcar_llamada_atendida → llamada atendida',
    q.estado = '00000' and (select estado from public.waiter_calls where id = pg_temp.ctx('w1')::uuid) = 'atendido',
    coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_canjear_puntos', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_canjear_puntos 10 → 90 puntos y movimiento de resta',
    q.estado = '00000'
      and (select puntos from public.clientes where id = pg_temp.ctx('cl1')::uuid) = 90
      and exists (select 1 from public.clientes_movimientos
                  where cliente_id = pg_temp.ctx('cl1')::uuid and tipo = 'resta' and puntos = 10),
    coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_crear_reserva_manual', r1, ca, ta));
  v_id := case when q.estado = '00000' then q.resultado::uuid end;
  perform pg_temp.anotar('3. A: fn_staff_crear_reserva_manual → reserva creada',
    v_id is not null and exists (select 1 from public.reservations where id = v_id and restaurant_id = r1 and origen = 'manual'),
    coalesce(q.mensaje, 'reserva ' || v_id));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_cambiar_estado_reserva', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_cambiar_estado_reserva → cancelada',
    q.estado = '00000' and (select estado from public.reservations where id = pg_temp.ctx('rs1')::uuid) = 'cancelada',
    coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_cambiar_estado_pedido', r1, ca, ta));
  perform pg_temp.anotar('3. A: fn_staff_cambiar_estado_pedido → preparando',
    q.estado = '00000' and (select estado from public.orders where id = pg_temp.ctx('o1')::uuid) = 'preparando',
    coalesce(q.mensaje, 'ok'));

  -- B (solo pedidos): lo de pedidos y limpieza funciona; lo demás, "No autorizado"
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, cb, tb), true);
  perform pg_temp.anotar('3. B (solo pedidos): fn_camarero_listar_sesiones → funciona',
    q.estado = '00000', coalesce(q.mensaje, q.resultado || ' filas'));
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_toggle_limpieza', r1, cb, tb), true);
  perform pg_temp.anotar('3. B (solo pedidos): fn_camarero_toggle_limpieza → funciona (checklist desde Pedidos)',
    q.estado = '00000', coalesce(q.mensaje, 'ok'));

  for f in select * from _protegidas where permiso in ('clientes', 'reservas', 'cocina') order by orden loop
    q := pg_temp.como('anon', pg_temp.sql_llamada(f.funcion, r1, cb, tb), true);
    perform pg_temp.anotar('3. B (solo pedidos): ' || f.funcion || ' → No autorizado',
      q.estado = 'P0001' and q.mensaje = 'No autorizado', q.estado || ' ' || coalesce(q.mensaje, 'sin error'));
  end loop;

  -- El dueño le quita permisos a A con la sesión abierta
  update public.camareros set permisos = '{pedidos}' where id = ca;
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_listar_clientes', r1, ca, ta), true);
  perform pg_temp.anotar('3. A tras quitarle "clientes": fn_staff_listar_clientes → No autorizado',
    q.estado = 'P0001' and q.mensaje = 'No autorizado', q.estado || ' ' || coalesce(q.mensaje, 'sin error'));
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_staff_contar_alertas', r1, ca, ta));
  j := case when q.estado = '00000' then q.resultado::jsonb end;
  perform pg_temp.anotar('3. A tras quitarle "limpieza": fn_staff_contar_alertas → limpieza 0',
    (j->>'limpieza')::int = 0, coalesce(q.mensaje, q.resultado));
end
$$;

-- Criterio 5: la mesa por QR sigue igual; un pedido "de camarero" exige su sesión ------
do $$
declare
  r1 uuid := pg_temp.ctx('r1'); ca uuid := pg_temp.ctx('ca'); cc uuid := pg_temp.ctx('cc');
  sqr uuid := pg_temp.ctx('sqr');
  v_items text := jsonb_build_array(jsonb_build_object('menu_item_id', pg_temp.ctx('m1'), 'cantidad', 1))::text;
  q record; v_id uuid;
begin
  q := pg_temp.como('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => %L::jsonb)::text', sqr, v_items));
  v_id := case when q.estado = '00000' then q.resultado::uuid end;
  perform pg_temp.anotar('5. QR: fn_registrar_pedido sin camarero → pedido creado y tomado_por vacío',
    v_id is not null and exists (select 1 from public.orders where id = v_id and tomado_por is null),
    coalesce(q.mensaje, 'pedido ' || v_id));

  q := pg_temp.como('anon', format(
    'select public.fn_estado_fidelizacion(p_restaurant_id => %L, p_telefono => %L)::text', r1, '600000001'));
  perform pg_temp.anotar('5. QR: fn_estado_fidelizacion → funciona',
    q.estado = '00000' and q.resultado::jsonb ? 'puntos', coalesce(q.mensaje, left(q.resultado, 60)));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_consultar_vale(p_restaurant_id => %L, p_codigo => %L)', r1, 'zzpin1'));
  perform pg_temp.anotar('5. QR: fn_consultar_vale → encuentra el vale',
    q.estado = '00000' and q.resultado = '1', coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_canjear_vale_regalo(p_table_session_id => %L, p_vale_codigo => %L, p_vale_importe => 5)', sqr, 'ZZPIN1'));
  perform pg_temp.anotar('5. QR: fn_canjear_vale_regalo 5 → saldo 45',
    q.estado = '00000' and (select saldo_actual from public.vales_regalo where restaurant_id = r1 and codigo = 'ZZPIN1') = 45,
    coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => %L::jsonb, p_camarero_id => %L)::text', sqr, v_items, ca), true);
  perform pg_temp.anotar('5. fn_registrar_pedido con p_camarero_id y sin token → RM401 y sin pedido [fase 2]',
    q.estado = 'RM401' and not q.cambio, q.estado || ' ' || coalesce(q.mensaje, 'pedido ' || q.resultado));

  q := pg_temp.como('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => %L::jsonb, p_camarero_id => %L, p_camarero_token => %L)::text',
    sqr, v_items, ca, encode(extensions.gen_random_bytes(32), 'hex')), true);
  perform pg_temp.anotar('5. fn_registrar_pedido con p_camarero_id y token inventado → RM401 y sin pedido',
    q.estado = 'RM401' and not q.cambio, q.estado || ' ' || coalesce(q.mensaje, 'pedido ' || q.resultado));

  q := pg_temp.como('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => %L::jsonb, p_camarero_id => %L, p_camarero_token => %L)::text',
    sqr, v_items, cc, pg_temp.ctx('tc')), true);
  perform pg_temp.anotar('5. fn_registrar_pedido en R1 con camarero y token válidos de R2 → RM401',
    q.estado = 'RM401' and not q.cambio, q.estado || ' ' || coalesce(q.mensaje, 'pedido ' || q.resultado));

  q := pg_temp.como('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => %L::jsonb, p_camarero_id => %L, p_camarero_token => %L)::text',
    sqr, v_items, ca, pg_temp.ctx('ta')));
  v_id := case when q.estado = '00000' then q.resultado::uuid end;
  perform pg_temp.anotar('5. fn_registrar_pedido con p_camarero_id y su token → tomado_por = ese camarero',
    v_id is not null and (select tomado_por from public.orders where id = v_id) = ca,
    coalesce(q.mensaje, 'pedido ' || v_id));
end
$$;

-- Criterio 6: esquema -------------------------------------------------------------------
do $$
declare
  v_t text; v_oid oid; v_f record; n int; p record;
  v_todos constant text := 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER';
begin
  foreach v_t in array array['camarero_sesiones', 'camarero_llamadas_sin_token'] loop
    v_oid := to_regclass('public.' || v_t);
    if v_oid is null then
      perform pg_temp.anotar('6. ' || v_t || ': RLS activado y sin grants a anon ni authenticated',
        v_t = 'camarero_llamadas_sin_token', 'no existe' || case when v_t = 'camarero_llamadas_sin_token' then ' (normal tras la fase 2)' else '' end);
      continue;
    end if;
    perform pg_temp.anotar('6. ' || v_t || ': RLS activado y sin grants a anon ni authenticated',
      (select relrowsecurity from pg_class where oid = v_oid)
        and not has_table_privilege('anon', v_oid, v_todos)
        and not has_table_privilege('authenticated', v_oid, v_todos)
        and has_table_privilege('service_role', v_oid, 'SELECT,INSERT,UPDATE,DELETE')
        and exists (select 1 from pg_policy where polrelid = v_oid),
      'rls=' || (select relrowsecurity from pg_class where oid = v_oid)
        || ' anon=' || has_table_privilege('anon', v_oid, v_todos)
        || ' authenticated=' || has_table_privilege('authenticated', v_oid, v_todos)
        || ' políticas=' || (select count(*) from pg_policy where polrelid = v_oid));
  end loop;

  v_oid := to_regprocedure('public.fn_camarero_cerrar_sesion(text)');
  perform pg_temp.anotar('6. fn_camarero_cerrar_sesion en el grupo A (anon, authenticated, service_role)',
    v_oid is not null
      and has_function_privilege('anon', v_oid, 'execute')
      and has_function_privilege('authenticated', v_oid, 'execute')
      and has_function_privilege('service_role', v_oid, 'execute'),
    coalesce((select proacl::text from pg_proc where oid = v_oid), 'no existe'));

  v_oid := to_regprocedure('public.fn_staff_exigir_sesion(uuid, uuid, text, text[], text)');
  perform pg_temp.anotar('6. fn_staff_exigir_sesion en el grupo C (solo service_role)',
    v_oid is not null
      and not has_function_privilege('anon', v_oid, 'execute')
      and not has_function_privilege('authenticated', v_oid, 'execute')
      and has_function_privilege('service_role', v_oid, 'execute'),
    coalesce((select proacl::text from pg_proc where oid = v_oid), 'no existe'));

  for v_f in
    select * from (values
      ('fn_camarero_listar_sesiones',       'uuid, uuid, text'),
      ('fn_camarero_abrir_mesa',            'uuid, uuid, uuid, integer, text'),
      ('fn_camarero_tomar_mesa',            'uuid, uuid, uuid, text'),
      ('fn_camarero_listar_pedidos_sesion', 'uuid, uuid, uuid, text'),
      ('fn_camarero_editar_cliente_sesion', 'uuid, uuid, uuid, text, text, text'),
      ('fn_staff_listar_llamadas',          'uuid, uuid, text'),
      ('fn_staff_marcar_llamada_atendida',  'uuid, uuid, uuid, text'),
      ('fn_registrar_pedido',               'uuid, jsonb, text, uuid, jsonb, text, numeric, text'),
      ('fn_camarero_toggle_limpieza',       'uuid, uuid, uuid, uuid, text'),
      ('fn_staff_contar_alertas',           'uuid, uuid, text'),
      ('fn_staff_listar_clientes',          'uuid, uuid, text'),
      ('fn_staff_historial_cliente',        'uuid, uuid, uuid, text'),
      ('fn_staff_canjear_puntos',           'uuid, uuid, uuid, integer, text, text'),
      ('fn_staff_listar_reservas',          'uuid, uuid, text'),
      ('fn_staff_cambiar_estado_reserva',   'uuid, uuid, uuid, text, text'),
      ('fn_staff_crear_reserva_manual',     'uuid, uuid, text, text, date, time, integer, text, text, text'),
      ('fn_staff_listar_pedidos_cocina',    'uuid, uuid, text'),
      ('fn_staff_cambiar_estado_pedido',    'uuid, uuid, uuid, text, text'),
      ('fn_verificar_camarero_pin',         'uuid, uuid, text'),
      ('fn_resetear_pin_camarero',          'uuid, uuid, text'),
      ('fn_camarero_cerrar_sesion',         'text'),
      ('fn_staff_exigir_sesion',            'uuid, uuid, text, text[], text')
    ) as v(nombre, args)
  loop
    select count(*) into n from pg_proc where pronamespace = 'public'::regnamespace and proname = v_f.nombre;
    v_oid := to_regprocedure('public.' || v_f.nombre || '(' || v_f.args || ')');
    select p2.prosecdef,
           exists (select 1 from unnest(p2.proconfig) cfg where cfg like 'search_path=%') as con_path,
           exists (select 1 from aclexplode(coalesce(p2.proacl, acldefault('f', p2.proowner))) a
                   where a.grantee = 0 and a.privilege_type = 'EXECUTE') as public_exec
      into p
    from pg_proc p2 where p2.oid = v_oid;
    perform pg_temp.anotar('6. ' || v_f.nombre || '(' || v_f.args || '): una sola versión, SECURITY DEFINER, search_path fijo, sin PUBLIC',
      n = 1 and v_oid is not null and p.prosecdef and p.con_path and not p.public_exec,
      n || ' versiones; ' || case when v_oid is null then 'no existe con esa firma'
        else 'definer=' || p.prosecdef || ' search_path=' || p.con_path || ' public=' || p.public_exec end);
  end loop;
end
$$;

-- Criterio 4: caducidad, cierre, baja, cambio de PIN y restaurante inactivo ------------
do $$
declare
  r1 uuid := pg_temp.ctx('r1'); r2 uuid := pg_temp.ctx('r2');
  ca uuid := pg_temp.ctx('ca'); cb uuid := pg_temp.ctx('cb'); cc uuid := pg_temp.ctx('cc');
  ta text := pg_temp.ctx('ta'); tb text := pg_temp.ctx('tb'); tc text := pg_temp.ctx('tc');
  v_tok text; q record; q2 record; q3 record;
  v_owner text := pg_temp.ctx('owner');
begin
  -- a) caducada
  v_tok := pg_temp.entrar(r1, ca, '1234');
  begin
    update public.camarero_sesiones set caduca_at = now() - interval '1 minute'
    where token_hash = encode(extensions.digest(v_tok, 'sha256'), 'hex');
  exception when others then null;
  end;
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, ca, v_tok), true);
  q2 := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, cb, tb), true);
  perform pg_temp.anotar('4a. sesión caducada → RM401; la de B sigue funcionando',
    v_tok is not null and q.estado = 'RM401' and q2.estado = '00000',
    'A: ' || q.estado || ' ' || coalesce(q.mensaje, '') || ' | B: ' || q2.estado || ' ' || coalesce(q2.mensaje, ''));

  -- b) cerrada con fn_camarero_cerrar_sesion
  v_tok := pg_temp.entrar(r1, ca, '1234');
  q3 := pg_temp.como('anon', format('select count(*)::text from public.fn_camarero_cerrar_sesion(%L)', v_tok));
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, ca, v_tok), true);
  q2 := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, ca, ta), true);
  perform pg_temp.anotar('4b. sesión cerrada (anon, fn_camarero_cerrar_sesion) → RM401; otra sesión de A sigue',
    v_tok is not null and q3.estado = '00000' and q.estado = 'RM401' and q2.estado = '00000',
    'cerrar: ' || q3.estado || ' ' || coalesce(q3.mensaje, '') || ' | después: ' || q.estado || ' | otra: ' || q2.estado);

  -- c) el dueño desactiva a B
  update public.camareros set activo = false where id = cb;
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, cb, tb), true);
  q2 := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, ca, ta), true);
  perform pg_temp.anotar('4c. camarero desactivado → RM401; la sesión de A sigue funcionando',
    q.estado = 'RM401' and q2.estado = '00000',
    'B: ' || q.estado || ' ' || coalesce(q.mensaje, '') || ' | A: ' || q2.estado || ' ' || coalesce(q2.mensaje, ''));

  -- d) el dueño cambia el PIN de A
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', coalesce(v_owner, ''), true);
  q3 := pg_temp.como('authenticated', format(
    'select count(*)::text from public.fn_resetear_pin_camarero(%L, %L, %L)', ca, r1, '4321'));
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, ca, ta), true);
  q2 := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r2, cc, tc), true);
  perform pg_temp.anotar('4d. el dueño cambia el PIN (fn_resetear_pin_camarero) → RM401; la de C sigue',
    q3.estado = '00000' and q.estado = 'RM401' and q2.estado = '00000',
    'reset: ' || q3.estado || ' ' || coalesce(q3.mensaje, '') || ' | A: ' || q.estado || ' | C: ' || q2.estado || ' ' || coalesce(q2.mensaje, ''));

  -- e) restaurante inactivo
  v_tok := pg_temp.entrar(r1, ca, '4321');
  update public.restaurants set activo = false where id = r1;
  q := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r1, ca, v_tok), true);
  q2 := pg_temp.como('anon', pg_temp.sql_llamada('fn_camarero_listar_sesiones', r2, cc, tc), true);
  perform pg_temp.anotar('4e. restaurante inactivo → RM401 o "no disponible"; la de C (otro restaurante) sigue',
    v_tok is not null
      and (q.estado = 'RM401' or q.mensaje like 'Este restaurante no está disponible%')
      and q2.estado = '00000',
    'nuevo PIN: ' || coalesce(left(v_tok, 8), 'null') || ' | A: ' || q.estado || ' ' || coalesce(q.mensaje, '') || ' | C: ' || q2.estado);
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL pin_camarero', count(*) filter (where not ok) = 0,
       count(*) filter (where not ok) || ' fallos de ' || count(*)
       || ' (de ellos [fase 2]: ' || count(*) filter (where not ok and prueba like '%[fase 2]%') || ')'
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
