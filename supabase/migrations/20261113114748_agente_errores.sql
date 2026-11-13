-- =============================================================================
-- Registro de fallos del agente de WhatsApp (entrega 1a, punto 4)
-- Especificación: docs/specs/2026-11-13-agente-whatsapp-revision.md
--
-- NO TOCA DATOS existentes. Crea:
--   - agente_errores: un aviso por fallo que afecta a un cliente (lo ve el
--     dueño si visible_restaurante; el superadmin lo ve todo).
--   - agente_errores_detalle: detalle técnico (solo superadmin). Tabla aparte
--     para que el dueño no lo vea ni por Realtime.
--   - fn_agente_registrar_error(...): escritura desde n8n (solo service_role),
--     agrupa repeticiones de 30 minutos.
--   - fn_agente_error_marcar_atendida(uuid): dueño de ese restaurante o
--     superadmin (no exige el módulo whatsapp: decisión 10).
--
-- No se borra ninguna fila de las dos tablas (decisión 13): service_role
-- solo tiene SELECT, INSERT y UPDATE.
-- Idempotente.
-- =============================================================================

-- 1. Tablas ---------------------------------------------------------------------
create table if not exists public.agente_errores (
  id                  uuid        primary key default gen_random_uuid(),
  restaurant_id       uuid        null references public.restaurants(id) on delete cascade,
  telefono_cliente    text        null,
  tipo                text        not null,
  paso                text        null,
  visible_restaurante boolean     not null default false,
  veces               integer     not null default 1,
  created_at          timestamptz not null default now(),
  ultima_vez_at       timestamptz not null default now(),
  atendida            boolean     not null default false,
  atendida_por        uuid        null references auth.users(id) on delete set null,
  atendida_at         timestamptz null,
  constraint agente_errores_tipo_check check (tipo in (
    'sin_respuesta', 'pedido_no_creado', 'reserva_no_creada', 'reserva_no_modificada',
    'pedido_demasiado_grande', 'firma_invalida', 'error_interno', 'registro_fallido'
  )),
  -- Un aviso visible siempre es de un restaurante concreto.
  constraint agente_errores_visible_con_restaurante check (not visible_restaurante or restaurant_id is not null),
  constraint agente_errores_veces_check check (veces >= 1)
);

create index if not exists agente_errores_rest_atendida_created_idx
  on public.agente_errores (restaurant_id, atendida, created_at);
create index if not exists agente_errores_rest_atendida_at_idx
  on public.agente_errores (restaurant_id, atendida_at);

create table if not exists public.agente_errores_detalle (
  id         uuid        primary key default gen_random_uuid(),
  error_id   uuid        not null references public.agente_errores(id) on delete cascade,
  detalle    jsonb       not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists agente_errores_detalle_error_idx
  on public.agente_errores_detalle (error_id, created_at);

-- 2. RLS ------------------------------------------------------------------------
alter table public.agente_errores enable row level security;
alter table public.agente_errores_detalle enable row level security;

drop policy if exists agente_errores_duenio_select on public.agente_errores;
create policy agente_errores_duenio_select on public.agente_errores
  for select to authenticated
  using (restaurant_id in (select id from public.restaurants where user_id = auth.uid()) and visible_restaurante);

drop policy if exists agente_errores_superadmin_select on public.agente_errores;
create policy agente_errores_superadmin_select on public.agente_errores
  for select to authenticated
  using (public.fn_es_superadmin());

drop policy if exists agente_errores_detalle_superadmin_select on public.agente_errores_detalle;
create policy agente_errores_detalle_superadmin_select on public.agente_errores_detalle
  for select to authenticated
  using (public.fn_es_superadmin());

-- 3. Grants (mínimos y explícitos; sin DELETE para nadie) -------------------------
revoke all on table public.agente_errores, public.agente_errores_detalle from public, anon, authenticated, service_role;
grant select on table public.agente_errores to authenticated;
grant select on table public.agente_errores_detalle to authenticated;   -- lo filtra la política de superadmin
grant select, insert, update on table public.agente_errores, public.agente_errores_detalle to service_role;

-- 4. Realtime (solo la tabla de avisos; el detalle no se publica) ----------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'agente_errores') then
    alter publication supabase_realtime add table public.agente_errores;
  end if;
end
$$;

