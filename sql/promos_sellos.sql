-- ============================================================================
-- Fidelización — tarjeta de sellos: "compra N de un producto y la
-- siguiente unidad (u otro producto) va gratis". Es un mecanismo
-- aparte de los puntos/niveles ya existentes, configurable por el
-- dueño: producto objetivo, cantidad objetivo, producto premio,
-- cantidad de premio y caducidad (o "nunca").
--
-- Se cuenta en el mismo momento que ya suma puntos (pedido de take
-- away entregado, o mesa cerrada) — no al confirmar el pedido — así
-- que el premio ganado se puede usar recién en la visita siguiente,
-- igual que ya pasa con los premios por puntos. Esto evita tocar
-- fn_registrar_pedido más que en la parte de canje (sin agregar ni
-- quitar parámetros — esa función ya tuvo bugs de sobrecarga antes).
-- ============================================================================

create table if not exists promos_sellos (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  nombre text not null,
  producto_objetivo_id uuid not null references menu_items(id) on delete cascade,
  cantidad_objetivo integer not null check (cantidad_objetivo > 0),
  producto_premio_id uuid not null references menu_items(id) on delete cascade,
  cantidad_premio integer not null default 1 check (cantidad_premio > 0),
  caducidad_dias integer check (caducidad_dias is null or caducidad_dias > 0), -- null = nunca vence
  activo boolean not null default true,
  orden integer not null default 0,
  created_at timestamp with time zone not null default now()
);

alter table promos_sellos enable row level security;
grant select, insert, update, delete on table promos_sellos to authenticated;

drop policy if exists promos_sellos_dueno on promos_sellos;
create policy promos_sellos_dueno on promos_sellos for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- Progreso por cliente y promoción. unidades_acumuladas es del ciclo
-- ACTUAL únicamente (ya sin contar los sellos de premios ya ganados);
-- fecha_inicio_ciclo marca cuándo arrancó ese ciclo para poder aplicar
-- la caducidad, y se limpia (null) cuando el ciclo está en cero.
create table if not exists clientes_sellos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references clientes(id) on delete cascade,
  promo_id uuid not null references promos_sellos(id) on delete cascade,
  unidades_acumuladas integer not null default 0,
  premios_disponibles integer not null default 0,
  fecha_inicio_ciclo timestamp with time zone,
  updated_at timestamp with time zone not null default now(),
  unique (cliente_id, promo_id)
);

alter table clientes_sellos enable row level security;
-- Solo lectura para el dueño (mismo patrón que clientes_movimientos) — la
-- escritura va exclusivamente por las funciones de abajo.
grant select on table clientes_sellos to authenticated;

