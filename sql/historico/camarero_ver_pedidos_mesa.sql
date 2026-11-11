-- ============================================================================
-- Hasta ahora, Camarero.jsx no tenía forma de ver qué se pidió ya en una
-- mesa durante la visita en curso — ni lo que pidió el propio camarero en
-- rondas anteriores, ni lo que el cliente pidió por su cuenta desde el QR
-- (Mesa.jsx sí lo muestra, con "Mis pedidos"). Esta función le da al
-- camarero esa misma vista.
--
-- Mismo resultado que get_session_orders (la que usa Mesa.jsx), pero
-- autorizada por PIN de camarero + permiso "pedidos" en vez de por el
-- qr_token de la mesa — un camarero no tiene ese token a mano.
-- ============================================================================

create or replace function fn_camarero_listar_pedidos_sesion(
  p_restaurant_id uuid,
  p_camarero_id uuid,
  p_table_session_id uuid
)
returns table(
  order_id uuid, order_created_at timestamp with time zone, order_estado text,
  order_total numeric, order_notas text,
  item_id uuid, item_nombre text, item_precio numeric, item_cantidad integer,
  item_notas text, item_modificadores text, item_modificadores_extra numeric
)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  return query
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
    left join order_items oi on oi.order_id = o.id
    where o.table_session_id = p_table_session_id
      and ts.restaurant_id = p_restaurant_id
      and o.estado != 'cancelado'
    order by o.created_at asc, oi.id asc;
end;
$$;

grant execute on function fn_camarero_listar_pedidos_sesion(uuid, uuid, uuid) to anon, authenticated;

notify pgrst, 'reload schema';
