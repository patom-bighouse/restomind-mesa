-- ============================================================================
-- Importador de carta con foto + IA: el dueño sube una o varias fotos
-- de su carta impresa y una Edge Function (supabase/functions/
-- importar-carta) le pide a Claude que extraiga categorías y platos.
-- El resultado NUNCA se inserta directo — se muestra en una pantalla
-- de revisión editable en AdminCarta.jsx, y solo al confirmar se
-- crean categorías/platos con inserts normales (RLS de siempre, sin
-- función especial: el dueño ya puede crear platos por su cuenta).
--
-- Módulo de pago aparte del de multiidioma — un restaurante puede
-- querer uno sin el otro.
-- ============================================================================

insert into modulos (key, nombre, descripcion, requiere, orden) values
  ('importador_carta', 'Importador de carta con foto (IA)', 'Sube una foto de la carta impresa y la IA extrae platos, precios y categorías automáticamente.', 'nucleo', 6)
on conflict (key) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  requiere = excluded.requiere,
  orden = excluded.orden;
