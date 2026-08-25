-- ============================================================================
-- Checklist de limpieza entre clientes: el dueño define una lista de
-- pasos reutilizable (una sola vez, no por mesa). Al cerrar una mesa
-- con pedidos reales, en vez de quedar libre al instante pasa a
-- "necesita limpieza" hasta que se tildan todos los pasos — el cuarto
-- estado que quedó pendiente del plano de sala visual.
-- ============================================================================

create table if not exists limpieza_pasos (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  texto text not null,
  orden integer not null default 0,
  activo boolean not null default true,
  created_at timestamp with time zone not null default now()
);

alter table limpieza_pasos enable row level security;

grant select, insert, update, delete on table limpieza_pasos to authenticated;

drop policy if exists limpieza_pasos_dueno on limpieza_pasos;
create policy limpieza_pasos_dueno on limpieza_pasos for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- Camarero.jsx corre como rol anónimo (login por PIN propio, no
-- sesión de Supabase Auth) — necesita poder leer los pasos activos
-- para mostrar el checklist.
grant select on table limpieza_pasos to anon;

drop policy if exists limpieza_pasos_select_publico on limpieza_pasos;
create policy limpieza_pasos_select_publico on limpieza_pasos for select using (activo = true);

-- Estado de limpieza por mesa: se resetea cada vez que arranca un
-- nuevo ciclo (mesa recién cerrada). limpieza_progreso guarda los ids
-- de los pasos ya tildados del ciclo actual.
alter table tables
  add column if not exists necesita_limpieza boolean not null default false,
  add column if not exists limpieza_progreso jsonb not null default '[]'::jsonb;

-- tables tiene permisos por columna para el rol anónimo que no
-- incluían estas dos (mismo problema que tuvimos con "comensales" en
-- table_sessions) — Camarero.jsx necesita leerlas Y escribirlas
-- (tilda pasos del checklist él mismo, sin pasar por un dueño logueado).
grant select (necesita_limpieza, limpieza_progreso) on tables to anon;
grant update (necesita_limpieza, limpieza_progreso) on tables to anon;

-- Además del permiso por columna, tables no tenía NINGUNA política
-- RLS que permitiera UPDATE al rol anónimo (solo lectura) — sin esto,
-- el permiso de arriba no alcanza. El propio permiso por columna ya
-- limita a qué puede tocar; esta política solo habilita el UPDATE en
-- sí, igual de permisiva que la de lectura que ya existía para tables.
drop policy if exists anon_update_limpieza_tables on tables;
create policy anon_update_limpieza_tables on tables for update to anon
  using (true)
  with check (true);
