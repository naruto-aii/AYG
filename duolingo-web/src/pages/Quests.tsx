import { useEffect } from 'react'
import { Shell } from '../components/Shell'
import { playSound } from '../sound'
import { useStore } from '../store'

export function QuestsPage() {
  const { state, claimQuest } = useStore()
  const quests = [
    { label: 'XPを20獲得する', current: state.xpToday, goal: 20 },
    { label: 'レッスンを2回終える', current: state.lessonsToday, goal: 2 },
    { label: 'パーフェクトを1回出す', current: state.perfectToday, goal: 1 },
  ]
  const ready = quests.every((quest) => quest.current >= quest.goal)
  const claimed = state.questClaimed === state.day

  useEffect(() => {
    document.title = 'クエスト'
  }, [])

  return (
    <Shell>
      <div className="page">
        <h1>クエスト</h1>
        <section className="card flat">
          <h2>今日のクエスト</h2>
          {quests.map((quest) => (
            <div key={quest.label} className="quest-row">
              <div className="card-head">
                <span>{quest.label}</span>
                <span>{Math.min(quest.current, quest.goal)}/{quest.goal}</span>
              </div>
              <div className="bar"><span style={{ width: `${Math.min(100, (quest.current / quest.goal) * 100)}%` }} /></div>
            </div>
          ))}
          <button
            className="btn btn-green btn-block"
            type="button"
            disabled={!ready || claimed}
            onClick={() => {
              if (claimQuest()) playSound('gem', state.sound)
            }}
          >
            {claimed ? '受け取り済み' : '宝箱を受け取る +30'}
          </button>
        </section>
        <section className="card flat locked-card">
          <h2>フレンドクエスト</h2>
          <p>友だちをフォローすると、ここに共同クエストが出ます。このデモではリーグの相手をフォローできます。</p>
        </section>
      </div>
    </Shell>
  )
}
