// Avisos de fallos del agente de WhatsApp (tabla agente_errores).
// Catálogo y textos de docs/specs/2026-11-13-agente-whatsapp-revision.md
// ("Catálogo de tipos"). {tel} es el teléfono completo y {hora}, la hora del
// restaurante: la zona se recibe como parámetro (regla 7).
import { horaEnZona } from './fechas'

export const TIPOS_AVISO = {
  sin_respuesta: {
    etiqueta: 'Sin respuesta',
    visible: true,
    texto: 'Un cliente ({tel}) escribió a las {hora} y no recibió respuesta. Llámale.',
  },
  pedido_no_creado: {
    etiqueta: 'Pedido no registrado',
    visible: true,
    texto: 'Un cliente ({tel}) intentó confirmar un pedido a las {hora} y no se pudo registrar. Llámale para tomarlo.',
  },
  reserva_no_creada: {
    etiqueta: 'Reserva no guardada',
    visible: true,
    texto: 'Un cliente ({tel}) intentó reservar a las {hora} y no se pudo guardar la reserva. Llámale para confirmarla.',
  },
  reserva_no_modificada: {
    etiqueta: 'Reserva no cambiada',
    visible: true,
    texto: 'Un cliente ({tel}) intentó anular o cambiar su reserva a las {hora} y no se pudo. Revisa su reserva y llámale.',
  },
  pedido_demasiado_grande: {
    etiqueta: 'Pedido demasiado grande',
    visible: true,
    texto: 'Un cliente ({tel}) quería un pedido mayor que el máximo por WhatsApp a las {hora}. Puede que te llame.',
  },
  // Solo superadmin
  firma_invalida: { etiqueta: 'Firma no válida', visible: false, texto: 'Petición al webhook sin la firma de Meta o con una firma que no cuadra.' },
  numero_desconocido: { etiqueta: 'Número desconocido', visible: false, texto: 'Mensaje a un número de WhatsApp que no es de ningún restaurante.' },
  mensajes_multiples: { etiqueta: 'Varios mensajes', visible: false, texto: 'Aviso de Meta con varios mensajes: solo se procesó el primero.' },
  error_interno: { etiqueta: 'Error interno', visible: false, texto: 'Fallo no controlado en el workflow del agente.' },
  registro_fallido: { etiqueta: 'Registro fallido', visible: false, texto: 'No se pudo registrar un aviso con su detalle.' },
}

// Días que el dueño sigue viendo un aviso atendido (decisión 13). Es solo un
// filtro de pantalla: no se borra ninguna fila.
export const DIAS_ATENDIDAS = 30

// Instante a partir del cual se muestran las atendidas (ISO).
export function desdeAtendidas(ahora = new Date()) {
  return new Date(ahora.getTime() - DIAS_ATENDIDAS * 24 * 60 * 60 * 1000).toISOString()
}

// Teléfono guardado con fn_normalizar_telefono (solo cifras; los españoles,
// sin el 34). Devuelve el texto para mostrar y el enlace tel:.
export function telefonoAviso(tel) {
  const d = String(tel || '').replace(/\D/g, '')
  if (!d) return null
  if (/^[6789]\d{8}$/.test(d)) {
    return { texto: `+34 ${d.slice(0, 3)} ${d.slice(3, 6)} ${d.slice(6)}`, href: `tel:+34${d}` }
  }
  return { texto: `+${d}`, href: `tel:+${d}` }
}

// Texto llano del aviso según el catálogo. Si no hay teléfono se dice "sin
// teléfono" en lugar de dejar el hueco.
export function textoAviso(aviso, zona) {
  const t = TIPOS_AVISO[aviso?.tipo]
  if (!t) return `Aviso del agente de WhatsApp (${aviso?.tipo || 'sin tipo'}).`
  const tel = telefonoAviso(aviso.telefono_cliente)
  return t.texto
    .replace('{tel}', tel ? tel.texto : 'sin teléfono')
    .replace('{hora}', aviso.created_at ? horaEnZona(aviso.created_at, zona) : '--:--')
}

export function esVisibleParaRestaurante(aviso, restaurantId) {
  return !!aviso && aviso.visible_restaurante === true && aviso.restaurant_id === restaurantId
}

export const COLUMNAS_AVISO = 'id, restaurant_id, telefono_cliente, tipo, paso, visible_restaurante, veces, created_at, ultima_vez_at, atendida, atendida_por, atendida_at'
