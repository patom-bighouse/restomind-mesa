-- ============================================================================
-- Modo "Camarero": permite que el restaurante elija que los pedidos se
-- carguen desde una tablet del camarero (con PIN propio) en vez de que
-- el cliente los cargue solo desde su celular.
-- ============================================================================

-- 1) Tabla de camareros por restaurante
create table if not exists camareros (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  nombre text not null,
  pin text not null,
  activo boolean not null default true,
  created_at timestamp with time zone not null default now(),
  unique (restaurant_id, pin)
);

alter table camareros enable row level security;

-- Solo el dueño del restaurante (o superadmin) puede ver/gestionar la
-- lista de camareros y sus PINs — nunca se expone directamente al
-- cliente ni a la tablet sin pasar por la función de verificación
-- (el grant de ejecución sobre esa función va más abajo, después de
-- crearla).
grant select, insert, update, delete on table camareros to authenticated;

drop policy if exists camareros_dueno on camareros;
create policy camareros_dueno
  on camareros
  for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- 2) Quién tomó cada pedido (null = lo cargó el propio cliente)
alter table orders
  add column if not exists tomado_por uuid references camareros(id);

-- 3) Verifica un PIN sin exponer la tabla completa de camareros. Se
-- ejecuta con permisos elevados (security definer) para poder leer la
-- tabla protegida por RLS, pero solo devuelve id + nombre si el PIN es
-- correcto — nunca el PIN mismo.
create or replace function fn_verificar_camarero_pin(p_restaurant_id uuid, p_pin text)
returns table(id uuid, nombre text)
language sql
security definer
set search_path to 'public'
as $$
  select c.id, c.nombre
  from camareros c
  where c.restaurant_id = p_restaurant_id
    and c.pin = p_pin
    and c.activo = true
  limit 1
$$;

grant execute on function fn_verificar_camarero_pin(uuid, text) to anon, authenticated;

-- 4) Actualizar fn_registrar_pedido para aceptar el camarero que tomó el
-- pedido (parámetro opcional, mantiene compatibilidad con las llamadas
-- existentes desde Mesa.jsx y el agente de WhatsApp, que no lo envían).
CREATE OR REPLACE FUNCTION public.fn_registrar_pedido(
  p_table_session_id uuid,
  p_items jsonb,
  p_notas text DEFAULT NULL::text,
  p_camarero_id uuid DEFAULT NULL::uuid
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_restaurant_id  uuid;
  v_table_id       uuid;
  v_modo_cocina    text;
  v_minutos_limite int;
  v_order_id       uuid;
  v_notas_actual   text;
begin
  perform pg_advisory_xact_lock(hashtext(p_table_session_id::text));

  select ts.restaurant_id, ts.table_id, r.modo_cocina, r.minutos_limite_agrupado
    into v_restaurant_id, v_table_id, v_modo_cocina, v_minutos_limite
  from table_sessions ts
  join restaurants r on r.id = ts.restaurant_id
  where ts.id = p_table_session_id
    and ts.estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa % no existe o ya está cerrada', p_table_session_id;
  end if;

  if v_modo_cocina = 'agrupado_mesa' then
    select id into v_order_id
    from orders
    where table_session_id = p_table_session_id
      and estado = 'pendiente'
      and created_at > now() - (v_minutos_limite || ' minutes')::interval
    order by created_at desc
    limit 1;
  end if;

  if v_order_id is null then
    insert into orders (restaurant_id, table_id, table_session_id, tipo, estado, notas, tomado_por)
    values (v_restaurant_id, v_table_id, p_table_session_id, 'mesa', 'pendiente', p_notas, p_camarero_id)
    returning id into v_order_id;
  elsif p_notas is not null and length(trim(p_notas)) > 0 then
    select notas into v_notas_actual from orders where id = v_order_id;
    if v_notas_actual is null or length(trim(v_notas_actual)) = 0 then
      update orders set notas = p_notas where id = v_order_id;
    elsif position(p_notas in v_notas_actual) = 0 then
      update orders set notas = v_notas_actual || ' · ' || p_notas where id = v_order_id;
    end if;
  end if;

  insert into order_items (
    order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, agregado_at, restaurant_id
  )
  select
    v_order_id,
    mi.id,
    mi.nombre,
    mi.precio,
    mi.precio_costo,
    (i->>'cantidad')::int,
    i->>'notas',
    now(),
    v_restaurant_id
  from jsonb_array_elements(p_items) as i
  join menu_items mi on mi.id = (i->>'menu_item_id')::uuid;

  return v_order_id;
end;
$function$