drop policy if exists clientes_sellos_dueno on clientes_sellos;
create policy clientes_sellos_dueno on clientes_sellos for select
  using (
    cliente_id in (
      select c.id from clientes c
      join restaurants r on r.id = c.restaurant_id
      where r.user_id = auth.uid()
    )
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- Traza de qué línea de un pedido vino de canjear un premio por
-- sellos (mismo propósito que premio_canjeado_id, para distinguirla
-- en CuentaMesa/ticket) — separada porque no es una fila de
-- premios_fidelizacion.
alter table order_items
  add column if not exists promo_sello_id uuid references promos_sellos(id) on delete set null;

-- ============================================================================
-- Suma unidades de las promos activas de un restaurante para un
-- cliente, a partir de un conteo {menu_item_id: cantidad} ya armado
-- por quien la llama (el pedido de take away entregado, o el total de
-- una mesa cerrada). Si el ciclo actual venció según la caducidad
-- configurada, arranca de nuevo en cero antes de sumar.
-- ============================================================================
create or replace function fn_procesar_sellos(
  p_restaurant_id uuid,
  p_cliente_id uuid,
  p_conteo_productos jsonb
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_promo record;
  v_cantidad_pedida integer;
  v_progreso record;
  v_base integer;
  v_total integer;
  v_nuevos_premios integer;
  v_restante integer;
begin
  if p_cliente_id is null or p_conteo_productos is null or p_conteo_productos = '{}'::jsonb then
    return;
  end if;

  for v_promo in
    select * from promos_sellos
    where restaurant_id = p_restaurant_id and activo = true
  loop
    v_cantidad_pedida := coalesce((p_conteo_productos->>(v_promo.producto_objetivo_id::text))::integer, 0);
    if v_cantidad_pedida <= 0 then
      continue;
    end if;

    select * into v_progreso
    from clientes_sellos
    where cliente_id = p_cliente_id and promo_id = v_promo.id
    for update;

    if v_progreso.id is null then
      insert into clientes_sellos (cliente_id, promo_id)
      values (p_cliente_id, v_promo.id)
      returning * into v_progreso;
    end if;

    v_base := v_progreso.unidades_acumuladas;

    -- Caducidad: si el ciclo en curso venció sin llegar al objetivo, se
    -- descarta el progreso acumulado (no afecta a los premios ya ganados).
    if v_base > 0
       and v_promo.caducidad_dias is not null
       and v_progreso.fecha_inicio_ciclo is not null
       and v_progreso.fecha_inicio_ciclo < now() - (v_promo.caducidad_dias || ' days')::interval
    then
      v_base := 0;
    end if;

    v_total := v_base + v_cantidad_pedida;
    v_nuevos_premios := v_total / v_promo.cantidad_objetivo;
    v_restante := v_total % v_promo.cantidad_objetivo;

    update clientes_sellos
    set unidades_acumuladas = v_restante,
        premios_disponibles = premios_disponibles + v_nuevos_premios,
        fecha_inicio_ciclo = case
          when v_restante = 0 then null
          when v_base = 0 then now()
          else fecha_inicio_ciclo
        end,
        updated_at = now()
    where id = v_progreso.id;
  end loop;
end;
$$;

-- ============================================================================
-- fn_otorgar_puntos_fidelizacion / fn_otorgar_puntos_mesa: se agrega el
-- conteo de sellos, en el mismo trigger que ya otorga puntos y
-- actualiza gasto_acumulado/última_visita (base: crm_clientes.sql).
-- Mismos triggers, misma firma — solo se extiende el cuerpo.
-- ============================================================================
create or replace function fn_otorgar_puntos_fidelizacion()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_tasa numeric;
  v_puntos integer;
  v_cliente_id uuid;
  v_conteo jsonb;
begin
  if new.estado = 'entregado'
     and (old.estado is distinct from 'entregado')
     and new.tipo = 'takeaway'
     and new.cliente_telefono is not null
  then
    select coalesce((config->>'puntos_por_euro')::numeric, 1)
      into v_tasa
    from restaurants
    where id = new.restaurant_id;

    v_puntos := greatest(floor(coalesce(new.total, 0) * v_tasa), 0);

    insert into clientes (restaurant_id, telefono, nombre, puntos, gasto_acumulado, ultima_visita)
    values (new.restaurant_id, new.cliente_telefono, new.cliente_nombre, v_puntos, coalesce(new.total, 0), now())
    on conflict (restaurant_id, telefono) do update
      set puntos = clientes.puntos + v_puntos,
          gasto_acumulado = clientes.gasto_acumulado + coalesce(new.total, 0),
          ultima_visita = now(),
          nombre = coalesce(excluded.nombre, clientes.nombre),
          updated_at = now()
    returning id into v_cliente_id;

    if v_puntos > 0 then
      insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, order_id)
      values (v_cliente_id, 'suma', v_puntos, 'Pedido take away entregado', new.id);
    end if;

    select jsonb_object_agg(oi.menu_item_id::text, oi.cantidad_total)
      into v_conteo
    from (
      select menu_item_id, sum(cantidad) as cantidad_total
      from order_items
      where order_id = new.id and menu_item_id is not null and premio_canjeado_id is null and promo_sello_id is null
      group by menu_item_id
    ) oi;

    perform fn_procesar_sellos(new.restaurant_id, v_cliente_id, coalesce(v_conteo, '{}'::jsonb));
  end if;
  return new;
end;
$$;

create or replace function fn_otorgar_puntos_mesa()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_restaurant_id uuid;
  v_tasa numeric;
  v_puntos integer;
  v_cliente_id uuid;
  v_conteo jsonb;
begin
  if new.estado = 'cerrada'
     and (old.estado is distinct from 'cerrada')
     and new.cliente_telefono is not null
  then
    select restaurant_id into v_restaurant_id from table_sessions where id = new.id;

    select coalesce((config->>'puntos_por_euro')::numeric, 1)
      into v_tasa
    from restaurants
    where id = v_restaurant_id;

    v_puntos := greatest(floor(coalesce(new.total, 0) * v_tasa), 0);

    insert into clientes (restaurant_id, telefono, nombre, puntos, gasto_acumulado, ultima_visita)
    values (v_restaurant_id, new.cliente_telefono, new.cliente_nombre, v_puntos, coalesce(new.total, 0), now())
    on conflict (restaurant_id, telefono) do update
      set puntos = clientes.puntos + v_puntos,
          gasto_acumulado = clientes.gasto_acumulado + coalesce(new.total, 0),
          ultima_visita = now(),
          nombre = coalesce(excluded.nombre, clientes.nombre),
          updated_at = now()
    returning id into v_cliente_id;

    if v_puntos > 0 then
      insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, table_session_id)
      values (v_cliente_id, 'suma', v_puntos, 'Visita en mesa', new.id);
    end if;

    select jsonb_object_agg(oi.menu_item_id::text, oi.cantidad_total)
      into v_conteo
    from (
      select oi.menu_item_id, sum(oi.cantidad) as cantidad_total
      from order_items oi
      join orders o on o.id = oi.order_id
      where o.table_session_id = new.id
        and oi.menu_item_id is not null
        and oi.premio_canjeado_id is null
        and oi.promo_sello_id is null
      group by oi.menu_item_id
    ) oi;

    perform fn_procesar_sellos(v_restaurant_id, v_cliente_id, coalesce(v_conteo, '{}'::jsonb));
  end if;
  return new;
