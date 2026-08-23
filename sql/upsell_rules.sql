-- ============================================================================
-- Reglas de upsell automáticas: el dueño define "si el cliente agrega
-- algo de la categoría X, sugerí el plato Y" (ej. Principales -> Flan
-- casero). Se evalúan en el carrito de Mesa.jsx y Camarero.jsx —
-- ambas pantallas leen las mismas reglas, sea cual sea el modo de
-- pedidos del restaurante.
-- ============================================================================

create table if not exists upsell_rules (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  trigger_categoria_id uuid not null references categories(id) on delete cascade,
  sugerido_item_id uuid not null references menu_items(id) on delete cascade,
  mensaje text,
  activa boolean not null default true,
  created_at timestamp with time zone not null default now(),
  unique (restaurant_id, trigger_categoria_id, sugerido_item_id)
);

alter table upsell_rules enable row level security;

grant select, insert, update, delete on table upsell_rules to authenticated;
grant select on table upsell_rules to anon;

drop policy if exists upsell_rules_dueno on upsell_rules;
create policy upsell_rules_dueno on upsell_rules for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- El cliente (anónimo, en Mesa.jsx) y el camarero solo necesitan ver
-- las reglas activas, nunca las que el dueño desactivó.
drop policy if exists upsell_rules_select_publico on upsell_rules;
create policy upsell_rules_select_publico on upsell_rules for select using (activa = true);
