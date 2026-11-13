> Movido de `n8n-agente-takeaway/ROADMAP_correcciones_agente.md` (fuera de git) el 13-11-2026. Las correcciones siguientes están en `docs/specs/2026-11-13-agente-whatsapp-revision.md`.

# Roadmap de correcciones — Agente WhatsApp (pedidos y reservas)

Origen: prueba de pedido takeaway del 5 nov 2026 (el bot dijo "ahora son las 23:49" cuando eran las 22:49) y análisis completo del workflow `restomind_whatsapp_agente_V02.json`.

Estado: ✅ hecho · 🧪 hecho, pendiente de probar en n8n · ⏳ pendiente

| # | Corrección | Prioridad | Dónde | Estado |
|---|---|---|---|---|
| 0 | Hora de España con zona `Europe/Madrid` (antes UTC+2 fijo) en takeaway | Crítica | n8n | ✅ |
| 1 | Reservas: no aceptar fechas/horas pasadas, validar al momento, franjas que cruzan medianoche | Crítica | n8n | ✅ |
| 2 | Disponibilidad de mesas: horas de mesas ocupadas calculadas en UTC | Alta | SQL | ✅ (staging y producción, 7 nov 2026) |
| 3 | Panel web: "hoy" calculado en UTC (falla de 00:00 a 01:00/02:00) | Media | Frontend | ✅ (producción, 7 nov 2026) |
| 4 | `current_date`/`current_time` de la base de datos en UTC (incluye menús por horario) | Alta | SQL | ✅ (staging y producción, 7 nov 2026) |
| 5 | Takeaway: confirmación explícita con total antes de crear el pedido | Alta | n8n | ✅ |
| 6 | Hora de recogida en columna propia de `orders` (hoy solo en `notas`) | Media | SQL + n8n + panel | ✅ (producción, 7 nov 2026) |
| 7 | Historial de conversación para el modelo (últimos mensajes) | Media | n8n | ✅ (8 nov 2026) |
| 8 | Reservas: no aceptar una reserva pocos minutos antes del cierre | Baja | n8n + panel | ✅ (8 nov 2026) |
| 9 | Takeaway: no pedir el teléfono (ya lo tenemos por WhatsApp) | Baja | n8n | ✅ (8 nov 2026) |
| 10 | Fidelización: normalizar el teléfono del cliente (puntos repartidos en fichas duplicadas) | Alta | SQL | ✅ (staging y producción, 7 nov 2026) |
| 11 | Menús (precios por horario/día) no se aplicaban en los pedidos de WhatsApp | Alta | SQL + n8n + panel | ✅ (producción, 8 nov 2026) |
| 12 | Un solo criterio de menú activo: `fn_registrar_pedido` usa `fn_menu_activo` | Media | SQL | ✅ (staging y producción, 8 nov 2026) |
| 13 | Reserva web pública: no comprueba el horario del restaurante (ni la última reserva) | Media | SQL + web | ✅ (producción, 8 nov 2026) |
| 14 | Mesa y Camarero no podían leer menús ni upsell (políticas del dueño evaluadas para anónimos) | Crítica | SQL | ✅ (staging y producción, 8 nov 2026) |
| 15 | Mesa y Camarero recalculan el menú activo cada minuto (no solo al abrir la carta) | Alta | Web | ✅ (producción, 8 nov 2026) |
| 16 | Cambio de tema en mitad de la conversación (pedido → reserva y al revés) | Alta | n8n | ✅ (8 nov 2026) |
| 17 | Takeaway: última recogida X minutos antes del cierre (ajuste por restaurante) | Baja | n8n + panel | 🧪 (web en producción; falta reimportar JSON y probar) |
| 18 | Takeaway: el modelo calculaba los totales (mal) y a veces mandaba el JSON crudo al cliente | Crítica | n8n | 🧪 (falta reimportar JSON y probar) |
| 19 | Reservas: escenarios reales (sí con cambios, alternativas sin fecha, reservas ya hechas) | Alta | n8n | 🧪 (falta reimportar JSON y probar) |
| 20 | Reservas por WhatsApp: sin pedir teléfono, anular/cambiar la propia reserva, grupos grandes | Alta | SQL + n8n + panel | 🧪 (en producción; probando) |
| 21 | Mensajes de WhatsApp duplicados (un "sí" procesado dos veces) | Alta | SQL + n8n | 🧪 (falta SQL, reimportar JSON y probar) |

---

