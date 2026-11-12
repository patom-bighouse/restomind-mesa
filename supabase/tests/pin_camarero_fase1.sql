-- =============================================================================
-- Sesión de camarero con PIN — criterio 7 de docs/specs/2026-11-12-pin-camarero.md
-- (FASE 1, modo tolerante)
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql), y solo ENTRE la migración de fase 1
-- y la de fase 2 (con la fase 2 aplicada, las llamadas sin token dan RM401 y
-- esta prueba falla a propósito). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/pin_camarero_fase1.sql
--
-- Hace las llamadas EXACTAMENTE como las hace la versión anterior de la app
-- (sin p_token; sin p_camarero_id en fn_camarero_listar_sesiones y
-- fn_camarero_toggle_limpieza) y comprueba que:
--   * funcionan como antes (y siguen dando "No autorizado" sin el permiso);
--   * cada llamada queda anotada en camarero_llamadas_sin_token;
--   * con un token inventado, fallan con RM401.
-- Mismos ayudantes y datos de prueba que supabase/tests/pin_camarero.sql.
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

-- Criterio 7: llamadas de la versión anterior de la app (sin token) ------------------
do $$
declare
  r1 uuid := pg_temp.ctx('r1'); r2 uuid := pg_temp.ctx('r2');
  ca uuid := pg_temp.ctx('ca'); cb uuid := pg_temp.ctx('cb'); cc uuid := pg_temp.ctx('cc');
  s1 uuid := pg_temp.ctx('s1'); t2 uuid := pg_temp.ctx('t2'); t3 uuid := pg_temp.ctx('t3');
  v_items text := jsonb_build_array(jsonb_build_object('menu_item_id', pg_temp.ctx('m1'), 'cantidad', 1))::text;
  q record; j json; v_id uuid; f record; n int;
