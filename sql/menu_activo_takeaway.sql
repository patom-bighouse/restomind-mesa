-- ============================================================================
-- Menús (precios y exclusiones por horario/día) también en los pedidos de
-- WhatsApp.
--
-- El agente leía la carta directamente de menu_items, con el precio base:
-- un menú como "Viernes Nocturno" (precios distintos los viernes de 21:00 a
-- 23:59) se aplicaba en la mesa y en Camarero, pero no en WhatsApp.
--
--   menus.aplica_whatsapp: el administrador decide en cada menú si se
--       aplica también a los pedidos de WhatsApp (por defecto, no). Solo
--       puede marcarse en menús sin zona ("Cualquiera"): un pedido para
--       llevar no tiene zona de mesa.
--   fn_menu_activo(restaurante, zona, momento): el menú que aplica, con el
--       mismo criterio que fn_registrar_pedido y src/lib/menus.js (zona,
--       franja horaria y día de la semana en hora de España; gana el más
--       específico y, a igualdad, el de menor orden).
--   fn_carta_takeaway(restaurante, momento): la carta para el agente, con
--       los precios del menú activo entre los marcados para WhatsApp, y sin
--       los platos excluidos.
--
-- Precio: el del menú activo en el momento del pedido (igual que en la
-- mesa). El agente lo fija al añadir cada plato, así el resumen con el
-- total y el pedido final coinciden aunque entre medias empiece otro menú.
--
-- Ejecutar ANTES de reimportar el workflow de n8n que la usa.
-- Re-ejecutable. Ejecutar en staging y después en producción.
-- ============================================================================

alter table menus add column if not exists aplica_whatsapp boolean not null default false;

alter table menus drop constraint if exists menus_aplica_whatsapp_sin_zona;
alter table menus add constraint menus_aplica_whatsapp_sin_zona
  check (not aplica_whatsapp or zona is null);

-- p_whatsapp: solo los menús marcados para WhatsApp (que no tienen zona).
create or replace function fn_menu_activo(
  p_restaurant_id uuid,
  p_zona text default null,
  p_momento timestamp with time zone default now(),
  p_whatsapp boolean default false
)
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select m.id
  from menus m,
       lateral (select (p_momento at time zone 'Europe/Madrid') as local) l
  where m.restaurant_id = p_restaurant_id
    and m.activo = true
    and (m.zona is null or m.zona = p_zona)
    and (not p_whatsapp or m.aplica_whatsapp)
    and (
      m.hora_inicio is null or m.hora_fin is null or (
        case when m.hora_inicio <= m.hora_fin
          then l.local::time >= m.hora_inicio and l.local::time < m.hora_fin
          -- franja que cruza la medianoche (22:00-02:00)
          else l.local::time >= m.hora_inicio or l.local::time < m.hora_fin
        end
      )
    )
    and (
      m.dias_semana is null or array_length(m.dias_semana, 1) is null
      or extract(dow from l.local)::smallint = any(m.dias_semana)
    )
  order by
    (case when m.zona is not null then 1 else 0 end
     + case when m.hora_inicio is not null then 1 else 0 end
     + case when m.dias_semana is not null and array_length(m.dias_semana, 1) > 0 then 1 else 0 end) desc,
    m.orden asc
  limit 1
$$;

-- Misma forma que devolvía la consulta del agente a menu_items (id, nombre,
-- descripcion, precio, emoji, category_id, categories{nombre, orden}), más
-- el precio de carta y el nombre del menú aplicado.
create or replace function fn_carta_takeaway(
  p_restaurant_id uuid,
  p_momento timestamp with time zone default now()
)
returns table (
  id uuid,
  nombre text,
  descripcion text,
  precio numeric,
  precio_carta numeric,
  emoji text,
  category_id uuid,
  categories json,
  menu_nombre text
)
language sql
stable
security definer
set search_path to 'public'
as $$
  with activo as (
    select fn_menu_activo(p_restaurant_id, null, p_momento, true) as menu_id
  )
  select mi.id, mi.nombre, mi.descripcion,
         coalesce(mp.precio, mi.precio) as precio,
         mi.precio as precio_carta,
         mi.emoji, mi.category_id,
         case when c.id is null then null else json_build_object('nombre', c.nombre, 'orden', c.orden) end as categories,
         m.nombre as menu_nombre
  from menu_items mi
  cross join activo a
  left join menus m on m.id = a.menu_id
  left join categories c on c.id = mi.category_id
  left join menu_item_precios_menu mp on mp.menu_id = a.menu_id and mp.menu_item_id = mi.id
  where mi.restaurant_id = p_restaurant_id
    and mi.disponible = true
    and coalesce(mp.excluido, false) = false
  order by c.orden nulls last, mi.orden nulls last, mi.nombre
$$;

grant execute on function fn_menu_activo(uuid, text, timestamp with time zone, boolean) to anon, authenticated;
grant execute on function fn_carta_takeaway(uuid, timestamp with time zone) to anon, authenticated;

notify pgrst, 'reload schema';
