-- ============================================================================
-- CRM de clientes: sobre la ficha que ya usa fidelización, agrega gasto
-- acumulado y última visita. Hasta ahora la ficha (clientes) solo se
-- creaba/actualizaba cuando el pedido generaba puntos (v_puntos > 0) —
-- eso dejaba sin registrar cualquier visita en un restaurante con tasa
-- de puntos en 0, o pedidos por debajo del umbral de 1 punto. Estas
-- dos columnas quedan desacopladas de esa condición: se actualizan en
-- toda visita con teléfono, gane puntos o no.
-- ============================================================================

alter table clientes
  add column if not exists gasto_acumulado numeric(10,2) not null default 0,
  add column if not exists ultima_visita timestamp with time zone;

-- Take away: mismo disparador que ya existía (pedido entregado, con
-- teléfono) — se mantiene el registro en clientes_movimientos tal cual
-- estaba, solo se agrega la actualización de gasto/última visita.
create or replace function fn_otorgar_puntos_fidelizacion()
returns trigger
language plpgsql
security definer
as $$
declare
  v_tasa numeric;
  v_puntos integer;
  v_cliente_id uuid;
begin
  if new.estado = 'entregado'
     and (old.estado is distinct from 'entregado')
     and new.tipo = 'takeaway'
     and new.cliente_telefono is not null
  then
    select coalesce((config->>'puntos_por_euro')::numeric, 1)
      into v_tasa
    from restaurants
    where id = new.restaurant_id;

    v_puntos := greatest(floor(coalesce(new.total, 0) * v_tasa), 0);

    insert into clientes (restaurant_id, telefono, nombre, puntos, gasto_acumulado, ultima_visita)
    values (new.restaurant_id, new.cliente_telefono, new.cliente_nombre, v_puntos, coalesce(new.total, 0), now())
    on conflict (restaurant_id, telefono) do update
      set puntos = clientes.puntos + v_puntos,
          gasto_acumulado = clientes.gasto_acumulado + coalesce(new.total, 0),
          ultima_visita = now(),
          nombre = coalesce(excluded.nombre, clientes.nombre),
          updated_at = now()
    returning id into v_cliente_id;

    if v_puntos > 0 then
      insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, order_id)
      values (v_cliente_id, 'suma', v_puntos, 'Pedido take away entregado', new.id);
    end if;
  end if;
  return new;
end;
$$;

-- Mesa: mismo criterio (sesión cerrada con teléfono, incluye cierres
-- por invitación de la casa igual que ya hacía este trigger).
create or replace function fn_otorgar_puntos_mesa()
returns trigger
language plpgsql
security definer
as $$
declare
  v_restaurant_id uuid;
  v_tasa numeric;
  v_puntos integer;
  v_cliente_id uuid;
begin
  if new.estado = 'cerrada'
     and (old.estado is distinct from 'cerrada')
     and new.cliente_telefono is not null
  then
    select restaurant_id into v_restaurant_id from table_sessions where id = new.id;

    select coalesce((config->>'puntos_por_euro')::numeric, 1)
      into v_tasa
    from restaurants
    where id = v_restaurant_id;

    v_puntos := greatest(floor(coalesce(new.total, 0) * v_tasa), 0);

    insert into clientes (restaurant_id, telefono, nombre, puntos, gasto_acumulado, ultima_visita)
    values (v_restaurant_id, new.cliente_telefono, new.cliente_nombre, v_puntos, coalesce(new.total, 0), now())
    on conflict (restaurant_id, telefono) do update
      set puntos = clientes.puntos + v_puntos,
          gasto_acumulado = clientes.gasto_acumulado + coalesce(new.total, 0),
          ultima_visita = now(),
          nombre = coalesce(excluded.nombre, clientes.nombre),
          updated_at = now()
    returning id into v_cliente_id;

    if v_puntos > 0 then
      insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, table_session_id)
      values (v_cliente_id, 'suma', v_puntos, 'Visita en mesa', new.id);
    end if;
  end if;
  return new;
end;
$$;
