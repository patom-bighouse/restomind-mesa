-- ============================================================================
-- CRM: buscador de restaurantes (Google Places) para cargar prospectos.
--
--   crm_cuentas     → nuevas columnas con lo que trae Google: identificador
--                     del local (evita duplicados), web, valoración, nº de
--                     reseñas, nivel de precio y tamaño estimado.
--   crm_config      → una sola fila: consultas gratis al mes, precio por
--                     1.000 consultas y si los vendedores pueden buscar.
--   crm_busquedas   → registro de cada búsqueda y de cuántas consultas
--                     cobrables a Google hizo (para el contador de uso).
--
-- La búsqueda la hace la Edge Function crm-buscar-restaurantes: la clave de
-- Google nunca llega al navegador. Esa función usa fn_crm_puede_buscar(),
-- fn_crm_registrar_busqueda() y fn_crm_duplicados() de este archivo.
--
-- Re-ejecutable. Ejecutar después de crm_vendedores.sql y crm_maps_url.sql,
-- en staging y en producción.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Datos de Google en cada cuenta
-- ---------------------------------------------------------------------------

alter table crm_cuentas
  add column if not exists google_place_id text,
  add column if not exists web text,
  add column if not exists valoracion numeric(2,1),
  add column if not exists num_resenas integer,
  add column if not exists nivel_precio smallint,
  add column if not exists tamano_estimado text;

-- Un mismo local de Google solo puede estar una vez en el CRM. Índice único
-- normal (no parcial) para poder usar "on conflict do nothing" al importar;
-- los null no chocan entre sí.
create unique index if not exists crm_cuentas_google_place_id_key on crm_cuentas (google_place_id);

alter table crm_cuentas drop constraint if exists crm_cuentas_tamano_estimado_check;
alter table crm_cuentas add constraint crm_cuentas_tamano_estimado_check
  check (tamano_estimado is null or tamano_estimado in ('pequeno', 'mediano', 'grande', 'muy_grande'));

alter table crm_cuentas drop constraint if exists crm_cuentas_nivel_precio_check;
alter table crm_cuentas add constraint crm_cuentas_nivel_precio_check
  check (nivel_precio is null or nivel_precio between 0 and 4);

alter table crm_cuentas drop constraint if exists crm_cuentas_web_check;
alter table crm_cuentas add constraint crm_cuentas_web_check
  check (web is null or web ~* '^https?://');

-- ---------------------------------------------------------------------------
-- Configuración (una sola fila)
-- ---------------------------------------------------------------------------

create table if not exists crm_config (
  id boolean primary key default true check (id),
  -- Google cambia sus tarifas: se ajustan aquí sin tocar código.
  places_gratis_mes integer not null default 1000 check (places_gratis_mes >= 0),
  places_precio_1000 numeric(8,2) not null default 35 check (places_precio_1000 >= 0),
  -- Preparado para más adelante: el superadmin decide si los vendedores
  -- también pueden buscar.
  vendedores_pueden_buscar boolean not null default false,
  updated_at timestamp with time zone not null default now()
);

insert into crm_config (id) values (true) on conflict (id) do nothing;

alter table crm_config enable row level security;

drop policy if exists crm_config_select on crm_config;
create policy crm_config_select on crm_config for select to authenticated
  using (fn_es_superadmin() or fn_mi_vendedor_id() is not null);

drop policy if exists crm_config_update on crm_config;
create policy crm_config_update on crm_config for update to authenticated
  using (fn_es_superadmin()) with check (fn_es_superadmin());

-- ---------------------------------------------------------------------------
-- Registro de búsquedas
-- ---------------------------------------------------------------------------

create table if not exists crm_busquedas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid default auth.uid(),
  autor_nombre text,
  parametros jsonb not null default '{}'::jsonb,
  consultas integer not null default 0 check (consultas >= 0), -- llamadas cobrables a Google
  resultados integer not null default 0,
  created_at timestamp with time zone not null default now()
);

create index if not exists crm_busquedas_created_idx on crm_busquedas (created_at);

alter table crm_busquedas enable row level security;

