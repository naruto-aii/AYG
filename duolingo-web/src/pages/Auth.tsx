import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Owl, Wordmark } from '../components/Owl'
import { useStore } from '../store'

export function AuthPage({ mode }: { mode: 'login' | 'register' }) {
  const { state, login, register, continueAsGuest } = useStore()
  const navigate = useNavigate()
  const [name, setName] = useState(state.pending?.name ?? '')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [social, setSocial] = useState('')

  useEffect(() => {
    document.title = mode === 'login' ? 'ログイン' : 'アカウント作成'
    if (state.user) navigate('/learn', { replace: true })
  }, [mode, navigate, state.user])

  const onSubmit = (event: FormEvent) => {
    event.preventDefault()
    const message = mode === 'login' ? login(email, password) : register({ name, email, password })
    if (message) setError(message)
    else navigate('/learn')
  }

  return (
    <div className="auth-screen">
      <div className="auth-card">
        <Link to="/" className="logo-link"><Wordmark /></Link>
        <Owl mood="idle" size={96} />
        <h1>{mode === 'login' ? 'おかえりなさい' : 'アカウントを作成'}</h1>
        <p className="muted">このデモでは入力内容をこのブラウザだけに保存します。外部には送られません。</p>
        <form onSubmit={onSubmit} className="stack-form">
          {mode === 'register' && (
            <label>
              名前
              <input value={name} onChange={(event) => setName(event.target.value)} autoComplete="nickname" />
            </label>
          )}
          <label>
            メールアドレス
            <input value={email} onChange={(event) => setEmail(event.target.value)} type="email" autoComplete="username" />
          </label>
          <label>
            パスワード
            <input value={password} onChange={(event) => setPassword(event.target.value)} type="password" autoComplete={mode === 'login' ? 'current-password' : 'new-password'} />
          </label>
          {error && <p className="form-error">{error}</p>}
          <button className="btn btn-green btn-block" type="submit">{mode === 'login' ? 'ログイン' : '作成してはじめる'}</button>
        </form>
        <div className="socials">
          {['Google', 'Facebook', 'Apple'].map((provider) => (
            <button key={provider} className="btn btn-white btn-block" type="button" onClick={() => setSocial(`${provider} 連携はこのデモでは使えません。メールかゲストで進めます。`)}>
              {provider}で続ける
            </button>
          ))}
          {social && <p className="form-note">{social}</p>}
        </div>
        {mode === 'register' && (
          <button
            className="text-link"
            type="button"
            onClick={() => {
              continueAsGuest(name || state.pending?.name || 'ゲスト')
              navigate('/learn')
            }}
          >
            ゲストとして続ける
          </button>
        )}
        <p className="switch-auth">
          {mode === 'login' ? (
            <>アカウントをお持ちでない方は <Link to="/onboarding">こちら</Link></>
          ) : (
            <>すでにアカウントがある方は <Link to="/login">ログイン</Link></>
          )}
        </p>
      </div>
    </div>
  )
}
