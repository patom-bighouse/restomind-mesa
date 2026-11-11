-- ============================================================================
-- Confirmación por sector: cuando una comanda tiene ítems de más de un
-- sector de cocina, cada sector involucrado debe confirmar su parte
-- antes de que la comanda avance de Pendiente→Preparando o de
-- Preparando→Listo. Evita que un sector avance el pedido sin que el
-- otro haya terminado su parte.
-- ============================================================================

create table if not exists order_sector_confirmaciones (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  sector_cocina_id uuid not null references sectores_cocina(id) on delete cascade,
  confirmado_preparando boolean not null default false,
  confirmado_listo boolean not null default false,
  unique (order_id, sector_cocina_id)
);

alter table order_sector_confirmaciones enable row level security;

grant select, insert, update on table order_sector_confirmaciones to anon, authenticated;

drop policy if exists order_sector_confirmaciones_por_restaurante on order_sector_confirmaciones;
create policy order_sector_confirmaciones_por_restaurante
  on order_sector_confirmaciones
  for all
  using (
    order_id in (
      select o.id from orders o
      join restaurants r on r.id = o.restaurant_id
      where r.user_id = auth.uid()
    )
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- Trigger: cada vez que se inserta una línea de pedido (order_items) cuyo
-- plato tiene un sector asignado, se asegura de que exista una fila de
-- confirmación pendiente para ese (order_id, sector). Funciona sin
-- importar si el pedido vino del flujo de mesa o del agente de WhatsApp,
-- ya que ambos insertan en la misma tabla order_items.
create or replace function fn_asegurar_sector_confirmacion()
returns trigger
language plpgsql
security definer
as $$
declare
  v_sector_id uuid;
begin
  if new.menu_item_id is not null then
    select mi.sector_cocina_id into v_sector_id
    from menu_items mi
    where mi.id = new.menu_item_id;

    if v_sector_id is not null then
      insert into order_sector_confirmaciones (order_id, sector_cocina_id)
      values (new.order_id, v_sector_id)
      on conflict (order_id, sector_cocina_id) do nothing;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_asegurar_sector_confirmacion on order_items;
create trigger trg_asegurar_sector_confirmacion
  after insert on order_items
  for each row
  execute function fn_asegurar_sector_confirmacion();
