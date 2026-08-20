-- ============================================================================
-- Fidelización (puntos): arranca cubriendo take away/reservas por
-- WhatsApp, donde ya tenemos cliente_nombre y cliente_telefono en cada
-- pedido. Mesa/Camarero queda para una segunda etapa.
--
-- Los puntos se otorgan en un único momento: cuando el pedido pasa a
-- estado 'entregado'. Evita duplicar puntos mientras el pedido se arma
-- en varios pasos (el total cambia varias veces antes de estar
-- completo), y tiene sentido de negocio: se premia la compra
-- efectivamente completada, no un pedido que después se cancele.
-- ============================================================================

-- 1) Ficha de cliente por restaurante — también sirve de base para el
-- CRM que se construye después.
create table if not exists clientes (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  telefono text not null,
  nombre text,
  puntos integer not null default 0,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  unique (restaurant_id, telefono)
);

alter table clientes enable row level security;

grant select, insert, update on table clientes to authenticated;

drop policy if exists clientes_dueno on clientes;
create policy clientes_dueno on clientes for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- 2) Trigger: al marcar un pedido de take away como "entregado", suma
-- puntos al cliente (según el teléfono que ya trae el propio pedido),
-- usando la tasa configurada por el restaurante (config.puntos_por_euro,
-- default 1 punto por cada 1€).
create or replace function fn_otorgar_puntos_fidelizacion()
returns trigger
language plpgsql
security definer
as $$
declare
  v_tasa numeric;
  v_puntos integer;
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
            updated_at = now();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_otorgar_puntos_fidelizacion on orders;
create trigger trg_otorgar_puntos_fidelizacion
  after update of estado on orders
  for each row
  execute function fn_otorgar_puntos_fidelizacion();
