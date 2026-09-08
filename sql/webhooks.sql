-- ============================================================================
-- Webhooks para integraciones externas (#24 del roadmap): el
-- restaurante configura una o varias URLs propias, y Restomind les
-- avisa —firmado con HMAC-SHA256— cada vez que pasa algo relevante
-- (pedido nuevo, pago recibido, reserva creada, llamada al camarero).
-- Pensado para conectar con Zapier/Make, su propio ERP, un canal de
-- Slack, etc. sin que tengamos que integrar cada herramienta a mano.
--
-- Módulo de pago — pensado para cuentas más avanzadas/técnicas.
--
-- El envío se hace con pg_net (asíncrono, no bloquea la transacción
-- que originó el evento) desde triggers en las tablas relevantes, así
-- se dispara sin importar qué función/pantalla haya creado la fila —
-- no hay que acordarse de llamarlo desde cada lugar nuevo que cree un
-- pedido/pago/reserva.
-- ============================================================================

create extension if not exists pg_net;
create extension if not exists pgcrypto;

insert into modulos (key, nombre, descripcion, requiere, orden) values
  ('webhooks', 'Webhooks para integraciones externas', 'Notifica en tiempo real a una URL propia (Zapier, tu ERP, Slack...) cada vez que hay un pedido, un pago, una reserva o una llamada al camarero.', 'nucleo', 8)
on conflict (key) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  requiere = excluded.requiere,
  orden = excluded.orden;

create table webhooks (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  url text not null,
  secreto text not null,
  eventos text[] not null default '{}',
  activo boolean not null default true,
  created_at timestamp with time zone not null default now()
);

alter table webhooks enable row level security;
grant select, insert, update, delete on table webhooks to authenticated;

drop policy if exists webhooks_dueno on webhooks;
create policy webhooks_dueno on webhooks for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- Registro de cada intento de envío — qué se mandó y cuándo. No
-- guarda el código de respuesta real: pg_net solo conserva esa
-- información un puñado de horas, así que para confirmar que a un
-- endpoint le llegó de verdad, se revisa del lado receptor (ej.
-- webhook.site al probar).
create table webhook_entregas (
  id uuid primary key default gen_random_uuid(),
  webhook_id uuid not null references webhooks(id) on delete cascade,
  evento text not null,
  payload jsonb not null,
  request_id bigint,
  created_at timestamp with time zone not null default now()
);

alter table webhook_entregas enable row level security;
grant select on table webhook_entregas to authenticated;

drop policy if exists webhook_entregas_dueno on webhook_entregas;
create policy webhook_entregas_dueno on webhook_entregas for all
  using (
    exists (
      select 1 from webhooks w
      join restaurants r on r.id = w.restaurant_id
      where w.id = webhook_entregas.webhook_id
        and (r.user_id = auth.uid() or exists (select 1 from superadmins s where s.user_id = auth.uid()))
    )
  );

-- Dispara todos los webhooks activos de un restaurante suscritos a
-- p_evento. SECURITY DEFINER porque se llama desde triggers en tablas
-- (orders, table_session_payments...) que anon no puede leer/escribir
-- directo — necesita poder leer la tabla webhooks igual.
create or replace function fn_disparar_webhooks(p_restaurant_id uuid, p_evento text, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path to 'public'
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
    -- Firma HMAC-SHA256 del cuerpo tal cual se envía, para que quien
    -- lo reciba pueda verificar que viene de verdad de Restomind.
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

-- ----------------------------------------------------------------------------
-- Triggers: uno por tabla/evento, todos siguen el mismo patrón. Van
-- en la tabla en sí (no en las funciones que la escriben) para que
-- disparen sin importar qué función haya insertado la fila.
-- ----------------------------------------------------------------------------

create or replace function fn_trigger_webhook_order_placed()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform fn_disparar_webhooks(
    new.restaurant_id,
    'order.placed',
    jsonb_build_object(
      'order_id', new.id,
      'table_id', new.table_id,
      'tipo', new.tipo,
      'estado', new.estado,
      'created_at', new.created_at
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_webhook_order_placed on orders;
create trigger trg_webhook_order_placed
  after insert on orders
  for each row
  execute function fn_trigger_webhook_order_placed();

create or replace function fn_trigger_webhook_payment_received()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform fn_disparar_webhooks(
    new.restaurant_id,
    'payment.received',
    jsonb_build_object(
      'payment_id', new.id,
      'table_session_id', new.table_session_id,
      'monto', new.monto,
      'metodo_pago', new.metodo_pago,
      'created_at', new.created_at
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_webhook_payment_received on table_session_payments;
create trigger trg_webhook_payment_received
  after insert on table_session_payments
  for each row
  execute function fn_trigger_webhook_payment_received();

create or replace function fn_trigger_webhook_reservation_created()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform fn_disparar_webhooks(
    new.restaurant_id,
    'reservation.created',
    jsonb_build_object(
      'reservation_id', new.id,
      'nombre', new.nombre,
      'telefono', new.telefono,
      'fecha', new.fecha,
      'hora', new.hora,
      'personas', new.personas,
      'zona', new.zona,
      'origen', new.origen,
      'created_at', new.created_at
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_webhook_reservation_created on reservations;
create trigger trg_webhook_reservation_created
  after insert on reservations
  for each row
  execute function fn_trigger_webhook_reservation_created();

create or replace function fn_trigger_webhook_waiter_call()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform fn_disparar_webhooks(
    new.restaurant_id,
    'waiter.call',
    jsonb_build_object(
      'call_id', new.id,
      'table_id', new.table_id,
      'created_at', new.created_at
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_webhook_waiter_call on waiter_calls;
create trigger trg_webhook_waiter_call
  after insert on waiter_calls
  for each row
  execute function fn_trigger_webhook_waiter_call();
