-- =============================================================================
-- Criterio 1 de docs/specs/2026-11-11-permisos-minimos.md
-- Grants de tabla y de columna de anon y authenticated en public.
--
-- SOLO CONTRA TEST (sfkwbhzelrestmrmptql). Todo dentro de begin … rollback.
--   npx supabase db query --remote=sfkwbhzelrestmrmptql -f supabase/tests/permisos_tablas.sql
--
-- Resultado: una fila por comprobación (prueba, ok, detalle). Debe salir ok = true
-- en todas. Las filas "diferencia" solo aparecen si algo no coincide.
--
-- Nota: los grants se leen con aclexplode(pg_class.relacl / pg_attribute.attacl)
-- en vez de information_schema, porque information_schema.column_privileges
-- mezcla los grants de tabla con los de columna y role_table_grants depende
-- del rol que consulta. El resultado es el mismo dato, sin ruido.
-- =============================================================================
begin;

create temp table _resultado (orden serial, prueba text, ok boolean, detalle text) on commit drop;

-- Lista esperada (de la tabla "Grants de tabla" de la especificación) ---------
create temp table _esperado_tabla (tabla text, rol text, privilegio text) on commit drop;
insert into _esperado_tabla (tabla, rol, privilegio)
select v.tabla, v.rol, trim(p)
from (values
  -- Avisos del agente de WhatsApp (docs/specs/2026-11-13-agente-whatsapp-revision.md):
  -- solo lectura, filtrada por RLS (dueño: visibles de su restaurante; detalle: superadmin).
  ('agente_errores',                  'authenticated', 'SELECT'),
  ('agente_errores_detalle',          'authenticated', 'SELECT'),
  ('camareros',                       'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('categoria_traducciones',          'anon',          'SELECT'),
  ('categoria_traducciones',          'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('categories',                      'anon',          'SELECT'),
  ('categories',                      'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('clientes',                        'authenticated', 'SELECT,INSERT,UPDATE'),
  ('clientes_movimientos',            'authenticated', 'SELECT,INSERT'),
  ('clientes_sellos',                 'authenticated', 'SELECT'),
  ('condiciones_aceptaciones',        'authenticated', 'SELECT'),
  ('crm_actividades',                 'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('crm_busquedas',                   'authenticated', 'SELECT'),
  ('crm_comisiones',                  'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('crm_config',                      'authenticated', 'SELECT,UPDATE'),
  ('crm_cuentas',                     'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('crm_historial',                   'authenticated', 'SELECT'),
  ('crm_tareas',                      'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('ingredientes',                    'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('limpieza_pasos',                  'anon',          'SELECT'),
  ('limpieza_pasos',                  'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('menu_item_modificador_grupos',    'anon',          'SELECT'),
  ('menu_item_modificador_grupos',    'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('menu_item_modificador_precios',   'anon',          'SELECT'),
  ('menu_item_modificador_precios',   'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('menu_item_precios_menu',          'anon',          'SELECT'),
  ('menu_item_precios_menu',          'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('menu_item_traducciones',          'anon',          'SELECT'),
  ('menu_item_traducciones',          'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('menu_items',                      'anon',          'SELECT'),
  ('menu_items',                      'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('menus',                           'anon',          'SELECT'),
  ('menus',                           'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('modificador_grupo_traducciones',  'anon',          'SELECT'),
  ('modificador_grupo_traducciones',  'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('modificador_grupos',              'anon',          'SELECT'),
  ('modificador_grupos',              'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('modificador_opcion_traducciones', 'anon',          'SELECT'),
  ('modificador_opcion_traducciones', 'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('modificador_opciones',            'anon',          'SELECT'),
  ('modificador_opciones',            'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('modulos',                         'authenticated', 'SELECT'),
  ('niveles_fidelizacion',            'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('order_deliveries',                'authenticated', 'SELECT,INSERT,UPDATE'),
  ('order_item_modificadores',        'authenticated', 'SELECT,INSERT'),
  ('order_items',                     'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('order_sector_confirmaciones',     'authenticated', 'SELECT,INSERT,UPDATE'),
  ('orders',                          'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('planes',                          'anon',          'SELECT'),
  ('planes',                          'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('premios_fidelizacion',            'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('promos_sellos',                   'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('receta_items',                    'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('resenas',                         'authenticated', 'SELECT'),
  ('reservations',                    'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('restaurant_billing',              'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('restaurant_info',                 'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('restaurant_modulos',              'authenticated', 'SELECT,INSERT,UPDATE'),
  ('restaurants',                     'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('sectores_cocina',                 'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('stock_movimientos',               'authenticated', 'SELECT,INSERT'),
  ('superadmins',                     'authenticated', 'SELECT'),
  ('table_session_payments',          'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('table_sessions',                  'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('tables',                          'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('upsell_rules',                    'anon',          'SELECT'),
  ('upsell_rules',                    'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('upsell_traducciones',             'anon',          'SELECT'),
  ('upsell_traducciones',             'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('vale_movimientos',                'authenticated', 'SELECT'),
  ('vales_regalo',                    'authenticated', 'SELECT,INSERT,UPDATE'),
  ('vendedores',                      'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('waiter_calls',                    'anon',          'INSERT'),
  ('waiter_calls',                    'authenticated', 'SELECT,INSERT,UPDATE,DELETE'),
  ('webhook_entregas',                'authenticated', 'SELECT'),
  ('webhooks',                        'authenticated', 'SELECT,INSERT,UPDATE,DELETE')
  -- Sin nada para anon ni authenticated: camarero_pin_intentos,
  -- whatsapp_mensajes_procesados, whatsapp_sessions.
) as v(tabla, rol, privs),
lateral unnest(string_to_array(v.privs, ',')) as p;

create temp table _esperado_columna (tabla text, columna text, rol text, privilegio text) on commit drop;
insert into _esperado_columna (tabla, columna, rol, privilegio)
select 'restaurants', c, 'anon', 'SELECT'
from unnest(array['id','nombre','logo_url','activo','config','direccion','moneda','slug','subdominio','whatsapp']) c
union all
select 'tables', c, 'anon', 'SELECT'
from unnest(array['id','restaurant_id','numero','zona','capacidad','activa','necesita_limpieza','limpieza_progreso']) c;

-- Lo que hay ----------------------------------------------------------------------
create temp table _real_tabla on commit drop as
select c.relname::text as tabla, pg_get_userbyid(a.grantee)::text as rol, a.privilege_type::text as privilegio
from pg_class c, aclexplode(c.relacl) a
where c.relnamespace = 'public'::regnamespace
  and c.relkind in ('r','p','v','m','f')
  and a.grantee in ('anon'::regrole, 'authenticated'::regrole)
  and not exists (select 1 from pg_depend d
                  where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e');

create temp table _real_columna on commit drop as
select c.relname::text as tabla, att.attname::text as columna, pg_get_userbyid(a.grantee)::text as rol,
       a.privilege_type::text as privilegio
from pg_class c
join pg_attribute att on att.attrelid = c.oid and att.attnum > 0 and not att.attisdropped and att.attacl is not null,
     aclexplode(att.attacl) a
where c.relnamespace = 'public'::regnamespace
  and a.grantee in ('anon'::regrole, 'authenticated'::regrole);

-- Diferencias ---------------------------------------------------------------------
insert into _resultado (prueba, ok, detalle)
select 'diferencia tabla', false, 'falta: ' || tabla || ' ' || rol || ' ' || privilegio
from (select * from _esperado_tabla except select * from _real_tabla) x
union all
select 'diferencia tabla', false, 'sobra: ' || tabla || ' ' || rol || ' ' || privilegio
from (select * from _real_tabla except select * from _esperado_tabla) x
union all
select 'diferencia columna', false, 'falta: ' || tabla || '.' || columna || ' ' || rol || ' ' || privilegio
from (select * from _esperado_columna except select * from _real_columna) x
union all
select 'diferencia columna', false, 'sobra: ' || tabla || '.' || columna || ' ' || rol || ' ' || privilegio
from (select * from _real_columna except select * from _esperado_columna) x;

insert into _resultado (prueba, ok, detalle)
select 'grants de tabla y columna = spec',
       not exists (select 1 from _resultado where prueba like 'diferencia%'),
       (select count(*) from _real_tabla) || ' filas de tabla, ' || (select count(*) from _real_columna) || ' de columna; ' ||
       (select count(*) from _resultado where prueba like 'diferencia%') || ' diferencias';

insert into _resultado (prueba, ok, detalle)
select 'sin TRUNCATE/REFERENCES/TRIGGER/MAINTAIN para anon/authenticated',
       count(*) = 0, count(*) || ' filas prohibidas'
from (select privilegio from _real_tabla union all select privilegio from _real_columna) x
where privilegio in ('TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN');

-- Comprobaciones en vivo ------------------------------------------------------------
do $$
begin
  begin
    set local role anon;
    perform user_id from public.restaurants limit 1;
    reset role;
    insert into _resultado (prueba, ok, detalle) values ('anon: select user_id from restaurants → error', false, 'no dio error');
  exception when insufficient_privilege then
    insert into _resultado (prueba, ok, detalle) values ('anon: select user_id from restaurants → error', true, sqlerrm);
  end;

  begin
    set local role anon;
    perform id from public.menu_items limit 1;
    reset role;
    insert into _resultado (prueba, ok, detalle) values ('anon: select id from menu_items → sin error', true, 'sin error');
  exception when others then
    insert into _resultado (prueba, ok, detalle) values ('anon: select id from menu_items → sin error', false, sqlerrm);
  end;
end
$$;

insert into _resultado (prueba, ok, detalle)
select 'TOTAL permisos_tablas', bool_and(coalesce(ok, false)), count(*) filter (where not coalesce(ok, false)) || ' fallos de ' || count(*)
from _resultado;

select prueba, ok, detalle from _resultado order by orden;

rollback;
