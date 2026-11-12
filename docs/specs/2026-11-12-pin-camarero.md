# Funciones del camarero protegidas por sesión con PIN
- Fecha: 2026-11-12
- Estado: aprobada por Patricio el 12-11-2026

## Qué y para quién
Hoy cualquiera que conozca el id del restaurante (está en la URL `/camarero/<id>`) puede, sin PIN, leer teléfonos y puntos de clientes, ver y cambiar reservas, mover pedidos de cocina, canjear puntos y ver quién está sentado en cada mesa. Esta tarea hace que todas esas funciones exijan una **sesión de camarero** que solo se obtiene introduciendo el PIN correcto.
Afecta al personal con PIN (camarero, limpieza, cocina con PIN, reservas y clientes en `/camarero/...`). El cliente en mesa por QR no nota nada. El dueño no nota nada, salvo que al cambiar el PIN de alguien o darle de baja, esa persona tiene que volver a entrar.

## Lo que hay hoy (comprobado en el código y en `supabase/migrations/20261111193648_remote_schema.sql`)
- El personal no usa Supabase Auth: todo corre como `anon`. Tras validar el PIN, `Camarero.jsx` guarda `{ id, nombre, permisos }` solo en memoria (`useState`, sin `localStorage`). Recargar la página ya obliga hoy a volver a poner el PIN.
- `fn_listar_camareros_nombres(p_restaurant_id)` devuelve `id` y `nombre` de los camareros activos a cualquiera.
- `fn_staff_tiene_permiso(restaurante, camarero, permiso)` solo comprueba restaurante activo + camarero activo + permiso. No sabe nada del PIN.
- `fn_camarero_listar_sesiones(p_restaurant_id)` no comprueba nada: devuelve id de sesión, nombre y teléfono del cliente de todas las mesas abiertas. Con ese id de sesión, además, cualquiera puede llamar a `fn_registrar_pedido` y `fn_canjear_vale_regalo` en mesas ajenas.
- `fn_camarero_abrir_mesa`, `fn_camarero_tomar_mesa`, `fn_camarero_editar_cliente_sesion` solo comprueban que el camarero exista (y `abrir_mesa` acepta `p_camarero_id` nulo). `fn_camarero_toggle_limpieza` no recibe camarero.
- `fn_registrar_pedido` acepta `p_camarero_id` sin comprobarlo: se puede atribuir un pedido a cualquier camarero (`orders.tomado_por`, que se ve en `Cocina.jsx` y en el filtro "atendido por" de `AdminDashboard.jsx`).
- `fn_verificar_camarero_pin` compara el PIN con `crypt` y lleva el límite de intentos en `camarero_pin_intentos` (10 fallos en 5 minutos → 5 minutos bloqueado, por camarero).
- Todas estas funciones están en el grupo A de `docs/specs/2026-11-11-permisos-minimos.md` (EXECUTE para anon, authenticated y service_role). Los grants no pueden cerrar el agujero: la app las necesita como anon.

## Solución recomendada: sesión de camarero con token guardado en BD
1. Al acertar el PIN, `fn_verificar_camarero_pin` crea una fila en una tabla nueva `camarero_sesiones` y devuelve, además de `id`, `nombre` y `permisos`, un `token` aleatorio (32 bytes de `gen_random_bytes`, en hexadecimal) y `caduca_at`. En la tabla solo se guarda el hash del token (`sha256`), nunca el token.
2. El front guarda el token en el mismo estado en memoria donde ya guarda al camarero, y lo envía como `p_token` en cada llamada.
3. Una única función interna `fn_staff_exigir_sesion(p_restaurant_id, p_camarero_id, p_token, p_permisos text[], p_funcion text)` hace todas las comprobaciones: el hash existe, es de ese camarero y de ese restaurante, no está revocado ni caducado, el camarero sigue activo, el restaurante está activo y el camarero tiene **ahora** alguno de los permisos pedidos (los permisos se leen en vivo de `camareros.permisos`; si el dueño quita un permiso, se nota en la siguiente llamada).
   - Sesión no válida → error con `errcode = 'RM401'` y mensaje "Tu sesión ha caducado. Recarga la página y vuelve a introducir tu PIN."
   - Sesión válida sin el permiso → el error de hoy, "No autorizado".
