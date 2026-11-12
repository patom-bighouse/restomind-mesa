# Permisos mínimos iguales en Test y Producción (esquema `public`)
- Fecha: 2026-11-11
- Estado: aprobada por Patricio el 11-11-2026; aplicada en Test (11-11) y en Producción (12-11-2026). Criterios 1-8 OK.
- Anexo con el estado actual medido: `2026-11-11-permisos-minimos-estado-actual.md`

## Qué y para quién
Una migración en `supabase/migrations/` que deja los grants de tabla y el EXECUTE de funciones del esquema `public` idénticos en Test y en Producción, con el mínimo privilegio que necesita la app.
No cambia nada visible. Afecta a todos los que usan la app: cliente en mesa, camarero y cocina con PIN (anon), dueño, superadmin y vendedor (authenticated), y n8n del cliente por WhatsApp (service_role).

### Por qué no se copia Test
Test no es un estado correcto:
- `service_role` no tiene SELECT/INSERT/UPDATE/DELETE en ninguna tabla. n8n y las Edge Functions con service_role no funcionarían.
- `fn_registrar_pedido`, `get_session_orders`, `fn_procesar_sellos` y `fn_reserva_fuera_de_horario` no tienen EXECUTE para nadie. La mesa por QR no puede pedir ni ver "Mis pedidos" en Test.

### Corrección sobre los roles
`src/pages/Cocina.jsx` **no** corre como anon: exige sesión de Supabase Auth (si no la hay, redirige a `/admin/login`) y lee `orders`, `order_items`, `camareros`, `table_sessions`… directamente. Es una pantalla de authenticated. La cocina con PIN es `src/components/CamareroCocina.jsx`, dentro de `Camarero.jsx`.

## Inventario de uso real (base de la tabla objetivo)
Leído del código el 11-11-2026. El implementador lo confirma con `grep -rn "\.rpc(\|\.from(" src/ supabase/functions/` y corrige la spec si aparece algo nuevo.

**anon** (sin sesión):
| Pantalla | Tablas (`.from`) | RPC (`.rpc`) |
|---|---|---|
| `Mesa.jsx` | SELECT: `restaurants` (nombre, moneda, config, activo), `categories`, `menu_items`, `menus`, `menu_item_precios_menu`, `upsell_rules`, `menu_item_traducciones`, `categoria_traducciones`, `upsell_traducciones`, `menu_item_modificador_grupos`, `modificador_grupos`, `modificador_opciones`, `menu_item_modificador_precios`, `modificador_grupo_traducciones`, `modificador_opcion_traducciones`. INSERT: `waiter_calls`. Realtime: `menu_items`, `categories`, `tables` | `get_table_by_qr`, `fn_sesion_abierta_por_token`, `fn_estado_sesion_mesa`, `fn_registrar_pedido`, `get_session_orders`, `fn_registrar_cliente_sesion`, `fn_estado_fidelizacion`, `fn_consultar_vale`, `fn_canjear_vale_regalo`, `fn_registrar_resena` |
| `Camarero.jsx` | SELECT: `restaurants` (nombre, moneda, config), `tables` (id, numero, zona, capacidad, activa, necesita_limpieza, limpieza_progreso), `limpieza_pasos`, carta (mismas tablas que Mesa salvo traducciones). Realtime: `tables` | `fn_listar_camareros_nombres`, `fn_verificar_camarero_pin`, `fn_camarero_listar_sesiones`, `fn_camarero_abrir_mesa`, `fn_camarero_tomar_mesa`, `fn_camarero_toggle_limpieza`, `fn_camarero_listar_pedidos_sesion`, `fn_camarero_editar_cliente_sesion`, `fn_staff_contar_alertas`, `fn_staff_listar_llamadas`, `fn_staff_marcar_llamada_atendida`, `fn_registrar_pedido`, `fn_estado_fidelizacion`, `fn_consultar_vale`, `fn_canjear_vale_regalo` |
| `CamareroClientes.jsx` | — | `fn_staff_listar_clientes`, `fn_staff_historial_cliente`, `fn_staff_canjear_puntos` |
| `CamareroReservas.jsx` | — | `fn_staff_listar_reservas`, `fn_staff_cambiar_estado_reserva`, `fn_staff_crear_reserva_manual` |
| `CamareroLimpieza.jsx` | SELECT: `tables`, `limpieza_pasos` | `fn_camarero_toggle_limpieza` |
| `CamareroCocina.jsx` | — | `fn_staff_listar_pedidos_cocina`, `fn_staff_cambiar_estado_pedido` |
| `Reservar.jsx` | SELECT: `restaurants` (nombre, config) | `fn_info_restaurante_publica`, `fn_crear_reserva_web` |
| `GuardRestaurante.jsx` (envuelve camarero, cocina, reservar) | — | `fn_restaurante_accesible`; `fn_condiciones_pendientes` solo en rutas no públicas (para anon falla y se trata como "no pendiente", igual que hoy en Producción) |
| `Landing.jsx` | SELECT: `planes` | — |

