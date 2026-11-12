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
- Personal (camarero/cocina) **no** usa Supabase Auth: corre como `anon`. Al acertar el PIN, `fn_verificar_camarero_pin` crea una **sesión de camarero** (`camarero_sesiones`, 12 horas; en la tabla solo se guarda el sha256 del token) y devuelve un token que la app guarda en memoria y envía como `p_token` (`p_camarero_token` en `fn_registrar_pedido`) a todas las RPC `fn_staff_*` / `fn_camarero_*`. Cada una llama a `fn_staff_exigir_sesion`, que comprueba token, camarero, restaurante y permisos en vivo; si la sesión no vale, error `RM401` y la app vuelve a "¿Quién eres?". "Cambiar camarero" cierra la sesión (`fn_camarero_cerrar_sesion`) y cambiar el PIN las revoca. Spec: `docs/specs/2026-11-12-pin-camarero.md`. Mientras solo esté la fase 1, una llamada sin token (versión vieja de la app) se acepta con la comprobación de antes y queda anotada en `camarero_llamadas_sin_token`.
- Cliente en mesa: anónimo; accede por el token del QR (`get_table_by_qr`, `fn_sesion_abierta_por_token`) y pide con `fn_registrar_pedido`.

## Módulos de pago
- Catálogo en `modulos`, planes en `planes`, asignación por restaurante en `restaurant_modulos`.
- Front: `useRestaurantModulos()` en `src/lib/modulos.js`. BD: p. ej. `fn_validar_modulo_pedido` (take away).

## Piezas que conviene conocer
- **Pedidos**: `orders` + `order_items` (+ `order_item_modificadores` como instantánea). `fn_registrar_pedido` inserta fila a fila para guardar los modificadores. `recalc_order_total` mantiene el total.
- **Mesa**: `table_sessions` (una visita). Los puntos de fidelización se otorgan al cerrar la sesión (`fn_otorgar_puntos_mesa`); en take away, al entregar (`fn_otorgar_puntos_fidelizacion`).
- **Fidelización**: `clientes`, `clientes_movimientos`, niveles y premios, sellos (`promos_sellos`, `clientes_sellos`), vales regalo.
- **Reservas**: web (`fn_crear_reserva_web`), WhatsApp (`fn_reserva_whatsapp_crear`, `fn_reserva_cliente_*`) y manual por el personal. Disponibilidad atómica con `fn_reserva_hay_mesa` en hora de Madrid.
- **Webhooks salientes**: `webhooks`, `webhook_entregas`, `fn_disparar_webhooks` (firmados con HMAC).
- **WhatsApp**: `whatsapp_sessions`, `whatsapp_mensajes_procesados` (deduplicación con `fn_whatsapp_mensaje_nuevo`).
- **Delivery**: patrón adaptador en `src/lib/delivery/` (manual + stubs de Glovo y PedidosYa).

## Hora
Hoy todo lo que es "hoy" o "a qué hora" se calcula en hora de España (`fn_*_madrid`, `src/lib/fechas.js`). Es correcto para restaurantes de la península y Baleares, pero no para Canarias ni otros países: pendiente la zona horaria por restaurante (ver `BACKLOG.md`).
