import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Icon } from '../components/Icons'
import { Owl } from '../components/Owl'
import { correctLabel, findPathNode, findPractice, getCourse, isUnlocked } from '../data'
import { praise, shuffle } from '../lib'
import { playSound, speak } from '../sound'
import { useStore } from '../store'
import type { Question } from '../types'

type Phase = 'passage' | 'ask' | 'feedback' | 'quit' | 'empty' | 'chest'

export function LessonPage({ practice = false }: { practice?: boolean }) {
  const { nodeId = '' } = useParams()
  const navigate = useNavigate()
  const { state, loseHeart, finishLesson, openChest } = useStore()
  const course = getCourse(state.courseId)
  const found = practice ? null : findPathNode(nodeId, state.courseId)
  const practiceNode = practice ? findPractice(nodeId, state.courseId) : null
  const node = practiceNode ?? (found && found.node.kind !== 'chest' ? found.node : null)
  const chest = !practice && found?.node.kind === 'chest' ? found.node : null
  const [phase, setPhase] = useState<Phase>(chest ? 'chest' : node?.passage ? 'passage' : 'ask')
  const [index, setIndex] = useState(0)
  const [picked, setPicked] = useState<number | null>(null)
  const [bank, setBank] = useState<string[]>([])
  const [matched, setMatched] = useState<string[]>([])
  const [leftPick, setLeftPick] = useState<string | null>(null)
  const [wrongPair, setWrongPair] = useState(false)
  const [correctCount, setCorrectCount] = useState(0)
  const [message, setMessage] = useState('')
  const [ok, setOk] = useState(false)
  const [started] = useState(() => Date.now())
  const [gems, setGems] = useState(0)
  const [opened, setOpened] = useState(false)
  const [back, setBack] = useState<Phase>('ask')

  const question: Question | null = node?.questions[index] ?? null
  const tiles = useMemo(() => (question?.type === 'bank' ? shuffle([...question.answer, ...question.extra]) : []), [question])
  const rights = useMemo(
    () => (question?.type === 'match' ? shuffle(question.pairs.map((pair) => pair[1])) : []),
    [question],
  )

  useEffect(() => {
    document.title = node?.title ?? chest?.title ?? 'レッスン'
  }, [node, chest])

  useEffect(() => {
    if (!state.user) navigate('/', { replace: true })
  }, [state.user, navigate])

  useEffect(() => {
    if (!practice && found && !isUnlocked(nodeId, state.completed, state.chests, state.courseId)) navigate('/learn', { replace: true })
  }, [practice, found, nodeId, state.completed, state.chests, state.courseId, navigate])

  useEffect(() => {
    if (question?.type === 'listen') speak(question.speak, course.speechLang, state.sound)
  }, [question, course.speechLang, state.sound])

  if (!state.user) return null
  if (!node && !chest) {
    return (
      <div className="lesson-screen">
        <p>レッスンが見つかりません。</p>
        <button className="btn btn-green" type="button" onClick={() => navigate('/learn')}>戻る</button>
      </div>
    )
  }

  const total = node?.questions.length ?? 0
  const progress = total === 0 ? 0 : (index / total) * 100

  const resetAnswer = () => {
    setPicked(null)
    setBank([])
    setMatched([])
    setLeftPick(null)
    setWrongPair(false)
  }

  const canCheck = () => {
    if (!question) return false
    if (question.type === 'choice' || question.type === 'listen' || question.type === 'blank') return picked !== null
    if (question.type === 'bank') return bank.length === question.answer.length
    return matched.length === question.pairs.length * 2
  }

  const grade = (forceWrong = false) => {
    if (!question) return
    let right = false
    if (!forceWrong && (question.type === 'choice' || question.type === 'listen' || question.type === 'blank')) {
      right = picked === question.answer
    } else if (!forceWrong && question.type === 'bank') right = bank.join(' ') === question.answer.join(' ')
    else if (!forceWrong && question.type === 'match') right = matched.length === question.pairs.length * 2
    setOk(right)
    setMessage(right ? praise() : `正解: ${correctLabel(question)}`)
    setPhase('feedback')
    playSound(right ? 'ok' : 'bad', state.sound)
    if (right) setCorrectCount((count) => count + 1)
    else {
      const hearts = loseHeart()
      if (hearts <= 0) setPhase('empty')
    }
  }

  const finish = () => {
    if (!node) return
    const result = finishLesson(node.id, correctCount, total)
    const seconds = Math.max(1, Math.round((Date.now() - started) / 1000))
    navigate('/complete', {
      state: {
        title: node.title,
        xp: result?.xp ?? 0,
        correct: correctCount,
        total,
        increased: result?.increased ?? false,
        streak: result?.streak ?? state.streak,
        perfect: result?.perfect ?? false,
        seconds,
        practice,
      },
    })
  }

  const continueNext = () => {
    if (!node) return
    if (index + 1 >= total) {
      finish()
      return
    }
    setIndex((value) => value + 1)
    resetAnswer()
    setPhase('ask')
  }

  const onMatch = (side: 'left' | 'right', value: string) => {
    if (!question || question.type !== 'match' || matched.includes(value)) return
    if (side === 'left') {
      setLeftPick(value)
      return
    }
    if (!leftPick) return
    const pair = question.pairs.find((item) => item[0] === leftPick)
    if (pair && pair[1] === value) {
      setMatched((current) => [...current, leftPick, value])
      playSound('tap', state.sound)
    } else {
      setWrongPair(true)
      playSound('bad', state.sound)
      window.setTimeout(() => setWrongPair(false), 350)
    }
    setLeftPick(null)
  }

  if (phase === 'quit') {
    return (
      <div className="modal-screen">
        <div className="modal">
          <Owl mood="sad" size={120} />
          <h1>レッスンをやめますか？</h1>
          <p>ここまでの進み具合は保存されません。</p>
          <button className="btn btn-red btn-block" type="button" onClick={() => navigate(practice ? '/practice' : '/learn')}>やめる</button>
          <button className="btn btn-white btn-block" type="button" onClick={() => setPhase(back)}>続ける</button>
        </div>
      </div>
    )
  }

  if (phase === 'empty') {
    return (
      <div className="modal-screen">
        <div className="modal">
          <Owl mood="sad" size={140} />
          <h1>ハートがなくなりました</h1>
          <p>練習するか、ショップで回復するとレッスンを再開できます。</p>
          <button className="btn btn-green btn-block" type="button" onClick={() => navigate('/practice')}>練習して回復</button>
          <button className="btn btn-white btn-block" type="button" onClick={() => navigate('/shop')}>ショップ</button>
          <button className="btn btn-purple btn-block" type="button" onClick={() => navigate('/super')}>Superを見る</button>
          <button className="text-link" type="button" onClick={() => navigate('/learn')}>やめる</button>
        </div>
      </div>
    )
  }

  if (chest && phase === 'chest') {
    const taken = opened || state.chests.includes(chest.id)
    return (
      <div className="modal-screen">
        <div className="modal">
          <div className="chest-art">{taken ? '💎' : '🧰'}</div>
          <h1>{gems > 0 ? `宝石を ${gems} 個手に入れた！` : taken ? 'この宝箱は開いています' : chest.title}</h1>
          <p>{taken ? 'パスの次のレッスンが開きます。' : 'タップして中を見ます。'}</p>
          {taken ? (
            <button className="btn btn-green btn-block" type="button" onClick={() => navigate('/learn')}>つづける</button>
          ) : (
            <button
              className="btn btn-green btn-block"
              type="button"
              onClick={() => {
                const gained = openChest(chest.id)
                setGems(gained)
                setOpened(true)
                playSound('gem', state.sound)
              }}
            >
              開ける
            </button>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="lesson-screen">
      <header className="lesson-top">
        <button className="icon-btn" type="button" aria-label="閉じる" onClick={() => { setBack(phase); setPhase('quit') }}>
          <Icon name="close" />
        </button>
        <div className="progress" aria-label={`進捗 ${Math.round(progress)}%`}>
          <span style={{ width: `${progress}%` }} />
        </div>
        <span className="heart-count">
          <Icon name="heart" color="#ff4b4b" size={22} />
          {state.super ? '∞' : state.hearts}
        </span>
      </header>
      {phase === 'passage' && node?.passage && (
        <div className="lesson-body">
          <div className="passage">
            <p className="eyebrow">ストーリー</p>
            <h1>{node.title}</h1>
            {node.passage.map((line) => <p key={line}>{line}</p>)}
          </div>
          <footer className="lesson-foot">
            <button className="btn btn-green btn-wide" type="button" onClick={() => setPhase('ask')}>問題へ</button>
          </footer>
        </div>
      )}
      {question && phase !== 'passage' && (
        <div className="lesson-body">
          <div className="prompt-row">
            <Owl mood={phase === 'feedback' ? (ok ? 'happy' : 'sad') : 'idle'} size={92} />
            <div>
              <h1>{question.prompt}</h1>
              {'sentence' in question && question.sentence && <p className="sentence">{question.sentence}</p>}
            </div>
          </div>
          {question.type === 'listen' && (
            <button className="speaker" type="button" onClick={() => speak(question.speak, course.speechLang, true)}>
              <Icon name="speaker" size={42} color="#1cb0f6" />
              もう一度聞く
            </button>
          )}
          {(question.type === 'choice' || question.type === 'listen') && (
            <div className="choice-list">
              {question.choices.map((choice, choiceIndex) => {
                const marked = phase === 'feedback' && (choiceIndex === question.answer || choiceIndex === picked)
                const status = phase === 'feedback' && choiceIndex === question.answer ? 'correct' : phase === 'feedback' && choiceIndex === picked ? 'wrong' : ''
                return (
                  <button
                    key={choice}
                    className={`choice${picked === choiceIndex ? ' selected' : ''} ${status}`}
                    type="button"
                    disabled={phase === 'feedback'}
                    onClick={() => setPicked(choiceIndex)}
                  >
                    {choice}
                    {marked && status === 'correct' && <Icon name="check" color="#58a700" />}
                  </button>
                )
              })}
            </div>
          )}
          {question.type === 'blank' && (
            <div className="blank-block">
              <p className="sentence" lang={course.htmlLang}>{question.before}<em>{picked === null ? '______' : question.choices[picked]}</em>{question.after}</p>
              <div className="chips">
                {question.choices.map((choice, choiceIndex) => (
                  <button
                    key={choice}
                    className={`chip${picked === choiceIndex ? ' selected' : ''}`}
                    type="button"
                    disabled={phase === 'feedback'}
                    onClick={() => setPicked(choiceIndex)}
                  >
                    {choice}
                  </button>
                ))}
              </div>
            </div>
          )}
          {question.type === 'bank' && (
            <div className="bank-block">
              <div className="answer-line">
                {bank.map((word, wordIndex) => (
                  <button
                    key={`${word}-${wordIndex}`}
                    className="chip"
                    type="button"
                    disabled={phase === 'feedback'}
                    onClick={() => setBank((current) => current.filter((_, item) => item !== wordIndex))}
                  >
                    {word}
                  </button>
                ))}
              </div>
              <div className="chips">
                {tiles.map((word, wordIndex) => {
                  const used = bank.filter((item) => item === word).length
                  const seen = tiles.slice(0, wordIndex + 1).filter((item) => item === word).length
                  const hidden = seen <= used
                  return (
                    <button
                      key={`${word}-${wordIndex}`}
                      className={`chip${hidden ? ' used' : ''}`}
                      type="button"
                      disabled={hidden || phase === 'feedback'}
                      onClick={() => setBank((current) => [...current, word])}
                    >
                      {word}
                    </button>
                  )
                })}
              </div>
            </div>
          )}
          {question.type === 'match' && (
            <div className={`match-grid${wrongPair ? ' shake' : ''}`}>
              <div>
                {question.pairs.map((pair) => (
                  <button
                    key={pair[0]}
                    className={`choice${matched.includes(pair[0]) ? ' correct' : ''}${leftPick === pair[0] ? ' selected' : ''}`}
                    type="button"
                    disabled={matched.includes(pair[0]) || phase === 'feedback'}
                    onClick={() => onMatch('left', pair[0])}
                  >
                    {pair[0]}
                  </button>
                ))}
              </div>
              <div>
                {rights.map((value) => (
                  <button
                    key={value}
                    className={`choice${matched.includes(value) ? ' correct' : ''}`}
                    type="button"
                    disabled={matched.includes(value) || phase === 'feedback'}
                    onClick={() => onMatch('right', value)}
                  >
                    {value}
                  </button>
                ))}
              </div>
            </div>
          )}
          <footer className={`lesson-foot${phase === 'feedback' ? (ok ? ' good' : ' bad') : ''}`}>
            {phase === 'feedback' && <strong aria-live="polite">{message}</strong>}
            {phase === 'feedback' ? (
              <button className={`btn ${ok ? 'btn-green' : 'btn-red'} btn-wide`} type="button" onClick={continueNext}>つづける</button>
            ) : (
              <div className="check-row">
                <button className="text-link" type="button" onClick={() => grade(true)}>
                  わからない
                </button>
                <button className="btn btn-green btn-wide" type="button" disabled={!canCheck()} onClick={() => grade()}>チェック</button>
              </div>
            )}
          </footer>
        </div>
      )}
    </div>
  )
}
