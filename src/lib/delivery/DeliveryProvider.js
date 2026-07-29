// Interfaz común para cualquier proveedor de delivery a domicilio.
//
// La idea: el resto de la app (Mesa.jsx, el flujo de WhatsApp, Cocina.jsx)
// nunca habla directamente con "Glovo" o "PedidosYa" — siempre habla con
// esta interfaz. Así, agregar un proveedor nuevo (o cambiar de uno a otro
// en un país) no toca nada fuera de esta carpeta.
//
// Todos los adaptadores devuelven las MISMAS formas de datos, sin importar
// las particularidades de cada API externa — esa traducción es trabajo
// del adaptador, no de quien lo usa.

/**
 * @typedef {Object} Address
 * @property {number} lat
 * @property {number} lng
 * @property {string} label       - dirección en texto, para mostrar
 * @property {string} [details]   - piso/depto/referencias
 * @property {string} [phone]
 */

/**
 * @typedef {Object} DeliveryEstimate
 * @property {string} quoteId       - referencia de esta cotización en el proveedor
 * @property {number} price
 * @property {string} moneda
 * @property {number} etaMinutes
 * @property {string} expiresAt     - ISO timestamp; después de esto hay que volver a cotizar
 */

/**
 * @typedef {Object} DeliveryResult
 * @property {string} externalId    - id del envío ya confirmado, en el proveedor
 * @property {string} estado        - normalizado: ver ESTADOS_DELIVERY
 * @property {string} [trackingUrl]
 */

// Estados normalizados — iguales para cualquier proveedor. Cada adaptador
// traduce sus propios estados internos a uno de estos antes de devolverlo.
export const ESTADOS_DELIVERY = {
  COTIZANDO: 'cotizando',
  CONFIRMADO: 'confirmado',
  ASIGNADO: 'asignado',
  EN_CAMINO: 'en_camino',
  ENTREGADO: 'entregado',
  CANCELADO: 'cancelado',
}

/**
 * Todo adaptador de proveedor debe implementar estos 4 métodos.
 * @interface
 */
export class DeliveryProvider {
  /**
   * Pide una cotización (precio + tiempo estimado) sin confirmar nada
   * todavía. El cliente ve este precio antes de aceptar el pedido.
   * @param {{pickup: Address, dropoff: Address}} params
   * @returns {Promise<DeliveryEstimate>}
   */
  async estimate({ pickup, dropoff }) {
    throw new Error('estimate() no implementado')
  }

  /**
   * Confirma el envío real, a partir de una cotización ya pedida.
   * A partir de acá el proveedor empieza a buscar un repartidor.
   * @param {{quoteId: string, orderId: string, pickup: Address, dropoff: Address}} params
   * @returns {Promise<DeliveryResult>}
   */
  async createDelivery({ quoteId, orderId, pickup, dropoff }) {
    throw new Error('createDelivery() no implementado')
  }

  /**
   * Cancela un envío ya confirmado (por ejemplo, si el restaurante no
   * puede cumplir el pedido).
   * @param {string} externalId
   */
  async cancelDelivery(externalId) {
    throw new Error('cancelDelivery() no implementado')
  }

  /**
   * Traduce el payload crudo de un webhook del proveedor a un formato
   * normalizado. No hace ninguna llamada a la API — es una función pura.
   * @param {any} payload
   * @returns {{externalId: string, estado: string}}
   */
  parseWebhook(payload) {
    throw new Error('parseWebhook() no implementado')
  }
}
