-- ============================================================================
-- Actualiza get_session_orders para que "Mis pedidos" (Mesa.jsx) también
-- muestre qué modificadores eligió el cliente en cada línea, no solo el
-- nombre del plato.
--
-- Cambia la firma de salida (se agrega item_modificadores), así que hay
-- que borrar la función antes de recrearla — CREATE OR REPLACE no
-- permite cambiar las columnas de retorno de una función existente.
-- ============================================================================

drop function if exists get_session_orders(uuid, text);

CREATE OR REPLACE FUNCTION public.get_session_orders(p_session_id uuid, p_qr_token text)
 RETURNS TABLE(order_id uuid, order_created_at timestamp with time zone, order_estado text, order_total numeric, order_notas text, item_id uuid, item_nombre text, item_precio numeric, item_cantidad integer, item_notas text, item_modificadores text, item_modificadores_extra numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    o.id, o.created_at, o.estado, o.total, o.notas,
    oi.id, oi.nombre_snapshot, oi.precio_snapshot, oi.cantidad, oi.notas,
    (
      select string_agg(oim.opcion_nombre, ', ' order by oim.grupo_nombre, oim.opcion_nombre)
      from order_item_modificadores oim
      where oim.order_item_id = oi.id
    ) as item_modificadores,
    (
      select coalesce(sum(oim.precio_extra), 0)
      from order_item_modificadores oim
      where oim.order_item_id = oi.id
    ) as item_modificadores_extra
  from orders o
  join table_sessions ts on ts.id = o.table_session_id
  join tables t on t.id = ts.table_id
  left join order_items oi on oi.order_id = o.id
  where o.table_session_id = p_session_id
    and t.qr_token = p_qr_token
    and o.estado != 'cancelado'
  order by o.created_at asc, oi.id asc;
$function$
