import { DeliveryProvider } from './DeliveryProvider'

// Adaptador de PedidosYa — TODAVÍA NO CONECTADO a la API real.
//
// PedidosYa expone una "Courier API" pensada exactamente para este caso:
// enviar un paquete/pedido desde un punto de recogida a un punto de
// entrega, usando su red de repartidores, sin pasar por el marketplace
// de PedidosYa. El flujo real es: pedir estimación → confirmar dentro
// del tiempo de validez de esa estimación → recibir el envío asignado.
//
// Por ahora tira error a propósito, para que sea imposible usarlo por
// accidente antes de estar realmente conectado.
export class PedidosYaDeliveryProvider extends DeliveryProvider {
  constructor({ apiKey, apiSecret, sandbox = true } = {}) {
    super()
    this.apiKey = apiKey
    this.apiSecret = apiSecret
    this.sandbox = sandbox
  }

  async estimate({ pickup, dropoff }) {
    throw new Error('PedidosYaDeliveryProvider.estimate: pendiente de conectar la API real de PedidosYa')
  }

  async createDelivery({ quoteId, orderId, pickup, dropoff }) {
    throw new Error('PedidosYaDeliveryProvider.createDelivery: pendiente de conectar la API real de PedidosYa')
  }

  async cancelDelivery(externalId) {
    throw new Error('PedidosYaDeliveryProvider.cancelDelivery: pendiente de conectar la API real de PedidosYa')
  }

  parseWebhook(payload) {
    throw new Error('PedidosYaDeliveryProvider.parseWebhook: pendiente de conectar la API real de PedidosYa')
  }
}
