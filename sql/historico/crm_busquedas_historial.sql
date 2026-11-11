-- ============================================================================
-- CRM: historial de búsquedas de restaurantes.
--
-- Cada búsqueda guarda también los locales que trajo Google, para poder
-- volver a abrirla desde "Búsquedas recientes" sin gastar consultas.
-- Los locales se borran a los 30 días (las condiciones de Google no permiten
-- guardar sus datos indefinidamente); la fila de la búsqueda se conserva
-- porque el contador de consultas del mes la necesita. Lo importado al CRM
-- no se toca.
--
-- Re-ejecutable. Ejecutar después de crm_buscador.sql, en staging y en
-- producción, ANTES de desplegar la nueva versión de la Edge Function
-- crm-buscar-restaurantes.
-- ============================================================================

alter table crm_busquedas add column if not exists locales jsonb;

-- Cambia el tipo de retorno (void → uuid): hay que borrar la anterior.
drop function if exists fn_crm_registrar_busqueda(jsonb, integer, integer);

create or replace function fn_crm_registrar_busqueda(
  p_parametros jsonb, p_consultas integer, p_resultados integer, p_locales jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id uuid;
begin
  if not fn_crm_puede_buscar() then
    raise exception 'No tienes permiso para buscar restaurantes.';
  end if;

  -- Caducidad de los datos de Google.
  update crm_busquedas set locales = null
  where locales is not null and created_at < now() - interval '30 days';

  insert into crm_busquedas (user_id, autor_nombre, parametros, consultas, resultados, locales)
  values (
    auth.uid(),
    coalesce((select v.nombre from vendedores v where v.user_id = auth.uid() limit 1), 'Superadmin'),
    coalesce(p_parametros, '{}'::jsonb),
    greatest(coalesce(p_consultas, 0), 0),
    greatest(coalesce(p_resultados, 0), 0),
    p_locales
  )
  returning id into v_id;
  return v_id;
end;
$$;

-- Búsquedas que aún se pueden reabrir. El superadmin ve todas; un vendedor
-- (si algún día puede buscar) solo las suyas.
create or replace function fn_crm_busquedas_recientes()
returns table (id uuid, parametros jsonb, resultados integer, autor_nombre text, created_at timestamp with time zone)
language sql
stable
security definer
set search_path to 'public'
as $$
  select b.id, b.parametros, b.resultados, b.autor_nombre, b.created_at
  from crm_busquedas b
  where fn_crm_puede_buscar()
    and (fn_es_superadmin() or b.user_id = auth.uid())
    and b.locales is not null
    and b.resultados > 0
    and b.created_at >= now() - interval '30 days'
  order by b.created_at desc
  limit 20
$$;

-- Reabre una búsqueda guardada. Recalcula "ya en el CRM" con los datos de
-- hoy: lo importado después de buscar sale marcado.
create or replace function fn_crm_busqueda_cargar(p_id uuid)
returns table (parametros jsonb, locales jsonb, created_at timestamp with time zone)
language sql
stable
security definer
set search_path to 'public'
as $$
  with b as (
    select b.parametros, b.locales, b.created_at
    from crm_busquedas b
    where b.id = p_id
      and fn_crm_puede_buscar()
      and (fn_es_superadmin() or b.user_id = auth.uid())
      and b.locales is not null
      and b.created_at >= now() - interval '30 days'
  ), dups as (
    select d.place_id, d.motivo from b, fn_crm_duplicados(b.locales) d
  )
  select b.parametros,
         coalesce((
           select jsonb_agg(x.local || jsonb_build_object('duplicado', d.motivo) order by x.n)
           from jsonb_array_elements(b.locales) with ordinality as x(local, n)
           left join dups d on d.place_id = x.local->>'place_id'
         ), '[]'::jsonb),
         b.created_at
  from b
$$;

revoke execute on function fn_crm_registrar_busqueda(jsonb, integer, integer, jsonb) from public, anon;
revoke execute on function fn_crm_busquedas_recientes() from public, anon;
revoke execute on function fn_crm_busqueda_cargar(uuid) from public, anon;
grant execute on function fn_crm_registrar_busqueda(jsonb, integer, integer, jsonb) to authenticated;
grant execute on function fn_crm_busquedas_recientes() to authenticated;
grant execute on function fn_crm_busqueda_cargar(uuid) to authenticated;