**authenticated**: pantallas `Admin*`, `SuperAdmin*`, `Vendedor*`, `components/crm/`, `Cocina.jsx`, `CuentaMesa.jsx`, `AceptarCondiciones.jsx`, y las Edge Functions (`importar-carta`, `traducir-carta`, `crm-buscar-restaurantes`; usan la anon key con el JWT del usuario). Además, el dueño con sesión iniciada que abre `/mesa/...` o `/camarero/...` en el mismo navegador corre como authenticated: authenticated necesita todo lo de anon.

**service_role**: n8n (fuera del repo). Por prudencia, acceso completo.

## Permisos objetivo

### Reglas generales
- Esquema: `USAGE` en `public` para `anon`, `authenticated`, `service_role`.
- `anon` y `authenticated`: nunca TRUNCATE, REFERENCES, TRIGGER ni MAINTAIN (PG17) en ninguna tabla.
- `service_role`: todos los privilegios en todas las tablas de `public`.
- Grants por columna: solo para `anon` en `restaurants` y `tables`. Se quitan los grants por columna redundantes de `authenticated` en `table_sessions` (`cliente_nombre`, `cliente_telefono`), que ya cubre el grant de tabla.
- Para authenticated, un privilegio solo se concede si alguna política RLS para `authenticated` o `PUBLIC` cubre ese comando (sin política el privilegio no sirve) y si las pantallas lo usan. Donde Test ya era más estricto que Producción y la preview de staging funciona, se toma lo de Test.
- No hay secuencias en `public` (todas las claves son `uuid` o `text`). Si el implementador encuentra alguna, `USAGE, SELECT` a authenticated solo si hace falta para un INSERT suyo, y todo a service_role.

### Grants de tabla
S = SELECT, I = INSERT, U = UPDATE, D = DELETE. "—" = nada. service_role tiene ALL en todas.

