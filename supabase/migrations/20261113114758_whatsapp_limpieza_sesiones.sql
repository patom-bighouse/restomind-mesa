-- =============================================================================
-- Conversaciones de WhatsApp: se borran a los 30 días sin actividad
-- (entrega 1a, punto 6; decisión 7 y S6)
-- Especificación: docs/specs/2026-11-13-agente-whatsapp-revision.md
--
-- BORRA DATOS: en cada mensaje nuevo, fn_whatsapp_mensaje_nuevo borra las filas
-- de whatsapp_sessions con updated_at de hace más de 30 días (historial de la
-- conversación con nombres, alergias…). No toca orders ni reservations.
-- No hay pg_cron en el proyecto: el borrado va con cada mensaje, igual que el
-- de los wamid de más de 3 días.
-- Misma firma y mismos grants (solo service_role). Idempotente.
-- =============================================================================

create index if not exists whatsapp_sessions_updated_at_idx on public.whatsapp_sessions (updated_at);

create or replace function public.fn_whatsapp_mensaje_nuevo (
  p_wamid         text,
  p_restaurant_id uuid default null::uuid
)
  returns boolean
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_insertadas int;
begin
  -- Conversaciones sin actividad en 30 días (aunque el mensaje no traiga wamid).
  delete from whatsapp_sessions where updated_at < now() - interval '30 days';

  if p_wamid is null or p_wamid = '' then
    return true;
  end if;
  -- Limpieza de los de hace más de 3 días.
  delete from whatsapp_mensajes_procesados where recibido_at < now() - interval '3 days';
  insert into whatsapp_mensajes_procesados (wamid, restaurant_id)
  values (p_wamid, p_restaurant_id)
  on conflict (wamid) do nothing;
  get diagnostics v_insertadas = row_count;
  return v_insertadas = 1;
end;
$$;

revoke all on function public.fn_whatsapp_mensaje_nuevo(text, uuid) from public, anon, authenticated;
grant execute on function public.fn_whatsapp_mensaje_nuevo(text, uuid) to service_role;
