-- =============================================================================
-- Avisos de prueba para validar en la preview de staging la entrega 1b del
-- agente de WhatsApp (criterios 11 y 12 de
-- docs/specs/2026-11-13-agente-whatsapp-revision.md).
--
-- SOLO EN TEST (sfkwbhzelrestmrmptql). A diferencia del resto de
-- supabase/tests/, este script DEJA DATOS (no hace rollback): al terminar la
-- validación hay que ejecutar avisos_1b_borrar.sql.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/preview/avisos_1b_crear.sql
--
-- Restaurante propio: "Restaurante de Prueba" (b33b0de2-…, dueño test@restomind.com,
-- con el módulo whatsapp). Otro restaurante: "Resto Fuerteventura" (c5179262-…).
-- Todos los avisos llevan paso = 'PRUEBA PREVIEW 1b' (así los borra el otro
-- script) y teléfonos 699 000 0xx.
--
-- Qué debe verse:
--   Dueño de "Restaurante de Prueba", /admin/avisos-whatsapp/b33b0de2-…:
--     Pendientes: sin_respuesta 699 000 001 (×3) y pedido_no_creado 699 000 002
--                 (y el de las 00:30 de ayer, 699 000 008).
--     Atendidos (30 días): reserva_no_creada 699 000 003 (hace 5 días).
--     NO aparecen: reserva_no_modificada 699 000 004 (atendida hace 31 días),
--                  error_interno (no visible) ni el de Resto Fuerteventura.
--   Superadmin, /superadmin/agente-whatsapp: todos, también el de hace 31 días,
--     el error_interno, el de Fuerteventura y la firma_invalida sin restaurante.
-- =============================================================================
do $$
declare
  c_paso constant text := 'PRUEBA PREVIEW 1b';
  v_rest uuid := 'b33b0de2-4504-4709-9d3b-9efbfabd55b1';
  v_otro uuid := 'c5179262-2994-42ba-813d-8e930e7d44c6';
  v_duenio uuid;
  v_id uuid;
begin
  -- Guardia: estos restaurantes solo existen en Test.
  select user_id into v_duenio from restaurants where id = v_rest and nombre = 'Restaurante de Prueba';
  if v_duenio is null or not exists (select 1 from restaurants where id = v_otro) then
    raise exception 'No es la base de Test (faltan los restaurantes de prueba). No se crea nada.';
  end if;

  -- 1. Pendiente, repetido 3 veces → "(×3)".
  for i in 1..3 loop
    v_id := fn_agente_registrar_error(v_rest, '34699000001', 'sin_respuesta', c_paso,
              jsonb_build_object('error', 'Prueba de la preview: la IA no respondió', 'ejecucion', 'prueba-' || i));
  end loop;

  -- 2. Pendiente.
  perform fn_agente_registrar_error(v_rest, '699000002', 'pedido_no_creado', c_paso,
            '{"error": "Prueba de la preview: fn_pedido_whatsapp_crear devolvió 500", "ejecucion": "prueba-2"}'::jsonb);

  -- 3. Atendido hace 5 días (se ve en "Atendidos").
  insert into agente_errores (restaurant_id, telefono_cliente, tipo, paso, visible_restaurante, created_at, ultima_vez_at,
                              atendida, atendida_por, atendida_at)
  values (v_rest, '699000003', 'reserva_no_creada', c_paso, true, now() - interval '6 days', now() - interval '6 days',
          true, v_duenio, now() - interval '5 days');

  -- 4. Atendido hace 31 días: NO se ve en la pantalla del dueño; sí en superadmin.
  insert into agente_errores (restaurant_id, telefono_cliente, tipo, paso, visible_restaurante, created_at, ultima_vez_at,
                              atendida, atendida_por, atendida_at)
  values (v_rest, '699000004', 'reserva_no_modificada', c_paso, true, now() - interval '32 days', now() - interval '32 days',
          true, v_duenio, now() - interval '31 days');

  -- 5. No visible para el restaurante (solo superadmin).
  perform fn_agente_registrar_error(v_rest, '699000005', 'error_interno', c_paso, '{"error": "Prueba de la preview: error interno"}'::jsonb);

  -- 6. De otro restaurante.
  perform fn_agente_registrar_error(v_otro, '699000006', 'sin_respuesta', c_paso, '{"error": "Prueba de la preview: otro restaurante"}'::jsonb);

  -- 7. Sin restaurante (solo superadmin).
  insert into agente_errores (restaurant_id, telefono_cliente, tipo, paso, visible_restaurante)
  values (null, null, 'firma_invalida', c_paso, false);

  -- 8. Ayer a las 00:30 de Madrid: en las estadísticas cuenta en el día de ayer.
  insert into agente_errores (restaurant_id, telefono_cliente, tipo, paso, visible_restaurante, created_at, ultima_vez_at)
  values (v_rest, '699000008', 'pedido_demasiado_grande', c_paso, true,
          ((fn_hoy_madrid() - 1)::timestamp + time '00:30') at time zone 'Europe/Madrid',
          ((fn_hoy_madrid() - 1)::timestamp + time '00:30') at time zone 'Europe/Madrid');
end
$$;

select e.tipo, coalesce(r.nombre, 'Sin restaurante') as restaurante, e.telefono_cliente, e.veces, e.visible_restaurante,
       e.atendida, to_char(e.created_at at time zone 'Europe/Madrid', 'DD/MM/YYYY HH24:MI') as creado_madrid,
       to_char(e.atendida_at at time zone 'Europe/Madrid', 'DD/MM/YYYY HH24:MI') as atendida_madrid
from agente_errores e left join restaurants r on r.id = e.restaurant_id
where e.paso = 'PRUEBA PREVIEW 1b'
order by e.created_at;
