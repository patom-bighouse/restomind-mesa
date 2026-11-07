-- ============================================================================
-- Hora de recogida de los pedidos takeaway en su propia columna.
--
-- Hasta ahora el agente de WhatsApp solo la dejaba como texto en
-- orders.notas ("Recogida a las 21:30"): Cocina no podía ordenar por ella
-- ni avisar cuando se acerca. Con la columna:
--   - Cocina coloca cada takeaway según cuándo hay que empezar a
--     prepararlo (hora de recogida - minutos de preparación) y muestra
--     "Recoge a las 21:30 · en 25 min".
--   - El panel la muestra y la exporta.
--   - Servirá como hora de entrega cuando se active el envío a domicilio.
--
-- timestamptz (fecha + hora), para que un pedido a las 23:50 para recoger
-- a las 00:15 quede en el día correcto.
--
-- Ejecutar ANTES de reimportar el workflow de n8n que la rellena (si no,
-- la creación de pedidos falla al no existir la columna).
-- Re-ejecutable. Ejecutar en staging y después en producción.
-- ============================================================================

alter table orders add column if not exists hora_recogida timestamp with time zone;

create index if not exists orders_restaurant_hora_recogida_idx
  on orders (restaurant_id, hora_recogida)
  where hora_recogida is not null;

-- Pedidos existentes: se saca la hora de la nota. Fecha = la del pedido en
-- España; si la hora de recogida es anterior a la hora del pedido, es que
-- era para después de medianoche (día siguiente).
update orders o
set hora_recogida = (
  (x.fecha_pedido + case when x.hora < x.hora_pedido then 1 else 0 end) + x.hora
)::timestamp at time zone 'Europe/Madrid'
from (
  select id,
         (created_at at time zone 'Europe/Madrid')::date as fecha_pedido,
         (created_at at time zone 'Europe/Madrid')::time as hora_pedido,
         (substring(notas from 'Recogida a las (\d{1,2}:\d{2})'))::time as hora
  from orders
  where tipo = 'takeaway'
    and hora_recogida is null
    and notas ~ 'Recogida a las \d{1,2}:\d{2}'
) x
where o.id = x.id;

notify pgrst, 'reload schema';
