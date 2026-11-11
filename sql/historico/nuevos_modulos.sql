-- ============================================================================
-- Reorganización de "núcleo": varias funcionalidades que hasta ahora
-- estaban incluidas gratis para cualquier restaurante pasan a ser
-- módulos de pago independientes, agrupadas por a quién le sirven:
--
--   gestion_equipo         — camareros con PIN y roles múltiples +
--                            sectores de cocina (para equipos grandes)
--   marketing_fidelizacion — vales regalo + fidelización + upsell
--                            (herramientas para vender más/retener)
--   reservas               — panel de reservas + página pública
--   multi_menu             — precios por franja horaria / día
--   marca_propia           — subdominio propio para el link de mesas
--
-- Los restaurantes que ya existen NO quedan con estos módulos
-- activados automáticamente por este script — hay que activarlos
-- manualmente desde SuperAdminRestaurantes para cada restaurante que
-- ya los venía usando gratis, si se decide no cobrárselos de entrada.
-- ============================================================================

insert into modulos (key, nombre, descripcion, requiere, orden) values
  ('gestion_equipo', 'Gestión de equipo', 'Camareros con PIN y permisos por rol, y sectores de cocina para restaurantes con varios turnos o partidas.', 'nucleo', 9),
  ('marketing_fidelizacion', 'Marketing y fidelización', 'Vales regalo, puntos de fidelización y sugerencias de venta cruzada (upsell) para vender más y hacer que vuelvan.', 'nucleo', 10),
  ('reservas', 'Reservas', 'Gestión de reservas y página pública para que los clientes reserven online.', 'nucleo', 11),
  ('multi_menu', 'Multi-menú', 'Precios distintos según franja horaria o día de la semana (desayuno, almuerzo, happy hour...).', 'nucleo', 12),
  ('marca_propia', 'Marca propia', 'Subdominio propio para el link de tus mesas, en vez del dominio compartido de la plataforma.', 'nucleo', 13)
on conflict (key) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  requiere = excluded.requiere,
  orden = excluded.orden;
