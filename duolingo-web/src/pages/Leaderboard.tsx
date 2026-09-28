import { useEffect } from 'react'
import { Link } from 'react-router-dom'
import { Avatar, Shell } from '../components/Shell'
import { leagueFor, rivals } from '../data'
import { useStore } from '../store'

export function LeaderboardPage() {
  const { state } = useStore()
  const league = leagueFor(state.weekXp)
  const rows = [
    ...rivals.map((rival) => ({ ...rival, me: false })),
    { id: 'me', name: state.user?.name ?? 'あなた', xp: state.weekXp, me: true },
  ].sort((a, b) => b.xp - a.xp)

  useEffect(() => {
    document.title = 'リーグ'
  }, [])

  return (
    <Shell>
      <div className="page">
        <header className="league-hero" style={{ background: league.color }}>
          <p>今週のリーグ</p>
          <h1>{league.name}リーグ</h1>
          <span>残り 4 日</span>
        </header>
        <p className="zone up">上位5名は昇格圏</p>
        <ol className="board">
          {rows.map((row, index) => (
            <li key={row.id} className={row.me ? 'me' : ''}>
              <span className="rank">{index + 1}</span>
              {row.me ? <Avatar name={row.name} /> : <Link to={`/profile/${row.id}`}><Avatar name={row.name} /></Link>}
              <span className="who">{row.me ? `${row.name}（あなた）` : <Link to={`/profile/${row.id}`}>{row.name}</Link>}</span>
              <b>{row.xp} XP</b>
            </li>
          ))}
        </ol>
        <p className="zone down">下位3名は降格圏</p>
      </div>
    </Shell>
  )
}
