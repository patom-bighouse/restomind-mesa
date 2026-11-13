-- =============================================================================
-- Bloqueo progresivo del PIN: intentos simultáneos y mensaje
-- (corrige 20261113082049_pin_bloqueo_progresivo, aún no aplicada en Producción).
--
-- 1. Concurrencia (revisor, 13-11-2026): la fila de camarero_pin_intentos se
--    leía sin bloquear. Con K peticiones a la vez para el mismo camarero, todas
--    leían el mismo contador y escribían n+1: se probaban K PIN y contaba un
--    fallo. Ahora se crea la fila si no existe y se lee con `for update`: los
--    intentos de un mismo camarero van de uno en uno.
-- 2. Mensaje de bloqueo: con bloqueos de 2 h o 24 h, "en unos minutos"
--    engañaba. Ahora: "Espera un rato o pide al encargado que te cambie el PIN"
--    (cambiar el PIN desbloquea).
--
-- Cuánto frena (sin concurrencia): la mejor estrategia de un atacante es 30
-- intentos (≈2 h 35 min de bloqueos), esperar 24 h y repetir: ≈27 PIN al día
-- por camarero (≈1 año el peor caso, ≈6 meses de media). Pero los PIN son
-- únicos por restaurante y se puede probar el mismo PIN contra los N
-- camareros a la vez: ≈10.000/(N+1) intentos por camarero (con 10 camareros,
-- ≈1 mes). Lo cierra del todo el aviso al dueño (backlog).
--
-- Misma firma y grants. No toca datos.
-- =============================================================================

create or replace function public.fn_verificar_camarero_pin(p_restaurant_id uuid, p_camarero_id uuid, p_pin text)
returns table(id uuid, nombre text, permisos text[], token text, caduca_at timestamptz)
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  v_bloqueo camarero_pin_intentos;
  v_match record;
  v_nuevos_fallidos integer;
  v_bloqueado_hasta timestamptz;
  v_token text;
  v_caduca timestamptz;
begin
  if not fn_restaurante_activo(p_restaurant_id) then
    raise exception 'Este restaurante no está disponible en este momento.';
  end if;

  select c.id, c.nombre, c.permisos, c.pin_hash into v_match
  from camareros c
  where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true;

  if v_match.id is null then
    raise exception 'Camarero no válido.';
  end if;

  -- Los intentos de un mismo camarero se procesan de uno en uno: se asegura
  -- que existe su fila y se bloquea (for update) antes de leer el contador.
  -- Sin esto, K intentos simultáneos leían el mismo contador y solo sumaban 1.
  insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
  values (p_camarero_id, 0, null, now())
  on conflict (camarero_id) do nothing;

  select * into v_bloqueo from camarero_pin_intentos cpi
  where cpi.camarero_id = p_camarero_id
  for update;

  if v_bloqueo.bloqueado_hasta is not null and v_bloqueo.bloqueado_hasta > now() then
    raise exception 'Demasiados intentos fallidos. Espera un rato o pide al encargado que te cambie el PIN.';
  end if;

  if crypt(p_pin, v_match.pin_hash) = v_match.pin_hash then
    insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
    values (p_camarero_id, 0, null, now())
    on conflict (camarero_id) do update set fallidos = 0, bloqueado_hasta = null, ultimo_intento = now();

    -- Limpieza: sesiones caducadas o revocadas hace más de 7 días.
    delete from camarero_sesiones s
    where s.caduca_at < now() - interval '7 days'
       or s.revocada_at < now() - interval '7 days';

    v_token := encode(gen_random_bytes(32), 'hex');
    v_caduca := now() + interval '12 hours';

    insert into camarero_sesiones (camarero_id, restaurant_id, token_hash, caduca_at)
    values (v_match.id, p_restaurant_id, encode(digest(v_token, 'sha256'), 'hex'), v_caduca);

    return query select v_match.id, v_match.nombre, v_match.permisos, v_token, v_caduca;
    return;
  end if;

  -- PIN fallido. El contador vuelve a 1 si han pasado 24 h sin fallos, contadas
  -- desde el último fallo o desde el fin del último bloqueo (lo más tarde).
  v_nuevos_fallidos := case
    when v_bloqueo.camarero_id is null
      or greatest(v_bloqueo.ultimo_intento, coalesce(v_bloqueo.bloqueado_hasta, v_bloqueo.ultimo_intento))
         < now() - interval '24 hours'
    then 1
    else v_bloqueo.fallidos + 1
  end;

  -- Cada 10 fallos seguidos, un bloqueo más largo: 5 min, 30 min, 2 h y 24 h.
  v_bloqueado_hasta := case
    when v_nuevos_fallidos % 10 <> 0 then null
    when v_nuevos_fallidos = 10 then now() + interval '5 minutes'
    when v_nuevos_fallidos = 20 then now() + interval '30 minutes'
    when v_nuevos_fallidos = 30 then now() + interval '2 hours'
    else now() + interval '24 hours'
  end;

  insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
  values (p_camarero_id, v_nuevos_fallidos, v_bloqueado_hasta, now())
  on conflict (camarero_id) do update
    set fallidos = v_nuevos_fallidos,
        bloqueado_hasta = v_bloqueado_hasta,
        ultimo_intento = now();

  return;
end;
$function$;

revoke all on function public.fn_verificar_camarero_pin(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fn_verificar_camarero_pin(uuid, uuid, text) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