## 0. Hora de España en takeaway — ✅
Estaba en "Preparar takeaway" y "Validar hora recogida". Corregido:
- `ahoraMadrid()` con `Intl` y zona `Europe/Madrid`; si `Intl` fallara, se usa la regla oficial de la UE (último domingo de marzo / octubre, 01:00 UTC). Nunca un desfase fijo.
- La hora de recogida se valida en cuanto el cliente la da (antes, solo al final).
- Franjas que cruzan la medianoche, cierre anticipado ("ya no aceptamos más pedidos hoy"), platos fuera de la carta, pedidos incompletos, fallo al guardar en Supabase, teléfono de respaldo, último mensaje del bot en el prompt, inactividad de 5 a 15 min.
- Zona horaria del workflow en ajustes: `Europe/Madrid`.

## 1. Reservas — ✅
Antes: una reserva "para hoy a las 14:00" hecha a las 20:00 (o para ayer) se aceptaba. Y "el viernes a las 00:15" se rechazaba aunque el viernes cierre a las 00:30.
- **Preparar reserva**: el modelo recibe la fecha en formato ISO, la hora actual de España y reglas para "hoy", "mañana" y la madrugada.
- **Procesar respuesta reserva**: en cuanto llegan la fecha y la hora se comprueban el formato, que no hayan pasado (con 15 min de antelación mínima) y que el restaurante abra. Si algo falla se borra el dato, se explica el motivo y se vuelve a preguntar (antes se descubría tras pedir zona, teléfono y preferencias).
- **Verificar disponibilidad**: se vuelve a comprobar si la hora ya ha pasado. Las alternativas que se ofrecen nunca son horas pasadas. Las horas de madrugada se aceptan si caen en la franja del día anterior.
- **Crear reserva Supabase**: si el cliente dice "sí" cuando la hora ya ha pasado, no se crea la reserva. Las alternativas siguen la misma regla.

**Cómo probar**: pedir reserva "para hoy" a una hora ya pasada → debe avisar al momento; "para ayer" → debe pedir otro día; día cerrado → "cerrado el …"; franja de madrugada si el restaurante la tiene.

## 2. Disponibilidad de mesas en hora de España (SQL) — ✅
`fn_reserva_hay_mesa` (la usan el agente y la creación atómica de reservas) comparaba la hora de la reserva con horas en UTC. Corregido en `sql/reserva_disponibilidad_hora_madrid.sql`:
- La hora de apertura de las mesas ocupadas, en hora de España (antes iba 1 h atrás en invierno y 2 h en verano).
- "Hoy" en hora de España (antes, entre las 00:00 y la 01:00/02:00, no se contaban las mesas ocupadas).
- Cruce de medianoche: las mesas abiertas y las reservas del día anterior bloquean las reservas de madrugada.
- Una mesa que sigue abierta más allá de la duración estimada se cuenta ocupada al menos hasta dentro de 30 minutos.
Simulado el 7 nov 2026: "mesa abierta a las 19:00 (2 pax) y reserva a las 20:45" antes salía libre y ahora sale ocupada.

## 3. "Hoy" en el panel web — ✅
`new Date().toISOString().slice(0, 10)` daba la fecha UTC. Nuevo `src/lib/fechas.js` (`hoyMadrid()`, `fechaISOMadrid()`, `partesMadrid()`, `sumarDiasISO()`) aplicado en reservas (panel, camarero y web pública), plano de mesas, vales (caducidad en panel, mesa y camarero), permanencia, trial/descuentos del superadmin y nombres de archivos exportados. Los menús por horario (`src/lib/menus.js`) usan la hora y el día de España, no los del móvil del cliente, igual que el servidor.

## 4. Fecha y hora de la base de datos en UTC — ✅
`sql/fechas_hora_madrid.sql`: `fn_hoy_madrid()`, `fn_hora_madrid()` y `fn_ahora_madrid()`, y reescritura automática de las 11 funciones que usaban `current_date`, `current_time` o `extract(dow from now())` (ensayado en producción: 16 líneas, solo esas expresiones), más el valor por defecto de `crm_tareas.vence_en`. Lo más grave: `fn_registrar_pedido` decidía el **menú activo por franja horaria y día de la semana en UTC**, de modo que el menú del mediodía empezaba y acababa 1-2 h tarde y no coincidía con lo que veía el cliente. También: vales caducados, reservas web "para ayer" de madrugada, trial, descuentos, permanencia, bajas y comisiones.
Regla: en SQL nuevo, nunca `current_date`/`current_time`; usar `fn_hoy_madrid()`/`fn_hora_madrid()`.

