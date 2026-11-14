-- =============================================================================
-- Criterio 3 de docs/specs/2026-11-11-permisos-minimos.md
-- service_role: los 8 privilegios en todas las tablas de public y EXECUTE en
-- las 83 funciones no trigger (81 de permisos mínimos + fn_camarero_cerrar_sesion
-- y fn_staff_exigir_sesion de docs/specs/2026-11-12-pin-camarero.md).
-- Actualizado con docs/specs/2026-11-13-agente-whatsapp-revision.md: 86 funciones
-- (+ fn_pedido_whatsapp_crear, fn_agente_registrar_error y
-- fn_agente_error_marcar_atendida; 87 con la versión con clave de
-- fn_reserva_whatsapp_crear; 89 en la entrega 1b con fn_agente_datos_restaurante
-- y fn_superadmin_estadisticas_agente) y excepción en agente_errores y
-- agente_errores_detalle: service_role solo SELECT, INSERT y UPDATE (no se
-- borra ninguna fila, decisión 13).
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql -f supabase/tests/permisos_service_role.sql
--
-- Resultado: una fila por comprobación (prueba, ok, detalle). Debe salir ok = true en todas.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

create temp table _tablas on commit drop as
select c.oid, c.relname::text as tabla, c.relacl, c.relowner
from pg_class c
where c.relnamespace = 'public'::regnamespace
  and c.relkind in ('r','p','v','m','f')
  and not exists (select 1 from pg_depend d
                  where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e');

create temp table _sin_todo on commit drop as
select t.tabla,
       array(select p from unnest(case when t.tabla in ('agente_errores', 'agente_errores_detalle')
                                       then array['SELECT','INSERT','UPDATE']
                                       else array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'] end) p
             except
             select a.privilege_type from aclexplode(coalesce(t.relacl, acldefault('r', t.relowner))) a
             where a.grantee = 'service_role'::regrole) as faltan
from _tablas t;

insert into _resultado (prueba, ok, detalle)
select 'diferencia', false, 'a service_role le falta en ' || tabla || ': ' || array_to_string(faltan, ',')
from _sin_todo where cardinality(faltan) > 0;

insert into _resultado (prueba, ok, detalle)
select 'agente_errores y su detalle: service_role sin DELETE ni TRUNCATE',
       count(*) = 0, count(*) || ' privilegios de más'
from _tablas t, aclexplode(coalesce(t.relacl, acldefault('r', t.relowner))) a
where t.tabla in ('agente_errores', 'agente_errores_detalle')
  and a.grantee = 'service_role'::regrole
  and a.privilege_type not in ('SELECT', 'INSERT', 'UPDATE');

insert into _resultado (prueba, ok, detalle)
select 'tablas sin los 8 privilegios para service_role = 0 (salvo las 2 de avisos: 3)',
       count(*) filter (where cardinality(faltan) > 0) = 0,
       count(*) filter (where cardinality(faltan) > 0) || ' de ' || count(*) || ' tablas'
from _sin_todo;

create temp table _funciones on commit drop as
select p.oid, p.proname::text as funcion, p.proacl, p.proowner
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.prorettype <> 'trigger'::regtype
  and p.proname <> 'rls_auto_enable'
  and not exists (select 1 from pg_depend d
                  where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e');

insert into _resultado (prueba, ok, detalle)
select 'diferencia', false, 'service_role sin EXECUTE en ' || f.funcion
from _funciones f
where not exists (select 1 from aclexplode(coalesce(f.proacl, acldefault('f', f.proowner))) a
                  where a.grantee = 'service_role'::regrole and a.privilege_type = 'EXECUTE');

insert into _resultado (prueba, ok, detalle)
select 'funciones no trigger sin EXECUTE para service_role = 0 (de 89)',
       count(*) = 89 and not exists (select 1 from _resultado where detalle like 'service_role sin EXECUTE%'),
       count(*) || ' funciones no trigger; ' ||
       (select count(*) from _resultado where detalle like 'service_role sin EXECUTE%') || ' sin EXECUTE'
from _funciones;

do $$
declare
  n bigint;
begin
  begin
    set local role service_role;
    select count(*) into n from public.whatsapp_sessions;
    reset role;
    insert into _resultado (prueba, ok, detalle) values ('service_role: select count(*) from whatsapp_sessions → sin error', true, n || ' filas');
  exception when others then
    insert into _resultado (prueba, ok, detalle) values ('service_role: select count(*) from whatsapp_sessions → sin error', false, sqlerrm);
  end;
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL permisos_service_role', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
