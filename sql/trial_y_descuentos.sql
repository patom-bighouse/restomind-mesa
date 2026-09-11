-- ============================================================================
-- Trial gratuito y descuentos de bienvenida — Opción A (sin
-- automatización): guarda las fechas para que SuperAdmin pueda ver
-- qué restaurantes tienen un trial o un descuento por vencer, pero no
-- hace ningún downgrade ni cobro automático. Restomind no tiene
-- pasarela de pago — el cobro real sigue pasando fuera de la app.
--
-- Mismo criterio de seguridad que restaurants.plan: la tabla
-- restaurants ya tiene una política "el dueño puede editar todo lo
-- suyo", así que estas columnas quedan con el UPDATE revocado para
-- authenticated y solo se escriben vía RPC (chequeo de superadmin
-- server-side, no solo ocultando el botón en el frontend).
-- ============================================================================

alter table restaurants add column if not exists trial_termina_en date;
alter table restaurants add column if not exists precio_override numeric(10,2);
alter table restaurants add column if not exists precio_override_hasta date;

revoke update (trial_termina_en, precio_override, precio_override_hasta) on restaurants from authenticated;

create or replace function fn_iniciar_trial(p_restaurant_id uuid, p_dias integer default 14)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  update restaurants set trial_termina_en = current_date + p_dias where id = p_restaurant_id;
end;
$$;

grant execute on function fn_iniciar_trial(uuid, integer) to authenticated;

create or replace function fn_limpiar_trial(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  update restaurants set trial_termina_en = null where id = p_restaurant_id;
end;
$$;

grant execute on function fn_limpiar_trial(uuid) to authenticated;

create or replace function fn_aplicar_descuento(p_restaurant_id uuid, p_precio numeric, p_dias integer)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if p_precio is null or p_precio < 0 then
    raise exception 'Precio inválido.';
  end if;
  update restaurants
  set precio_override = p_precio, precio_override_hasta = current_date + p_dias
  where id = p_restaurant_id;
end;
$$;

grant execute on function fn_aplicar_descuento(uuid, numeric, integer) to authenticated;

create or replace function fn_limpiar_descuento(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  update restaurants set precio_override = null, precio_override_hasta = null where id = p_restaurant_id;
end;
$$;

grant execute on function fn_limpiar_descuento(uuid) to authenticated;

notify pgrst, 'reload schema';
