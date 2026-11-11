-- ============================================================================
-- CRM de vendedores: cada vendedor gestiona su cartera de restaurantes
-- (prospectos y clientes) y cobra comisión sobre la cuota mensual de los
-- clientes que cierra.
--
--   vendedores        → nuevo rol con login propio (/vendedor/login).
--   crm_cuentas       → un restaurante dentro del CRM, sea prospecto o
--                       cliente. Pasa a "cliente" cuando el superadmin lo
--                       convierte y queda vinculado a restaurants.id.
--   crm_actividades   → llamadas, visitas, WhatsApp, emails, demos, notas.
--   crm_tareas        → recordatorios con fecha.
--   crm_historial     → cambios de etapa y de vendedor (auditoría/métricas).
--   crm_comisiones    → una fila por cuenta y mes: % de la cuota cobrada,
--                       durante el número de cuotas pactado.
--
-- Seguridad: el vendedor solo ve las cuentas que tiene asignadas, y un
-- trigger le impide tocar vendedor, restaurante vinculado y condiciones de
-- comisión (aunque llame a la API directamente). No ve `restaurants`: los
-- datos de sus clientes los lee vía fn_crm_restaurantes_cuentas(), que
-- devuelve solo campos seguros. El superadmin ve y edita todo.
--
-- Re-ejecutable: todo es if not exists / create or replace / drop policy
-- if exists. Ejecutar en staging y después en producción.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Vendedores
-- ---------------------------------------------------------------------------

create table if not exists vendedores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  nombre text not null,
  email text not null,
  telefono text,
  activo boolean not null default true,
  -- Condiciones por defecto; se copian a cada cuenta al asignarla y desde
  -- ahí se pueden ajustar cuenta por cuenta.
  comision_pct numeric(5,2) not null default 10 check (comision_pct >= 0 and comision_pct <= 100),
  comision_cuotas integer check (comision_cuotas is null or comision_cuotas > 0), -- null = sin límite
  created_at timestamp with time zone not null default now()
);

-- ---------------------------------------------------------------------------
-- Helpers de permisos
-- ---------------------------------------------------------------------------

create or replace function fn_es_superadmin()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (select 1 from superadmins s where s.user_id = auth.uid())
$$;

-- Vendedor activo de la sesión, o null. Un vendedor desactivado deja de
-- ver todo al instante (todas las políticas pasan por aquí).
create or replace function fn_mi_vendedor_id()
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select v.id from vendedores v where v.user_id = auth.uid() and v.activo limit 1
$$;

revoke execute on function fn_es_superadmin() from anon;
revoke execute on function fn_mi_vendedor_id() from anon;
grant execute on function fn_es_superadmin() to authenticated;
grant execute on function fn_mi_vendedor_id() to authenticated;

-- ---------------------------------------------------------------------------
-- Cuentas
-- ---------------------------------------------------------------------------

create table if not exists crm_cuentas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  contacto_nombre text,
  contacto_cargo text,
  telefono text,
  email text,
  ciudad text,
  pais text,
  direccion text,
  tipo_local text,
  num_mesas integer check (num_mesas is null or num_mesas >= 0),
  fuente text,
  etapa text not null default 'prospecto'
    check (etapa in ('prospecto', 'contactado', 'demo', 'propuesta', 'negociacion', 'ganado', 'perdido')),
  motivo_perdida text,
  plan_interes text references planes(key),
  cuota_estimada numeric(10,2),
  proxima_accion text,
  proxima_accion_fecha date,
  notas text,
  vendedor_id uuid references vendedores(id) on delete set null,
  restaurant_id uuid unique references restaurants(id) on delete set null,
  comision_pct numeric(5,2) check (comision_pct is null or (comision_pct >= 0 and comision_pct <= 100)),
  comision_cuotas integer check (comision_cuotas is null or comision_cuotas > 0), -- null = sin límite
  comision_inicio date, -- primer mes que genera comisión
  ganado_en timestamp with time zone,
  perdido_en timestamp with time zone,
  ultima_actividad_en timestamp with time zone,
  created_by uuid default auth.uid(),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists crm_cuentas_vendedor_idx on crm_cuentas (vendedor_id);
create index if not exists crm_cuentas_etapa_idx on crm_cuentas (etapa);

