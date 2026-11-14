-- =============================================================================
-- Borra los avisos de prueba de la preview de la entrega 1b (los creados por
-- avisos_1b_crear.sql y avisos_1b_en_vivo.sql: paso = 'PRUEBA PREVIEW 1b').
-- Su detalle se borra en cascada.
--
-- SOLO EN TEST (sfkwbhzelrestmrmptql). Es la única excepción a "no se borra
-- ninguna fila de agente_errores" (decisión 13): son datos de prueba de Test.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/preview/avisos_1b_borrar.sql
-- =============================================================================
do $$
begin
  if not exists (select 1 from restaurants where id = 'b33b0de2-4504-4709-9d3b-9efbfabd55b1' and nombre = 'Restaurante de Prueba') then
    raise exception 'No es la base de Test. No se borra nada.';
  end if;
end
$$;

with borrados as (
  delete from agente_errores where paso = 'PRUEBA PREVIEW 1b' returning id
)
select count(*) as avisos_borrados from borrados;
