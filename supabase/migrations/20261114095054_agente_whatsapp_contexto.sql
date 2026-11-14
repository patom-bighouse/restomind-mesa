-- =============================================================================
-- Agente de WhatsApp, entrega 1b: contexto del restaurante (C1-C5, decisiones 1 y 2)
-- Especificación: docs/specs/2026-11-13-agente-whatsapp-revision.md
--
-- NO TOCA DATOS. Cambia:
--   - fn_carta_takeaway: devuelve también `alergenos` (jsonb, claves del
--     catálogo de la carta: gluten, huevos…). CAMBIA LA FIRMA (columna nueva
--     al final), así que se borra y se vuelve a crear con los mismos grants
--     (solo service_role). El agente de la 1a sigue funcionando: ignora la
--     columna nueva. fn_pedido_whatsapp_crear la usa (plpgsql, sin
--     dependencia registrada) y solo lee id, nombre y precio.
--   - fn_agente_datos_restaurante(p_restaurant_id, p_zona): nueva, solo
--     service_role (n8n). Dirección, teléfono (config.telefono_reservas o,
--     si no hay, restaurants.whatsapp), moneda, horario semanal en texto y el
--     día de hoy en la zona del restaurante. No depende del módulo
--     info_restaurante (decisión 1).
--     La zona va como parámetro (regla 7); hoy n8n no la manda y vale
--     Europe/Madrid hasta que exista la zona por restaurante.
-- Orden de despliegue: esta migración en Producción ANTES de reimportar el
-- agente de la 1b.
-- Idempotente.
-- =============================================================================

-- 1. fn_carta_takeaway con alérgenos -------------------------------------------
drop function if exists public.fn_carta_takeaway(uuid, timestamp with time zone);

create function public.fn_carta_takeaway (
  p_restaurant_id uuid,
  p_momento       timestamp with time zone default now()
)
  returns table (
    id           uuid,
    nombre       text,
    descripcion  text,
    precio       numeric,
    precio_carta numeric,
    emoji        text,
    category_id  uuid,
    categories   json,
    menu_nombre  text,
    alergenos    jsonb
  )
  language sql
  stable
  security definer
  set search_path = public
as $function$
  with activo as (
    select fn_menu_activo(p_restaurant_id, null, p_momento, true) as menu_id
  )
  select mi.id, mi.nombre, mi.descripcion,
         coalesce(mp.precio, mi.precio) as precio,
         mi.precio as precio_carta,
         mi.emoji, mi.category_id,
         case when c.id is null then null else json_build_object('nombre', c.nombre, 'orden', c.orden) end as categories,
         m.nombre as menu_nombre,
         case when jsonb_typeof(mi.alergenos) = 'array' then mi.alergenos else '[]'::jsonb end as alergenos
  from menu_items mi
  cross join activo a
  left join menus m on m.id = a.menu_id
  left join categories c on c.id = mi.category_id
  left join menu_item_precios_menu mp on mp.menu_id = a.menu_id and mp.menu_item_id = mi.id
  where mi.restaurant_id = p_restaurant_id
    and mi.disponible = true
    and coalesce(mp.excluido, false) = false
  order by c.orden nulls last, mi.orden nulls last, mi.nombre
$function$;

revoke all on function public.fn_carta_takeaway(uuid, timestamp with time zone) from public, anon, authenticated;
grant execute on function public.fn_carta_takeaway(uuid, timestamp with time zone) to service_role;

-- 2. fn_agente_datos_restaurante -----------------------------------------------
-- Devuelve null si el restaurante no existe. Campos sin dato → null (el
-- agente contesta "no dispongo de ese dato" en vez de inventar).
--   { nombre, direccion, telefono, moneda, zona,
--     hoy: { fecha 'YYYY-MM-DD', dia 'sábado' },
--     horario_texto: 'Lunes: de 13:00 a 16:00 y de 20:00 a 23:30\nMartes: cerrado\n…' | null }
-- Solo service_role (n8n): no hay comprobación de sesión dentro porque
-- anon y authenticated no la pueden ejecutar (mismo criterio que
-- fn_carta_takeaway y fn_agente_registrar_error).
create or replace function public.fn_agente_datos_restaurante (
  p_restaurant_id uuid,
  p_zona          text default 'Europe/Madrid'
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
  v_zona text := coalesce(nullif(btrim(p_zona), ''), 'Europe/Madrid');
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

revoke all on function public.fn_agente_datos_restaurante(uuid, text) from public, anon, authenticated;
grant execute on function public.fn_agente_datos_restaurante(uuid, text) to service_role;
