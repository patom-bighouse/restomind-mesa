-- =============================================================================
-- Arreglo: la limpieza marcada desde el móvil del camarero no se guardaba.
--
-- fn_camarero_toggle_limpieza leía tables.limpieza_progreso (jsonb, por
-- defecto '[]') en una variable uuid[]; cada llamada fallaba con
-- `malformed array literal: "[]"` (400) y no se guardaba ningún paso.
-- Fallaba igual en Test y en Producción. Ver docs/BACKLOG.md.
--
-- Cambios:
--   * Trabaja con jsonb (array de uuid en texto), como AdminMesas.jsx.
--   * `for update` al leer la mesa: dos pasos marcados a la vez no se pisan.
--   * Firma y tipo de retorno iguales (create or replace conserva la ACL);
--     aun así se reescriben los grants, igual que en la migración de
--     permisos mínimos (grupo A: anon, authenticated y service_role).
--
-- No toca datos.
-- =============================================================================

create or replace function public.fn_camarero_toggle_limpieza(
  p_table_id uuid,
  p_restaurant_id uuid,
  p_paso_id uuid
)
returns table(necesita_limpieza boolean, limpieza_progreso uuid[])
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_actual jsonb;
  v_nuevo jsonb;
  v_completo boolean;
begin
  select t.limpieza_progreso into v_actual
  from tables t
  where t.id = p_table_id and t.restaurant_id = p_restaurant_id
  for update;

  if not found then
    raise exception 'Mesa no encontrada.';
  end if;

  if v_actual is null or jsonb_typeof(v_actual) <> 'array' then
    v_actual := '[]'::jsonb;
  end if;

  if v_actual ? p_paso_id::text then
    v_nuevo := v_actual - p_paso_id::text;
  else
    v_nuevo := v_actual || jsonb_build_array(p_paso_id::text);
  end if;

  select not exists (
    select 1 from limpieza_pasos lp
    where lp.restaurant_id = p_restaurant_id
      and lp.activo = true
      and not (v_nuevo ? lp.id::text)
  ) into v_completo;

  update tables t
  set limpieza_progreso = v_nuevo,
      necesita_limpieza = not v_completo
  where t.id = p_table_id and t.restaurant_id = p_restaurant_id;

  return query
  select (not v_completo),
         array(select e::uuid from jsonb_array_elements_text(v_nuevo) as e);
end;
$function$;

revoke all on function public.fn_camarero_toggle_limpieza(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fn_camarero_toggle_limpieza(uuid, uuid, uuid) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
