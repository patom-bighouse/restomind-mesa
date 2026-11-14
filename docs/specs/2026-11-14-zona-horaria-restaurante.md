# Zona horaria por restaurante
- Fecha: 2026-11-14
- Estado: aprobada por Patricio el 14-11-2026 (decisiones 1-8).
- Rama: `feature/zona-horaria-restaurante`
- Backlog: "Zona horaria por restaurante" (`docs/BACKLOG.md`). Regla fija 7 de `CLAUDE.md`.

## Qué y para quién
Cada restaurante tiene su propia zona horaria. Todo lo que es "hoy" o "a qué hora" en su operativa (reservas, recogidas, menús por franja, vales, cierre de caja, agente de WhatsApp) se calcula con ella, y no con la hora de España.
Lo usan el dueño, el camarero, la cocina, el cliente en mesa, el cliente de la web de reservas y el cliente por WhatsApp. La fija solo el superadmin (decisión 1).
Lo de Restomind como negocio (pruebas gratuitas, permanencia, descuentos, comisiones y tareas del CRM, facturación, días y estadísticas del superadmin) sigue en hora de España.

Es obligatorio antes del primer cliente fuera de la España peninsular y Baleares, Canarias incluida. En Producción ya hay un restaurante de prueba en Canarias ("Resto Fuerteventura").

## Decisiones (14-11-2026)
Respuestas de Patricio a las preguntas del primer borrador.
1. **Quién cambia la zona:** solo el superadmin, en el alta y en la edición del restaurante. El dueño la ve en Configuración y no la puede editar. La BD también lo impide: `fn_restaurants_proteger_comercial` conserva el valor anterior de `zona_horaria` cuando quien actualiza no es superadmin (criterio 3).
2. **Cómo se elige:** una lista corta por país. No se puede escribir a mano.
3. **Canarias:** si la dirección es de Canarias, se propone "Canarias" y el superadmin lo confirma al guardar.
4. **Recogidas antiguas de "Resto Fuerteventura":** no se tocan.
5. **Cambio con pedidos o reservas en marcha:** se permite. Antes sale un aviso con cuántas recogidas pendientes y cuántas reservas futuras tiene el restaurante.
6. **Pantallas secundarias** (historial de clientes, stock, webhooks): pasan ya a la hora del restaurante.
7. **Panel del superadmin:** hora de España y, si el restaurante está en otra zona, su hora local al lado: "22:00 (21:00 en el restaurante)".
8. **Dirección que parece de otra zona en un restaurante que ya existe:** no se cambia la zona; al lado del selector sale el aviso "Esta dirección parece de Canarias y la zona es Península y Baleares" y el superadmin decide.

## Inventario verificado

Fuente: `supabase/migrations/` (versión vigente de cada función; base `20261111193648_remote_schema.sql`). `sql/historico/` no añade nada que no esté ya en la base.

### Base de datos — operativa del restaurante (CAMBIA)
| # | Objeto | Dónde está la versión vigente | Qué usa hoy |
|---|---|---|---|
| 1 | `fn_menu_activo(p_restaurant_id, p_zona, p_momento, p_whatsapp)` | base, l. 2654 | `p_momento at time zone 'Europe/Madrid'` para la franja y el día de la semana. La usan `fn_registrar_pedido` y `fn_carta_takeaway`, que se arreglan solas. |
| 2 | `fn_registrar_pedido` | `20261112152109_pin_camarero_fase1.sql`, l. 867 | vale: `fecha_vencimiento < fn_hoy_madrid()` (l. 1174); menú: `fn_menu_activo(..., now(), false)` |
| 3 | `fn_canjear_vale_regalo` | base, l. 1530 | `fecha_vencimiento < fn_hoy_madrid()` |
| 4 | `fn_crear_reserva_web` | base, l. 1704 | `p_fecha < fn_hoy_madrid()`, `fn_ahora_madrid()` ×2 (hora pasada, 15 min de antelación) |
| 5 | `fn_reserva_whatsapp_crear` (10 argumentos, con `p_clave`) | `20261113164803_reserva_whatsapp_idempotente.sql`, l. 23 | `fn_ahora_madrid()` ×2. La versión de 9 argumentos solo la llama y no cambia. |
| 6 | `fn_reserva_cliente_bloquear` | base, l. 3379 | `fecha + hora > fn_ahora_madrid()` |
| 7 | `fn_reserva_cliente_cancelar` | base, l. 3409 | nota "Anulada … el DD/MM HH:MM" con `fn_ahora_madrid()` |
| 8 | `fn_reserva_cliente_modificar` | base, l. 3433 | 15 min de antelación y nota "Cambiada … el …" con `fn_ahora_madrid()` |
| 9 | `fn_reserva_contexto_cliente` | base, l. 3515 | reservas futuras: `fecha + hora > fn_ahora_madrid()` |
| 10 | `fn_reserva_hay_mesa` | base, l. 3643 | `now() at time zone 'Europe/Madrid'` y `ts.abierta_at at time zone 'Europe/Madrid'` (sesiones abiertas) |
| 11 | `fn_pedido_whatsapp_crear` | `20261113164800_pedido_whatsapp_validaciones.sql`, l. 21 | nota "Recogida a las HH:MM" con `p_hora_recogida at time zone 'Europe/Madrid'` |
| 12 | `fn_agente_datos_restaurante(p_restaurant_id, p_zona)` | `20261114095054_agente_whatsapp_contexto.sql`, l. 81 | ya recibe la zona; por defecto `'Europe/Madrid'` y n8n no la manda |

Cambia también, por la decisión 1, el trigger `fn_restaurants_proteger_comercial` (base, l. 3874). No usa la hora: se le añade `zona_horaria` a la lista de campos que solo toca el superadmin.