## 5. Confirmación del pedido con total — ✅
Antes el pedido se creaba en cuanto el modelo lo daba por completo, sin que el cliente viera el total ni dijera "sí" (detectado en la prueba del 6 nov). Ahora:
- Con platos, hora y nombre, el sistema manda el resumen con el total (calculado con los precios de la carta, nunca por el modelo) y pasa a `pendiente_confirmacion_pedido`.
- El pedido solo se crea si el cliente responde con un sí claro ("sí", "vale", "ok", "confirmo", "perfecto"…) y nada ha cambiado desde el resumen.
- Si pide un cambio ("sí, pero quita el coulant"), se aplica y se vuelve a mandar el resumen.
- Antes de crearlo se vuelve a comprobar la hora de recogida.

## 6. Hora de recogida en su propia columna — ✅
Para todos los restaurantes con takeaway (y, en el futuro, como hora de entrega a domicilio).
- `sql/hora_recogida_pedidos.sql`: `orders.hora_recogida` (timestamptz) + índice, y relleno de los pedidos existentes a partir de la nota "Recogida a las HH:MM" (ensayado en producción: 26 pedidos).
- n8n: el agente guarda fecha + hora de recogida (`"2026-11-07 21:30 Europe/Madrid"`; las recogidas pasada la medianoche quedan en el día siguiente). La nota se mantiene.
- Cocina (opción A): cada takeaway se coloca según cuándo hay que empezar a prepararlo (recogida − 20 min, ajustable con `config.takeaway_minutos_preparacion`); en la tarjeta, "🕐 Recoge a las 21:30 · en 25 min" en dorado, ámbar a ≤15 min y rojo si ya pasó la hora; se refresca cada 30 s.
- Panel → Pedidos: hora de recogida en la tabla, el CSV y la impresión.
- Orden de despliegue: SQL (staging y producción) → web → reimportar JSON (el agente escribe en la base de datos de producción).

## 7. Historial de conversación para el modelo — ✅
- "Preparar contexto" guarda en la sesión (`contexto.historial`) los últimos 10 mensajes (5 de cada lado), cada uno recortado a 400 caracteres (el primero suele llevar la carta).
- Los prompts de pedidos y reservas incluyen la "Conversación reciente" solo si hay un pedido/reserva en curso y reciente (mismo criterio que el último mensaje), así un pedido nuevo no arrastra la conversación anterior. El pedido/reserva en curso manda sobre lo dicho en el historial.
- El clasificador no recibe el historial (no lo necesita).

## 8. Última reserva antes del cierre — ✅
- Nuevo ajuste por restaurante `config.reservas_minutos_antes_cierre` (60 por defecto; 0 = hasta el cierre), en Configuración > Horarios de apertura (solo con el módulo de reservas).
- El agente (`horarioReserva` en los 4 nodos de reservas) solo acepta reservas hasta esa hora en cada turno, también en turnos que cruzan la medianoche, y lo explica: "a las 22:45 ya no admitimos reservas: la última es a las 22:30 (cerramos a las 23:30)". Las horas alternativas que propone respetan el mismo límite.

## 9. No pedir el teléfono en takeaway — ✅
- El agente ya no pregunta el teléfono: se usa el de WhatsApp (normalizado por la base de datos). Si el cliente da otro por su cuenta, se guarda ese.
- El resumen antes de confirmar muestra "📞 Teléfono: 678237019", así el cliente puede corregirlo.
- Las reservas siguen pidiendo un teléfono de contacto (decisión aparte).

## 10. Teléfono normalizado para la fidelización — ✅
Los puntos y sellos se suman cuando un pedido takeaway pasa a `entregado` y al cerrar una mesa. El cliente se identifica por `(restaurant_id, telefono)` con el texto tal cual, así que `677226644`, `34677226644` (WhatsApp) y `+34 677 22 66 44` (mesa) eran tres fichas distintas.

Solución en `sql/telefono_normalizado.sql`, todo en la base de datos:
- `fn_normalizar_telefono()`: solo dígitos, sin `00` y, en los números españoles, 9 cifras sin el `34` (el formato que ya tenían todos los datos). Los extranjeros conservan su prefijo.
- Triggers que normalizan al guardar en `clientes`, `orders` y `table_sessions`. Así el agente de WhatsApp, la mesa, Camarero y el panel quedan cubiertos sin tocar n8n ni el frontend.
- `fn_estado_fidelizacion` (consulta de puntos desde la mesa) busca con el teléfono normalizado.
- Fusión automática de las fichas duplicadas (puntos, gasto, movimientos y sellos) y normalización de lo ya guardado. A 7 nov 2026 no había duplicados ni en staging ni en producción; solo cambia 1 sesión de mesa en producción, que tenía espacios.

