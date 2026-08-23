-- ============================================================================
-- Reseñas de clientes post-pago: valoración de 1 a 5 estrellas + comentario
-- opcional, que el cliente deja desde Mesa.jsx justo después de que la
-- mesa se cierra (pagada), visible para el dueño en el Dashboard.
-- ============================================================================

create table if not exists resenas (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  table_session_id uuid references table_sessions(id) on delete set null,
  puntuacion integer not null check (puntuacion between 1 and 5),
  comentario text,
  created_at timestamp with time zone not null default now(),
  unique (table_session_id)
);

alter table resenas enable row level security;

grant select on table resenas to authenticated;

drop policy if exists resenas_dueno on resenas;
create policy resenas_dueno on resenas for select
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- El cliente (anónimo, en Mesa.jsx) solo puede dejar la reseña a
-- través de esta función — nunca insertando directo a la tabla —
-- para poder validar que el qr_token corresponda a la mesa de esa
-- sesión y que la sesión ya esté cerrada (no se califica antes de
-- pagar, ni la mesa de otro).
create or replace function fn_registrar_resena(
  p_session_id uuid,
  p_qr_token text,
  p_puntuacion integer,
  p_comentario text default null
)
returns void
language plpgsql
security definer
as $$
declare
  v_restaurant_id uuid;
begin
  if p_puntuacion is null or p_puntuacion < 1 or p_puntuacion > 5 then
    raise exception 'Puntuación inválida';
  end if;

  select ts.restaurant_id into v_restaurant_id
  from table_sessions ts
  join tables t on t.id = ts.table_id
  where ts.id = p_session_id
    and t.qr_token = p_qr_token
    and ts.estado <> 'abierta';

  if v_restaurant_id is null then
    raise exception 'Sesión no encontrada o todavía abierta';
  end if;

  insert into resenas (restaurant_id, table_session_id, puntuacion, comentario)
  values (v_restaurant_id, p_session_id, p_puntuacion, nullif(trim(p_comentario), ''))
  on conflict (table_session_id) do nothing;
end;
$$;

grant execute on function fn_registrar_resena(uuid, text, integer, text) to anon, authenticated;
