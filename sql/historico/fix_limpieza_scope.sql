-- ============================================================================
-- Punto 8: la política de UPDATE del checklist de limpieza dejaba
-- marcar/desmarcar el progreso de limpieza de CUALQUIER mesa de
-- CUALQUIER restaurante ("using(true) with check(true)"), acotado
-- solo a nivel de columna (necesita_limpieza, limpieza_progreso) pero
-- sin ningún filtro por restaurante.
--
-- Se reemplaza por una función que exige conocer el restaurant_id de
-- la mesa (mismo modelo de confianza que ya usa el resto del modo
-- camarero) y recalcula el progreso del lado del servidor.
-- ============================================================================

create or replace function fn_camarero_toggle_limpieza(p_table_id uuid, p_restaurant_id uuid, p_paso_id uuid)
returns table(necesita_limpieza boolean, limpieza_progreso uuid[])
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_actual uuid[];
  v_nuevo uuid[];
  v_completo boolean;
begin
  select t.limpieza_progreso into v_actual
  from tables t where t.id = p_table_id and t.restaurant_id = p_restaurant_id;

  if not found then
    raise exception 'Mesa no encontrada.';
  end if;

  v_actual := coalesce(v_actual, '{}');
  if p_paso_id = any(v_actual) then
    v_nuevo := array_remove(v_actual, p_paso_id);
  else
    v_nuevo := v_actual || p_paso_id;
  end if;

  select not exists (
    select 1 from limpieza_pasos lp
    where lp.restaurant_id = p_restaurant_id and lp.activo = true and not (lp.id = any(v_nuevo))
  ) into v_completo;

  update tables set limpieza_progreso = v_nuevo, necesita_limpieza = not v_completo
  where id = p_table_id and restaurant_id = p_restaurant_id;

  return query select (not v_completo), v_nuevo;
end;
$$;

grant execute on function fn_camarero_toggle_limpieza(uuid, uuid, uuid) to anon, authenticated;

drop policy if exists anon_update_limpieza_tables on tables;
revoke update (necesita_limpieza, limpieza_progreso) on tables from anon;

notify pgrst, 'reload schema';
