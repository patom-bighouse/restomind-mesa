-- ============================================================================
-- Control de stock por ingrediente: cada plato puede tener una receta
-- (qué ingredientes y en qué cantidad lleva); al confirmarse un pedido
-- se descuenta el stock solo, con un historial de movimientos
-- (venta/merma/reposición/ajuste) para poder ver después por qué se
-- acabó algo, no solo el número actual.
--
-- Dos capas de activación, a pedido del dueño de la plataforma:
--   1) El módulo "control_stock" (restaurant_modulos) — si el
--      restaurante lo tiene pagado/activado desde SuperAdmin.
--   2) Un toggle propio del restaurante en Configuración
--      (restaurants.config.control_stock_activo) — puede tener el
--      módulo pagado pero no querer usarlo activamente. El descuento
--      automático en fn_registrar_pedido solo corre si las dos están
--      en true; la gestión de ingredientes/recetas en el panel solo
--      depende de tener el módulo, para poder configurarlas de
--      antemano sin que ya estén descontando stock en vivo.
-- ============================================================================

insert into modulos (key, nombre, descripcion, requiere, orden) values
  ('control_stock', 'Control de stock', 'Lleva el stock de tus ingredientes: se descuenta solo con cada pedido, con alertas de bajo stock y registro de mermas.', 'nucleo', 7)
on conflict (key) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  requiere = excluded.requiere,
  orden = excluded.orden;

create table ingredientes (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  nombre text not null,
  unidad text not null default 'unidad' check (unidad in ('kg', 'g', 'l', 'ml', 'unidad')),
  stock_actual numeric not null default 0,
  umbral_alerta numeric,
  activo boolean not null default true,
  created_at timestamp with time zone not null default now()
);

alter table ingredientes enable row level security;
grant select, insert, update, delete on table ingredientes to authenticated;

drop policy if exists ingredientes_dueno on ingredientes;
create policy ingredientes_dueno on ingredientes for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- Qué ingredientes (y en qué cantidad, en la unidad del ingrediente)
-- lleva un plato. Sin filas acá, ese plato simplemente no descuenta
-- nada al venderse.
create table receta_items (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references menu_items(id) on delete cascade,
  ingrediente_id uuid not null references ingredientes(id) on delete cascade,
  cantidad numeric not null check (cantidad > 0),
  unique (menu_item_id, ingrediente_id)
);

alter table receta_items enable row level security;
grant select, insert, update, delete on table receta_items to authenticated;

drop policy if exists receta_items_dueno on receta_items;
create policy receta_items_dueno on receta_items for all
  using (
    exists (
      select 1 from menu_items mi
      join restaurants r on r.id = mi.restaurant_id
      where mi.id = receta_items.menu_item_id
        and (r.user_id = auth.uid() or exists (select 1 from superadmins s where s.user_id = auth.uid()))
    )
  );

create table stock_movimientos (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  ingrediente_id uuid not null references ingredientes(id) on delete cascade,
  tipo text not null check (tipo in ('venta', 'merma', 'reposicion', 'ajuste')),
  cantidad numeric not null, -- negativo = salida (venta/merma), positivo = entrada (reposición/ajuste al alza)
  motivo text,
  order_id uuid references orders(id) on delete set null,
  created_at timestamp with time zone not null default now()
);

alter table stock_movimientos enable row level security;
grant select, insert on table stock_movimientos to authenticated;