Sin cambios porque no miran el reloj (trabajan con fecha y hora "de pared" que ya vienen dadas): `fn_reserva_fuera_de_horario`, `fn_carta_takeaway`, la versión de 9 argumentos de `fn_reserva_whatsapp_crear`, `fn_staff_crear_reserva_manual`, `fn_staff_listar_reservas`. Las duraciones (`now() - interval …`: sesiones de camarero, bloqueos de PIN, agrupado de cocina, limpieza de WhatsApp) no dependen de la zona.

### Base de datos — negocio de Restomind (NO cambia)
| Objeto | Dónde | Qué usa |
|---|---|---|
| `fn_ahora_madrid`, `fn_hoy_madrid`, `fn_hora_madrid` | base, l. 1175, 2524, 2517 | se quedan para lo de negocio (`fn_hora_madrid` no la usa nadie) |
| `fn_aplicar_descuento` | base, l. 1182 | `precio_override_hasta = fn_hoy_madrid() + p_dias` |
| `fn_iniciar_trial` | base, l. 2557 | `trial_termina_en = fn_hoy_madrid() + p_dias` |
| `fn_restaurants_permanencia_alta` (trigger) | base, l. 3860 | `created_at at time zone 'Europe/Madrid'` + 3 meses |
| `fn_permanencia_penalizacion` | base, l. 2858 | `p_fecha default fn_hoy_madrid()` |
| `fn_dar_baja_restaurante` | base, l. 2269 | `fn_hoy_madrid()` ×3 |
| `fn_crm_cuentas_antes` (trigger) | base, l. 1872 | `comision_inicio` con `fn_hoy_madrid()` |
| `fn_crm_generar_comisiones` | base, l. 2021 | `fn_hoy_madrid()` |
| `fn_crm_restaurantes_cuentas` | base, l. 2165 | `fn_crm_cuota_restaurante(r.id, fn_hoy_madrid())` |
| `fn_crm_cuota_restaurante` | base, l. 1965 | `p_fecha default CURRENT_DATE` (es UTC, no España; fallo menor, fuera de alcance, ver Riesgos) |
| `fn_crm_uso_places` | base, l. 2193 | `America/Los_Angeles`: mes de facturación de Google. Correcto así. |
| `crm_tareas.vence_en` | base, l. 7386 | `default fn_hoy_madrid()` |
| `fn_superadmin_estadisticas_agente(…, p_zona)` | `20261114095057_…`, l. 26 | días de las estadísticas en España (decisión de la 1b; la decisión 7 solo añade la hora local al mostrar cada aviso) |

No hay vistas, políticas RLS ni `pg_cron` que usen la hora (`20261113114758` lo confirma: no hay `pg_cron`).

### Front — operativa del restaurante (CAMBIA)
| # | Archivo | Qué usa hoy |
|---|---|---|
| 1 | `src/lib/fechas.js` | `partesMadrid`, `fechaISOMadrid`, `hoyMadrid`, `horaMadrid` fijos a Madrid; `partesEnZona` no devuelve `minutos` |
| 2 | `src/lib/horarioReservas.js` | `horasReserva(config, fecha, ahora = partesMadrid())` |
| 3 | `src/lib/menus.js` | `resolverMenuActivo(menus, zona, ahora)` con `partesMadrid` (aquí `zona` es la del salón) |
| 4 | `src/pages/Reservar.jsx` (web pública) | `hoyMadrid()`, `horasReserva` |
| 5 | `src/pages/Mesa.jsx` (cliente en mesa) | `hoyMadrid()` (vale), `resolverMenuActivo` ×2, hora de los pedidos con `toLocaleTimeString` (zona del móvil) |
| 6 | `src/pages/Camarero.jsx` | `hoyMadrid()` (vale), `resolverMenuActivo` ×2, `toLocaleTimeString` |
| 7 | `src/components/CamareroReservas.jsx` | `hoyMadrid()` para "próximas"; fecha de reserva (solo fecha, correcto) |
| 8 | `src/pages/AdminReservas.jsx` | `hoyMadrid()` para "próximas" |
| 9 | `src/pages/AdminMesas.jsx` | `hoyMadrid()` (reservas de hoy), "Abierta desde" con `toLocaleTimeString` |
| 10 | `src/pages/AdminVales.jsx` | `hoyMadrid()` (vencimiento por defecto y "Caducado") |
| 11 | `src/pages/Cocina.jsx` | `horaMadrid(hora_recogida)`, `toLocaleTimeString` (l. 102), fecha de cabecera con `toLocaleDateString` (l. 615) |
| 12 | `src/pages/AdminDashboard.jsx` | `getRangeDates` con la hora del navegador ("Hoy", "Esta semana", "Este mes"), horas pico con `getHours()`, días con `getDay()`, `horaMadrid`, `fechaISOMadrid`, CSV y cierre de caja con `toLocale…` |
| 13 | `src/components/CuentaMesa.jsx` | 5 horas con `toLocaleString`/`toLocaleTimeString` |
| 14 | `src/components/AlertasAgente.jsx` | `zona = ZONA_POR_DEFECTO` |
| 15 | `src/components/GuardRestaurante.jsx` | monta `AlertasAgente` sin zona |
| 16 | `src/pages/AdminAvisosWhatsApp.jsx` | `ZONA = ZONA_POR_DEFECTO` |
| 17 | `src/pages/AdminCarta.jsx` | `hoyMadrid()` en el nombre del archivo exportado (menor) |
| 18 | `src/pages/AdminClientes.jsx` | última visita y movimientos de puntos con `toLocale…` (decisión 6) |
| 19 | `src/components/CamareroClientes.jsx` | movimientos de puntos con `toLocaleString` (decisión 6) |
| 20 | `src/pages/AdminStock.jsx` | movimientos de stock con `toLocaleString` (decisión 6) |
| 21 | `src/pages/AdminWebhooks.jsx` | envíos de webhooks con `toLocaleString` (decisión 6) |

