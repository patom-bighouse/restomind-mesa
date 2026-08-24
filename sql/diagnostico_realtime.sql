-- ============================================================================
-- Diagnóstico + fix: confirma qué tablas están agregadas a la
-- publicación de Realtime de Supabase, y agrega las que falten.
-- Útil para chequear un proyecto (como test) que puede haber quedado
-- incompleto respecto a producción.
-- ============================================================================

-- PASO 1: ver qué hay agregado ahora mismo
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public'
order by tablename;

-- Deberían estar (comparado con lo que usa la app hoy):
--   categories, menu_items, order_items, orders, reservations,
--   table_session_payments, table_sessions, tables, waiter_calls

-- PASO 2: agregar las que falten (no rompe nada si ya estaban —
-- el chequeo previo evita el error de "ya es miembro")
do $$
declare
  t text;
begin
  foreach t in array array['categories','menu_items','order_items','orders','table_session_payments','table_sessions','tables','waiter_calls']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;
