-- ============================================================================
-- CRM: enlace de Google Maps con la ubicación exacta de cada cuenta.
--
-- Opcional: el vendedor busca el local en Google Maps, "Compartir → Copiar
-- enlace" y lo pega en la ficha. Si está vacío, la app genera el enlace a
-- partir de nombre + dirección + ciudad.
-- Re-ejecutable. Ejecutar después de crm_vendedores.sql, en staging y en
-- producción.
-- ============================================================================

alter table crm_cuentas add column if not exists maps_url text;

alter table crm_cuentas drop constraint if exists crm_cuentas_maps_url_check;
alter table crm_cuentas add constraint crm_cuentas_maps_url_check
  check (maps_url is null or maps_url ~* '^https?://');
