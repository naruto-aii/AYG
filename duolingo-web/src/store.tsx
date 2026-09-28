import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { findPathNode, findPractice, lessonXp } from './data'
import { shiftDay, todayKey, usernameFrom } from './lib'
import type { LessonNode, Persisted, User } from './types'

const KEY = 'ayg-lingo-ui-v1'
const HEART_MS = 4 * 60 * 60 * 1000

function blank(): Persisted {
  return {
    user: null,
    accounts: [],
    reason: '',
    dailyGoal: 10,
    xp: 0,
    weekXp: 0,
    gems: 50,
    hearts: 5,
    heartAt: Date.now(),
    super: false,
    streak: 0,
    lastActive: null,
    freezes: 0,
    boostUntil: 0,
    completed: [],
    chests: [],
    lessonsToday: 0,
    xpToday: 0,
    perfectToday: 0,
    day: todayKey(),
    totalLessons: 0,
    totalPerfect: 0,
    purchases: 0,
    sound: true,
    notifications: true,
    following: [],
    questClaimed: null,
    pending: null,
  }
}

function rollDay(state: Persisted): Persisted {
  const day = todayKey()
  if (state.day === day) return state
  return { ...state, day, lessonsToday: 0, xpToday: 0, perfectToday: 0 }
}

function regen(state: Persisted): Persisted {
  if (state.super || state.hearts >= 5) return { ...state, hearts: state.super ? 5 : state.hearts }
  const gained = Math.floor((Date.now() - state.heartAt) / HEART_MS)
  if (gained <= 0) return state
  const hearts = Math.min(5, state.hearts + gained)
  return {
    ...state,
    hearts,
    heartAt: hearts >= 5 ? Date.now() : state.heartAt + gained * HEART_MS,
  }
}

function sanitize(raw: Partial<Persisted>): Persisted {
  const base = blank()
  return regen(
    rollDay({
      ...base,
      ...raw,
      accounts: Array.isArray(raw.accounts) ? raw.accounts : [],
      completed: Array.isArray(raw.completed) ? raw.completed : [],
      chests: Array.isArray(raw.chests) ? raw.chests : [],
      following: Array.isArray(raw.following) ? raw.following : [],
      user: raw.user ?? null,
      pending: raw.pending ?? null,
    }),
  )
}

function load(): Persisted {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return blank()
    return sanitize(JSON.parse(raw) as Partial<Persisted>)
  } catch {
    return blank()
  }
}

export type LessonResult = {
  xp: number
  increased: boolean
  streak: number
  perfect: boolean
}

type Store = {
  state: Persisted
  setPending: (pending: Persisted['pending']) => void
  register: (input: { name: string; email: string; password: string }) => string | null
  login: (email: string, password: string) => string | null
  continueAsGuest: (name: string) => void
  logout: () => void
  loseHeart: () => number
  finishLesson: (nodeId: string, correct: number, total: number) => LessonResult | null
  openChest: (nodeId: string) => number
  buy: (itemId: 'freeze' | 'hearts' | 'boost') => string | null
  activateSuper: () => void
  toggleFollow: (id: string) => void
  setSound: (sound: boolean) => void
  setNotifications: (notifications: boolean) => void
  setDailyGoal: (minutes: number) => void
  setName: (name: string) => void
  claimQuest: () => boolean
  resetAll: () => void
}

const StoreContext = createContext<Store | null>(null)

