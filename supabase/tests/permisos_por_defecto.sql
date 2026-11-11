-- =============================================================================
-- Criterio 4 de docs/specs/2026-11-11-permisos-minimos.md
-- Privilegios por defecto: lo que crea postgres en public nace cerrado salvo
-- para service_role.
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback
-- (la tabla y la función de prueba no quedan creadas).
--   npx supabase db query --remote=sfkwbhzelrestmrmptql -f supabase/tests/permisos_por_defecto.sql
--
-- Resultado: una fila por comprobación (prueba, ok, detalle). Debe salir ok = true en todas.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

-- Objetos nuevos (se deshacen con el rollback) ----------------------------------------
create table public.zz_prueba (id int);
create function public.zz_f() returns int language sql as 'select 1';

create temp table _acl_tabla on commit drop as
select pg_get_userbyid(a.grantee)::text as rol, a.privilege_type::text as privilegio
from pg_class c, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
where c.oid = 'public.zz_prueba'::regclass;

create temp table _acl_funcion on commit drop as
select case when a.grantee = 0 then 'PUBLIC' else pg_get_userbyid(a.grantee)::text end as rol, a.privilege_type::text as privilegio
from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
where p.oid = 'public.zz_f()'::regprocedure;

insert into _resultado (prueba, ok, detalle)
select 'tabla nueva: solo postgres (dueño) y service_role, con los 8 privilegios',
       (select array_agg(distinct rol order by rol) from _acl_tabla) = array['postgres','service_role']
       and (select count(*) from _acl_tabla where rol = 'service_role') = 8,
       (select string_agg(rol || ':' || privilegio, ' ' order by rol, privilegio) from _acl_tabla);

insert into _resultado (prueba, ok, detalle)
select 'función nueva: EXECUTE solo para postgres y service_role',
       (select array_agg(distinct rol order by rol) from _acl_funcion) = array['postgres','service_role'],
       (select string_agg(rol || ':' || privilegio, ' ' order by rol) from _acl_funcion);

-- pg_default_acl de postgres (global y public) ------------------------------------------
create temp table _esperado (entrada text, rol text, privilegio text) on commit drop;
insert into _esperado values
  ('GLOBAL f', 'postgres', 'EXECUTE'),
  ('public f', 'postgres', 'EXECUTE'), ('public f', 'service_role', 'EXECUTE'),
  ('public S', 'postgres', 'SELECT'), ('public S', 'postgres', 'UPDATE'), ('public S', 'postgres', 'USAGE'),
  ('public S', 'service_role', 'SELECT'), ('public S', 'service_role', 'UPDATE'), ('public S', 'service_role', 'USAGE');
insert into _esperado
select 'public r', r, p
from unnest(array['postgres','service_role']) r,
     unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) p;

create temp table _real on commit drop as
select case when da.defaclnamespace = 0 then 'GLOBAL' else da.defaclnamespace::regnamespace::text end
         || ' ' || da.defaclobjtype::text as entrada,
       case when a.grantee = 0 then 'PUBLIC' else pg_get_userbyid(a.grantee)::text end as rol,
       a.privilege_type::text as privilegio
from pg_default_acl da, aclexplode(da.defaclacl) a
where da.defaclrole = 'postgres'::regrole
  and da.defaclnamespace in (0, 'public'::regnamespace);

insert into _resultado (prueba, ok, detalle)
select 'diferencia', false, 'falta: ' || entrada || ' ' || rol || ' ' || privilegio
from (select * from _esperado except select * from _real) x
union all
select 'diferencia', false, 'sobra: ' || entrada || ' ' || rol || ' ' || privilegio
from (select * from _real except select * from _esperado) x;

insert into _resultado (prueba, ok, detalle)
select 'pg_default_acl de postgres = esperado',
       not exists (select 1 from _resultado where prueba = 'diferencia'),
       (select count(*) from _real) || ' filas; ' ||
       (select count(*) from _resultado where prueba = 'diferencia') || ' diferencias';

insert into _resultado (prueba, ok, detalle)
select 'TOTAL permisos_por_defecto', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
