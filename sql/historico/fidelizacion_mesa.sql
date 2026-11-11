-- ============================================================================
-- Fidelización — extensión a Mesa/Camarero: el teléfono se asocia a la
-- SESIÓN de mesa (no a cada pedido individual), porque una visita puede
-- tener varios pedidos mientras la mesa está abierta, y los puntos se
-- otorgan una sola vez, al cerrar la mesa — no por cada pedido suelto.
-- ============================================================================

alter table table_sessions
  add column if not exists cliente_telefono text,
  add column if not exists cliente_nombre text;

-- Traza de qué sesión de mesa originó cada movimiento (además de la
-- columna order_id que ya existía para los movimientos de take away).
alter table clientes_movimientos
  add column if not exists table_session_id uuid references table_sessions(id) on delete set null;

-- ============================================================================
-- RPC para que el cliente (anónimo, vía Mesa.jsx) pueda dejar su
-- teléfono desde el botón "Sumá puntos" — valida que la sesión
-- realmente pertenezca a la mesa del qr_token que está escaneando,
-- para que nadie pueda escribir el teléfono de la sesión de otra mesa.
-- ============================================================================
create or replace function fn_registrar_cliente_sesion(
  p_session_id uuid,
  p_qr_token text,
  p_telefono text,
  p_nombre text default null
)
returns void
language plpgsql
security definer
as $$
begin
  update table_sessions ts
  set cliente_telefono = p_telefono,
      cliente_nombre = coalesce(p_nombre, ts.cliente_nombre)
  from tables t
  where ts.table_id = t.id
    and ts.id = p_session_id
    and t.qr_token = p_qr_token
    and ts.estado = 'abierta';
end;
$$;

grant execute on function fn_registrar_cliente_sesion(uuid, text, text, text) to anon, authenticated;

-- ============================================================================
-- Trigger: al cerrar una mesa con teléfono asociado, otorga puntos
-- sobre el total de la sesión completa (todos los pedidos de esa
-- visita), igual que ya pasa con take away al entregar.
-- ============================================================================
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

    v_puntos := floor(coalesce(new.total, 0) * v_tasa);

    if v_puntos > 0 then
      insert into clientes (restaurant_id, telefono, nombre, puntos)
      values (v_restaurant_id, new.cliente_telefono, new.cliente_nombre, v_puntos)
      on conflict (restaurant_id, telefono) do update
        set puntos = clientes.puntos + v_puntos,
            nombre = coalesce(excluded.nombre, clientes.nombre),
            updated_at = now()
      returning id into v_cliente_id;

      insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, table_session_id)
      values (v_cliente_id, 'suma', v_puntos, 'Visita en mesa', new.id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_otorgar_puntos_mesa on table_sessions;
create trigger trg_otorgar_puntos_mesa
  after update of estado on table_sessions
  for each row
  execute function fn_otorgar_puntos_mesa();