| Tabla | anon | authenticated | Justificación anon / notas |
|---|---|---|---|
| `camarero_pin_intentos` | — | — | Solo `fn_verificar_camarero_pin` (definer). Hoy anon tiene todo en Producción. |
| `camareros` | — | S I U D | |
| `categoria_traducciones` | S | S I U D | Mesa (carta multiidioma) |
| `categories` | S | S I U D | Mesa, Camarero (carta) + Realtime en Mesa |
| `clientes` | — | S I U | Sin DELETE (como Test) |
| `clientes_movimientos` | — | S I | Libro de movimientos (como Test) |
| `clientes_sellos` | — | S | Única política para authenticated es SELECT |
| `condiciones_aceptaciones` | — | S | Escritura solo por `fn_aceptar_condiciones` |
| `crm_actividades` | — | S I U D | |
| `crm_busquedas` | — | S | Política `crm_busquedas_select`. Escritura por `fn_crm_registrar_busqueda`. Hoy anon tiene todo en Producción |
| `crm_comisiones` | — | S I U D | |
| `crm_config` | — | S U | Políticas `crm_config_select` y `crm_config_update`. `CrmBuscador.jsx` guarda la configuración de Places con `.update(...).eq('id', true)` (necesita S para el filtro y U). Hoy anon tiene todo en Producción |
| `crm_cuentas` | — | S I U D | |
| `crm_historial` | — | S | Lo escribe el trigger `fn_crm_cuentas_despues` |
| `crm_tareas` | — | S I U D | |
| `ingredientes` | — | S I U D | |
| `limpieza_pasos` | S | S I U D | Camarero, CamareroLimpieza |
| `menu_item_modificador_grupos` | S | S I U D | Mesa, Camarero |
| `menu_item_modificador_precios` | S | S I U D | Mesa, Camarero |
| `menu_item_precios_menu` | S | S I U D | Mesa, Camarero (precios por menú) |
| `menu_item_traducciones` | S | S I U D | Mesa |
| `menu_items` | S | S I U D | Mesa, Camarero + Realtime en Mesa |
| `menus` | S | S I U D | Mesa, Camarero |
| `modificador_grupo_traducciones` | S | S I U D | Mesa |
| `modificador_grupos` | S | S I U D | Mesa, Camarero |
| `modificador_opcion_traducciones` | S | S I U D | Mesa |
| `modificador_opciones` | S | S I U D | Mesa, Camarero |
| `modulos` | — | S | Solo hay política SELECT. Escritura por `fn_asignar_modulo_a_plan` |
| `niveles_fidelizacion` | — | S I U D | |
| `order_deliveries` | — | S I U | Sin DELETE (como Test). `Cocina.jsx` hace UPDATE |
| `order_item_modificadores` | — | S I | Instantánea del pedido (como Test) |
| `order_items` | — | S I U D | |
| `order_sector_confirmaciones` | — | S I U | Sin DELETE (como Test) |
| `orders` | — | S I U D | |
| `planes` | S | S I U D | Landing (precios). Hoy anon tiene todo en Producción |
| `premios_fidelizacion` | — | S I U D | |
| `promos_sellos` | — | S I U D | Anon lo ve por `fn_estado_fidelizacion`. Hoy anon tiene todo en Producción |
| `receta_items` | — | S I U D | |
| `resenas` | — | S | Solo política SELECT. Escritura por `fn_registrar_resena` |
| `reservations` | — | S I U D | |
| `restaurant_billing` | — | S I U D | |
| `restaurant_info` | — | S I U D | Anon lo ve por `fn_info_restaurante_publica`. Hoy anon tiene todo en Producción |
| `restaurant_modulos` | — | S I U | No hay política de DELETE |
| `restaurants` | S (columnas `id`, `nombre`, `logo_url`, `activo`, `config`, `direccion`, `moneda`, `slug`, `subdominio`, `whatsapp`) | S I U D | Mesa, Camarero, Reservar. Se conservan las 10 columnas que anon lee hoy (decisión 2: no se sabe si algo fuera del repo usa `logo_url`, `direccion`, `slug`, `subdominio`, `whatsapp`). Se quita el INSERT/UPDATE/DELETE de tabla |
| `sectores_cocina` | — | S I U D | `Cocina.jsx` (authenticated) |
| `stock_movimientos` | — | S I | Libro de movimientos (como Test) |
| `superadmins` | — | S | Solo política `self_select_superadmins` |
| `table_session_payments` | — | S I U D | |
| `table_sessions` | — | S I U D | `AdminMesas.jsx` borra sesiones sin pedidos |
| `tables` | S (columnas `id`, `restaurant_id`, `numero`, `zona`, `capacidad`, `activa`, `necesita_limpieza`, `limpieza_progreso`) | S I U D | Camarero, CamareroLimpieza + Realtime. Se quita el INSERT/UPDATE/DELETE de tabla: el checklist va por `fn_camarero_toggle_limpieza` |
| `upsell_rules` | S | S I U D | Mesa, Camarero |
| `upsell_traducciones` | S | S I U D | Mesa |
| `vale_movimientos` | — | S | Escritura por funciones (como Test) |
| `vales_regalo` | — | S I U | Sin DELETE (como Test) |
| `vendedores` | — | S I U D | |
| `waiter_calls` | I | S I U D | Mesa "Llamar al camarero" (insert sin `.select()`) |
| `webhook_entregas` | — | S | La escribe `fn_disparar_webhooks` |
| `webhooks` | — | S I U D | |
| `whatsapp_mensajes_procesados` | — | — | Solo `fn_whatsapp_mensaje_nuevo` (service_role). Hoy anon y authenticated tienen todo en Producción |
| `whatsapp_sessions` | — | — | Solo n8n |

### EXECUTE en funciones
`postgres` (dueño) conserva EXECUTE en **todas** las funciones de `public` en los dos entornos: las funciones `SECURITY DEFINER` se llaman entre sí como `postgres` (p. ej. `fn_otorgar_puntos_mesa` → `fn_procesar_sellos`, `fn_crear_reserva_web` → `fn_reserva_fuera_de_horario`). `PUBLIC` no tiene EXECUTE en ninguna.

