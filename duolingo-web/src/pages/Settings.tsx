import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Shell } from '../components/Shell'
import { courses, goals } from '../data'
import { useStore } from '../store'

export function SettingsPage() {
  const { state, setSound, setNotifications, setDailyGoal, setName, logout, resetAll, setCourse } = useStore()
  const navigate = useNavigate()
  const [name, setLocalName] = useState(state.user?.name ?? '')
  const [confirm, setConfirm] = useState(false)

  useEffect(() => {
    document.title = '設定'
  }, [])

  return (
    <Shell>
      <div className="page">
        <h1>設定</h1>
        <section className="card flat">
          <h2>アカウント</h2>
          <label>
            名前
            <input value={name} onChange={(event) => setLocalName(event.target.value)} />
          </label>
          <button className="btn btn-white" type="button" onClick={() => setName(name)}>保存</button>
          <p className="muted">{state.user?.email || 'ゲスト'}</p>
        </section>
        <section className="card flat">
          <h2>学習</h2>
          <label>
            コース
            <select value={state.courseId} onChange={(event) => setCourse(event.target.value as typeof state.courseId)}>
              {courses.map((course) => (
                <option key={course.id} value={course.id}>{course.label}</option>
              ))}
            </select>
          </label>
          <p className="muted">進み具合はコースごとに残ります。XP・連続記録・宝石は共通です。</p>
          <label>
            1日の目標
            <select value={state.dailyGoal} onChange={(event) => setDailyGoal(Number(event.target.value))}>
              {goals.map((goal) => (
                <option key={goal.minutes} value={goal.minutes}>{goal.minutes}分 · {goal.label}</option>
              ))}
            </select>
          </label>
          <label className="toggle">
            <input type="checkbox" checked={state.sound} onChange={(event) => setSound(event.target.checked)} />
            効果音
          </label>
          <label className="toggle">
            <input type="checkbox" checked={state.notifications} onChange={(event) => setNotifications(event.target.checked)} />
            リマインダー表示（このデモでは通知は飛びません）
          </label>
        </section>
        <section className="card flat">
          <h2>このデモについて</h2>
          <p>画面と遷移の再現です。アカウント情報と進捗は、このブラウザの localStorage だけに残ります。</p>
          <button className="btn btn-white btn-block" type="button" onClick={() => { logout(); navigate('/') }}>ログアウト</button>
          {!confirm ? (
            <button className="text-link danger" type="button" onClick={() => setConfirm(true)}>進捗を消す</button>
          ) : (
            <button className="btn btn-red btn-block" type="button" onClick={() => { resetAll(); navigate('/') }}>本当に消す</button>
          )}
        </section>
      </div>
    </Shell>
  )
}