-- 5. fn_agente_registrar_error (solo service_role: n8n) --------------------------
-- Devuelve el id del aviso (nuevo o el pendiente al que se ha sumado).
-- Repeticiones: si hay un aviso PENDIENTE del mismo restaurante, teléfono y
-- tipo cuya última vez fue hace 30 minutos o menos, se suma 1 a `veces` y se
-- actualiza `ultima_vez_at` (una caída larga sigue agrupándose en el mismo).
-- El detalle de cada vez se guarda aparte, sin claves y con tamaño acotado.
create or replace function public.fn_agente_registrar_error (
  p_restaurant_id uuid,
  p_telefono      text,
  p_tipo          text,
  p_paso          text  default null,
  p_detalle       jsonb default null
)
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  c_visibles constant text[] := array['sin_respuesta', 'pedido_no_creado', 'reserva_no_creada',
                                      'reserva_no_modificada', 'pedido_demasiado_grande'];
  v_tel text := left(fn_normalizar_telefono(p_telefono), 30);
  v_rest uuid := p_restaurant_id;
  v_id uuid;
  v_texto text;
begin
  if p_tipo is null or p_tipo not in ('sin_respuesta', 'pedido_no_creado', 'reserva_no_creada', 'reserva_no_modificada',
                                      'pedido_demasiado_grande', 'firma_invalida', 'error_interno', 'registro_fallido') then
    raise exception 'Tipo de aviso no válido: %', coalesce(p_tipo, 'null') using errcode = '22023';
  end if;

  -- Un restaurant_id que no existe (cuerpo manipulado, restaurante borrado)
  -- se registra sin restaurante: solo lo ve el superadmin.
  if v_rest is not null and not exists (select 1 from restaurants where id = v_rest) then
    v_rest := null;
  end if;

  -- Dos fallos simultáneos del mismo cliente no crean dos avisos.
  perform pg_advisory_xact_lock(hashtext('agente_errores|' || coalesce(v_rest::text, '-') || '|' ||
                                         coalesce(v_tel, '-') || '|' || p_tipo));

  select id into v_id
  from agente_errores
  where restaurant_id is not distinct from v_rest
    and telefono_cliente is not distinct from v_tel
    and tipo = p_tipo
    and not atendida
    and ultima_vez_at >= now() - interval '30 minutes'
  order by ultima_vez_at desc
  limit 1
  for update;

  if v_id is not null then
    update agente_errores set veces = veces + 1, ultima_vez_at = now() where id = v_id;
  else
    insert into agente_errores (restaurant_id, telefono_cliente, tipo, paso, visible_restaurante)
    values (v_rest, v_tel, p_tipo, left(p_paso, 200), v_rest is not null and p_tipo = any (c_visibles))
    returning id into v_id;
  end if;

  if p_detalle is not null then
    -- Nunca claves: se tapan los patrones conocidos (Anthropic, Meta, JWT,
    -- cabeceras Bearer). Los patrones no contienen comillas, así que el
    -- JSON sigue siendo válido.
    v_texto := regexp_replace(p_detalle::text,
                 '(sk-ant-[A-Za-z0-9_\-]+|EAA[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+|Bearer [A-Za-z0-9_\-\.]+)',
                 '[oculto]', 'g');
    insert into agente_errores_detalle (error_id, detalle)
    values (v_id,
            case when length(v_texto) <= 8000 then v_texto::jsonb
                 else jsonb_build_object('truncado', true, 'extracto', left(v_texto, 8000)) end);
  end if;

  return v_id;
end;
$$;

revoke all on function public.fn_agente_registrar_error(uuid, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.fn_agente_registrar_error(uuid, text, text, text, jsonb) to service_role;

-- 6. fn_agente_error_marcar_atendida (panel: dueño o superadmin) ------------------
-- No exige el módulo whatsapp (decisión 10): un restaurante que lo pierde
-- puede cerrar sus avisos antiguos. El dueño solo puede marcar los avisos
-- que ve (visible_restaurante). Si ya estaba atendida, no cambia quién ni
-- cuándo. Devuelve la fila para actualizar el estado local (regla 9).
create or replace function public.fn_agente_error_marcar_atendida (
  p_error_id uuid
)
  returns public.agente_errores
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_fila agente_errores;
begin
  if auth.uid() is null then
    raise exception 'No autorizado.' using errcode = '42501';
  end if;

  select * into v_fila from agente_errores where id = p_error_id for update;
  if v_fila.id is null then
    raise exception 'Aviso no encontrado.' using errcode = 'P0002';
  end if;

  if not (fn_es_superadmin()
          or (v_fila.visible_restaurante
              and exists (select 1 from restaurants r where r.id = v_fila.restaurant_id and r.user_id = auth.uid()))) then
    raise exception 'No autorizado.' using errcode = '42501';
  end if;

  if not v_fila.atendida then
    update agente_errores
    set atendida = true, atendida_por = auth.uid(), atendida_at = now()
    where id = p_error_id
    returning * into v_fila;
  end if;

  return v_fila;
end;
$$;

revoke all on function public.fn_agente_error_marcar_atendida(uuid) from public, anon;
grant execute on function public.fn_agente_error_marcar_atendida(uuid) to authenticated, service_role;