**Cómo probar**: en la mesa (QR), registrar el teléfono como `+34 677 22 66 44` → debe mostrar los puntos de Luis.

## 11. Menús en los pedidos de WhatsApp — ✅
El agente leía `menu_items` con el precio base: los menús (p. ej. "Viernes Nocturno", viernes 21:00-23:59, Crema catalana 5,50 → 7,00 €) se aplicaban en la mesa y en Camarero, pero no en WhatsApp. El pedido de prueba del 6 nov a las 23:36 cobró la Crema catalana a 5,50 €.
- Cada menú tiene la casilla **"Aplicar también a pedidos de WhatsApp"** (`menus.aplica_whatsapp`, por defecto desmarcada). Solo puede marcarse en menús con zona "Cualquiera" (restricción en la base de datos y casilla desactivada en el panel). Solo la ven los restaurantes con el módulo `takeaway_delivery`.
- `sql/menu_activo_takeaway.sql`: `fn_menu_activo()` (mismo criterio que la mesa: zona, franja y día en hora de España; gana el más específico) y `fn_carta_takeaway()` (carta con los precios del menú activo entre los marcados para WhatsApp, sin los platos excluidos).
- n8n: "Leer carta takeaway" y "Leer carta Supabase" (respuesta a "¿qué tenéis?") usan `fn_carta_takeaway`. Cada plato se cobra al precio del menú vigente cuando se añadió, y el resumen y el pedido final coinciden aunque cambie el menú entre medias. El prompt indica qué menú está vigente.
- Pendiente opcional: que `fn_registrar_pedido` use también `fn_menu_activo()` para tener el criterio en un solo sitio.

## 12. Un solo criterio de menú activo — ✅
`fn_registrar_pedido` (pedidos de mesa) tenía su propia copia de las reglas de menú. `sql/menu_activo_unico.sql` sustituye ese bloque por `fn_menu_activo(...)` (comprueba que el bloque sea exactamente el esperado; si no, no toca nada). Comparado en producción: 0 diferencias en 1.680 casos (semana completa cada 30 min, todas las zonas). La web (`src/lib/menus.js`) sigue calculando el menú para mostrar los precios; lo que se cobra lo decide la base de datos.

## 13. Reserva web pública sin comprobar horario — ✅
`fn_crear_reserva_web` y `Reservar.jsx` solo comprobaban que la fecha no fuese pasada: se podía reservar a cualquier hora, incluso con el restaurante cerrado.
- `sql/reserva_web_horario.sql`: `fn_reserva_fuera_de_horario()` (mismo criterio que `horarioReserva` del agente: franjas, madrugada de la franja del día anterior, última reserva con `reservas_minutos_antes_cierre`; sin horario configurado no se comprueba) y `fn_crear_reserva_web` la usa, además de exigir 15 min de antelación para hoy. Probado en staging con el horario de Casa Montiel: 13 casos, mismos resultados que el agente.
- Formulario (`src/lib/horarioReservas.js`): la hora es un desplegable con las horas válidas del día (cada 15 min, más la última exacta, p. ej. 22:50); avisa si ese día está cerrado o ya no quedan horas. Sin horario configurado, hora libre como antes.
- Agente: sin horario configurado ya no responde "cerrado" todos los días (mismo criterio que la web y el takeaway).

## 17. Última recogida antes del cierre (takeaway) — 🧪
- Ajuste por restaurante `config.takeaway_minutos_antes_cierre` (0 por defecto = hasta el cierre, ningún restaurante nota cambios), en Configuración > Horarios de apertura (solo con el módulo `takeaway_delivery`).
- El agente (Preparar takeaway, Procesar respuesta takeaway, Validar hora recogida) solo ofrece y acepta recogidas hasta esa hora en cada turno, también en los que cruzan la medianoche: "A las 23:20 ya no aceptamos pedidos para recoger: la última recogida es a las 23:00 (cerramos a las 23:30)". Si ya no queda tiempo en el día, "por hoy ya no podemos aceptar más pedidos".

