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

-- Forma de la mesa en el plano — cada zona puede combinar libremente
-- mesas redondas y rectangulares, no es una elección por zona sino
-- por mesa individual.
alter table tables
  add column if not exists forma text not null default 'circular';

alter table tables drop constraint if exists tables_forma_check;
alter table tables add constraint tables_forma_check check (forma in ('circular', 'rectangular'));
