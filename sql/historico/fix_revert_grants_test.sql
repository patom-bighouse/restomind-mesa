-- ============================================================================
-- Revierte sql/fix_grants_test.sql: ese script (corrido en producción)
-- hizo "grant select, insert, update, delete on all tables in schema
-- public to anon, authenticated", dejando prácticamente todas las
-- tablas abiertas de par en par para el rol anon a nivel de permiso.
-- Lo único que hoy evita que un visitante anónimo lea/escriba esas
-- tablas es que cada política RLS lo bloquee correctamente — un
-- colchón muy frágil (basta una política mal escrita para exponer
-- datos sensibles: PINs de camareros, secretos de webhooks, etc.).
--
-- Este script quita el permiso general tabla por tabla y devuelve
-- exactamente lo que cada tabla necesita, verificado contra el código
-- real de Mesa.jsx / Camarero.jsx / Reservar.jsx / CamareroLimpieza.jsx
-- (las únicas superficies que corren como anon).
--
-- Deliberadamente NO toca "tables" ni "restaurants" (ya resueltas en
-- fix_seguridad_anon_columnas.sql) ni "table_sessions" (pendiente de
-- resolver aparte — no hay política RLS de INSERT/UPDATE para anon en
-- el repo, así que primero hay que confirmar qué hay corriendo en
-- producción antes de tocar sus grants).
-- ============================================================================

revoke all on table camareros from anon;
revoke all on table categoria_traducciones from anon;
revoke all on table categories from anon;
revoke all on table clientes from anon;
revoke all on table clientes_movimientos from anon;
revoke all on table ingredientes from anon;
revoke all on table limpieza_pasos from anon;
revoke all on table menu_item_modificador_grupos from anon;
revoke all on table menu_item_modificador_precios from anon;
revoke all on table menu_item_precios_menu from anon;
revoke all on table menu_item_traducciones from anon;
revoke all on table menu_items from anon;
revoke all on table menus from anon;
revoke all on table modificador_grupo_traducciones from anon;
revoke all on table modificador_grupos from anon;
revoke all on table modificador_opcion_traducciones from anon;
revoke all on table modificador_opciones from anon;
revoke all on table modulos from anon;
revoke all on table niveles_fidelizacion from anon;
revoke all on table order_deliveries from anon;
revoke all on table order_item_modificadores from anon;
revoke all on table order_items from anon;
revoke all on table order_sector_confirmaciones from anon;
revoke all on table orders from anon;
revoke all on table premios_fidelizacion from anon;
revoke all on table receta_items from anon;
revoke all on table resenas from anon;
revoke all on table reservations from anon;
revoke all on table restaurant_billing from anon;
revoke all on table restaurant_modulos from anon;
revoke all on table sectores_cocina from anon;
revoke all on table stock_movimientos from anon;
revoke all on table superadmins from anon;
revoke all on table table_session_payments from anon;
revoke all on table upsell_rules from anon;
revoke all on table upsell_traducciones from anon;
revoke all on table vale_movimientos from anon;
revoke all on table vales_regalo from anon;
revoke all on table waiter_calls from anon;
revoke all on table webhook_entregas from anon;
revoke all on table webhooks from anon;
revoke all on table whatsapp_sessions from anon;

-- Re-otorga exactamente lo que el código anon-facing usa hoy. Todo lo
-- demás (clientes, vales_regalo, camareros, resenas, reservations...)
-- pasa por funciones SECURITY DEFINER — no necesitan grant de tabla,
-- solo EXECUTE en la función (ya concedido en cada sql/*.sql propio).
grant select on table categories to anon;
grant select on table menu_items to anon;
grant select on table menus to anon;
grant select on table menu_item_precios_menu to anon;
grant select on table menu_item_traducciones to anon;
grant select on table categoria_traducciones to anon;
grant select on table upsell_rules to anon;
grant select on table upsell_traducciones to anon;
grant select on table menu_item_modificador_grupos to anon;
grant select on table menu_item_modificador_precios to anon;
grant select on table modificador_grupos to anon;
grant select on table modificador_opciones to anon;
grant select on table modificador_grupo_traducciones to anon;
grant select on table modificador_opcion_traducciones to anon;
grant select on table limpieza_pasos to anon;
grant insert on table waiter_calls to anon;

notify pgrst, 'reload schema';