## 14. Políticas del dueño evaluadas para anónimos — ✅
Desde `sql/fix_seguridad_anon_columnas.sql` (8 sep 2026) el rol anónimo no puede leer `restaurants.user_id`. Las políticas `*_dueno` de 16 tablas (13 en staging) estaban declaradas para todos los roles y consultan esa columna: para el anónimo daban "permission denied for table restaurants" y anulaban toda la lectura, aunque la política pública la permitiera. Afecta cuando la política pública tiene condición: la mesa y Camarero no veían **los menús ni el upsell** (modificadores y traducciones, con política pública `true`, sí funcionaban). Detectado el 8 nov 2026 con "Menu Noche Domingo" (staging), consultando la API con la clave pública.
`sql/politicas_dueno_solo_authenticated.sql`: esas políticas pasan a `to authenticated` (para el anónimo nunca daban acceso, comparan con `auth.uid()`). Regla para tablas nuevas: políticas con `auth.uid()` o que consulten `restaurants`, siempre `to authenticated`.

## 15. Menú activo recalculado cada minuto — ✅
La mesa y Camarero resolvían el menú una sola vez al abrir la carta: con la mesa abierta antes de las 20:00, a las 20:10 seguían mostrando la carta normal mientras `fn_registrar_pedido` cobraba el menú. Ahora cada minuto se vuelve a resolver (sin peticiones) y, si cambia, se recarga la carta.

## 16. Cambio de tema en mitad de la conversación — ✅
Con un pedido en curso, "quiero una reserva para 4 hoy a las 23:20" iba al agente de pedidos (la conversación activa se salta el clasificador), y al pasar luego a reservas se perdían los datos. Ahora "Combinar con sesión" detecta el cambio (palabras de reserva sin palabras de pedido, o al revés), cierra la conversación anterior y manda el mensaje completo directamente al otro agente (`intencion_forzada`), que extrae personas, día y hora. Además, el agente de pedidos nunca dice qué servicios ofrece o no el restaurante, y si le piden una reserva la deriva. Probado el 8 nov 2026.

## 18. Importes y JSON en takeaway — 🧪
Prueba del 9 nov: tras cambiar una merluza por un secreto el modelo dijo "el total sigue siendo 166,50€" (eran 167,00€) y, al pedirle revisar la cuenta, escribió texto antes del JSON, el parseo falló y el cliente recibió el JSON crudo.
- Las llamadas al modelo (takeaway y reservas) usan salida estructurada (`output_config.format` con un esquema JSON): la API garantiza un JSON válido. Además, si aun así viniera texto alrededor, se aísla el JSON, y nunca se manda el texto crudo. Si la API falla, el flujo sigue (reintento + mensaje "¿me lo repites?") en lugar de quedarse callado.
- El modelo ya no escribe importes ni enumera el pedido: cuando cambian los platos o el cliente pregunta la cuenta, el sistema añade "🧾 Tu pedido" con las líneas y el total calculados con los precios de la carta. Si el modelo pone un importe igualmente, esa frase se quita.
- `items` es siempre el pedido completo (añadir, quitar, cambiar cantidades, sustituir con nota); el emoji sale de la carta.
- Con el resumen final enviado: un cambio (o "¿cuánto es?") vuelve a mandar el resumen con el nuevo total; una pregunta suelta se responde y se sigue esperando la confirmación (antes se perdía y había que confirmar dos veces).
- Solo pedidos para hoy y para recoger: "para mañana a las 14" ya no se guarda como las 14:00 de hoy. "Nada más / eso es todo" no es cancelar.
- Simulado con el código real del nodo: 10 escenarios (incluida la captura).

## 19. Reservas: escenarios reales — 🧪
- Con el resumen enviado, un "sí" crea la reserva aunque el modelo dude; "sí, pero para 6" o "mejor a las 22" vuelve a comprobar disponibilidad y manda un resumen nuevo (antes podía crearla sin que el cliente viera el cambio); un "no" nunca la crea.
- Sin mesa libre: se mantiene la fecha (antes se borraba y "la de las 22" perdía el día) y el mensaje usa la fecha legible ("el viernes, 4 de diciembre") en vez de "2026-12-04".
- El agente no puede ver, cambiar ni cancelar reservas ya hechas: ahora lo dice y remite al restaurante (antes podía decir "hemos cancelado" sin cancelar nada).
- `personas` siempre entero; zona con 📍.
- Las tres decisiones pendientes se hicieron en el punto 20.