create or replace function fn_crm_cuenta_puede_ver(p_cuenta_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select fn_es_superadmin()
    or exists (
      select 1 from crm_cuentas c
      where c.id = p_cuenta_id and c.vendedor_id = fn_mi_vendedor_id()
    )
$$;

revoke execute on function fn_crm_cuenta_puede_ver(uuid) from anon;
grant execute on function fn_crm_cuenta_puede_ver(uuid) to authenticated;

-- Candado server-side: lo que un vendedor no puede cambiar se restaura
-- aquí, haga lo que haga el frontend. auth.uid() null = service role.
create or replace function fn_crm_cuentas_antes()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_admin boolean := auth.uid() is null or fn_es_superadmin();
  v_vendedor record;
begin
  if not v_admin then
    if tg_op = 'INSERT' then
      new.vendedor_id := fn_mi_vendedor_id();
      if new.vendedor_id is null then
        raise exception 'No autorizado.';
      end if;
      new.restaurant_id := null;
      new.comision_pct := null;
      new.comision_cuotas := null;
      new.comision_inicio := null;
    else
      new.vendedor_id := old.vendedor_id;
      new.restaurant_id := old.restaurant_id;
      new.comision_pct := old.comision_pct;
      new.comision_cuotas := old.comision_cuotas;
      new.comision_inicio := old.comision_inicio;
      new.created_by := old.created_by;
      -- Un cliente ya convertido no vuelve atrás en el embudo desde el
      -- lado del vendedor: eso lo decide el superadmin.
      if old.restaurant_id is not null then
        new.etapa := old.etapa;
      end if;
    end if;
  end if;

  -- Condiciones de comisión por defecto del vendedor asignado.
  if new.vendedor_id is not null
     and (tg_op = 'INSERT' or new.vendedor_id is distinct from old.vendedor_id)
     and new.comision_pct is null then
    select comision_pct, comision_cuotas into v_vendedor from vendedores where id = new.vendedor_id;
    new.comision_pct := v_vendedor.comision_pct;
    new.comision_cuotas := v_vendedor.comision_cuotas;
  end if;

  if new.etapa = 'ganado' and (tg_op = 'INSERT' or old.etapa is distinct from 'ganado') then
    new.ganado_en := coalesce(new.ganado_en, now());
  end if;
  if new.etapa = 'perdido' and (tg_op = 'INSERT' or old.etapa is distinct from 'perdido') then
    new.perdido_en := now();
  end if;
  if new.etapa <> 'perdido' then
    new.perdido_en := null;
  end if;

  -- Al vincular el restaurante, la comisión arranca por defecto el mes
  -- siguiente (el superadmin puede cambiarlo).
  if new.restaurant_id is not null and new.comision_inicio is null then
    new.comision_inicio := (date_trunc('month', current_date) + interval '1 month')::date;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_crm_cuentas_antes on crm_cuentas;
create trigger trg_crm_cuentas_antes
  before insert or update on crm_cuentas
  for each row execute function fn_crm_cuentas_antes();

-- ---------------------------------------------------------------------------
-- Historial (etapa y vendedor)
-- ---------------------------------------------------------------------------

create table if not exists crm_historial (
  id uuid primary key default gen_random_uuid(),
  cuenta_id uuid not null references crm_cuentas(id) on delete cascade,
  campo text not null check (campo in ('etapa', 'vendedor')),
  valor_anterior text,
  valor_nuevo text,
  user_id uuid default auth.uid(),
  created_at timestamp with time zone not null default now()
);

create index if not exists crm_historial_cuenta_idx on crm_historial (cuenta_id, created_at);

create or replace function fn_crm_cuentas_despues()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'INSERT' then
    insert into crm_historial (cuenta_id, campo, valor_anterior, valor_nuevo)
    values (new.id, 'etapa', null, new.etapa);
    if new.vendedor_id is not null then
      insert into crm_historial (cuenta_id, campo, valor_anterior, valor_nuevo)
      values (new.id, 'vendedor', null, new.vendedor_id::text);
    end if;
  else
    if new.etapa is distinct from old.etapa then
      insert into crm_historial (cuenta_id, campo, valor_anterior, valor_nuevo)
      values (new.id, 'etapa', old.etapa, new.etapa);
    end if;
    if new.vendedor_id is distinct from old.vendedor_id then
      insert into crm_historial (cuenta_id, campo, valor_anterior, valor_nuevo)
      values (new.id, 'vendedor', old.vendedor_id::text, new.vendedor_id::text);
    end if;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_crm_cuentas_despues on crm_cuentas;
create trigger trg_crm_cuentas_despues
  after insert or update on crm_cuentas
  for each row execute function fn_crm_cuentas_despues();

-- ---------------------------------------------------------------------------
-- Actividades
-- ---------------------------------------------------------------------------

create table if not exists crm_actividades (
  id uuid primary key default gen_random_uuid(),
  cuenta_id uuid not null references crm_cuentas(id) on delete cascade,
  tipo text not null check (tipo in ('llamada', 'visita', 'whatsapp', 'email', 'demo', 'nota')),
  descripcion text not null,
  resultado text,
  fecha timestamp with time zone not null default now(),
  autor_user_id uuid default auth.uid(),
  autor_nombre text,
  created_at timestamp with time zone not null default now()
);

create index if not exists crm_actividades_cuenta_idx on crm_actividades (cuenta_id, fecha desc);

create or replace function fn_crm_actividades_antes()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is not null then
    new.autor_user_id := auth.uid();
    new.autor_nombre := coalesce(
      (select nombre from vendedores where user_id = auth.uid()),
      (select coalesce(nombre, 'Admin') from superadmins where user_id = auth.uid()),
      new.autor_nombre
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_crm_actividades_antes on crm_actividades;
create trigger trg_crm_actividades_antes
  before insert on crm_actividades
  for each row execute function fn_crm_actividades_antes();

create or replace function fn_crm_actividades_despues()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  update crm_cuentas
  set ultima_actividad_en = greatest(coalesce(ultima_actividad_en, new.fecha), new.fecha)
  where id = new.cuenta_id;
  return null;
end;
$$;

drop trigger if exists trg_crm_actividades_despues on crm_actividades;
create trigger trg_crm_actividades_despues
  after insert on crm_actividades
  for each row execute function fn_crm_actividades_despues();

-- ---------------------------------------------------------------------------
-- Tareas
-- ---------------------------------------------------------------------------

create table if not exists crm_tareas (
  id uuid primary key default gen_random_uuid(),
  cuenta_id uuid not null references crm_cuentas(id) on delete cascade,
  titulo text not null,
  vence_en date not null default current_date,
  completada boolean not null default false,
  completada_en timestamp with time zone,
  created_by uuid default auth.uid(),
  created_at timestamp with time zone not null default now()
);

create index if not exists crm_tareas_cuenta_idx on crm_tareas (cuenta_id);
create index if not exists crm_tareas_pendientes_idx on crm_tareas (vence_en) where not completada;

-- ---------------------------------------------------------------------------
-- Comisiones
-- ---------------------------------------------------------------------------

create table if not exists crm_comisiones (
  id uuid primary key default gen_random_uuid(),
  cuenta_id uuid not null references crm_cuentas(id) on delete cascade,
  vendedor_id uuid not null references vendedores(id),
  restaurant_id uuid references restaurants(id) on delete set null,
  periodo date not null, -- primer día del mes
  numero_cuota integer not null,
  cuota_base numeric(10,2) not null,
  porcentaje numeric(5,2) not null,
  importe numeric(10,2) not null,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'pagada', 'anulada')),
  pagada_en timestamp with time zone,
  nota text,
  created_at timestamp with time zone not null default now(),
  unique (cuenta_id, periodo)
);

