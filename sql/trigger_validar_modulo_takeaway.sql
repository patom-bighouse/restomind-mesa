-- ============================================================================
-- Validación a nivel de base de datos: bloquea la creación de pedidos de
-- takeaway/delivery si el restaurante no tiene el módulo 'takeaway_delivery'
-- activo en restaurant_modulos.
--
-- Esto protege el sistema sin importar de dónde venga el pedido (agente de
-- WhatsApp, app web, o cualquier cliente futuro).
-- ============================================================================

create or replace function fn_validar_modulo_pedido()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.tipo <> 'mesa' then
    if not exists (
      select 1
      from restaurant_modulos
      where restaurant_id = new.restaurant_id
        and modulo_key = 'takeaway_delivery'
        and activo = true
    ) then
      raise exception 'El restaurante % no tiene el módulo takeaway_delivery activo', new.restaurant_id
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validar_modulo_pedido on orders;
create trigger trg_validar_modulo_pedido
  before insert on orders
  for each row
  execute function fn_validar_modulo_pedido();
