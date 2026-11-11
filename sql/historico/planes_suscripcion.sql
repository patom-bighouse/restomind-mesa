-- ============================================================================
-- Planes de suscripción (Básico / Profesional / Premium): agrupan los
-- módulos existentes para poder asignarle un plan completo a un
-- restaurante de una sola vez, en vez de activar módulo por módulo.
--
-- El mecanismo real de permisos NO cambia — tieneModulo() sigue
-- leyendo exclusivamente restaurant_modulos, como siempre. "Plan" es
-- una capa de conveniencia por encima: una etiqueta en
-- restaurants.plan + un atajo que activa/desactiva en bloque los
-- módulos que correspondan según modulos.plan.
-- ============================================================================

create table if not exists planes (
  key text primary key,
  nombre text not null,
  descripcion text,
  orden integer not null default 0
);

alter table planes enable row level security;
grant select on table planes to anon, authenticated;
grant insert, update, delete on table planes to authenticated;

drop policy if exists planes_select on planes;
create policy planes_select on planes for select using (true);

drop policy if exists planes_superadmin_write on planes;
create policy planes_superadmin_write on planes for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

insert into planes (key, nombre, descripcion, orden) values
  ('basico', 'Básico', 'Lo esencial para digitalizar tu restaurante: mesas, carta, cocina y cobro.', 1),
  ('profesional', 'Profesional', 'Herramientas para operar mejor el día a día: reportes, stock, equipo, reservas, multiidioma y marketing.', 2),
  ('premium', 'Premium', 'IA (importador de carta, agente de WhatsApp), integraciones externas y marca propia.', 3)
on conflict (key) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  orden = excluded.orden;

-- A qué plan pertenece cada módulo. Solo lectura para todo el mundo
-- (lo necesita el catálogo de SuperAdminRestaurantes); la escritura
-- va exclusivamente por fn_asignar_modulo_a_plan (más abajo), no por
-- GRANT directo — así no hace falta pelearse con permisos por columna
-- en una tabla que ya tenía "select" abierto a anon/authenticated.
alter table modulos add column if not exists plan text references planes(key);

update modulos set plan = 'basico' where key = 'nucleo';
update modulos set plan = 'profesional' where key in (
  'reportes', 'multi_menu', 'control_stock', 'reservas',
  'marketing_fidelizacion', 'gestion_equipo', 'multiidioma'
);
update modulos set plan = 'premium' where key in (
  'importador_carta', 'whatsapp', 'takeaway_delivery', 'webhooks', 'marca_propia'
);

-- Qué plan tiene asignado cada restaurante (solo una etiqueta — el
-- acceso real sigue viniendo de restaurant_modulos). Igual que con
-- modulos.plan, la escritura va por RPC (fn_asignar_plan), no por
-- GRANT: la tabla restaurants ya tiene una política "el dueño puede
-- editar todo lo suyo", así que si dejáramos esta columna con el
-- grant normal, el propio dueño podría auto-asignarse un plan.
alter table restaurants add column if not exists plan text references planes(key);
revoke update (plan) on restaurants from authenticated;

-- Reasigna un módulo a otro plan (usado desde la pantalla "Planes").
create or replace function fn_asignar_modulo_a_plan(p_modulo_key text, p_plan_key text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if not exists (select 1 from planes where key = p_plan_key) then
    raise exception 'Plan no válido.';
  end if;

  update modulos set plan = p_plan_key where key = p_modulo_key;
end;
$$;

grant execute on function fn_asignar_modulo_a_plan(text, text) to authenticated;

-- Asigna un plan completo a un restaurante: guarda la etiqueta y
-- sincroniza restaurant_modulos con todo lo que corresponda a ese
-- plan o a uno inferior (los planes son acumulativos — Premium trae
-- todo lo de Profesional y Básico también). Lo que no corresponda a
-- ningún plan igual o menor queda desactivado.
create or replace function fn_asignar_plan(p_restaurant_id uuid, p_plan_key text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_orden_destino integer;
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;

  select orden into v_orden_destino from planes where key = p_plan_key;
  if v_orden_destino is null then
    raise exception 'Plan no válido.';
  end if;

  update restaurants set plan = p_plan_key where id = p_restaurant_id;

  insert into restaurant_modulos (restaurant_id, modulo_key, activo)
  select p_restaurant_id, m.key, true
  from modulos m
  join planes pl on pl.key = m.plan
  where pl.orden <= v_orden_destino
  on conflict (restaurant_id, modulo_key) do update set activo = true;

  update restaurant_modulos rm
  set activo = false
  from modulos m
  join planes pl on pl.key = m.plan
  where rm.modulo_key = m.key
    and rm.restaurant_id = p_restaurant_id
    and pl.orden > v_orden_destino;
end;
$$;

grant execute on function fn_asignar_plan(uuid, text) to authenticated;

notify pgrst, 'reload schema';
