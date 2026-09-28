import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Shell } from '../components/Shell'
import { Icon } from '../components/Icons'
import { allPathNodes, currentNodeId, isNodeDone, isUnlocked, sections } from '../data'
import { wave } from '../lib'
import { playSound } from '../sound'
import { useStore } from '../store'
import type { PathNode } from '../types'

export function LearnPage() {
  const { state } = useStore()
  const navigate = useNavigate()
  const [openId, setOpenId] = useState<string | null>(null)
  const [hint, setHint] = useState('')
  const [compact, setCompact] = useState(false)
  const activeId = currentNodeId(state.completed, state.chests)

  useEffect(() => {
    document.title = '学習'
    const media = window.matchMedia('(max-width: 700px)')
    const apply = () => setCompact(media.matches)
    apply()
    media.addEventListener('change', apply)
    return () => media.removeEventListener('change', apply)
  }, [])

  useEffect(() => {
    const node = document.getElementById('node-current')
    node?.scrollIntoView({ block: 'center' })
  }, [activeId])

  const jump = () => document.getElementById('node-current')?.scrollIntoView({ behavior: 'smooth', block: 'center' })

  const onNode = (node: PathNode) => {
    playSound('tap', state.sound)
    if (!isUnlocked(node.id, state.completed, state.chests)) {
      setHint('前のレッスンを終えると開きます')
      setOpenId(null)
      return
    }
    setHint('')
    setOpenId((current) => (current === node.id ? null : node.id))
  }

  const start = (node: PathNode) => {
    if (node.kind === 'chest') navigate(`/lesson/${node.id}`)
    else navigate(`/lesson/${node.id}`)
  }

  return (
    <Shell>
      <div className="learn">
        {sections.map((section) => (
          <section key={section.id} className="course-section">
            <div className="section-label">
              <span>{section.title}</span>
              <strong>{section.kicker}</strong>
            </div>
            {section.units.map((unit) => {
              const doneCount = unit.nodes.filter((node) => isNodeDone(node.id, state.completed, state.chests)).length
              const amplitude = compact ? 72 : 100
              const height = unit.nodes.length * 112
              const points = unit.nodes.map((_, index) => `${160 + wave(index, amplitude)},${index * 112 + 56}`)
              return (
                <div key={unit.id} className="unit">
                  <div className="unit-banner" style={{ background: unit.color }}>
                    <div>
                      <p>{unit.title}</p>
                      <strong>{doneCount}/{unit.nodes.length}</strong>
                    </div>
                    <Link to={`/guidebook/${unit.id}`} className="book-btn" aria-label="ガイドブック" style={{ color: unit.color }}>
                      <Icon name="book" color={unit.color} />
                    </Link>
                  </div>
                  <div className="path-inner">
                    <svg className="path-svg" width="320" height={height} viewBox={`0 0 320 ${height}`} aria-hidden="true">
                      <polyline points={points.join(' ')} fill="none" stroke="#e5e5e5" strokeWidth="12" strokeLinejoin="round" strokeLinecap="round" />
                    </svg>
                    {unit.nodes.map((node, index) => {
                      const done = isNodeDone(node.id, state.completed, state.chests)
                      const unlocked = isUnlocked(node.id, state.completed, state.chests)
                      const current = node.id === activeId && !done
                      const icon = node.kind === 'chest' ? 'chest' : node.kind === 'story' ? 'book' : node.kind === 'trophy' ? 'trophy' : 'star'
                      return (
                        <div
                          key={node.id}
                          id={current ? 'node-current' : undefined}
                          className="node-row"
                          style={{ transform: `translateX(${wave(index, amplitude)}px)` }}
                        >
                          {current && <span className="start-pill">スタート</span>}
                          <button
                            className={`node${done ? ' done' : ''}${current ? ' current' : ''}${unlocked ? '' : ' locked'}`}
                            style={{ background: unlocked ? unit.color : undefined, boxShadow: unlocked ? `0 6px 0 ${unit.dark}` : undefined }}
                            type="button"
                            onClick={() => onNode(node)}
                            aria-label={node.title}
                          >
                            <Icon name={unlocked ? icon : 'lock'} color="#fff" size={30} />
                          </button>
                          {openId === node.id && (
                            <div className="popover" role="dialog">
                              <p className="eyebrow">{node.kind === 'chest' ? '宝箱' : node.kind === 'story' ? 'ストーリー' : node.kind === 'trophy' ? '復習' : 'レッスン'}</p>
                              <h3>{node.title}</h3>
                              <p>{done ? 'もう一度練習すると少しXPが入ります。' : node.kind === 'chest' ? '宝石がもらえます。' : `+${node.xp} XP`}</p>
                              <button className="btn btn-green btn-block" type="button" onClick={() => start(node)}>
                                {done ? '練習する' : node.kind === 'chest' ? '開ける' : 'スタート'}
                              </button>
                            </div>
                          )}
                        </div>
                      )
                    })}
                  </div>
                </div>
              )
            })}
          </section>
        ))}
        <p className="path-end">ここまでがデモのコースです。全部で {allPathNodes().length} ステップあります。</p>
        {hint && <p className="toast">{hint}</p>}
        <button className="jump" type="button" onClick={jump}>現在地へ</button>
      </div>
    </Shell>
  )
}
