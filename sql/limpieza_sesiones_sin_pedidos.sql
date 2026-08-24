-- ============================================================================
-- Verificación de mantenimiento — se queda en el repo, no es de un
-- solo uso. Desde que AdminMesas.jsx borra las sesiones cerradas sin
-- pedidos en vez de guardarlas (en lugar de solo cerrarlas), el
-- SELECT de abajo debería devolver siempre 0 filas. Si alguna vez
-- aparece algo, es señal de que ese camino se rompió en algún punto
-- (bug, cambio posterior, etc.) y conviene revisarlo antes de correr
-- el DELETE.
--
-- Ya se corrió una vez en test y en producción (2026-08-24) para
-- limpiar lo acumulado antes de este cambio.
-- ============================================================================

-- PASO 1: previsualizar
select ts.id, ts.table_id, ts.abierta_at, ts.cerrada_at, ts.estado, r.nombre as restaurante
from table_sessions ts
join restaurants r on r.id = ts.restaurant_id
where ts.estado <> 'abierta'
  and not exists (
    select 1 from orders o
    where o.table_session_id = ts.id
      and o.estado <> 'cancelado'
  )
  and not exists (
    select 1 from table_session_payments p
    where p.table_session_id = ts.id
  )
order by ts.abierta_at desc;

-- PASO 2: borrar (corré esto después de revisar el resultado de arriba)
delete from table_sessions ts
where ts.estado <> 'abierta'
  and not exists (
    select 1 from orders o
    where o.table_session_id = ts.id
      and o.estado <> 'cancelado'
  )
  and not exists (
    select 1 from table_session_payments p
    where p.table_session_id = ts.id
  );
