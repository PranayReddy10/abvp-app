import { useState, type FormEvent } from 'react'
import { api, ApiError } from '../api'
import { useAuth } from '../auth'
import { ErrorBox } from '../components/ui'

/** Your own sign-in: set or change the password used on the admin panel. */
export default function Account() {
  const { me } = useAuth()
  const [hasPw, setHasPw] = useState(!!me?.has_password)
  const [current, setCurrent] = useState('')
  const [pw, setPw] = useState('')
  const [again, setAgain] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<unknown>(null)
  const [done, setDone] = useState(false)
  const fieldErr = (k: string) => (error instanceof ApiError ? error.fields?.[k]?.[0] : undefined)
  const mismatch = again.length > 0 && pw !== again

  async function save(e: FormEvent) {
    e.preventDefault()
    if (mismatch) return
    setBusy(true); setError(null); setDone(false)
    try {
      await api.put('/me/password', { current_password: hasPw ? current : undefined, password: pw, password_confirmation: again })
      setHasPw(true); setDone(true); setCurrent(''); setPw(''); setAgain('')
    } catch (err) { setError(err) } finally { setBusy(false) }
  }

  return (
    <main className="content">
      <div className="page-head">
        <div>
          <h1>My account</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>{me?.profile?.full_name ?? me?.name} · {me?.mobile}</p>
        </div>
      </div>
      <div className="grid2">
        <form className="card settings-card" onSubmit={save}>
          <div className="settings-head">
            <div>
              <h3 style={{ margin: 0 }}>{hasPw ? 'Change password' : 'Set a password'}</h3>
              <p className="muted" style={{ margin: '4px 0 0' }}>Sign in to the admin panel with your mobile number and this password – no waiting for an SMS code.</p>
            </div>
            <span className={`pill ${hasPw ? 'info' : 'mute'}`}>{hasPw ? 'Password set' : 'No password yet'}</span>
          </div>
          {done && <div className="notice" role="status">Password saved. Other devices signed in to your account have been signed out.</div>}
          <ErrorBox error={error instanceof ApiError && error.fields ? null : error} />
          <div className="settings-fields">
            {hasPw && (
              <div className="field">
                <label htmlFor="cur">Current password</label>
                <input id="cur" className="input" type="password" autoComplete="current-password" value={current} onChange={(e) => setCurrent(e.target.value)} required />
                {fieldErr('current_password') && <small className="bad-text">{fieldErr('current_password')}</small>}
              </div>
            )}
            <div className="field">
              <label htmlFor="new">New password</label>
              <input id="new" className="input" type="password" autoComplete="new-password" minLength={8} value={pw} onChange={(e) => setPw(e.target.value)} required />
              {fieldErr('password') ? <small className="bad-text">{fieldErr('password')}</small> : <small className="muted">At least 8 characters. Don't reuse your email or bank password.</small>}
            </div>
            <div className="field">
              <label htmlFor="again">Type it again</label>
              <input id="again" className="input" type="password" autoComplete="new-password" value={again} onChange={(e) => setAgain(e.target.value)} required />
              {mismatch && <small className="bad-text">The two passwords don't match.</small>}
            </div>
          </div>
          <div><button className="btn primary" disabled={busy || mismatch || pw.length < 8}>{busy ? 'Saving…' : hasPw ? 'Change password' : 'Set password'}</button></div>
        </form>
        <section className="card settings-card">
          <h3 style={{ margin: 0 }}>Forgot your password?</h3>
          <p className="muted" style={{ margin: 0 }}>Sign in with <b>Code on mobile</b> instead, then set a new one here. Your technical team can also reset it on the server:</p>
          <code style={{ display: 'block', padding: 12, borderRadius: 10, background: 'var(--surface-2)', fontSize: 13, overflowX: 'auto' }}>php artisan abvp:set-password {me?.mobile?.replace('+91', '')}</code>
        </section>
      </div>
    </main>
  )
}
