-- ============================================================================
-- Teléfono del cliente en un único formato (fidelización: puntos y sellos).
--
-- La ficha del cliente se identifica por (restaurant_id, telefono), con el
-- texto tal cual. El mismo móvil llegaba de formas distintas y daba fichas
-- distintas, con los puntos repartidos:
--   677226644          lo que escribe el cliente
--   34677226644        el número de WhatsApp (respaldo del agente takeaway)
--   +34 677 22 66 44   lo que se teclea en la mesa o en Camarero
--
-- Formato único: solo dígitos; los móviles/fijos españoles, en 9 cifras
-- sin el 34 (es el formato que ya tenían todos los datos guardados). Los
-- números extranjeros conservan su prefijo internacional.
--
--   1. fn_normalizar_telefono()
--   2. Fusiona fichas que pasen a coincidir (puntos, gasto, movimientos y
--      sellos) y normaliza los teléfonos ya guardados.
--   3. Triggers que normalizan al guardar en clientes, orders y
--      table_sessions: cubre el agente de WhatsApp, la mesa, Camarero y el
--      panel sin tocar cada función.
--   4. fn_estado_fidelizacion busca con el teléfono normalizado.
--
-- Re-ejecutable. Ejecutar en staging y después en producción.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Normalización
-- ---------------------------------------------------------------------------

create or replace function fn_normalizar_telefono(p_telefono text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select nullif(
    case
      -- 34 + 9 cifras españolas (6/7/8/9) → 9 cifras
      when d ~ '^34[6789]\d{8}$' then substr(d, 3)
      else d
    end, '')
  from (
    -- solo dígitos, sin el 00 internacional
    select regexp_replace(regexp_replace(coalesce(p_telefono, ''), '\D', '', 'g'), '^00', '') as d
  ) x
$$;

grant execute on function fn_normalizar_telefono(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Datos existentes: fusionar duplicados y normalizar
-- ---------------------------------------------------------------------------

do $$
declare
  g record;
  v_keeper uuid;
begin
  -- Grupos de fichas del mismo restaurante que, normalizadas, son el mismo
  -- teléfono. Se conserva la más antigua.
  for g in
    select restaurant_id, fn_normalizar_telefono(telefono) as tel,
           array_agg(id order by created_at, id) as ids
    from clientes
    where fn_normalizar_telefono(telefono) is not null
    group by restaurant_id, fn_normalizar_telefono(telefono)
    having count(*) > 1
  loop
    v_keeper := g.ids[1];

    update clientes k
    set puntos = k.puntos + o.puntos,
        gasto_acumulado = coalesce(k.gasto_acumulado, 0) + o.gasto,
        ultima_visita = greatest(k.ultima_visita, o.ultima_visita),
        nombre = coalesce(k.nombre, o.nombre),
        updated_at = now()
    from (
      select sum(puntos) as puntos, sum(coalesce(gasto_acumulado, 0)) as gasto,
             max(ultima_visita) as ultima_visita,
             (array_agg(nombre order by updated_at desc) filter (where nombre is not null))[1] as nombre
      from clientes where id = any(g.ids[2:])
    ) o
    where k.id = v_keeper;

    update clientes_movimientos set cliente_id = v_keeper where cliente_id = any(g.ids[2:]);

    -- Sellos: una fila por promo en la ficha conservada, con lo acumulado
    -- por todas las fichas del grupo.
    with agg as (
      select promo_id, sum(unidades_acumuladas) as unidades, sum(premios_disponibles) as premios,
             min(fecha_inicio_ciclo) as inicio
      from clientes_sellos where cliente_id = any(g.ids) group by promo_id
    ), borrar as (
      delete from clientes_sellos where cliente_id = any(g.ids[2:])
    )
    insert into clientes_sellos (cliente_id, promo_id, unidades_acumuladas, premios_disponibles, fecha_inicio_ciclo, updated_at)
    select v_keeper, promo_id, unidades, premios, inicio, now() from agg
    on conflict (cliente_id, promo_id) do update
      set unidades_acumuladas = excluded.unidades_acumuladas,
          premios_disponibles = excluded.premios_disponibles,
          fecha_inicio_ciclo = excluded.fecha_inicio_ciclo,
          updated_at = now();

    delete from clientes where id = any(g.ids[2:]);

    raise notice 'Fusionadas % fichas del teléfono % (restaurante %)', array_length(g.ids, 1), g.tel, g.restaurant_id;
  end loop;

  update clientes set telefono = fn_normalizar_telefono(telefono)
  where fn_normalizar_telefono(telefono) is not null and telefono is distinct from fn_normalizar_telefono(telefono);

  update orders set cliente_telefono = fn_normalizar_telefono(cliente_telefono)
  where cliente_telefono is distinct from fn_normalizar_telefono(cliente_telefono);

  -- table_sessions tiene un trigger que bloquea cambios en restaurantes
  -- inactivos: fila a fila, y si alguna falla se deja como está.
  for g in
    select id from table_sessions
    where cliente_telefono is distinct from fn_normalizar_telefono(cliente_telefono)
  loop
    begin
      update table_sessions set cliente_telefono = fn_normalizar_telefono(cliente_telefono) where id = g.id;
    exception when others then
      raise notice 'Sesión % no normalizada: %', g.id, sqlerrm;
    end;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Normalizar al guardar
-- ---------------------------------------------------------------------------

create or replace function fn_trg_normalizar_telefono_cliente()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if tg_table_name = 'clientes' then
    new.telefono := coalesce(fn_normalizar_telefono(new.telefono), new.telefono);
  else
    new.cliente_telefono := fn_normalizar_telefono(new.cliente_telefono);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_normalizar_telefono on clientes;
create trigger trg_normalizar_telefono
  before insert or update of telefono on clientes
  for each row execute function fn_trg_normalizar_telefono_cliente();

drop trigger if exists trg_normalizar_telefono on orders;
create trigger trg_normalizar_telefono
  before insert or update of cliente_telefono on orders
  for each row execute function fn_trg_normalizar_telefono_cliente();

drop trigger if exists trg_normalizar_telefono on table_sessions;
create trigger trg_normalizar_telefono
  before insert or update of cliente_telefono on table_sessions
  for each row execute function fn_trg_normalizar_telefono_cliente();

-- ---------------------------------------------------------------------------
-- 4. Consulta de puntos (mesa) con el teléfono normalizado
-- ---------------------------------------------------------------------------

-- Se reescribe solo la condición de búsqueda sobre la definición vigente,
-- para no pisar el resto de la función.
do $$
declare
  v_def text := pg_get_functiondef('public.fn_estado_fidelizacion(uuid,text)'::regprocedure);
begin
  if v_def like '%telefono = fn_normalizar_telefono(p_telefono)%' then
    raise notice 'fn_estado_fidelizacion ya normalizaba el teléfono.';
  elsif v_def like '%telefono = p_telefono%' then
    execute replace(v_def, 'telefono = p_telefono', 'telefono = fn_normalizar_telefono(p_telefono)');
  else
    raise exception 'fn_estado_fidelizacion no tiene la condición esperada: revisar a mano.';
  end if;
end;
$$;

notify pgrst, 'reload schema';