end;
$$;

-- ============================================================================
-- fn_estado_fidelizacion: se agregan los premios ganados por sellos a
-- la misma lista "premios" (con origen:'sello', sin costo_puntos —
-- Mesa.jsx/Camarero.jsx los habilita según premios_disponibles, no
-- según puntos), y un array aparte "sellos_progreso" con el avance de
-- cada promo activa (se muestre o no premios disponibles todavía).
-- ============================================================================
create or replace function fn_estado_fidelizacion(p_restaurant_id uuid, p_telefono text)
returns json
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_puntos integer := 0;
  v_gasto numeric := 0;
  v_cliente_id uuid;
  v_nivel_actual json;
  v_proximo_nivel json;
  v_premios_puntos json;
  v_premios_sellos json;
  v_sellos_progreso json;
begin
  select id, coalesce(puntos, 0), coalesce(gasto_acumulado, 0)
    into v_cliente_id, v_puntos, v_gasto
  from clientes
  where restaurant_id = p_restaurant_id and telefono = p_telefono;

  v_puntos := coalesce(v_puntos, 0);
  v_gasto := coalesce(v_gasto, 0);

  select json_build_object('id', id, 'nombre', nombre, 'umbral_gasto', umbral_gasto)
    into v_nivel_actual
  from niveles_fidelizacion
  where restaurant_id = p_restaurant_id and umbral_gasto <= v_gasto
  order by umbral_gasto desc
  limit 1;

  select json_build_object('id', id, 'nombre', nombre, 'umbral_gasto', umbral_gasto)
    into v_proximo_nivel
  from niveles_fidelizacion
  where restaurant_id = p_restaurant_id and umbral_gasto > v_gasto
  order by umbral_gasto asc
  limit 1;

  select coalesce(json_agg(json_build_object(
      'id', p.id,
      'origen', 'puntos',
      'nombre', p.nombre,
      'descripcion', p.descripcion,
      'costo_puntos', p.costo_puntos,
      'tipo', p.tipo,
      'menu_item_nombre', mi.nombre,
      'descuento_importe', p.descuento_importe,
      'disponible', (p.costo_puntos <= v_puntos)
    ) order by p.costo_puntos), '[]'::json)
    into v_premios_puntos
  from premios_fidelizacion p
  left join menu_items mi on mi.id = p.menu_item_id
  where p.restaurant_id = p_restaurant_id
    and p.activo = true
    and (
      p.nivel_minimo_id is null
      or exists (
        select 1 from niveles_fidelizacion nm
        where nm.id = p.nivel_minimo_id and nm.umbral_gasto <= v_gasto
      )
    );

  select coalesce(json_agg(json_build_object(
      'id', ps.id,
      'origen', 'sello',
      'nombre', ps.nombre,
      'descripcion', null,
      'costo_puntos', 0,
      'tipo', 'plato_gratis',
      'menu_item_nombre', mp.nombre,
      'cantidad_premio', ps.cantidad_premio,
      'premios_disponibles', cs.premios_disponibles,
      'disponible', true
    ) order by ps.orden), '[]'::json)
    into v_premios_sellos
  from promos_sellos ps
  join clientes_sellos cs on cs.promo_id = ps.id and cs.cliente_id = v_cliente_id
  join menu_items mp on mp.id = ps.producto_premio_id
  where ps.restaurant_id = p_restaurant_id
    and ps.activo = true
    and cs.premios_disponibles > 0;

  select coalesce(json_agg(json_build_object(
      'id', ps.id,
      'nombre', ps.nombre,
      'producto_objetivo_nombre', mo.nombre,
      'producto_premio_nombre', mp.nombre,
      'cantidad_objetivo', ps.cantidad_objetivo,
      'cantidad_premio', ps.cantidad_premio,
      'unidades_acumuladas', coalesce(cs.unidades_acumuladas, 0)
    ) order by ps.orden), '[]'::json)
    into v_sellos_progreso
  from promos_sellos ps
  join menu_items mo on mo.id = ps.producto_objetivo_id
  join menu_items mp on mp.id = ps.producto_premio_id
  left join clientes_sellos cs on cs.promo_id = ps.id and cs.cliente_id = v_cliente_id
  where ps.restaurant_id = p_restaurant_id and ps.activo = true;

  return json_build_object(
    'puntos', v_puntos,
    'gasto_acumulado', v_gasto,
    'nivel_actual', v_nivel_actual,
    'proximo_nivel', v_proximo_nivel,
    'premios', (
      select coalesce(json_agg(elem), '[]'::json)
      from (
        select json_array_elements(v_premios_puntos) as elem
        union all
        select json_array_elements(v_premios_sellos) as elem
      ) t
    ),
    'sellos_progreso', v_sellos_progreso
  );
