-- ============================================================================
-- Puntos 6 y 7 de la revisión de seguridad:
--
-- 6) Los PINs de camarero estaban en texto plano en camareros.pin,
--    visibles tal cual en AdminConfig y legibles por cualquiera que
--    llegara a ver una fila de esa tabla (backup, dump, acceso
--    directo). Se reemplaza por camareros.pin_hash (bcrypt, vía
--    pgcrypto) — el dueño ya no puede "ver" el PIN de un camarero
--    después de creado, solo restablecerlo a uno nuevo.
--
-- 7) fn_verificar_camarero_pin no tenía ningún límite de intentos —
--    con 4 dígitos (10.000 combinaciones) y sin bloqueo, era viable
--    de forzar por fuerza bruta. Se agrega un contador de fallos por
--    restaurante: 10 intentos fallidos en una ventana de 5 minutos
--    bloquean nuevos intentos durante 5 minutos.
-- ============================================================================

create extension if not exists pgcrypto;

alter table camareros add column if not exists pin_hash text;

-- Migra los PINs existentes (no rompe si se corre más de una vez:
-- solo toca filas que todavía no tengan pin_hash).
update camareros set pin_hash = crypt(pin, gen_salt('bf')) where pin_hash is null and pin is not null;

alter table camareros alter column pin_hash set not null;

-- El unique(restaurant_id, pin) original ya no tiene sentido sobre un
-- hash (dos PINs iguales generan hashes distintos por el salt) — se
-- verifica "no hay otro camarero con este mismo PIN en texto plano"
-- dentro de las funciones de abajo antes de guardar.
do $$
declare
  v_conname text;
begin
  select conname into v_conname
  from pg_constraint
  where conrelid = 'camareros'::regclass and contype = 'u'
    and pg_get_constraintdef(oid) ilike '%pin%';
  if v_conname is not null then
    execute format('alter table camareros drop constraint %I', v_conname);
  end if;
end $$;

alter table camareros drop column if exists pin;

-- Crear camarero: valida formato de PIN + que no choque con uno ya
-- existente en el mismo restaurante, y hashea antes de guardar.
create or replace function fn_crear_camarero(p_restaurant_id uuid, p_nombre text, p_pin text, p_permisos text[])
returns uuid
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_id uuid;
begin
  if not exists (select 1 from restaurants r where r.id = p_restaurant_id and r.user_id = auth.uid())
     and not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if p_pin !~ '^\d{4}$' then
    raise exception 'El PIN debe ser de 4 dígitos numéricos.';
  end if;
  if exists (
    select 1 from camareros c
    where c.restaurant_id = p_restaurant_id and crypt(p_pin, c.pin_hash) = c.pin_hash
  ) then
    raise exception 'Ya existe un camarero con ese PIN en este restaurante.';
  end if;

  insert into camareros (restaurant_id, nombre, pin_hash, permisos)
  values (p_restaurant_id, p_nombre, crypt(p_pin, gen_salt('bf')), p_permisos)
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function fn_crear_camarero(uuid, text, text, text[]) to authenticated;

-- Restablecer el PIN de un camarero existente (reemplaza al "ver el
-- PIN actual", que ya no es posible una vez hasheado).
create or replace function fn_resetear_pin_camarero(p_camarero_id uuid, p_restaurant_id uuid, p_pin_nuevo text)
returns void
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
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
end;
$$;

grant execute on function fn_resetear_pin_camarero(uuid, uuid, text) to authenticated;

-- Contador de intentos fallidos por restaurante (no por camarero,
-- porque hasta que el PIN no acierta no se sabe a quién pertenece).
create table if not exists camarero_pin_intentos (
  restaurant_id uuid primary key references restaurants(id) on delete cascade,
  fallidos integer not null default 0,
  bloqueado_hasta timestamptz,
  ultimo_intento timestamptz not null default now()
);

alter table camarero_pin_intentos enable row level security;
-- Sin políticas para anon/authenticated a propósito: esta tabla solo
-- la toca fn_verificar_camarero_pin (security definer) — nadie más
-- necesita leerla ni escribirla directo.

create or replace function fn_verificar_camarero_pin(p_restaurant_id uuid, p_pin text)
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
  select * into v_bloqueo from camarero_pin_intentos where restaurant_id = p_restaurant_id;

  if v_bloqueo.bloqueado_hasta is not null and v_bloqueo.bloqueado_hasta > now() then
    raise exception 'Demasiados intentos fallidos. Probá de nuevo en unos minutos.';
  end if;

  select c.id, c.nombre, c.permisos into v_match
  from camareros c
  where c.restaurant_id = p_restaurant_id and c.activo = true and crypt(p_pin, c.pin_hash) = c.pin_hash
  limit 1;

  if v_match.id is not null then
    insert into camarero_pin_intentos (restaurant_id, fallidos, bloqueado_hasta, ultimo_intento)
    values (p_restaurant_id, 0, null, now())
    on conflict (restaurant_id) do update set fallidos = 0, bloqueado_hasta = null, ultimo_intento = now();

    return query select v_match.id, v_match.nombre, v_match.permisos;
    return;
  end if;

  v_nuevos_fallidos := case
    when v_bloqueo.restaurant_id is null or v_bloqueo.ultimo_intento < now() - interval '5 minutes' then 1
    else v_bloqueo.fallidos + 1
  end;

  insert into camarero_pin_intentos (restaurant_id, fallidos, bloqueado_hasta, ultimo_intento)
  values (p_restaurant_id, v_nuevos_fallidos, case when v_nuevos_fallidos >= 10 then now() + interval '5 minutes' else null end, now())
  on conflict (restaurant_id) do update
    set fallidos = v_nuevos_fallidos,
        bloqueado_hasta = case when v_nuevos_fallidos >= 10 then now() + interval '5 minutes' else null end,
        ultimo_intento = now();

  return;
end;
$$;

grant execute on function fn_verificar_camarero_pin(uuid, text) to anon, authenticated;

notify pgrst, 'reload schema';
