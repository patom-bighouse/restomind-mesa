-- ============================================================================
-- Fidelización: niveles y premios. El nivel de un cliente se calcula
-- siempre a partir de gasto_acumulado (histórico, no baja al canjear)
-- — nunca se guarda un nivel fijo en la ficha del cliente, así que
-- cambiar los umbrales después no deja clientes con un nivel viejo
-- inconsistente.
-- ============================================================================

create table if not exists niveles_fidelizacion (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  nombre text not null,
  umbral_gasto numeric(10,2) not null default 0,
  orden integer not null default 0,
  created_at timestamp with time zone not null default now(),
  unique (restaurant_id, nombre)
);

create table if not exists premios_fidelizacion (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  nombre text not null,
  descripcion text,
  costo_puntos integer not null check (costo_puntos > 0),
  nivel_minimo_id uuid references niveles_fidelizacion(id) on delete set null,
  activo boolean not null default true,
  orden integer not null default 0,
  created_at timestamp with time zone not null default now()
);

alter table niveles_fidelizacion enable row level security;
alter table premios_fidelizacion enable row level security;

grant select, insert, update, delete on table niveles_fidelizacion to authenticated;
grant select, insert, update, delete on table premios_fidelizacion to authenticated;

drop policy if exists niveles_fidelizacion_dueno on niveles_fidelizacion;
create policy niveles_fidelizacion_dueno on niveles_fidelizacion for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

drop policy if exists premios_fidelizacion_dueno on premios_fidelizacion;
create policy premios_fidelizacion_dueno on premios_fidelizacion for all
  using (
    restaurant_id in (select id from restaurants where user_id = auth.uid())
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- El cliente anónimo (Mesa.jsx) nunca lee `clientes` directo (podría
-- consultar el saldo de cualquier teléfono ajeno) — todo pasa por esta
-- función, que arma en un único JSON los puntos, el gasto acumulado,
-- el nivel actual, cuánto falta para el próximo, y los premios que
-- puede ver (activos y, si tienen nivel mínimo, solo si ya lo alcanzó).
create or replace function fn_estado_fidelizacion(p_restaurant_id uuid, p_telefono text)
returns json
language plpgsql
security definer
as $$
declare
  v_puntos integer := 0;
  v_gasto numeric := 0;
  v_nivel_actual json;
  v_proximo_nivel json;
  v_premios json;
begin
  select coalesce(puntos, 0), coalesce(gasto_acumulado, 0)
    into v_puntos, v_gasto
  from clientes
  where restaurant_id = p_restaurant_id and telefono = p_telefono;

  v_puntos := coalesce(v_puntos, 0);
  v_gasto := coalesce(v_gasto, 0);

  select json_build_object('id', id, 'nombre', nombre, 'umbral_gasto', umbral_gasto)
    into v_nivel_actual
  from niveles_fidelizacion
  where restaurant_id = p_restaurant_id and umbral_gasto <= v_gasto
  order by umbral_gasto desc
  limit 1;

  select json_build_object('id', id, 'nombre', nombre, 'umbral_gasto', umbral_gasto)
    into v_proximo_nivel
  from niveles_fidelizacion
  where restaurant_id = p_restaurant_id and umbral_gasto > v_gasto
  order by umbral_gasto asc
  limit 1;

  select coalesce(json_agg(json_build_object(
      'id', p.id,
      'nombre', p.nombre,
      'descripcion', p.descripcion,
      'costo_puntos', p.costo_puntos,
      'disponible', (p.costo_puntos <= v_puntos)
    ) order by p.costo_puntos), '[]'::json)
    into v_premios
  from premios_fidelizacion p
  where p.restaurant_id = p_restaurant_id
    and p.activo = true
    and (
      p.nivel_minimo_id is null
      or exists (
        select 1 from niveles_fidelizacion nm
        where nm.id = p.nivel_minimo_id and nm.umbral_gasto <= v_gasto
      )
    );

  return json_build_object(
    'puntos', v_puntos,
    'gasto_acumulado', v_gasto,
    'nivel_actual', v_nivel_actual,
    'proximo_nivel', v_proximo_nivel,
    'premios', v_premios
  );
end;
$$;

grant execute on function fn_estado_fidelizacion(uuid, text) to anon, authenticated;
