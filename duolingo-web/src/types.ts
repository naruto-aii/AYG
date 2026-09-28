export type ChoiceQuestion = {
  type: 'choice'
  prompt: string
  sentence?: string
  choices: string[]
  answer: number
}

export type BankQuestion = {
  type: 'bank'
  prompt: string
  sentence: string
  answer: string[]
  extra: string[]
}

export type MatchQuestion = {
  type: 'match'
  prompt: string
  pairs: [string, string][]
}

export type ListenQuestion = {
  type: 'listen'
  prompt: string
  speak: string
  choices: string[]
  answer: number
}

export type BlankQuestion = {
  type: 'blank'
  prompt: string
  before: string
  after: string
  choices: string[]
  answer: number
}

export type Question =
  | ChoiceQuestion
  | BankQuestion
  | MatchQuestion
  | ListenQuestion
  | BlankQuestion

export type LessonNode = {
  id: string
  kind: 'lesson' | 'story' | 'trophy'
  title: string
  xp: number
  passage?: string[]
  questions: Question[]
}

export type ChestNode = {
  id: string
  kind: 'chest'
  title: string
  gems: number
}

export type PathNode = LessonNode | ChestNode

export type Unit = {
  id: string
  title: string
  color: string
  dark: string
  phrases: { ko: string; ja: string }[]
  nodes: PathNode[]
}

export type Section = {
  id: string
  title: string
  kicker: string
  units: Unit[]
}

export type Rival = {
  id: string
  name: string
  xp: number
}

export type Account = {
  email: string
  password: string
  name: string
  username: string
  joined: string
}

export type User = {
  name: string
  username: string
  email: string
  joined: string
}

export type PendingProfile = {
  reason: string
  dailyGoal: number
  name: string
}

export type Persisted = {
  user: User | null
  accounts: Account[]
  reason: string
  dailyGoal: number
  xp: number
  weekXp: number
  gems: number
  hearts: number
  heartAt: number
  super: boolean
  streak: number
  lastActive: string | null
  freezes: number
  boostUntil: number
  completed: string[]
  chests: string[]
  lessonsToday: number
  xpToday: number
  perfectToday: number
  day: string
  totalLessons: number
  totalPerfect: number
  purchases: number
  sound: boolean
  notifications: boolean
  following: string[]
  questClaimed: string | null
  pending: PendingProfile | null
}
