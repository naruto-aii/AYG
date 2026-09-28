import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { Shell } from '../components/Shell'
import { practiceLessons } from '../data'

const blurbs = ['耳で意味をつかむ', '単語の対応をそろえる', '語順を組み立てる']

export function PracticePage() {
  const navigate = useNavigate()
  useEffect(() => {
    document.title = '練習'
  }, [])

  return (
    <Shell>
      <div className="page">
        <h1>練習ハブ</h1>
        <p className="muted">パスとは別に、短い練習ができます。終えるとハートが1つ戻ります。</p>
        <div className="practice-list">
          {practiceLessons.map((lesson, index) => (
            <button key={lesson.id} className="practice-card" type="button" onClick={() => navigate(`/practice/${lesson.id}`)}>
              <strong>{lesson.title}</strong>
              <span>{blurbs[index]}</span>
              <em>+{lesson.xp} XP</em>
            </button>
          ))}
        </div>
      </div>
    </Shell>
  )
}