create index if not exists crm_comisiones_vendedor_idx on crm_comisiones (vendedor_id, periodo);

-- Cuota mensual vigente de un restaurante en una fecha: el descuento
-- (precio_override) si sigue en vigor, si no el precio de su plan.
create or replace function fn_crm_cuota_restaurante(p_restaurant_id uuid, p_fecha date default current_date)
returns numeric
language sql
stable
security definer
set search_path to 'public'
as $$
  select case
    when r.precio_override is not null
         and (r.precio_override_hasta is null or r.precio_override_hasta >= p_fecha)
      then r.precio_override
    else coalesce(pl.precio, 0)
  end
  from restaurants r
  left join planes pl on pl.key = r.plan
  where r.id = p_restaurant_id
$$;

revoke execute on function fn_crm_cuota_restaurante(uuid, date) from anon;
grant execute on function fn_crm_cuota_restaurante(uuid, date) to authenticated;

-- Genera las comisiones de un mes. Idempotente: un mes ya generado para
-- una cuenta no se duplica. Solo cuentan los meses en que el restaurante
-- realmente paga: activo, con el trial terminado y cuota > 0. La comisión
-- es del vendedor asignado en el momento de generarla, y para cuando se
-- alcanzan las cuotas pactadas (las anuladas no cuentan).
create or replace function fn_crm_generar_comisiones(p_periodo date)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_ini date := date_trunc('month', p_periodo)::date;
  v_fin date := (date_trunc('month', p_periodo) + interval '1 month - 1 day')::date;
  v_n integer;
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;
  if v_ini > date_trunc('month', current_date)::date then
    raise exception 'No se pueden generar comisiones de meses futuros.';
  end if;

  insert into crm_comisiones (cuenta_id, vendedor_id, restaurant_id, periodo, numero_cuota, cuota_base, porcentaje, importe)
  select c.id, c.vendedor_id, c.restaurant_id, v_ini, prev.n + 1, q.cuota, c.comision_pct,
         round(q.cuota * c.comision_pct / 100, 2)
  from crm_cuentas c
  join restaurants r on r.id = c.restaurant_id
  cross join lateral (select fn_crm_cuota_restaurante(r.id, v_ini) as cuota) q
  cross join lateral (
    select count(*)::integer as n from crm_comisiones x
    where x.cuenta_id = c.id and x.estado <> 'anulada'
  ) prev
  where c.vendedor_id is not null
    and coalesce(c.comision_pct, 0) > 0
    and c.comision_inicio is not null
    and c.comision_inicio <= v_fin
    and coalesce(r.activo, true)
    and (r.trial_termina_en is null or r.trial_termina_en < v_fin)
    and q.cuota > 0
    and (c.comision_cuotas is null or prev.n < c.comision_cuotas)
  on conflict (cuenta_id, periodo) do nothing;

  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke execute on function fn_crm_generar_comisiones(date) from anon;
