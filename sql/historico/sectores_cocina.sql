-- ============================================================================
-- Sectores de cocina: permite a restaurantes con cocina dividida (ej:
-- Parrilla, Cocina fría, Postres) filtrar las comandas por sector en la
-- pantalla de Cocina. Es opcional, activable por restaurante desde
-- Configuración.
-- ============================================================================

create table if not exists sectores_cocina (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  nombre text not null,
  orden integer not null default 0,
  created_at timestamp with time zone not null default now()
);

alter table sectores_cocina enable row level security;

grant select, insert, update, delete on table sectores_cocina to authenticated;
grant select on table sectores_cocina to anon;

drop policy if exists sectores_cocina_dueno on sectores_cocina;
create policy sectores_cocina_dueno
  on sectores_cocina
  for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- Lectura pública de solo lectura (para futuros usos, ej. si algún día
-- se quisiera mostrar el sector en Mesa.jsx). No afecta escritura.
drop policy if exists sectores_cocina_select_publico on sectores_cocina;
create policy sectores_cocina_select_publico
  on sectores_cocina
  for select
  using (true);

-- A qué sector pertenece cada plato. NULL = "general", visible siempre
-- sin importar el filtro de sector activo en Cocina.
alter table menu_items
  add column if not exists sector_cocina_id uuid references sectores_cocina(id) on delete set null;
