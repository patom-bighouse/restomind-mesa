-- ============================================================================
-- Corrige el canje de vales regalo: antes solo se podía aplicar un
-- vale al confirmar un pedido nuevo (vía fn_registrar_pedido), lo que
-- obligaba a acordarse del vale ANTES de pedir. En la práctica el
-- cliente puede acordarse recién al momento de pagar, sin querer
-- pedir nada más.
--
-- Se resuelve tratando el vale como una forma de pago más — igual que
-- efectivo/tarjeta en CuentaMesa.jsx — en vez de un descuento atado a
-- un pedido: se puede aplicar en cualquier momento mientras la mesa
-- siga abierta (sin estarlo, ya no hay "cuenta" a la que aplicarlo).
-- El canje dentro de fn_registrar_pedido (p_vale_codigo/p_vale_importe)
-- queda sin usar desde el frontend — no se toca esa función para no
-- arriesgar su firma ya desplegada, simplemente deja de invocarse así.
-- ============================================================================

alter table vale_movimientos
  add column if not exists table_session_id uuid references table_sessions(id) on delete set null;

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

  insert into pagos (table_session_id, restaurant_id, monto, metodo_pago)
  values (p_table_session_id, v_restaurant_id, p_vale_importe, 'vale_regalo');
end;
$$;

grant execute on function fn_canjear_vale_regalo(uuid, text, numeric) to anon, authenticated;
