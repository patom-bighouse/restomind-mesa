-- ============================================================================
-- Rentabilidad por producto: añade el precio de coste actual (menu_items)
-- y su snapshot histórico por cada línea de pedido (order_items), igual
-- que ya existe precio_snapshot para el precio de venta.
-- ============================================================================

-- 1) Precio de coste actual del producto (editable en AdminCarta)
alter table menu_items
  add column if not exists precio_costo numeric;

-- 2) Snapshot del coste en el momento exacto de cada venta
alter table order_items
  add column if not exists costo_snapshot numeric;

-- 3) Actualizar fn_registrar_pedido para que capture también el coste al
--    crear cada línea de pedido (flujo de mesa / QR)
CREATE OR REPLACE FUNCTION public.fn_registrar_pedido(p_table_session_id uuid, p_items jsonb, p_notas text DEFAULT NULL::text)
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
begin
  -- Evita que dos envíos casi simultáneos de la misma mesa (QR + WhatsApp)
  -- creen dos pedidos nuevos en paralelo.
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

  -- Solo en modo "agrupado_mesa" se busca un pedido pendiente para sumarse.
  -- En "orden_llegada", v_order_id queda NULL y siempre se crea uno nuevo.
  if v_modo_cocina = 'agrupado_mesa' then
    select id into v_order_id
    from orders
    where table_session_id = p_table_session_id
      and estado = 'pendiente'
      and created_at > now() - (v_minutos_limite || ' minutes')::interval
    order by created_at desc
    limit 1;
    -- Si Cocina revierte un pedido de "preparando" a "pendiente", esta misma
    -- condición hace que vuelva a admitir ítems nuevos automáticamente
    -- (siempre que siga dentro del tiempo límite) sin lógica adicional.
  end if;

  if v_order_id is null then
    insert into orders (restaurant_id, table_id, table_session_id, tipo, estado, notas)
    values (v_restaurant_id, v_table_id, p_table_session_id, 'mesa', 'pendiente', p_notas)
    returning id into v_order_id;
  elsif p_notas is not null and length(trim(p_notas)) > 0 then
    -- El pedido ya existía (se agrupó): si trae una nota general nueva y
    -- distinta a la que ya tenía, se agrega al final en vez de perderla.
    select notas into v_notas_actual from orders where id = v_order_id;
    if v_notas_actual is null or length(trim(v_notas_actual)) = 0 then
      update orders set notas = p_notas where id = v_order_id;
    elsif position(p_notas in v_notas_actual) = 0 then
      update orders set notas = v_notas_actual || ' · ' || p_notas where id = v_order_id;
    end if;
  end if;

  insert into order_items (
    order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, agregado_at, restaurant_id
  )
  select
    v_order_id,
    mi.id,
    mi.nombre,
    mi.precio,
    mi.precio_costo,
    (i->>'cantidad')::int,
    i->>'notas',
    now(),
    v_restaurant_id
  from jsonb_array_elements(p_items) as i
  join menu_items mi on mi.id = (i->>'menu_item_id')::uuid;

  -- No recalculamos orders.total acá: el trigger trg_recalc_order_total
  -- (AFTER INSERT en order_items) ya lo hace automáticamente. Duplicarlo
  -- en la función sería la misma regla escrita en dos lugares.

  return v_order_id;
end;
$function$
