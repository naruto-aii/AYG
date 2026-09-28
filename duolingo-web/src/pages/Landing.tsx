import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Owl, Wordmark } from '../components/Owl'
import { useStore } from '../store'

const languages = ['韓国語', '英語', 'スペイン語', 'フランス語', '中国語', 'ドイツ語']

export function LandingPage() {
  const { state } = useStore()
  const navigate = useNavigate()
  const [notice, setNotice] = useState('')

  useEffect(() => {
    document.title = '言葉を学ぼう（非公式UIデモ）'
  }, [])

  return (
    <div className="landing">
      <header className="land-header">
        <Wordmark />
        <div className="land-actions">
          <button className="text-btn" type="button" onClick={() => setNotice('このデモの表示言語は日本語です。')}>
            言語: 日本語
          </button>
          <Link className="btn btn-white btn-small" to="/login">ログイン</Link>
        </div>
      </header>
      <section className="hero">
        <div className="hero-copy">
          <h1>無料で、楽しく、続く。言葉のレッスンをはじめよう。</h1>
          <p>日本語で意味を確認しながら、ハングルのあいさつから一日の表現まで進めます。問題の文は、このデモ用の見本です。</p>
          <button className="btn btn-green btn-wide" type="button" onClick={() => navigate(state.user ? '/learn' : '/onboarding')}>
            {state.user ? '学習を続ける' : '今すぐ始める'}
          </button>
          <Link className="text-link" to="/login">アカウントをお持ちの方はこちら</Link>
          {notice && <p className="form-note">{notice}</p>}
        </div>
        <div className="hero-art" aria-hidden="true">
          <div className="blob" />
          <Owl mood="happy" size={230} />
          <span className="float-card c1" lang="ko">안녕하세요</span>
          <span className="float-card c2">こんにちは</span>
          <span className="float-card c3">+15 XP</span>
        </div>
      </section>
      <section className="lang-section">
        <h2>学びたいコース</h2>
        <div className="lang-grid">
          {languages.map((language) => (
            <button
              key={language}
              className="lang-card"
              type="button"
              onClick={() => {
                if (language === '韓国語') navigate(state.user ? '/learn' : '/onboarding')
                else setNotice(`${language}コースは、このデモではまだ開けません。韓国語コースでハングルと日本語の問題を確認できます。`)
              }}
            >
              <span className="flag">{language.slice(0, 1)}</span>
              <strong>{language}</strong>
              <span>日本語話者向け</span>
            </button>
          ))}
        </div>
      </section>
      <section className="feature-section">
        <article>
          <h3>道なりに進む</h3>
          <p>ユニットごとに並んだ丸いレッスンを、上から順に開いていきます。</p>
        </article>
        <article>
          <h3>すぐわかる</h3>
          <p>選択、並べ替え、リスニング、マッチ。答えるとすぐに色で返ってきます。</p>
        </article>
        <article>
          <h3>続く仕組み</h3>
          <p>連続記録、宝石、ハート、リーグ、クエスト。今日の目標が横に残ります。</p>
        </article>
      </section>
      <footer className="land-footer">
        <p>これは画面構成と操作を確認するための非公式デモです。Duolingo, Inc. とは関係ありません。レッスンの文はオリジナルの見本で、公式の教材ではありません。</p>
        <p>進捗はこのブラウザの中だけに保存されます。</p>
      </footer>
    </div>
  )
}
