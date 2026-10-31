-- ============================================================================
-- El agente de WhatsApp (n8n) identificaba a qué restaurante pertenece
-- un mensaje mirando el número de quien ESCRIBE (el cliente) — eso
-- solo "funcionaba" en pruebas porque el restaurante de prueba tenía
-- cargado el propio teléfono del que probaba. Con clientes reales
-- nunca iba a poder identificar el restaurante correcto, porque cada
-- cliente tiene un número distinto.
--
-- Meta manda en cada mensaje un "phone_number_id": el ID del número
-- de WhatsApp AL QUE le escribieron (no quién escribe) — ese es el
-- dato correcto para identificar el restaurante, y es lo que ahora
-- usa el enrutador de n8n en vez del número del remitente.
--
-- Esta columna la completa el dueño de Restomind (no el restaurante)
-- al conectar el número real de cada restaurante en Meta — se
-- consigue en Meta for Developers > WhatsApp > API Setup, campo
-- "Phone number ID".
-- ============================================================================

alter table restaurants add column if not exists whatsapp_phone_number_id text;

create unique index if not exists restaurants_whatsapp_phone_number_id_unique
  on restaurants (whatsapp_phone_number_id)
  where whatsapp_phone_number_id is not null;