Además:
- `src/pages/SuperAdminRestaurantes.jsx`: selector de zona, propuesta por país y por dirección, aviso del cambio (decisiones 1, 2, 3 y 5). Sus usos de `hoyMadrid()` (prueba gratuita, descuento) son de negocio y no cambian.
- `src/pages/AdminConfig.jsx`: el dueño ve la zona, sin poder editarla. Su uso de `hoyMadrid()` (permanencia) es de negocio y no cambia.
- `src/pages/SuperAdminAgenteWhatsApp.jsx`: horas con la hora local al lado (decisión 7). Los filtros por día y las estadísticas siguen en España.

### Front — negocio de Restomind (NO cambia)
`src/lib/crm.js` y `src/components/crm/*`. Los filtros por día y las estadísticas de `SuperAdminAgenteWhatsApp.jsx`. `Privacidad.jsx`, `Condiciones.jsx` y `Landing.jsx` solo muestran el año.

### n8n — `n8n/workflows/restomind_whatsapp_agente.json` (CAMBIA)
| Nodo | Qué usa hoy |
|---|---|
| Verificar restaurante y módulo whatsapp | lee `restaurants` (`select=id,nombre,activo,whatsapp,moneda,…`): falta `zona_horaria` |
| Combinar con sesión | llama a `fn_agente_datos_restaurante` sin `p_zona` (sale Madrid) |
| Preparar reserva | `ahoraMadrid()`; el prompt dice "Hora actual en España" |
| Procesar respuesta reserva | `ahoraMadrid()` |
| Crear reserva Supabase | `ahoraMadrid()` |
| Verificar disponibilidad | `ahoraMadrid()` |
| Preparar takeaway | `ahoraMadrid()` |
| Procesar respuesta takeaway | `ahoraMadrid()` |
| Validar hora recogida | `ahoraMadrid()` |
| Preparar pedido datos | `p_hora_recogida: "<fecha> <hora> Europe/Madrid"` |

`ahoraMadrid()` tiene un respaldo sin `Intl` con la regla de la UE (offsets +1/+2): solo vale para Madrid.
No cambian: `settings.timezone` de los dos workflows (ningún nodo usa `$now` ni Luxon) y `restomind_whatsapp_errores.json`.
Comprobadores: `n8n/tests/comprobar_workflow.py` (punto 8) y `n8n-agente-takeaway/comprobar_hora_espana.py` (este apunta por defecto al JSON viejo `restomind_whatsapp_agente_V02.json`).

### Tamaño real
- BD: 12 funciones de operativa + 1 trigger de protección que cambian, y 4 nuevas (3 de ayuda y 1 de trigger de validación) = 17. 0 vistas, 0 políticas.
- Front: 21 archivos de operativa + 3 de superadmin y Configuración = 24, más 1 archivo nuevo (`src/lib/zonasHorarias.js`) y las pruebas.
- n8n: 10 nodos de 1 workflow, y 2 comprobadores.

## Diseño

### Columna
- `restaurants.zona_horaria text not null default 'Europe/Madrid'`. Todos los restaurantes actuales quedan en Madrid: mismo comportamiento que hoy.
- Nombre `zona_horaria` (y `zonaHoraria` en JS) en todo el código. "Zona" ya significa zona del salón en `reservations.zona`, `tables.zona`, `menus.zona` y el `p_zona` de `fn_crear_reserva_web`, `fn_menu_activo` y `fn_reserva_*`.

### Funciones de ayuda (SQL)
- `fn_zona_restaurante(p_restaurant_id uuid) returns text`: la zona del restaurante; `'Europe/Madrid'` si el restaurante no existe.
- `fn_ahora_restaurante(p_restaurant_id uuid) returns timestamp`: `now() at time zone fn_zona_restaurante(...)` (hora de pared, como `fn_ahora_madrid`).
- `fn_hoy_restaurante(p_restaurant_id uuid) returns date`.
- `stable`, `set search_path = public`, `security invoker`. Sin `grant` a `anon` ni `authenticated`: solo se llaman desde otras funciones. Encajarlas en el grupo que toque de `supabase/tests/permisos_funciones.sql`.
- Las 12 funciones cambian `fn_*_madrid()` y `'Europe/Madrid'` por estas, sin cambiar su firma. n8n y el front las siguen llamando igual.
- `fn_agente_datos_restaurante`: `p_zona` pasa a `default null`; si es null, usa `fn_zona_restaurante`. Si viene una zona, se respeta (compatibilidad).

### Validación de la zona
- En BD, trigger `fn_restaurants_validar_zona_horaria` (`before insert or update of zona_horaria on restaurants`). Acepta solo nombres que:
  - existen en `pg_timezone_names`;
  - empiezan por `Africa/`, `America/`, `Antarctica/`, `Asia/`, `Atlantic/`, `Australia/`, `Europe/`, `Indian/` o `Pacific/` (fuera `CET`, `UTC`, `Etc/GMT+3`, `posix/…`, abreviaturas).
  - Si no, error `22023` "Zona horaria no válida: …".
- La BD no se limita a la lista del front. Así, para abrir un país nuevo basta con añadir su lista al front, sin migración. Lo que se ofrece en pantalla es solo la lista corta (decisión 2).
- En el front, la lista cerrada por país está en `src/lib/zonasHorarias.js`, comprobada también con `Intl.DateTimeFormat(…, { timeZone })`.

### Solo el superadmin la cambia (decisión 1)
- `fn_restaurants_proteger_comercial` (trigger `before update` de `restaurants`, ya existente) añade `new.zona_horaria := old.zona_horaria` dentro de `if auth.uid() is not null and not fn_es_superadmin()`. Mismo criterio que `plan`, `permanencia_hasta`, etc.: si lo intenta un dueño por la API, el cambio se ignora sin error, y el resto de su guardado sigue funcionando.
- En el alta no hace falta proteger nada más: solo el superadmin puede crear restaurantes (política `superadmin_insert_restaurants`).
- n8n y las migraciones (`service_role`, sin `auth.uid()`) no quedan afectados. No escriben la zona.
- `AdminConfig.jsx` no envía `zona_horaria` en su `update`. Solo la muestra: "Zona horaria: Canarias (ahora son las 21:00 en el restaurante). Si no es correcta, escríbenos.".