end;
$$;

grant execute on function fn_estado_fidelizacion(uuid, text) to anon, authenticated;

-- ============================================================================
-- fn_registrar_pedido: se agrega la rama de canje de premios por
-- sellos dentro del mismo loop de "Canje de premios" — cada elemento
-- de p_premios_canjeados puede traer "origen":"sello" (si no lo trae,
-- se asume "puntos", el comportamiento de siempre). Misma firma de
-- siempre (7 parámetros) — solo cambia el cuerpo.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_registrar_pedido(
  p_table_session_id uuid,
  p_items jsonb,
  p_notas text DEFAULT NULL::text,
  p_camarero_id uuid DEFAULT NULL::uuid,
  p_premios_canjeados jsonb DEFAULT '[]'::jsonb,
  p_vale_codigo text DEFAULT NULL::text,
  p_vale_importe numeric DEFAULT NULL::numeric
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
  v_vale                 record;
  v_promo_sello           record;
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
  -- insuficientes, nivel no alcanzado, sin premios de sello
  -- disponibles) todo el pedido se cancele en vez de dejar canjes a
  -- medias.
  for v_premio_item in select * from jsonb_array_elements(p_premios_canjeados)
  loop
    if v_cliente_telefono is null then
      raise exception 'No hay un cliente asociado a esta mesa para canjear premios';
    end if;

    select id, puntos, gasto_acumulado into v_cliente_id, v_cliente_puntos, v_cliente_gasto
    from clientes
    where restaurant_id = v_restaurant_id and telefono = v_cliente_telefono;

    -- ---- Premio ganado por sellos (tarjeta de "compra N, la siguiente gratis") ----
    if coalesce(v_premio_item->>'origen', 'puntos') = 'sello' then
      select ps.id, ps.nombre, ps.producto_premio_id, ps.cantidad_premio
        into v_promo_sello
      from promos_sellos ps
      where ps.id = (v_premio_item->>'premio_id')::uuid
        and ps.restaurant_id = v_restaurant_id
        and ps.activo = true;

      if v_promo_sello.id is null then
        raise exception 'Esa promoción ya no está disponible';
      end if;

      if v_cliente_id is null then
        raise exception 'No hay un cliente asociado a esta mesa para canjear premios';
      end if;

      update clientes_sellos
      set premios_disponibles = premios_disponibles - 1, updated_at = now()
      where cliente_id = v_cliente_id and promo_id = v_promo_sello.id and premios_disponibles > 0;

      if not found then
        raise exception 'No tienes premios disponibles para "%"', v_promo_sello.nombre;
      end if;

      v_comensal_premio := nullif(v_premio_item->>'comensal', '')::int;

      select nombre, precio_costo into v_menu_item
      from menu_items where id = v_promo_sello.producto_premio_id;

      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, promo_sello_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, v_promo_sello.producto_premio_id, v_menu_item.nombre, 0, v_menu_item.precio_costo, v_promo_sello.cantidad_premio,
        'Premio por sellos: ' || v_promo_sello.nombre, v_comensal_premio, v_promo_sello.id, now(), v_restaurant_id
      );

      if v_control_stock_activo then
        for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_promo_sello.producto_premio_id
        loop
          update ingredientes set stock_actual = stock_actual - (v_receta.cantidad * v_promo_sello.cantidad_premio) where id = v_receta.ingrediente_id;
          insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
          values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -(v_receta.cantidad * v_promo_sello.cantidad_premio), v_order_id);
        end loop;
      end if;

      continue;
    end if;

    -- ---- Premio por puntos (como siempre) ----
    select id, nombre, tipo, costo_puntos, menu_item_id, descuento_importe, nivel_minimo_id
      into v_premio
    from premios_fidelizacion
    where id = (v_premio_item->>'premio_id')::uuid
      and restaurant_id = v_restaurant_id
      and activo = true;

    if v_premio.id is null then
      raise exception 'Ese premio ya no está disponible';
    end if;

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

  -- Vale regalo: se bloquea la fila para que no se pueda gastar el
  -- mismo saldo dos veces en simultáneo desde mesas distintas.
  if p_vale_codigo is not null and p_vale_importe is not null and p_vale_importe > 0 then
    select id, saldo_actual, activo, fecha_vencimiento into v_vale
    from vales_regalo
    where restaurant_id = v_restaurant_id and upper(codigo) = upper(p_vale_codigo)
    for update;

    if v_vale.id is null then
      raise exception 'Ese vale no existe';
    end if;
    if not v_vale.activo then
      raise exception 'Ese vale ya no está activo';
    end if;
    if v_vale.fecha_vencimiento < current_date then
      raise exception 'Ese vale ya venció';
    end if;
    if p_vale_importe > v_vale.saldo_actual then
      raise exception 'El vale no tiene saldo suficiente';
    end if;

    update vales_regalo set saldo_actual = saldo_actual - p_vale_importe where id = v_vale.id;

    insert into vale_movimientos (vale_id, importe, order_id)
    values (v_vale.id, -p_vale_importe, v_order_id);

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, cantidad, notas, agregado_at, restaurant_id
    )
    values (
      v_order_id, null, 'Vale regalo: ' || upper(p_vale_codigo), -p_vale_importe, 1, null, now(), v_restaurant_id
    );
  end if;

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
