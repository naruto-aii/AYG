import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { courses, getCourse, goals, reasons } from '../data'
import { useStore } from '../store'
import { Icon } from '../components/Icons'
import type { CourseId } from '../types'

export function OnboardingPage() {
  const { state, setPending, setCourse } = useStore()
  const navigate = useNavigate()
  const [step, setStep] = useState(0)
  const [language, setLanguage] = useState<CourseId>(state.courseId)
  const [reason, setReason] = useState(reasons[0])
  const [goal, setGoal] = useState(10)
  const [name, setName] = useState('')
  const [note, setNote] = useState('')
  const course = getCourse(language)

  useEffect(() => {
    document.title = 'コースをはじめる'
  }, [])

  const next = () => {
    if (step === 3 && !name.trim()) return
    if (step < 3) {
      setNote('')
      setStep((value) => value + 1)
      return
    }
    setCourse(language)
    setPending({ reason, dailyGoal: goal, name: name.trim(), courseId: language })
    navigate('/register')
  }

  return (
    <div className="wizard">
      <header className="wizard-top">
        <button className="icon-btn" type="button" aria-label="戻る" onClick={() => (step === 0 ? navigate('/') : setStep((value) => value - 1))}>
          <Icon name="close" />
        </button>
        <div className="progress" aria-hidden="true">
          <span style={{ width: `${((step + 1) / 4) * 100}%` }} />
        </div>
      </header>
      <div className="wizard-body">
        {step === 0 && (
          <>
            <h1>どの言語を学びますか？</h1>
            <div className="option-list">
              {courses.map((item) => (
                <button key={item.id} type="button" className={`option${language === item.id ? ' selected' : ''}`} onClick={() => { setLanguage(item.id); setCourse(item.id); setNote('') }}>
                  <strong>{item.label}</strong>
                  <span lang={item.htmlLang}>{item.sample} · {item.sampleJa}</span>
                </button>
              ))}
            </div>
          </>
        )}
        {step === 1 && (
          <>
            <h1>なぜ{course.label}を学びますか？</h1>
            <div className="option-list">
              {reasons.map((item) => (
                <button key={item} type="button" className={`option${reason === item ? ' selected' : ''}`} onClick={() => setReason(item)}>
                  <strong>{item}</strong>
                </button>
              ))}
            </div>
          </>
        )}
        {step === 2 && (
          <>
            <h1>1日の目標は？</h1>
            <div className="option-list">
              {goals.map((item) => (
                <button key={item.minutes} type="button" className={`option${goal === item.minutes ? ' selected' : ''}`} onClick={() => setGoal(item.minutes)}>
                  <strong>1日 {item.minutes} 分</strong>
                  <span>{item.label} · {item.xp} XP</span>
                </button>
              ))}
            </div>
          </>
        )}
        {step === 3 && (
          <>
            <h1>なんて呼べばいいですか？</h1>
            <label className="name-field">
              名前
              <input value={name} onChange={(event) => setName(event.target.value)} placeholder="例: はな" autoFocus />
            </label>
          </>
        )}
        {note && <p className="form-note">{note}</p>}
      </div>
      <footer className="wizard-foot">
        <button className="btn btn-green btn-wide" type="button" disabled={step === 3 && !name.trim()} onClick={next}>
          つづける
        </button>
      </footer>
    </div>
  )
}
