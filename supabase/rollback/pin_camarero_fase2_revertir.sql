-- =============================================================================
-- VUELTA ATRÁS de la FASE 2 de la sesión de camarero con PIN
-- (docs/specs/2026-11-12-pin-camarero.md, "Despliegue y vuelta atrás").
--
-- NO es una migración: no está en supabase/migrations/ a propósito. Es la
-- salida rápida si, tras aplicar la fase 2, algún restaurante no puede
-- trabajar (p. ej. una tablet con la versión vieja de la app que no se puede
-- recargar): vuelve a poner fn_staff_exigir_sesion en MODO TOLERANTE (token
-- nulo = comprobación de antes + anotación) y vuelve a crear
-- camarero_llamadas_sin_token. Es una sola función: efecto inmediato, sin
-- tocar el front ni las firmas.
--
-- Contenido = secciones "camarero_llamadas_sin_token" y "2." de
-- supabase/migrations/20261112152109_pin_camarero_fase1.sql, sin cambios.
--
-- Cómo aplicarlo (siempre como migración, regla 1 de CLAUDE.md):
--   1. npx supabase migration new revertir_pin_camarero_fase2
--      y copiar este archivo en supabase/migrations/<ts nuevo>_revertir_pin_camarero_fase2.sql
--      QUITANDO las líneas `begin;` y `commit;` (db push ya va en transacción).
--   2. Test:        npx supabase db push --remote=sfkwbhzelrestmrmptql --dry-run && npx supabase db push --remote=sfkwbhzelrestmrmptql
--   3. Producción:  npx supabase db push --remote=mfxrluanpawfjncpqrvu --dry-run && npx supabase db push --remote=mfxrluanpawfjncpqrvu
--   4. Comprobar:   supabase/tests/pin_camarero_fase1.sql en Test (todo ok).
-- =============================================================================
begin;

-- Solo fase 1: llamadas que llegan sin token (versión vieja de la app abierta).
-- Se borra en la fase 2.
create table if not exists public.camarero_llamadas_sin_token (
  restaurant_id  uuid        not null references public.restaurants(id) on delete cascade,
  funcion        text        not null,
  llamadas       integer     not null default 0,
  ultima_llamada timestamptz not null default now(),
  primary key (restaurant_id, funcion)
);

alter table public.camarero_llamadas_sin_token enable row level security;

drop policy if exists "camarero_llamadas_sin_token: el dueño lee las de su restaurante" on public.camarero_llamadas_sin_token;
create policy "camarero_llamadas_sin_token: el dueño lee las de su restaurante"
  on public.camarero_llamadas_sin_token for select to authenticated
  using (restaurant_id in (select r.id from public.restaurants r where r.user_id = auth.uid()));

revoke all on table public.camarero_llamadas_sin_token from public, anon, authenticated;
grant all on table public.camarero_llamadas_sin_token to service_role;

-- 2. fn_staff_exigir_sesion (grupo C: solo service_role y postgres) -------------
-- La llaman al principio todas las funciones del camarero.
--   p_permisos: basta con tener uno de ellos; vacío = solo sesión válida.
--   Sesión no válida → errcode RM401. Sesión válida sin permiso → 'No autorizado'.
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
  -- FASE 1 (tolerante): sin token = versión anterior de la app. Se anota y se
  -- hace la comprobación de antes. La fase 2 sustituye este bloque por un RM401.
  if p_token is null then
    insert into camarero_llamadas_sin_token (restaurant_id, funcion, llamadas, ultima_llamada)
    select p_restaurant_id, coalesce(p_funcion, '?'), 1, now()
    where exists (select 1 from restaurants r where r.id = p_restaurant_id)
    on conflict (restaurant_id, funcion) do update
      set llamadas = camarero_llamadas_sin_token.llamadas + 1,
          ultima_llamada = now();

    if p_camarero_id is null then
      -- Estas tres no comprobaban nada cuando no llegaba camarero.
      if p_funcion in ('fn_camarero_listar_sesiones', 'fn_camarero_toggle_limpieza', 'fn_camarero_abrir_mesa') then
        return;
      end if;
      raise exception 'No autorizado';
    end if;

    if coalesce(cardinality(p_permisos), 0) = 0 then
      return;  -- fn_staff_contar_alertas: cuenta según permisos ella misma
    end if;

    if not exists (select 1 from unnest(p_permisos) as x(permiso)
                   where fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, x.permiso)) then
      raise exception 'No autorizado';
    end if;
    return;
  end if;

  -- Con token: tiene que ser una sesión viva de ese camarero y ese restaurante,
  -- con el camarero activo y el restaurante activo.
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

  if not found then
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

notify pgrst, 'reload schema';

commit;