4. Todas las `fn_camarero_*` y `fn_staff_*` del grupo A la llaman al principio.
5. Caducidad: 12 horas desde que se puso el PIN (decisión 1). Es una duración, no una hora del día: `caduca_at = now() + interval '12 hours'`. No depende de la zona horaria (regla 7 de `CLAUDE.md` no aplica).
6. Revocación: "Cambiar camarero" en la app cierra la sesión (`fn_camarero_cerrar_sesion(p_token)`). `fn_resetear_pin_camarero` revoca todas las sesiones de ese camarero. Desactivar al camarero o el restaurante invalida sus sesiones en la siguiente llamada (se comprueba en vivo).
7. Despliegue en dos fases para no dejar sin servicio a quien tenga la app abierta (ver "Despliegue y vuelta atrás").

### Alternativas descartadas
| Alternativa | Por qué no |
|---|---|
| Enviar el PIN en cada llamada | El front tendría que guardar el PIN. Cada llamada haría un `crypt` bcrypt (la app consulta cada 5–10 s por dispositivo). No permite caducidad ni cerrar sesión. Cada llamada sería un intento de PIN más. |
| Supabase Auth para el personal (JWT propio emitido por una Edge Function, o inicio de sesión anónimo) | Es lo más sólido a largo plazo (permitiría RLS y Realtime en `table_sessions`), pero es un cambio grande: firmar JWT, refrescarlos y convivir con la sesión del dueño en el mismo navegador (el dueño que abre `/camarero/...` perdería su sesión del panel). Queda como posible mejora futura. |
| Esconder los `id` de `fn_listar_camareros_nombres` | No basta: los id se filtran por otros sitios (`table_sessions.camarero_id` en `fn_camarero_listar_sesiones`, `orders.tomado_por`) y un id no es un secreto. |

## Criterios de aceptación
"Fase 1" = primera migración (modo tolerante). "Fase 2" = segunda migración (token obligatorio). Salvo el 7, los criterios se comprueban con las dos migraciones aplicadas en Test.

Funciones protegidas y permiso que exigen (con sesión válida):
| Función | Permiso exigido |
|---|---|
| `fn_camarero_listar_sesiones`, `fn_camarero_abrir_mesa`, `fn_camarero_tomar_mesa`, `fn_camarero_listar_pedidos_sesion`, `fn_camarero_editar_cliente_sesion`, `fn_staff_listar_llamadas`, `fn_staff_marcar_llamada_atendida`, `fn_registrar_pedido` (solo cuando llega `p_camarero_id`) | `pedidos` |
| `fn_camarero_toggle_limpieza` | `limpieza` o `pedidos` (`Camarero.jsx` abre el checklist desde la sección de pedidos) |
| `fn_staff_contar_alertas` | ninguno concreto: exige sesión válida y cuenta solo lo que permiten sus permisos, como hoy |
| `fn_staff_listar_clientes`, `fn_staff_historial_cliente`, `fn_staff_canjear_puntos` | `clientes` |
| `fn_staff_listar_reservas`, `fn_staff_cambiar_estado_reserva`, `fn_staff_crear_reserva_manual` | `reservas` |
| `fn_staff_listar_pedidos_cocina`, `fn_staff_cambiar_estado_pedido` | `cocina` |

