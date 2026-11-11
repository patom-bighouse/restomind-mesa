-- ============================================================================
-- Marca de tiempo automática en cada cambio de estado de un pedido
-- (pendiente -> preparando -> listo -> entregado). Con esto el Dashboard
-- puede calcular tiempo medio de preparación y tiempo medio hasta servir
-- con datos reales, en vez de depender de nada externo.
--
-- Se hace con un trigger, no tocando cada sitio que cambia orders.estado,
-- porque hay al menos dos caminos distintos: Cocina.jsx actualiza la fila
-- directo, y el PIN de camarero pasa por fn_staff_cambiar_estado_pedido.
-- Un trigger cubre los dos (y cualquier otro que se añada después) sin
-- que haya que acordarse de nada en cada uno.
-- ============================================================================

alter table orders
  add column if not exists preparando_at timestamp with time zone,
  add column if not exists listo_at timestamp with time zone,
  add column if not exists entregado_at timestamp with time zone;

create or replace function fn_marcar_timestamp_estado_pedido()
returns trigger
language plpgsql
as $$
begin
  if new.estado is distinct from old.estado then
    case new.estado
      when 'preparando' then
        new.preparando_at := coalesce(new.preparando_at, now());
        new.listo_at := null;
        new.entregado_at := null;
      when 'listo' then
        new.listo_at := coalesce(new.listo_at, now());
        new.entregado_at := null;
      when 'entregado' then
        new.entregado_at := coalesce(new.entregado_at, now());
      when 'pendiente' then
        -- Cocina revirtió el pedido hasta el principio: las marcas de
        -- estados posteriores ya no corresponden a este ciclo.
        new.preparando_at := null;
        new.listo_at := null;
        new.entregado_at := null;
      else
        -- 'cancelado' u otro estado: no se tocan las marcas ya puestas.
        null;
    end case;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_marcar_timestamp_estado_pedido on orders;
create trigger trg_marcar_timestamp_estado_pedido
  before update on orders
  for each row execute function fn_marcar_timestamp_estado_pedido();
