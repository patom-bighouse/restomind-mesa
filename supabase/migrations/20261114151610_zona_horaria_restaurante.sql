-- =============================================================================
-- Zona horaria por restaurante (fase 1, BD)
-- Especificación: docs/specs/2026-11-14-zona-horaria-restaurante.md
--
-- NO TOCA DATOS: todos los restaurantes quedan en 'Europe/Madrid' (mismo
-- comportamiento que hoy). Añade:
--   1. restaurants.zona_horaria text not null default 'Europe/Madrid'
--      ("zona" ya es la zona del salón: aquí siempre zona_horaria).
--   2. Trigger fn_restaurants_validar_zona_horaria: solo zonas IANA de
--      pg_timezone_names con región (Europe/, America/, Atlantic/…). Fuera CET,
--      UTC, Etc/GMT+3, posix/…, ''. Error 22023 "Zona horaria no válida: …".
--      Se dispara después de fn_restaurants_proteger_comercial (orden
--      alfabético de los triggers: "proteger" < "validar").
--   3. Funciones de ayuda fn_zona_restaurante, fn_ahora_restaurante y
--      fn_hoy_restaurante (stable, security invoker, solo service_role y
--      postgres: grupo C de permisos_funciones.sql; las llaman las funciones
--      SECURITY DEFINER de abajo, que corren como postgres).
--   4. Las 12 funciones de operativa del inventario cambian fn_*_madrid() y
--      'Europe/Madrid' por la zona del restaurante, con la misma firma (los
--      grants se conservan con create or replace). Cuerpos copiados de su
--      versión vigente; solo cambian las líneas de la hora.
--      fn_restaurants_proteger_comercial conserva zona_horaria si quien
--      actualiza no es superadmin (decisión 1).
--   5. grant select (zona_horaria) on restaurants to anon (web de reservas,
--      mesa, camarero y cocina).
-- Lo de negocio de Restomind (fn_ahora_madrid, fn_hoy_madrid, pruebas,
-- permanencia, CRM, estadísticas del superadmin) no cambia.
-- Idempotente.
-- =============================================================================

-- 1. Columna --------------------------------------------------------------------
alter table public.restaurants
  add column if not exists zona_horaria text not null default 'Europe/Madrid';

comment on column public.restaurants.zona_horaria is
  'Zona horaria IANA del restaurante (Europe/Madrid, Atlantic/Canary…). Solo la cambia el superadmin. Para la operativa: reservas, recogidas, menús, vales, cierre de caja y agente.';

-- 2. Validación -----------------------------------------------------------------
create or replace function public.fn_restaurants_validar_zona_horaria()
  returns trigger
  language plpgsql
  set search_path = public
as $function$
begin
  if new.zona_horaria is null
     or new.zona_horaria !~ '^(Africa|America|Antarctica|Asia|Atlantic|Australia|Europe|Indian|Pacific)/[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$'
     or not exists (select 1 from pg_timezone_names t where t.name = new.zona_horaria) then
    raise exception 'Zona horaria no válida: %', coalesce(nullif(new.zona_horaria, ''), '(vacía)')
      using errcode = '22023';
  end if;
  return new;
end;
$function$;

revoke all on function public.fn_restaurants_validar_zona_horaria() from public, anon, authenticated, service_role;

drop trigger if exists trg_restaurants_validar_zona_horaria on public.restaurants;
create trigger trg_restaurants_validar_zona_horaria
  before insert or update of zona_horaria on public.restaurants
  for each row
  execute function public.fn_restaurants_validar_zona_horaria();

-- 3. Funciones de ayuda ------------------------------------------------------------
-- Zona del restaurante; 'Europe/Madrid' si no existe.
create or replace function public.fn_zona_restaurante(p_restaurant_id uuid)
  returns text
  language sql
  stable
  security invoker
  set search_path = public
as $function$
  select coalesce((select nullif(r.zona_horaria, '') from restaurants r where r.id = p_restaurant_id), 'Europe/Madrid')
$function$;

-- Hora de pared del restaurante (como fn_ahora_madrid).
create or replace function public.fn_ahora_restaurante(p_restaurant_id uuid)
  returns timestamp without time zone
  language sql
  stable
  security invoker
  set search_path = public
as $function$
  select now() at time zone fn_zona_restaurante(p_restaurant_id)
$function$;

-- "Hoy" del restaurante (como fn_hoy_madrid).
create or replace function public.fn_hoy_restaurante(p_restaurant_id uuid)
  returns date
  language sql
  stable
  security invoker
  set search_path = public
as $function$
  select (now() at time zone fn_zona_restaurante(p_restaurant_id))::date
$function$;

revoke all on function public.fn_zona_restaurante(uuid) from public, anon, authenticated;
revoke all on function public.fn_ahora_restaurante(uuid) from public, anon, authenticated;
revoke all on function public.fn_hoy_restaurante(uuid) from public, anon, authenticated;
grant execute on function public.fn_zona_restaurante(uuid) to service_role;
grant execute on function public.fn_ahora_restaurante(uuid) to service_role;
grant execute on function public.fn_hoy_restaurante(uuid) to service_role;