**Grupo A. anon + authenticated + service_role** (las llama la mesa, el camarero/cocina con PIN o la web pública; 32):
`get_table_by_qr`, `fn_sesion_abierta_por_token`, `fn_estado_sesion_mesa`, `fn_registrar_pedido`, `get_session_orders`, `fn_registrar_cliente_sesion`, `fn_estado_fidelizacion`, `fn_consultar_vale`, `fn_canjear_vale_regalo`, `fn_registrar_resena`, `fn_restaurante_accesible`, `fn_info_restaurante_publica`, `fn_crear_reserva_web`, `fn_listar_camareros_nombres`, `fn_verificar_camarero_pin`, `fn_camarero_listar_sesiones`, `fn_camarero_abrir_mesa`, `fn_camarero_tomar_mesa`, `fn_camarero_toggle_limpieza`, `fn_camarero_listar_pedidos_sesion`, `fn_camarero_editar_cliente_sesion`, `fn_staff_contar_alertas`, `fn_staff_listar_llamadas`, `fn_staff_marcar_llamada_atendida`, `fn_staff_listar_clientes`, `fn_staff_historial_cliente`, `fn_staff_canjear_puntos`, `fn_staff_listar_reservas`, `fn_staff_cambiar_estado_reserva`, `fn_staff_crear_reserva_manual`, `fn_staff_listar_pedidos_cocina`, `fn_staff_cambiar_estado_pedido`.

**Grupo B. authenticated + service_role** (panel, superadmin, CRM, Edge Functions, políticas y valores por defecto; 32):
- Identidad y políticas RLS: `fn_mi_restaurante`, `fn_es_superadmin`, `fn_mi_vendedor_id`, `is_restaurant_owner` (también en las políticas de `storage.objects` de `menu-images`), `fn_crm_cuenta_puede_ver`.
- Condiciones: `fn_condiciones_pendientes`, `fn_aceptar_condiciones`.
- Administración (hoy anon las puede ejecutar en Producción; pasan a solo authenticated): `fn_asignar_modulo_a_plan`, `fn_iniciar_trial`, `fn_aplicar_descuento`, `fn_limpiar_trial`, `fn_limpiar_descuento`, `fn_crear_camarero`, `fn_resetear_pin_camarero`, `fn_asignar_plan`, `fn_actualizar_precio_contrato`, `fn_dar_baja_restaurante`, `fn_permanencia_penalizacion`.
- CRM: `fn_crm_importar_restaurantes`, `fn_crm_restaurantes_cuentas`, `fn_crm_generar_comisiones`, `fn_crm_cuota_restaurante`, `fn_crm_permanencias`, `fn_crm_vendedor_cambiar_password`, `fn_crm_puede_buscar`, `fn_crm_uso_places`, `fn_crm_duplicados`, `fn_crm_registrar_busqueda`, `fn_crm_busquedas_recientes`, `fn_crm_busqueda_cargar`.
- Usadas de forma indirecta con los permisos de quien llama: `fn_hoy_madrid` (DEFAULT de `crm_tareas.vence_en` y parámetro por defecto de `fn_permanencia_penalizacion`), `fn_normalizar_telefono` (la llama el trigger `fn_trg_normalizar_telefono_cliente`, que no es definer, cuando el dueño o n8n escriben en `clientes`, `orders` o `table_sessions`).

**Grupo C. solo service_role** (n8n o uso interno; 17):
`fn_whatsapp_mensaje_nuevo`, `fn_reserva_contexto_cliente`, `fn_reserva_cliente_cancelar`, `fn_reserva_cliente_modificar`, `fn_reserva_cliente_bloquear`, `fn_disparar_webhooks`, `fn_reserva_whatsapp_crear`, `fn_reserva_hay_mesa`, `fn_reserva_fuera_de_horario`, `fn_carta_takeaway`, `fn_menu_activo`, `fn_procesar_sellos`, `fn_staff_tiene_permiso`, `fn_restaurante_activo`, `order_is_valid_for_items`, `fn_ahora_madrid`, `fn_hora_madrid`.
Si el `grep` encuentra alguna de estas en un `.rpc(` de una pantalla authenticated, pasa al grupo B (y se anota aquí).