| # | Criterio | Cómo se prueba |
|---|---|---|
| 1 | Dado un camarero activo con PIN conocido, cuando anon llama a `fn_verificar_camarero_pin` con el PIN correcto, entonces recibe `id`, `nombre`, `permisos`, un `token` de 64 caracteres hexadecimales y `caduca_at` = ahora + 12 h (±1 min), y en `camarero_sesiones` hay una fila nueva con el hash del token y sin el token en claro. Con PIN incorrecto: 0 filas y ninguna sesión nueva. Tras 10 fallos seguidos: "Demasiados intentos fallidos…", igual que hoy. | sql: `supabase/tests/pin_camarero.sql` contra Test, `begin … rollback`. Crea como `postgres` un restaurante de prueba y un camarero con `pin_hash = crypt('1234', gen_salt('bf'))` y permisos `{pedidos}`; las llamadas van con `set local role anon`. Filas `prueba \| ok \| detalle` y fila TOTAL, mismo formato que `supabase/tests/limpieza_toggle.sql`. |
| 2 | Dado un camarero válido con su `id` y el de su restaurante, cuando anon llama a cada una de las 17 funciones de la tabla de arriba sin `p_token`, con un token inventado o con un token de otro camarero o de otro restaurante, entonces todas fallan con código `RM401`, no devuelven filas y no cambian nada (mesa, sesión, reserva, pedido, llamada, cliente y puntos quedan igual). En particular `fn_camarero_listar_sesiones` ya no devuelve teléfonos ni nombres. | sql: `supabase/tests/pin_camarero.sql`. Para cada función, captura `sqlstate` en un bloque `exception` y compara contra `RM401`; después compara el estado de las filas de prueba antes y después. Una fila por función y caso. |
| 3 | Dada una sesión válida, cuando el camarero llama a cada función con su `p_token`, entonces funciona como hoy si tiene el permiso de la tabla, y da "No autorizado" si no lo tiene. Si el dueño le quita el permiso con la sesión abierta, la siguiente llamada da "No autorizado". `fn_staff_contar_alertas` solo cuenta limpieza y llamadas según sus permisos. | sql: `supabase/tests/pin_camarero.sql`. Dos camareros de prueba (uno con `{pedidos,limpieza,clientes,reservas,cocina}`, otro con `{pedidos}`). Comprueba resultado y efecto en BD (mesa abierta, `tomado_por`, puntos restados con su movimiento, reserva creada y cambiada, pedido avanzado, llamada atendida, paso de limpieza guardado). Después `update camareros set permisos = '{pedidos}'` y la llamada a `fn_staff_listar_clientes` da "No autorizado". |
| 4 | Dada una sesión válida, cuando: a) pasa su `caduca_at`, b) se llama a `fn_camarero_cerrar_sesion` con su token, c) el dueño desactiva al camarero, d) el dueño le cambia el PIN con `fn_resetear_pin_camarero`, o e) el restaurante pasa a inactivo, entonces la siguiente llamada con ese token falla (`RM401` en a–d; en e, el error de restaurante no disponible o `RM401`). Las demás sesiones de otros camareros siguen funcionando. | sql: `supabase/tests/pin_camarero.sql`. a) `update camarero_sesiones set caduca_at = now() - interval '1 minute'`; b) llamada como anon; c) `update camareros set activo = false`; d) `fn_resetear_pin_camarero` con `request.jwt.claims` del dueño de prueba (`set local role authenticated`); e) `update restaurants set activo = false`. |
| 5 | Dada la mesa por QR, cuando el cliente (anon, sin token) pide con `fn_registrar_pedido` sin `p_camarero_id`, consulta su fidelización con `fn_estado_fidelizacion`, consulta un vale con `fn_consultar_vale` y lo aplica con `fn_canjear_vale_regalo`, entonces todo funciona igual que hoy y `tomado_por` queda vacío. Cuando alguien llama a `fn_registrar_pedido` con `p_camarero_id` y sin `p_camarero_token` válido, el pedido se rechaza con `RM401`; con token válido, el pedido queda con `tomado_por` = ese camarero. | sql: `supabase/tests/pin_camarero.sql`, con una sesión de mesa de prueba (`table_sessions` abierta en una mesa de prueba) y un vale de prueba. |
| 6 | Dado Test con las migraciones aplicadas, cuando se revisa el esquema, entonces: `camarero_sesiones` (y en fase 1 `camarero_llamadas_sin_token`) tienen RLS activado y ningún grant a anon ni authenticated; `fn_camarero_cerrar_sesion` está en el grupo A; `fn_staff_exigir_sesion` en el grupo C; todas las funciones nuevas o cambiadas son `SECURITY DEFINER` con `search_path` fijado y sin EXECUTE para `PUBLIC`; y cada función afectada tiene **una sola** versión (sin la firma antigua al lado). `supabase/tests/permisos_funciones.sql`, actualizado con las funciones nuevas, sale todo `ok`. | sql: bloque de esquema en `supabase/tests/pin_camarero.sql` (`pg_class.relrowsecurity`, `has_table_privilege`, `has_function_privilege`, `proconfig`, `count(*)` por `proname` en `pg_proc` = 1) + `supabase/tests/permisos_funciones.sql`. |
| 7 | Dada solo la fase 1 aplicada, cuando una pantalla con la versión anterior de la app (sin token) llama a las funciones, entonces funcionan como hoy y cada llamada queda anotada en `camarero_llamadas_sin_token` (restaurante, función, nº de llamadas, última llamada); y cuando llega un token inventado, falla con `RM401`. | sql: `supabase/tests/pin_camarero_fase1.sql` contra Test, `begin … rollback`, ejecutado **entre** la migración de fase 1 y la de fase 2. manual: 1) antes de aplicar la fase 1 en Test, abrir en una pestaña la URL del despliegue actual de `staging` en Vercel (versión vieja), entrar como camarero con PIN; 2) aplicar la fase 1 en Test; 3) en esa pestaña, sin recargar: abrir una mesa, pedir, ver pedidos de la sesión, marcar un paso de limpieza, y con un camarero con permisos `cocina`, `reservas` y `clientes`, avanzar un pedido, ver reservas y ver clientes; todo funciona; 4) comprobar que aparecen filas en `camarero_llamadas_sin_token`. |
| 8 | Dada la preview de la rama (Test con las dos fases), cuando el personal usa la app, entonces todo funciona sin errores en la consola; al pulsar "Cambiar camarero" su token deja de valer; y si su sesión caduca, en menos de 15 s la app vuelve a la pantalla "¿Quién eres?" con el aviso "Tu sesión ha caducado. Vuelve a introducir tu PIN." (también desde Clientes, Reservas, Limpieza y Cocina). | manual, en incógnito: 1) `/camarero/<id>`, elegir persona, PIN; abrir mesa libre, tomar una mesa abierta desde el panel, pedir, ver pedidos de la sesión, cargar teléfono del cliente, aplicar un vale, marcar llamada atendida (crearla antes con "Llamar al camarero" desde `/mesa/<token>`), completar checklist de limpieza. 2) Con un camarero con `clientes`, `reservas`, `limpieza` y `cocina`: canjear puntos, crear reserva manual y cambiar su estado, completar una limpieza desde la sección Limpieza, avanzar un pedido en Cocina. 3) "Cambiar camarero" y volver a entrar. 4) Caducidad: con la app abierta en la sección de pedidos, el orquestador ejecuta en **Test** `update camarero_sesiones set caduca_at = now() where camarero_id = '<id>'`; se comprueba el aviso. Repetir en Cocina (sondeo de 8 s). 5) Mesa por QR: pedir y aplicar vale desde `/mesa/<token>`, sin cambios. `npm run build` en verde. |

