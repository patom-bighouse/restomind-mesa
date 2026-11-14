-- =============================================================================
-- fn_pedido_whatsapp_crear: más validaciones (revisión de la entrega 1a)
-- Corrige 20261113114751_pedido_whatsapp_crear (ya aplicada en Test).
-- Especificación: docs/specs/2026-11-13-agente-whatsapp-revision.md (criterio 3)
--
-- NO TOCA DATOS. Misma firma y mismos grants (solo service_role). Añade:
--   - la cantidad de cada línea tiene que ser un número entero (antes 1.5 se
--     redondeaba a 2): RMP03;
--   - p_hora_recogida ya pasada: RMP03 (después de comprobar la clave, para
--     que un "sí" repetido de un pedido ya creado siga devolviéndolo).
-- No comprueba el horario de take away: es la lógica de franjas y
-- takeaway_minutos_antes_cierre que hoy vive en n8n ("Validar hora recogida");
-- llevarla a la BD duplicaría mucho. Queda anotado para la fase 2.
-- Idempotente.
-- =============================================================================

-- p_items: [{ "menu_item_id": uuid, "cantidad": int, "notas": text }, ...]
-- Cualquier otro campo (nombre, precio…) se ignora: el nombre y el precio
-- salen de la carta (fn_carta_takeaway en este momento).
-- Devuelve { id, total, ya_existia, lineas: [{ nombre, cantidad, precio, notas }] }.
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
                   'Recogida a las ' || to_char(p_hora_recogida at time zone 'Europe/Madrid', 'HH24:MI')),
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

revoke all on function public.fn_pedido_whatsapp_crear(uuid, text, text, text, timestamptz, text, jsonb) from public, anon, authenticated;
grant execute on function public.fn_pedido_whatsapp_crear(uuid, text, text, text, timestamptz, text, jsonb) to service_role;
