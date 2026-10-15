-- ============================================================================
-- Cierra el hueco de overbooking del agente de WhatsApp: hasta ahora la
-- disponibilidad se comprobaba en JavaScript (n8n), UNA sola vez, cuando
-- se terminaban de recoger los datos — y al responder el cliente "sí" a
-- la confirmación (un mensaje nuevo, en una ejecución nueva, que puede
-- llegar minutos después), la reserva se creaba sin volver a comprobar
-- nada. Si en ese hueco otra reserva/sesión ocupaba la última mesa, el
-- agente confirmaba igual, a ciegas.
--
-- Esto mueve la comprobación a dos funciones SQL:
--   - fn_reserva_hay_mesa: el cálculo en sí (solo lectura, reutilizable
--     para el chequeo informativo y para buscar horas alternativas).
--   - fn_reserva_whatsapp_crear: toma un advisory lock por
--     restaurante+día, vuelve a llamar a fn_reserva_hay_mesa bajo ese
--     lock, y solo entonces inserta — así ninguna otra conversación (ni
--     el widget web, ni el panel de personal) puede colarse entre medio.
--     Mismo patrón que ya usa fn_registrar_pedido con los pedidos.
--
-- De paso corrige dos bugs del cálculo anterior:
--   1. Comparaba CANTIDAD de mesas contra CANTIDAD de reservas, sin
--      mirar si la mesa realmente cabía el grupo (una zona con 5 mesas
--      de 2 personas podía "confirmar" un grupo de 8).
--   2. No miraba las mesas ocupadas ahora mismo por clientes sin
--      reserva (table_sessions) — solo otras reservas.
-- ============================================================================