-- Solo lectura para el superadmin. Nadie inserta, edita ni borra desde la
-- API: se escribe únicamente vía fn_crm_registrar_busqueda().
drop policy if exists crm_busquedas_select on crm_busquedas;
create policy crm_busquedas_select on crm_busquedas for select to authenticated
  using (fn_es_superadmin());

-- ---------------------------------------------------------------------------
-- Funciones
-- ---------------------------------------------------------------------------

create or replace function fn_crm_puede_buscar()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select fn_es_superadmin()
    or (fn_mi_vendedor_id() is not null
        and coalesce((select vendedores_pueden_buscar from crm_config where id), false))
$$;

-- Google factura por mes natural en hora del Pacífico.
create or replace function fn_crm_uso_places()
returns table (
  gratis_mes integer,
  usadas_mes integer,
  restantes integer,
  excedidas integer,
  precio_1000 numeric,
  coste_estimado numeric,
  mes date
)
language sql
stable
security definer
set search_path to 'public'
as $$
  with cfg as (
    select places_gratis_mes, places_precio_1000 from crm_config where id
  ), inicio as (
    select date_trunc('month', now() at time zone 'America/Los_Angeles') as ini
  ), uso as (
    select coalesce(sum(b.consultas), 0)::int as usadas
    from crm_busquedas b, inicio i
    where (b.created_at at time zone 'America/Los_Angeles') >= i.ini
  )
  select cfg.places_gratis_mes,
         uso.usadas,
         greatest(cfg.places_gratis_mes - uso.usadas, 0),
         greatest(uso.usadas - cfg.places_gratis_mes, 0),
         cfg.places_precio_1000,
         round(greatest(uso.usadas - cfg.places_gratis_mes, 0) * cfg.places_precio_1000 / 1000.0, 2),
         (select ini::date from inicio)
  from cfg, uso
  where fn_crm_puede_buscar()
$$;

create or replace function fn_crm_registrar_busqueda(p_parametros jsonb, p_consultas integer, p_resultados integer)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not fn_crm_puede_buscar() then
    raise exception 'No tienes permiso para buscar restaurantes.';
  end if;
  insert into crm_busquedas (user_id, autor_nombre, parametros, consultas, resultados)
  values (
    auth.uid(),
    coalesce((select v.nombre from vendedores v where v.user_id = auth.uid() limit 1), 'Superadmin'),
    coalesce(p_parametros, '{}'::jsonb),
    greatest(coalesce(p_consultas, 0), 0),
    greatest(coalesce(p_resultados, 0), 0)
  );
end;
$$;

-- Cuáles de los locales encontrados ya están en el CRM (en cualquier
-- cartera, aunque quien busca no la vea): por identificador de Google o por
-- teléfono (últimos 9 dígitos). Devuelve solo el motivo, nunca datos de la
-- cuenta existente.
create or replace function fn_crm_duplicados(p_locales jsonb)
returns table (place_id text, motivo text)
language sql
stable
security definer
set search_path to 'public'
as $$
  with l as (
    select x->>'place_id' as place_id,
           right(regexp_replace(coalesce(x->>'telefono', ''), '\D', '', 'g'), 9) as tel
    from jsonb_array_elements(coalesce(p_locales, '[]'::jsonb)) x
  )
  select l.place_id,
         case when exists (select 1 from crm_cuentas c where c.google_place_id = l.place_id)
              then 'google' else 'telefono' end
  from l
  where fn_crm_puede_buscar()
    and (
      exists (select 1 from crm_cuentas c where c.google_place_id = l.place_id)
      or (length(l.tel) = 9 and exists (
        select 1 from crm_cuentas c
        where right(regexp_replace(coalesce(c.telefono, ''), '\D', '', 'g'), 9) = l.tel
      ))
    )
$$;

revoke execute on function fn_crm_puede_buscar() from public, anon;
revoke execute on function fn_crm_uso_places() from public, anon;
revoke execute on function fn_crm_registrar_busqueda(jsonb, integer, integer) from public, anon;
revoke execute on function fn_crm_duplicados(jsonb) from public, anon;
grant execute on function fn_crm_puede_buscar() to authenticated;
grant execute on function fn_crm_uso_places() to authenticated;
grant execute on function fn_crm_registrar_busqueda(jsonb, integer, integer) to authenticated;
grant execute on function fn_crm_duplicados(jsonb) to authenticated;
