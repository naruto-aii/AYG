import { useEffect, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { Owl } from '../components/Owl'
import { playSound } from '../sound'
import { useStore } from '../store'

type ResultState = {
  title: string
  xp: number
  correct: number
  total: number
  increased: boolean
  streak: number
  perfect: boolean
  seconds: number
  practice: boolean
}

export function CompletePage() {
  const location = useLocation()
  const navigate = useNavigate()
  const { state } = useStore()
  const result = location.state as ResultState | null
  const [step, setStep] = useState<'score' | 'streak'>('score')

  useEffect(() => {
    document.title = 'レッスン完了'
    if (!result) navigate('/learn', { replace: true })
    else playSound('fanfare', state.sound)
  }, [result, navigate, state.sound])

  if (!result) return null
  const accuracy = result.total === 0 ? 0 : Math.round((result.correct / result.total) * 100)

  if (step === 'streak' && result.increased) {
    return (
      <div className="complete-screen">
        <div className="confetti" aria-hidden="true">
          {Array.from({ length: 16 }, (_, index) => <i key={index} style={{ left: `${(index * 6.2) % 100}%`, animationDelay: `${index * 0.08}s` }} />)}
        </div>
        <p className="eyebrow">連続記録</p>
        <div className="streak-num">{result.streak}</div>
        <h1>{result.streak}日連続！</h1>
        <p>今日のレッスンで火がつきました。</p>
        <button className="btn btn-green btn-wide" type="button" onClick={() => navigate(result.practice ? '/practice' : '/learn')}>つづける</button>
      </div>
    )
  }

  return (
    <div className="complete-screen">
      <div className="confetti" aria-hidden="true">
        {Array.from({ length: 16 }, (_, index) => <i key={index} style={{ left: `${(index * 6.2) % 100}%`, animationDelay: `${index * 0.08}s` }} />)}
      </div>
      <Owl mood="wow" size={170} />
      <h1>{result.perfect ? 'パーフェクト！' : 'レッスン完了！'}</h1>
      <p>{result.title}</p>
      <div className="score-grid">
        <article><span>合計XP</span><strong>{result.xp}</strong></article>
        <article><span>正解率</span><strong>{accuracy}%</strong></article>
        <article><span>時間</span><strong>{result.seconds}秒</strong></article>
      </div>
      <button
        className="btn btn-green btn-wide"
        type="button"
        onClick={() => {
          if (result.increased) setStep('streak')
          else navigate(result.practice ? '/practice' : '/learn')
        }}
      >
        つづける
      </button>
    </div>
  )
}
