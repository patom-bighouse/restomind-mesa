// Sonidos de aviso para el panel (Cocina, Mesas).
// Usa Web Audio API con varios armónicos superpuestos para simular
// el timbre real de una campanilla (no un simple beep de sintetizador),
// con volumen y frecuencias pensadas para cortar el ruido ambiente
// de un restaurante.

let audioCtx = null

function getCtx() {
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext
    if (!Ctx) return null
    if (!audioCtx) {
      audioCtx = new Ctx()
      // Compresor de rango dinámico: permite subir el volumen general
      // sin que los armónicos se saturen o distorsionen al sumarse.
      const compressor = audioCtx.createDynamicsCompressor()
      compressor.threshold.value = -12
      compressor.knee.value = 20
      compressor.ratio.value = 4
      compressor.attack.value = 0.003
      compressor.release.value = 0.25
      compressor.connect(audioCtx.destination)
      audioCtx._master = compressor
    }
    // Los navegadores suspenden el audio hasta la primera interacción
    // del usuario con la página; esto lo reactiva si hace falta.
    if (audioCtx.state === 'suspended') {
      audioCtx.resume().catch(() => {})
    }
    return audioCtx
  } catch (e) {
    return null
  }
}

// Una campana real no es un tono puro: es un fundamental + varios
// armónicos (parciales) que decaen a distinta velocidad. Estas
// proporciones (ratio) y tiempos de decaimiento (decay) son los que
// le dan el carácter de "campanilla" en vez de "beep".
const BELL_PARTIALS = [
  { ratio: 1,    gain: 1.0,  decay: 1.1 },
  { ratio: 2.01, gain: 0.55, decay: 0.85 },
  { ratio: 3.0,  gain: 0.3,  decay: 0.55 },
  { ratio: 4.2,  gain: 0.16, decay: 0.32 },
]

/**
 * Debe llamarse una vez, desde un handler de interacción real del
 * usuario (click/tap), apenas se monta la pantalla. Los navegadores
 * bloquean el audio hasta que hay una interacción genuina; si el
 * primer sonido que se intenta reproducir llega por un evento async
 * (como un aviso de Realtime), el navegador lo silencia sin avisar.
 * Llamar esto temprano "desbloquea" el audio para esos casos.
 */
export function unlockAudio() {
  getCtx()
}

function strikeBell(freq, volume, startTime = 0) {
  try {
    const ctx = getCtx()
    if (!ctx) return
    const now = ctx.currentTime + startTime
    BELL_PARTIALS.forEach(p => {
      const osc = ctx.createOscillator()
      osc.type = 'sine'
      osc.frequency.value = freq * p.ratio
      const gain = ctx.createGain()
      gain.gain.setValueAtTime(0, now)
      gain.gain.linearRampToValueAtTime(volume * p.gain, now + 0.006)
      gain.gain.exponentialRampToValueAtTime(0.0001, now + p.decay)
      osc.connect(gain)
      gain.connect(ctx._master)
      osc.start(now)
      osc.stop(now + p.decay + 0.05)
    })
  } catch (e) {}
}

/** Campanita de dos notas ascendente — aviso de pedido nuevo. */
export function playNewOrderChime() {
  strikeBell(1046.5, 0.5, 0)      // C6
  strikeBell(1318.5, 0.55, 0.16)  // E6
}

/** Campana de servicio, doble toque agudo — llamada de camarero. */
export function playWaiterBell() {
  strikeBell(1567.98, 0.62, 0)    // G6
  strikeBell(1567.98, 0.62, 0.32)
}
