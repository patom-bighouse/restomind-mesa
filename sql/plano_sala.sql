-- ============================================================================
-- Plano de sala visual: posición de cada mesa dentro de su zona,
-- guardada como porcentaje (0-100) del ancho/alto del lienzo — así el
-- layout no depende de la resolución de pantalla de quien lo mira.
-- Null significa "todavía sin posicionar a mano" — el frontend le
-- calcula una posición de arranque razonable hasta que el dueño la
-- arrastre a su lugar real.
-- ============================================================================

alter table tables
  add column if not exists pos_x numeric,
  add column if not exists pos_y numeric;
