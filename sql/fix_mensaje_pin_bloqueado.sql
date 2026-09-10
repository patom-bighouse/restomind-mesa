-- Corrige el mensaje de bloqueo de PIN: estaba en voseo argentino
-- ("Probá de nuevo"), debe ser español peninsular. Mismos parámetros
-- que la función ya creada — un CREATE OR REPLACE alcanza, no hace
-- falta dropearla.
create or replace function fn_verificar_camarero_pin(p_restaurant_id uuid, p_camarero_id uuid, p_pin text)
returns table(id uuid, nombre text, permisos text[])
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_bloqueo camarero_pin_intentos;
  v_match record;
  v_nuevos_fallidos integer;
begin
  select c.id, c.nombre, c.permisos, c.pin_hash into v_match
  from camareros c
  where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true;

  if v_match.id is null then
    raise exception 'Camarero no válido.';
  end if;

  select * into v_bloqueo from camarero_pin_intentos where camarero_id = p_camarero_id;

  if v_bloqueo.bloqueado_hasta is not null and v_bloqueo.bloqueado_hasta > now() then
    raise exception 'Demasiados intentos fallidos. Inténtalo de nuevo en unos minutos.';
  end if;

  if crypt(p_pin, v_match.pin_hash) = v_match.pin_hash then
    insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
    values (p_camarero_id, 0, null, now())
    on conflict (camarero_id) do update set fallidos = 0, bloqueado_hasta = null, ultimo_intento = now();

    return query select v_match.id, v_match.nombre, v_match.permisos;
    return;
  end if;

  v_nuevos_fallidos := case
    when v_bloqueo.camarero_id is null or v_bloqueo.ultimo_intento < now() - interval '5 minutes' then 1
    else v_bloqueo.fallidos + 1
  end;

  insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
  values (p_camarero_id, v_nuevos_fallidos, case when v_nuevos_fallidos >= 10 then now() + interval '5 minutes' else null end, now())
  on conflict (camarero_id) do update
    set fallidos = v_nuevos_fallidos,
        bloqueado_hasta = case when v_nuevos_fallidos >= 10 then now() + interval '5 minutes' else null end,
        ultimo_intento = now();

  return;
end;
$$;

notify pgrst, 'reload schema';
