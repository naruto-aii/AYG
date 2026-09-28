import { useEffect, useState } from 'react'
import { Shell } from '../components/Shell'
import { Icon } from '../components/Icons'
import { shopItems } from '../data'
import { formatLeft } from '../lib'
import { playSound } from '../sound'
import { nextHeartIn, useStore } from '../store'

const icons = { freeze: 'freeze', hearts: 'heart', boost: 'bolt' } as const

export function ShopPage() {
  const { state, buy } = useStore()
  const [note, setNote] = useState('')

  useEffect(() => {
    document.title = 'ショップ'
  }, [])

  return (
    <Shell>
      <div className="page">
        <header className="page-hero">
          <h1>ショップ</h1>
          <p className="gem-pill"><Icon name="gem" color="#1cb0f6" size={20} /> {state.gems}</p>
        </header>
        {!state.super && state.hearts < 5 && <p className="muted">次のハートまで {formatLeft(nextHeartIn(state))}</p>}
        {state.boostUntil > Date.now() && <p className="form-note">2倍のXPが有効です。</p>}
        <div className="shop-grid">
          {shopItems.map((item) => (
            <article key={item.id} className="shop-card">
              <Icon name={icons[item.id]} size={36} color={item.id === 'hearts' ? '#ff4b4b' : item.id === 'boost' ? '#ffc800' : '#1cb0f6'} />
              <h2>{item.name}</h2>
              <p>{item.desc}</p>
              <button
                className="btn btn-white"
                type="button"
                onClick={() => {
                  const message = buy(item.id)
                  setNote(message ?? `${item.name}を手に入れました`)
                  if (!message) playSound('gem', state.sound)
                }}
              >
                <Icon name="gem" color="#1cb0f6" size={18} /> {item.price}
              </button>
            </article>
          ))}
        </div>
        {note && <p className="toast static">{note}</p>}
        <p className="muted">所持中のフリーズ: {state.freezes}/2</p>
      </div>
    </Shell>
  )
}