### Lista por país y propuesta (decisiones 2 y 3)
| País | Propuesta | Otras zonas de la lista |
|---|---|---|
| ES | `Europe/Madrid` ("Península y Baleares") | `Atlantic/Canary` ("Canarias"). Ceuta y Melilla tienen la misma hora que Madrid. |
| MX | `America/Mexico_City` | `America/Cancun` (Quintana Roo), `America/Merida`, `America/Monterrey`, `America/Chihuahua`, `America/Ciudad_Juarez`, `America/Mazatlan` (Pacífico), `America/Hermosillo` (Sonora), `America/Tijuana` (Baja California) |
| US | `America/New_York` | `America/Chicago`, `America/Denver`, `America/Phoenix`, `America/Los_Angeles`, `America/Anchorage`, `Pacific/Honolulu` |
| AR | `America/Argentina/Buenos_Aires` | (una sola hora en todo el país) |
| CO | `America/Bogota` | — |
| CL | `America/Santiago` | `America/Punta_Arenas` (Magallanes), `Pacific/Easter` (Isla de Pascua) |
| PE | `America/Lima` | — |

- El desplegable muestra nombres claros ("Canarias", "Península y Baleares", "Ciudad de México"…) con la hora actual de cada zona al lado. Solo ofrece las zonas del país elegido. No hay campo libre.
- Al crear un restaurante, o al cambiar su país, se rellena la propuesta del país.
- Canarias (decisión 3): con país ES, si la dirección contiene "Canarias", "Las Palmas", "Santa Cruz de Tenerife", el nombre de una isla (Tenerife, Gran Canaria, Lanzarote, Fuerteventura, La Palma, La Gomera, El Hierro, La Graciosa) o un código postal 35xxx o 38xxx, se propone "Canarias". Sin distinguir mayúsculas ni tildes. Lo hace la función `zonaPropuesta(pais, direccion)` de `zonasHorarias.js`.
- El superadmin confirma al guardar: la zona propuesta se ve marcada ("Propuesta por la dirección: Canarias") y puede elegir otra de la lista.
- En la edición de un restaurante que ya existe, cambiar la dirección no cambia la zona por sí sola. Si la dirección nueva sugiere otra zona, se muestra la sugerencia junto al selector (ver pregunta 8).
- Si el restaurante tiene guardada una zona que no está en la lista de su país (por ejemplo, puesta por SQL), el desplegable la muestra igualmente, marcada como "fuera de la lista", para no perderla al guardar.

### Aviso al cambiar la zona (decisión 5)
- Solo al editar un restaurante que ya existe y cuando la zona elegida es distinta de la guardada.
- Al pulsar Guardar, el front cuenta (el superadmin ya puede leer `orders` y `reservations` por RLS: `is_restaurant_owner` y `reservations_dueno` lo incluyen):
  - recogidas pendientes: `orders` del restaurante con `tipo = 'takeaway'` y `estado in ('pendiente','preparando','listo')`;
  - reservas futuras: `reservations` con `estado in ('confirmada','pendiente')` y fecha + hora posteriores a "ahora" en la zona guardada.
- Ventana de confirmación con las dos cifras, también cuando son 0: "Vas a cambiar la zona de <restaurante> de Península y Baleares a Canarias. Tiene 2 recogidas pendientes y 5 reservas futuras. Las reservas mantienen su hora. Las recogidas pendientes pueden verse con una hora de diferencia. ¿Cambiar la zona?" → "Cambiar" / "Cancelar".
- Si no se pueden contar (fallo de red), el aviso lo dice ("No he podido comprobar los pedidos y reservas en marcha") y deja confirmar igual.
- El cálculo de "reservas futuras" va en una función pura de `zonasHorarias.js` (`contarReservasFuturas(reservas, zonaHoraria, ahora)`) para probarla con Vitest.

### Panel del superadmin (decisión 7)
- Nueva función `fechaHoraConLocal(instante, zonaRestaurante)` en `fechas.js`. Devuelve "DD/MM/AAAA 22:00 (21:00 en el restaurante)". Si la hora mostrada en la zona del restaurante coincide con la de España (Madrid, Ceuta…), solo "DD/MM/AAAA 22:00". Si el día también cambia: "14/11/2026 00:30 (13/11 23:30 en el restaurante)".
- `SuperAdminAgenteWhatsApp.jsx`:
  - añade `zona_horaria` a su lectura de `restaurants`;
  - usa `fechaHoraConLocal` en "Primera vez", "Última vez", "atendida", la columna de fecha y el detalle;
  - los filtros por día, `inicioDiaEnZona` y `fn_superadmin_estadisticas_agente` siguen en España;
  - el texto del aviso (`textoAviso`) se muestra igual que lo ve el dueño, con la hora del restaurante, porque es su texto.
- Avisos sin restaurante: solo hora de España.

### Cómo llega la zona al resto del front
- Las páginas que ya leen `restaurants` añaden `zona_horaria` a su `select`.
- La columna se añade al `grant select (…)` de `anon` en `restaurants`. La necesitan la web de reservas, la mesa, el camarero y la cocina, que corren como `anon`. Es un dato inofensivo. Cambia la huella de permisos (`supabase/tests/permisos_huella.sql`): actualizarla y comprobar que es igual en Test y Producción.
- `AlertasAgente` lo monta `GuardRestaurante`. Hay que decidir si `GuardRestaurante` lee la zona y se la pasa, o si `AlertasAgente` la lee él mismo. Lo decide el implementador; no se toca la lógica de suspensión.
- `fechas.js`:
  - `partesEnZona` devuelve también `minutos`;
  - nuevas `hoyEnZona(zona)`, `rangoDiasEnZona(rango, desde, hasta, zona)` (para el panel) y `fechaHoraConLocal`;
  - `partesMadrid`, `hoyMadrid`, `fechaISOMadrid` y `horaMadrid` se quedan solo para lo de negocio.
