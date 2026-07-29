import { DeliveryProvider } from './DeliveryProvider'

// Adaptador de Glovo — TODAVÍA NO CONECTADO a la API real.
//
// Cuando tengas cuenta de negocio y credenciales (business.glovoapp.com),
// cada método de acá abajo hace la llamada real a su Partners API y
// traduce la respuesta al formato común de DeliveryProvider. Por ahora
// tira error a propósito, para que sea imposible usarlo por accidente
// antes de estar realmente conectado.
//
// Notas para cuando se conecte (para no tener que reinvestigar todo):
// - Requiere alta como partner de negocio + tarjeta de crédito asociada.
// - Identifica cada local con un "store id" propio, que hay que enviar
//   en cada llamada.
// - Soporta tanto pedidos con repartidor de Glovo como con repartidor
//   propio del restaurante (nuestro caso siempre sería con repartidor
//   de Glovo).
export class GlovoDeliveryProvider extends DeliveryProvider {
  constructor({ apiKey, apiSecret, storeId, sandbox = true } = {}) {
    super()
    this.apiKey = apiKey
    this.apiSecret = apiSecret
    this.storeId = storeId
    this.sandbox = sandbox
  }

  async estimate({ pickup, dropoff }) {
    throw new Error('GlovoDeliveryProvider.estimate: pendiente de conectar la API real de Glovo')
  }

  async createDelivery({ quoteId, orderId, pickup, dropoff }) {
    throw new Error('GlovoDeliveryProvider.createDelivery: pendiente de conectar la API real de Glovo')
  }

  async cancelDelivery(externalId) {
    throw new Error('GlovoDeliveryProvider.cancelDelivery: pendiente de conectar la API real de Glovo')
  }

  parseWebhook(payload) {
    throw new Error('GlovoDeliveryProvider.parseWebhook: pendiente de conectar la API real de Glovo')
  }
}
