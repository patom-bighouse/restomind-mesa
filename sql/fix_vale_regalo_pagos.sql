-- ============================================================================
-- Dos bugs en el canje de vale regalo como pago:
--
-- 1) fn_canjear_vale_regalo insertaba en una tabla "pagos" que no
--    existe — la tabla real es table_session_payments (la misma que
--    usa CuentaMesa.jsx). Se corrige la función completa.
-- 2) table_session_payments_metodo_pago_check solo permitía los
--    métodos originales (tarjeta/efectivo/bizum/otro) — "vale_regalo"
--    no estaba dado de alta a nivel de base de datos, así que
--    cualquier intento de registrarlo (desde el canje automático o
--    desde el desplegable manual de CuentaMesa.jsx) violaba la
--    restricción.
-- ============================================================================

alter table table_session_payments drop constraint if exists table_session_payments_metodo_pago_check;
alter table table_session_payments add constraint table_session_payments_metodo_pago_check
  check (metodo_pago in ('tarjeta', 'efectivo', 'bizum', 'vale_regalo', 'otro'));

create or replace function fn_canjear_vale_regalo(
  p_table_session_id uuid,
  p_vale_codigo text,
  p_vale_importe numeric
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_restaurant_id uuid;
  v_vale record;
begin
  select restaurant_id into v_restaurant_id
  from table_sessions
  where id = p_table_session_id and estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa no existe o ya está cerrada';
  end if;

  if p_vale_importe is null or p_vale_importe <= 0 then
    raise exception 'Importe inválido';
  end if;

  select id, saldo_actual, activo, fecha_vencimiento into v_vale
  from vales_regalo
  where restaurant_id = v_restaurant_id and upper(codigo) = upper(p_vale_codigo)
  for update;

  if v_vale.id is null then
    raise exception 'Ese vale no existe';
  end if;
  if not v_vale.activo then
    raise exception 'Ese vale ya no está activo';
  end if;
  if v_vale.fecha_vencimiento < current_date then
    raise exception 'Ese vale ya venció';
  end if;
  if p_vale_importe > v_vale.saldo_actual then
    raise exception 'El vale no tiene saldo suficiente';
  end if;

  update vales_regalo set saldo_actual = saldo_actual - p_vale_importe where id = v_vale.id;

  insert into vale_movimientos (vale_id, importe, table_session_id)
  values (v_vale.id, -p_vale_importe, p_table_session_id);

  insert into table_session_payments (table_session_id, restaurant_id, monto, metodo_pago)
  values (p_table_session_id, v_restaurant_id, p_vale_importe, 'vale_regalo');
end;
$$;

grant execute on function fn_canjear_vale_regalo(uuid, text, numeric) to anon, authenticated;
