-- =============================================================================
-- Bloqueo progresivo del PIN del camarero (backlog: "Endurecer el PIN").
--
-- Antes: 10 fallos seguidos → 5 minutos de bloqueo y el contador volvía a cero
-- a los 5 minutos sin fallos. Unos 2.900 intentos al día por camarero: el PIN
-- (4 cifras) se podía adivinar en unos días.
--
-- Ahora (decisión de Patricio, 13-11-2026), por cada 10 fallos seguidos:
--   10 → 5 min · 20 → 30 min · 30 → 2 h · 40 o más → 24 h (cada 10 fallos).
-- El contador vuelve a cero al acertar el PIN, cuando pasan 24 h sin fallos
-- (contadas desde el último fallo o desde el fin del último bloqueo, lo que
-- sea más tarde), o cuando el dueño le cambia el PIN.
-- Con esto un ataque necesita más de un año por camarero.
--
-- Cambios:
--   * fn_verificar_camarero_pin: solo cambia el cálculo tras un PIN fallido.
--   * fn_resetear_pin_camarero: además borra el bloqueo del camarero (cambiar
--     el PIN desde el panel sirve para desbloquearlo).
-- Mismas firmas (create or replace conserva la ACL); los grants se reescriben
-- igual que en 20261112152109_pin_camarero_fase1.sql.
-- No toca datos.
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

  select * into v_bloqueo from camarero_pin_intentos cpi where cpi.camarero_id = p_camarero_id;

  if v_bloqueo.bloqueado_hasta is not null and v_bloqueo.bloqueado_hasta > now() then
    raise exception 'Demasiados intentos fallidos. Inténtalo de nuevo en unos minutos.';
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

create or replace function public.fn_resetear_pin_camarero(p_camarero_id uuid, p_restaurant_id uuid, p_pin_nuevo text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $function$
begin
  if not exists (select 1 from restaurants r where r.id = p_restaurant_id and r.user_id = auth.uid())
     and not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if p_pin_nuevo !~ '^\d{4}$' then
    raise exception 'El PIN debe ser de 4 dígitos numéricos.';
  end if;
  if exists (
    select 1 from camareros c
    where c.restaurant_id = p_restaurant_id and c.id != p_camarero_id and crypt(p_pin_nuevo, c.pin_hash) = c.pin_hash
  ) then
    raise exception 'Ya existe un camarero con ese PIN en este restaurante.';
  end if;
  update camareros set pin_hash = crypt(p_pin_nuevo, gen_salt('bf'))
  where id = p_camarero_id and restaurant_id = p_restaurant_id;
  -- Quien tenga la app abierta con el PIN anterior tiene que volver a entrar.
  update camarero_sesiones s
  set revocada_at = now()
  where s.camarero_id = p_camarero_id
    and s.restaurant_id = p_restaurant_id
    and s.revocada_at is null;
  -- Cambiar el PIN desbloquea al camarero (fallidos y bloqueo a cero).
  delete from camarero_pin_intentos cpi
  where cpi.camarero_id = p_camarero_id
    and exists (select 1 from camareros c where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id);
end;
$function$;

revoke all on function public.fn_resetear_pin_camarero(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fn_resetear_pin_camarero(uuid, uuid, text) to authenticated, service_role;

notify pgrst, 'reload schema';
