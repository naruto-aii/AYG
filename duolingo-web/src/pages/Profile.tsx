import { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Avatar, Shell } from '../components/Shell'
import { leagueFor, rivals } from '../data'
import { useStore } from '../store'

export function ProfilePage() {
  const { userId } = useParams()
  const { state, toggleFollow } = useStore()
  const [query, setQuery] = useState('')
  const rival = rivals.find((item) => item.id === userId)
  const mine = !userId
  const league = leagueFor(mine ? state.weekXp : rival?.xp ?? 0)
  const name = mine ? state.user?.name ?? '' : rival?.name ?? '学習者'
  const achievements = useMemo(
    () => [
      { title: 'はじめの一歩', desc: 'レッスンを1回終える', ok: state.totalLessons >= 1 },
      { title: '100 XP', desc: '合計100 XP', ok: state.xp >= 100 },
      { title: '3日連続', desc: '3日連続で学習', ok: state.streak >= 3 },
      { title: 'パーフェクト', desc: '全問正解を1回', ok: state.totalPerfect >= 1 },
      { title: '宝箱', desc: '宝箱を開ける', ok: state.chests.length >= 1 },
      { title: 'お買い物', desc: 'ショップで買う', ok: state.purchases >= 1 },
    ],
    [state],
  )
  const friends = rivals.filter((item) => state.following.includes(item.id) && item.name.includes(query.trim()))

  useEffect(() => {
    document.title = name
  }, [name])

  return (
    <Shell>
      <div className="page profile">
        <div className="profile-banner" />
        <div className="profile-head">
          <Avatar name={name} size={84} />
          <div>
            <h1>{name}</h1>
            <p className="muted">{mine ? `@${state.user?.username}` : 'リーグの学習者'}</p>
            {mine ? <p className="muted">開始 {state.user?.joined} · 韓国語 · {state.reason || '入門'}</p> : null}
          </div>
          {!mine && rival && (
            <button className="btn btn-white" type="button" onClick={() => toggleFollow(rival.id)}>
              {state.following.includes(rival.id) ? 'フォロー中' : 'フォロー'}
            </button>
          )}
        </div>
        {!mine && !rival && <p>この学習者は見つかりません。<Link to="/leaderboard">リーグへ戻る</Link></p>}
        <div className="stat-row">
          <article><span>連続</span><strong>{mine ? state.streak : 12}</strong></article>
          <article><span>今週のXP</span><strong>{mine ? state.weekXp : rival?.xp ?? 0}</strong></article>
          <article><span>リーグ</span><strong>{league.name}</strong></article>
        </div>
        {mine && (
          <>
            <h2>実績</h2>
            <div className="achieve-grid">
              {achievements.map((item) => (
                <article key={item.title} className={item.ok ? 'on' : ''}>
                  <strong>{item.title}</strong>
                  <span>{item.desc}</span>
                </article>
              ))}
            </div>
            <h2>フォロー中</h2>
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="名前で探す" aria-label="友だちを探す" />
            {friends.length === 0 ? (
              <p className="muted">まだフォローしていません。リーグから相手を開けます。</p>
            ) : (
              <ul className="friend-list">
                {friends.map((friend) => (
                  <li key={friend.id}>
                    <Link to={`/profile/${friend.id}`}><Avatar name={friend.name} size={36} /> {friend.name}</Link>
                    <button type="button" className="text-link" onClick={() => toggleFollow(friend.id)}>解除</button>
                  </li>
                ))}
              </ul>
            )}
          </>
        )}
      </div>
    </Shell>
  )
}