**Grupo T. funciones de trigger: solo `postgres`** (22). Un trigger se dispara sin EXECUTE de quien escribe:
`fn_validar_modulo_pedido`, `fn_asegurar_sector_confirmacion`, `fn_otorgar_puntos_fidelizacion`, `fn_otorgar_puntos_mesa`, `fn_marcar_timestamp_estado_pedido`, `fn_bloquear_si_restaurante_inactivo`, `set_updated_at`, `fn_crm_cuentas_antes`, `fn_crm_cuentas_despues`, `fn_crm_actividades_antes`, `fn_crm_actividades_despues`, `force_zero_total_on_mesa_insert`, `recalc_order_total`, `fn_trigger_webhook_order_placed`, `fn_trigger_webhook_payment_received`, `fn_trigger_webhook_reservation_created`, `fn_trigger_webhook_waiter_call`, `fn_activar_modulo_nucleo`, `fn_restaurants_permanencia_alta`, `fn_restaurants_proteger_comercial`, `fn_restaurants_proteger_comercial_alta`, `fn_trg_normalizar_telefono_cliente`.

### Privilegios por defecto (objetos nuevos creados por `postgres`)
Decisión: **nada abierto por defecto salvo para service_role**.
- Tablas nuevas en `public`: ALL a `service_role`; nada a `anon` ni `authenticated`.
- Funciones nuevas: EXECUTE a `service_role`; nada a `PUBLIC`, `anon` ni `authenticated`. Ojo: el EXECUTE a `PUBLIC` es un valor por defecto global de Postgres; se quita con `alter default privileges for role postgres revoke execute on functions from public` **sin** `in schema`. Las entradas de Supabase para `anon`/`authenticated` se quitan con `in schema public`.
- Secuencias nuevas: ALL a `service_role`; nada a `anon` ni `authenticated`.

Por qué: cumple las reglas fijas 4 y 5 de `CLAUDE.md` (grants explícitos y mínimos en la migración que crea cada objeto). Un olvido falla cerrado (la pantalla da "permission denied" en Test y se ve en la preview) en vez de abrir datos. service_role queda abierto para no romper n8n con tablas nuevas.

### Otros cambios
- `fn_marcar_timestamp_estado_pedido`: `set search_path = public`. Solo eso; el cuerpo no cambia.
- La migración termina con `notify pgrst, 'reload schema'`.

### Forma de la migración (requisitos, no código)
- Archivo nuevo `supabase/migrations/<ts>_permisos_minimos.sql`. Idempotente.
- Primero revoca y después concede, recorriendo el catálogo (`pg_class`, `pg_proc` del esquema `public`) para no depender de lo que haya hoy en cada entorno. Revocar ALL de tabla no quita los grants por columna: hay que revocarlos también.
- Excluye los objetos que pertenecen a extensiones (`pg_depend` con `deptype = 'e'`) y la función `rls_auto_enable()` (solo existe en Test, fuera de alcance).
- No revoca nada a `postgres`.
- Comentario al principio: no toca datos.

