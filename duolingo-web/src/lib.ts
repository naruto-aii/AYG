export function todayKey(date = new Date()) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

export function shiftDay(days: number, date = new Date()) {
  const next = new Date(date)
  next.setDate(next.getDate() + days)
  return todayKey(next)
}

export function usernameFrom(name: string) {
  const ascii = name
    .normalize('NFKC')
    .replace(/[^a-zA-Z0-9]/g, '')
    .toLowerCase()
  const base = (ascii || 'learner').slice(0, 12)
  return `${base}${Math.floor(10 + Math.random() * 90)}`
}

export function wave(index: number, amplitude: number) {
  const seq = [0, 0.55, 1, 0.55, 0, -0.55, -1, -0.55]
  return seq[index % seq.length] * amplitude
}

export function shuffle<T>(list: T[]) {
  const copy = [...list]
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1))
    const tmp = copy[i]
    copy[i] = copy[j]
    copy[j] = tmp
  }
  return copy
}

export function formatLeft(ms: number) {
  const total = Math.max(0, Math.ceil(ms / 1000))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  if (hours > 0) return `${hours}時間${minutes}分`
  return `${minutes}分`
}

export function praise() {
  const lines = ['正解！', 'すごい！', 'その調子！', 'ばっちり！']
  return lines[Math.floor(Math.random() * lines.length)]
}
