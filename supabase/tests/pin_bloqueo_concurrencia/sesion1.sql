-- Prueba manual de concurrencia del PIN (migración 20261113082740). SOLO TEST.
-- Sesión 1: mantiene bloqueada la fila de intentos de un camarero 8 s.
-- Lanzar este archivo y, a los 3 s, sesion2.sql en otra terminal:
--   npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/pin_bloqueo_concurrencia/sesion1.sql </dev/null &
--   sleep 3; npx supabase db query --remote=sfkwbhzelrestmrmptql --yes -f supabase/tests/pin_bloqueo_concurrencia/sesion2.sql </dev/null
-- Esperado: sesion2 da espera_ms ≈ 5000 (esperó a la sesión 1). Las dos hacen rollback.
-- Camarero: Xavi de "Restaurante de Prueba" en Test.
begin;
set local role anon;
select * from public.fn_verificar_camarero_pin('b33b0de2-4504-4709-9d3b-9efbfabd55b1','472b6bee-c868-4627-b0d7-937be3ebe020','0000');
select pg_sleep(8);
rollback;