## Criterios de aceptación
| # | Criterio | Cómo se prueba |
|---|---|---|
| 1 | Dado Test con la migración aplicada, cuando se listan los grants de tabla y de columna de `anon` y `authenticated` en `public`, entonces coinciden fila a fila con la tabla "Grants de tabla" de esta spec, y ninguna fila es TRUNCATE, REFERENCES, TRIGGER ni MAINTAIN. | sql: `supabase/tests/permisos_tablas.sql` contra Test. Consulta `information_schema.role_table_grants` y `information_schema.column_privileges` y la compara con la lista esperada escrita en el propio test; devuelve 0 filas de diferencia. Más `set local role anon; select user_id from restaurants limit 1;` → error "permission denied"; `set local role anon; select id from menu_items limit 1;` → sin error. Todo dentro de `begin … rollback`. |
| 2 | Dado Test con la migración aplicada, cuando se lista el EXECUTE de cada función de `public`, entonces: grupo A = anon, authenticated, service_role, postgres; grupo B = authenticated, service_role, postgres; grupo C = service_role, postgres; grupo T = solo postgres; y `PUBLIC` no aparece en ninguna. | sql: `supabase/tests/permisos_funciones.sql` contra Test, con `aclexplode(proacl)` de `pg_proc`; 0 filas de diferencia con la lista esperada. Más, con `rollback`: `set local role anon; select fn_iniciar_trial('00000000-0000-0000-0000-000000000000', 1);` → "permission denied for function fn_iniciar_trial"; lo mismo con `fn_procesar_sellos` y `fn_reserva_whatsapp_crear`; `set local role anon; select * from get_table_by_qr('x');` → sin error y 0 filas. |
| 3 | Dado Test con la migración aplicada, cuando se lista lo de `service_role`, entonces tiene los 8 privilegios (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN) en todas las tablas de `public` y EXECUTE en las 81 funciones no trigger. | sql: `supabase/tests/permisos_service_role.sql` contra Test: cuenta tablas sin los 8 privilegios (espera 0) y funciones no trigger sin EXECUTE (espera 0). Más `set local role service_role; select count(*) from whatsapp_sessions;` → sin error. |
| 4 | Dado Test con la migración aplicada, cuando `postgres` crea una tabla y una función nuevas en `public`, entonces la tabla solo tiene grants para `service_role` y la función solo EXECUTE para `postgres` y `service_role`. | sql: `supabase/tests/permisos_por_defecto.sql` contra Test: `begin; create table public.zz_prueba(id int); create function public.zz_f() returns int language sql as 'select 1';` consulta sus ACL; `rollback;`. Además lista `pg_default_acl` del rol `postgres` y la compara con lo esperado. |
| 5 | Dado Test con la migración aplicada, cuando se mira la configuración de `fn_marcar_timestamp_estado_pedido`, entonces tiene `search_path=public`, y al pasar un pedido de `pendiente` a `preparando` se rellena `preparando_at`. | sql: `select proconfig from pg_proc where proname = 'fn_marcar_timestamp_estado_pedido'` → `{search_path=public}`. En `begin … rollback`: update de un pedido de prueba de Test a `preparando` y comprobar `preparando_at is not null`. |
| 6 | Dados Test y Producción con la migración aplicada, cuando se ejecuta la consulta de huella de permisos en los dos, entonces devuelven exactamente las mismas filas y el mismo `md5`. | sql: `supabase/tests/permisos_huella.sql` (solo `select`, sin escritura). Saca una lista ordenada de (objeto, rol, privilegio) de tablas, columnas, funciones y `pg_default_acl` de `public`, sin objetos de extensiones ni `rls_auto_enable`, y su `md5(string_agg(...))`. Se ejecuta en Test y, tras el paso a Producción, en Producción (lectura permitida por la regla 1). Las dos salidas se pegan en el PR. Antes de aplicar en Producción, la misma consulta debe dar distinto (comprueba que la huella detecta diferencias). |
| 7 | Dada la preview de `staging` (Supabase Test) con la migración aplicada, cuando se hace el recorrido completo, entonces todo funciona sin errores de permisos en la consola del navegador. | manual, en una ventana de incógnito (sin sesión) salvo donde se indica: 1) Mesa por QR: abrir `/mesa/<token>` de una mesa con sesión abierta, cambiar idioma, añadir un plato con modificador, enviar pedido, abrir "Mis pedidos", "Llamar al camarero", guardar teléfono en "Sumar puntos", consultar y aplicar un vale. 2) Camarero: `/camarero/<id>`, elegir persona, PIN, abrir mesa libre, pedir, ver pedidos de la sesión, cargar teléfono, ver alerta de la llamada del paso 1 y marcarla atendida, completar checklist de limpieza; con un camarero con permisos `clientes`, `reservas` y `cocina`: canjear puntos, crear reserva manual, avanzar un pedido en su cocina. 3) Reserva web: `/reservar/<id>`, reservar para mañana dentro del horario. 4) Con sesión de dueño: `/cocina/<id>` recibe en tiempo real un pedido nuevo desde la mesa; en el panel editar un plato de la carta, crear un camarero, ver clientes, cerrar la mesa del paso 1 con un cobro y comprobar que suben los puntos del teléfono. 5) Superadmin: iniciar y limpiar prueba gratuita, aplicar y limpiar descuento, cambiar plan de un restaurante de Test. 6) Vendedor: entrar en `/vendedor/crm`, crear cuenta, añadir tarea y actividad. 7) Abrir `/mesa/<token>` con la sesión de dueño iniciada en el mismo navegador y pedir. |
| 8 | Dado n8n con service_role, cuando se aplica la migración, entonces el agente de WhatsApp sigue creando pedidos take away y reservas. | conversación, **solo en Producción** (n8n no está conectado a Test; decisión 1). Antes de aplicar: el orquestador comprueba en los registros de API de Producción (`query_logs`, solo lectura) que las llamadas de n8n llegan con rol `service_role`; si alguna llega como `anon`, no se aplica y se avisa a Patricio. Justo después de aplicar: Patricio hace una conversación de take away completa (carta, pedido, confirmación con hora de recogida) y una de reserva (crear, modificar, anular); se comprueba que aparecen en `orders` y `reservations`. |