## 20. Reservas: teléfono, anular/cambiar y grupos — 🧪
- **Teléfono**: ya no se pregunta; se usa el de WhatsApp (la reserva ya se guardaba con él) y aparece en el resumen ("📞 Teléfono"). Si el cliente da otro, se guarda en las notas como antes.
- **Anular / cambiar la propia reserva**: `sql/reservas_cliente_whatsapp.sql` (`fn_reserva_contexto_cliente`, `fn_reserva_cliente_cancelar`, `fn_reserva_cliente_modificar`; solo con la clave de servicio). El cliente se identifica por su número de WhatsApp (normalizado, también encuentra las hechas en la web o el panel con ese teléfono). El agente ve sus próximas reservas; si tiene varias pregunta cuál; siempre pide confirmación ("¿Confirmas que anulo...?" / "Antes… Ahora… ¿Confirmo el cambio?", estados `pendiente_anulacion` / `pendiente_modificacion`). Un cambio comprueba horario, antelación y mesa libre sin contar la propia reserva, bajo el mismo bloqueo que la creación. Anular deja la reserva en `cancelada` (el panel ya la muestra así); las dos acciones quedan anotadas en las notas de la reserva. Probado en staging dentro de una transacción deshecha: 11 comprobaciones.
- **Grupos grandes**: por WhatsApp se reservan grupos hasta `config.reservas_max_personas` o, si está vacío, la capacidad de la mesa más grande (Casa Montiel: 6). Para más: "Para grupos de más de 6 personas preferimos organizarlo directamente contigo: llámanos al … y te buscamos la mejor mesa". El teléfono es `config.telefono_reservas` (Configuración > Horarios); sin él, "contacta directamente con el restaurante".
- Simulado con el código real del nodo: 12 escenarios de anular/cambiar/grupos + los 6 anteriores.
- **Prueba del 9 nov (falló)**: "para 8 el viernes a las 21" → el modelo, que veía el límite (7), negoció él ("¿reservamos para 7 y el octavo lo gestionas tú?"), guardó 7 personas y "el viernes" como el día 15 (domingo); y al pedir el teléfono dijo "búscalo en Google" aunque estaba configurado. Corregido:
  - El modelo ya no ve el límite: copia el número exacto y el sistema da el aviso de grupo (sin proponer reservar para menos).
  - Personas y día también se sacan del texto del cliente ("para 8", "somos ocho", "8 personas"; "hoy", "esta noche", "mañana", "pasado mañana", "el viernes") y mandan sobre el modelo. No se tocan "2 adultos y 2 niños", "el viernes 20", "el 21 de noviembre" ni "para las 21".
  - El prompt lleva un calendario de los próximos 21 días (fecha = día de la semana) y el teléfono del restaurante (o la orden de no inventar cómo contactar).
  - Simulado: 10 frases nuevas + las 18 anteriores.

## 21. Mensajes duplicados — 🧪
Prueba del 9 nov: el "sí" que confirmaba la reserva de Horacio llegó dos veces. La primera creó la reserva (solo una, bien) y la segunda, ya sin reserva en curso, hizo contestar al agente "Veo que ya tienes una reserva... ¿quieres modificarla?".
- `sql/whatsapp_mensajes_duplicados.sql`: tabla `whatsapp_mensajes_procesados` + `fn_whatsapp_mensaje_nuevo(wamid)` (true la primera vez, false las siguientes; guarda 3 días; solo clave de servicio).
- "Extraer mensaje y contexto" la llama con el id del mensaje (wamid) y descarta los repetidos (van a "Ignorar"). Si la llamada falla, el mensaje se procesa igual.
- Además, justo después de confirmar/cambiar/anular una reserva, un "sí", "vale" o "gracias" suelto recibe "¡Gracias a ti! Si necesitas cualquier otra cosa, aquí estoy." en vez de reabrir la conversación.

---

## Que no vuelva a pasar con el cambio de hora
- **Regla**: nunca sumar un desfase fijo a UTC. En n8n, siempre `ahoraMadrid()`. En SQL, `at time zone 'Europe/Madrid'`. En el frontend, `Intl` con `timeZone: 'Europe/Madrid'`.
- **Comprobación automática**: `python3 n8n-agente-takeaway/comprobar_hora_espana.py` revisa todos los Code nodes buscando desfases fijos y prueba `ahoraMadrid()` en los próximos cambios de hora, tanto con `Intl` como con el respaldo de la UE. Ejecutarlo antes de cada importación en n8n.
- **Recordatorio**: probar el agente después de cada cambio de hora: **28 mar 2027** y **31 oct 2027**.
- Copias del workflow: `..._BACKUP_pre_hora_madrid_20261105.json` (antes de los puntos 0 y 1).
