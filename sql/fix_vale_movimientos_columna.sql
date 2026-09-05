-- ============================================================================
-- La columna table_session_id de vale_movimientos (necesaria para que
-- fn_canjear_vale_regalo pueda registrar un canje que no está atado a
-- ningún pedido) venía en sql/vales_regalo_pago.sql, pero no llegó a
-- aplicarse en este proyecto. "if not exists" hace que sea seguro
-- correr esto aunque ya se hubiera creado.
-- ============================================================================

alter table vale_movimientos
  add column if not exists table_session_id uuid references table_sessions(id) on delete set null;