## Fuera de alcance
- Mover la extensión `pg_net` fuera de `public`.
- La diferencia de código de `fn_disparar_webhooks` entre Test y Producción. Aquí solo se igualan sus grants.
- `rls_auto_enable()`, que solo existe en Test. La migración no la toca y la huella la excluye.
- Protección de contraseñas filtradas: es configuración de Auth; la cambia Patricio en el panel de Supabase.
- El esquema `router` (`router.clientes_cache` tiene todos los privilegios para anon y authenticated; RLS sin políticas lo bloquea).
- Restringir columnas de `menu_items` para anon (hoy anon puede leer `precio_costo`).
- Cerrar a anon las columnas `logo_url`, `direccion`, `slug`, `subdominio` y `whatsapp` de `restaurants` (decisión 2; queda en el backlog).
- Cambiar el código de funciones, salvo el `search_path` de `fn_marcar_timestamp_estado_pedido`.
- Políticas RLS. No se crean ni se cambian. La política `anon_insert_order_items` queda sin efecto (anon no tiene INSERT en `order_items`); no se borra aquí.
- Fallos de lógica detectados al revisar (ver Riesgos, punto 6). Van en otra tarea, la siguiente del backlog (decisión 4).

## Impacto técnico
- Front: ningún archivo. Solo se revisa con `grep`.
- BD:
  - Nueva migración `supabase/migrations/<ts>_permisos_minimos.sql`: grants de tabla, de columna y de funciones en `public`; `alter default privileges` de `postgres`; `alter function fn_marcar_timestamp_estado_pedido() set search_path = public`.
  - Nuevos tests en `supabase/tests/`: `permisos_tablas.sql`, `permisos_funciones.sql`, `permisos_service_role.sql`, `permisos_por_defecto.sql`, `permisos_huella.sql`. Solo contra Test y con `rollback`, salvo `permisos_huella.sql`, que es de solo lectura y también se ejecuta en Producción.
  - No hay tablas nuevas ni cambios de RLS ni de Realtime. Las suscripciones Realtime de anon (`menu_items`, `categories`, `tables`) siguen teniendo su SELECT.
  - Actualizar `docs/MIGRACIONES.md` (apartado "Estado"): permisos igualados por esta migración.
- n8n: ningún workflow cambia. service_role conserva todo.
- Edge Functions: ninguna cambia. `crm-buscar-restaurantes` necesita `fn_crm_puede_buscar`, `fn_crm_duplicados` y `fn_crm_registrar_busqueda` para authenticated (grupo B).
- Módulo de pago: no aplica.