- `horasReserva(config, fecha, ahora)` y `resolverMenuActivo(menus, zonaSalon, ahora, zonaHoraria)` reciben la zona.
- Si un restaurante no trae la zona (dato vacío), se usa `ZONA_POR_DEFECTO` (`Europe/Madrid`).
- Las horas de pantalla salen con `horaEnZona` / `fechaHoraEnZona`, nunca con `toLocale…` sin `timeZone`. Incluidas las 4 pantallas secundarias (decisión 6).

### n8n
- "Verificar restaurante y módulo whatsapp" añade `zona_horaria` al `select` y la deja en `datosRest.zona_horaria`.
- `ahoraMadrid()` pasa a `ahoraEnZona(zona, instante)` en los 7 nodos. La zona se lee de `$('Verificar restaurante y módulo whatsapp')`, con `'Europe/Madrid'` si falta.
- El respaldo sin `Intl` (regla de la UE) se queda solo para `Europe/Madrid` (+1/+2) y `Atlantic/Canary` (0/+1). Con otra zona y sin `Intl`, se registra `error_interno` y el cliente recibe el mensaje de problema técnico. En la práctica, el Node de n8n siempre trae `Intl`.
- "Preparar pedido datos": `"<fecha> <hora> <zona>"`.
- Prompt de "Preparar reserva": "Hora actual en el restaurante" en lugar de "en España".
- "Combinar con sesión" no cambia: la función SQL ya usa la zona del restaurante.
- Comprobadores: `comprobar_workflow.py` (punto 8) y `comprobar_hora_espana.py` pasan a probar `ahoraEnZona` en `Europe/Madrid`, `Atlantic/Canary` y `America/Mexico_City`, en los próximos cambios de hora y sin `Intl`. Prohíben `'Europe/Madrid'` escrito fuera del valor por defecto. `comprobar_hora_espana.py` apunta por defecto a `n8n/workflows/restomind_whatsapp_agente.json`.
- Antes de editar el JSON: pedir a Patricio el export actual de n8n (el local puede estar desincronizado).

### Datos ya guardados
| Dato | Tipo | Qué pasa |
|---|---|---|
| `reservations.fecha` + `hora` | fecha y hora "de pared", sin zona | No se migran. Ya significan la hora local del restaurante (lo que dijo el cliente). Lo que cambia es con qué "ahora" se comparan. |
| `menus.hora_inicio/hora_fin/dias_semana`, `config.horario` | hora de pared | No se migran. |
| `vales_regalo.fecha_vencimiento` | fecha | No se migra. Se compara con el "hoy" del restaurante. |
| `orders.created_at`, `hora_recogida`, `table_sessions.abierta_at/cerrada_at`, pagos, avisos | `timestamptz` (instante absoluto) | No se migran. Solo cambia cómo se muestran. |
| `orders.hora_recogida` de pedidos de WhatsApp ya creados en "Resto Fuerteventura" | `timestamptz` construido como "hora dicha + Europe/Madrid" | No se tocan (decisión 4). Al pasarlo a Canarias se verán una hora antes de lo que dijo el cliente. Son pruebas. |
| `orders.notas` "Recogida a las HH:MM", notas de reservas "Anulada/Cambiada … el …" | texto | Se quedan como están. |
| Cierre de caja | no se guarda: se calcula al abrir el panel | Con la zona nueva, el día va de 00:00 a 00:00 del restaurante. Un cierre de un día antiguo, si se vuelve a sacar, puede cambiar en las ventas de cerca de medianoche (antes contaba la hora del ordenador). |

Al cambiar la zona de un restaurante, los pedidos para recoger que estén pendientes en ese momento conservan su instante. Si se crearon con la zona vieja, se verán con otra hora. Por eso sale el aviso de la decisión 5.

### Cambio de hora (verano/invierno)
- Siempre zonas IANA (`at time zone <zona>` en Postgres, `Intl` en el navegador y en n8n). Nunca desfases fijos. Cada zona cambia en su fecha: Madrid y Canarias el último domingo de marzo y de octubre a las 01:00 UTC; EE. UU. en otras fechas; México (`America/Mexico_City`) no cambia desde 2022.
- Horas que no existen (Madrid 02:30 o Canarias 01:30 el día que se adelanta la hora) y horas repetidas (el día que se atrasa): Postgres las resuelve sin error al convertir "fecha hora zona". Lo que se exige es que no fallen y que la hora mostrada sea la pedida o la siguiente válida. Las reservas se comparan en hora de pared, así que no les afecta.
- Depende de que los datos de zonas estén al día en Supabase y en los dispositivos. Un móvil muy antiguo podría seguir aplicando el horario de verano de México. Las comprobaciones que deciden (reserva válida, vale caducado, menú activo) están en la BD.

### Cómo se prueba sin romper Madrid
- Valor por defecto `Europe/Madrid`: tras la migración, `fn_ahora_restaurante(id) = fn_ahora_madrid()` para todos los restaurantes actuales. Dentro de una transacción `now()` es fijo, así que la igualdad es exacta.
- Se vuelven a pasar sin tocarlas las pruebas actuales: `reserva_whatsapp_validaciones.sql`, `reserva_whatsapp_idempotente.sql`, `pedido_whatsapp.sql`, `agente_datos_restaurante.sql`, `agente_errores.sql`, `permisos_*.sql` (con la huella nueva).
- Prueba nueva `supabase/tests/zona_horaria.sql` (solo Test, `begin … rollback`):
  - crea restaurantes de prueba en `Atlantic/Canary` y `America/Mexico_City`;
  - usa instantes fijos en `fn_menu_activo` (tiene `p_momento`);
  - en reservas y vales calcula el "ahora" con `fn_ahora_restaurante` para no depender de la hora a la que se ejecute.
