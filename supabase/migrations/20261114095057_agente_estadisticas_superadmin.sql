-- =============================================================================
-- Agente de WhatsApp, entrega 1b: estadísticas de avisos para el superadmin
-- (criterio 12). Especificación: docs/specs/2026-11-13-agente-whatsapp-revision.md
--
-- NO TOCA DATOS. Crea fn_superadmin_estadisticas_agente(p_desde, p_hasta, p_zona):
--   - exige fn_es_superadmin() (si no, error 42501);
--   - cuenta los avisos de agente_errores cuyo primer registro (created_at)
--     cae entre p_desde y p_hasta (ambos incluidos; null = sin límite), con
--     los días en la zona p_zona: por defecto Europe/Madrid (regla 7, negocio
--     de Restomind: hora de España);
--   - incluye los avisos sin restaurante (restaurante "sin restaurante") y
--     los atendidos de cualquier fecha: el superadmin lo ve todo (decisión 13).
-- Devuelve una fila por grupo:
--   agrupacion = 'tipo' | 'restaurante' | 'dia' | 'semana' | 'total'
--   clave      = tipo, restaurant_id ('' si no tiene), 'YYYY-MM-DD' (la semana,
--                su lunes) o 'total'
--   nombre     = nombre legible (restaurante o la misma clave)
--   avisos     = filas de agente_errores
--   veces      = suma de `veces` (repeticiones agrupadas)
--   pendientes = avisos sin atender
-- SECURITY INVOKER: además de la comprobación, la RLS de agente_errores
-- sigue aplicando. authenticated + service_role (grupo B).
-- Idempotente.
-- =============================================================================

create or replace function public.fn_superadmin_estadisticas_agente (
  p_desde date,
  p_hasta date,
  p_zona  text default 'Europe/Madrid'
)
  returns table (
    agrupacion text,
    clave      text,
    nombre     text,
    avisos     bigint,
    veces      bigint,
    pendientes bigint
  )
  language plpgsql
  stable
  security invoker
  set search_path = public
as $function$
declare
  v_zona text := coalesce(nullif(btrim(p_zona), ''), 'Europe/Madrid');
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.' using errcode = '42501';
  end if;
  if not exists (select 1 from pg_timezone_names where name = v_zona) then
    raise exception 'Zona horaria no válida: %', v_zona using errcode = '22023';
  end if;
  if p_desde is not null and p_hasta is not null and p_desde > p_hasta then
    raise exception 'La fecha de inicio es posterior a la de fin.' using errcode = '22023';
  end if;

  return query
  with base as (
    select e.tipo, e.restaurant_id, e.veces, e.atendida,
           (e.created_at at time zone v_zona)::date as dia
    from agente_errores e
  ),
  filtrado as (
    select * from base b
    where (p_desde is null or b.dia >= p_desde)
      and (p_hasta is null or b.dia <= p_hasta)
  )
  select 'total'::text, 'total'::text, 'Total'::text,
         count(*), coalesce(sum(f.veces), 0)::bigint, count(*) filter (where not f.atendida)
  from filtrado f
  union all
  select 'tipo', f.tipo, f.tipo,
         count(*), sum(f.veces)::bigint, count(*) filter (where not f.atendida)
  from filtrado f group by f.tipo
  union all
  select 'restaurante', coalesce(f.restaurant_id::text, ''), coalesce(min(r.nombre), 'Sin restaurante'),
         count(*), sum(f.veces)::bigint, count(*) filter (where not f.atendida)
  from filtrado f left join restaurants r on r.id = f.restaurant_id
  group by f.restaurant_id
  union all
  select 'dia', to_char(f.dia, 'YYYY-MM-DD'), to_char(f.dia, 'YYYY-MM-DD'),
         count(*), sum(f.veces)::bigint, count(*) filter (where not f.atendida)
  from filtrado f group by f.dia
  union all
  select 'semana', to_char(date_trunc('week', f.dia)::date, 'YYYY-MM-DD'), to_char(date_trunc('week', f.dia)::date, 'YYYY-MM-DD'),
         count(*), sum(f.veces)::bigint, count(*) filter (where not f.atendida)
  from filtrado f group by date_trunc('week', f.dia)
  order by 1, 2;
end;
$function$;

revoke all on function public.fn_superadmin_estadisticas_agente(date, date, text) from public, anon;
grant execute on function public.fn_superadmin_estadisticas_agente(date, date, text) to authenticated, service_role;
