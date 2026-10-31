-- ============================================================================
-- CRM: la "próxima acción" de una cuenta pasa a ser su tarea pendiente más
-- cercana (crm_tareas), en vez de un texto + fecha sueltos en crm_cuentas.
--
-- Convierte lo que se hubiera escrito en crm_cuentas.proxima_accion /
-- proxima_accion_fecha en una tarea pendiente y vacía esas columnas (quedan
-- sin uso). Re-ejecutable: si ya no hay nada que convertir, no hace nada.
-- Ejecutar después de crm_vendedores.sql, en staging y en producción.
-- ============================================================================

insert into crm_tareas (cuenta_id, titulo, vence_en, created_by)
select c.id,
       coalesce(nullif(trim(c.proxima_accion), ''), 'Próxima acción'),
       coalesce(c.proxima_accion_fecha, current_date),
       c.created_by
from crm_cuentas c
where (c.proxima_accion is not null or c.proxima_accion_fecha is not null)
  and not exists (
    select 1 from crm_tareas t
    where t.cuenta_id = c.id
      and t.titulo = coalesce(nullif(trim(c.proxima_accion), ''), 'Próxima acción')
  );

update crm_cuentas
set proxima_accion = null, proxima_accion_fecha = null
where proxima_accion is not null or proxima_accion_fecha is not null;
