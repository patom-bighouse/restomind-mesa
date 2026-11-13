-- =============================================================================
-- fn_reserva_whatsapp_crear idempotente con clave (revisión de la entrega 1a)
-- Especificación: docs/specs/2026-11-13-agente-whatsapp-revision.md (criterio 4)
--
-- NO TOCA DATOS existentes. Añade:
--   - reservations.clave_whatsapp (null en las reservas que no vienen del
--     agente) con índice único parcial (restaurant_id, clave_whatsapp);
--   - fn_reserva_whatsapp_crear(..., p_clave text) -> json (id, ya_existia):
--     las mismas validaciones de 20261113114755 y, con la misma clave, devuelve
--     la reserva que ya existe en vez de crear otra (un "sí" repetido cuando
--     falló el envío de la confirmación). Solo service_role (grupo C).
--   - La versión de 9 argumentos (la que usa el agente actual hasta que se
--     reimporte) se mantiene y llama a la nueva sin clave: mismo resultado que hoy.
-- Idempotente.
-- =============================================================================

alter table public.reservations add column if not exists clave_whatsapp text;

create unique index if not exists reservations_clave_whatsapp_key
  on public.reservations (restaurant_id, clave_whatsapp)
  where clave_whatsapp is not null;

create or replace function public.fn_reserva_whatsapp_crear (
  p_restaurant_id    uuid,
  p_nombre           text,
  p_telefono         text,
  p_fecha            date,
  p_hora             time without time zone,
  p_personas         integer,
  p_zona             text,
  p_notas            text,
  p_duracion_minutos integer,
  p_clave            text
)
  returns json
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  c_max_nombre   constant int := 100;
  c_max_notas    constant int := 500;
  c_max_telefono constant int := 30;
  v_id uuid;
  v_motivo text;
  v_max int;
  c_max_clave    constant int := 200;
begin
  -- Idempotencia: la misma clave (un "sí" repetido, p. ej. si no llegó la
  -- confirmación) devuelve la misma reserva. Antes de las validaciones, para
  -- que una reserva ya creada se siga devolviendo aunque su hora esté cerca.
  if p_clave is not null then
    if trim(p_clave) = '' or length(p_clave) > c_max_clave then
      raise exception 'Clave de reserva no válida.' using errcode = 'P0001';
    end if;
    perform pg_advisory_xact_lock(hashtext('reserva_whatsapp|' || coalesce(p_restaurant_id::text, '-') || '|' || p_clave));
    select r.id into v_id from reservations r where r.restaurant_id = p_restaurant_id and r.clave_whatsapp = p_clave;
    if v_id is not null then
      return json_build_object('id', v_id, 'ya_existia', true);
    end if;
  end if;

  if p_restaurant_id is null or not exists (select 1 from restaurants where id = p_restaurant_id) then
    raise exception 'Restaurante no encontrado.' using errcode = 'P0001';
  end if;
  if p_nombre is null or trim(p_nombre) = '' then
    raise exception 'Falta el nombre de la reserva.' using errcode = 'P0001';
  end if;
  if length(trim(p_nombre)) > c_max_nombre then
    raise exception 'El nombre es demasiado largo (máximo % caracteres).', c_max_nombre using errcode = 'P0001';
  end if;
  if p_telefono is null or trim(p_telefono) = '' or length(trim(p_telefono)) > c_max_telefono then
    raise exception 'Teléfono no válido.' using errcode = 'P0001';
  end if;
  if length(trim(coalesce(p_notas, ''))) > c_max_notas then
    raise exception 'Las notas son demasiado largas (máximo % caracteres).', c_max_notas using errcode = 'P0001';
  end if;
  if p_fecha is null or p_hora is null then
    raise exception 'Falta la fecha o la hora de la reserva.' using errcode = 'P0001';
  end if;
  if p_fecha + p_hora <= date_trunc('minute', fn_ahora_madrid()) then
    raise exception 'Esa fecha y hora ya han pasado. Elige otra, por favor.' using errcode = 'P0001';
  end if;
  if p_fecha + p_hora < date_trunc('minute', fn_ahora_madrid()) + interval '15 minutes' then
    raise exception 'Para reservar hoy necesitamos al menos 15 minutos de antelación. Elige una hora más tarde.' using errcode = 'P0001';
  end if;

  v_motivo := fn_reserva_fuera_de_horario(p_restaurant_id, p_fecha, p_hora);
  if v_motivo is not null then
    raise exception '%', v_motivo using errcode = 'P0001';
  end if;

  v_max := (fn_reserva_contexto_cliente(p_restaurant_id, null) ->> 'max_personas')::int;
  if p_personas is null or p_personas < 1 then
    raise exception 'El número de personas no es válido.' using errcode = 'P0001';
  end if;
  if v_max is not null and p_personas > v_max then
    raise exception 'Por WhatsApp podemos reservar como máximo para % personas. Para grupos más grandes, llámanos.', v_max
      using errcode = 'P0001';
  end if;

  -- Serializa todos los intentos de reserva de este restaurante y día:
  -- mientras una transacción tiene el lock, ninguna otra (otra
  -- conversación de WhatsApp, el personal desde el panel, etc.) puede
  -- comprobar/crear para el mismo restaurante+fecha hasta que termine.
  perform pg_advisory_xact_lock(hashtext(p_restaurant_id::text || p_fecha::text));

  if not fn_reserva_hay_mesa(p_restaurant_id, p_fecha, p_hora, p_personas, p_zona, p_duracion_minutos) then
    raise exception 'Ya no hay disponibilidad para esa franja.' using errcode = 'P0001';
  end if;

  insert into reservations (
    restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, duracion_minutos, estado, origen, clave_whatsapp
  ) values (
    p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas,
    coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''),
    p_duracion_minutos, 'confirmada', 'whatsapp', p_clave
  )
  returning id into v_id;

  return json_build_object('id', v_id, 'ya_existia', false);
end;
$$;


revoke all on function public.fn_reserva_whatsapp_crear(uuid, text, text, date, time without time zone, integer, text, text, integer, text) from public, anon, authenticated;
grant execute on function public.fn_reserva_whatsapp_crear(uuid, text, text, date, time without time zone, integer, text, text, integer, text) to service_role;

-- Versión sin clave (agente actual): misma firma y grants, mismo comportamiento.
create or replace function public.fn_reserva_whatsapp_crear (
  p_restaurant_id    uuid,
  p_nombre           text,
  p_telefono         text,
  p_fecha            date,
  p_hora             time without time zone,
  p_personas         integer,
  p_zona             text,
  p_notas            text,
  p_duracion_minutos integer
)
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  return (fn_reserva_whatsapp_crear(p_restaurant_id, p_nombre, p_telefono, p_fecha, p_hora, p_personas,
                                    p_zona, p_notas, p_duracion_minutos, null::text) ->> 'id')::uuid;
end;
$$;

revoke all on function public.fn_reserva_whatsapp_crear(uuid, text, text, date, time without time zone, integer, text, text, integer) from public, anon, authenticated;
grant execute on function public.fn_reserva_whatsapp_crear(uuid, text, text, date, time without time zone, integer, text, text, integer) to service_role;