## Riesgos
1. **Romper mesa, camarero o cocina con PIN en Producción.** Todo corre como anon. Si falta un SELECT o un EXECUTE, la pantalla falla para todos los restaurantes a la vez. Mitigación: el criterio 7 completo en la preview de staging antes de Producción; dejar preparada, sin aplicar, una migración de vuelta atrás que reponga los grants quitados.
2. **Romper n8n.** No está en el repo y no sabemos qué tablas y funciones usa. Por eso service_role conserva todo. Riesgo restante: que n8n llame con la anon key en vez de la service_role. Si fuera así, perdería `fn_reserva_whatsapp_crear`, `fn_carta_takeaway`, `fn_menu_activo`, `fn_reserva_hay_mesa`, `fn_reserva_fuera_de_horario` y `fn_procesar_sellos` (hoy anon las tiene en Producción). n8n solo corre en Producción, así que no se puede probar antes en Test. Mitigación: comprobación del rol en los registros de Producción antes de aplicar y conversación justo después (criterio 8).
3. **Orden de aplicación.** Test (`db push --remote=sfkwbhzelrestmrmptql`) → criterios 1 a 7 → PR `staging` → `main` → comprobación del rol de n8n (criterio 8, primera parte) → Producción (`db push --remote=mfxrluanpawfjncpqrvu`) → criterio 6 en Producción y conversación del criterio 8. Momento: cualquiera; en Producción solo hay restaurantes de prueba (decisión 5). Nunca SQL suelto en Producción (regla 1). Mientras la migración esté solo en Test, la preview es la única que la tiene.
4. **Pantallas de authenticated que usen algo no inventariado.** No se ha leído cada `Admin*`. Mitigación: el `grep` del inventario y el recorrido del criterio 7. Lo más delicado: quitar DELETE en `clientes`, `vales_regalo`, `order_deliveries`, `order_sector_confirmaciones`, `restaurant_modulos`, y dejar `clientes_movimientos`, `stock_movimientos`, `order_item_modificadores` en S I. Producción tiene hoy todo; Test ya tenía estas reducciones.
5. **Privilegios por defecto cerrados.** Toda migración futura que cree tabla o función debe incluir sus grants. Si se olvidan, la pantalla falla con "permission denied" (falla cerrado). Conviene recordarlo en `docs/FLUJO_DE_TRABAJO.md`. Los objetos que cree `supabase_admin` (no `postgres`) no los cubre este cambio.
6. **Fallos de lógica encontrados al revisar (no se arreglan aquí, pero hay que saberlos):**
   - `fn_listar_camareros_nombres` devuelve a anon los `id` de los camareros, y `fn_staff_tiene_permiso` solo comprueba que el camarero existe y tiene el permiso, no el PIN. Con eso, cualquiera puede llamar a `fn_staff_listar_clientes` (teléfonos y puntos de todos los clientes), `fn_staff_listar_reservas`, `fn_staff_canjear_puntos`, etc. sin PIN. Los grants no lo pueden cerrar porque anon necesita esas funciones.
   - `fn_camarero_listar_sesiones` no comprueba nada: anon puede ver los teléfonos y nombres de clientes de las mesas abiertas de cualquier restaurante.
   - Hoy en Producción anon puede ejecutar `fn_procesar_sellos` (suma sellos sin comprobaciones) y `fn_reserva_whatsapp_crear` (crea reservas confirmadas sin validar horario). Esta migración sí lo cierra (grupo C).
7. **Multi-tenant.** No cambia: lo sigue protegiendo RLS y las comprobaciones dentro de las funciones.
8. **Hora de Madrid y dinero.** Sin impacto: no cambia ninguna función de fechas ni de importes. `fn_hoy_madrid` sigue disponible para authenticated por el DEFAULT de `crm_tareas`.
9. **Pedidos en curso.** Los grants se aplican al momento. Una mesa con el carrito abierto sigue pidiendo por `fn_registrar_pedido`, que no pierde EXECUTE.

## Decisiones (respuestas de Patricio, 11-11-2026)
1. **n8n:** solo corre en Producción; no hay workflow conectado a Test. El criterio 8 se hace solo en Producción. Qué clave usa n8n lo comprueba el orquestador en los registros de API de Producción (solo lectura) antes de aplicar.
2. **Columnas de `restaurants` para anon:** no se sabe si algo fuera del repo las usa. Se conservan las 10 columnas de hoy; cerrarlas queda para otra tarea (backlog).
3. **`crm_config` y `crm_busquedas`:** resuelta con el código, sin preguntar. `CrmBuscador.jsx` actualiza `crm_config` directamente, así que queda S U. `crm_busquedas` se queda en S (solo se escribe por `fn_crm_registrar_busqueda`).
4. **Fallo del PIN del camarero (Riesgo 6):** primero se termina esta tarea; la de seguridad va justo después (ya está en el backlog con prioridad alta).
5. **Momento de aplicar en Producción:** cualquiera. Todos los restaurantes de Producción son de prueba; todavía no hay clientes reales. **Provisional:** en cuanto haya un cliente real, los cambios en Producción vuelven a aplicarse fuera de horas de servicio (ver el aviso en `docs/BACKLOG.md`).
