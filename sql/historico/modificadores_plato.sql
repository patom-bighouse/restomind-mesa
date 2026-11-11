-- ============================================================================
-- Modificadores de plato: grupos de opciones (ej: "Punto de cocción",
-- "Tamaño") reutilizables por nombre en toda la carta del restaurante,
-- pero con precio extra específico por plato.
-- ============================================================================

-- 1) Catálogo de grupos, reutilizable por nombre dentro del restaurante
create table if not exists modificador_grupos (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  nombre text not null,
  orden integer not null default 0,
  created_at timestamp with time zone not null default now()
);

-- 2) Opciones de cada grupo (ej: "Poco hecho", "Al punto", "Muy hecho")
create table if not exists modificador_opciones (
  id uuid primary key default gen_random_uuid(),
  grupo_id uuid not null references modificador_grupos(id) on delete cascade,
  nombre text not null,
  orden integer not null default 0
);

-- 3) Qué grupos aplica cada plato, y CÓMO se comporta ese grupo en ESE
-- plato en particular (obligatorio, selección única o múltiple) — esto
-- no es una propiedad del grupo, sino de su uso en ese plato.
create table if not exists menu_item_modificador_grupos (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references menu_items(id) on delete cascade,
  grupo_id uuid not null references modificador_grupos(id) on delete cascade,
  obligatorio boolean not null default false,
  tipo_seleccion text not null default 'unica' check (tipo_seleccion in ('unica', 'multiple')),
  orden integer not null default 0,
  unique (menu_item_id, grupo_id)
);

-- 4) Precio extra de cada opción, específico por plato. Si no existe
-- fila para una combinación (menu_item_id, opcion_id), el recargo es
-- 0€ — no hace falta cargar precio en las opciones que no cuestan
-- extra. AdminCarta crea estas filas en 0 automáticamente al asignar
-- un grupo a un plato, y el dueño edita las que sí llevan recargo.
create table if not exists menu_item_modificador_precios (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references menu_items(id) on delete cascade,
  opcion_id uuid not null references modificador_opciones(id) on delete cascade,
  precio_extra numeric not null default 0,
  unique (menu_item_id, opcion_id)
);

-- 5) Snapshot de qué se eligió realmente en cada línea de pedido —
-- mismo patrón que precio_snapshot: el nombre y el precio quedan
-- "congelados" en el momento de la venta, sin importar si después se
-- edita o borra el modificador desde AdminCarta.
create table if not exists order_item_modificadores (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references order_items(id) on delete cascade,
  grupo_id uuid references modificador_grupos(id) on delete set null,
  opcion_id uuid references modificador_opciones(id) on delete set null,
  grupo_nombre text not null,
  opcion_nombre text not null,
  precio_extra numeric not null default 0
);

-- ============================================================================
-- RLS: mismo patrón que sectores_cocina — solo el dueño (o superadmin)
-- gestiona el catálogo; lectura pública para que Mesa.jsx y Camarero.jsx
-- puedan mostrar los modificadores sin login.
-- ============================================================================

alter table modificador_grupos enable row level security;
alter table modificador_opciones enable row level security;
alter table menu_item_modificador_grupos enable row level security;
alter table menu_item_modificador_precios enable row level security;
alter table order_item_modificadores enable row level security;

grant select, insert, update, delete on table modificador_grupos to authenticated;
grant select, insert, update, delete on table modificador_opciones to authenticated;
grant select, insert, update, delete on table menu_item_modificador_grupos to authenticated;
grant select, insert, update, delete on table menu_item_modificador_precios to authenticated;
grant select, insert on table order_item_modificadores to authenticated;
grant select on table order_item_modificadores to anon;

grant select on table modificador_grupos to anon;
grant select on table modificador_opciones to anon;
grant select on table menu_item_modificador_grupos to anon;
grant select on table menu_item_modificador_precios to anon;

