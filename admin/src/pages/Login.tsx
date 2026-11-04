import { useState, type FormEvent } from 'react'
import { api, ApiError, token } from '../api'
import { useAuth } from '../auth'
import type { Me } from '../types'
import { ErrorBox } from '../components/ui'

export default function Login() {
  const { signIn } = useAuth()
  const [mobile, setMobile] = useState('')
  const [code, setCode] = useState('')
  const [sentTo, setSentTo] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<unknown>(null)

  async function send(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null)
    try {
      const r = await api.post<{ mobile: string }>('/auth/send-otp', { mobile })
      setSentTo(r.data.mobile)
    } catch (err) { setError(err) } finally { setBusy(false) }
  }

  async function verify(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null)
    try {
      const r = await api.post<{ token: string; user: Me }>('/auth/verify-otp', { mobile, code, device_name: 'admin-web' })
      if (!r.data.user.permissions.includes('admin.access')) {
        token.set(r.data.token)
        await api.post('/auth/logout').catch(() => null)
        token.clear()
        throw new ApiError(403, 'NO_ADMIN_ROLE', 'This number has no admin role. Ask your state or district office to assign one.')
      }
      signIn(r.data.token, r.data.user)
    } catch (err) { setError(err) } finally { setBusy(false) }
  }

  return (
    <main className="login">
      <section className="brand-panel" aria-hidden="true">
        <h2>ABVP Connect</h2>
        <p>Membership, Vibhags, meetings, events and event-day operations for every office, in one place.</p>
        <p style={{ fontSize: 14 }}>एक सदस्य · एक पहचान · हर कार्यक्रम</p>
      </section>
      <div className="form-side">
      <div className="box">
        <img src="/favicon.svg" alt="" width={44} height={44} />
        <div style={{ display: 'grid', gap: 4 }}>
          <h1>ABVP Connect Admin</h1>
          <p className="muted">Sign in with the mobile number your admin role is linked to.</p>
        </div>
        <ErrorBox error={error} />
        {!sentTo ? (
          <form onSubmit={send} style={{ display: 'grid', gap: 12 }}>
            <div className="field">
              <label htmlFor="mobile">Mobile number</label>
              <input id="mobile" className="input" inputMode="tel" autoComplete="tel" placeholder="98480 12345"
                value={mobile} onChange={(e) => setMobile(e.target.value)} required />
            </div>
            <button className="btn primary" disabled={busy}>{busy ? 'Sending…' : 'Send code'}</button>
          </form>
        ) : (
          <form onSubmit={verify} style={{ display: 'grid', gap: 12 }}>
            <div className="field">
              <label htmlFor="code">6-digit code sent to {sentTo}</label>
              <input id="code" className="input otp" inputMode="numeric" autoComplete="one-time-code" maxLength={6}
                value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} required autoFocus />
            </div>
            <button className="btn primary" disabled={busy || code.length !== 6}>{busy ? 'Checking…' : 'Verify and sign in'}</button>
            <button type="button" className="btn" onClick={() => { setSentTo(null); setCode('') }}>Use a different number</button>
          </form>
        )}
      </div>
      </div>
    </main>
  )
}
