-- ============================================================================
-- Precio de contrato de cada restaurante.
--
-- Hasta ahora la cuota de un restaurante sin descuento era el precio actual
-- de su plan (planes.precio): cambiar el precio de un plan cambiaba la cuota
-- de todos los clientes de ese plan. Ahora cada restaurante guarda su propio
-- precio (restaurants.precio_contrato):
--
--   - Se fija al asignarle un plan (fn_asignar_plan) con la tarifa de ese
--     momento. Reasignar el mismo plan no lo toca.
--   - Cambiar el precio de un plan solo afecta a los clientes nuevos. Los
--     existentes conservan el suyo; las subidas se pactan con cada uno y se
--     aplican con fn_actualizar_precio_contrato.
--   - El descuento temporal (precio_override) sigue mandando mientras esté
--     en vigor.
--
-- Al ejecutarlo, cada restaurante con plan recibe el precio actual de su
-- plan, así que la cuota de nadie cambia ese día.
--
-- Re-ejecutable. Necesita crm_vendedores.sql y permanencia.sql.
-- Ejecutar en staging y después en producción.
-- ============================================================================

alter table restaurants add column if not exists precio_contrato numeric(10,2);

update restaurants r
set precio_contrato = pl.precio
from planes pl
where pl.key = r.plan
  and r.precio_contrato is null
  and pl.precio is not null;

alter table planes drop constraint if exists planes_precio_check;
alter table planes add constraint planes_precio_check check (precio is null or precio >= 0);

-- ---------------------------------------------------------------------------
-- Cuota: descuento en vigor, si no el precio de contrato, si no la tarifa
-- ---------------------------------------------------------------------------

create or replace function fn_crm_cuota_restaurante(p_restaurant_id uuid, p_fecha date default current_date)
returns numeric
language sql
stable
security definer
set search_path to 'public'
as $$
  select case
    when r.precio_override is not null
         and (r.precio_override_hasta is null or r.precio_override_hasta >= p_fecha)
      then r.precio_override
    else coalesce(r.precio_contrato, pl.precio, 0)
  end
  from restaurants r
  left join planes pl on pl.key = r.plan
  where r.id = p_restaurant_id
$$;

revoke execute on function fn_crm_cuota_restaurante(uuid, date) from public, anon;
grant execute on function fn_crm_cuota_restaurante(uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Asignar plan: fija el precio de contrato si cambia de plan
-- ---------------------------------------------------------------------------

create or replace function fn_asignar_plan(p_restaurant_id uuid, p_plan_key text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_orden_destino integer;
  v_precio numeric;
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;

  select orden, precio into v_orden_destino, v_precio from planes where key = p_plan_key;
  if v_orden_destino is null then
    raise exception 'Plan no válido.';
  end if;

  -- Cambio de plan (o primer plan): precio de contrato = tarifa actual.
  -- El mismo plan otra vez conserva el precio que ya tenía.
  update restaurants
  set precio_contrato = case
        when plan is distinct from p_plan_key or precio_contrato is null then v_precio
        else precio_contrato
      end,
      plan = p_plan_key
  where id = p_restaurant_id;

  insert into restaurant_modulos (restaurant_id, modulo_key, activo)
  select p_restaurant_id, m.key, true
  from modulos m
  join planes pl on pl.key = m.plan
  where pl.orden <= v_orden_destino
  on conflict (restaurant_id, modulo_key) do update set activo = true;

  update restaurant_modulos rm
  set activo = false
  from modulos m
  join planes pl on pl.key = m.plan
  where rm.modulo_key = m.key
    and rm.restaurant_id = p_restaurant_id
    and pl.orden > v_orden_destino;
end;
$$;

revoke execute on function fn_asignar_plan(uuid, text) from public, anon;
grant execute on function fn_asignar_plan(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Cambiar el precio de contrato (subida pactada, precio especial...)
-- ---------------------------------------------------------------------------

-- p_precio null = pasarlo a la tarifa actual de su plan.
create or replace function fn_actualizar_precio_contrato(p_restaurant_id uuid, p_precio numeric default null)
returns numeric
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_precio numeric;
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;
  if p_precio is not null and p_precio < 0 then
    raise exception 'El precio no puede ser negativo.';
  end if;

  if p_precio is null then
    select pl.precio into v_precio
    from restaurants r join planes pl on pl.key = r.plan
    where r.id = p_restaurant_id;
    if v_precio is null then
      raise exception 'El restaurante no tiene plan o su plan no tiene precio.';
    end if;
  else
    v_precio := round(p_precio, 2);
  end if;

  update restaurants set precio_contrato = v_precio where id = p_restaurant_id;
  if not found then
    raise exception 'Restaurante no encontrado.';
  end if;
  return v_precio;
end;
$$;

revoke execute on function fn_actualizar_precio_contrato(uuid, numeric) from public, anon;
grant execute on function fn_actualizar_precio_contrato(uuid, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- El dueño no puede cambiarse el precio de contrato
-- ---------------------------------------------------------------------------

create or replace function fn_restaurants_proteger_comercial()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is not null and not fn_es_superadmin() then
    new.plan := old.plan;
    new.activo := old.activo;
    new.trial_termina_en := old.trial_termina_en;
    new.precio_override := old.precio_override;
    new.precio_override_hasta := old.precio_override_hasta;
    new.precio_contrato := old.precio_contrato;
    new.permanencia_hasta := old.permanencia_hasta;
    new.baja_en := old.baja_en;
    new.baja_motivo := old.baja_motivo;
    new.baja_penalizacion := old.baja_penalizacion;
  end if;
  return new;
end;
$$;

-- Al dar de alta tampoco puede traerlo puesto.
create or replace function fn_restaurants_proteger_comercial_alta()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is not null and not fn_es_superadmin() then
    new.precio_contrato := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restaurants_proteger_comercial_alta on restaurants;
create trigger trg_restaurants_proteger_comercial_alta
  before insert on restaurants
  for each row execute function fn_restaurants_proteger_comercial_alta();

notify pgrst, 'reload schema';
