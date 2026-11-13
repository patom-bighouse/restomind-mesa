-- Sesión 2 de la prueba de concurrencia del PIN: ver sesion1.sql.
begin;
create temp table _t(ms int) on commit drop;
do $$ declare t0 timestamptz := clock_timestamp(); begin
  set local role anon;
  perform public.fn_verificar_camarero_pin('b33b0de2-4504-4709-9d3b-9efbfabd55b1','472b6bee-c868-4627-b0d7-937be3ebe020','0000');
  reset role;
  insert into _t values (extract(epoch from clock_timestamp()-t0)*1000);
end $$;
select ms as espera_ms from _t;
rollback;
