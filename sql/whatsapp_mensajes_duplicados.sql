-- ============================================================================
-- WhatsApp: no procesar dos veces el mismo mensaje.
--
-- WhatsApp (o el workflow que reenvía los mensajes al agente) puede entregar
-- el mismo mensaje más de una vez. El 9 nov un "sí" que confirmaba una
-- reserva llegó dos veces: la primera creó la reserva y la segunda, ya sin
-- reserva en curso, hizo contestar al agente "Veo que ya tienes una
-- reserva... ¿quieres modificarla?".
--
-- Cada mensaje de WhatsApp trae un id único (wamid). El agente llama a
-- fn_whatsapp_mensaje_nuevo(wamid) al recibirlo: devuelve true la primera
-- vez y false las siguientes, y entonces el mensaje se ignora. Se guardan
-- 3 días (los reintentos llegan en minutos).
--
-- Solo la llama n8n con la clave de servicio. Re-ejecutable.
-- Ejecutar en staging y después en producción.
-- ============================================================================

create table if not exists whatsapp_mensajes_procesados (
  wamid text primary key,
  restaurant_id uuid,
  recibido_at timestamptz not null default now()
);

create index if not exists whatsapp_mensajes_procesados_recibido_idx
  on whatsapp_mensajes_procesados (recibido_at);

-- Sin políticas: solo accesible con la clave de servicio.
alter table whatsapp_mensajes_procesados enable row level security;

create or replace function fn_whatsapp_mensaje_nuevo(
  p_wamid text,
  p_restaurant_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_insertadas int;
begin
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

revoke all on function fn_whatsapp_mensaje_nuevo(text, uuid) from public, anon, authenticated;
grant execute on function fn_whatsapp_mensaje_nuevo(text, uuid) to service_role;

notify pgrst, 'reload schema';
