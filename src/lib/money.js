// Formato de dinero centralizado — así ningún componente vuelve a tener un
// "€" escrito a mano. Cuando un restaurante se da de alta en otro país con
// otra moneda, alcanza con que esta función lo sepa; no hay que tocar cada
// pantalla que muestra un precio.

// Mapeo moneda -> locale, elegido para que el separador decimal y la
// posición del símbolo salgan naturales para ese mercado (todos son
// variantes en español, ya que tus clientes son de habla hispana).
const LOCALE_POR_MONEDA = {
  EUR: 'es-ES',
  USD: 'en-US',
  MXN: 'es-MX',
  ARS: 'es-AR',
  COP: 'es-CO',
  CLP: 'es-CL',
  PEN: 'es-PE',
}

/**
 * Formatea un monto según la moneda del restaurante.
 * @param {number|string} amount - monto a formatear (ej. 21 o "21.00")
 * @param {string} currencyCode - código ISO 4217 (ej. "EUR", "MXN")
 * @returns {string} ej. "21,00 €" o "$21.00" o "$21,00" según la moneda
 */
export function formatMoney(amount, currencyCode = 'EUR') {
  const monto = typeof amount === 'string' ? parseFloat(amount) : amount
  const valor = Number.isFinite(monto) ? monto : 0
  const locale = LOCALE_POR_MONEDA[currencyCode] || 'es-ES'

  try {
    return new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: currencyCode,
    }).format(valor)
  } catch {
    // Por si llega un código de moneda no soportado por Intl (no debería
    // pasar si se respeta el check de la base), fallback simple.
    return `${valor.toFixed(2)} ${currencyCode}`
  }
}

/**
 * Devuelve solo el símbolo de la moneda (ej. "€", "$"), útil para labels de
 * formulario donde no hay un monto todavía para formatear.
 */
export function getCurrencySymbol(currencyCode = 'EUR') {
  const locale = LOCALE_POR_MONEDA[currencyCode] || 'es-ES'
  try {
    const parts = new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: currencyCode,
    }).formatToParts(0)
    return parts.find(p => p.type === 'currency')?.value || currencyCode
  } catch {
    return currencyCode
  }
}