- Front: Vitest con instantes fijos (adelanta lo previsto en la fase 3 del backlog: añadir `vitest` como dependencia de desarrollo y el script `npm test`).
- n8n: comprobador con las tres zonas. Conversación en Producción con un restaurante en Madrid (los casos de `n8n/tests/conversaciones.md`) y con "Resto Fuerteventura" en Canarias.

## Plan por fases y orden de despliegue
Regla de oro: **ningún restaurante cambia de zona hasta que las tres fases estén en Producción**. Mientras todos estén en Madrid, cada fase por separado no cambia nada visible. El selector solo aparece en la fase 2, así que nadie puede cambiar la zona antes.

1. **Fase 1 — BD** (una migración):
   - columna, trigger de validación, 3 funciones de ayuda, 12 funciones reescritas;
   - protección de `zona_horaria` en `fn_restaurants_proteger_comercial`;
   - `grant select (zona_horaria)` a `anon`;
   - pruebas en `supabase/tests/zona_horaria.sql` y huella de permisos;
   - Test → pruebas → Producción. Debe estar en Producción **antes** de que llegue a `main` cualquier front que pida `zona_horaria`: si no, las páginas que la piden fallan al cargar (la mesa, la web de reservas, la cocina).
2. **Fase 1b — n8n**:
   - workflow con `ahoraEnZona` y comprobadores generalizados;
   - se reimporta en Producción (n8n solo existe allí) después de la fase 1 y fuera de servicio. Con todos en Madrid, se comporta igual que hoy.
3. **Fase 2 — Front**:
   - `fechas.js`, `horarioReservas.js`, `menus.js`, `zonasHorarias.js`, páginas, Vitest;
   - selector, propuesta y aviso en el superadmin; vista en Configuración; hora local en el panel del agente;
   - PR a `staging` → preview → `main`.
4. **Fase 3 — Activación**: con las tres fases en Producción, Patricio pone "Resto Fuerteventura" en Canarias desde el superadmin y hace la prueba de conversación del criterio 7.

Se puede hacer en una sola rama y un solo PR, siempre que la migración se aplique en Producción antes del merge a `main` y el n8n se reimporte después de la migración.