grant execute on function fn_crm_generar_comisiones(date) to authenticated;

-- ---------------------------------------------------------------------------
-- Datos de los clientes (restaurantes vinculados) visibles en el CRM
-- ---------------------------------------------------------------------------

create or replace function fn_crm_restaurantes_cuentas()
returns table (
  cuenta_id uuid,
  restaurant_id uuid,
  nombre text,
  plan text,
  activo boolean,
  trial_termina_en date,
  precio_override numeric,
  precio_override_hasta date,
  cuota_actual numeric,
  alta_en timestamp with time zone
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select c.id, r.id, r.nombre, r.plan, coalesce(r.activo, true), r.trial_termina_en,
         r.precio_override, r.precio_override_hasta,
         fn_crm_cuota_restaurante(r.id, current_date), r.created_at
  from crm_cuentas c
  join restaurants r on r.id = c.restaurant_id
  where fn_es_superadmin() or c.vendedor_id = fn_mi_vendedor_id()
$$;

revoke execute on function fn_crm_restaurantes_cuentas() from anon;
grant execute on function fn_crm_restaurantes_cuentas() to authenticated;

-- Crea una cuenta "ganada" (sin vendedor) por cada restaurante que todavía
-- no esté en el CRM, para poder asignar la cartera existente.
create or replace function fn_crm_importar_restaurantes()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_n integer;
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;

  insert into crm_cuentas (nombre, email, telefono, direccion, pais, etapa, fuente, plan_interes, restaurant_id, ganado_en)
  select r.nombre, r.email_dueno, r.whatsapp, r.direccion, r.pais, 'ganado', 'Cliente existente', r.plan, r.id, r.created_at
  from restaurants r
  where not exists (select 1 from crm_cuentas c where c.restaurant_id = r.id);

  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke execute on function fn_crm_importar_restaurantes() from anon;
grant execute on function fn_crm_importar_restaurantes() to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table vendedores enable row level security;
alter table crm_cuentas enable row level security;
alter table crm_historial enable row level security;
alter table crm_actividades enable row level security;
alter table crm_tareas enable row level security;
alter table crm_comisiones enable row level security;

revoke all on table vendedores, crm_cuentas, crm_historial, crm_actividades, crm_tareas, crm_comisiones from anon;
grant select, insert, update, delete on table vendedores, crm_cuentas, crm_actividades, crm_tareas, crm_comisiones to authenticated;
grant select on table crm_historial to authenticated;

-- vendedores: el superadmin gestiona; cada vendedor ve su propia ficha.
drop policy if exists vendedores_select on vendedores;
create policy vendedores_select on vendedores for select to authenticated
  using (fn_es_superadmin() or user_id = auth.uid());
drop policy if exists vendedores_superadmin_write on vendedores;
create policy vendedores_superadmin_write on vendedores for all to authenticated
  using (fn_es_superadmin()) with check (fn_es_superadmin());

-- crm_cuentas: el vendedor crea y edita las suyas; borrar, solo superadmin.
drop policy if exists crm_cuentas_select on crm_cuentas;
create policy crm_cuentas_select on crm_cuentas for select to authenticated
  using (fn_es_superadmin() or vendedor_id = fn_mi_vendedor_id());
drop policy if exists crm_cuentas_insert on crm_cuentas;
create policy crm_cuentas_insert on crm_cuentas for insert to authenticated
  with check (fn_es_superadmin() or vendedor_id = fn_mi_vendedor_id());
drop policy if exists crm_cuentas_update on crm_cuentas;
create policy crm_cuentas_update on crm_cuentas for update to authenticated
  using (fn_es_superadmin() or vendedor_id = fn_mi_vendedor_id())
  with check (fn_es_superadmin() or vendedor_id = fn_mi_vendedor_id());
drop policy if exists crm_cuentas_delete on crm_cuentas;
create policy crm_cuentas_delete on crm_cuentas for delete to authenticated
  using (fn_es_superadmin());

-- crm_historial: solo lectura (lo escribe el trigger).
drop policy if exists crm_historial_select on crm_historial;
create policy crm_historial_select on crm_historial for select to authenticated
  using (fn_crm_cuenta_puede_ver(cuenta_id));

-- crm_actividades: cada uno puede corregir o borrar las suyas.
drop policy if exists crm_actividades_select on crm_actividades;
create policy crm_actividades_select on crm_actividades for select to authenticated
  using (fn_crm_cuenta_puede_ver(cuenta_id));
drop policy if exists crm_actividades_insert on crm_actividades;
create policy crm_actividades_insert on crm_actividades for insert to authenticated
  with check (fn_crm_cuenta_puede_ver(cuenta_id));
drop policy if exists crm_actividades_update on crm_actividades;
create policy crm_actividades_update on crm_actividades for update to authenticated
  using (fn_es_superadmin() or (autor_user_id = auth.uid() and fn_crm_cuenta_puede_ver(cuenta_id)))
  with check (fn_es_superadmin() or (autor_user_id = auth.uid() and fn_crm_cuenta_puede_ver(cuenta_id)));
drop policy if exists crm_actividades_delete on crm_actividades;
create policy crm_actividades_delete on crm_actividades for delete to authenticated
  using (fn_es_superadmin() or (autor_user_id = auth.uid() and fn_crm_cuenta_puede_ver(cuenta_id)));

-- crm_tareas: todo lo de las cuentas que uno ve.
drop policy if exists crm_tareas_all on crm_tareas;
create policy crm_tareas_all on crm_tareas for all to authenticated
  using (fn_crm_cuenta_puede_ver(cuenta_id))
  with check (fn_crm_cuenta_puede_ver(cuenta_id));

-- crm_comisiones: el vendedor ve las suyas; las gestiona el superadmin.
drop policy if exists crm_comisiones_select on crm_comisiones;
create policy crm_comisiones_select on crm_comisiones for select to authenticated
  using (fn_es_superadmin() or vendedor_id = fn_mi_vendedor_id());
drop policy if exists crm_comisiones_superadmin_write on crm_comisiones;
create policy crm_comisiones_superadmin_write on crm_comisiones for all to authenticated
  using (fn_es_superadmin()) with check (fn_es_superadmin());

notify pgrst, 'reload schema';
