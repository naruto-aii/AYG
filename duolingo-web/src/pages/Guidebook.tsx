import { useEffect } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Shell } from '../components/Shell'
import { findUnit, getCourse } from '../data'
import { useStore } from '../store'

export function GuidebookPage() {
  const { unitId = '' } = useParams()
  const { state } = useStore()
  const course = getCourse(state.courseId)
  const unit = findUnit(unitId, state.courseId)

  useEffect(() => {
    document.title = unit ? `${unit.title}のガイド` : 'ガイドブック'
  }, [unit])

  return (
    <Shell>
      <div className="page">
        <Link className="text-link" to="/learn">学習へ戻る</Link>
        {unit ? (
          <>
            <header className="unit-banner slim" style={{ background: unit.color }}>
              <div>
                <p>ガイドブック</p>
                <strong>{unit.title}</strong>
              </div>
            </header>
            <ul className="phrase-list">
              {unit.phrases.map((phrase) => (
                <li key={phrase.text}>
                  <strong lang={course.htmlLang}>{phrase.text}</strong>
                  <span>{phrase.ja}</span>
                </li>
              ))}
            </ul>
          </>
        ) : (
          <p>ガイドが見つかりません。</p>
        )}
      </div>
    </Shell>
  )
}
