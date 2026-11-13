-- =============================================================================
-- fn_pedido_whatsapp_crear (migración 20261113114751_pedido_whatsapp_crear)
-- Criterio 3 de docs/specs/2026-11-13-agente-whatsapp-revision.md
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/pedido_whatsapp.sql
--
-- Crea en la transacción un dueño, dos restaurantes, módulo takeaway_delivery,
-- platos (uno no disponible y uno de otro restaurante) y un menú de WhatsApp
-- que cambia el precio de un plato. Llama a la función como service_role.
--
-- Comprueba:
--   1. Pedido correcto: orders (takeaway, hora_recogida, clave) + order_items,
--      precio_snapshot = precio de fn_carta_takeaway aunque se mande otro,
--      total = suma de las líneas.
--   2. La misma clave dos veces: mismo id, ya_existia, un solo pedido.
--   3. Rechazos sin crear nada: plato inexistente, no disponible, de otro
--      restaurante; cantidad 0 y 21; 61 unidades; textos largos; sin módulo;
--      restaurante inactivo.
--   4. anon y authenticated no pueden ejecutarla.
--
-- Resultado: una fila por comprobación (prueba, ok, detalle) + TOTAL.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

-- Llama a la función como service_role y devuelve el código de error ('' si fue bien).
create function pg_temp.pedir(p_rest uuid, p_clave text, p_items jsonb,
                              p_nombre text default 'Ana', p_notas text default null,
                              p_tel text default '600000001') returns text
language plpgsql as $$
begin
  set local role service_role;
  perform public.fn_pedido_whatsapp_crear(p_rest, p_clave, p_tel, p_nombre, now() + interval '1 hour', p_notas, p_items);
  reset role;
  return '';
exception when others then
  reset role;
  return sqlstate || ': ' || sqlerrm;
end $$;

do $$
declare
  v_duenio uuid := gen_random_uuid();
  v_rest uuid;
  v_otro uuid;
  v_inactivo uuid;
  v_sin_modulo uuid;
  v_a uuid; v_b uuid; v_no_disp uuid; v_ajeno uuid;
  v_menu uuid;
  v_res json;
  v_res2 json;
  v_err text;
  v_n int;
  v_total numeric;
  v_antes int;
