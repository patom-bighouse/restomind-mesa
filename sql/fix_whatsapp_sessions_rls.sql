-- whatsapp_sessions no tenía RLS habilitado (alerta de seguridad de
-- Supabase: "Table publicly accessible" / rls_disabled_in_public).
-- Con la anon key (pública, va embebida en cualquier cliente) cualquiera
-- podía leer, editar o borrar el historial de conversaciones de WhatsApp
-- de cualquier restaurante.
--
-- Esta tabla la usa exclusivamente el agente de n8n, con la service_role
-- key (que siempre evita RLS) — no hace falta ninguna policy para
-- anon/authenticated, alcanza con negarles el acceso por completo.

alter table whatsapp_sessions enable row level security;

revoke all on table whatsapp_sessions from anon;
revoke all on table whatsapp_sessions from authenticated;
