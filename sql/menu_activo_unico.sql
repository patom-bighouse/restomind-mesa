-- ============================================================================
-- Un solo criterio de "menú activo" en la base de datos.
--
-- fn_registrar_pedido (guarda los pedidos de mesa) tenía su propia copia de
-- las reglas para elegir el menú (zona, franja horaria, día de la semana,
-- gana el más específico), igual que fn_menu_activo (agente de WhatsApp,
-- sql/menu_activo_takeaway.sql). Si un día se cambia una regla en un sitio
-- y no en el otro, la mesa y WhatsApp cobrarían menús distintos.
--
-- Se sustituye ese bloque por una llamada a fn_menu_activo(). Mismo
-- resultado: comparado en producción el 8 nov 2026 (semana completa cada
-- 30 min, todas las zonas): 0 diferencias en 1.680 casos.
--
-- Solo se toca ese bloque; el resto de fn_registrar_pedido queda igual. Si
-- el bloque no es exactamente el esperado, no se cambia nada y da error.
--
-- La web (src/lib/menus.js) sigue calculando el menú para mostrar precios;
-- lo que se cobra lo decide esta función.
--
-- Necesita sql/menu_activo_takeaway.sql. Re-ejecutable.
-- Ejecutar en staging y después en producción.
-- ============================================================================

do $$
declare
  v_def text := pg_get_functiondef(
    'public.fn_registrar_pedido(uuid, jsonb, text, uuid, jsonb, text, numeric)'::regprocedure);
  v_bloque text;
begin
  if v_def like '%v_menu_activo_id := fn_menu_activo(%' then
    raise notice 'fn_registrar_pedido ya usaba fn_menu_activo.';
    return;
  end if;

  if (select count(*) from regexp_matches(v_def, 'select m\.id into v_menu_activo_id.*?limit 1;', 'g')) <> 1 then
    raise exception 'No se encontró (una sola vez) el bloque del menú activo en fn_registrar_pedido: revisar a mano.';
  end if;

  v_bloque := (regexp_match(v_def, '(select m\.id into v_menu_activo_id.*?limit 1;)'))[1];
  if md5(v_bloque) <> '034125c1c30a75cda21ca71f44e0145c' then
    raise exception 'El bloque del menú activo de fn_registrar_pedido no es el esperado (md5 %): revisar a mano.', md5(v_bloque);
  end if;

  execute replace(v_def, v_bloque,
    '-- Mismo criterio que WhatsApp: fn_menu_activo (sql/menu_activo_unico.sql).' || chr(10) ||
    '  v_menu_activo_id := fn_menu_activo(v_restaurant_id, v_zona, now(), false);');
  raise notice 'fn_registrar_pedido usa ahora fn_menu_activo.';
end;
$$;

notify pgrst, 'reload schema';