begin
  insert into auth.users (id, email, aud, role, instance_id)
  values (v_duenio, 'zz_pedido_wa@example.invalid', 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000');

  insert into restaurants (nombre, slug, user_id) values ('ZZ Pedido WA', 'zz-pedido-wa-' || substr(v_duenio::text, 1, 8), v_duenio) returning id into v_rest;
  insert into restaurants (nombre, slug) values ('ZZ Otro', 'zz-otro-wa-' || substr(v_duenio::text, 1, 8)) returning id into v_otro;
  insert into restaurants (nombre, slug) values ('ZZ Sin módulo', 'zz-sinmod-wa-' || substr(v_duenio::text, 1, 8)) returning id into v_sin_modulo;
  insert into restaurants (nombre, slug) values ('ZZ Inactivo', 'zz-inact-wa-' || substr(v_duenio::text, 1, 8)) returning id into v_inactivo;
  insert into restaurant_modulos (restaurant_id, modulo_key, activo)
  values (v_rest, 'takeaway_delivery', true), (v_otro, 'takeaway_delivery', true), (v_inactivo, 'takeaway_delivery', true);

  insert into menu_items (restaurant_id, nombre, precio, disponible) values (v_rest, 'Tortilla', 10.50, true) returning id into v_a;
  insert into menu_items (restaurant_id, nombre, precio, disponible) values (v_rest, 'Croquetas', 7.00, true) returning id into v_b;
  insert into menu_items (restaurant_id, nombre, precio, disponible) values (v_rest, 'Agotado', 5.00, false) returning id into v_no_disp;
  insert into menu_items (restaurant_id, nombre, precio, disponible) values (v_otro, 'De otro', 3.00, true) returning id into v_ajeno;
  insert into menu_items (restaurant_id, nombre, precio, disponible) values (v_inactivo, 'Plato', 3.00, true);

  -- Menú de WhatsApp siempre activo: las croquetas cuestan 6,00 en él.
  insert into menus (restaurant_id, nombre, aplica_whatsapp) values (v_rest, 'WhatsApp', true) returning id into v_menu;
  insert into menu_item_precios_menu (menu_id, menu_item_id, precio) values (v_menu, v_b, 6.00);

  update restaurants set activo = false where id = v_inactivo;

  -- 1. Pedido correcto ------------------------------------------------------
  set local role service_role;
  v_res := public.fn_pedido_whatsapp_crear(v_rest, 'clave-1', '+34 600 000 001', 'Ana', now() + interval '1 hour', null,
             jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 2, 'precio', 0.01, 'nombre', 'falso'),
                               jsonb_build_object('menu_item_id', v_b, 'cantidad', 1, 'notas', 'sin salsa')));
  reset role;

  select count(*), max(total) into v_n, v_total from orders where restaurant_id = v_rest;
  insert into _resultado (prueba, ok, detalle) values
    ('pedido correcto: 1 pedido takeaway con hora_recogida y clave',
     v_n = 1 and exists (select 1 from orders where id = (v_res ->> 'id')::uuid and tipo = 'takeaway' and estado = 'pendiente'
                         and hora_recogida is not null and clave_whatsapp = 'clave-1' and cliente_telefono = '600000001'),
     v_n || ' pedidos; ' || v_res::text);

  insert into _resultado (prueba, ok, detalle)
  select 'pedido correcto: 2 líneas con precio de fn_carta_takeaway (10,50 y 6,00), no el enviado',
         count(*) = 2
           and bool_and((menu_item_id = v_a and precio_snapshot = 10.50 and cantidad = 2 and nombre_snapshot = 'Tortilla')
                     or (menu_item_id = v_b and precio_snapshot = 6.00 and cantidad = 1 and notas = 'sin salsa')),
         string_agg(nombre_snapshot || ' x' || cantidad || ' a ' || precio_snapshot, ', ')
  from order_items where order_id = (v_res ->> 'id')::uuid;

  insert into _resultado (prueba, ok, detalle) values
    ('pedido correcto: total = suma de líneas (27,00) y lo devuelve', v_total = 27.00 and (v_res ->> 'total')::numeric = 27.00,
     'orders.total=' || v_total || ', devuelto=' || (v_res ->> 'total') || ', ya_existia=' || (v_res ->> 'ya_existia'));

  -- 2. Idempotencia ---------------------------------------------------------
  set local role service_role;
  v_res2 := public.fn_pedido_whatsapp_crear(v_rest, 'clave-1', '600000001', 'Ana', now() + interval '1 hour', null,
              jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 5)));
  reset role;
  select count(*) into v_n from orders where restaurant_id = v_rest;
  insert into _resultado (prueba, ok, detalle) values
    ('misma clave dos veces: mismo id, ya_existia y un solo pedido con sus 2 líneas',
     (v_res2 ->> 'id') = (v_res ->> 'id') and (v_res2 ->> 'ya_existia')::boolean and v_n = 1
       and (select count(*) from order_items where order_id = (v_res ->> 'id')::uuid) = 2
       and json_array_length(v_res2 -> 'lineas') = 2,
     v_n || ' pedidos; ' || v_res2::text);

  -- 3. Rechazos sin crear nada ----------------------------------------------
  select count(*) into v_antes from orders where restaurant_id in (v_rest, v_otro, v_sin_modulo, v_inactivo);

  v_err := pg_temp.pedir(v_rest, 'r1', jsonb_build_array(jsonb_build_object('menu_item_id', gen_random_uuid(), 'cantidad', 1)));
  insert into _resultado values (default, 'rechaza plato inexistente (RMP02)', v_err like 'RMP02%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r2', jsonb_build_array(jsonb_build_object('menu_item_id', v_no_disp, 'cantidad', 1)));
  insert into _resultado values (default, 'rechaza plato no disponible (RMP02)', v_err like 'RMP02%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r3', jsonb_build_array(jsonb_build_object('menu_item_id', v_ajeno, 'cantidad', 1)));
  insert into _resultado values (default, 'rechaza plato de otro restaurante (RMP02)', v_err like 'RMP02%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r3b', jsonb_build_array(jsonb_build_object('nombre', 'Tortilla', 'cantidad', 1)));
  insert into _resultado values (default, 'rechaza línea sin menu_item_id (RMP02)', v_err like 'RMP02%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r4', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 0)));
  insert into _resultado values (default, 'rechaza cantidad 0 (RMP03)', v_err like 'RMP03%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r5', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 21)));
  insert into _resultado values (default, 'rechaza 21 unidades de un plato (RMP01, pedido grande)', v_err like 'RMP01%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r5b', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 15),
                                                         jsonb_build_object('menu_item_id', v_a, 'cantidad', 10)));
  insert into _resultado values (default, 'rechaza 25 del mismo plato en dos líneas (RMP01)', v_err like 'RMP01%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r5c', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 20)));
  insert into _resultado values (default, 'acepta 20 unidades de un plato (límite)', v_err = '', coalesce(nullif(v_err, ''), 'sin error'));
  delete from order_items where order_id in (select id from orders where restaurant_id = v_rest and clave_whatsapp = 'r5c');
  delete from orders where restaurant_id = v_rest and clave_whatsapp = 'r5c';

  -- 61 unidades sin pasar de 20 por plato: tortilla, croquetas y pan 20 cada uno + 1 agua.
  insert into menu_items (restaurant_id, nombre, precio, disponible) values (v_rest, 'Pan', 1.00, true);
  insert into menu_items (restaurant_id, nombre, precio, disponible) values (v_rest, 'Agua', 1.00, true);
  v_err := pg_temp.pedir(v_rest, 'r6', (
    select jsonb_agg(jsonb_build_object('menu_item_id', id, 'cantidad', case nombre when 'Agua' then 1 else 20 end))
    from menu_items where restaurant_id = v_rest and disponible));
  insert into _resultado values (default, 'rechaza 61 unidades en total (RMP01)', v_err like 'RMP01%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r7', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 1)), repeat('x', 101));
  insert into _resultado values (default, 'rechaza nombre de 101 caracteres (RMP03)', v_err like 'RMP03%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r8', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 1)), 'Ana', repeat('x', 501));
  insert into _resultado values (default, 'rechaza notas de 501 caracteres (RMP03)', v_err like 'RMP03%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r9', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 1, 'notas', repeat('x', 201))));
  insert into _resultado values (default, 'rechaza notas de plato de 201 caracteres (RMP03)', v_err like 'RMP03%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r10', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 1)), 'Ana', null, repeat('6', 31));
  insert into _resultado values (default, 'rechaza teléfono de 31 caracteres (RMP03)', v_err like 'RMP03%', v_err);

  v_err := pg_temp.pedir(v_rest, 'r11', (select jsonb_agg(jsonb_build_object('menu_item_id', v_a, 'cantidad', 1)) from generate_series(1, 31)));
  insert into _resultado values (default, 'rechaza más de 30 líneas (RMP01)', v_err like 'RMP01%', v_err);

  v_err := pg_temp.pedir(v_sin_modulo, 'r12', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 1)));
  insert into _resultado values (default, 'rechaza restaurante sin takeaway_delivery (RMP04)', v_err like 'RMP04%', v_err);

  v_err := pg_temp.pedir(v_inactivo, 'r13', jsonb_build_array(jsonb_build_object('menu_item_id', v_a, 'cantidad', 1)));
  insert into _resultado values (default, 'rechaza restaurante inactivo (RMP04)', v_err like 'RMP04%', v_err);

  select count(*) into v_n from orders where restaurant_id in (v_rest, v_otro, v_sin_modulo, v_inactivo);
  insert into _resultado values (default, 'los rechazos no crean pedidos ni líneas', v_n = v_antes
         and not exists (select 1 from order_items oi join orders o on o.id = oi.order_id
                         where o.restaurant_id = v_rest and o.clave_whatsapp <> 'clave-1'),
         'pedidos antes=' || v_antes || ', después=' || v_n);

  -- 4. Permisos -------------------------------------------------------------
  begin
    set local role anon;
    perform public.fn_pedido_whatsapp_crear(v_rest, 'x', '600', 'x', now(), null, '[]'::jsonb);
    reset role;
    insert into _resultado values (default, 'anon no puede ejecutarla', false, 'no dio error');
  exception when insufficient_privilege then
    reset role;
    insert into _resultado values (default, 'anon no puede ejecutarla', true, sqlerrm);
  end;
  begin
    set local role authenticated;
    perform public.fn_pedido_whatsapp_crear(v_rest, 'x', '600', 'x', now(), null, '[]'::jsonb);
    reset role;
    insert into _resultado values (default, 'authenticated no puede ejecutarla', false, 'no dio error');
  exception when insufficient_privilege then
    reset role;
    insert into _resultado values (default, 'authenticated no puede ejecutarla', true, sqlerrm);
  end;
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'has_function_privilege: solo service_role',
       not has_function_privilege('anon', 'public.fn_pedido_whatsapp_crear(uuid,text,text,text,timestamptz,text,jsonb)', 'execute')
       and not has_function_privilege('authenticated', 'public.fn_pedido_whatsapp_crear(uuid,text,text,text,timestamptz,text,jsonb)', 'execute')
       and has_function_privilege('service_role', 'public.fn_pedido_whatsapp_crear(uuid,text,text,text,timestamptz,text,jsonb)', 'execute'),
       'anon/authenticated sin EXECUTE, service_role con EXECUTE';

insert into _resultado (prueba, ok, detalle)
select 'TOTAL pedido_whatsapp', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