create or replace function fn_reserva_hay_mesa(
  p_restaurant_id uuid,
  p_fecha date,
  p_hora time,
  p_personas integer,
  p_zona text,
  p_duracion_minutos integer
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_inicio integer;
  v_fin integer;
  v_candidatas uuid[];
  v_ocup record;
  v_elegida uuid;
begin
  v_inicio := extract(hour from p_hora)::int * 60 + extract(minute from p_hora)::int;
  v_fin := v_inicio + p_duracion_minutos;

  -- Mesas que individualmente caben el grupo, de la zona pedida (o
  -- todas si "sin preferencia"/null), ordenadas de menor a mayor
  -- capacidad: así el hueco libre más ajustado se gasta primero y no
  -- se "quema" una mesa grande en un grupo pequeño sin necesidad.
  select array_agg(id order by capacidad asc) into v_candidatas
  from tables
  where restaurant_id = p_restaurant_id
    and activa = true
    and capacidad >= p_personas
    and (p_zona is null or p_zona = 'sin preferencia' or zona = p_zona);

  if v_candidatas is null or array_length(v_candidatas, 1) = 0 then
    return false;
  end if;

  -- Demanda ya existente que se solapa con la franja pedida: otras
  -- reservas confirmadas (sin mesa fija — se les asigna por tamaño,
  -- de mayor a menor) y sesiones de mesa abiertas ahora mismo (mesa
  -- fija conocida, ligada a table_id; solo importan si la franja
  -- pedida es hoy y cercana — se estima cuánto van a tardar en
  -- liberarse con la misma regla que la duración de una reserva
  -- nueva, 90/120/150/180 min según comensales).
  for v_ocup in (
    select r.personas as tam, null::uuid as mesa_fija
    from reservations r
    where r.restaurant_id = p_restaurant_id
      and r.fecha = p_fecha
      and r.estado = 'confirmada'
      and (p_zona is null or p_zona = 'sin preferencia'
           or r.zona is null or r.zona = 'sin preferencia' or r.zona = p_zona)
      and v_inicio < (extract(hour from r.hora)::int * 60 + extract(minute from r.hora)::int
                       + coalesce(r.duracion_minutos, 120))
      and v_fin > (extract(hour from r.hora)::int * 60 + extract(minute from r.hora)::int)

    union all

    select t.capacidad as tam, t.id as mesa_fija
    from table_sessions ts
    join tables t on t.id = ts.table_id
    where ts.restaurant_id = p_restaurant_id
      and ts.estado = 'abierta'
      and t.activa = true
      and p_fecha = current_date
      and (p_zona is null or p_zona = 'sin preferencia' or t.zona = p_zona)
      -- Igual que getDuracion() en el lado de n8n (90/120/150/180 según
      -- comensales): si la sesión no tiene comensales cargados, 150 min
      -- de margen conservador, como antes.
      and v_inicio < (extract(hour from ts.abierta_at)::int * 60 + extract(minute from ts.abierta_at)::int
                       + case
                           when ts.comensales is null then 150
                           when ts.comensales <= 2 then 90
                           when ts.comensales <= 4 then 120
                           when ts.comensales <= 8 then 150
                           else 180
                         end)
      and v_fin > (extract(hour from ts.abierta_at)::int * 60 + extract(minute from ts.abierta_at)::int)

    order by tam desc
  )
  loop
    if v_ocup.mesa_fija is not null then
      -- Sesión de mesa: sabemos exactamente qué mesa ocupa.
      v_candidatas := array_remove(v_candidatas, v_ocup.mesa_fija);
    else
      -- Reserva sin mesa fija: le quitamos a las candidatas la más
      -- ajustada que todavía le entre.
      select id into v_elegida
      from tables
      where id = any(v_candidatas) and capacidad >= v_ocup.tam
      order by capacidad asc
      limit 1;
      if v_elegida is not null then
        v_candidatas := array_remove(v_candidatas, v_elegida);
      end if;
    end if;
  end loop;

  -- array_length(...) de un array vacío (tras quitarle todos los
  -- elementos con array_remove) da NULL, no 0 — con coalesce nos
  -- aseguramos de que "sin mesas candidatas" dé `false` de verdad, no
  -- NULL (que en el `if not ...` de fn_reserva_whatsapp_crear se
  -- trataría como "no lanzar la excepción", dejando pasar la reserva).
  return coalesce(array_length(v_candidatas, 1), 0) > 0;
end;
$$;

grant execute on function fn_reserva_hay_mesa(uuid, date, time, integer, text, integer) to anon, authenticated;

-- Crea la reserva del agente de WhatsApp solo si, bajo bloqueo, sigue
-- habiendo mesa en ese preciso instante. Si no, no inserta nada y
-- lanza una excepción clara — el workflow de n8n la captura y avisa al
-- cliente en vez de confirmar algo que ya no existe.
create or replace function fn_reserva_whatsapp_crear(
  p_restaurant_id uuid,
  p_nombre text,
  p_telefono text,
  p_fecha date,
  p_hora time,
  p_personas integer,
  p_zona text,
  p_notas text,
  p_duracion_minutos integer
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id uuid;
begin
  -- Serializa todos los intentos de reserva de este restaurante y día:
  -- mientras una transacción tiene el lock, ninguna otra (otra
  -- conversación de WhatsApp, el personal desde el panel, etc.) puede
  -- comprobar/crear para el mismo restaurante+fecha hasta que termine.
  perform pg_advisory_xact_lock(hashtext(p_restaurant_id::text || p_fecha::text));

  if not fn_reserva_hay_mesa(p_restaurant_id, p_fecha, p_hora, p_personas, p_zona, p_duracion_minutos) then
    raise exception 'Ya no hay disponibilidad para esa franja.' using errcode = 'P0001';
  end if;

  insert into reservations (
    restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, duracion_minutos, estado, origen
  ) values (
    p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas,
    coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''),
    p_duracion_minutos, 'confirmada', 'whatsapp'
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function fn_reserva_whatsapp_crear(uuid, text, text, date, time, integer, text, text, integer) to anon, authenticated;

notify pgrst, 'reload schema';