## Despliegue y vuelta atrás
Dos PR y dos migraciones. Nunca las dos en el mismo `db push`: si las dos están en `supabase/migrations/` a la vez, `db push` aplica ambas y no hay transición.

**PR 1 (fase 1, modo tolerante) — esta tarea:**
- Migración `<ts>_pin_camarero_fase1.sql`:
  - Crea `camarero_sesiones` y `camarero_llamadas_sin_token`.
  - Crea `fn_staff_exigir_sesion` en modo tolerante: si `p_token` es nulo, hace la comprobación de hoy (`fn_staff_tiene_permiso`) y anota la llamada en `camarero_llamadas_sin_token`; si llega token, lo exige válido.
  - Cambia las funciones afectadas añadiendo parámetros **con valor por defecto nulo** al final (`p_token text default null`; en `fn_camarero_listar_sesiones` y `fn_camarero_toggle_limpieza` también `p_camarero_id uuid default null`; en `fn_registrar_pedido`, `p_camarero_token text default null`). Como cambia la firma, cada una se borra (`drop function` con la firma antigua) y se crea de nuevo en la misma migración, con sus grants del grupo A. Así la app vieja (que no envía esos parámetros) sigue encontrando la función, y no quedan dos versiones que confundan a PostgREST.
  - `fn_verificar_camarero_pin` cambia su tipo de retorno (añade `token` y `caduca_at`): `drop` + `create` con los mismos parámetros. La app vieja ignora las columnas nuevas.
  - `fn_resetear_pin_camarero` revoca las sesiones del camarero.
  - Crea `fn_camarero_cerrar_sesion`.