## Criterios de aceptación
| # | Criterio | Cómo se prueba |
|---|---|---|
| 1 | Dado un restaurante existente, cuando se aplica la migración, entonces su `zona_horaria` es `Europe/Madrid`, `fn_ahora_restaurante(id) = fn_ahora_madrid()`, `fn_hoy_restaurante(id) = fn_hoy_madrid()`, y las pruebas SQL actuales siguen en verde sin tocarlas. | sql: `supabase/tests/zona_horaria.sql` (`begin … rollback`, en Test) para todos los restaurantes de Test; volver a pasar `reserva_whatsapp_validaciones.sql`, `reserva_whatsapp_idempotente.sql`, `pedido_whatsapp.sql`, `agente_datos_restaurante.sql`, `agente_errores.sql` y `permisos_*.sql`. |
| 2 | Dado un restaurante, cuando el superadmin guarda `zona_horaria` = `'Europe/Madird'`, `'CET'`, `'UTC'`, `'Etc/GMT+3'` o `''`, entonces da error `22023` y no se guarda. Con `'Atlantic/Canary'` o `'America/Mexico_City'` se guarda. `anon` puede leer `zona_horaria`. | sql: en `zona_horaria.sql`, `set local role authenticated` + `request.jwt.claims` de un superadmin de prueba, `update` comprobando `sqlstate`; `set local role anon` + `select zona_horaria`. |
| 3 | Dado un restaurante en `Europe/Madrid` y su dueño (`authenticated`, no superadmin), cuando el dueño hace `update restaurants set zona_horaria = 'Atlantic/Canary', nombre = 'X'`, entonces el nombre cambia y la zona sigue en `Europe/Madrid`. Cuando lo hace el superadmin, la zona cambia. En la preview, Configuración del dueño muestra la zona y no tiene ningún campo para cambiarla. | sql: `zona_horaria.sql`, `set local role authenticated` con los `request.jwt.claims` del dueño de prueba y después de un superadmin, `update` y relectura, dentro de `begin … rollback`. manual: en la preview, entrar como dueño en `/admin/config/<id>` y comprobar que la zona sale como texto, sin desplegable. |
| 4 | Dado un menú 13:00–14:00, cuando se pide `fn_menu_activo` en `2027-01-15 12:30Z`, entonces sale activo en Madrid (13:30) y no en Canarias (12:30). En `2027-07-15 19:30Z` sale activo en `America/Mexico_City` (13:30, sin horario de verano) y no en Madrid (21:30). Con un menú 02:00–03:00 el día del cambio de hora en Canarias (`2027-03-28`): a las `00:59Z` no está activo (00:59); a las `01:00Z` sí (02:00, ya en verano); en Madrid a las `01:00Z` no (03:00). | sql: `zona_horaria.sql` con 3 restaurantes de prueba y `p_momento` fijo. |
| 5 | Dado un restaurante en `America/Mexico_City` (y otro en `Atlantic/Canary`) sin horario configurado, siendo L = `fn_ahora_restaurante(id)`, entonces: una reserva para L + 5 min la rechazan `fn_crear_reserva_web` y `fn_reserva_whatsapp_crear` por los 15 min de antelación; una para L − 10 min da "ya han pasado"; una para L + 60 min se crea; `fn_reserva_contexto_cliente` devuelve la de L + 30 min y no la de L − 30 min; `fn_reserva_cliente_modificar` aplica los mismos 15 min con L. | sql: `zona_horaria.sql`; fecha y hora calculadas desde L (válido a cualquier hora a la que se ejecute). |
| 6 | Dado un restaurante en `Atlantic/Canary`, entonces: un vale con vencimiento `fn_hoy_restaurante(id) − 1` se rechaza en `fn_canjear_vale_regalo` y en `fn_registrar_pedido`, y uno que vence hoy se acepta; `fn_pedido_whatsapp_crear` con `p_hora_recogida = '<mañana> 21:30 Atlantic/Canary'` guarda la nota "Recogida a las 21:30"; `fn_agente_datos_restaurante(id)` sin zona devuelve `zona = 'Atlantic/Canary'` y `hoy.fecha` = `fn_hoy_restaurante(id)`. | sql: `zona_horaria.sql`, ampliando `pedido_whatsapp.sql` y `agente_datos_restaurante.sql`. |
| 7 | (a) Dado el workflow del agente, cuando se ejecuta el comprobador, entonces `ahoraEnZona` de cada nodo da la hora correcta, con y sin `Intl` (el segundo solo en Madrid y Canarias), en: Madrid y Canarias en los próximos cambios (`2027-03-28 00:59Z` → Canarias 00:59 / Madrid 01:59; `01:00Z` → Canarias 02:00 / Madrid 03:00; `2027-10-31 00:59Z` → Canarias 01:59; `01:00Z` → Canarias 01:00); y México sin cambios (`2027-04-04 12:00Z` y `2027-10-31 12:00Z` → 06:00). Falla si queda `'Europe/Madrid'` escrito fuera del valor por defecto o si "Preparar pedido datos" no usa la zona. (b) Con "Resto Fuerteventura" en `Atlantic/Canary` (fase 3): "¿qué día es hoy?" responde la fecha de Canarias; un pedido para recoger "a las <hora de Canarias + 30 min>" se acepta y en Cocina y en el panel sale "Recoge a las" esa misma hora; una reserva "hoy a las <hora de Canarias + 10 min>" se rechaza por los 15 min; y a las <hora de Canarias + 1 h> se crea. Con un restaurante en Madrid, los casos de `n8n/tests/conversaciones.md` dan lo mismo que antes. | auto: `python3 n8n/tests/comprobar_workflow.py --para-importar n8n/workflows/restomind_whatsapp_agente.json` y `python3 n8n-agente-takeaway/comprobar_hora_espana.py n8n/workflows/restomind_whatsapp_agente.json`. conversación: casos nuevos en `n8n/tests/conversaciones.md` (sección "Zona horaria"), en Producción con el número de prueba, apuntando la hora de Canarias en el momento de la prueba. |
| 8 | Dado el front, entonces: (a) con instantes fijos, `partesEnZona`, `hoyEnZona`, `rangoDiasEnZona`, `horasReserva` y `resolverMenuActivo` dan los mismos resultados que los criterios 4 y 5 para Madrid, Canarias y México, incluido el día de cambio de hora. `fechaHoraConLocal('2027-01-15T21:00:00Z', 'Atlantic/Canary')` da "15/01/2027 22:00 (21:00 en el restaurante)"; con `Europe/Madrid` da solo "15/01/2027 22:00". `zonaPropuesta('ES', 'C/ Mayor 3, 35600 Puerto del Rosario')` da `Atlantic/Canary`; `zonaPropuesta('ES', 'C/ Mayor 3, 28013 Madrid')` da `Europe/Madrid`; `zonaPropuesta('MX', …)` da `America/Mexico_City`. `contarReservasFuturas` no cuenta las ya pasadas en la zona dada. (b) En la preview, con el ordenador en hora de Madrid y un restaurante de Test en Canarias: la web de reservas, el panel ("Hoy", horas pico, cierre de caja), Cocina, Camarero, la mesa y las 4 pantallas secundarias usan la hora de Canarias; el superadmin ve la lista corta del país, la propuesta de Canarias por la dirección y el aviso con recogidas y reservas antes de cambiar; el panel del agente muestra "22:00 (21:00 en el restaurante)". | auto: Vitest (`npm test`, archivos `src/lib/*.test.js`) + `npm run build`. manual: Patricio, en la preview de `staging`, con un restaurante de Test (no "Resto Fuerteventura" de Producción): 1) superadmin → Restaurantes → editar; el desplegable de zona solo ofrece "Península y Baleares" y "Canarias"; 2) escribir una dirección con código postal 35xxx y ver "Propuesta por la dirección: Canarias"; 3) elegir Canarias y pulsar Guardar: sale el aviso con el número de recogidas pendientes y reservas futuras; confirmar; 4) abrir `/reservar/<id>` para hoy: la primera hora ofrecida es como mínimo la hora de Canarias + 15 min; 5) crear un pedido desde la mesa y ver en Cocina, Camarero y el panel la hora de Canarias (una hora menos que el reloj del ordenador); 6) en el panel, "Hoy" no incluye pedidos de antes de las 00:00 de Canarias; 7) en Clientes, Stock y Webhooks las horas salen en hora de Canarias; 8) en superadmin → Agente WhatsApp, un aviso de ese restaurante sale como "HH:MM (HH−1:MM en el restaurante)"; 9) volver a poner "Península y Baleares" y comprobar que todo vuelve a la hora del ordenador y que el panel del agente ya no muestra el paréntesis. |

## Fuera de alcance
- Zona horaria para lo de negocio de Restomind (pruebas, permanencia, CRM, facturación, días y estadísticas del superadmin): sigue en España.
- Hora de corte del día distinta de medianoche para el cierre de caja (bares que cierran a las 2:00).
- Corregir pedidos o reservas antiguos (decisión 4).
- Que el dueño edite la zona (decisión 1).
- Escribir la zona a mano o buscar en una lista mundial (decisión 2).
- Validar en BD el horario de take away (sigue en n8n; está en la fase 2 del agente).
- Arreglar `fn_crm_cuota_restaurante` (`CURRENT_DATE` en UTC): es de negocio. Se apunta en el backlog.
- Idiomas, formatos de fecha por país y moneda: siguen como hoy (`es-ES`, `formatMoney()`).
- Detectar la zona por GPS o por la dirección con servicios externos: la propuesta de Canarias es solo por texto.

