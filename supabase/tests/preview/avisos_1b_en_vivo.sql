-- =============================================================================
-- Criterio 10 (alerta al momento) de docs/specs/2026-11-13-agente-whatsapp-revision.md.
-- Con Mesas, Carta y Cocina de "Restaurante de Prueba" abiertas en la preview,
-- registra tres avisos como lo hace n8n (fn_agente_registrar_error):
--   - sin_respuesta de "Restaurante de Prueba" → banda y timbre en las tres pestañas;
--   - sin_respuesta de "Resto Fuerteventura"   → no aparece;
--   - error_interno de "Restaurante de Prueba" → no aparece (no es visible).
--
-- SOLO EN TEST (sfkwbhzelrestmrmptql). DEJA DATOS: al terminar, avisos_1b_borrar.sql.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/preview/avisos_1b_en_vivo.sql
-- Se puede ejecutar varias veces; cada vez usa un teléfono nuevo para que salga
-- un aviso nuevo (y no una repetición del anterior).
-- =============================================================================
do $$
declare
  c_paso constant text := 'PRUEBA PREVIEW 1b';
  v_rest uuid := 'b33b0de2-4504-4709-9d3b-9efbfabd55b1';
  v_otro uuid := 'c5179262-2994-42ba-813d-8e930e7d44c6';
  v_tel text := '6990001' || lpad((extract(epoch from now())::bigint % 100)::text, 2, '0');
begin
  if not exists (select 1 from restaurants where id = v_rest and nombre = 'Restaurante de Prueba')
     or not exists (select 1 from restaurants where id = v_otro) then
    raise exception 'No es la base de Test (faltan los restaurantes de prueba). No se crea nada.';
  end if;
  perform fn_agente_registrar_error(v_rest, v_tel, 'sin_respuesta', c_paso, '{"error": "Prueba en vivo de la preview"}'::jsonb);
  perform fn_agente_registrar_error(v_otro, v_tel, 'sin_respuesta', c_paso, '{"error": "Prueba en vivo: otro restaurante"}'::jsonb);
  perform fn_agente_registrar_error(v_rest, v_tel, 'error_interno', c_paso, '{"error": "Prueba en vivo: error interno"}'::jsonb);
end
$$;

select e.tipo, coalesce(r.nombre, 'Sin restaurante') as restaurante, e.telefono_cliente, e.visible_restaurante,
       to_char(e.created_at at time zone 'Europe/Madrid', 'HH24:MI:SS') as hora_madrid
from agente_errores e left join restaurants r on r.id = e.restaurant_id
where e.paso = 'PRUEBA PREVIEW 1b' and e.created_at > now() - interval '1 minute'
order by e.created_at;
