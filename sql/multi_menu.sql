-- ============================================================================
-- Multi-menú desde una única carta: el mismo plato vive una vez en
-- menu_items, pero puede tener un precio distinto (o quedar excluido)
-- según el menú activo. El menú activo se resuelve en el frontend
-- (Mesa.jsx/Camarero.jsx) según la zona de la mesa y la hora actual —
-- sin ningún menú configurado, todo sigue funcionando exactamente
-- igual que antes (carta base, sin cambios).
-- ============================================================================

create table menus (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  nombre text not null,
  -- null = aplica a cualquier zona de mesa. Mismos valores que
  -- tables.zona (interior/terraza/privado/barra).
  zona text,
  -- null en ambos = aplica a cualquier hora. Con las dos puestas,
  -- soporta franjas que cruzan medianoche (ej. 22:00–02:00): se
  -- interpreta en el frontend, acá solo se guardan.
  hora_inicio time,
  hora_fin time,
  -- Días de la semana en los que aplica (0=domingo...6=sábado, igual
  -- que Date.getDay() en JS). Null o vacío = todos los días.
  dias_semana smallint[],
  activo boolean not null default true,
  orden integer not null default 0,
  created_at timestamp with time zone not null default now()
);

alter table menus enable row level security;

grant select, insert, update, delete on table menus to authenticated;
grant select on table menus to anon;

drop policy if exists menus_dueno on menus;
create policy menus_dueno on menus for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- El cliente/camarero (anon) solo necesita ver los menús activos, para
-- resolver cuál aplicarle a la mesa.
drop policy if exists menus_select_publico on menus;
create policy menus_select_publico on menus for select using (activo = true);

-- Solo se guarda una fila por (menú, plato) cuando hay una excepción
-- a la carta base — precio distinto, o excluido de ese menú. Un plato
-- sin fila acá se muestra con su precio normal en todos los menús.
create table menu_item_precios_menu (
  id uuid primary key default gen_random_uuid(),
  menu_id uuid not null references menus(id) on delete cascade,
  menu_item_id uuid not null references menu_items(id) on delete cascade,
  precio numeric(8,2),
  excluido boolean not null default false,
  unique (menu_id, menu_item_id)
);

alter table menu_item_precios_menu enable row level security;

grant select, insert, update, delete on table menu_item_precios_menu to authenticated;
grant select on table menu_item_precios_menu to anon;

drop policy if exists menu_item_precios_menu_dueno on menu_item_precios_menu;
create policy menu_item_precios_menu_dueno on menu_item_precios_menu for all
  using (
    exists (
      select 1 from menus m
      where m.id = menu_item_precios_menu.menu_id
        and (
          m.restaurant_id in (select id from restaurants where user_id = auth.uid())
          or exists (select 1 from superadmins s where s.user_id = auth.uid())
        )
    )
  );

drop policy if exists menu_item_precios_menu_select_publico on menu_item_precios_menu;
create policy menu_item_precios_menu_select_publico on menu_item_precios_menu for select using (true);
