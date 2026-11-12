-- Fix (v2): hmac() vive en el esquema "extensions" en Supabase, no en
-- "public" — la función definía search_path solo a 'public' y por
-- eso no la encontraba ("function hmac(bytea, bytea, unknown) does
-- not exist"), aunque pgcrypto sí estuviera instalada.
create or replace function fn_disparar_webhooks(p_restaurant_id uuid, p_evento text, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_webhook record;
  v_cuerpo jsonb;
  v_firma text;
  v_request_id bigint;
begin
  for v_webhook in
    select id, url, secreto from webhooks
    where restaurant_id = p_restaurant_id and activo = true and p_evento = any(eventos)
  loop
    v_cuerpo := jsonb_build_object(
      'evento', p_evento,
      'restaurant_id', p_restaurant_id,
      'timestamp', extract(epoch from now())::bigint,
      'datos', p_payload
    );
    v_firma := encode(hmac(v_cuerpo::text::bytea, v_webhook.secreto::bytea, 'sha256'), 'hex');

    select net.http_post(
      url := v_webhook.url,
      body := v_cuerpo,
      headers := jsonb_build_object('Content-Type', 'application/json', 'X-Restomind-Signature', v_firma)
    ) into v_request_id;

    insert into webhook_entregas (webhook_id, evento, payload, request_id)
    values (v_webhook.id, p_evento, v_cuerpo, v_request_id);
  end loop;
end;
$$;
