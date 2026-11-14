# Arquitectura

```
Cliente en mesa (QR) ─┐
Camarero / Cocina ────┼──► SPA React (Vercel) ──► Supabase (Postgres + RLS + RPC + Realtime + Storage)
Dueño / Superadmin ───┤                                   ▲            │
Vendedor (CRM) ───────┘                                   │            └─► Edge Functions (IA: importar/traducir carta, búsqueda CRM)
                                                          │
Cliente por WhatsApp ──► Meta WhatsApp Cloud API ──► n8n (agente take away + reservas) ──► Supabase (service_role / RPC)
```

## Multi-tenant
- Cada fila de negocio lleva `restaurant_id`. El dueño se identifica con `restaurants.user_id = auth.uid()`.
- Superadmin: tabla `superadmins` + `fn_es_superadmin()`. Vendedores del CRM: `fn_mi_vendedor_id()`.
- Personal (camarero/cocina) **no** usa Supabase Auth: corre como `anon`. Al acertar el PIN, `fn_verificar_camarero_pin` crea una **sesión de camarero** (`camarero_sesiones`, 12 horas; en la tabla solo se guarda el sha256 del token) y devuelve un token que la app guarda en memoria y envía como `p_token` (`p_camarero_token` en `fn_registrar_pedido`) a todas las RPC `fn_staff_*` / `fn_camarero_*`. Cada una llama a `fn_staff_exigir_sesion`, que comprueba token, camarero, restaurante y permisos en vivo; si la sesión no vale, error `RM401` y la app vuelve a "¿Quién eres?". "Cambiar camarero" cierra la sesión (`fn_camarero_cerrar_sesion`) y cambiar el PIN las revoca. Spec: `docs/specs/2026-11-12-pin-camarero.md`. Desde la fase 2 (migración `20261112162501`) el token es obligatorio: sin él, `RM401`.
- Cliente en mesa: anónimo; accede por el token del QR (`get_table_by_qr`, `fn_sesion_abierta_por_token`) y pide con `fn_registrar_pedido`.

## Módulos de pago
- Catálogo en `modulos`, planes en `planes`, asignación por restaurante en `restaurant_modulos`.
- Front: `useRestaurantModulos()` en `src/lib/modulos.js`. BD: p. ej. `fn_validar_modulo_pedido` (take away).

## Piezas que conviene conocer
- **Pedidos**: `orders` + `order_items` (+ `order_item_modificadores` como instantánea). `fn_registrar_pedido` inserta fila a fila para guardar los modificadores. `recalc_order_total` mantiene el total.
- **Mesa**: `table_sessions` (una visita). Los puntos de fidelización se otorgan al cerrar la sesión (`fn_otorgar_puntos_mesa`); en take away, al entregar (`fn_otorgar_puntos_fidelizacion`).
- **Fidelización**: `clientes`, `clientes_movimientos`, niveles y premios, sellos (`promos_sellos`, `clientes_sellos`), vales regalo.
- **Reservas**: web (`fn_crear_reserva_web`), WhatsApp (`fn_reserva_whatsapp_crear`, `fn_reserva_cliente_*`) y manual por el personal. Disponibilidad atómica con `fn_reserva_hay_mesa` en la hora del restaurante.
- **Webhooks salientes**: `webhooks`, `webhook_entregas`, `fn_disparar_webhooks` (firmados con HMAC).
- **WhatsApp**: `whatsapp_sessions`, `whatsapp_mensajes_procesados` (deduplicación con `fn_whatsapp_mensaje_nuevo`).
- **Delivery**: patrón adaptador en `src/lib/delivery/` (manual + stubs de Glovo y PedidosYa).

## Hora
Cada restaurante tiene su zona horaria (`restaurants.zona_horaria`, IANA, por defecto `Europe/Madrid`; spec `docs/specs/2026-11-14-zona-horaria-restaurante.md`). Solo la cambia el superadmin, con una lista corta por país (`src/lib/zonasHorarias.js`); la BD valida que sea una zona real con región y conserva la anterior si quien guarda no es superadmin.
- **Operativa del restaurante** (reservas, recogidas, menús por franja, vales, cierre de caja, pantallas del dueño, camarero y cocina, agente de WhatsApp): hora del restaurante. En la BD, `fn_ahora_restaurante(id)`, `fn_hoy_restaurante(id)` y `fn_zona_restaurante(id)`; en el front, las funciones "EnZona" de `src/lib/fechas.js` con `zonaHorariaDe(restaurante)`; en n8n, `ahoraEnZona(zonaRestaurante())`.
- **Negocio de Restomind** (pruebas gratuitas, permanencia, CRM, facturación, días y estadísticas del superadmin): hora de España (`fn_*_madrid`, `hoyMadrid`…). En el panel del superadmin, cada hora sale en España y, si el restaurante está en otra zona, con su hora local al lado (`fechaHoraConLocal`).
- Las reservas, los menús y el horario se guardan en hora "de pared" (la que dice el restaurante); los pedidos, sesiones y avisos, como instante absoluto. Nunca desfases fijos: siempre zonas IANA (`at time zone` en Postgres, `Intl` en el navegador y en n8n).