- Front que envía el token y gestiona `RM401`.
- Orden: migración en Test → criterio 7 (incluido el paso con la versión vieja abierta) → front en la preview → criterios 1–6 se comprueban después de la fase 2 en Test (ver abajo) → PR `staging` → `main` → **migración en Producción antes** de que Vercel publique el front (el front nuevo envía `p_token` y con la BD vieja daría "función no encontrada").

**PR 2 (fase 2, token obligatorio):**
- Migración `<ts>_pin_camarero_fase2.sql`: reescribe solo `fn_staff_exigir_sesion` para rechazar el token nulo, y borra `camarero_llamadas_sin_token`.
- En Test se aplica justo después de validar la fase 1, para pasar los criterios 1–6 y 8.
- En Producción, solo cuando `camarero_llamadas_sin_token` no tenga llamadas en las últimas 24 h (consulta de solo lectura que hace el orquestador; regla 1); si alguna pantalla sigue con la versión antigua, se avisa a ese restaurante para que recargue (decisión 2). Mientras en Producción solo haya restaurantes de prueba, la fase 2 se aplica en cuanto la fase 1 esté comprobada en Producción.

**Vuelta atrás (preparada, sin aplicar, en `supabase/rollback/`):**
- `pin_camarero_fase2_revertir.sql`: vuelve a poner `fn_staff_exigir_sesion` en modo tolerante. Es una sola función; no hace falta tocar el front ni las firmas. Es la salida rápida si, tras la fase 2, algún restaurante no puede trabajar.
- `pin_camarero_fase1_revertir.sql`: repone las funciones con sus firmas y cuerpos de antes. Antes hay que volver a la versión anterior del front en Vercel (si no, el front nuevo envía `p_token` a funciones que ya no lo aceptan).
- Las dos se aplican como migración, primero en Test y luego en Producción, igual que la de permisos mínimos.

## Fuera de alcance
- Guardar la sesión para que recargar la página no pida el PIN. Hoy ya lo pide; no cambia.
- Endurecer el PIN (más dígitos, bloqueo progresivo, aviso al dueño). Tarea aparte en el backlog (decisión 3).
- `fn_estado_fidelizacion` y `fn_consultar_vale`: cualquiera con el id del restaurante puede consultar los puntos de un teléfono o probar códigos de vale. Las usa la mesa por QR sin sesión; cerrarlo es otra tarea.
- `fn_canjear_vale_regalo`: no cambia. Tras esta tarea, el id de sesión de mesa solo se obtiene con el token QR de la mesa (`fn_sesion_abierta_por_token`) o con sesión de camarero.
- `fn_listar_camareros_nombres` sigue devolviendo nombres e id (la pantalla "¿Quién eres?" los necesita).
- Pasar el personal a Supabase Auth, y RLS o Realtime en `table_sessions`.
- Una pantalla para que el dueño vea o cierre sesiones abiertas.
- Las columnas de `tables` que lee anon.

