-- ============================================================================
-- Permanencia mínima, bajas y aceptación de las condiciones del servicio.
--
--   restaurants.permanencia_hasta → fecha de alta + 3 meses. Se rellena sola
--       al crear un restaurante (solo los nuevos: los que ya existen quedan
--       sin permanencia). El superadmin puede ajustarla a mano.
--   restaurants.baja_*            → cuándo y por qué se dio de baja, y la
--       penalización aplicada.
--   condiciones_aceptaciones      → prueba de que el dueño aceptó las
--       condiciones: versión, fecha, usuario, IP y navegador.
--
-- Baja anticipada (dentro de la permanencia y fuera del periodo de prueba):
-- penalización del 50 % de las cuotas que faltan hasta el fin de la
-- permanencia (un mes empezado cuenta entero), y las comisiones del
-- vendedor por ese cliente se retiran: las pendientes se anulan y las ya
-- pagadas quedan "a descontar" del siguiente pago.
--
-- Además corrige un agujero previo: la política owner_all_restaurants deja
-- al dueño actualizar cualquier columna de su restaurante, y los
-- "revoke update (columna)" de planes_suscripcion.sql y
-- trial_y_descuentos.sql no tenían efecto (hay grant de UPDATE sobre la
-- tabla entera). Un trigger impide ahora que alguien que no sea superadmin
-- cambie plan, trial, descuento, estado, permanencia o baja.
--
-- Re-ejecutable. Necesita crm_vendedores.sql (fn_es_superadmin,
-- fn_crm_cuota_restaurante, crm_comisiones). Ejecutar en staging y después
-- en producción.
-- ============================================================================

alter table restaurants
  add column if not exists permanencia_hasta date,
  add column if not exists baja_en date,
  add column if not exists baja_motivo text,
  add column if not exists baja_penalizacion numeric(10,2);

-- ---------------------------------------------------------------------------
-- Permanencia automática al dar de alta
-- ---------------------------------------------------------------------------

create or replace function fn_restaurants_permanencia_alta()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  -- Meses de permanencia desde la fecha de alta (hora de España).
  if new.permanencia_hasta is null then
    new.permanencia_hasta := ((coalesce(new.created_at, now()) at time zone 'Europe/Madrid')::date + interval '3 months')::date;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restaurants_permanencia_alta on restaurants;
create trigger trg_restaurants_permanencia_alta
  before insert on restaurants
  for each row execute function fn_restaurants_permanencia_alta();

-- ---------------------------------------------------------------------------
-- Datos comerciales: solo los cambia el superadmin
-- ---------------------------------------------------------------------------

-- Sin sesión (auth.uid() null) es la service role o un proceso interno:
-- se deja pasar. Con sesión, solo el superadmin.
create or replace function fn_restaurants_proteger_comercial()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is not null and not fn_es_superadmin() then
    new.plan := old.plan;
    new.activo := old.activo;
    new.trial_termina_en := old.trial_termina_en;
    new.precio_override := old.precio_override;
    new.precio_override_hasta := old.precio_override_hasta;
    new.permanencia_hasta := old.permanencia_hasta;
    new.baja_en := old.baja_en;
    new.baja_motivo := old.baja_motivo;
    new.baja_penalizacion := old.baja_penalizacion;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restaurants_proteger_comercial on restaurants;
create trigger trg_restaurants_proteger_comercial
  before update on restaurants
  for each row execute function fn_restaurants_proteger_comercial();

-- ---------------------------------------------------------------------------
-- Penalización por baja anticipada
-- ---------------------------------------------------------------------------