drop policy if exists modificador_grupos_dueno on modificador_grupos;
create policy modificador_grupos_dueno on modificador_grupos for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

drop policy if exists modificador_grupos_select_publico on modificador_grupos;
create policy modificador_grupos_select_publico on modificador_grupos for select using (true);

drop policy if exists modificador_opciones_dueno on modificador_opciones;
create policy modificador_opciones_dueno on modificador_opciones for all
  using (
    grupo_id in (
      select mg.id from modificador_grupos mg
      join restaurants r on r.id = mg.restaurant_id
      where r.user_id = auth.uid()
    )
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

drop policy if exists modificador_opciones_select_publico on modificador_opciones;
create policy modificador_opciones_select_publico on modificador_opciones for select using (true);

drop policy if exists menu_item_modificador_grupos_dueno on menu_item_modificador_grupos;
create policy menu_item_modificador_grupos_dueno on menu_item_modificador_grupos for all
  using (
    menu_item_id in (
      select mi.id from menu_items mi
      join restaurants r on r.id = mi.restaurant_id
      where r.user_id = auth.uid()
    )
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

drop policy if exists menu_item_modificador_grupos_select_publico on menu_item_modificador_grupos;
create policy menu_item_modificador_grupos_select_publico on menu_item_modificador_grupos for select using (true);

drop policy if exists menu_item_modificador_precios_dueno on menu_item_modificador_precios;
create policy menu_item_modificador_precios_dueno on menu_item_modificador_precios for all
  using (
    menu_item_id in (
      select mi.id from menu_items mi
      join restaurants r on r.id = mi.restaurant_id
      where r.user_id = auth.uid()
    )
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

drop policy if exists menu_item_modificador_precios_select_publico on menu_item_modificador_precios;
create policy menu_item_modificador_precios_select_publico on menu_item_modificador_precios for select using (true);

drop policy if exists order_item_modificadores_por_restaurante on order_item_modificadores;
create policy order_item_modificadores_por_restaurante on order_item_modificadores for all
  using (
    order_item_id in (
      select oi.id from order_items oi
      join orders o on o.id = oi.order_id
      join restaurants r on r.id = o.restaurant_id
      where r.user_id = auth.uid()
    )
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- Nota: NO se agrega una política de INSERT pública para clientes
-- anónimos. La inserción real ocurre dentro de fn_registrar_pedido
-- (más abajo), que corre como security definer y por lo tanto no
-- necesita permiso de RLS propio — mantiene la creación de order_items
-- y sus modificadores como una única operación atómica, igual que ya
-- pasa hoy con order_items.

-- ============================================================================
-- fn_registrar_pedido actualizada: ahora recibe también los
-- modificadores elegidos por ítem, y los inserta junto con cada línea
-- de order_items, todo en la misma transacción. Cambia de un INSERT
-- masivo (set-based) a un loop, porque necesitamos el id generado de
-- cada order_item para poder asociarle sus modificadores.
--
-- Formato esperado de p_items (cada elemento):
-- {
--   "menu_item_id": "uuid",
--   "cantidad": 2,
--   "notas": "sin cebolla" | null,
--   "modificadores": [
--     { "grupo_id": "uuid", "opcion_id": "uuid" }
--   ]
-- }
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_registrar_pedido(
  p_table_session_id uuid,
  p_items jsonb,
  p_notas text DEFAULT NULL::text,
  p_camarero_id uuid DEFAULT NULL::uuid
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_restaurant_id  uuid;
  v_table_id       uuid;
  v_modo_cocina    text;
  v_minutos_limite int;
  v_order_id       uuid;
  v_notas_actual   text;
  v_item           jsonb;
  v_mod            jsonb;
  v_menu_item      record;
  v_order_item_id  uuid;
  v_extra          numeric;
  v_opcion_nombre  text;
  v_grupo_nombre   text;
begin
  perform pg_advisory_xact_lock(hashtext(p_table_session_id::text));

  select ts.restaurant_id, ts.table_id, r.modo_cocina, r.minutos_limite_agrupado
    into v_restaurant_id, v_table_id, v_modo_cocina, v_minutos_limite
  from table_sessions ts
  join restaurants r on r.id = ts.restaurant_id
  where ts.id = p_table_session_id
    and ts.estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa % no existe o ya está cerrada', p_table_session_id;
  end if;

  if v_modo_cocina = 'agrupado_mesa' then
    select id into v_order_id
    from orders
    where table_session_id = p_table_session_id
      and estado = 'pendiente'
      and created_at > now() - (v_minutos_limite || ' minutes')::interval
    order by created_at desc
    limit 1;
  end if;

  if v_order_id is null then
    insert into orders (restaurant_id, table_id, table_session_id, tipo, estado, notas, tomado_por)
    values (v_restaurant_id, v_table_id, p_table_session_id, 'mesa', 'pendiente', p_notas, p_camarero_id)
    returning id into v_order_id;
  elsif p_notas is not null and length(trim(p_notas)) > 0 then
    select notas into v_notas_actual from orders where id = v_order_id;
    if v_notas_actual is null or length(trim(v_notas_actual)) = 0 then
      update orders set notas = p_notas where id = v_order_id;
    elsif position(p_notas in v_notas_actual) = 0 then
      update orders set notas = v_notas_actual || ' · ' || p_notas where id = v_order_id;
    end if;
  end if;

  -- Loop por cada ítem del pedido (antes era un INSERT ... SELECT
  -- masivo; ahora hace falta el id de cada order_item para poder
  -- asociarle sus modificadores).
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, nombre, precio, precio_costo into v_menu_item
    from menu_items
    where id = (v_item->>'menu_item_id')::uuid;

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, agregado_at, restaurant_id
    )
    values (
      v_order_id,
      v_menu_item.id,
      v_menu_item.nombre,
      v_menu_item.precio,
      v_menu_item.precio_costo,
      (v_item->>'cantidad')::int,
      v_item->>'notas',
      now(),
      v_restaurant_id
    )
    returning id into v_order_item_id;

    -- Modificadores elegidos para este ítem (si los hay)
    if v_item ? 'modificadores' then
      for v_mod in select * from jsonb_array_elements(v_item->'modificadores')
      loop
        select nombre into v_grupo_nombre from modificador_grupos where id = (v_mod->>'grupo_id')::uuid;
        select nombre into v_opcion_nombre from modificador_opciones where id = (v_mod->>'opcion_id')::uuid;

        select coalesce(precio_extra, 0) into v_extra
        from menu_item_modificador_precios
        where menu_item_id = v_menu_item.id
          and opcion_id = (v_mod->>'opcion_id')::uuid;

        insert into order_item_modificadores (
          order_item_id, grupo_id, opcion_id, grupo_nombre, opcion_nombre, precio_extra
        )
        values (
          v_order_item_id,
          (v_mod->>'grupo_id')::uuid,
          (v_mod->>'opcion_id')::uuid,
          coalesce(v_grupo_nombre, ''),
          coalesce(v_opcion_nombre, ''),
          coalesce(v_extra, 0)
        );
      end loop;
    end if;
  end loop;

  -- El trigger trg_recalc_order_total sigue sumando order_items.precio_snapshot,
  -- pero eso NO incluye el recargo de los modificadores — hay que
  -- sumarlo aparte al total del pedido después del loop.
  update orders o
  set total = coalesce((
    select sum(oi.precio_snapshot * oi.cantidad) + coalesce((
      select sum(oim.precio_extra) from order_item_modificadores oim
      join order_items oi2 on oi2.id = oim.order_item_id
      where oi2.order_id = o.id
    ), 0)
    from order_items oi where oi.order_id = o.id
  ), 0)
  where o.id = v_order_id;

  return v_order_id;
end;
$function$