## Impacto técnico
- Front:
  - `src/pages/Camarero.jsx`: guardar `token` en el estado `camarero`; enviar `p_token` en todas las llamadas de la tabla de funciones; `p_camarero_id` y `p_token` en `fn_camarero_listar_sesiones` y `fn_camarero_toggle_limpieza`; `p_camarero_token` en `fn_registrar_pedido`; `cambiarCamarero()` llama a `fn_camarero_cerrar_sesion` (sin bloquear la salida si falla); ante `error.code === 'RM401'` en cualquier llamada (también en los sondeos de `loadTablas`, `loadAlertas`, `loadLlamadas`, `loadPedidosSesion`), volver a "¿Quién eres?" con el aviso. Pasar `camarero` y un `onSesionCaducada` a los cuatro componentes.
  - `src/components/CamareroClientes.jsx`, `CamareroReservas.jsx`, `CamareroCocina.jsx`, `CamareroLimpieza.jsx` (este último hoy no recibe `camarero`): enviar el token y llamar a `onSesionCaducada` ante `RM401`.
  - Opcional: un ayudante pequeño en `src/lib/` (p. ej. `esSesionCamareroCaducada(error)`) para no repetir la comprobación.
  - `src/pages/Mesa.jsx`: sin cambios.
- BD:
  - Tabla `camarero_sesiones`: `id uuid pk default gen_random_uuid()`, `camarero_id uuid not null references camareros(id) on delete cascade`, `restaurant_id uuid not null references restaurants(id) on delete cascade`, `token_hash text not null unique`, `creada_at timestamptz not null default now()`, `caduca_at timestamptz not null`, `revocada_at timestamptz`. Índice por `camarero_id`. RLS activado; política de solo lectura del dueño (regla 4) aunque authenticated no tenga grant (como `camarero_pin_intentos`, solo la usan funciones `SECURITY DEFINER`). Grants: ninguno a anon ni authenticated; service_role ya lo recibe por los privilegios por defecto. Sin Realtime. Limpieza: al iniciar sesión se borran las sesiones caducadas o revocadas hace más de 7 días.
  - Tabla `camarero_llamadas_sin_token` (solo fase 1): `restaurant_id`, `funcion`, `llamadas int`, `ultima_llamada timestamptz`, clave (`restaurant_id`, `funcion`). Mismas reglas de RLS y grants. Se borra en la fase 2.
  - Funciones nuevas: `fn_staff_exigir_sesion` (grupo C: solo service_role y postgres), `fn_camarero_cerrar_sesion(p_token text)` (grupo A).
  - Funciones cambiadas: las 17 de la tabla, `fn_registrar_pedido`, `fn_verificar_camarero_pin`, `fn_resetear_pin_camarero`. Todas `SECURITY DEFINER`, `set search_path = public` (o `public, extensions` donde se use `crypt`, `digest` o `gen_random_bytes`), `revoke all ... from public` y grants explícitos de su grupo. `fn_staff_tiene_permiso` se conserva (grupo C).
  - `notify pgrst, 'reload schema'` al final de cada migración.
  - Tests: nuevos `supabase/tests/pin_camarero.sql` y `supabase/tests/pin_camarero_fase1.sql`. Actualizar `supabase/tests/permisos_funciones.sql` (añadir las dos funciones nuevas a sus grupos) y `supabase/tests/limpieza_toggle.sql` (debe iniciar sesión y pasar el token, si no fallará en la fase 2). La huella de `supabase/tests/permisos_huella.sql` cambia: hay que volver a comparar Test y Producción tras aplicar cada fase en los dos.
  - Vuelta atrás: `supabase/rollback/pin_camarero_fase1_revertir.sql` y `supabase/rollback/pin_camarero_fase2_revertir.sql`.
- Docs: `docs/ARQUITECTURA.md` (línea del personal: hoy dice que las funciones "comprueban el PIN"; pasa a describir la sesión), `docs/BACKLOG.md` (cerrar la tarea; añadir las de "Fuera de alcance" que se decidan), `docs/MIGRACIONES.md` (estado).
- n8n: no debería verse afectado (usa service_role y no llama a funciones de camarero). Riesgo con `fn_registrar_pedido` en Riesgos.
- Módulo de pago: no aplica. Los permisos del camarero no dependen de módulos.