-- 4. Funciones de operativa (misma firma y grants) -----------------------------------
-- 4.1. fn_menu_activo: franja y día de la semana en la hora del restaurante. La usan fn_registrar_pedido y fn_carta_takeaway.
CREATE OR REPLACE FUNCTION public.fn_menu_activo (
  p_restaurant_id uuid,
  p_zona          text                     DEFAULT NULL::text,
  p_momento       timestamp with time zone DEFAULT now(),
  p_whatsapp      boolean                  DEFAULT false
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select m.id
  from menus m,
       lateral (select (p_momento at time zone fn_zona_restaurante(p_restaurant_id)) as local) l
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
$function$;

-- 4.2. fn_registrar_pedido: vale caducado con el "hoy" del restaurante (el menú ya sale de fn_menu_activo).
create or replace function public.fn_registrar_pedido(
  p_table_session_id uuid,
  p_items jsonb,
  p_notas text default null,
  p_camarero_id uuid default null,
  p_premios_canjeados jsonb default '[]'::jsonb,
  p_vale_codigo text default null,
  p_vale_importe numeric default null,
  p_camarero_token text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
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

  -- Pedido cargado por un camarero: exige su sesión (nuevo).
  if p_camarero_id is not null then
    perform fn_staff_exigir_sesion(v_restaurant_id, p_camarero_id, p_camarero_token, array['pedidos'], 'fn_registrar_pedido');
  end if;

  v_control_stock_activo := coalesce((v_restaurant_config->>'control_stock_activo')::boolean, false);

  select zona into v_zona from tables where id = v_table_id;

  -- Menú activo para esta mesa ahora mismo: más específico gana
  -- (zona+hora+días > menos criterios), igual que en el frontend.
  -- Mismo criterio que WhatsApp: fn_menu_activo (sql/menu_activo_unico.sql).
  v_menu_activo_id := fn_menu_activo(v_restaurant_id, v_zona, now(), false);

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
    if v_vale.fecha_vencimiento < fn_hoy_restaurante(v_restaurant_id) then
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

-- 4.3. fn_canjear_vale_regalo: vale caducado con el "hoy" del restaurante.
CREATE OR REPLACE FUNCTION public.fn_canjear_vale_regalo (
  p_table_session_id uuid,
  p_vale_codigo      text,
  p_vale_importe     numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_restaurant_id uuid;
  v_vale record;
begin
  select restaurant_id into v_restaurant_id
  from table_sessions
  where id = p_table_session_id and estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa no existe o ya está cerrada';
  end if;

  if p_vale_importe is null or p_vale_importe <= 0 then
    raise exception 'Importe inválido';
  end if;

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
  if v_vale.fecha_vencimiento < fn_hoy_restaurante(v_restaurant_id) then
    raise exception 'Ese vale ya venció';
  end if;
  if p_vale_importe > v_vale.saldo_actual then
    raise exception 'El vale no tiene saldo suficiente';
  end if;

  update vales_regalo set saldo_actual = saldo_actual - p_vale_importe where id = v_vale.id;

  insert into vale_movimientos (vale_id, importe, table_session_id)
  values (v_vale.id, -p_vale_importe, p_table_session_id);

  insert into table_session_payments (table_session_id, restaurant_id, monto, metodo_pago)
  values (p_table_session_id, v_restaurant_id, p_vale_importe, 'vale_regalo');
end;
$function$;

-- 4.4. fn_crear_reserva_web: "hoy", hora pasada y 15 min de antelación en la hora del restaurante.
CREATE OR REPLACE FUNCTION public.fn_crear_reserva_web (
  p_restaurant_id uuid,
  p_nombre        text,
  p_telefono      text,
  p_fecha         date,
  p_hora          time without time zone,
  p_personas      integer,
  p_zona          text                   DEFAULT 'sin preferencia'::text,
  p_notas         text                   DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
declare
  v_motivo text;
begin
  if p_nombre is null or trim(p_nombre) = '' then
    raise exception 'Falta el nombre';
  end if;
  if p_telefono is null or trim(p_telefono) = '' then
    raise exception 'Falta el teléfono';
  end if;
  if p_personas is null or p_personas < 1 then
    raise exception 'Cantidad de personas inválida';
  end if;
  if p_fecha is null or p_fecha < fn_hoy_restaurante(p_restaurant_id) then
    raise exception 'La fecha tiene que ser hoy o más adelante';
  end if;
  if p_hora is null then
    raise exception 'Falta la hora';
  end if;
  if not exists (select 1 from restaurants where id = p_restaurant_id) then
    raise exception 'Restaurante no encontrado';
  end if;

  -- Hoy: hora no pasada y al menos 15 minutos de antelación (como el agente).
  if p_fecha + p_hora <= date_trunc('minute', fn_ahora_restaurante(p_restaurant_id)) then
    raise exception 'Las % de hoy ya han pasado. Elige una hora más tarde.', to_char(p_hora, 'HH24:MI');
  end if;
  if p_fecha + p_hora < date_trunc('minute', fn_ahora_restaurante(p_restaurant_id)) + interval '15 minutes' then
    raise exception 'Para reservar hoy necesitamos al menos 15 minutos de antelación. Elige una hora más tarde.';
  end if;

  v_motivo := fn_reserva_fuera_de_horario(p_restaurant_id, p_fecha, p_hora);
  if v_motivo is not null then
    raise exception '%', v_motivo;
  end if;

  insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, estado, origen)
  values (p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas, coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''), 'pendiente', 'web');
end;
$function$;

-- 4.5. fn_reserva_whatsapp_crear: versión de 10 argumentos (con p_clave): hora pasada y 15 min con la hora del restaurante. La de 9 solo la llama.
create or replace function public.fn_reserva_whatsapp_crear (
  p_restaurant_id    uuid,
  p_nombre           text,
  p_telefono         text,
  p_fecha            date,
  p_hora             time without time zone,
  p_personas         integer,
  p_zona             text,
  p_notas            text,
  p_duracion_minutos integer,
  p_clave            text
)
  returns json
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  c_max_nombre   constant int := 100;
  c_max_notas    constant int := 500;
  c_max_telefono constant int := 30;
  v_id uuid;
  v_motivo text;
  v_max int;
  c_max_clave    constant int := 200;
begin
  -- Idempotencia: la misma clave (un "sí" repetido, p. ej. si no llegó la
  -- confirmación) devuelve la misma reserva. Antes de las validaciones, para
  -- que una reserva ya creada se siga devolviendo aunque su hora esté cerca.
  if p_clave is not null then
    if trim(p_clave) = '' or length(p_clave) > c_max_clave then
      raise exception 'Clave de reserva no válida.' using errcode = 'P0001';
    end if;
    perform pg_advisory_xact_lock(hashtext('reserva_whatsapp|' || coalesce(p_restaurant_id::text, '-') || '|' || p_clave));
    select r.id into v_id from reservations r where r.restaurant_id = p_restaurant_id and r.clave_whatsapp = p_clave;
    if v_id is not null then
      return json_build_object('id', v_id, 'ya_existia', true);
    end if;
  end if;

  if p_restaurant_id is null or not exists (select 1 from restaurants where id = p_restaurant_id) then
    raise exception 'Restaurante no encontrado.' using errcode = 'P0001';
  end if;
  if p_nombre is null or trim(p_nombre) = '' then
    raise exception 'Falta el nombre de la reserva.' using errcode = 'P0001';
  end if;
  if length(trim(p_nombre)) > c_max_nombre then
    raise exception 'El nombre es demasiado largo (máximo % caracteres).', c_max_nombre using errcode = 'P0001';
  end if;
  if p_telefono is null or trim(p_telefono) = '' or length(trim(p_telefono)) > c_max_telefono then
    raise exception 'Teléfono no válido.' using errcode = 'P0001';
  end if;
  if length(trim(coalesce(p_notas, ''))) > c_max_notas then
    raise exception 'Las notas son demasiado largas (máximo % caracteres).', c_max_notas using errcode = 'P0001';
  end if;
  if p_fecha is null or p_hora is null then
    raise exception 'Falta la fecha o la hora de la reserva.' using errcode = 'P0001';
  end if;
  if p_fecha + p_hora <= date_trunc('minute', fn_ahora_restaurante(p_restaurant_id)) then
    raise exception 'Esa fecha y hora ya han pasado. Elige otra, por favor.' using errcode = 'P0001';
  end if;
  if p_fecha + p_hora < date_trunc('minute', fn_ahora_restaurante(p_restaurant_id)) + interval '15 minutes' then
    raise exception 'Para reservar hoy necesitamos al menos 15 minutos de antelación. Elige una hora más tarde.' using errcode = 'P0001';
  end if;

  v_motivo := fn_reserva_fuera_de_horario(p_restaurant_id, p_fecha, p_hora);
  if v_motivo is not null then
    raise exception '%', v_motivo using errcode = 'P0001';
  end if;

  v_max := (fn_reserva_contexto_cliente(p_restaurant_id, null) ->> 'max_personas')::int;
  if p_personas is null or p_personas < 1 then
    raise exception 'El número de personas no es válido.' using errcode = 'P0001';
  end if;
  if v_max is not null and p_personas > v_max then
    raise exception 'Por WhatsApp podemos reservar como máximo para % personas. Para grupos más grandes, llámanos.', v_max
      using errcode = 'P0001';
  end if;

  -- Serializa todos los intentos de reserva de este restaurante y día:
  -- mientras una transacción tiene el lock, ninguna otra (otra
  -- conversación de WhatsApp, el personal desde el panel, etc.) puede
  -- comprobar/crear para el mismo restaurante+fecha hasta que termine.
  perform pg_advisory_xact_lock(hashtext(p_restaurant_id::text || p_fecha::text));

  if not fn_reserva_hay_mesa(p_restaurant_id, p_fecha, p_hora, p_personas, p_zona, p_duracion_minutos) then
    raise exception 'Ya no hay disponibilidad para esa franja.' using errcode = 'P0001';
  end if;

  insert into reservations (
    restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, duracion_minutos, estado, origen, clave_whatsapp
  ) values (
    p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas,
    coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''),
    p_duracion_minutos, 'confirmada', 'whatsapp', p_clave
  )
  returning id into v_id;

  return json_build_object('id', v_id, 'ya_existia', false);
end;
$$;

-- 4.6. fn_reserva_cliente_bloquear: reserva futura con la hora del restaurante.
CREATE OR REPLACE FUNCTION public.fn_reserva_cliente_bloquear (
  p_restaurant_id uuid,
  p_telefono      text,
  p_reserva_id    uuid
)
  RETURNS public.reservations
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_res reservations;
begin
  select * into v_res from reservations
  where id = p_reserva_id
    and restaurant_id = p_restaurant_id
    and estado in ('confirmada', 'pendiente')
    and fecha + hora > fn_ahora_restaurante(p_restaurant_id)
    and fn_normalizar_telefono(telefono) = fn_normalizar_telefono(p_telefono)
    and coalesce(fn_normalizar_telefono(p_telefono), '') <> ''
  for update;
  if v_res.id is null then
    raise exception 'No encuentro esa reserva: puede que ya esté anulada o que ya haya pasado.' using errcode = 'P0001';
  end if;
  return v_res;
end;
$function$;

-- 4.7. fn_reserva_cliente_cancelar: la nota "Anulada … el DD/MM HH:MM" con la hora del restaurante.
CREATE OR REPLACE FUNCTION public.fn_reserva_cliente_cancelar (
  p_restaurant_id uuid,
  p_telefono      text,
  p_reserva_id    uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_res reservations;
begin
  v_res := fn_reserva_cliente_bloquear(p_restaurant_id, p_telefono, p_reserva_id);
  update reservations
  set estado = 'cancelada',
      notas = concat_ws(' | ', nullif(notas, ''),
                'Anulada por el cliente por WhatsApp el ' || to_char(fn_ahora_restaurante(p_restaurant_id), 'DD/MM HH24:MI'))
  where id = v_res.id;
end;
$function$;

-- 4.8. fn_reserva_cliente_modificar: 15 min de antelación y nota "Cambiada … el …" con la hora del restaurante.
CREATE OR REPLACE FUNCTION public.fn_reserva_cliente_modificar (
  p_restaurant_id    uuid,
  p_telefono         text,
  p_reserva_id       uuid,
  p_fecha            date,
  p_hora             time without time zone,
  p_personas         integer,
  p_zona             text,
  p_duracion_minutos integer,
  p_aplicar          boolean                DEFAULT false
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_res reservations;
  v_motivo text;
  v_libre boolean;
  v_zona text := coalesce(nullif(trim(p_zona), ''), 'sin preferencia');
begin
  if p_fecha is null or p_hora is null or p_personas is null or p_personas < 1 then
    return 'Faltan datos para cambiar la reserva.';
  end if;

  -- Mismo bloqueo que fn_reserva_whatsapp_crear (restaurante + día), para
  -- el día nuevo y el de antes, en orden fijo para no bloquearse entre sí.
  perform pg_advisory_xact_lock(hashtext(p_restaurant_id::text || d::text))
  from (
    select distinct d from unnest(array[p_fecha, (select fecha from reservations where id = p_reserva_id)]) d
    where d is not null order by d
  ) x;

  v_res := fn_reserva_cliente_bloquear(p_restaurant_id, p_telefono, p_reserva_id);

  if p_fecha + p_hora <= date_trunc('minute', fn_ahora_restaurante(p_restaurant_id)) + interval '15 minutes' then
    return 'Para hoy necesitamos al menos 15 minutos de antelación.';
  end if;

  v_motivo := fn_reserva_fuera_de_horario(p_restaurant_id, p_fecha, p_hora);
  if v_motivo is not null then
    return v_motivo;
  end if;

  -- La disponibilidad se comprueba sin contar la propia reserva: se marca
  -- un momento como cancelada y se deja como estaba (todo dentro de esta
  -- transacción, nadie más lo ve).
  update reservations set estado = 'cancelada' where id = v_res.id;
  v_libre := fn_reserva_hay_mesa(p_restaurant_id, p_fecha, p_hora, p_personas, v_zona, coalesce(p_duracion_minutos, 120));

  if not v_libre then
    update reservations set estado = v_res.estado where id = v_res.id;
    return format('Lo sentimos, no tenemos mesa libre el %s a las %s para %s personas%s.',
      to_char(p_fecha, 'DD/MM'), to_char(p_hora, 'HH24:MI'), p_personas,
      case when v_zona <> 'sin preferencia' then ' en ' || v_zona else '' end);
  end if;

  if not p_aplicar then
    update reservations set estado = v_res.estado where id = v_res.id;
    return null;
  end if;

  update reservations
  set estado = v_res.estado,
      fecha = p_fecha,
      hora = p_hora,
      personas = p_personas,
      zona = v_zona,
      duracion_minutos = coalesce(p_duracion_minutos, duracion_minutos),
      notas = concat_ws(' | ', nullif(notas, ''),
                format('Cambiada por el cliente por WhatsApp el %s (antes: %s %s, %s pers., %s)',
                  to_char(fn_ahora_restaurante(p_restaurant_id), 'DD/MM HH24:MI'),
                  to_char(v_res.fecha, 'DD/MM'), to_char(v_res.hora, 'HH24:MI'), v_res.personas,
                  coalesce(v_res.zona, 'sin preferencia')))
  where id = v_res.id;
  return null;
end;
$function$;

-- 4.9. fn_reserva_contexto_cliente: reservas futuras con la hora del restaurante.
CREATE OR REPLACE FUNCTION public.fn_reserva_contexto_cliente (
  p_restaurant_id uuid,
  p_telefono      text
)
  RETURNS json
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select json_build_object(
    'reservas', coalesce((
      select json_agg(json_build_object(
               'id', r.id, 'nombre', r.nombre, 'fecha', r.fecha, 'hora', to_char(r.hora, 'HH24:MI'),
               'personas', r.personas, 'zona', r.zona, 'estado', r.estado
             ) order by r.fecha, r.hora)
      from (
        select * from reservations r
        where r.restaurant_id = p_restaurant_id
          and r.estado in ('confirmada', 'pendiente')
          and r.fecha + r.hora > fn_ahora_restaurante(p_restaurant_id)
          and fn_normalizar_telefono(r.telefono) = fn_normalizar_telefono(p_telefono)
          and coalesce(fn_normalizar_telefono(p_telefono), '') <> ''
        order by r.fecha, r.hora
        limit 5
      ) r
    ), '[]'::json),
    'max_personas', (
      select case
        when (rs.config ->> 'reservas_max_personas') ~ '^\d+$' and (rs.config ->> 'reservas_max_personas')::int > 0
          then (rs.config ->> 'reservas_max_personas')::int
        else (select max(t.capacidad) from tables t where t.restaurant_id = p_restaurant_id and t.activa = true)
      end
      from restaurants rs where rs.id = p_restaurant_id
    ),
    'telefono_reservas', (
      select nullif(trim(rs.config ->> 'telefono_reservas'), '') from restaurants rs where rs.id = p_restaurant_id
    )
  )
$function$;

-- 4.10. fn_reserva_hay_mesa: "ahora" y apertura de las mesas abiertas en la hora del restaurante.
CREATE OR REPLACE FUNCTION public.fn_reserva_hay_mesa (
  p_restaurant_id    uuid,
  p_fecha            date,
  p_hora             time without time zone,
  p_personas         integer,
  p_zona             text,
  p_duracion_minutos integer
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  -- Minutos de una sesión que sigue abierta: aunque haya superado la
  -- duración estimada, se cuenta ocupada al menos hasta ahora + este margen.
  c_margen_sesion_abierta constant integer := 30;
  v_inicio integer;
  v_fin integer;
  v_ahora integer;
  v_candidatas uuid[];
  v_ocup record;
  v_elegida uuid;
  v_zona_horaria text := fn_zona_restaurante(p_restaurant_id);
begin
  v_inicio := extract(hour from p_hora)::int * 60 + extract(minute from p_hora)::int;
  v_fin := v_inicio + p_duracion_minutos;
  -- "Ahora" en minutos desde la medianoche (hora del restaurante) del día de la reserva:
  -- negativo si la reserva es de un día futuro, > 1440 si fuera pasado.
  v_ahora := floor(extract(epoch from ((now() at time zone v_zona_horaria) - p_fecha::timestamp)) / 60)::int;

  -- Mesas que individualmente caben el grupo, de la zona pedida (o
  -- todas si "sin preferencia"/null), ordenadas de menor a mayor
  -- capacidad: así el hueco libre más ajustado se gasta primero y no
  -- se "quema" una mesa grande en un grupo pequeño sin necesidad.
  select array_agg(id order by capacidad asc) into v_candidatas
  from tables
  where restaurant_id = p_restaurant_id
    and activa = true
    and capacidad >= p_personas
    and (p_zona is null or p_zona = 'sin preferencia' or zona = p_zona);

  if v_candidatas is null or array_length(v_candidatas, 1) = 0 then
    return false;
  end if;

  -- Demanda ya existente que se solapa con la franja pedida: otras
  -- reservas confirmadas (sin mesa fija — se les asigna por tamaño, de
  -- mayor a menor), incluidas las del día anterior y siguiente que
  -- cruzan la medianoche, y sesiones de mesa abiertas (mesa fija conocida).
  for v_ocup in (
    select x.tam, x.mesa_fija
    from (
      select r.personas as tam, null::uuid as mesa_fija,
             (r.fecha - p_fecha) * 1440
               + extract(hour from r.hora)::int * 60 + extract(minute from r.hora)::int as ini,
             coalesce(r.duracion_minutos, 120) as dur
      from reservations r
      where r.restaurant_id = p_restaurant_id
        and r.fecha between p_fecha - 1 and p_fecha + 1
        and r.estado = 'confirmada'
        and (p_zona is null or p_zona = 'sin preferencia'
             or r.zona is null or r.zona = 'sin preferencia' or r.zona = p_zona)
    ) x
    where v_inicio < x.ini + x.dur and v_fin > x.ini

    union all

    select s.tam, s.mesa_fija
    from (
      select t.capacidad as tam, t.id as mesa_fija,
             floor(extract(epoch from ((ts.abierta_at at time zone v_zona_horaria) - p_fecha::timestamp)) / 60)::int as ini,
             -- Igual que getDuracion() en n8n (90/120/150/180 según
             -- comensales); sin comensales cargados, 150 min.
             case
               when ts.comensales is null then 150
               when ts.comensales <= 2 then 90
               when ts.comensales <= 4 then 120
               when ts.comensales <= 8 then 150
               else 180
             end as dur
      from table_sessions ts
      join tables t on t.id = ts.table_id
      where ts.restaurant_id = p_restaurant_id
        and ts.estado = 'abierta'
        and t.activa = true
        and (p_zona is null or p_zona = 'sin preferencia' or t.zona = p_zona)
    ) s
    where v_inicio < greatest(s.ini + s.dur, v_ahora + c_margen_sesion_abierta)
      and v_fin > s.ini

    order by tam desc
  )
  loop
    if v_ocup.mesa_fija is not null then
      -- Sesión de mesa: sabemos exactamente qué mesa ocupa.
      v_candidatas := array_remove(v_candidatas, v_ocup.mesa_fija);
    else
      -- Reserva sin mesa fija: le quitamos a las candidatas la más
      -- ajustada que todavía le entre.
      v_elegida := null;
      select id into v_elegida
      from tables
      where id = any(v_candidatas) and capacidad >= v_ocup.tam
      order by capacidad asc
      limit 1;
      if v_elegida is not null then
        v_candidatas := array_remove(v_candidatas, v_elegida);
      end if;
    end if;
  end loop;

  -- array_length(...) de un array vacío (tras quitarle todos los
  -- elementos con array_remove) da NULL, no 0 — con coalesce nos
  -- aseguramos de que "sin mesas candidatas" dé `false` de verdad, no
  -- NULL (que en el `if not ...` de fn_reserva_whatsapp_crear se
  -- trataría como "no lanzar la excepción", dejando pasar la reserva).
  return coalesce(array_length(v_candidatas, 1), 0) > 0;
end;
$function$;

-- 4.11. fn_pedido_whatsapp_crear: la nota "Recogida a las HH:MM" en la hora del restaurante.
create or replace function public.fn_pedido_whatsapp_crear (
  p_restaurant_id uuid,
  p_clave         text,
  p_telefono      text,
  p_nombre        text,
  p_hora_recogida timestamptz,
  p_notas         text,
  p_items         jsonb
)
  returns json
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  c_max_por_plato  constant int := 20;
  c_max_unidades   constant int := 60;
  c_max_lineas     constant int := 30;
  c_max_nombre     constant int := 100;
  c_max_telefono   constant int := 30;
  c_max_notas      constant int := 500;
  c_max_notas_item constant int := 200;
  c_max_clave      constant int := 200;
  v_order_id uuid;
  v_n_lineas int;
  v_unidades int;
  v_lineas jsonb;
begin
  -- Datos básicos ------------------------------------------------------------
  if p_restaurant_id is null then
    raise exception 'Falta el restaurante.' using errcode = 'RMP03';
  end if;
  if p_clave is null or trim(p_clave) = '' or length(p_clave) > c_max_clave then
    raise exception 'Clave de pedido no válida.' using errcode = 'RMP03';
  end if;
  if p_telefono is null or trim(p_telefono) = '' or length(trim(p_telefono)) > c_max_telefono then
    raise exception 'Teléfono no válido.' using errcode = 'RMP03';
  end if;
  if length(trim(coalesce(p_nombre, ''))) > c_max_nombre then
    raise exception 'El nombre es demasiado largo (máximo % caracteres).', c_max_nombre using errcode = 'RMP03';
  end if;
  if length(trim(coalesce(p_notas, ''))) > c_max_notas then
    raise exception 'Las notas son demasiado largas (máximo % caracteres).', c_max_notas using errcode = 'RMP03';
  end if;
  if p_hora_recogida is null then
    raise exception 'Falta la hora de recogida.' using errcode = 'RMP03';
  end if;

  -- Idempotencia: la misma clave (dos "sí" seguidos) devuelve el mismo pedido.
  perform pg_advisory_xact_lock(hashtext('pedido_whatsapp|' || p_restaurant_id::text || '|' || p_clave));

  select o.id into v_order_id
  from orders o
  where o.restaurant_id = p_restaurant_id and o.clave_whatsapp = p_clave;

  if v_order_id is not null then
    return (
      select json_build_object(
        'id', o.id, 'total', o.total, 'ya_existia', true,
        'lineas', coalesce((select json_agg(json_build_object('nombre', oi.nombre_snapshot, 'cantidad', oi.cantidad,
                                                              'precio', oi.precio_snapshot, 'notas', oi.notas)
                                            order by oi.agregado_at, oi.id)
                            from order_items oi where oi.order_id = o.id), '[]'::json))
      from orders o where o.id = v_order_id
    );
  end if;

  -- Hora de recogida ya pasada (después de la idempotencia: un "sí" repetido
  -- de un pedido ya creado devuelve ese pedido aunque la hora haya pasado).
  if p_hora_recogida < now() then
    raise exception 'La hora de recogida ya ha pasado.' using errcode = 'RMP03';
  end if;

  -- Restaurante y módulo -----------------------------------------------------
  if not exists (select 1 from restaurants r where r.id = p_restaurant_id and coalesce(r.activo, true)) then
    raise exception 'El restaurante no está disponible.' using errcode = 'RMP04';
  end if;
  if not exists (select 1 from restaurant_modulos m
                 where m.restaurant_id = p_restaurant_id and m.modulo_key = 'takeaway_delivery' and m.activo) then
    raise exception 'El restaurante no tiene el take away activo.' using errcode = 'RMP04';
  end if;

  -- Líneas -------------------------------------------------------------------
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'El pedido no tiene platos.' using errcode = 'RMP03';
  end if;
  -- La cantidad tiene que ser un número entero (1.5 no se redondea a 2).
  if exists (select 1 from jsonb_array_elements(p_items) e
             where case when jsonb_typeof(e -> 'cantidad') = 'number'
                        then (e ->> 'cantidad')::numeric <> trunc((e ->> 'cantidad')::numeric)
                        else true end) then
    raise exception 'La cantidad de cada plato tiene que ser un número entero.' using errcode = 'RMP03';
  end if;

  -- Se lee todo en un jsonb (sin tablas temporales: con SECURITY DEFINER no se
  -- usa pg_temp). Nombre, precio y coste salen de la carta de take away de
  -- ahora (fn_carta_takeaway), ignorando lo que mande n8n.
  begin
    select coalesce(jsonb_agg(jsonb_build_object(
             'orden', l.orden, 'menu_item_id', l.menu_item_id, 'cantidad', l.cantidad, 'notas', l.notas,
             'nombre', c.nombre, 'precio', c.precio, 'costo', mi.precio_costo) order by l.orden), '[]'::jsonb)
    into v_lineas
    from (
      select x.ord::int as orden,
             nullif(x.e ->> 'menu_item_id', '')::uuid as menu_item_id,
             (x.e ->> 'cantidad')::numeric::int as cantidad,
             nullif(trim(x.e ->> 'notas'), '') as notas
      from jsonb_array_elements(p_items) with ordinality as x(e, ord)
    ) l
    left join fn_carta_takeaway(p_restaurant_id, now()) c on c.id = l.menu_item_id
    left join menu_items mi on mi.id = c.id;
  exception when invalid_text_representation or numeric_value_out_of_range or cannot_coerce then
    raise exception 'Formato de platos no válido.' using errcode = 'RMP03';
  end;

  select count(*), coalesce(sum((e ->> 'cantidad')::int), 0) into v_n_lineas, v_unidades
  from jsonb_array_elements(v_lineas) e;

  if exists (select 1 from jsonb_array_elements(v_lineas) e
             where e ->> 'cantidad' is null or (e ->> 'cantidad')::int < 1) then
    raise exception 'Cada plato tiene que tener al menos 1 unidad.' using errcode = 'RMP03';
  end if;
  if exists (select 1 from jsonb_array_elements(v_lineas) e where length(e ->> 'notas') > c_max_notas_item) then
    raise exception 'Las notas de un plato son demasiado largas (máximo % caracteres).', c_max_notas_item using errcode = 'RMP03';
  end if;
  -- Tope por plato: también si el mismo plato viene en varias líneas.
  if v_n_lineas > c_max_lineas
     or v_unidades > c_max_unidades
     or exists (select 1 from jsonb_array_elements(v_lineas) e
                group by e ->> 'menu_item_id' having sum((e ->> 'cantidad')::int) > c_max_por_plato) then
    raise exception 'Pedido demasiado grande para WhatsApp (máximo % unidades por plato y % en total).',
      c_max_por_plato, c_max_unidades using errcode = 'RMP01';
  end if;

  if exists (select 1 from jsonb_array_elements(v_lineas) e
             where e ->> 'menu_item_id' is null or e ->> 'nombre' is null or e ->> 'precio' is null) then
    raise exception 'Algún plato del pedido ya no está en la carta.' using errcode = 'RMP02';
  end if;

  -- Inserción ----------------------------------------------------------------
  insert into orders (restaurant_id, tipo, estado, metodo_entrega, cliente_nombre, cliente_telefono,
                      notas, hora_recogida, total, clave_whatsapp)
  values (p_restaurant_id, 'takeaway', 'pendiente', 'retiro_local', nullif(trim(p_nombre), ''), trim(p_telefono),
          coalesce(nullif(trim(p_notas), ''),
                   'Recogida a las ' || to_char(p_hora_recogida at time zone fn_zona_restaurante(p_restaurant_id), 'HH24:MI')),
          p_hora_recogida, 0, p_clave)
  returning id into v_order_id;

  insert into order_items (order_id, restaurant_id, menu_item_id, nombre_snapshot, precio_snapshot,
                           costo_snapshot, cantidad, notas, agregado_at)
  select v_order_id, p_restaurant_id, (e ->> 'menu_item_id')::uuid, e ->> 'nombre', (e ->> 'precio')::numeric,
         (e ->> 'costo')::numeric, (e ->> 'cantidad')::int, e ->> 'notas',
         now() + make_interval(secs => (e ->> 'orden')::int / 1000.0)   -- conserva el orden de las líneas
  from jsonb_array_elements(v_lineas) e
  order by (e ->> 'orden')::int;

  return (
    select json_build_object(
      'id', o.id, 'total', o.total, 'ya_existia', false,
      'lineas', (select json_agg(json_build_object('nombre', e ->> 'nombre', 'cantidad', (e ->> 'cantidad')::int,
                                                   'precio', (e ->> 'precio')::numeric, 'notas', e ->> 'notas')
                                 order by (e ->> 'orden')::int)
                 from jsonb_array_elements(v_lineas) e))
    from orders o where o.id = v_order_id
  );
end;
$$;

-- 4.12. fn_agente_datos_restaurante: sin p_zona (o null) usa la zona del restaurante; si llega una zona, se respeta. Zona no válida → Madrid, como antes.
create or replace function public.fn_agente_datos_restaurante (
  p_restaurant_id uuid,
  p_zona          text default null
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public
as $function$
declare
  c_dias constant text[] := array['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
  c_nombres constant text[] := array['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  v_zona text := coalesce(nullif(btrim(p_zona), ''), fn_zona_restaurante(p_restaurant_id));
  v_rest restaurants;
  v_horario jsonb;
  v_dia jsonb;
  v_franjas text[];
  v_lineas text[] := array[]::text[];
  v_hoy date;
  v_isodow int;
  v_a text;
  v_c text;
begin
  select * into v_rest from restaurants where id = p_restaurant_id;
  if v_rest.id is null then
    return null;
  end if;

  -- Zona no válida → Madrid (no se rompe el agente por un dato mal puesto).
  if not exists (select 1 from pg_timezone_names where name = v_zona) then
    v_zona := 'Europe/Madrid';
  end if;
  v_hoy := (now() at time zone v_zona)::date;
  v_isodow := extract(isodow from v_hoy)::int;

  v_horario := case when jsonb_typeof(v_rest.config -> 'horario') = 'object' then v_rest.config -> 'horario' end;
  if v_horario is not null then
    for i in 1..7 loop
      v_dia := v_horario -> c_dias[i];
      v_franjas := array[]::text[];
      if v_dia is null or jsonb_typeof(v_dia) <> 'object' then
        v_lineas := v_lineas || (c_nombres[i] || ': sin horario indicado');
        continue;
      end if;
      if lower(coalesce(v_dia ->> 'abierto', '')) is distinct from 'true' then
        v_lineas := v_lineas || (c_nombres[i] || ': cerrado');
        continue;
      end if;
      v_a := left(nullif(btrim(v_dia ->> 'apertura'), ''), 5);
      v_c := left(nullif(btrim(v_dia ->> 'cierre'), ''), 5);
      if v_a is not null and v_c is not null then
        v_franjas := v_franjas || ('de ' || v_a || ' a ' || v_c);
      end if;
      v_a := left(nullif(btrim(v_dia ->> 'apertura2'), ''), 5);
      v_c := left(nullif(btrim(v_dia ->> 'cierre2'), ''), 5);
      if v_a is not null and v_c is not null then
        v_franjas := v_franjas || ('de ' || v_a || ' a ' || v_c);
      end if;
      v_lineas := v_lineas || (c_nombres[i] || ': ' ||
                  case when cardinality(v_franjas) = 0 then 'abierto, sin horas indicadas'
                       else array_to_string(v_franjas, ' y ') end);
    end loop;
  end if;

  return jsonb_build_object(
    'nombre', v_rest.nombre,
    'direccion', nullif(btrim(coalesce(v_rest.direccion, '')), ''),
    'telefono', coalesce(nullif(btrim(coalesce(v_rest.config ->> 'telefono_reservas', '')), ''),
                         nullif(btrim(coalesce(v_rest.whatsapp, '')), '')),
    'moneda', coalesce(nullif(v_rest.moneda, ''), 'EUR'),
    'zona', v_zona,
    'hoy', jsonb_build_object('fecha', to_char(v_hoy, 'YYYY-MM-DD'), 'dia', lower(c_nombres[v_isodow])),
    'horario_texto', case when cardinality(v_lineas) = 0 then null else array_to_string(v_lineas, E'\n') end
  );
end;
$function$;

-- 4.13. fn_restaurants_proteger_comercial: zona_horaria solo la cambia el superadmin; el cambio de un dueño se ignora sin error.
CREATE OR REPLACE FUNCTION public.fn_restaurants_proteger_comercial()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if auth.uid() is not null and not fn_es_superadmin() then
    new.plan := old.plan;
    new.activo := old.activo;
    new.trial_termina_en := old.trial_termina_en;
    new.precio_override := old.precio_override;
    new.precio_override_hasta := old.precio_override_hasta;
    new.precio_contrato := old.precio_contrato;
    new.permanencia_hasta := old.permanencia_hasta;
    new.baja_en := old.baja_en;
    new.baja_motivo := old.baja_motivo;
    new.baja_penalizacion := old.baja_penalizacion;
    new.zona_horaria := old.zona_horaria;  -- solo la cambia el superadmin (decisión 1)
  end if;
  return new;
end;
$function$;
-- fn_agente_datos_restaurante cambia el valor por defecto de p_zona: se repiten
-- sus grants (los mismos que tenía: solo service_role).
revoke all on function public.fn_agente_datos_restaurante(uuid, text) from public, anon, authenticated;
grant execute on function public.fn_agente_datos_restaurante(uuid, text) to service_role;

-- 5. anon puede leer la zona (web de reservas, mesa, camarero y cocina) --------------
grant select (zona_horaria) on public.restaurants to anon;

notify pgrst, 'reload schema';
