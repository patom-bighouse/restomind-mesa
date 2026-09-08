-- ============================================================================
-- Fix de seguridad: hoy cualquiera con la clave anon (pública, va en el
-- bundle de la web) puede leer TODAS las columnas de "tables" y
-- "restaurants" para TODOS los restaurantes de la plataforma con una
-- petición directa a la API REST de Supabase, sin pasar por la app.
--
-- Revisado el código: ningún flujo anon (Mesa.jsx, Camarero.jsx,
-- Reservar.jsx) necesita leer tables.qr_token ni restaurants.user_id
-- directamente — el qr_token solo se usa vía la función
-- get_table_by_qr(token), que ya lo valida uno a uno.
--
-- Este fix NO toca filas (RLS) — solo columnas, con GRANT a nivel de
-- columna. Es idempotente: se puede correr las veces que haga falta.
-- ============================================================================

revoke select on tables from anon;
grant select (
  id, restaurant_id, numero, zona, capacidad, activa,
  necesita_limpieza, limpieza_progreso
) on tables to anon;

revoke select on restaurants from anon;
grant select (
  id, nombre, slug, logo_url, whatsapp, direccion,
  config, activo, moneda, subdominio
) on restaurants to anon;

notify pgrst, 'reload schema';
