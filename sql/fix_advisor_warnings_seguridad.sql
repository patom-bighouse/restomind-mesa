-- ============================================================================
-- Revisión de los 119 warnings del Security Advisor de Supabase
-- (2026-09-22). Tres cosas distintas, en orden de importancia real:
--
-- 1) fn_disparar_webhooks: ÚNICO hallazgo con riesgo real. No tiene
--    ningún chequeo interno de autorización ni GRANT/REVOKE explícito
--    — depende del permiso de EXECUTE que Postgres le da a PUBLIC por
--    defecto al crear cualquier función. Como no verifica nada, cualquiera
--    sin sesión podía llamarla directo vía
--    /rest/v1/rpc/fn_disparar_webhooks y falsificar un webhook (con firma
--    HMAC válida, indistinguible de uno real) hacia la URL configurada
--    por cualquier restaurante. Solo la llaman internamente los
--    fn_trigger_webhook_* (funciones de trigger, no vienen de fuera) —
--    no necesita ser accesible por anon/authenticated en absoluto.
--
-- 2) Funciones de superadmin/dueño (fn_asignar_plan, fn_iniciar_trial,
--    fn_crear_camarero, etc.): SÍ verifican `auth.uid()` contra
--    superadmins o el dueño del restaurante — en la práctica ya están
--    protegidas (un anon las puede *intentar* llamar, pero la función
--    las rechaza). El aviso es por el mismo motivo: falta el REVOKE
--    explícito de PUBLIC. Se corrige por prolijidad/defensa en
--    profundidad, no porque haya un hueco real.
--
-- 3) function_search_path_mutable (~12+ funciones, algunas redefinidas
--    varias veces en distintos archivos a lo largo del proyecto — no
--    hay certeza desde el repo de cuál firma es la vigente hoy en
--    producción). En vez de adivinar, este bloque recorre el catálogo
--    real de Postgres (pg_proc) y le fija search_path a CUALQUIER
--    función del schema public que no lo tenga, sea cual sea su firma
--    actual — sin ambigüedad posible.
--
-- No se tocan las funciones con grant a anon/authenticated que NO
-- verifican auth.uid() (fn_registrar_pedido, fn_crear_reserva_web,
-- fn_camarero_*, fn_staff_*, etc.) — es el diseño intencional de la
-- app: clientes (QR) y camareros (PIN) operan sin login de Supabase
-- Auth, así que necesitan poder llamarlas como anon. Ese aviso del
-- Advisor es un falso positivo esperado para esas.
--
-- 4) public_bucket_allows_listing (menu-images): el bucket ya está
--    marcado como "Public" a nivel del propio bucket, así que las
--    fotos se siguen sirviendo por URL directa sin necesitar ninguna
--    policy de SELECT en storage.objects. Había dos policies de
--    lectura pública duplicadas ahí encima, lo que además habilitaba
--    listar/enumerar todos los archivos del bucket (no solo pedir uno
--    puntual por URL conocida) — se sacan las dos, sin afectar la
--    carga de imágenes.
--
-- No se toca extension_in_public (pg_net): mover el schema de esa
-- extensión es más delicado (pg_net ya usa un schema propio "net" del
-- que depende fn_disparar_webhooks) y no es una exposición real de
-- datos, solo prolijidad — queda pendiente para revisar con más calma.
-- ============================================================================

-- 1) fn_disparar_webhooks — cerrar el acceso público real
revoke execute on function fn_disparar_webhooks(uuid, text, jsonb) from public;
revoke execute on function fn_disparar_webhooks(uuid, text, jsonb) from anon;
revoke execute on function fn_disparar_webhooks(uuid, text, jsonb) from authenticated;

-- 2) Funciones de superadmin/dueño ya protegidas por auth.uid() —
--    cerrar también el permiso implícito a PUBLIC
revoke execute on function fn_asignar_modulo_a_plan(text, text) from public;
revoke execute on function fn_asignar_plan(uuid, text) from public;
revoke execute on function fn_iniciar_trial(uuid, integer) from public;
revoke execute on function fn_limpiar_trial(uuid) from public;
revoke execute on function fn_aplicar_descuento(uuid, numeric, integer) from public;
revoke execute on function fn_limpiar_descuento(uuid) from public;
revoke execute on function fn_crear_camarero(uuid, text, text, text[]) from public;
revoke execute on function fn_resetear_pin_camarero(uuid, uuid, text) from public;

-- 3) search_path — recorre pg_proc en vivo, sin depender de qué
--    versión de cada función quedó escrita en el repo
do $$
declare
  r record;
begin
  for r in
    select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and not exists (
        select 1 from unnest(coalesce(p.proconfig, '{}')) cfg
        where cfg like 'search_path=%'
      )
  loop
    execute format(
      'alter function public.%I(%s) set search_path = ''public'', ''extensions''',
      r.proname, r.args
    );
    raise notice 'search_path fijado en %(%)', r.proname, r.args;
  end loop;
end $$;

-- 4) menu-images — sacar las policies de lectura pública duplicadas
--    (el bucket ya sirve las imágenes por ser público)
drop policy if exists "public_read_menu_images" on storage.objects;
drop policy if exists "lectura publica menu-images" on storage.objects;
