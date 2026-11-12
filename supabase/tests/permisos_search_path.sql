-- =============================================================================
-- Criterio 5 de docs/specs/2026-11-11-permisos-minimos.md
-- fn_marcar_timestamp_estado_pedido(): search_path = public y sigue rellenando
-- preparando_at.
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback
-- (el pedido de prueba vuelve a como estaba).
--   npx supabase db query --remote=sfkwbhzelrestmrmptql -f supabase/tests/permisos_search_path.sql
--
-- Usa el pedido más reciente de Test: lo pasa a 'pendiente' (el trigger borra
-- las marcas) y después a 'preparando', y comprueba preparando_at.
--
-- Resultado: una fila por comprobación (prueba, ok, detalle). Debe salir ok = true en todas.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

insert into _resultado (prueba, ok, detalle)
select 'proconfig = {search_path=public}',
       coalesce(proconfig = array['search_path=public'], false),
       coalesce(proconfig::text, 'null')
from pg_proc
where oid = 'public.fn_marcar_timestamp_estado_pedido()'::regprocedure;

do $$
declare
  v_id uuid;
  v_preparando timestamptz;
begin
  select id into v_id from public.orders order by created_at desc limit 1;
  if v_id is null then
    insert into _resultado (prueba, ok, detalle) values ('pendiente → preparando rellena preparando_at', false, 'no hay pedidos en Test');
    return;
  end if;

  update public.orders set estado = 'pendiente' where id = v_id;
  update public.orders set estado = 'preparando' where id = v_id;
  select preparando_at into v_preparando from public.orders where id = v_id;

  insert into _resultado (prueba, ok, detalle)
  values ('pendiente → preparando rellena preparando_at', v_preparando is not null,
          'pedido ' || v_id || ', preparando_at = ' || coalesce(v_preparando::text, 'null'));
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL permisos_search_path', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
