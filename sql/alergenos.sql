-- ============================================================================
-- Alérgenos (Reglamento UE 1169/2011, Anexo II): permite marcar cuáles de
-- los 14 alérgenos obligatorios contiene cada plato, y que el cliente
-- filtre la carta según los que quiera evitar.
--
-- El catálogo de los 14 alérgenos es fijo por ley — no es configurable
-- por restaurante, por eso NO se crea una tabla nueva (a diferencia de
-- sectores_cocina o camareros). La lista vive directamente en el código
-- del frontend (AdminCarta.jsx y Mesa.jsx), y acá solo guardamos qué
-- códigos aplican a cada plato.
-- ============================================================================

alter table menu_items
  add column if not exists alergenos jsonb not null default '[]'::jsonb;

-- Códigos de referencia (para que quede documentado en el propio SQL):
-- gluten, crustaceos, huevos, pescado, cacahuetes, soja, lacteos,
-- frutos_cascara, apio, mostaza, sesamo, sulfitos, altramuces, moluscos
