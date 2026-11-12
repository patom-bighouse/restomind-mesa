-- ============================================================================
-- Subcategorías de carta: una categoría puede tener otra como "padre"
-- (ej. "Vinos Tintos" dentro de "Bebidas"). Un solo nivel de anidado
-- — una subcategoría no puede a su vez tener hijas, eso se controla
-- desde AdminCarta.jsx, no hace falta un check acá. Si se borra la
-- categoría padre, las hijas vuelven a quedar como principales en vez
-- de borrarse con ella.
-- ============================================================================

alter table categories
  add column if not exists categoria_padre_id uuid references categories(id) on delete set null;
