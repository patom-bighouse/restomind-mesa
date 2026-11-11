-- ============================================================================
-- fn_staff_listar_llamadas devolvía solo el número de mesa, no la zona.
-- Con dos mesas con el mismo número en zonas distintas (ej. "Mesa 3" en
-- terraza y "Mesa 3" en privado), el camarero no podía saber cuál de las
-- dos estaba llamando. Cambia la forma de salida (se agrega mesa_zona),
-- así que hay que borrarla antes de recrearla.
-- ============================================================================

drop function if exists fn_staff_listar_llamadas(uuid, uuid);

create or replace function fn_staff_listar_llamadas(p_restaurant_id uuid, p_camarero_id uuid)
returns table(id uuid, table_id uuid, mesa_numero integer, mesa_zona text, created_at timestamp with time zone)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  return query
    select w.id, w.table_id, t.numero, t.zona, w.created_at
    from waiter_calls w
    join tables t on t.id = w.table_id
    where w.restaurant_id = p_restaurant_id and w.estado = 'pendiente'
    order by w.created_at;
end;
$$;

grant execute on function fn_staff_listar_llamadas(uuid, uuid) to anon, authenticated;

notify pgrst, 'reload schema';