drop policy if exists stock_movimientos_dueno on stock_movimientos;
create policy stock_movimientos_dueno on stock_movimientos for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- ============================================================================
-- fn_registrar_pedido: se agrega el descuento automático de stock. Al
-- ser SECURITY DEFINER, escribe en ingredientes/stock_movimientos sin
-- necesitar que anon tenga permiso directo sobre esas tablas — mismo
-- patrón que el resto de esta función.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_registrar_pedido(
  p_table_session_id uuid,
  p_items jsonb,
  p_notas text DEFAULT NULL::text,
  p_camarero_id uuid DEFAULT NULL::uuid,
  p_premios_canjeados jsonb DEFAULT '[]'::jsonb
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_restaurant_id     uuid;
  v_table_id          uuid;
  v_modo_cocina       text;
  v_minutos_limite    int;
  v_cliente_telefono  text;
  v_restaurant_config jsonb;
  v_control_stock_activo boolean;
  v_order_id          uuid;
  v_notas_actual      text;
  v_item              jsonb;
  v_mod                jsonb;
  v_menu_item          record;
  v_order_item_id      uuid;
  v_extra              numeric;
  v_opcion_nombre      text;
  v_grupo_nombre       text;
  v_premio_item        jsonb;
  v_premio             record;
  v_cliente_id         uuid;
  v_cliente_puntos     integer;
  v_cliente_gasto      numeric;
  v_comensal_premio    int;
  v_zona                text;
  v_menu_activo_id      uuid;
  v_precio_override     numeric;
  v_receta              record;
  v_cantidad_pedida      int;
begin
  perform pg_advisory_xact_lock(hashtext(p_table_session_id::text));

  select ts.restaurant_id, ts.table_id, r.modo_cocina, r.minutos_limite_agrupado, ts.cliente_telefono, r.config
    into v_restaurant_id, v_table_id, v_modo_cocina, v_minutos_limite, v_cliente_telefono, v_restaurant_config
  from table_sessions ts
  join restaurants r on r.id = ts.restaurant_id
  where ts.id = p_table_session_id
    and ts.estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa % no existe o ya está cerrada', p_table_session_id;
  end if;

  v_control_stock_activo := coalesce((v_restaurant_config->>'control_stock_activo')::boolean, false);

  select zona into v_zona from tables where id = v_table_id;

  -- Menú activo para esta mesa ahora mismo: más específico gana
  -- (zona+hora+días > menos criterios), igual que en el frontend.
  select m.id into v_menu_activo_id
  from menus m
  where m.restaurant_id = v_restaurant_id
    and m.activo = true
    and (m.zona is null or m.zona = v_zona)
    and (
      m.hora_inicio is null or m.hora_fin is null or (
        case when m.hora_inicio <= m.hora_fin
          then current_time >= m.hora_inicio and current_time < m.hora_fin
          else current_time >= m.hora_inicio or current_time < m.hora_fin
        end
      )
    )
    and (
      m.dias_semana is null or array_length(m.dias_semana, 1) is null
      or extract(dow from now())::smallint = any(m.dias_semana)
    )
  order by
    (case when m.zona is not null then 1 else 0 end
     + case when m.hora_inicio is not null then 1 else 0 end
     + case when m.dias_semana is not null and array_length(m.dias_semana, 1) > 0 then 1 else 0 end) desc,
    m.orden asc
  limit 1;

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

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, nombre, precio, precio_costo into v_menu_item
    from menu_items
    where id = (v_item->>'menu_item_id')::uuid;

    v_precio_override := null;
    if v_menu_activo_id is not null then
      select precio into v_precio_override
      from menu_item_precios_menu
      where menu_id = v_menu_activo_id
        and menu_item_id = v_menu_item.id
        and excluido = false;
    end if;

    v_cantidad_pedida := (v_item->>'cantidad')::int;

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, agregado_at, restaurant_id
    )
    values (
      v_order_id,
      v_menu_item.id,
      v_menu_item.nombre,
      coalesce(v_precio_override, v_menu_item.precio),
      v_menu_item.precio_costo,
      v_cantidad_pedida,
      v_item->>'notas',
      nullif(v_item->>'comensal', '')::int,
      now(),
      v_restaurant_id
    )
    returning id into v_order_item_id;

    if v_control_stock_activo then
      for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_menu_item.id
      loop
        update ingredientes
        set stock_actual = stock_actual - (v_receta.cantidad * v_cantidad_pedida)
        where id = v_receta.ingrediente_id;

        insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
        values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -(v_receta.cantidad * v_cantidad_pedida), v_order_id);
      end loop;
    end if;

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

  -- Canje de premios: uno por uno, para que si alguno falla (puntos
  -- insuficientes, nivel no alcanzado) todo el pedido se cancele en
  -- vez de dejar canjes a medias.
  for v_premio_item in select * from jsonb_array_elements(p_premios_canjeados)
  loop
    if v_cliente_telefono is null then
      raise exception 'No hay un cliente asociado a esta mesa para canjear premios';
    end if;

    select id, nombre, tipo, costo_puntos, menu_item_id, descuento_importe, nivel_minimo_id
      into v_premio
    from premios_fidelizacion
    where id = (v_premio_item->>'premio_id')::uuid
      and restaurant_id = v_restaurant_id
      and activo = true;

    if v_premio.id is null then
      raise exception 'Ese premio ya no está disponible';
    end if;

    select id, puntos, gasto_acumulado into v_cliente_id, v_cliente_puntos, v_cliente_gasto
    from clientes
    where restaurant_id = v_restaurant_id and telefono = v_cliente_telefono;

    if v_cliente_id is null or coalesce(v_cliente_puntos, 0) < v_premio.costo_puntos then
      raise exception 'No hay puntos suficientes para canjear "%"', v_premio.nombre;
    end if;

    if v_premio.nivel_minimo_id is not null and not exists (
      select 1 from niveles_fidelizacion nm
      where nm.id = v_premio.nivel_minimo_id and nm.umbral_gasto <= coalesce(v_cliente_gasto, 0)
    ) then
      raise exception 'Todavía no alcanzas el nivel necesario para "%"', v_premio.nombre;
    end if;

    update clientes set puntos = puntos - v_premio.costo_puntos, updated_at = now() where id = v_cliente_id;

    insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, order_id)
    values (v_cliente_id, 'resta', v_premio.costo_puntos, 'Canje: ' || v_premio.nombre, v_order_id);

    v_comensal_premio := nullif(v_premio_item->>'comensal', '')::int;

    if v_premio.tipo = 'plato_gratis' then
      select nombre, precio_costo into v_menu_item
      from menu_items where id = v_premio.menu_item_id;

      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, premio_canjeado_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, v_premio.menu_item_id, v_menu_item.nombre, 0, v_menu_item.precio_costo, 1,
        'Canjeado con puntos', v_comensal_premio, v_premio.id, now(), v_restaurant_id
      );

      if v_control_stock_activo then
        for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_premio.menu_item_id
        loop
          update ingredientes set stock_actual = stock_actual - v_receta.cantidad where id = v_receta.ingrediente_id;
          insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
          values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -v_receta.cantidad, v_order_id);
        end loop;
      end if;
    else
      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, cantidad, notas, comensal, premio_canjeado_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, null, 'Descuento fidelización: ' || v_premio.nombre, -v_premio.descuento_importe, 1,
        null, v_comensal_premio, v_premio.id, now(), v_restaurant_id
      );
    end if;
  end loop;

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
$function$;
