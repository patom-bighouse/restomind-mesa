-- ============================================================================
-- Restaurante inactivo = todo cortado. Hasta ahora el botón Activo/Inactivo
-- del superadmin solo cambiaba `restaurants.activo` y nadie lo leía. Con
-- este script, un restaurante inactivo:
--   1. No puede recibir pedidos, reservas, mesas abiertas, llamadas al
--      camarero ni pagos por NINGÚN canal (QR, camarero, WhatsApp/n8n,
--      API directa). Son triggers, así que se aplican incluso con la
--      service role key que usa n8n.
--   2. Su dueño deja de ver y tocar sus datos: is_restaurant_owner()
--      devuelve false, y todas las políticas RLS de dueño pasan por ella
--      (directa o indirectamente, vía la política de `restaurants`).
--   3. Su personal con PIN no puede entrar ni usar las funciones de staff.
-- El superadmin no se ve afectado y puede reactivarlo cuando quiera.
--
-- Mismas firmas que las funciones ya existentes — CREATE OR REPLACE
-- alcanza, no hace falta dropear nada.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- activo NULL cuenta como activo (la columna tiene default true pero
-- admite null). Un id inexistente también devuelve true: esa página ya
-- se encarga de mostrar su propio "no encontrado".
create or replace function fn_restaurante_activo(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce((select r.activo from restaurants r where r.id = p_restaurant_id), true)
$$;

-- Para el guard del frontend: el superadmin sigue pudiendo abrir las
-- páginas de admin/cocina de un restaurante inactivo desde su panel.
create or replace function fn_restaurante_accesible(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select fn_restaurante_activo(p_restaurant_id)
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
$$;

-- Para el login del dueño: con el restaurante inactivo, RLS ya no le deja
-- leer su fila de `restaurants`, así que necesita esto para distinguir
-- "cuenta suspendida" de "no hay restaurante vinculado".
create or replace function fn_mi_restaurante()
returns table(id uuid, activo boolean)
language sql
stable
security definer
set search_path to 'public'
as $$
  select r.id, coalesce(r.activo, true)
  from restaurants r
  where r.user_id = auth.uid()
  limit 1
$$;

grant execute on function fn_restaurante_activo(uuid) to anon, authenticated;
grant execute on function fn_restaurante_accesible(uuid) to anon, authenticated;
revoke execute on function fn_mi_restaurante() from anon;
grant execute on function fn_mi_restaurante() to authenticated;

-- ---------------------------------------------------------------------------
-- Dueño: sin acceso a sus datos mientras esté inactivo
-- ---------------------------------------------------------------------------

create or replace function public.is_restaurant_owner(rid uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    exists (
      select 1 from restaurants r
      where r.id = rid and r.user_id = auth.uid() and coalesce(r.activo, true)
    )
    or exists (
      select 1 from superadmins s
      where s.user_id = auth.uid()
    )
$$;

-- ---------------------------------------------------------------------------
-- Personal con PIN
-- ---------------------------------------------------------------------------

-- Todas las fn_staff_* pasan por aquí.
create or replace function fn_staff_tiene_permiso(p_restaurant_id uuid, p_camarero_id uuid, p_permiso text)
returns boolean
language sql
security definer
set search_path to 'public'
as $$
  select fn_restaurante_activo(p_restaurant_id) and exists (
    select 1 from camareros c
    where c.id = p_camarero_id
      and c.restaurant_id = p_restaurant_id
      and c.activo = true
      and p_permiso = any(c.permisos)
  )
$$;

-- Igual que en fix_mensaje_pin_bloqueado.sql, con el corte al principio.
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
  if not fn_restaurante_activo(p_restaurant_id) then
    raise exception 'Este restaurante no está disponible en este momento.';
  end if;

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

-- ---------------------------------------------------------------------------
-- Candado de escritura: ningún canal crea nada en un restaurante inactivo
-- ---------------------------------------------------------------------------

create or replace function fn_bloquear_si_restaurante_inactivo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_restaurant_id uuid;
begin
  if tg_table_name = 'order_items' then
    select o.restaurant_id into v_restaurant_id from orders o where o.id = new.order_id;
  else
    v_restaurant_id := new.restaurant_id;
  end if;

  if v_restaurant_id is not null and not fn_restaurante_activo(v_restaurant_id) then
    raise exception 'Este restaurante no está disponible en este momento.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restaurante_inactivo on orders;
create trigger trg_restaurante_inactivo
  before insert on orders
  for each row execute function fn_bloquear_si_restaurante_inactivo();

drop trigger if exists trg_restaurante_inactivo on order_items;
create trigger trg_restaurante_inactivo
  before insert on order_items
  for each row execute function fn_bloquear_si_restaurante_inactivo();

drop trigger if exists trg_restaurante_inactivo on reservations;
create trigger trg_restaurante_inactivo
  before insert on reservations
  for each row execute function fn_bloquear_si_restaurante_inactivo();

-- También update: fn_camarero_tomar_mesa y fn_camarero_editar_cliente_sesion
-- modifican sesiones sin pasar por fn_staff_tiene_permiso.
drop trigger if exists trg_restaurante_inactivo on table_sessions;
create trigger trg_restaurante_inactivo
  before insert or update on table_sessions
  for each row execute function fn_bloquear_si_restaurante_inactivo();

drop trigger if exists trg_restaurante_inactivo on table_session_payments;
create trigger trg_restaurante_inactivo
  before insert on table_session_payments
  for each row execute function fn_bloquear_si_restaurante_inactivo();

drop trigger if exists trg_restaurante_inactivo on waiter_calls;
create trigger trg_restaurante_inactivo
  before insert on waiter_calls
  for each row execute function fn_bloquear_si_restaurante_inactivo();

notify pgrst, 'reload schema';
