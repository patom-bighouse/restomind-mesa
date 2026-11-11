-- ============================================================================
-- Bug: al agregar p_vale_codigo/p_vale_importe al final de
-- fn_registrar_pedido, "CREATE OR REPLACE FUNCTION" no reemplazó la
-- versión anterior de 5 parámetros — en Postgres, una función con más
-- parámetros (aunque tengan default) es una firma distinta, así que
-- quedaron dos versiones ambiguas al mismo tiempo. Cualquier llamada
-- que solo mande los primeros 5 parámetros (como hace ahora
-- Mesa.jsx/Camarero.jsx, ya que el vale se canjea aparte con
-- fn_canjear_vale_regalo) no sabe cuál de las dos usar.
--
-- Se borran todas las firmas viejas posibles y queda solo la actual
-- de 7 parámetros — "if exists" hace que sea seguro correrlo aunque
-- alguna de estas ya no exista en este proyecto.
-- ============================================================================

drop function if exists public.fn_registrar_pedido(uuid, jsonb);
drop function if exists public.fn_registrar_pedido(uuid, jsonb, text);
drop function if exists public.fn_registrar_pedido(uuid, jsonb, text, uuid);
drop function if exists public.fn_registrar_pedido(uuid, jsonb, text, uuid, jsonb);
