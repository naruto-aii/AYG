import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Shell } from '../components/Shell'
import { Owl } from '../components/Owl'
import { useStore } from '../store'

export function SuperPage() {
  const { state, activateSuper } = useStore()
  const navigate = useNavigate()
  const [plan, setPlan] = useState<'month' | 'year'>('year')

  useEffect(() => {
    document.title = 'Super'
  }, [])

  return (
    <Shell>
      <div className="page super-page">
        <Owl mood="wow" size={120} />
        <h1>Super</h1>
        <p className="muted">デモ用の表示です。実際の決済は行われません。</p>
        <ul className="perks">
          <li>ハートが減らない</li>
          <li>広告の枠を出さない</li>
          <li>復習を好きなだけ開ける</li>
        </ul>
        <div className="plan-row">
          <button type="button" className={plan === 'month' ? 'selected' : ''} onClick={() => setPlan('month')}>月額プラン</button>
          <button type="button" className={plan === 'year' ? 'selected' : ''} onClick={() => setPlan('year')}>年額プラン</button>
        </div>
        {state.super ? (
          <p className="form-note">Super は有効です。ハートは減りません。</p>
        ) : (
          <button className="btn btn-purple btn-wide" type="button" onClick={() => { activateSuper(); navigate('/learn') }}>
            デモなので無料で有効化
          </button>
        )}
      </div>
    </Shell>
  )
}