-- Cuánto costaría dar de baja hoy (o en p_fecha). Durante el periodo de
-- prueba la baja es gratuita.
create or replace function fn_permanencia_penalizacion(p_restaurant_id uuid, p_fecha date default current_date)
returns table (
  permanencia_hasta date,
  en_permanencia boolean,
  en_trial boolean,
  meses_pendientes integer,
  cuota numeric,
  porcentaje numeric,
  penalizacion numeric
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_pct constant numeric := 50;
  r record;
  v_edad interval;
  v_meses integer := 0;
  v_cuota numeric;
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;

  select x.permanencia_hasta, x.trial_termina_en into r from restaurants x where x.id = p_restaurant_id;
  if not found then
    raise exception 'Restaurante no encontrado.';
  end if;

  if r.permanencia_hasta is not null and r.permanencia_hasta > p_fecha then
    v_edad := age(r.permanencia_hasta, p_fecha);
    v_meses := (extract(year from v_edad) * 12 + extract(month from v_edad))::integer
               + case when extract(day from v_edad) > 0 then 1 else 0 end;
  end if;
  v_cuota := coalesce(fn_crm_cuota_restaurante(p_restaurant_id, p_fecha), 0);

  permanencia_hasta := r.permanencia_hasta;
  en_permanencia := v_meses > 0;
  en_trial := r.trial_termina_en is not null and r.trial_termina_en >= p_fecha;
  meses_pendientes := v_meses;
  cuota := v_cuota;
  porcentaje := v_pct;
  penalizacion := case when v_meses > 0 and not en_trial then round(v_meses * v_cuota * v_pct / 100, 2) else 0 end;
  return next;
end;
$$;

revoke execute on function fn_permanencia_penalizacion(uuid, date) from public, anon;
grant execute on function fn_permanencia_penalizacion(uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Baja de un restaurante
-- ---------------------------------------------------------------------------

alter table crm_comisiones drop constraint if exists crm_comisiones_estado_check;
alter table crm_comisiones add constraint crm_comisiones_estado_check
  check (estado in ('pendiente', 'pagada', 'anulada', 'a_descontar', 'descontada'));

-- Desactiva el restaurante y registra la baja. Si está dentro de la
-- permanencia: guarda la penalización (o 0 si se perdona) y retira las
-- comisiones de ese cliente.
create or replace function fn_dar_baja_restaurante(p_restaurant_id uuid, p_motivo text, p_cobrar_penalizacion boolean default true)
returns table (penalizacion numeric, comisiones_anuladas integer, comisiones_a_descontar integer)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  p record;
  v_anuladas integer := 0;
  v_descontar integer := 0;
  v_nota text := 'Baja dentro de la permanencia (' || to_char(current_date, 'DD/MM/YYYY') || ')';
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;

  select * into p from fn_permanencia_penalizacion(p_restaurant_id, current_date);

  update restaurants
  set activo = false,
      baja_en = current_date,
      baja_motivo = nullif(trim(coalesce(p_motivo, '')), ''),
      baja_penalizacion = case when p.en_permanencia then (case when p_cobrar_penalizacion then p.penalizacion else 0 end) end
  where id = p_restaurant_id;

  if p.en_permanencia then
    update crm_comisiones set estado = 'anulada', nota = v_nota
    where restaurant_id = p_restaurant_id and estado = 'pendiente';
    get diagnostics v_anuladas = row_count;

    update crm_comisiones set estado = 'a_descontar', nota = v_nota
    where restaurant_id = p_restaurant_id and estado = 'pagada';
    get diagnostics v_descontar = row_count;
  end if;

  penalizacion := case when p.en_permanencia and p_cobrar_penalizacion then p.penalizacion else 0 end;
  comisiones_anuladas := v_anuladas;
  comisiones_a_descontar := v_descontar;
  return next;
end;
$$;

revoke execute on function fn_dar_baja_restaurante(uuid, text, boolean) from public, anon;
grant execute on function fn_dar_baja_restaurante(uuid, text, boolean) to authenticated;

-- Permanencia y baja de los clientes del CRM (el vendedor ve solo los suyos).
create or replace function fn_crm_permanencias()
returns table (cuenta_id uuid, permanencia_hasta date, baja_en date, baja_penalizacion numeric)
language sql
stable
security definer
set search_path to 'public'
as $$
  select c.id, r.permanencia_hasta, r.baja_en, r.baja_penalizacion
  from crm_cuentas c
  join restaurants r on r.id = c.restaurant_id
  where fn_es_superadmin() or c.vendedor_id = fn_mi_vendedor_id()
$$;

revoke execute on function fn_crm_permanencias() from public, anon;
grant execute on function fn_crm_permanencias() to authenticated;

-- ---------------------------------------------------------------------------
-- Aceptación de las condiciones del servicio
-- ---------------------------------------------------------------------------

create table if not exists condiciones_aceptaciones (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  user_id uuid not null,
  version text not null,
  aceptado_en timestamp with time zone not null default now(),
  ip text,
  user_agent text,
  unique (restaurant_id, version)
);

alter table condiciones_aceptaciones enable row level security;
revoke all on table condiciones_aceptaciones from anon;
grant select on table condiciones_aceptaciones to authenticated;

-- Solo lectura (el dueño las suyas, el superadmin todas). Se escribe
-- únicamente con fn_aceptar_condiciones().
drop policy if exists condiciones_aceptaciones_select on condiciones_aceptaciones;
create policy condiciones_aceptaciones_select on condiciones_aceptaciones for select to authenticated
  using (fn_es_superadmin() or exists (
    select 1 from restaurants r where r.id = restaurant_id and r.user_id = auth.uid()
  ));

-- ¿Tiene que aceptar las condiciones quien está mirando? Solo el dueño, y
-- solo en restaurantes con permanencia (los dados de alta desde que existe).
create or replace function fn_condiciones_pendientes(p_restaurant_id uuid, p_version text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from restaurants r
    where r.id = p_restaurant_id
      and r.user_id = auth.uid()
      and r.permanencia_hasta is not null
      and not exists (
        select 1 from condiciones_aceptaciones a
        where a.restaurant_id = r.id and a.version = p_version
      )
  )
$$;

create or replace function fn_aceptar_condiciones(p_restaurant_id uuid, p_version text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_headers json := nullif(current_setting('request.headers', true), '')::json;
begin
  if not exists (select 1 from restaurants r where r.id = p_restaurant_id and r.user_id = auth.uid()) then
    raise exception 'Solo el titular del restaurante puede aceptar las condiciones.';
  end if;
  if coalesce(trim(p_version), '') = '' then
    raise exception 'Versión de las condiciones no válida.';
  end if;

  insert into condiciones_aceptaciones (restaurant_id, user_id, version, ip, user_agent)
  values (
    p_restaurant_id, auth.uid(), p_version,
    split_part(coalesce(v_headers->>'x-forwarded-for', v_headers->>'x-real-ip', ''), ',', 1),
    left(v_headers->>'user-agent', 400)
  )
  on conflict (restaurant_id, version) do nothing;
end;
$$;

revoke execute on function fn_condiciones_pendientes(uuid, text) from public, anon;
revoke execute on function fn_aceptar_condiciones(uuid, text) from public, anon;
grant execute on function fn_condiciones_pendientes(uuid, text) to authenticated;
grant execute on function fn_aceptar_condiciones(uuid, text) to authenticated;

notify pgrst, 'reload schema';
