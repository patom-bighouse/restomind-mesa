-- =============================================================================
-- Avisos del agente: tipos de la entrada directa desde Meta (decisión 6 cambiada
-- el 13-11-2026). Corrige 20261113114748_agente_errores (ya aplicada en Test).
-- Especificación: docs/specs/2026-11-13-agente-whatsapp-revision.md
--
-- NO TOCA DATOS. Cambia:
--   - el check de agente_errores.tipo: añade numero_desconocido (phone_number_id
--     de ningún restaurante) y mensajes_multiples (aviso de Meta con varios
--     mensajes). Los dos, solo superadmin.
--   - fn_agente_registrar_error (misma firma y grants):
--       * firma_invalida y numero_desconocido se agrupan en una sola fila por
--         tipo y media hora, sin restaurante ni teléfono (no son fiables), para
--         que miles de peticiones falsas no llenen la tabla;
--       * de esos dos tipos solo se guarda el detalle de las 5 primeras veces
--         de cada fila (el resto solo suma `veces`).
-- Idempotente.
-- =============================================================================

alter table public.agente_errores drop constraint if exists agente_errores_tipo_check;
alter table public.agente_errores add constraint agente_errores_tipo_check check (tipo in (
  'sin_respuesta', 'pedido_no_creado', 'reserva_no_creada', 'reserva_no_modificada',
  'pedido_demasiado_grande', 'firma_invalida', 'numero_desconocido', 'mensajes_multiples',
  'error_interno', 'registro_fallido'
));

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
  c_tipos constant text[] := array['sin_respuesta', 'pedido_no_creado', 'reserva_no_creada', 'reserva_no_modificada',
                                   'pedido_demasiado_grande', 'firma_invalida', 'numero_desconocido',
                                   'mensajes_multiples', 'error_interno', 'registro_fallido'];
  c_visibles constant text[] := array['sin_respuesta', 'pedido_no_creado', 'reserva_no_creada',
                                      'reserva_no_modificada', 'pedido_demasiado_grande'];
  -- Peticiones sin restaurante ni teléfono fiables: una fila por tipo y media hora.
  c_agrupados constant text[] := array['firma_invalida', 'numero_desconocido'];
  c_max_detalles_agrupados constant int := 5;
  v_tel text := left(fn_normalizar_telefono(p_telefono), 30);
  v_rest uuid := p_restaurant_id;
  v_id uuid;
  v_veces int;
  v_texto text;
begin
  if p_tipo is null or not (p_tipo = any (c_tipos)) then
    raise exception 'Tipo de aviso no válido: %', coalesce(p_tipo, 'null') using errcode = '22023';
  end if;

  if p_tipo = any (c_agrupados) then
    v_rest := null;
    v_tel := null;
  end if;

  -- Un restaurant_id que no existe se registra sin restaurante: solo lo ve el superadmin.
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
    update agente_errores set veces = veces + 1, ultima_vez_at = now() where id = v_id
    returning veces into v_veces;
  else
    insert into agente_errores (restaurant_id, telefono_cliente, tipo, paso, visible_restaurante)
    values (v_rest, v_tel, p_tipo, left(p_paso, 200), v_rest is not null and p_tipo = any (c_visibles))
    returning id, veces into v_id, v_veces;
  end if;

  if p_detalle is not null and (not (p_tipo = any (c_agrupados)) or v_veces <= c_max_detalles_agrupados) then
    -- Nunca claves: se tapan los patrones conocidos (Anthropic, Meta, JWT,
    -- cabeceras Bearer, firmas sha256=…). Los patrones no contienen comillas,
    -- así que el JSON sigue siendo válido.
    v_texto := regexp_replace(p_detalle::text,
                 '(sk-ant-[A-Za-z0-9_\-]+|EAA[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+|Bearer [A-Za-z0-9_\-\.]+|sha256=[0-9a-fA-F]+)',
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
