-- ============================================================================
-- Reservas con widget web + gestión de no-shows: la tabla `reservations`
-- ya existía (alimentada hasta ahora solo por el flujo de WhatsApp/n8n,
-- con acceso privilegiado), pero nunca tuvo RLS ni políticas — queda
-- sin protección real si se accede desde el frontend. Este archivo la
-- habilita para dos caminos nuevos: el panel de administración
-- (/admin/reservas) y el widget público (/reservar).
-- ============================================================================

alter table reservations enable row level security;

grant select, insert, update, delete on table reservations to authenticated;

drop policy if exists reservations_dueno on reservations;
create policy reservations_dueno on reservations for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- El cliente anónimo (widget público) no inserta directo a la tabla —
-- pasa por esta función, que fuerza estado = 'pendiente' y origen =
-- 'web' sin importar lo que mande el cliente, y valida los datos
-- mínimos. Así el dueño siempre confirma a mano antes de que cuente
-- como reserva real.
create or replace function fn_crear_reserva_web(
  p_restaurant_id uuid,
  p_nombre text,
  p_telefono text,
  p_fecha date,
  p_hora time,
  p_personas integer,
  p_zona text default 'sin preferencia',
  p_notas text default null
)
returns void
language plpgsql
security definer
as $$
begin
  if p_nombre is null or trim(p_nombre) = '' then
    raise exception 'Falta el nombre';
  end if;
  if p_telefono is null or trim(p_telefono) = '' then
    raise exception 'Falta el teléfono';
  end if;
  if p_personas is null or p_personas < 1 then
    raise exception 'Cantidad de personas inválida';
  end if;
  if p_fecha is null or p_fecha < current_date then
    raise exception 'La fecha tiene que ser hoy o más adelante';
  end if;
  if not exists (select 1 from restaurants where id = p_restaurant_id) then
    raise exception 'Restaurante no encontrado';
  end if;

  insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, estado, origen)
  values (p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas, coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''), 'pendiente', 'web');
end;
$$;

grant execute on function fn_crear_reserva_web(uuid, text, text, date, time, integer, text, text) to anon, authenticated;
