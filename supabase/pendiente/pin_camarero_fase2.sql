-- =============================================================================
-- BORRADOR — Sesión de camarero con PIN — FASE 2 (token obligatorio)
-- Spec: docs/specs/2026-11-12-pin-camarero.md ("PR 2")
--
-- NO es una migración todavía: está fuera de supabase/migrations/ a propósito,
-- para que `db push` no la aplique junto con la fase 1 (no habría transición).
--
-- Cuándo (decisión 2 de la spec):
--   * Test: justo después de validar la fase 1 (criterio 7).
--   * Producción: cuando camarero_llamadas_sin_token no tenga llamadas en las
--     últimas 24 h (consulta de solo lectura del orquestador):
--       select restaurant_id, funcion, llamadas, ultima_llamada
--       from camarero_llamadas_sin_token
--       where ultima_llamada > now() - interval '24 hours';
--     Mientras en Producción solo haya restaurantes de prueba, en cuanto la
--     fase 1 esté comprobada allí.
--
-- Cómo (en el PR 2):
--   npx supabase migration new pin_camarero_fase2
--   copiar este archivo en supabase/migrations/<ts>_pin_camarero_fase2.sql
--   (quitando este encabezado de borrador) y aplicarlo con db push, primero
--   en Test y luego en Producción.
--
-- Cambios: solo reescribe fn_staff_exigir_sesion para rechazar el token nulo
-- (RM401) y borra camarero_llamadas_sin_token. No toca firmas ni el front.
-- Vuelta atrás: supabase/rollback/pin_camarero_fase2_revertir.sql
-- =============================================================================

create or replace function public.fn_staff_exigir_sesion(
  p_restaurant_id uuid,
  p_camarero_id uuid,
  p_token text,
  p_permisos text[],
  p_funcion text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  v_permisos text[];
begin
  -- Sesión: token de una sesión viva de ese camarero y ese restaurante, con el
  -- camarero activo y el restaurante activo. Sin token → RM401.
  if p_token is not null then
    select c.permisos into v_permisos
    from camarero_sesiones s
    join camareros c on c.id = s.camarero_id
    join restaurants r on r.id = s.restaurant_id
    where s.token_hash = encode(digest(p_token, 'sha256'), 'hex')
      and s.camarero_id = p_camarero_id
      and s.restaurant_id = p_restaurant_id
      and c.restaurant_id = p_restaurant_id
      and s.revocada_at is null
      and s.caduca_at > now()
      and c.activo = true
      and coalesce(r.activo, true) = true;
  end if;

  if p_token is null or not found then
    raise exception 'Tu sesión ha caducado. Recarga la página y vuelve a introducir tu PIN.'
      using errcode = 'RM401';
  end if;

  if coalesce(cardinality(p_permisos), 0) > 0 and not (coalesce(v_permisos, '{}'::text[]) && p_permisos) then
    raise exception 'No autorizado';
  end if;
end;
$function$;

revoke all on function public.fn_staff_exigir_sesion(uuid, uuid, text, text[], text) from public, anon, authenticated;
grant execute on function public.fn_staff_exigir_sesion(uuid, uuid, text, text[], text) to service_role;

drop table if exists public.camarero_llamadas_sin_token;

notify pgrst, 'reload schema';
