-- ============================================================================
-- El bloqueo por intentos fallidos (sql/fix_camareros_pin_seguridad.sql)
-- era por restaurante entero: si un camarero se equivocaba/olvidaba
-- su PIN varias veces, bloqueaba a TODO el personal durante 5
-- minutos. Se cambia a bloqueo por persona: la pantalla de login pasa
-- a pedir primero "quién eres" (de una lista, no texto libre) y
-- después el PIN — así el contador de intentos fallidos es por
-- camarero_id, no por restaurante.
--
-- IMPORTANTE: fn_verificar_camarero_pin cambia de 2 a 3 parámetros.
-- CREATE OR REPLACE no reemplaza una función cuando cambia la lista
-- de parámetros (crea un overload nuevo en paralelo) — hay que borrar
-- la firma vieja explícitamente o quedan las dos ambiguas.
-- ============================================================================

drop function if exists fn_verificar_camarero_pin(uuid, text);

drop table if exists camarero_pin_intentos;

create table camarero_pin_intentos (
  camarero_id uuid primary key references camareros(id) on delete cascade,
  fallidos integer not null default 0,
  bloqueado_hasta timestamptz,
  ultimo_intento timestamptz not null default now()
);

alter table camarero_pin_intentos enable row level security;
-- Sin políticas para anon/authenticated: solo la toca
-- fn_verificar_camarero_pin (security definer).

-- Lista de nombres para la pantalla "¿quién eres?" — solo id y
-- nombre, nada sensible (ni PIN, ni permisos).
create or replace function fn_listar_camareros_nombres(p_restaurant_id uuid)
returns table(id uuid, nombre text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select c.id, c.nombre from camareros c
  where c.restaurant_id = p_restaurant_id and c.activo = true
  order by c.nombre
$$;

grant execute on function fn_listar_camareros_nombres(uuid) to anon, authenticated;

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

grant execute on function fn_verificar_camarero_pin(uuid, uuid, text) to anon, authenticated;

notify pgrst, 'reload schema';
