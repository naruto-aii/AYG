let audio: AudioContext | null = null

function context() {
  if (!audio) audio = new AudioContext()
  if (audio.state === 'suspended') void audio.resume()
  return audio
}

function tone(frequency: number, duration: number, type: OscillatorType, gain: number, delay = 0) {
  const ctx = context()
  const osc = ctx.createOscillator()
  const amp = ctx.createGain()
  osc.type = type
  osc.frequency.value = frequency
  amp.gain.value = 0.0001
  osc.connect(amp)
  amp.connect(ctx.destination)
  const start = ctx.currentTime + delay
  amp.gain.exponentialRampToValueAtTime(gain, start + 0.02)
  amp.gain.exponentialRampToValueAtTime(0.0001, start + duration)
  osc.start(start)
  osc.stop(start + duration + 0.02)
}

export function playSound(kind: 'tap' | 'ok' | 'bad' | 'fanfare' | 'gem', enabled: boolean) {
  if (!enabled) return
  try {
    if (kind === 'tap') tone(520, 0.08, 'triangle', 0.05)
    if (kind === 'ok') {
      tone(523, 0.12, 'sine', 0.06)
      tone(659, 0.16, 'sine', 0.06, 0.08)
    }
    if (kind === 'bad') {
      tone(220, 0.16, 'sawtooth', 0.03)
      tone(160, 0.2, 'triangle', 0.04, 0.08)
    }
    if (kind === 'gem') tone(880, 0.18, 'triangle', 0.05)
    if (kind === 'fanfare') {
      tone(523, 0.12, 'triangle', 0.05)
      tone(659, 0.12, 'triangle', 0.05, 0.1)
      tone(784, 0.22, 'triangle', 0.06, 0.2)
    }
  } catch {
    // Audio may be blocked until a gesture. The lesson still works.
  }
}

export function speak(text: string, lang: string, enabled: boolean) {
  if (!enabled || typeof window === 'undefined' || !('speechSynthesis' in window)) return
  window.speechSynthesis.cancel()
  const utterance = new SpeechSynthesisUtterance(text)
  utterance.lang = lang
  utterance.rate = 0.86
  window.speechSynthesis.speak(utterance)
}
