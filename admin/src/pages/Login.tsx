import { useEffect, useRef, useState, type FormEvent } from 'react'
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
  const [link, setLink] = useState<{ token: string; email: string } | null>(null)
  const [note, setNote] = useState('')
  const gBox = useRef<HTMLDivElement>(null)
  const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID

  async function finish(t: string, user: Me) {
    if (!user.permissions.includes('admin.access')) {
      token.set(t)
      await api.post('/auth/logout').catch(() => null)
      token.clear()
      throw new ApiError(403, 'NO_ADMIN_ROLE', 'This account has no admin role. Ask your state or district office to assign one.')
    }
    signIn(t, user)
  }

  // Google Identity Services button, when a client ID is configured.
  useEffect(() => {
    if (!clientId || link || sentTo) return
    const onCredential = async ({ credential }: { credential: string }) => {
      setBusy(true); setError(null)
      try {
        const r = await api.post<{ linked: boolean; token?: string; user?: Me; link_token?: string; email?: string }>('/auth/google', { id_token: credential, device_name: 'admin-web' })
        if (r.data.linked && r.data.token && r.data.user) await finish(r.data.token, r.data.user)
        else if (r.data.link_token) setLink({ token: r.data.link_token, email: r.data.email ?? '' })
      } catch (err) { setError(err) } finally { setBusy(false) }
    }
    const render = () => {
      if (!window.google || !gBox.current) return
      window.google.accounts.id.initialize({ client_id: clientId, callback: onCredential })
      window.google.accounts.id.renderButton(gBox.current, { theme: 'outline', size: 'large', shape: 'pill', width: 316, text: 'continue_with' })
    }
    if (window.google) { render(); return }
    const s = document.createElement('script')
    s.src = 'https://accounts.google.com/gsi/client'
    s.async = true
    s.onload = render
    document.head.appendChild(s)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [clientId, link, sentTo])

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
      const r = await api.post<{ token: string; user: Me }>('/auth/verify-otp', { mobile, code, device_name: 'admin-web', google_link_token: link?.token })
      await finish(r.data.token, r.data.user)
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
        {link && <div className="notice" role="status">Google account {link.email} is new here. Verify your mobile once to link it – next time Google signs you straight in.</div>}
        {note && !link && <div className="hint-box" role="status">{note}</div>}
        {!sentTo ? (
          <form onSubmit={send} style={{ display: 'grid', gap: 12 }}>
            <div className="field">
              <label htmlFor="mobile">Mobile number</label>
              <input id="mobile" className="input" inputMode="tel" autoComplete="tel" placeholder="98480 12345"
                value={mobile} onChange={(e) => setMobile(e.target.value)} required />
            </div>
            <button className="btn primary" disabled={busy}>{busy ? 'Sending…' : 'Send code'}</button>
            {!link && (
              <>
                <div className="or"><span>or</span></div>
                {clientId ? <div ref={gBox} className="gsi" /> : (
                  <button type="button" className="btn google-btn" onClick={() => setNote('Google sign-in is not switched on for this panel yet. Your technical team sets VITE_GOOGLE_CLIENT_ID (admin) and GOOGLE_CLIENT_IDS (API) – see docs/deploy-hostinger.md.')}>
                    <GoogleG /> Continue with Google
                  </button>
                )}
              </>
            )}
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

function GoogleG() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" />
      <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
      <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z" />
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" />
    </svg>
  )
}
