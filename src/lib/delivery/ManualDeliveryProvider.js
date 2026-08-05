import { DeliveryProvider, ESTADOS_DELIVERY } from './DeliveryProvider'

// Proveedor "manual": no llama a ninguna API externa. El restaurante
// organiza el envío por su cuenta (un cadete propio, una moto de
// confianza, etc.) y va actualizando el estado a mano desde Cocina o
// Mesas. Es el único de los tres que funciona hoy sin esperar ninguna
// cuenta de negocio ni credenciales — y queda como opción permanente
// para ciudades sin cobertura de Glovo/PedidosYa, no solo como relleno
// temporal.
export class ManualDeliveryProvider extends DeliveryProvider {
  async estimate({ pickup, dropoff }) {
    // No hay tarifa real que consultar: se le pide al restaurante un
    // costo de envío fijo (o ninguno) al momento de crear el pedido.
    // Se resuelve en la UI, no acá.
    return {
      quoteId: `manual-${Date.now()}`,
      price: 0,
      moneda: null,
      etaMinutes: null,
      expiresAt: null,
    }
  }

  async createDelivery({ quoteId, orderId }) {
    return {
      externalId: `manual-${orderId}`,
      estado: ESTADOS_DELIVERY.CONFIRMADO,
      trackingUrl: null,
    }
  }

  async cancelDelivery(externalId) {
    return { estado: ESTADOS_DELIVERY.CANCELADO }
  }

  parseWebhook(payload) {
    // No aplica: no hay webhooks entrantes de un proveedor manual. Los
    // cambios de estado se hacen a mano desde la UI (igual que el resto
    // de los estados de un pedido).
    throw new Error('El proveedor manual no recibe webhooks')
  }
}