export function StoreProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<Persisted>(load)
  const ref = useRef(state)
  ref.current = state

  useEffect(() => {
    localStorage.setItem(KEY, JSON.stringify(state))
  }, [state])

  const api = useMemo<Store>(() => {
    const commit = (recipe: (current: Persisted) => Persisted) => {
      const next = recipe(regen(rollDay(ref.current)))
      ref.current = next
      setState(next)
      return next
    }

    return {
      state,
      setPending: (pending) => commit((current) => ({ ...current, pending })),
      register: ({ name, email, password }) => {
        const current = regen(rollDay(ref.current))
        const normalized = email.trim().toLowerCase()
        if (!name.trim()) return '名前を入力してください'
        if (!normalized.includes('@')) return 'メールアドレスの形を確認してください'
        if (password.length < 6) return 'パスワードは6文字以上にしてください'
        if (current.accounts.some((account) => account.email === normalized)) {
          return 'このメールアドレスはすでに使われています'
        }
        const username = usernameFrom(name)
        const joined = todayKey()
        const user: User = { name: name.trim(), username, email: normalized, joined }
        commit((snapshot) => ({
          ...snapshot,
          user,
          reason: snapshot.pending?.reason || snapshot.reason,
          dailyGoal: snapshot.pending?.dailyGoal || snapshot.dailyGoal,
          pending: null,
          accounts: [
            ...snapshot.accounts,
            { email: normalized, password, name: user.name, username, joined },
          ],
        }))
        return null
      },
      login: (email, password) => {
        const current = regen(rollDay(ref.current))
        const normalized = email.trim().toLowerCase()
        const account = current.accounts.find((item) => item.email === normalized)
        if (!account || account.password !== password) return 'メールアドレスかパスワードが違います'
        commit((snapshot) => ({
          ...snapshot,
          user: {
            name: account.name,
            username: account.username,
            email: account.email,
            joined: account.joined,
          },
        }))
        return null
      },
      continueAsGuest: (name) => {
        const clean = name.trim() || 'ゲスト'
        const username = usernameFrom(clean)
        commit((current) => ({
          ...current,
          user: { name: clean, username, email: '', joined: todayKey() },
          reason: current.pending?.reason || current.reason,
          dailyGoal: current.pending?.dailyGoal || current.dailyGoal,
          pending: null,
        }))
      },
      logout: () => commit((current) => ({ ...current, user: null })),
      loseHeart: () => {
        const next = commit((current) => {
          if (current.super) return current
          const hearts = Math.max(0, current.hearts - 1)
          return {
            ...current,
            hearts,
            heartAt: current.hearts >= 5 ? Date.now() : current.heartAt,
          }
        })
        return next.super ? 5 : next.hearts
      },
      finishLesson: (nodeId, correct, total) => {
        const practice = findPractice(nodeId)
        const found = findPathNode(nodeId)
        const node: LessonNode | null =
          practice ?? (found && found.node.kind !== 'chest' ? found.node : null)
        if (!node) return null
        const before = regen(rollDay(ref.current))
        const already = before.completed.includes(nodeId)
        const perfect = total > 0 && correct === total
        let xp = lessonXp(node, already)
        if (perfect) xp += 5
        if (before.boostUntil > Date.now()) xp *= 2
        const day = todayKey()
        let streak = before.streak
        let freezes = before.freezes
        let increased = false
        if (before.lastActive !== day) {
          increased = true
          if (before.lastActive === shiftDay(-1)) streak = before.streak + 1
          else if (before.lastActive === shiftDay(-2) && before.freezes > 0) {
            streak = before.streak + 1
            freezes -= 1
          } else streak = 1
        }
        commit((current) => ({
          ...current,
          xp: current.xp + xp,
          weekXp: current.weekXp + xp,
          xpToday: current.xpToday + xp,
          lessonsToday: current.lessonsToday + 1,
          perfectToday: current.perfectToday + (perfect ? 1 : 0),
          totalLessons: current.totalLessons + 1,
          totalPerfect: current.totalPerfect + (perfect ? 1 : 0),
          completed:
            practice || current.completed.includes(nodeId)
              ? current.completed
              : [...current.completed, nodeId],
          hearts: practice ? Math.min(5, current.hearts + 1) : current.hearts,
          streak: current.lastActive === day ? current.streak : streak,
          freezes,
          lastActive: day,
        }))
        return {
          xp,
          increased,
          streak: before.lastActive === day ? before.streak : streak,
          perfect,
        }
      },
      openChest: (nodeId) => {
        const found = findPathNode(nodeId)
        if (!found || found.node.kind !== 'chest') return 0
        if (ref.current.chests.includes(nodeId)) return 0
        const gems = found.node.gems
        commit((current) =>
          current.chests.includes(nodeId)
            ? current
            : { ...current, gems: current.gems + gems, chests: [...current.chests, nodeId] },
        )
        return gems
      },
      buy: (itemId) => {
        const price = itemId === 'freeze' ? 200 : itemId === 'hearts' ? 350 : 100
        const current = regen(rollDay(ref.current))
        if (current.gems < price) return '宝石が足りません'
        if (itemId === 'freeze' && current.freezes >= 2) return 'フリーズは2個まで所持できます'
        if (itemId === 'hearts' && (current.hearts >= 5 || current.super)) return 'ハートは満タンです'
        commit((snapshot) => {
          if (snapshot.gems < price) return snapshot
          const next = { ...snapshot, gems: snapshot.gems - price, purchases: snapshot.purchases + 1 }
          if (itemId === 'freeze') next.freezes = Math.min(2, snapshot.freezes + 1)
          if (itemId === 'hearts') {
            next.hearts = 5
            next.heartAt = Date.now()
          }
          if (itemId === 'boost') {
            const start = Math.max(Date.now(), snapshot.boostUntil)
            next.boostUntil = start + 15 * 60 * 1000
          }
          return next
        })
        return null
      },
      activateSuper: () =>
        commit((current) => ({ ...current, super: true, hearts: 5, heartAt: Date.now() })),
      toggleFollow: (id) =>
        commit((current) => ({
          ...current,
          following: current.following.includes(id)
            ? current.following.filter((item) => item !== id)
            : [...current.following, id],
        })),
      setSound: (sound) => commit((current) => ({ ...current, sound })),
      setNotifications: (notifications) => commit((current) => ({ ...current, notifications })),
      setDailyGoal: (minutes) => commit((current) => ({ ...current, dailyGoal: minutes })),
      setName: (name) =>
        commit((current) =>
          current.user
            ? { ...current, user: { ...current.user, name: name.trim() || current.user.name } }
            : current,
        ),
      claimQuest: () => {
        const current = regen(rollDay(ref.current))
        const ready = current.xpToday >= 20 && current.lessonsToday >= 2 && current.perfectToday >= 1
        if (!ready || current.questClaimed === current.day) return false
        commit((snapshot) => ({ ...snapshot, gems: snapshot.gems + 30, questClaimed: snapshot.day }))
        return true
      },
      resetAll: () => {
        const next = blank()
        ref.current = next
        setState(next)
      },
    }
  }, [state])

  return <StoreContext.Provider value={api}>{children}</StoreContext.Provider>
}

export function useStore() {
  const store = useContext(StoreContext)
  if (!store) throw new Error('StoreProvider の中で使ってください')
  return store
}

export function nextHeartIn(state: Persisted) {
  if (state.super || state.hearts >= 5) return 0
  const elapsed = Date.now() - state.heartAt
  const remain = HEART_MS - (elapsed % HEART_MS)
  return remain
}
