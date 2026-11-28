import { useEffect, useState, type FormEvent } from 'react'
import { api, ApiError } from '../api'
import { useAuth } from '../auth'
import { useFetch } from '../useFetch'
import { ErrorBox, Skeleton } from './ui'

interface SignIn {
  otp_enabled: boolean
  sms_driver: 'msg91' | 'log'
  msg91: { template_id: string | null; key_hint: string | null; has_key: boolean }
  google_enabled: boolean
  admins_with_password: number
}

/** Settings → Sign-in: switch sign-in with a mobile code on or off, and choose how codes are sent. */
export default function SignInSettings() {
  const { me } = useAuth()
  const { data, error, reload } = useFetch<SignIn>('/admin/settings/sign-in')
  const [otp, setOtp] = useState(true)
  const [driver, setDriver] = useState<'msg91' | 'log'>('log')
  const [key, setKey] = useState('')
  const [template, setTemplate] = useState('')
  const [testTo, setTestTo] = useState('')
  const [busy, setBusy] = useState<'save' | 'test' | null>(null)
  const [err, setErr] = useState<unknown>(null)
  const [msg, setMsg] = useState('')

  useEffect(() => {
    if (!data) return
    setOtp(data.otp_enabled); setDriver(data.sms_driver); setTemplate(data.msg91.template_id ?? '')
  }, [data])

  if (!data) return <section className="card settings-card"><h3 style={{ margin: 0 }}>Sign-in</h3><ErrorBox error={error} />{!error && <Skeleton rows={4} />}</section>

  const changed = otp !== data.otp_enabled || driver !== data.sms_driver || key !== '' || template !== (data.msg91.template_id ?? '')
  const lockRisk = !otp && !me?.has_password

  async function save(e: FormEvent) {
    e.preventDefault()
    setBusy('save'); setErr(null); setMsg('')
    try {
      await api.put('/admin/settings/sign-in', { otp_enabled: otp, sms_driver: driver, msg91_key: key || undefined, msg91_template: template || undefined })
      setKey(''); setMsg('Saved.'); reload()
    } catch (x) { setErr(x) } finally { setBusy(null) }
  }

  async function test() {
    setBusy('test'); setErr(null); setMsg('')
    try {
      const r = await api.post<{ message: string }>('/admin/settings/sign-in/test-sms', { mobile: testTo, msg91_key: key || undefined, msg91_template: template || undefined })
      setMsg(r.data.message)
    } catch (x) { setErr(x) } finally { setBusy(null) }
  }

  return (
    <form className="card settings-card" onSubmit={save}>
      <div className="settings-head">
        <div>
          <h3 style={{ margin: 0 }}>Sign-in</h3>
          <p className="muted" style={{ margin: '4px 0 0' }}>How members and admins sign in to the app, the website and this panel.</p>
        </div>
        <span className={`pill ${data.otp_enabled ? (data.sms_driver === 'msg91' ? 'info' : 'mute') : 'bad'}`}>
          {!data.otp_enabled ? 'Codes off' : data.sms_driver === 'msg91' ? 'SMS · MSG91' : 'Codes in server log'}
        </span>
      </div>

      <div className="toggle-row">
        <div>
          <b>Sign in with a code on mobile (OTP)</b>
          <p className="muted" style={{ margin: '2px 0 0', fontSize: 13.5 }}>A 6-digit code by SMS. New members also need it to sign up.</p>
        </div>
        <button type="button" role="switch" aria-checked={otp} aria-label="Sign in with a code on mobile" className={`switch ${otp ? 'on' : ''}`} onClick={() => setOtp(!otp)}><i /></button>
      </div>
      {!otp && (
        <div className={lockRisk ? 'error' : 'hint-box'} role="status">
          {lockRisk
            ? 'Set your own password under My account first – otherwise you could lock yourself out.'
            : `With codes off, only password${data.google_enabled ? ' and Google sign-in work' : ' sign-in works'}. Members without a password cannot sign in or sign up on the app and website. ${data.admins_with_password} admin${data.admins_with_password === 1 ? ' has' : 's have'} a password.`}
        </div>
      )}

      {otp && (
        <>
          <div className="choice-grid" role="radiogroup" aria-label="How codes are sent">
            <label className={`choice ${driver === 'msg91' ? 'on' : ''}`}>
              <input type="radio" name="sms" checked={driver === 'msg91'} onChange={() => setDriver('msg91')} />
              <b>SMS through MSG91</b>
              <span className="muted">Real SMS to every phone. Needs an MSG91 account and a DLT-approved OTP template.</span>
            </label>
            <label className={`choice ${driver === 'log' ? 'on' : ''}`}>
              <input type="radio" name="sms" checked={driver === 'log'} onChange={() => setDriver('log')} />
              <b>Testing: server log</b>
              <span className="muted">No SMS is sent. Codes are written to api/storage/logs/laravel.log for your technical team.</span>
            </label>
          </div>
          {driver === 'msg91' && (
            <div className="settings-fields">
              <div className="field">
                <label htmlFor="m-key">MSG91 auth key</label>
                <input id="m-key" className="input" type="password" autoComplete="off" value={key} onChange={(e) => setKey(e.target.value.trim())}
                  placeholder={data.msg91.has_key ? `Saved (${data.msg91.key_hint}) – type only to replace` : 'From MSG91 → API → Auth key'} />
              </div>
              <div className="field">
                <label htmlFor="m-tpl">OTP template ID</label>
                <input id="m-tpl" className="input" autoComplete="off" value={template} onChange={(e) => setTemplate(e.target.value.trim())} placeholder="From MSG91 → Flow / Templates" />
                <small className="muted">The template's message must contain the variable <code>##otp##</code>.</small>
              </div>
              <div className="field">
                <label htmlFor="m-test">Send a test SMS to</label>
                <div style={{ display: 'flex', gap: 8 }}>
                  <input id="m-test" className="input" inputMode="tel" placeholder="98480 12345" value={testTo} onChange={(e) => setTestTo(e.target.value)} />
                  <button type="button" className="btn" disabled={!!busy || testTo.replace(/\D/g, '').length < 10 || (!key && !data.msg91.has_key) || !template} onClick={test}>{busy === 'test' ? 'Sending…' : 'Send test'}</button>
                </div>
              </div>
            </div>
          )}
          {driver === 'log' && <div className="hint-box">Use this only while testing. Switch to MSG91 before members start signing in.</div>}
        </>
      )}

      {msg && <div className="notice" role="status">{msg}</div>}
      <ErrorBox error={err instanceof ApiError || err instanceof Error ? err : null} />
      <div><button className="btn primary" disabled={!!busy || !changed || lockRisk}>{busy === 'save' ? 'Saving…' : 'Save'}</button></div>
      <p className="muted" style={{ fontSize: 12.5, margin: 0 }}>Password sign-in is always on for anyone who has set a password. Google sign-in is {data.google_enabled ? 'on' : 'off (set GOOGLE_CLIENT_IDS on the server)'}.</p>
    </form>
  )
}
