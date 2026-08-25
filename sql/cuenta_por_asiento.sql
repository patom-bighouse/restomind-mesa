-- ============================================================================
-- Cuenta dividida por asiento: cada línea de pedido queda etiquetada
-- con el número de comensal que lo pidió (1, 2, 3... según
-- table_sessions.comensales), o null para "compartido" (algo pedido
-- para toda la mesa, como una picada). No cambia la mecánica de
-- cobro — table_session_payments sigue aceptando montos libres — esto
-- solo le da a CuentaMesa.jsx el dato para mostrar cuánto le
-- corresponde a cada uno, en vez de que el grupo lo divida de memoria.
-- ============================================================================

alter table order_items
  add column if not exists comensal integer;

-- table_sessions tiene un permiso de SELECT por columna para el rol
-- anónimo (ver sql/fix_grants_test.sql) que nunca incluyó
-- "comensales" — Mesa.jsx lo necesita para mostrar los chips "¿Para
-- quién?". Es aditivo: no le saca acceso a ninguna columna que ya
-- tuviera permitida.
grant select (comensales) on table_sessions to anon;

-- Misma función de siempre (ver sql/modificadores_plato.sql), con un
-- único agregado: lee "comensal" de cada ítem del payload y lo guarda
-- en la columna nueva. El resto de la lógica (agrupado por mesa,
-- modificadores, recálculo de total) queda idéntico.
--
-- Formato esperado de p_items (cada elemento):
-- {
--   "menu_item_id": "uuid",
--   "cantidad": 2,
--   "notas": "sin cebolla" | null,
--   "comensal": 1 | null,
--   "modificadores": [
--     { "grupo_id": "uuid", "opcion_id": "uuid" }
--   ]
-- }
CREATE OR REPLACE FUNCTION public.fn_registrar_pedido(
  p_table_session_id uuid,
  p_items jsonb,
  p_notas text DEFAULT NULL::text,
  p_camarero_id uuid DEFAULT NULL::uuid
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_restaurant_id  uuid;
  v_table_id       uuid;
  v_modo_cocina    text;
  v_minutos_limite int;
  v_order_id       uuid;
  v_notas_actual   text;
  v_item           jsonb;
  v_mod            jsonb;
  v_menu_item      record;
  v_order_item_id  uuid;
  v_extra          numeric;
  v_opcion_nombre  text;
  v_grupo_nombre   text;
begin
  perform pg_advisory_xact_lock(hashtext(p_table_session_id::text));

  select ts.restaurant_id, ts.table_id, r.modo_cocina, r.minutos_limite_agrupado
    into v_restaurant_id, v_table_id, v_modo_cocina, v_minutos_limite
  from table_sessions ts
  join restaurants r on r.id = ts.restaurant_id
  where ts.id = p_table_session_id
    and ts.estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa % no existe o ya está cerrada', p_table_session_id;
  end if;

  if v_modo_cocina = 'agrupado_mesa' then
    select id into v_order_id
    from orders
    where table_session_id = p_table_session_id
      and estado = 'pendiente'
      and created_at > now() - (v_minutos_limite || ' minutes')::interval
    order by created_at desc
    limit 1;
  end if;

  if v_order_id is null then
    insert into orders (restaurant_id, table_id, table_session_id, tipo, estado, notas, tomado_por)
    values (v_restaurant_id, v_table_id, p_table_session_id, 'mesa', 'pendiente', p_notas, p_camarero_id)
    returning id into v_order_id;
  elsif p_notas is not null and length(trim(p_notas)) > 0 then
    select notas into v_notas_actual from orders where id = v_order_id;
    if v_notas_actual is null or length(trim(v_notas_actual)) = 0 then
      update orders set notas = p_notas where id = v_order_id;
    elsif position(p_notas in v_notas_actual) = 0 then
      update orders set notas = v_notas_actual || ' · ' || p_notas where id = v_order_id;
    end if;
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, nombre, precio, precio_costo into v_menu_item
    from menu_items
    where id = (v_item->>'menu_item_id')::uuid;

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, agregado_at, restaurant_id
    )
    values (
      v_order_id,
      v_menu_item.id,
      v_menu_item.nombre,
      v_menu_item.precio,
      v_menu_item.precio_costo,
      (v_item->>'cantidad')::int,
      v_item->>'notas',
      nullif(v_item->>'comensal', '')::int,
      now(),
      v_restaurant_id
    )
    returning id into v_order_item_id;

    if v_item ? 'modificadores' then
      for v_mod in select * from jsonb_array_elements(v_item->'modificadores')
      loop
        select nombre into v_grupo_nombre from modificador_grupos where id = (v_mod->>'grupo_id')::uuid;
        select nombre into v_opcion_nombre from modificador_opciones where id = (v_mod->>'opcion_id')::uuid;

        select coalesce(precio_extra, 0) into v_extra
        from menu_item_modificador_precios
        where menu_item_id = v_menu_item.id
          and opcion_id = (v_mod->>'opcion_id')::uuid;

        insert into order_item_modificadores (
          order_item_id, grupo_id, opcion_id, grupo_nombre, opcion_nombre, precio_extra
        )
        values (
          v_order_item_id,
          (v_mod->>'grupo_id')::uuid,
          (v_mod->>'opcion_id')::uuid,
          coalesce(v_grupo_nombre, ''),
          coalesce(v_opcion_nombre, ''),
          coalesce(v_extra, 0)
        );
      end loop;
    end if;
  end loop;

  update orders o
  set total = coalesce((
    select sum(oi.precio_snapshot * oi.cantidad) + coalesce((
      select sum(oim.precio_extra) from order_item_modificadores oim
      join order_items oi2 on oi2.id = oim.order_item_id
      where oi2.order_id = o.id
    ), 0)
    from order_items oi where oi.order_id = o.id
  ), 0)
  where o.id = v_order_id;

  return v_order_id;
end;
$function$;
