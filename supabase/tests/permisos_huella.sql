-- =============================================================================
-- Huella de permisos del esquema public (criterio 6 de
-- docs/specs/2026-11-11-permisos-minimos.md).
--
-- SOLO LECTURA: no escribe nada. Es la única prueba que se puede ejecutar
-- también en Producción (regla 1 de CLAUDE.md permite leer).
--
-- Saca una línea por objeto con sus permisos normalizados (rol=privilegios)
-- de: esquema public, tablas, columnas, funciones y pg_default_acl (de public y
-- globales), sin objetos de extensiones ni rls_auto_enable(). Las ACL nulas se
-- normalizan con acldefault() para que "sin ACL" y "ACL por defecto escrita"
-- den lo mismo. El grantor no entra en la huella (solo quién tiene qué).
--
-- Códigos de privilegio (los de Postgres): r=SELECT a=INSERT w=UPDATE d=DELETE
-- D=TRUNCATE x=REFERENCES t=TRIGGER m=MAINTAIN X=EXECUTE U=USAGE C=CREATE;
-- un "*" detrás indica WITH GRANT OPTION.
--
-- Consulta 1: resumen (filas y md5). Consulta 2: detalle, para pegar en el PR.
-- =============================================================================

-- Consulta 1: resumen -----------------------------------------------------------
with
privs as (
  -- esquema
  select 'esquema'::text as tipo, n.nspname::text as objeto, a.grantee, a.privilege_type, a.is_grantable
  from pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) a
  where n.nspname = 'public'
  union all
  -- tablas, vistas, secuencias
  select 'tabla', c.relname::text, a.grantee, a.privilege_type, a.is_grantable
  from pg_class c,
       aclexplode(coalesce(c.relacl, acldefault(case when c.relkind = 'S' then 's' else 'r' end::"char", c.relowner))) a
  where c.relnamespace = 'public'::regnamespace
    and c.relkind in ('r','p','v','m','S','f')
    and not exists (select 1 from pg_depend d
                    where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  union all
  -- columnas (solo las que tienen grants propios)
  select 'columna', c.relname || '.' || att.attname, a.grantee, a.privilege_type, a.is_grantable
  from pg_class c
  join pg_attribute att on att.attrelid = c.oid and att.attnum > 0 and not att.attisdropped and att.attacl is not null,
       aclexplode(att.attacl) a
  where c.relnamespace = 'public'::regnamespace
    and c.relkind in ('r','p','v','m','f')
    and not exists (select 1 from pg_depend d
                    where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  union all
  -- funciones
  select 'funcion', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', a.grantee, a.privilege_type, a.is_grantable
  from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
  where p.pronamespace = 'public'::regnamespace
    and p.proname <> 'rls_auto_enable'
    and not exists (select 1 from pg_depend d
                    where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  union all
  -- privilegios por defecto (de public y globales)
  select 'defecto', pg_get_userbyid(da.defaclrole) || ' ' ||
         case when da.defaclnamespace = 0 then 'GLOBAL' else da.defaclnamespace::regnamespace::text end || ' ' ||
         da.defaclobjtype::text,
         a.grantee, a.privilege_type, a.is_grantable
  from pg_default_acl da, aclexplode(da.defaclacl) a
  where da.defaclnamespace in (0, 'public'::regnamespace)
),
codigos(privilege_type, codigo) as (values
  ('SELECT','r'),('INSERT','a'),('UPDATE','w'),('DELETE','d'),('TRUNCATE','D'),
  ('REFERENCES','x'),('TRIGGER','t'),('MAINTAIN','m'),('EXECUTE','X'),('USAGE','U'),('CREATE','C')
),
por_rol as (
  select p.tipo, p.objeto,
         case when p.grantee = 0 then 'PUBLIC' else pg_get_userbyid(p.grantee)::text end as rol,
         string_agg(distinct coalesce(k.codigo, p.privilege_type) || case when p.is_grantable then '*' else '' end, '') as privs
  from privs p left join codigos k using (privilege_type)
  group by 1, 2, 3
),
lineas as (
  select tipo, objeto,
         string_agg(rol || '=' || (select string_agg(ch, '' order by ch collate "C")
                                   from regexp_split_to_table(privs, '(?=[a-zA-Z])') ch),
                    ' ' order by rol collate "C") as permisos
  from por_rol
  group by 1, 2
)
select count(*) as filas,
       md5(string_agg(tipo || '|' || objeto || '|' || permisos, E'\n' order by tipo collate "C", objeto collate "C")) as huella
from lineas;

-- Consulta 2: detalle -----------------------------------------------------------
with
privs as (
  select 'esquema'::text as tipo, n.nspname::text as objeto, a.grantee, a.privilege_type, a.is_grantable
  from pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) a
  where n.nspname = 'public'
  union all
  select 'tabla', c.relname::text, a.grantee, a.privilege_type, a.is_grantable
  from pg_class c,
       aclexplode(coalesce(c.relacl, acldefault(case when c.relkind = 'S' then 's' else 'r' end::"char", c.relowner))) a
  where c.relnamespace = 'public'::regnamespace
    and c.relkind in ('r','p','v','m','S','f')
    and not exists (select 1 from pg_depend d
                    where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  union all
  select 'columna', c.relname || '.' || att.attname, a.grantee, a.privilege_type, a.is_grantable
  from pg_class c
  join pg_attribute att on att.attrelid = c.oid and att.attnum > 0 and not att.attisdropped and att.attacl is not null,
       aclexplode(att.attacl) a
  where c.relnamespace = 'public'::regnamespace
    and c.relkind in ('r','p','v','m','f')
    and not exists (select 1 from pg_depend d
                    where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  union all
  select 'funcion', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', a.grantee, a.privilege_type, a.is_grantable
  from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
  where p.pronamespace = 'public'::regnamespace
    and p.proname <> 'rls_auto_enable'
    and not exists (select 1 from pg_depend d
                    where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  union all
  select 'defecto', pg_get_userbyid(da.defaclrole) || ' ' ||
         case when da.defaclnamespace = 0 then 'GLOBAL' else da.defaclnamespace::regnamespace::text end || ' ' ||
         da.defaclobjtype::text,
         a.grantee, a.privilege_type, a.is_grantable
  from pg_default_acl da, aclexplode(da.defaclacl) a
  where da.defaclnamespace in (0, 'public'::regnamespace)
),
codigos(privilege_type, codigo) as (values
  ('SELECT','r'),('INSERT','a'),('UPDATE','w'),('DELETE','d'),('TRUNCATE','D'),
  ('REFERENCES','x'),('TRIGGER','t'),('MAINTAIN','m'),('EXECUTE','X'),('USAGE','U'),('CREATE','C')
),
por_rol as (
  select p.tipo, p.objeto,
         case when p.grantee = 0 then 'PUBLIC' else pg_get_userbyid(p.grantee)::text end as rol,
         string_agg(distinct coalesce(k.codigo, p.privilege_type) || case when p.is_grantable then '*' else '' end, '') as privs
  from privs p left join codigos k using (privilege_type)
  group by 1, 2, 3
),
lineas as (
  select tipo, objeto,
         string_agg(rol || '=' || (select string_agg(ch, '' order by ch collate "C")
                                   from regexp_split_to_table(privs, '(?=[a-zA-Z])') ch),
                    ' ' order by rol collate "C") as permisos
  from por_rol
  group by 1, 2
)
select tipo, objeto, permisos
from lineas
order by tipo collate "C", objeto collate "C";
