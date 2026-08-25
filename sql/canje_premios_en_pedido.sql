-- ============================================================================
-- Canje de premios en el momento del pedido: el cliente (Mesa.jsx) o
-- el camarero (Camarero.jsx) puede agregar un premio al carrito igual
-- que un plato — se materializa recién al confirmar y enviar el
-- pedido, en la misma transacción que crea los order_items, para que
-- nunca se descuenten puntos de un carrito que se termina abandonando.
--
-- Dos tipos de premio:
--   - plato_gratis: crea una línea de ese plato con precio 0.
--   - descuento: crea una línea sin plato con precio NEGATIVO — así
--     el total del pedido (que ya se calcula sumando order_items) lo
--     resta solo, sin tocar ningún otro cálculo de total existente.
-- ============================================================================

alter table premios_fidelizacion
  add column if not exists tipo text not null default 'plato_gratis',
  add column if not exists menu_item_id uuid references menu_items(id) on delete cascade,
  add column if not exists descuento_importe numeric(10,2);

alter table premios_fidelizacion drop constraint if exists premios_fidelizacion_tipo_check;
alter table premios_fidelizacion add constraint premios_fidelizacion_tipo_check
  check (tipo in ('plato_gratis', 'descuento'));

-- Los premios creados con la versión anterior (antes de tipo/menu_item_id)
-- quedaron con tipo='plato_gratis' por el default de arriba pero sin
-- menu_item_id — no cumplen la restricción nueva. Eran de prueba, así
-- que se borran en vez de intentar adivinarles un plato al azar; hay
-- que volver a crearlos desde /admin/fidelizacion con el tipo correcto.
delete from premios_fidelizacion where tipo = 'plato_gratis' and menu_item_id is null;

alter table premios_fidelizacion drop constraint if exists premios_fidelizacion_config_check;
alter table premios_fidelizacion add constraint premios_fidelizacion_config_check
  check (
    (tipo = 'plato_gratis' and menu_item_id is not null and descuento_importe is null)
    or (tipo = 'descuento' and descuento_importe is not null and descuento_importe > 0 and menu_item_id is null)
  );

-- Traza de qué línea de un pedido vino de canjear un premio (para
-- distinguirla visualmente en CuentaMesa y en el ticket).
alter table order_items
  add column if not exists premio_canjeado_id uuid references premios_fidelizacion(id) on delete set null;

-- ============================================================================
-- fn_estado_fidelizacion: se agrega el tipo de cada premio y, según
-- corresponda, el nombre del plato o el importe del descuento — Mesa.jsx
-- y Camarero.jsx lo necesitan para mostrar el botón de canjear con la
-- info correcta.
-- ============================================================================
create or replace function fn_estado_fidelizacion(p_restaurant_id uuid, p_telefono text)
returns json
language plpgsql
security definer
as $$
declare
  v_puntos integer := 0;
  v_gasto numeric := 0;
  v_nivel_actual json;
  v_proximo_nivel json;
  v_premios json;
begin
  select coalesce(puntos, 0), coalesce(gasto_acumulado, 0)
    into v_puntos, v_gasto
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
      'nombre', p.nombre,
      'descripcion', p.descripcion,
      'costo_puntos', p.costo_puntos,
      'tipo', p.tipo,
      'menu_item_nombre', mi.nombre,
      'descuento_importe', p.descuento_importe,
      'disponible', (p.costo_puntos <= v_puntos)
    ) order by p.costo_puntos), '[]'::json)
    into v_premios
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

  return json_build_object(
    'puntos', v_puntos,
    'gasto_acumulado', v_gasto,
    'nivel_actual', v_nivel_actual,
    'proximo_nivel', v_proximo_nivel,
    'premios', v_premios
  );
end;
$$;

-- ============================================================================
-- fn_registrar_pedido: se agrega el parámetro p_premios_canjeados
-- (jsonb, default vacío para no romper las llamadas existentes). Cada
-- elemento: { "premio_id": "uuid", "comensal": 1 | null }. Por cada
-- uno: valida puntos/nivel del cliente de la sesión, descuenta puntos,
-- deja el movimiento en clientes_movimientos, y crea la línea
-- correspondiente en order_items.
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
begin
  perform pg_advisory_xact_lock(hashtext(p_table_session_id::text));

  select ts.restaurant_id, ts.table_id, r.modo_cocina, r.minutos_limite_agrupado, ts.cliente_telefono
    into v_restaurant_id, v_table_id, v_modo_cocina, v_minutos_limite, v_cliente_telefono
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

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, nombre, precio, precio_costo into v_menu_item
    from menu_items
    where id = (v_item->>'menu_item_id')::uuid;

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, agregado_at, restaurant_id
    )
    values (
      v_order_id,
      v_menu_item.id,
      v_menu_item.nombre,
      v_menu_item.precio,
      v_menu_item.precio_costo,
      (v_item->>'cantidad')::int,
      v_item->>'notas',
      nullif(v_item->>'comensal', '')::int,
      now(),
      v_restaurant_id
    )
    returning id into v_order_item_id;

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
