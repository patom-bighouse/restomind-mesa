import { ManualDeliveryProvider } from './ManualDeliveryProvider'
import { GlovoDeliveryProvider } from './GlovoDeliveryProvider'
import { PedidosYaDeliveryProvider } from './PedidosYaDeliveryProvider'

// ============================================================================
// IMPORTANTE — dónde puede vivir este archivo
// ============================================================================
// Este factory, y los adaptadores de Glovo/PedidosYa en particular, NO
// PUEDEN ejecutarse en el navegador del cliente una vez que tengan
// credenciales reales. Cualquier variable de entorno con prefijo VITE_
// queda empaquetada en el JS que se descarga al celular del comensal —
// visible para cualquiera con las herramientas de desarrollador abiertas.
//
// Cuando se conecte una API real, este código debe correr en un lugar con
// acceso seguro a esas claves: una Supabase Edge Function, o el propio
// workflow de n8n (que ya maneja lógica de negocio protegida). El
// ManualDeliveryProvider es la única excepción — no tiene credenciales,
// así que no importa desde dónde se llame.
// ============================================================================

// Qué proveedor corresponde a cada país. Un mismo país podría tener el
// suyo cambiado más adelante sin tocar nada fuera de este archivo.
// 'manual' en todos por ahora: ni Glovo ni PedidosYa están conectados
// todavía (ver esa nota en cada adaptador). Cuando se conecte uno de
// verdad, alcanza con cambiar la entrada correspondiente acá.
const PROVEEDOR_POR_PAIS = {
  ES: 'manual', // -> 'glovo' cuando se conecte
  MX: 'manual',
  AR: 'manual', // -> 'pedidosya' cuando se conecte
  CO: 'manual',
  CL: 'manual',
  PE: 'manual',
  US: 'manual',
}

/**
 * Devuelve la instancia del proveedor de delivery que corresponde a un
 * restaurante, según su país.
 *
 * `credenciales` se recibe por parámetro en vez de leerse de variables de
 * entorno del cliente — quien llame a esta función desde un contexto
 * seguro (Edge Function / n8n) es responsable de proveerlas desde SU
 * propio entorno protegido, no desde el navegador.
 *
 * @param {string} paisCode - código ISO del restaurante (ej. "ES", "MX")
 * @param {object} [credenciales] - claves del proveedor, provistas por el caller seguro
 * @returns {import('./DeliveryProvider').DeliveryProvider}
 */
export function getDeliveryProvider(paisCode, credenciales = {}) {
  const nombre = PROVEEDOR_POR_PAIS[paisCode] || 'manual'

  switch (nombre) {
    case 'glovo':
      return new GlovoDeliveryProvider(credenciales)
    case 'pedidosya':
      return new PedidosYaDeliveryProvider(credenciales)
    case 'manual':
    default:
      return new ManualDeliveryProvider()
  }
}