begin
  -- Inicio de sesión: la versión vieja solo lee id, nombre y permisos.
  q := pg_temp.como('anon', format(
    'select row_to_json(x)::text from (select id, nombre, permisos from public.fn_verificar_camarero_pin(p_restaurant_id => %L, p_camarero_id => %L, p_pin => %L)) x',
    r1, ca, '1234'));
  j := case when q.resultado is not null then q.resultado::json end;
  perform pg_temp.anotar('7. versión vieja: fn_verificar_camarero_pin → id, nombre y permisos',
    q.estado = '00000' and (j->>'id')::uuid = ca and j->>'nombre' = 'zz Ana', coalesce(q.mensaje, q.resultado));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_camarero_listar_sesiones(p_restaurant_id => %L)', r1));
  perform pg_temp.anotar('7. versión vieja: fn_camarero_listar_sesiones(p_restaurant_id) → las 2 mesas abiertas',
    q.estado = '00000' and q.resultado = '2', q.estado || ' ' || coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', format(
    'select public.fn_staff_contar_alertas(p_restaurant_id => %L, p_camarero_id => %L)::text', r1, ca));
  perform pg_temp.anotar('7. versión vieja: fn_staff_contar_alertas → limpieza 1, llamadas 1',
    q.estado = '00000' and (q.resultado::json->>'limpieza')::int = 1 and (q.resultado::json->>'llamadas')::int = 1,
    q.estado || ' ' || coalesce(q.mensaje, q.resultado));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_listar_llamadas(p_restaurant_id => %L, p_camarero_id => %L)', r1, ca));
  perform pg_temp.anotar('7. versión vieja: fn_staff_listar_llamadas → 1 llamada',
    q.estado = '00000' and q.resultado = '1', q.estado || ' ' || coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_camarero_abrir_mesa(p_table_id => %L, p_restaurant_id => %L, p_camarero_id => %L, p_comensales => 2)', t2, r1, ca));
  perform pg_temp.anotar('7. versión vieja: fn_camarero_abrir_mesa → mesa abierta',
    q.estado = '00000' and exists (select 1 from public.table_sessions where table_id = t2 and estado = 'abierta' and camarero_id = ca),
    q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_camarero_tomar_mesa(p_table_session_id => %L, p_restaurant_id => %L, p_camarero_id => %L)', s1, r1, ca));
  perform pg_temp.anotar('7. versión vieja: fn_camarero_tomar_mesa → la sesión pasa a A',
    q.estado = '00000' and (select camarero_id from public.table_sessions where id = s1) = ca, q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_camarero_editar_cliente_sesion(p_table_session_id => %L, p_restaurant_id => %L, p_camarero_id => %L, p_telefono => %L, p_nombre => %L)',
    s1, r1, ca, '600000003', 'zz Nuevo'));
  perform pg_temp.anotar('7. versión vieja: fn_camarero_editar_cliente_sesion → guardado',
    q.estado = '00000' and (select cliente_telefono from public.table_sessions where id = s1) = '600000003', q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select public.fn_registrar_pedido(p_table_session_id => %L, p_items => %L::jsonb, p_notas => null, p_camarero_id => %L, p_premios_canjeados => %L::jsonb)::text',
    s1, v_items, ca, '[]'));
  v_id := case when q.estado = '00000' then q.resultado::uuid end;
  perform pg_temp.anotar('7. versión vieja: fn_registrar_pedido con p_camarero_id → pedido con tomado_por = A',
    v_id is not null and (select tomado_por from public.orders where id = v_id) = ca, q.estado || ' ' || coalesce(q.mensaje, 'pedido ' || v_id));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_camarero_listar_pedidos_sesion(p_restaurant_id => %L, p_camarero_id => %L, p_table_session_id => %L)', r1, ca, s1));
  perform pg_temp.anotar('7. versión vieja: fn_camarero_listar_pedidos_sesion → los pedidos',
    q.estado = '00000' and q.resultado::int >= 2, q.estado || ' ' || coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_camarero_toggle_limpieza(p_table_id => %L, p_restaurant_id => %L, p_paso_id => %L)', t3, r1, pg_temp.ctx('p1')));
  perform pg_temp.anotar('7. versión vieja: fn_camarero_toggle_limpieza (sin camarero) → paso guardado',
    q.estado = '00000' and (select limpieza_progreso from public.tables where id = t3) ? pg_temp.ctx('p1'), q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_marcar_llamada_atendida(p_restaurant_id => %L, p_camarero_id => %L, p_llamada_id => %L)', r1, ca, pg_temp.ctx('w1')));
  perform pg_temp.anotar('7. versión vieja: fn_staff_marcar_llamada_atendida → atendida',
    q.estado = '00000' and (select estado from public.waiter_calls where id = pg_temp.ctx('w1')::uuid) = 'atendido', q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_listar_clientes(p_restaurant_id => %L, p_camarero_id => %L)', r1, ca));
  perform pg_temp.anotar('7. versión vieja: fn_staff_listar_clientes → el cliente',
    q.estado = '00000' and q.resultado = '1', q.estado || ' ' || coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_historial_cliente(p_restaurant_id => %L, p_camarero_id => %L, p_cliente_id => %L)', r1, ca, pg_temp.ctx('cl1')));
  perform pg_temp.anotar('7. versión vieja: fn_staff_historial_cliente → sin error',
    q.estado = '00000', q.estado || ' ' || coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_canjear_puntos(p_restaurant_id => %L, p_camarero_id => %L, p_cliente_id => %L, p_cantidad => 10, p_motivo => null)', r1, ca, pg_temp.ctx('cl1')));
  perform pg_temp.anotar('7. versión vieja: fn_staff_canjear_puntos → 90 puntos',
    q.estado = '00000' and (select puntos from public.clientes where id = pg_temp.ctx('cl1')::uuid) = 90, q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_listar_reservas(p_restaurant_id => %L, p_camarero_id => %L)', r1, ca));
  perform pg_temp.anotar('7. versión vieja: fn_staff_listar_reservas → la reserva',
    q.estado = '00000' and q.resultado = '1', q.estado || ' ' || coalesce(q.mensaje, q.resultado || ' filas'));

  q := pg_temp.como('anon', format(
    'select public.fn_staff_crear_reserva_manual(p_restaurant_id => %L, p_camarero_id => %L, p_nombre => %L, p_telefono => %L, p_fecha => current_date + 1, p_hora => %L, p_personas => 2, p_zona => %L, p_notas => null)::text',
    r1, ca, 'zz Reserva vieja', '600000005', '21:30', 'sin preferencia'));
  perform pg_temp.anotar('7. versión vieja: fn_staff_crear_reserva_manual → reserva creada',
    q.estado = '00000' and exists (select 1 from public.reservations where id = q.resultado::uuid), q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_cambiar_estado_reserva(p_restaurant_id => %L, p_camarero_id => %L, p_reserva_id => %L, p_nuevo_estado => %L)', r1, ca, pg_temp.ctx('rs1'), 'cancelada'));
  perform pg_temp.anotar('7. versión vieja: fn_staff_cambiar_estado_reserva → cancelada',
    q.estado = '00000' and (select estado from public.reservations where id = pg_temp.ctx('rs1')::uuid) = 'cancelada', q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  q := pg_temp.como('anon', format(
    'select public.fn_staff_listar_pedidos_cocina(p_restaurant_id => %L, p_camarero_id => %L)::text', r1, ca));
  perform pg_temp.anotar('7. versión vieja: fn_staff_listar_pedidos_cocina → incluye el pedido de prueba',
    q.estado = '00000' and q.resultado::jsonb @> jsonb_build_array(jsonb_build_object('id', pg_temp.ctx('o1'))), q.estado || ' ' || coalesce(q.mensaje, left(q.resultado, 60)));

  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_cambiar_estado_pedido(p_restaurant_id => %L, p_camarero_id => %L, p_order_id => %L, p_nuevo_estado => %L)', r1, ca, pg_temp.ctx('o1'), 'preparando'));
  perform pg_temp.anotar('7. versión vieja: fn_staff_cambiar_estado_pedido → preparando',
    q.estado = '00000' and (select estado from public.orders where id = pg_temp.ctx('o1')::uuid) = 'preparando', q.estado || ' ' || coalesce(q.mensaje, 'ok'));

  -- Sin el permiso sigue dando "No autorizado", como antes.
  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_listar_clientes(p_restaurant_id => %L, p_camarero_id => %L)', r1, cb), true);
  perform pg_temp.anotar('7. versión vieja: B (solo pedidos) en fn_staff_listar_clientes → No autorizado',
    q.estado = 'P0001' and q.mensaje = 'No autorizado', q.estado || ' ' || coalesce(q.mensaje, 'sin error'));
  q := pg_temp.como('anon', format(
    'select count(*)::text from public.fn_staff_listar_clientes(p_restaurant_id => %L, p_camarero_id => %L)', r1, cc), true);
  perform pg_temp.anotar('7. versión vieja: camarero de otro restaurante en fn_staff_listar_clientes → No autorizado',
    q.estado = 'P0001' and q.mensaje = 'No autorizado', q.estado || ' ' || coalesce(q.mensaje, 'sin error'));

  -- Cada llamada sin token queda anotada (restaurante, función, nº, última).
  for f in select * from _protegidas order by orden loop
    begin
      select llamadas into n from public.camarero_llamadas_sin_token
      where restaurant_id = r1 and funcion = f.funcion and ultima_llamada >= now() - interval '1 minute';
      perform pg_temp.anotar('7. camarero_llamadas_sin_token anota ' || f.funcion,
        coalesce(n, 0) >= 1, coalesce(n, 0) || ' llamadas');
    exception when others then
      perform pg_temp.anotar('7. camarero_llamadas_sin_token anota ' || f.funcion, false, sqlerrm);
    end;
  end loop;

  -- Con un token inventado, RM401.
  for f in select * from _protegidas order by orden loop
    q := pg_temp.como('anon', pg_temp.sql_llamada(f.funcion, r1, ca, encode(extensions.gen_random_bytes(32), 'hex')), true);
    perform pg_temp.anotar('7. ' || f.funcion || ' con token inventado → RM401 y sin cambios',
      q.estado = 'RM401' and not q.cambio, q.estado || ' ' || coalesce(q.mensaje, 'resultado ' || coalesce(q.resultado, 'null')));
  end loop;
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL pin_camarero_fase1', count(*) filter (where not ok) = 0,
       count(*) filter (where not ok) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
