// Validación básica de IBAN: formato general + checksum (algoritmo mod-97
// del estándar ISO 7064). No sustituye la verificación real que hace el
// banco al procesar una transferencia, pero atrapa errores de tipeo antes
// de guardar el dato.

export function isValidIban(raw) {
  if (!raw) return false
  const iban = raw.replace(/\s+/g, '').toUpperCase()

  if (!/^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$/.test(iban)) return false

  // Mueve los primeros 4 caracteres al final, y convierte cada letra a su
  // valor numérico (A=10, B=11, ..., Z=35), tal como pide el estándar.
  const reordenado = iban.slice(4) + iban.slice(0, 4)
  const numerico = reordenado.replace(/[A-Z]/g, (c) => (c.charCodeAt(0) - 55).toString())

  // mod 97 de un número potencialmente enorme, procesado en bloques para
  // no perder precisión con Number.
  let resto = 0
  for (let i = 0; i < numerico.length; i += 7) {
    resto = Number(String(resto) + numerico.substring(i, i + 7)) % 97
  }
  return resto === 1
}

export function formatIbanDisplay(raw) {
  const iban = (raw || '').replace(/\s+/g, '').toUpperCase()
  return iban.replace(/(.{4})/g, '$1 ').trim()
}
