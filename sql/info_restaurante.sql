-- ============================================================================
-- Información del restaurante: el dueño guarda datos libres del local
-- (parking, climatización, accesibilidad, mascotas, formas de pago...) en
-- entradas de "título + texto". Se usa en dos sitios:
--   * el agente de WhatsApp (n8n), para responder sin inventar;
--   * la página pública de reservas (/reservar/:id), para que el cliente
--     lo vea antes de reservar.
--
-- Va como módulo "info_restaurante":
--   * incluido en el plan Profesional (y por acumulación en Premium);
--   * opcional en Básico: se activa a mano desde SuperAdminRestaurantes.
--
-- La lectura pública pasa SIEMPRE por fn_info_restaurante_publica, que
-- solo devuelve datos si el módulo está activo y la entrada también.
-- ============================================================================

-- 1) Tabla de entradas ------------------------------------------------------
create table if not exists restaurant_info (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  titulo text not null check (char_length(titulo) between 1 and 80),
  contenido text not null default '' check (char_length(contenido) <= 2000),
  orden integer not null default 0,
  activo boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists restaurant_info_restaurant_idx on restaurant_info (restaurant_id, orden);

alter table restaurant_info enable row level security;

grant select, insert, update, delete on table restaurant_info to authenticated;

-- El dueño ve y gestiona lo suyo; escribir exige el módulo activo (así
-- un restaurante de plan Básico sin el módulo no puede saltarse la
-- pantalla). El superadmin puede todo.
drop policy if exists restaurant_info_dueno on restaurant_info;
create policy restaurant_info_dueno on restaurant_info for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  )
  with check (
    (
      restaurant_id in (select id from restaurants where user_id = auth.uid())
      and exists (
        select 1 from restaurant_modulos rm
        where rm.restaurant_id = restaurant_info.restaurant_id
          and rm.modulo_key = 'info_restaurante'
          and rm.activo = true
      )
    )
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- 2) Módulo en el catálogo y en el plan Profesional ------------------------
insert into modulos (key, nombre, descripcion, requiere, plan, orden)
select
  'info_restaurante',
  'Información del restaurante',
  'Datos libres del local (parking, climatización, accesibilidad, mascotas...) que el agente de WhatsApp y la página de reservas ofrecen a tus clientes.',
  'nucleo',
  'profesional',
  coalesce(max(orden), 0) + 1
from modulos
on conflict (key) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  requiere = excluded.requiere,
  plan = excluded.plan;

-- Los restaurantes que ya tienen plan Profesional o Premium lo reciben
-- ahora (fn_asignar_plan solo se ejecuta al reasignar el plan). Los de
-- Básico no: para ellos es opcional.
insert into restaurant_modulos (restaurant_id, modulo_key, activo)
select r.id, 'info_restaurante', true
from restaurants r
where r.plan in ('profesional', 'premium')
on conflict (restaurant_id, modulo_key) do update set activo = true;

-- 3) Lectura pública (web de reservas + agente de n8n) ----------------------
create or replace function fn_info_restaurante_publica(p_restaurant_id uuid)
returns table (titulo text, contenido text)
language sql
security definer
stable
set search_path to 'public'
as $$
  select i.titulo, i.contenido
  from restaurant_info i
  where i.restaurant_id = p_restaurant_id
    and i.activo = true
    and btrim(i.contenido) <> ''
    and exists (
      select 1 from restaurant_modulos rm
      where rm.restaurant_id = p_restaurant_id
        and rm.modulo_key = 'info_restaurante'
        and rm.activo = true
    )
  order by i.orden, i.created_at;
$$;

revoke all on function fn_info_restaurante_publica(uuid) from public;
grant execute on function fn_info_restaurante_publica(uuid) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
