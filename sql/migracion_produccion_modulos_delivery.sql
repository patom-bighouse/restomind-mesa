-- ============================================================================
-- Restomind — Migración a Producción
-- Generado a partir de comparar el schema real de Test vs Producción.
-- Incluye: módulos de suscripción, delivery genérico, columnas de entrega
-- en `orders`.
-- Seguro de correr de una sola vez (usa IF NOT EXISTS / CREATE OR REPLACE
-- en todos lados).
-- ============================================================================
 
 
-- ----------------------------------------------------------------------------
-- 1) Columnas nuevas en `orders` (delivery)
-- ----------------------------------------------------------------------------
alter table orders
  add column if not exists metodo_entrega text not null default 'retiro_local';
 
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'orders_metodo_entrega_check'
  ) then
    alter table orders
      add constraint orders_metodo_entrega_check
      check (metodo_entrega in ('retiro_local', 'domicilio'));
  end if;
end $$;
 
alter table orders
  add column if not exists direccion_entrega text,
  add column if not exists lat_entrega numeric,
  add column if not exists lng_entrega numeric;
 
 
-- ----------------------------------------------------------------------------
-- 2) Tabla `modulos` (catálogo de módulos de suscripción)
-- ----------------------------------------------------------------------------
create table if not exists modulos (
  key text primary key,
  nombre text not null,
  descripcion text,
  requiere text references modulos(key),
  orden integer not null default 0
);
 
insert into modulos (key, nombre, descripcion, requiere, orden) values
  ('nucleo', 'Núcleo', 'Mesas, Cocina, Carta y Cobro. Siempre incluido en cualquier plan.', null, 1),
  ('reportes', 'Reportes y Dashboard', 'Ingresos, ticket medio, platos más vendidos y horas pico.', 'nucleo', 2),
  ('whatsapp', 'Agente de WhatsApp', 'Consultas, reservas y pedidos takeaway por WhatsApp.', 'nucleo', 3),
  ('takeaway_delivery', 'Take away y Delivery', 'Retiro en el local y entrega a domicilio.', 'whatsapp', 4)
on conflict (key) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  requiere = excluded.requiere,
  orden = excluded.orden;
 
alter table modulos enable row level security;
 
-- Grant a nivel de tabla — sin esto PostgREST devuelve 403 aunque las
-- políticas de RLS estén bien escritas (lección aprendida en Test).
grant select on table modulos to anon, authenticated;
 
drop policy if exists modulos_select_publico on modulos;
create policy modulos_select_publico
  on modulos
  for select
  using (true);
 
 
-- ----------------------------------------------------------------------------
-- 3) Tabla `restaurant_modulos` (qué módulos tiene activo cada restaurante)
-- ----------------------------------------------------------------------------
create table if not exists restaurant_modulos (
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  modulo_key text not null references modulos(key),
  activo boolean not null default true,
  activado_en timestamp with time zone not null default now(),
  primary key (restaurant_id, modulo_key)
);
 
alter table restaurant_modulos enable row level security;
 
grant select, insert, update on table restaurant_modulos to anon, authenticated;
 
drop policy if exists restaurant_modulos_select on restaurant_modulos;
create policy restaurant_modulos_select
  on restaurant_modulos
  for select
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );
 
drop policy if exists restaurant_modulos_write on restaurant_modulos;
create policy restaurant_modulos_write
  on restaurant_modulos
  for insert
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));
 
drop policy if exists restaurant_modulos_update on restaurant_modulos;
create policy restaurant_modulos_update
  on restaurant_modulos
  for update
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()));
 
 
-- ----------------------------------------------------------------------------
-- 4) Función + trigger: activar "Núcleo" automáticamente en cada restaurante
--    nuevo, y backfill para los restaurantes que ya existen en producción
-- ----------------------------------------------------------------------------
create or replace function fn_activar_modulo_nucleo()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into restaurant_modulos (restaurant_id, modulo_key, activo)
  values (new.id, 'nucleo', true)
  on conflict (restaurant_id, modulo_key) do nothing;
  return new;
end;
$$;
 
drop trigger if exists trg_activar_modulo_nucleo on restaurants;
create trigger trg_activar_modulo_nucleo
  after insert on restaurants
  for each row
  execute function fn_activar_modulo_nucleo();
 
-- Backfill: activar Núcleo en todos los restaurantes que YA existen hoy
-- en producción (Casa Montiel y cualquier otro que hayas cargado).
insert into restaurant_modulos (restaurant_id, modulo_key, activo)
select id, 'nucleo', true from restaurants
on conflict (restaurant_id, modulo_key) do nothing;
 
 
-- ----------------------------------------------------------------------------
-- 5) Tabla `order_deliveries` (detalle del envío, separado de `orders`)
-- ----------------------------------------------------------------------------
create table if not exists order_deliveries (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  restaurant_id uuid not null references restaurants(id),
  proveedor text not null,
  estado text not null default 'cotizando',
  costo_envio numeric,
  moneda text,
  quien_paga text,
  proveedor_quote_id text,
  proveedor_delivery_id text,
  tracking_url text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);
 
alter table order_deliveries enable row level security;
 
grant select, insert, update on table order_deliveries to anon, authenticated;
 
drop policy if exists order_deliveries_by_restaurant on order_deliveries;
create policy order_deliveries_by_restaurant
  on order_deliveries
  for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );
 
 
-- ============================================================================
-- FIN. Después de correr esto, repetí las 3 consultas de introspección
-- (columnas, tablas, funciones) contra Producción y comparalas de nuevo
-- con Test para confirmar que quedaron 100% igualadas.
-- ============================================================================