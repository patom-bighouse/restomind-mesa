-- ============================================================================
-- Historial de movimientos de puntos: hasta ahora clientes.puntos solo
-- guardaba el saldo actual, sin dejar rastro de cuándo se sumó o se
-- canjeó cada movimiento. Esta tabla agrega esa trazabilidad.
-- ============================================================================

create table if not exists clientes_movimientos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references clientes(id) on delete cascade,
  tipo text not null check (tipo in ('suma', 'resta')),
  puntos integer not null check (puntos > 0),
  motivo text,
  order_id uuid references orders(id) on delete set null,
  created_at timestamp with time zone not null default now()
);

alter table clientes_movimientos enable row level security;

grant select, insert on table clientes_movimientos to authenticated;

drop policy if exists clientes_movimientos_dueno on clientes_movimientos;
create policy clientes_movimientos_dueno on clientes_movimientos for all
  using (
    cliente_id in (
      select c.id from clientes c
      join restaurants r on r.id = c.restaurant_id
      where r.user_id = auth.uid()
    )
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- ============================================================================
-- Actualiza el trigger de fidelización para que, además de sumar el
-- saldo, deje registrado el movimiento (con el pedido que lo originó).
-- Mismo nombre y firma de función — no hace falta recrear el trigger.
-- ============================================================================

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

    v_puntos := floor(coalesce(new.total, 0) * v_tasa);

    if v_puntos > 0 then
      insert into clientes (restaurant_id, telefono, nombre, puntos)
      values (new.restaurant_id, new.cliente_telefono, new.cliente_nombre, v_puntos)
      on conflict (restaurant_id, telefono) do update
        set puntos = clientes.puntos + v_puntos,
            nombre = coalesce(excluded.nombre, clientes.nombre),
            updated_at = now()
      returning id into v_cliente_id;

      insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, order_id)
      values (v_cliente_id, 'suma', v_puntos, 'Pedido take away entregado', new.id);
    end if;
  end if;
  return new;
end;
$$;