## Riesgos
1. **Dejar a todos los camareros sin trabajar.** Si la validación falla, falla en todos los restaurantes a la vez. Mitigación: fase 1 tolerante, criterio 7 con una pestaña vieja abierta, fase 2 solo tras 24 h sin llamadas sin token, y `pin_camarero_fase2_revertir.sql` preparado (una sola función, efecto inmediato).
2. **Orden de despliegue en Producción.** El front nuevo con la BD vieja da "función no encontrada" en todas las pantallas del camarero. La migración de fase 1 va siempre antes de que Vercel publique `main`. Al volver atrás, al revés: primero el front, luego la BD.
3. **Pantallas que nunca se recargan.** Una tablet de cocina puede tener abierta la versión vieja días enteros. Tras la fase 2 verá "Tu sesión ha caducado. Recarga la página…" (el mensaje está pensado para que lo entienda también la versión vieja, que muestra el texto del error en Clientes, Reservas y Cocina). En la sección de pedidos la versión vieja no muestra errores de sondeo: la lista de mesas dejaría de actualizarse sin aviso. Por eso la condición de las 24 h sin llamadas antiguas.
4. **Dos versiones de una función.** Si queda la firma antigua junto a la nueva, PostgREST puede no saber cuál usar y la llamada falla. El criterio 6 lo comprueba.
5. **`fn_registrar_pedido` la usa también la mesa por QR**, y no sabemos si n8n la llama. Se añade un parámetro con valor por defecto, así que una llamada con parámetros por nombre sigue funcionando. Si n8n la llamara con `p_camarero_id`, en fase 2 fallaría. Mitigación: el orquestador revisa en los registros de API de Producción (solo lectura) si hay llamadas a `fn_registrar_pedido` con rol `service_role` antes de la fase 2.
6. **El PIN sigue siendo el único secreto y es de 4 dígitos.** Con el límite actual (10 fallos cada 5 minutos por camarero) y probando contra todos los camareros a la vez, un atacante paciente puede acertar un PIN en horas o pocos días. Esta tarea cierra el acceso sin PIN, pero no hace el PIN más difícil de adivinar. Queda como tarea aparte en el backlog (decisión 3).
7. **Multi-tenant.** La sesión se ata a camarero y restaurante; `fn_staff_exigir_sesion` comprueba los dos. El criterio 2 prueba token de otro restaurante.
8. **Hora.** La caducidad es una duración (`now() + 12 h`), no "hasta tal hora". No usa la zona del navegador ni Madrid.
9. **Pedidos en curso.** Un camarero a media comanda cuando caduca su sesión pierde el carrito si la app vuelve a "¿Quién eres?". El front debe conservar el carrito en memoria hasta que vuelva a entrar el mismo camarero, o al menos no borrarlo sin avisar (decisión del implementador; se comprueba en el paso 4 del criterio 8).
10. **Regla 4 y la política del dueño.** Las tablas nuevas tienen la política del dueño, pero sin grant a authenticated no sirve de nada hasta que haya una pantalla que la use. Es a propósito (igual que `camarero_pin_intentos`).
11. **Escrituras en fase 1.** Cada llamada sin token escribe en `camarero_llamadas_sin_token` (la app sondea cada 5–10 s por dispositivo). Es una fila por restaurante y función, y dura solo la fase 1.

## Decisiones (respuestas de Patricio, 12-11-2026)
1. **Duración de la sesión:** 12 horas desde que se pone el PIN (`now() + interval '12 hours'`). Es una duración, sin zona horaria.
2. **Cuándo se aplica la fase 2 con clientes reales:** cuando pasen 24 h sin llamadas en `camarero_llamadas_sin_token`; si alguna pantalla sigue con la versión antigua, se avisa a ese restaurante para que recargue. Hoy (solo restaurantes de prueba en Producción) se aplica en cuanto la fase 1 esté comprobada en Producción.
3. **Endurecer el PIN:** no en esta tarea. Queda en el backlog como tarea aparte.
