grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;

revoke select on restaurants from anon;
grant select (id, nombre, logo_url) on restaurants to anon;

revoke select on tables from anon;
grant select (id, restaurant_id, numero, zona, capacidad, activa) on tables to anon;

revoke select on table_sessions from anon;
grant select (id, table_id, restaurant_id, estado, abierta_at) on table_sessions to anon;