## Impacto técnico
- Front:
  - `src/lib/fechas.js`, `src/lib/horarioReservas.js`, `src/lib/menus.js`;
  - nuevo `src/lib/zonasHorarias.js`: lista por país, nombres claros, `zonaPropuesta(pais, direccion)`, `contarReservasFuturas`;
  - `src/pages/Reservar.jsx`, `Mesa.jsx`, `Camarero.jsx`, `AdminReservas.jsx`, `AdminMesas.jsx`, `AdminVales.jsx`, `Cocina.jsx`, `AdminDashboard.jsx`, `AdminAvisosWhatsApp.jsx`, `AdminCarta.jsx`, `AdminClientes.jsx`, `AdminStock.jsx`, `AdminWebhooks.jsx`;
  - `AdminConfig.jsx` (solo lectura), `SuperAdminRestaurantes.jsx` (selector, propuesta, aviso), `SuperAdminAgenteWhatsApp.jsx` (hora local al lado);
  - `src/components/CamareroReservas.jsx`, `CamareroClientes.jsx`, `CuentaMesa.jsx`, `AlertasAgente.jsx`, `GuardRestaurante.jsx`;
  - pruebas `src/lib/*.test.js`, `package.json` (`vitest` en desarrollo y script `test`).
- BD: una migración `supabase/migrations/<ts>_zona_horaria_restaurante.sql`:
  - columna `restaurants.zona_horaria`;
  - trigger `fn_restaurants_validar_zona_horaria`;
  - `fn_zona_restaurante`, `fn_ahora_restaurante`, `fn_hoy_restaurante`;
  - las 12 funciones del inventario (misma firma y mismos grants; `fn_agente_datos_restaurante` mantiene la firma `(uuid, text)` y pasa a usar la zona del restaurante cuando `p_zona` es null);
  - `fn_restaurants_proteger_comercial` con `zona_horaria`;
  - `grant select (zona_horaria) on restaurants to anon`.
  - Sin tablas nuevas, así que no hace falta RLS ni Realtime nuevos.
  - Pruebas: `supabase/tests/zona_horaria.sql` y huella nueva en `permisos_huella.sql`. Anotarla en `docs/MIGRACIONES.md`.
- n8n: `n8n/workflows/restomind_whatsapp_agente.json` (10 nodos), `n8n/tests/comprobar_workflow.py`, `n8n-agente-takeaway/comprobar_hora_espana.py`, `n8n/tests/conversaciones.md`.
- Docs: `docs/ARQUITECTURA.md` (sección Hora), regla 7 de `CLAUDE.md` (ya no "pendiente"; lo cambia el orquestador), `docs/BACKLOG.md`.
- Módulo de pago: ninguno. La zona es un dato básico del restaurante y vale para todos los módulos.

## Riesgos
- **Orden de despliegue:** si el front que pide `zona_horaria` llega a Producción antes que la migración (o antes del `grant` a `anon`), la mesa, la web de reservas, el camarero y la cocina fallan al cargar el restaurante. La migración va primero.
- **Front y BD con zonas distintas:** si un restaurante se pasa a Canarias antes de que estén las tres fases, la web ofrece horas que la BD rechaza, o el agente valida con una hora y la BD con otra. Por eso ningún restaurante cambia de zona hasta la fase 3.
- **Pedidos en curso al cambiar la zona:** los pedidos para recoger que se crearon con la zona vieja se ven con otra hora. El aviso de la decisión 5 lo avisa, pero no lo impide. Con clientes reales, cambiar la zona fuera de servicio.
- **Protección silenciosa:** si un dueño cambia la zona por la API, la BD ignora el cambio sin dar error (mismo criterio que el plan o la permanencia). Desde la app no puede: no tiene el campo.
- **Propuesta de Canarias equivocada:** el texto de una dirección puede confundir (una "Calle La Palma" en Madrid, un código postal mal escrito). Por eso es solo una propuesta y el superadmin confirma. En la edición no cambia la zona sola.
- **Confusión entre "zona" del salón y zona horaria:** `p_zona` ya es la zona del salón en 5 funciones y en `resolverMenuActivo`. Si se mezclan, la reserva miraría las mesas de una "zona" `Atlantic/Canary`. Por eso todo lo nuevo se llama `zona_horaria` / `zonaHoraria`. La excepción heredada es `fn_agente_datos_restaurante(p_zona)`, que ya es zona horaria.
- **Multi-tenant:** las funciones de ayuda leen `restaurants` por id y no devuelven más datos que la zona. Al ser `security invoker` y sin grants públicos, nadie las llama desde fuera. Exponer `zona_horaria` a `anon` no revela nada sensible. El aviso del superadmin solo cuenta datos que el superadmin ya puede leer por RLS.
- **Permisos:** la huella cambia (columna nueva para `anon`, funciones nuevas). Tiene que quedar igual en Test y Producción.
- **Datos de zonas desactualizados:** Postgres de Supabase y los navegadores traen su propia copia de las reglas de cada país. Si un país cambia sus reglas (como México en 2022), un móvil antiguo puede mostrar una hora mal. Lo que decide (reserva válida, vale, menú) está en la BD.
- **Regla 7 respetada:** el cambio la cumple, también en el panel del superadmin (España, con la hora local solo como información). Sigue siendo pendiente una parte de negocio que usa UTC sin querer (`fn_crm_cuota_restaurante`), fuera de alcance.
- **JSON de n8n desincronizado:** el local puede no ser el que está activo. Pedir el export antes de editarlo y pasar los comprobadores antes de importarlo.
- **Panel con la hora del navegador:** hoy `AdminDashboard.jsx` usa la hora del ordenador, no la de Madrid. Un dueño que lo abra desde otro país verá cambios en "Hoy" y en las horas pico incluso estando su restaurante en Madrid. Es una corrección, pero conviene contarlo.

## Preguntas abiertas
Ninguna.
