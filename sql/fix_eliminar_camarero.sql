-- ============================================================================
-- Bug: no se podía eliminar un camarero/personal con PIN si tenía algún
-- pedido a su nombre (orders.tomado_por referencia camareros(id) sin
-- "on delete", así que por defecto Postgres bloquea el borrado). El
-- propio mensaje de confirmación en AdminConfig.jsx ya prometía que
-- "los pedidos que ya cargó quedan igual en el historial" — para que
-- eso sea cierto, la referencia debe quedar en null, no bloquear el
-- borrado.
-- ============================================================================

do $$
declare
  v_conname text;
begin
  select conname into v_conname
  from pg_constraint
  where conrelid = 'public.orders'::regclass
    and confrelid = 'public.camareros'::regclass
    and contype = 'f';
  if v_conname is not null then
    execute format('alter table public.orders drop constraint %I', v_conname);
  end if;
end $$;

alter table public.orders
  add constraint orders_tomado_por_fkey foreign key (tomado_por) references public.camareros(id) on delete set null;

-- Por si table_sessions.camarero_id también quedó con una referencia
-- sin "on delete" (se creó fuera de los .sql versionados) — mismo
-- criterio: si el camarero se borra, la sesión de mesa queda sin
-- dueño en vez de bloquear el borrado.
do $$
declare
  v_conname text;
begin
  select conname into v_conname
  from pg_constraint
  where conrelid = 'public.table_sessions'::regclass
    and confrelid = 'public.camareros'::regclass
    and contype = 'f';
  if v_conname is not null then
    execute format('alter table public.table_sessions drop constraint %I', v_conname);
    execute format('alter table public.table_sessions add constraint %I foreign key (camarero_id) references public.camareros(id) on delete set null', v_conname);
  end if;
end $$;
