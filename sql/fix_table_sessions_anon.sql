-- ============================================================================
-- table_sessions estaba en un estado raro: el grant heredado de
-- fix_grants_test.sql le daba a anon INSERT/UPDATE/DELETE sobre TODAS
-- las columnas (incluidas total/estado_pago/metodo_pago/motivo_exencion,
-- datos de pago que anon nunca debería poder leer ni tocar), pero no
-- existía NINGUNA política RLS que permitiera el INSERT/UPDATE — así
-- que "abrir mesa" desde el modo camarero (Camarero.jsx:364-375) muy
-- probablemente está fallando en producción ahora mismo.
--
-- Este fix:
--   1) agrega las políticas de INSERT/UPDATE que faltaban, con
--      validaciones básicas de consistencia (que la mesa exista y
--      sea del mismo restaurante; que el camarero exista, esté
--      activo y sea del mismo restaurante).
--   2) acota los GRANT a nivel de columna a exactamente lo que usa
--      Camarero.jsx/Mesa.jsx hoy — nada de columnas de pago.
--
-- Lo que este fix NO resuelve: anon sigue pudiendo leer sesiones
-- abiertas de CUALQUIER restaurante (teléfono/nombre de cliente
-- incluidos) porque la política de SELECT sigue sin estar acotada
-- por mesa/token — eso necesita el rediseño con RPC + qr_token que
-- quedó como punto aparte en la tabla de prioridades.
-- ============================================================================

drop policy if exists anon_insert_table_sessions on table_sessions;
create policy anon_insert_table_sessions on table_sessions for insert to anon
  with check (
    estado = 'abierta'
    and exists (
      select 1 from tables t
      where t.id = table_id and t.restaurant_id = table_sessions.restaurant_id and t.activa = true
    )
    and (
      camarero_id is null
      or exists (
        select 1 from camareros c
        where c.id = camarero_id and c.restaurant_id = table_sessions.restaurant_id and c.activo = true
      )
    )
  );

drop policy if exists anon_update_table_sessions on table_sessions;
create policy anon_update_table_sessions on table_sessions for update to anon
  using (estado = 'abierta')
  with check (
    estado = 'abierta'
    and (
      camarero_id is null
      or exists (
        select 1 from camareros c
        where c.id = camarero_id and c.restaurant_id = table_sessions.restaurant_id and c.activo = true
      )
    )
  );

revoke all on table table_sessions from anon;

grant select (
  id, table_id, restaurant_id, estado, abierta_at, comensales, camarero_id, cliente_telefono, cliente_nombre
) on table_sessions to anon;

grant insert (
  table_id, restaurant_id, comensales, camarero_id
) on table_sessions to anon;

grant update (
  camarero_id, cliente_telefono, cliente_nombre
) on table_sessions to anon;

notify pgrst, 'reload schema';
