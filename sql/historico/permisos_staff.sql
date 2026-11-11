-- ============================================================================
-- Permisos a la carta para el personal con PIN: cada camarero/encargado
-- tiene una lista de permisos (pedidos, cocina, clientes, reservas,
-- limpieza) en vez de un rol fijo. "Configuración" nunca es otorgable
-- por PIN — solo el dueño con su login real.
-- ============================================================================

alter table camareros
  add column if not exists permisos text[] not null default '{pedidos}';

-- fn_verificar_camarero_pin cambia de forma de salida (se agrega
-- permisos) — hay que borrarla antes de recrearla.
drop function if exists fn_verificar_camarero_pin(uuid, text);

create or replace function fn_verificar_camarero_pin(p_restaurant_id uuid, p_pin text)
returns table(id uuid, nombre text, permisos text[])
language sql
security definer
set search_path to 'public'
as $$
  select c.id, c.nombre, c.permisos
  from camareros c
  where c.restaurant_id = p_restaurant_id
    and c.pin = p_pin
    and c.activo = true
  limit 1
$$;

grant execute on function fn_verificar_camarero_pin(uuid, text) to anon, authenticated;

-- ============================================================================
-- Caja fuerte de Clientes: el PIN nunca lee la tabla `clientes` ni
-- `clientes_movimientos` directo (RLS solo deja pasar al dueño real) —
-- estas funciones revisan, en cada llamada, que ese camarero_id siga
-- activo y tenga el permiso 'clientes' antes de devolver o cambiar
-- nada. Revocarle el permiso a alguien (o desactivarlo) corta el
-- acceso al instante, sin depender de que "cierre sesión".
-- ============================================================================

create or replace function fn_staff_tiene_permiso(p_restaurant_id uuid, p_camarero_id uuid, p_permiso text)
returns boolean
language sql
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from camareros c
    where c.id = p_camarero_id
      and c.restaurant_id = p_restaurant_id
      and c.activo = true
      and p_permiso = any(c.permisos)
  )
$$;

create or replace function fn_staff_listar_clientes(p_restaurant_id uuid, p_camarero_id uuid)
returns table(id uuid, telefono text, nombre text, puntos integer, gasto_acumulado numeric, ultima_visita timestamp with time zone, updated_at timestamp with time zone)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  return query
    select c.id, c.telefono, c.nombre, c.puntos, c.gasto_acumulado, c.ultima_visita, c.updated_at
    from clientes c
    where c.restaurant_id = p_restaurant_id
    order by c.puntos desc;
end;
$$;

create or replace function fn_staff_historial_cliente(p_restaurant_id uuid, p_camarero_id uuid, p_cliente_id uuid)
returns table(id uuid, tipo text, puntos integer, motivo text, created_at timestamp with time zone)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  return query
    select m.id, m.tipo, m.puntos, m.motivo, m.created_at
    from clientes_movimientos m
    join clientes c on c.id = m.cliente_id
    where c.id = p_cliente_id and c.restaurant_id = p_restaurant_id
    order by m.created_at desc;
end;
$$;

create or replace function fn_staff_canjear_puntos(p_restaurant_id uuid, p_camarero_id uuid, p_cliente_id uuid, p_cantidad integer, p_motivo text default null)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_puntos_actuales integer;
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'Cantidad de puntos inválida';
  end if;

  select puntos into v_puntos_actuales
  from clientes
  where id = p_cliente_id and restaurant_id = p_restaurant_id;

  if v_puntos_actuales is null then
    raise exception 'Cliente no encontrado';
  end if;

  if p_cantidad > v_puntos_actuales then
    raise exception 'Ese cliente no tiene suficientes puntos';
  end if;

  update clientes
  set puntos = puntos - p_cantidad, updated_at = now()
  where id = p_cliente_id;

  insert into clientes_movimientos (cliente_id, tipo, puntos, motivo)
  values (p_cliente_id, 'resta', p_cantidad, coalesce(nullif(trim(p_motivo), ''), 'Canje en el local'));
end;
$$;

grant execute on function fn_staff_tiene_permiso(uuid, uuid, text) to anon, authenticated;
grant execute on function fn_staff_listar_clientes(uuid, uuid) to anon, authenticated;
grant execute on function fn_staff_historial_cliente(uuid, uuid, uuid) to anon, authenticated;
grant execute on function fn_staff_canjear_puntos(uuid, uuid, uuid, integer, text) to anon, authenticated;
