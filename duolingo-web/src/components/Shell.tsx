import { useEffect, useState, type ReactNode } from 'react'
import { Link, NavLink, useNavigate } from 'react-router-dom'
import { goalXp, leagueFor, rivals } from '../data'
import { formatLeft } from '../lib'
import { nextHeartIn, useStore } from '../store'
import { Icon } from './Icons'
import { Wordmark } from './Owl'

const links = [
  { to: '/learn', label: '学習', icon: 'home' as const },
  { to: '/practice', label: '練習', icon: 'practice' as const },
  { to: '/leaderboard', label: 'リーグ', icon: 'shield' as const },
  { to: '/quests', label: 'クエスト', icon: 'quest' as const },
  { to: '/shop', label: 'ショップ', icon: 'shop' as const },
  { to: '/profile', label: 'プロフィール', icon: 'person' as const },
]

export function Shell({ children }: { children: ReactNode }) {
  const { state, logout } = useStore()
  const navigate = useNavigate()
  const [more, setMore] = useState(false)
  const [heartsOpen, setHeartsOpen] = useState(false)
  const [, setTick] = useState(0)
  const user = state.user

  useEffect(() => {
    if (!user) navigate('/', { replace: true })
  }, [user, navigate])

  useEffect(() => {
    const timer = window.setInterval(() => setTick((value) => value + 1), 30000)
    return () => window.clearInterval(timer)
  }, [])

  if (!user) return null

  const league = leagueFor(state.weekXp)
  const goal = goalXp(state.dailyGoal)
  const quests = [
    { label: 'XPを20獲得', current: state.xpToday, goal: 20 },
    { label: 'レッスンを2回', current: state.lessonsToday, goal: 2 },
    { label: 'パーフェクトを1回', current: state.perfectToday, goal: 1 },
  ]
  const board = [...rivals.map((rival) => ({ name: rival.name, xp: rival.xp })), { name: user.name, xp: state.weekXp }]
    .sort((a, b) => b.xp - a.xp)
    .slice(0, 3)

  return (
    <div className="shell">
      <aside className="sidenav">
        <Link to="/learn" className="logo-link" aria-label="学習へ">
          <Wordmark />
        </Link>
        <nav className="side-links" aria-label="メイン">
          {links.map((link) => (
            <NavLink key={link.to} to={link.to} className={({ isActive }) => `side-link${isActive ? ' active' : ''}`}>
              <Icon name={link.icon} />
              <span>{link.label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="more-wrap">
          <button className="side-link more-btn" type="button" onClick={() => setMore((open) => !open)} aria-expanded={more}>
            <Icon name="more" />
            <span>もっと見る</span>
          </button>
          {more && (
            <div className="more-menu">
              <Link to="/settings" onClick={() => setMore(false)}>設定</Link>
              <Link to="/super" onClick={() => setMore(false)}>Super</Link>
              <button
                type="button"
                onClick={() => {
                  logout()
                  navigate('/')
                }}
              >
                ログアウト
              </button>
            </div>
          )}
        </div>
      </aside>
      <div className="center">
        <header className="topbar">
          <div className="top-stats">
            <Link to="/quests" className="stat flame">
              <Icon name="flame" color="#ff9600" size={22} />
              <strong>{state.streak}</strong>
            </Link>
            <Link to="/shop" className="stat gem">
              <Icon name="gem" color="#1cb0f6" size={22} />
              <strong>{state.gems}</strong>
            </Link>
            <button className="stat heart" type="button" onClick={() => setHeartsOpen((open) => !open)}>
              <Icon name="heart" color="#ff4b4b" size={22} />
              <strong>{state.super ? '∞' : state.hearts}</strong>
            </button>
            {heartsOpen && (
              <div className="heart-pop">
                <strong>{state.super ? 'ハートは無限です' : `ハート ${state.hearts}/5`}</strong>
                <p>
                  {state.super
                    ? 'Super を有効にしているので、まちがえても減りません。'
                    : state.hearts >= 5
                      ? 'ハートは満タンです。'
                      : `次のハートまで ${formatLeft(nextHeartIn(state))}`}
                </p>
                <Link to="/shop" onClick={() => setHeartsOpen(false)}>ショップで回復</Link>
              </div>
            )}
          </div>
        </header>
        {children}
      </div>
      <aside className="rail">
        {!state.super && (
          <section className="card super-card">
            <p className="eyebrow">SUPER</p>
            <h2>ハートを気にせず進もう</h2>
            <p>まちがえてもハートが減らないデモ用のプランです。</p>
            <Link className="btn btn-purple btn-block" to="/super">SUPERを見る</Link>
          </section>
        )}
        <section className="card">
          <div className="card-head">
            <h2>今日の目標</h2>
            <span>{Math.min(state.xpToday, goal)}/{goal} XP</span>
          </div>
          <div className="bar" aria-hidden="true">
            <span style={{ width: `${Math.min(100, (state.xpToday / goal) * 100)}%` }} />
          </div>
        </section>
        <section className="card">
          <div className="card-head">
            <h2>{league.name}リーグ</h2>
            <Link to="/leaderboard">すべて</Link>
          </div>
          <ol className="mini-board">
            {board.map((row, index) => (
              <li key={row.name} className={row.name === user.name ? 'me' : ''}>
                <span>{index + 1}</span>
                <span>{row.name}</span>
                <b>{row.xp} XP</b>
              </li>
            ))}
          </ol>
        </section>
        <section className="card">
          <div className="card-head">
            <h2>デイリークエスト</h2>
            <Link to="/quests">すべて</Link>
          </div>
          {quests.map((quest) => (
            <div key={quest.label} className="quest-row">
              <div className="card-head">
                <span>{quest.label}</span>
                <span>{Math.min(quest.current, quest.goal)}/{quest.goal}</span>
              </div>
              <div className="bar">
                <span style={{ width: `${Math.min(100, (quest.current / quest.goal) * 100)}%` }} />
              </div>
            </div>
          ))}
        </section>
        <p className="rail-note">非公式UIデモです。Duolingo, Inc. とは関係ありません。</p>
      </aside>
      <nav className="tabbar" aria-label="モバイル">
        {links.map((link) => (
          <NavLink key={link.to} to={link.to} className={({ isActive }) => (isActive ? 'active' : '')}>
            <Icon name={link.icon} size={24} />
            <span>{link.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  )
}

export function Avatar({ name, size = 48 }: { name: string; size?: number }) {
  const hue = [...name].reduce((sum, char) => sum + char.charCodeAt(0), 0) % 360
  return (
    <span className="avatar" style={{ width: size, height: size, background: `hsl(${hue} 70% 46%)`, fontSize: size * 0.42 }}>
      {name.slice(0, 1)}
    </span>
  )
}
